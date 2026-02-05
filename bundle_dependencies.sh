#!/bin/bash
# TabFTP - Bundle Dependencies
# This script collects all runtime dependencies for packaging

set -e

echo "=== TabFTP: Bundling Dependencies ==="
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Default output directory
OUTPUT_DIR="${1:-.packaging/deps}"

# Create output directory
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/lib"
mkdir -p "$OUTPUT_DIR/lib/gdk-pixbuf-2.0/loaders"
mkdir -p "$OUTPUT_DIR/share/glib-2.0/schemas"
mkdir -p "$OUTPUT_DIR/share/locale"

# List of system libraries to exclude (these should be on any Linux system)
EXCLUDE_LIBS=(
    "linux-vdso.so"
    "ld-linux-x86-64.so"
    "libc.so"
    "libm.so"
    "libdl.so"
    "librt.so"
    "libpthread.so"
    "libresolv.so"
    "libnss_"
    "libnsl.so"
)

# Function to check if library should be excluded
should_exclude() {
    local lib="$1"
    for exclude in "${EXCLUDE_LIBS[@]}"; do
        if [[ "$lib" == *"$exclude"* ]]; then
            return 0
        fi
    done
    return 1
}

# Function to copy library with symlinks
copy_lib() {
    local lib="$1"
    local dest="$2"
    
    if [ ! -f "$lib" ]; then
        return
    fi
    
    # Get the real file (resolve symlinks)
    local reallib=$(readlink -f "$lib")
    local basename=$(basename "$reallib")
    
    # Copy the real file if not already copied
    if [ ! -f "$dest/$basename" ]; then
        cp -a "$reallib" "$dest/"
        echo "  Copied: $basename"
    fi
    
    # Copy symlinks
    local libname=$(basename "$lib")
    if [ "$libname" != "$basename" ] && [ ! -e "$dest/$libname" ]; then
        ln -sf "$basename" "$dest/$libname"
    fi
}

# Function to collect dependencies for a binary
collect_deps() {
    local binary="$1"
    local dest="$2"
    
    echo "Analyzing: $binary"
    
    # Get all dependencies
    ldd "$binary" 2>/dev/null | while read -r line; do
        # Parse ldd output: libname.so => /path/to/lib (address)
        if [[ "$line" =~ "=>" ]]; then
            local lib=$(echo "$line" | awk '{print $3}')
            if [ -f "$lib" ]; then
                if ! should_exclude "$lib"; then
                    copy_lib "$lib" "$dest"
                fi
            fi
        fi
    done
}

echo "Step 1: Collecting dependencies for executables..."
echo ""

# Collect dependencies for main executables
collect_deps "src/interface/.libs/tabftp" "$OUTPUT_DIR/lib"
collect_deps "src/putty/fzsftp" "$OUTPUT_DIR/lib"
collect_deps "src/putty/fzputtygen" "$OUTPUT_DIR/lib"

# Also collect dependencies for our private libraries
echo ""
echo "Step 2: Collecting dependencies for private libraries..."
collect_deps "src/engine/.libs/libfzclient-private-3.69.5.so" "$OUTPUT_DIR/lib"
collect_deps "src/commonui/.libs/libfzclient-commonui-private-3.69.5.so" "$OUTPUT_DIR/lib"

echo ""
echo "Step 3: Copying private libraries..."
cp -a src/engine/.libs/libfzclient-private*.so* "$OUTPUT_DIR/lib/"
cp -a src/commonui/.libs/libfzclient-commonui-private*.so* "$OUTPUT_DIR/lib/"
echo "  Copied private libraries"

echo ""
echo "Step 4: Copying dynamic linker (ld-linux)..."
# Copy the dynamic linker for self-contained execution
if [ -f /lib64/ld-linux-x86-64.so.2 ]; then
    cp /lib64/ld-linux-x86-64.so.2 "$OUTPUT_DIR/lib/"
    echo "  Copied ld-linux-x86-64.so.2"
elif [ -f /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 ]; then
    cp /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 "$OUTPUT_DIR/lib/"
    echo "  Copied ld-linux-x86-64.so.2"
fi

