#!/bin/bash
set -e

APPDIR=".packaging/AppDir_Full"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/lib"
mkdir -p "$APPDIR/usr/share"

cp_with_symlinks() {
    local src="$1"
    local dest="$2"
    if [ -f "$src" ] || [ -L "$src" ]; then
        cp -a "$src"* "$dest/"
    fi
}

echo "Installing binaries..."
cp src/interface/.libs/tabftp "$APPDIR/usr/bin/"
cp src/putty/fzputtygen "$APPDIR/usr/bin/"
cp src/putty/fzsftp "$APPDIR/usr/bin/"

echo "Installing internal private libraries..."
# Copy both the symlink and the versioned library file
cp -a src/engine/.libs/libfzclient-private*.so* "$APPDIR/usr/lib/"
cp -a src/commonui/.libs/libfzclient-commonui-private*.so* "$APPDIR/usr/lib/"

echo "Installing resources..."
# Ensure the resource path matches what tabftp expects (FZ_DATADIR/resources)
mkdir -p "$APPDIR/usr/share/tabftp"
cp -a src/interface/resources "$APPDIR/usr/share/tabftp/"


echo "Copying ALL dependencies (including glibc)..."

# Helper to copy libs
copy_libs() {
    local bin="$1"
    # Get all dependencies
    ldd "$bin" | grep "=> /" | awk '{print $3}' | while read -r lib; do
        if [ -f "$lib" ]; then
            cp -n "$lib" "$APPDIR/usr/lib/" || true
        fi
    done
    # Also copy the interpreter (ld-linux)
    ldd "$bin" | grep "/ld-linux" | awk '{print $1}' | while read -r lib; do
        if [ -f "$lib" ]; then
            cp -n "$lib" "$APPDIR/usr/lib/" || true
        fi
    done
}

copy_libs "$APPDIR/usr/bin/tabftp"
copy_libs "$APPDIR/usr/bin/fzputtygen"
copy_libs "$APPDIR/usr/bin/fzsftp"

echo "Copying libfuse2..."
if [ -f /usr/lib/x86_64-linux-gnu/libfuse.so.2 ]; then
    cp -a /usr/lib/x86_64-linux-gnu/libfuse.so.2* "$APPDIR/usr/lib/"
fi

echo "Copying gdk-pixbuf loaders..."
GDK_PIXBUF_DIR="$APPDIR/usr/lib/gdk-pixbuf-2.0/loaders"
mkdir -p "$GDK_PIXBUF_DIR"
# Copy loaders from system
find /usr/lib/x86_64-linux-gnu/gdk-pixbuf-2.0 -name "libpixbufloader-*.so" -exec cp {} "$GDK_PIXBUF_DIR/" \;

# Generate loaders.cache.in with placeholder paths to be expanded at runtime
if [ -f /usr/lib/x86_64-linux-gnu/gdk-pixbuf-2.0/2.10.0/loaders.cache ]; then
    sed -E 's|"(/usr/lib[^"]*/gdk-pixbuf-2.0/[^"]*/loaders)/|"@GDK_PIXBUF_MODULEDIR@/|g' \
        /usr/lib/x86_64-linux-gnu/gdk-pixbuf-2.0/2.10.0/loaders.cache > "$GDK_PIXBUF_DIR/loaders.cache.in"
fi

echo "Copying gdk-pixbuf loader dependencies..."
for module in "$GDK_PIXBUF_DIR"/libpixbufloader-*.so; do
    if [ -f "$module" ]; then
        copy_libs "$module"
    fi
done

