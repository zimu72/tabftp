#!/bin/bash
# TabFTP - Build AppImage
# This script creates a self-contained AppImage package

set -e

echo "=== TabFTP: Building AppImage ==="
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Get version from configure.ac
VERSION=$(grep "AC_INIT" configure.ac | sed -n 's/.*\[TabFTP\],\[\([0-9.]*\)\].*/\1/p')
echo "Version: $VERSION"

# Output directory
APPDIR=".packaging/AppDir"
OUTPUT_DIR="dist"

# Clean and create directories
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/lib"
mkdir -p "$APPDIR/usr/lib/gdk-pixbuf-2.0/loaders"
mkdir -p "$APPDIR/usr/share/tabftp"
mkdir -p "$APPDIR/usr/share/glib-2.0/schemas"
mkdir -p "$APPDIR/usr/share/locale"
mkdir -p "$OUTPUT_DIR"

echo ""
echo "Step 1: Copying executables..."
cp src/interface/.libs/tabftp "$APPDIR/usr/bin/"
cp src/putty/fzsftp "$APPDIR/usr/bin/"
cp src/putty/fzputtygen "$APPDIR/usr/bin/"
echo "  Copied tabftp, fzsftp, fzputtygen"

echo ""
echo "Step 2: Copying private libraries..."
cp -a src/engine/.libs/libfzclient-private*.so* "$APPDIR/usr/lib/"
cp -a src/commonui/.libs/libfzclient-commonui-private*.so* "$APPDIR/usr/lib/"
echo "  Copied private libraries"

echo ""
echo "Step 3: Copying resources..."
cp -a src/interface/resources "$APPDIR/usr/share/tabftp/"
echo "  Copied resources"

echo ""
echo "Step 4: Collecting and copying dependencies..."

should_exclude_lib() {
    local lib_basename="$1"
    return 1
}

should_skip_strip() {
    local lib_basename="$1"
    case "$lib_basename" in
        ld-linux-*.so*|ld-linux-x86-64.so.2|ld-linux-aarch64.so.1)
            return 0
            ;;
        libc.so.6|libpthread.so.0|libm.so.6|libdl.so.2|librt.so.1|libutil.so.1|libresolv.so.2|libanl.so.1)
            return 0
            ;;
        libnss_*.so.*|libnss_*.so|libnss_files.so.2|libnss_dns.so.2|libnss_compat.so.2|libnss_myhostname.so.2)
            return 0
            ;;
    esac
    return 1
}

copy_lib() {
    local lib="$1"
    local dest="$2"
    
    if [ ! -f "$lib" ]; then
        return
    fi
    
    local reallib=$(readlink -f "$lib")
    local basename=$(basename "$reallib")
    
    if [ ! -f "$dest/$basename" ]; then
        cp -a "$reallib" "$dest/"
        if ! should_skip_strip "$basename"; then
            strip --strip-unneeded "$dest/$basename" 2>/dev/null || true
        fi
    fi
    
    local libname=$(basename "$lib")
    if [ "$libname" != "$basename" ] && [ ! -e "$dest/$libname" ]; then
        ln -sf "$basename" "$dest/$libname"
    fi
}

copy_libs_recursive() {
    local target="$1"
    local dest="$2"

    ldd "$target" 2>/dev/null | grep "=> /" | awk '{print $3}' | while read -r lib; do
        if [ -f "$lib" ]; then
            local reallib
            reallib=$(readlink -f "$lib")
            local basename
            basename=$(basename "$reallib")

            if should_exclude_lib "$basename"; then
                continue
            fi

            if [ ! -f "$dest/$basename" ]; then
                copy_lib "$lib" "$dest"
                copy_libs_recursive "$lib" "$dest"
            fi
        fi
    done
}