echo ""
echo "Step 5: Copying gdk-pixbuf loaders..."
# Find and copy gdk-pixbuf loaders
GDK_PIXBUF_LOADERS=""
for dir in /usr/lib/x86_64-linux-gnu/gdk-pixbuf-2.0 /usr/lib64/gdk-pixbuf-2.0 /usr/lib/gdk-pixbuf-2.0; do
    if [ -d "$dir" ]; then
        GDK_PIXBUF_LOADERS="$dir"
        break
    fi
done

if [ -n "$GDK_PIXBUF_LOADERS" ]; then
    find "$GDK_PIXBUF_LOADERS" -name "libpixbufloader-*.so" -exec cp {} "$OUTPUT_DIR/lib/gdk-pixbuf-2.0/loaders/" \;
    echo "  Copied pixbuf loaders"
    
    # Collect dependencies for pixbuf loaders
    for loader in "$OUTPUT_DIR/lib/gdk-pixbuf-2.0/loaders"/*.so; do
        if [ -f "$loader" ]; then
            collect_deps "$loader" "$OUTPUT_DIR/lib"
        fi
    done
    
    # Create loaders.cache template
    CACHE_FILE=$(find "$GDK_PIXBUF_LOADERS" -name "loaders.cache" 2>/dev/null | head -1)
    if [ -f "$CACHE_FILE" ]; then
        sed -E 's|"(/usr/lib[^"]*/gdk-pixbuf-2.0/[^"]*/loaders)/|"@GDK_PIXBUF_MODULEDIR@/|g' \
            "$CACHE_FILE" > "$OUTPUT_DIR/lib/gdk-pixbuf-2.0/loaders/loaders.cache.in"
        echo "  Created loaders.cache.in template"
    fi
fi

echo ""
echo "Step 6: Copying glib schemas..."
if [ -d /usr/share/glib-2.0/schemas ]; then
    cp /usr/share/glib-2.0/schemas/gschemas.compiled "$OUTPUT_DIR/share/glib-2.0/schemas/" 2>/dev/null || true
    # Also copy individual schema files for recompilation if needed
    cp /usr/share/glib-2.0/schemas/*.xml "$OUTPUT_DIR/share/glib-2.0/schemas/" 2>/dev/null || true
    echo "  Copied glib schemas"
fi

echo ""
echo "Step 7: Copying translation files..."
# Copy TabFTP translations
if [ -d locales ]; then
    for mo in locales/*.mo; do
        if [ -f "$mo" ]; then
            locale=$(basename "$mo" .mo)
            mkdir -p "$OUTPUT_DIR/share/locale/$locale/LC_MESSAGES"
            cp "$mo" "$OUTPUT_DIR/share/locale/$locale/LC_MESSAGES/tabftp.mo"
        fi
    done
    echo "  Copied TabFTP translations"
fi

# Copy libfilezilla translations
LFZ_PREFIX=$(pkg-config --variable=prefix libfilezilla 2>/dev/null || echo "/usr")
if [ -d "$LFZ_PREFIX/share/locale" ]; then
    for mo in "$LFZ_PREFIX"/share/locale/*/LC_MESSAGES/libfilezilla.mo; do
        if [ -f "$mo" ]; then
            locale=$(echo "$mo" | sed 's/.*\/\([^\/]*\)\/LC_MESSAGES\/libfilezilla.mo/\1/')
            mkdir -p "$OUTPUT_DIR/share/locale/$locale/LC_MESSAGES"
            cp "$mo" "$OUTPUT_DIR/share/locale/$locale/LC_MESSAGES/libfilezilla.mo"
        fi
    done
    echo "  Copied libfilezilla translations"
fi

echo ""
echo "=== Dependency Bundling Complete ==="
echo ""
echo "Output directory: $OUTPUT_DIR"
echo ""
echo "Contents:"
echo "  Libraries: $(find "$OUTPUT_DIR/lib" -name "*.so*" -type f | wc -l) files"
echo "  Pixbuf loaders: $(find "$OUTPUT_DIR/lib/gdk-pixbuf-2.0" -name "*.so" | wc -l) files"
echo "  Translations: $(find "$OUTPUT_DIR/share/locale" -name "*.mo" | wc -l) files"
echo ""
echo "Total size: $(du -sh "$OUTPUT_DIR" | cut -f1)"