echo "Copying glib schemas..."
mkdir -p "$APPDIR/usr/share/glib-2.0/schemas"
cp /usr/share/glib-2.0/schemas/* "$APPDIR/usr/share/glib-2.0/schemas/" || true
# If glib-compile-schemas is available, recompile. Otherwise hope gschemas.compiled is compatible.
if command -v glib-compile-schemas >/dev/null; then
    glib-compile-schemas "$APPDIR/usr/share/glib-2.0/schemas"
fi

# Manually copy ld-linux if missed (ldd output varies)
cp /lib64/ld-linux-x86-64.so.2 "$APPDIR/usr/lib/" || cp /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 "$APPDIR/usr/lib/"

echo "Creating AppRun..."
cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/bash
set -e
PATH="${PATH:-/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin}"
export PATH
THIS_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

FUSE_LD_LIBRARY_PATH=""
if [ -n "${APPIMAGE:-}" ]; then
    APPIMAGE_DIR="$(dirname "$APPIMAGE")"
    HAS_SYSTEM_FUSE=0

    if [ -e /lib/x86_64-linux-gnu/libfuse.so.2 ] || \
       [ -e /usr/lib/x86_64-linux-gnu/libfuse.so.2 ] || \
       [ -e /lib64/libfuse.so.2 ] || \
       [ -e /usr/lib64/libfuse.so.2 ] || \
       [ -e /lib/libfuse.so.2 ] || \
       [ -e /usr/lib/libfuse.so.2 ]; then
        HAS_SYSTEM_FUSE=1
    fi

    if [ "$HAS_SYSTEM_FUSE" -eq 0 ]; then
        if [ -f "$APPIMAGE_DIR/libfuse.so.2" ]; then
            FUSE_LD_LIBRARY_PATH="$APPIMAGE_DIR"
        elif [ -f "./libfuse.so.2" ]; then
            FUSE_LD_LIBRARY_PATH="$(pwd)"
        fi
    fi
fi

# Find linker - MUST happen before LD_LIBRARY_PATH is set to avoid system command breakage
# We expect ld-linux-x86-64.so.2 to be present in usr/lib
LINKER="$THIS_DIR/usr/lib/ld-linux-x86-64.so.2"
if [ ! -f "$LINKER" ]; then
    # Fallback using find if not at expected path, but do it safely
    LINKER=$(find "$THIS_DIR/usr/lib" -name "ld-linux-*.so.*" | head -n 1)
fi

EXEC="$THIS_DIR/usr/bin/tabftp"

GDK_PIXBUF_MODULEDIR="$THIS_DIR/usr/lib/gdk-pixbuf-2.0/loaders"
GDK_PIXBUF_TEMPLATE="$GDK_PIXBUF_MODULEDIR/loaders.cache.in"

GDK_PIXBUF_MODULE_FILE=""

cache_base="${XDG_CACHE_HOME:-$HOME/.cache}"
if [ -n "${cache_base:-}" ] && mkdir -p "$cache_base/tabftp" 2>/dev/null && [ -w "$cache_base/tabftp" ]; then
    RUNTIME_CACHE_DIR="$cache_base/tabftp"
else
    RUNTIME_CACHE_DIR="$(mktemp -d /tmp/tabftp-runtime.XXXXXX)"
fi
GDK_PIXBUF_CACHE_DIR="$RUNTIME_CACHE_DIR"
GDK_PIXBUF_CACHE_FILE="$GDK_PIXBUF_CACHE_DIR/gdk-pixbuf-loaders.cache"

if [ -f "$GDK_PIXBUF_TEMPLATE" ]; then
    sed "s|@GDK_PIXBUF_MODULEDIR@|$GDK_PIXBUF_MODULEDIR|g" "$GDK_PIXBUF_TEMPLATE" > "$GDK_PIXBUF_CACHE_FILE"
    GDK_PIXBUF_MODULE_FILE="$GDK_PIXBUF_CACHE_FILE"
elif [ -f "$THIS_DIR/usr/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache" ]; then
    GDK_PIXBUF_MODULE_FILE="$THIS_DIR/usr/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache"
fi

FZSFTP_WRAPPER="$RUNTIME_CACHE_DIR/fzsftp"
cat > "$FZSFTP_WRAPPER" <<EOF2
#!/bin/bash
exec "$LINKER" --library-path "$THIS_DIR/usr/lib" "$THIS_DIR/usr/bin/fzsftp" "\$@"
EOF2
chmod +x "$FZSFTP_WRAPPER" 2>/dev/null || true

FZPUTTYGEN_WRAPPER="$RUNTIME_CACHE_DIR/fzputtygen"
cat > "$FZPUTTYGEN_WRAPPER" <<EOF2
#!/bin/bash
exec "$LINKER" --library-path "$THIS_DIR/usr/lib" "$THIS_DIR/usr/bin/fzputtygen" "\$@"
EOF2
chmod +x "$FZPUTTYGEN_WRAPPER" 2>/dev/null || true

ENV_ARGS=(
    "PATH=$THIS_DIR/usr/bin:${PATH:-/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin}"
    "FZ_DATADIR=$THIS_DIR/usr/share/tabftp"
    "FZ_FZSFTP=$FZSFTP_WRAPPER"
    "FZ_FZPUTTYGEN=$FZPUTTYGEN_WRAPPER"
    "XDG_DATA_DIRS=$THIS_DIR/usr/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
    "GSETTINGS_SCHEMA_DIR=$THIS_DIR/usr/share/glib-2.0/schemas"
    "GDK_PIXBUF_MODULEDIR=$GDK_PIXBUF_MODULEDIR"
)
if [ -n "$GDK_PIXBUF_MODULE_FILE" ]; then
    ENV_ARGS+=("GDK_PIXBUF_MODULE_FILE=$GDK_PIXBUF_MODULE_FILE")
fi
if [ -n "$FUSE_LD_LIBRARY_PATH" ]; then
    ENV_ARGS+=("LD_LIBRARY_PATH=$FUSE_LD_LIBRARY_PATH${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}")
else
    ENV_ARGS+=("LD_LIBRARY_PATH=")
fi

exec env "${ENV_ARGS[@]}" "$LINKER" --library-path "$THIS_DIR/usr/lib" "$EXEC" "$@"
EOF

chmod +x "$APPDIR/AppRun"

echo "Copying desktop file and icon..."
cp data/tabftp.desktop "$APPDIR/"
cp src/interface/resources/48x48/tabftp.png "$APPDIR/"

echo "Done preparing AppDir_Full."