echo "  Collecting dependencies recursively for binaries..."
for bin in "$APPDIR/usr/bin"/*; do
    if [ -f "$bin" ]; then
        echo "    Scanning $bin..."
        copy_libs_recursive "$bin" "$APPDIR/usr/lib"
    fi
done

echo "  Collecting dependencies recursively for private libs..."
for lib in "$APPDIR/usr/lib"/libfzclient*.so*; do
    if [ -f "$lib" ] && [ ! -L "$lib" ]; then
        echo "    Scanning $lib..."
        copy_libs_recursive "$lib" "$APPDIR/usr/lib"
    fi
done

echo "  Collected library dependencies"

echo ""
echo "Step 4.5: Copying NSS modules..."
NSS_DIR=""
for dir in /lib/x86_64-linux-gnu /lib64 /usr/lib/x86_64-linux-gnu /usr/lib64 /lib /usr/lib; do
    if [ -f "$dir/libnss_files.so.2" ] || [ -f "$dir/libnss_dns.so.2" ]; then
        NSS_DIR="$dir"
        break
    fi
done

if [ -n "$NSS_DIR" ]; then
    for nss in \
        libnss_files.so.2 \
        libnss_dns.so.2 \
        libnss_compat.so.2 \
        libnss_nis.so.2 \
        libnss_nisplus.so.2 \
        libnss_hesiod.so.2 \
        libnss_myhostname.so.2 \
        libnsl.so.2 \
        libnsl.so.1; do
        if [ -f "$NSS_DIR/$nss" ]; then
            copy_lib "$NSS_DIR/$nss" "$APPDIR/usr/lib"
            copy_libs_recursive "$NSS_DIR/$nss" "$APPDIR/usr/lib"
        fi
    done
fi
echo "  Copied NSS modules"

echo ""
echo "Step 5: Copying dynamic linker..."
if [ -f /lib64/ld-linux-x86-64.so.2 ]; then
    cp -a "$(readlink -f /lib64/ld-linux-x86-64.so.2)" "$APPDIR/usr/lib/ld-linux-x86-64.so.2"
elif [ -f /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 ]; then
    cp -a "$(readlink -f /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2)" "$APPDIR/usr/lib/ld-linux-x86-64.so.2"
fi
echo "  Copied ld-linux-x86-64.so.2"

echo ""
echo "Step 5.5: Patching RPATH for direct execution..."
if command -v patchelf &>/dev/null; then
    for bin in "$APPDIR/usr/bin/tabftp" "$APPDIR/usr/bin/fzsftp" "$APPDIR/usr/bin/fzputtygen"; do
        if [ -f "$bin" ]; then
            patchelf --force-rpath --set-rpath '$ORIGIN/../lib' "$bin" 2>/dev/null || true
        fi
    done

    for so in "$APPDIR/usr/lib"/*.so*; do
        if [ -f "$so" ] && [ ! -L "$so" ]; then
            so_base=$(basename "$so")
            if should_skip_strip "$so_base"; then
                continue
            fi
            patchelf --force-rpath --set-rpath '$ORIGIN' "$so" 2>/dev/null || true
        fi
    done
fi
echo "  Patched RPATH"

echo ""
echo "Step 6: Copying gdk-pixbuf loaders..."
GDK_PIXBUF_DIR=""
for dir in /usr/lib/x86_64-linux-gnu/gdk-pixbuf-2.0 /usr/lib64/gdk-pixbuf-2.0 /usr/lib/gdk-pixbuf-2.0; do
    if [ -d "$dir" ]; then
        GDK_PIXBUF_DIR="$dir"
        break
    fi
done

if [ -n "$GDK_PIXBUF_DIR" ]; then
    find "$GDK_PIXBUF_DIR" -name "libpixbufloader-*.so" -exec cp {} "$APPDIR/usr/lib/gdk-pixbuf-2.0/loaders/" \;
    
    # Collect dependencies for loaders
    for loader in "$APPDIR/usr/lib/gdk-pixbuf-2.0/loaders"/*.so; do
        if [ -f "$loader" ]; then
            copy_libs_recursive "$loader" "$APPDIR/usr/lib"
        fi
    done
    
    # Create loaders.cache template
    CACHE_FILE=$(find "$GDK_PIXBUF_DIR" -name "loaders.cache" 2>/dev/null | head -1)
    if [ -f "$CACHE_FILE" ]; then
        sed -E 's|"(/usr/lib[^"]*/gdk-pixbuf-2.0/[^"]*/loaders)/|"@GDK_PIXBUF_MODULEDIR@/|g' \
            "$CACHE_FILE" > "$APPDIR/usr/lib/gdk-pixbuf-2.0/loaders/loaders.cache.in"
    fi
    echo "  Copied pixbuf loaders"
fi

echo ""
echo "Step 7: Copying glib schemas..."
if [ -d /usr/share/glib-2.0/schemas ]; then
    cp /usr/share/glib-2.0/schemas/gschemas.compiled "$APPDIR/usr/share/glib-2.0/schemas/" 2>/dev/null || true
fi
echo "  Copied glib schemas"

echo ""
echo "Step 8: Copying translations..."
# Copy to FZ_DATADIR/locales/ path (primary location checked by program)
mkdir -p "$APPDIR/usr/share/tabftp/locales"
if [ -d locales ]; then
    for mo in locales/*.mo; do
        if [ -f "$mo" ]; then
            locale=$(basename "$mo" .mo)
            mkdir -p "$APPDIR/usr/share/tabftp/locales/$locale"
            cp "$mo" "$APPDIR/usr/share/tabftp/locales/$locale/tabftp.mo"
        fi
    done
fi

LFZ_PREFIX=$(pkg-config --variable=prefix libfilezilla 2>/dev/null || echo "/usr")
if [ -d "$LFZ_PREFIX/share/locale" ]; then
    for mo in "$LFZ_PREFIX"/share/locale/*/LC_MESSAGES/libfilezilla.mo; do
        if [ -f "$mo" ]; then
            locale=$(echo "$mo" | sed 's/.*\/\([^\/]*\)\/LC_MESSAGES\/libfilezilla.mo/\1/')
            mkdir -p "$APPDIR/usr/share/tabftp/locales/$locale"
            cp "$mo" "$APPDIR/usr/share/tabftp/locales/$locale/libfilezilla.mo"
        fi
    done
fi

# Also copy to share/locale for fallback
if [ -d locales ]; then
    for mo in locales/*.mo; do
        if [ -f "$mo" ]; then
            locale=$(basename "$mo" .mo)
            mkdir -p "$APPDIR/usr/share/locale/$locale/LC_MESSAGES"
            cp "$mo" "$APPDIR/usr/share/locale/$locale/LC_MESSAGES/tabftp.mo"
        fi
    done
fi
if [ -d "$LFZ_PREFIX/share/locale" ]; then
    for mo in "$LFZ_PREFIX"/share/locale/*/LC_MESSAGES/libfilezilla.mo; do
        if [ -f "$mo" ]; then
            locale=$(echo "$mo" | sed 's/.*\/\([^\/]*\)\/LC_MESSAGES\/libfilezilla.mo/\1/')
            mkdir -p "$APPDIR/usr/share/locale/$locale/LC_MESSAGES"
            cp "$mo" "$APPDIR/usr/share/locale/$locale/LC_MESSAGES/libfilezilla.mo"
        fi
    done
fi
echo "  Copied translations"

echo ""
echo "Step 9: Creating AppRun script..."
cat > "$APPDIR/AppRun" << 'APPRUN_EOF'
#!/bin/bash
set -e
PATH="${PATH:-/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin}"
export PATH
THIS_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

FUSE_LD_LIBRARY_PATH=""
if [ -n "$APPIMAGE" ]; then
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

EXEC="$THIS_DIR/usr/bin/tabftp"
FZSFTP_BIN="$THIS_DIR/usr/bin/fzsftp"
FZPUTTYGEN_BIN="$THIS_DIR/usr/bin/fzputtygen"
LINKER="$THIS_DIR/usr/lib/ld-linux-x86-64.so.2"

GDK_PIXBUF_MODULEDIR="$THIS_DIR/usr/lib/gdk-pixbuf-2.0/loaders"
GDK_PIXBUF_TEMPLATE="$GDK_PIXBUF_MODULEDIR/loaders.cache.in"

GDK_PIXBUF_MODULE_FILE=""

# Setup runtime cache directory
cache_base="${XDG_CACHE_HOME:-$HOME/.cache}"
if [ -n "${cache_base:-}" ] && mkdir -p "$cache_base/tabftp" 2>/dev/null && [ -w "$cache_base/tabftp" ]; then
    RUNTIME_CACHE_DIR="$cache_base/tabftp"
else
    RUNTIME_CACHE_DIR="$(mktemp -d /tmp/tabftp-runtime.XXXXXX)"
fi
GDK_PIXBUF_CACHE_FILE="$RUNTIME_CACHE_DIR/gdk-pixbuf-loaders.cache"

# Generate pixbuf cache
if [ -f "$GDK_PIXBUF_TEMPLATE" ]; then
    sed "s|@GDK_PIXBUF_MODULEDIR@|$GDK_PIXBUF_MODULEDIR|g" "$GDK_PIXBUF_TEMPLATE" > "$GDK_PIXBUF_CACHE_FILE"
    GDK_PIXBUF_MODULE_FILE="$GDK_PIXBUF_CACHE_FILE"
fi

# Setup environment
ENV_ARGS=(
    "PATH=$THIS_DIR/usr/bin:${PATH:-/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin}"
    "FZ_DATADIR=$THIS_DIR/usr/share/tabftp"
    "FZ_FZSFTP=$FZSFTP_BIN"
    "FZ_FZPUTTYGEN=$FZPUTTYGEN_BIN"
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

if [ -x "$LINKER" ]; then
    exec env "${ENV_ARGS[@]}" "$LINKER" --library-path "$THIS_DIR/usr/lib" "$EXEC" "$@"
fi

exec env "${ENV_ARGS[@]}" "$EXEC" "$@"
APPRUN_EOF
chmod +x "$APPDIR/AppRun"
echo "  Created AppRun"

echo ""
echo "Step 10: Creating desktop file and icon..."
cp data/tabftp.desktop "$APPDIR/"
# Find and copy icon
if [ -f src/interface/resources/appicon.png ]; then
    cp src/interface/resources/appicon.png "$APPDIR/tabftp.png"
elif [ -f src/interface/resources/48x48/tabftp.png ]; then
    cp src/interface/resources/48x48/tabftp.png "$APPDIR/"
elif [ -f src/interface/resources/default/48x48/tabftp.png ]; then
    cp src/interface/resources/default/48x48/tabftp.png "$APPDIR/"
fi
# Create .DirIcon symlink
ln -sf tabftp.png "$APPDIR/.DirIcon"
echo "  Created desktop file and icon"

echo ""
echo "Step 11: Building AppImage..."

# Download appimagetool if not present
APPIMAGETOOL="./appimagetool-x86_64.AppImage"
if [ ! -f "$APPIMAGETOOL" ]; then
    echo "  Downloading appimagetool..."
    wget -q "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage" -O "$APPIMAGETOOL"
    chmod +x "$APPIMAGETOOL"
fi

# Build AppImage
APPIMAGE_NAME="TabFTP-${VERSION}-x86_64.AppImage"
ARCH=x86_64 "$APPIMAGETOOL" "$APPDIR" "$OUTPUT_DIR/$APPIMAGE_NAME"

echo ""
echo "=== AppImage Build Complete ==="
echo ""
echo "Output: $OUTPUT_DIR/$APPIMAGE_NAME"
ls -lh "$OUTPUT_DIR/$APPIMAGE_NAME"
