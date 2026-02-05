#!/bin/bash
# TabFTP - Build DEB Package (Full Dependencies)
# This script creates a Debian/Ubuntu package with all dependencies bundled

set -e

echo "=== TabFTP: Building DEB Package (Full) ==="
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Get version from configure.ac
VERSION=$(grep "AC_INIT" configure.ac | sed -n 's/.*\[TabFTP\],\[\([0-9.]*\)\].*/\1/p')
ARCH="amd64"
PACKAGE_NAME="tabftp_${VERSION}_${ARCH}"

echo "Version: $VERSION"
echo "Architecture: $ARCH"
echo "Package: $PACKAGE_NAME"

# Output directories
DEB_ROOT=".packaging/deb-root"
OUTPUT_DIR="dist"

# Clean and create directories
rm -rf "$DEB_ROOT"
mkdir -p "$DEB_ROOT/DEBIAN"
mkdir -p "$DEB_ROOT/opt/tabftp/bin"
mkdir -p "$DEB_ROOT/opt/tabftp/lib"
mkdir -p "$DEB_ROOT/opt/tabftp/lib/gdk-pixbuf-2.0/loaders"
mkdir -p "$DEB_ROOT/opt/tabftp/share/tabftp"
mkdir -p "$DEB_ROOT/opt/tabftp/share/glib-2.0/schemas"
mkdir -p "$DEB_ROOT/opt/tabftp/share/locale"
mkdir -p "$DEB_ROOT/usr/bin"
mkdir -p "$DEB_ROOT/usr/share/applications"
mkdir -p "$DEB_ROOT/usr/share/icons/hicolor/48x48/apps"
mkdir -p "$DEB_ROOT/usr/share/icons/hicolor/scalable/apps"
mkdir -p "$OUTPUT_DIR"

echo ""
echo "Step 1: Copying executables..."
cp src/interface/.libs/tabftp "$DEB_ROOT/opt/tabftp/bin/"
cp src/putty/fzsftp "$DEB_ROOT/opt/tabftp/bin/"
cp src/putty/fzputtygen "$DEB_ROOT/opt/tabftp/bin/"

# Rename the main binary so /opt/tabftp/bin/tabftp can be a wrapper as well
mv "$DEB_ROOT/opt/tabftp/bin/tabftp" "$DEB_ROOT/opt/tabftp/bin/tabftp.bin"

# Strip debug symbols
strip --strip-all "$DEB_ROOT/opt/tabftp/bin/tabftp.bin" 2>/dev/null || true
strip --strip-all "$DEB_ROOT/opt/tabftp/bin/fzsftp" 2>/dev/null || true
strip --strip-all "$DEB_ROOT/opt/tabftp/bin/fzputtygen" 2>/dev/null || true

echo "  Copied and stripped executables"

echo ""
echo "Step 2: Copying private libraries..."
cp -a src/engine/.libs/libfzclient-private*.so* "$DEB_ROOT/opt/tabftp/lib/"
cp -a src/commonui/.libs/libfzclient-commonui-private*.so* "$DEB_ROOT/opt/tabftp/lib/"
# Strip libraries
for lib in "$DEB_ROOT/opt/tabftp/lib"/*.so*; do
    if [ -f "$lib" ] && [ ! -L "$lib" ]; then
        strip --strip-unneeded "$lib" 2>/dev/null || true
    fi
done
echo "  Copied and stripped private libraries"

echo ""
echo "Step 3: Copying resources..."
cp -a src/interface/resources "$DEB_ROOT/opt/tabftp/share/tabftp/"
echo "  Copied resources"

echo ""
echo "Step 4: Collecting dependencies..."

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

# Function to copy library with symlinks
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

# Helper to copy libs recursively
# Usage: copy_libs_recursive binary_or_lib destination
copy_libs_recursive() {
    local target="$1"
    local dest="$2"
    
    # Use ldd to find dependencies
    # We want EVERYTHING that resolves to an absolute path
    ldd "$target" 2>/dev/null | grep "=> /" | awk '{print $3}' | while read -r lib; do
        if [ -f "$lib" ]; then
            # Check if we already have it in destination
            # We check against reallib basename to avoid duplicates
            local reallib=$(readlink -f "$lib")
            local basename=$(basename "$reallib")

            if [ ! -f "$dest/$basename" ]; then
                # Copy it
                copy_lib "$lib" "$dest"
                # Recurse!
                copy_libs_recursive "$lib" "$dest"
            fi
        fi
    done
}

echo "  Collecting dependencies recursively for binaries..."
for bin in "$DEB_ROOT/opt/tabftp/bin"/*; do
    echo "    Scanning $bin..."
    copy_libs_recursive "$bin" "$DEB_ROOT/opt/tabftp/lib"
done

echo "  Collecting dependencies recursively for private libs..."
for lib in "$DEB_ROOT/opt/tabftp/lib"/libfzclient*.so*; do
    if [ -f "$lib" ] && [ ! -L "$lib" ]; then
        echo "    Scanning $lib..."
        copy_libs_recursive "$lib" "$DEB_ROOT/opt/tabftp/lib"
    fi
done

echo "  Collected all dependencies"

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
            copy_lib "$NSS_DIR/$nss" "$DEB_ROOT/opt/tabftp/lib"
            copy_libs_recursive "$NSS_DIR/$nss" "$DEB_ROOT/opt/tabftp/lib"
        fi
    done
fi
echo "  Copied NSS modules"

echo ""
echo "Step 5: Copying dynamic linker..."
if [ -f /lib64/ld-linux-x86-64.so.2 ]; then
    cp -a "$(readlink -f /lib64/ld-linux-x86-64.so.2)" "$DEB_ROOT/opt/tabftp/lib/ld-linux-x86-64.so.2"
elif [ -f /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 ]; then
    cp -a "$(readlink -f /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2)" "$DEB_ROOT/opt/tabftp/lib/ld-linux-x86-64.so.2"
fi
echo "  Copied ld-linux"

echo ""
echo "Step 5.5: Patching RPATH for direct execution..."
if command -v patchelf &>/dev/null; then
    for bin in "$DEB_ROOT/opt/tabftp/bin"/*.bin "$DEB_ROOT/opt/tabftp/bin"/fzsftp "$DEB_ROOT/opt/tabftp/bin"/fzputtygen; do
        if [ -f "$bin" ]; then
            patchelf --force-rpath --set-rpath '$ORIGIN/../lib' "$bin" 2>/dev/null || true
        fi
    done

    for so in "$DEB_ROOT/opt/tabftp/lib"/*.so*; do
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
    find "$GDK_PIXBUF_DIR" -name "libpixbufloader-*.so" -exec cp {} "$DEB_ROOT/opt/tabftp/lib/gdk-pixbuf-2.0/loaders/" \;
    
    # Also collect dependencies for loaders!
    for loader in "$DEB_ROOT/opt/tabftp/lib/gdk-pixbuf-2.0/loaders"/*.so; do
        if [ -f "$loader" ]; then
            copy_libs_recursive "$loader" "$DEB_ROOT/opt/tabftp/lib"
        fi
    done
    
    CACHE_FILE=$(find "$GDK_PIXBUF_DIR" -name "loaders.cache" 2>/dev/null | head -1)
    if [ -f "$CACHE_FILE" ]; then
        sed -E 's|"(/usr/lib[^"]*/gdk-pixbuf-2.0/[^"]*/loaders)/|"@GDK_PIXBUF_MODULEDIR@/|g' \
            "$CACHE_FILE" > "$DEB_ROOT/opt/tabftp/lib/gdk-pixbuf-2.0/loaders/loaders.cache.in"
    fi
fi
echo "  Copied pixbuf loaders"

echo ""
echo "Step 7: Copying glib schemas..."
if [ -d /usr/share/glib-2.0/schemas ]; then
    cp /usr/share/glib-2.0/schemas/gschemas.compiled "$DEB_ROOT/opt/tabftp/share/glib-2.0/schemas/" 2>/dev/null || true
fi
echo "  Copied glib schemas"

echo ""
echo "Step 8: Copying translations..."
# Copy to FZ_DATADIR/locales/ path (primary location checked by program)
mkdir -p "$DEB_ROOT/opt/tabftp/share/tabftp/locales"
if [ -d locales ]; then
    for mo in locales/*.mo; do
        if [ -f "$mo" ]; then
            locale=$(basename "$mo" .mo)
            mkdir -p "$DEB_ROOT/opt/tabftp/share/tabftp/locales/$locale"
            cp "$mo" "$DEB_ROOT/opt/tabftp/share/tabftp/locales/$locale/tabftp.mo"
        fi
    done
fi

# Also copy libfilezilla translations
LFZ_PREFIX=$(pkg-config --variable=prefix libfilezilla 2>/dev/null || echo "/usr")
if [ -d "$LFZ_PREFIX/share/locale" ]; then
    for mo in "$LFZ_PREFIX"/share/locale/*/LC_MESSAGES/libfilezilla.mo; do
        if [ -f "$mo" ]; then
            locale=$(echo "$mo" | sed 's/.*\/\([^\/]*\)\/LC_MESSAGES\/libfilezilla.mo/\1/')
            mkdir -p "$DEB_ROOT/opt/tabftp/share/tabftp/locales/$locale"
            cp "$mo" "$DEB_ROOT/opt/tabftp/share/tabftp/locales/$locale/libfilezilla.mo"
        fi
    done
fi

# Also copy to share/locale for fallback (secondary location)
mkdir -p "$DEB_ROOT/opt/tabftp/share/locale"
if [ -d locales ]; then
    for mo in locales/*.mo; do
        if [ -f "$mo" ]; then
            locale=$(basename "$mo" .mo)
            mkdir -p "$DEB_ROOT/opt/tabftp/share/locale/$locale/LC_MESSAGES"
            cp "$mo" "$DEB_ROOT/opt/tabftp/share/locale/$locale/LC_MESSAGES/tabftp.mo"
        fi
    done
fi
if [ -d "$LFZ_PREFIX/share/locale" ]; then
    for mo in "$LFZ_PREFIX"/share/locale/*/LC_MESSAGES/libfilezilla.mo; do
        if [ -f "$mo" ]; then
            locale=$(echo "$mo" | sed 's/.*\/\([^\/]*\)\/LC_MESSAGES\/libfilezilla.mo/\1/')
            mkdir -p "$DEB_ROOT/opt/tabftp/share/locale/$locale/LC_MESSAGES"
            cp "$mo" "$DEB_ROOT/opt/tabftp/share/locale/$locale/LC_MESSAGES/libfilezilla.mo"
        fi
    done
fi
echo "  Copied translations"

echo ""
echo "Step 9: Creating launcher script..."

# Create launcher script
cat > "$DEB_ROOT/usr/bin/tabftp" << 'LAUNCHER_EOF'
#!/bin/bash
INSTALL_DIR="/opt/tabftp"
EXEC="$INSTALL_DIR/bin/tabftp.bin"
FZSFTP_BIN="$INSTALL_DIR/bin/fzsftp"
FZPUTTYGEN_BIN="$INSTALL_DIR/bin/fzputtygen"
LINKER="$INSTALL_DIR/lib/ld-linux-x86-64.so.2"

GDK_PIXBUF_MODULEDIR="$INSTALL_DIR/lib/gdk-pixbuf-2.0/loaders"
GDK_PIXBUF_TEMPLATE="$GDK_PIXBUF_MODULEDIR/loaders.cache.in"

# Setup runtime cache directory (using system commands, no LD_LIBRARY_PATH)
cache_base="${XDG_CACHE_HOME:-$HOME/.cache}"
if [ -n "${cache_base:-}" ]; then
    RUNTIME_CACHE_DIR="$cache_base/tabftp"
    /bin/mkdir -p "$RUNTIME_CACHE_DIR" 2>/dev/null || RUNTIME_CACHE_DIR="/tmp/tabftp-$$"
    /bin/mkdir -p "$RUNTIME_CACHE_DIR" 2>/dev/null
else
    RUNTIME_CACHE_DIR="/tmp/tabftp-$$"
    /bin/mkdir -p "$RUNTIME_CACHE_DIR" 2>/dev/null
fi

# Setup gdk-pixbuf cache
GDK_PIXBUF_MODULE_FILE=""
if [ -f "$GDK_PIXBUF_TEMPLATE" ]; then
    GDK_PIXBUF_CACHE_FILE="$RUNTIME_CACHE_DIR/gdk-pixbuf-loaders.cache"
    /bin/sed "s|@GDK_PIXBUF_MODULEDIR@|$GDK_PIXBUF_MODULEDIR|g" "$GDK_PIXBUF_TEMPLATE" > "$GDK_PIXBUF_CACHE_FILE" 2>/dev/null
    GDK_PIXBUF_MODULE_FILE="$GDK_PIXBUF_CACHE_FILE"
fi

RUNNER=("$EXEC")
if [ -x "$LINKER" ]; then
    RUNNER=("$LINKER" --library-path "$INSTALL_DIR/lib" "$EXEC")
fi

# Execute TabFTP
exec /usr/bin/env \
    FZ_DATADIR="$INSTALL_DIR/share/tabftp" \
    FZ_FZSFTP="$FZSFTP_BIN" \
    FZ_FZPUTTYGEN="$FZPUTTYGEN_BIN" \
    XDG_DATA_DIRS="$INSTALL_DIR/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" \
    GSETTINGS_SCHEMA_DIR="$INSTALL_DIR/share/glib-2.0/schemas" \
    GDK_PIXBUF_MODULEDIR="$GDK_PIXBUF_MODULEDIR" \
    GDK_PIXBUF_MODULE_FILE="$GDK_PIXBUF_MODULE_FILE" \
    "${RUNNER[@]}" "$@"
LAUNCHER_EOF
chmod +x "$DEB_ROOT/usr/bin/tabftp"
echo "  Created launcher script"

cat > "$DEB_ROOT/opt/tabftp/bin/tabftp" << 'LAUNCHER2_EOF'
#!/bin/bash
exec /usr/bin/tabftp "$@"
LAUNCHER2_EOF
chmod +x "$DEB_ROOT/opt/tabftp/bin/tabftp"

echo ""
echo "Step 10: Creating desktop file and icons..."
# Copy app icon
mkdir -p "$DEB_ROOT/usr/share/icons/hicolor/48x48/apps"
if [ -f src/interface/resources/appicon.png ]; then
    cp src/interface/resources/appicon.png "$DEB_ROOT/usr/share/icons/hicolor/48x48/apps/tabftp.png"
elif [ -f src/interface/resources/48x48/tabftp.png ]; then
    cp src/interface/resources/48x48/tabftp.png "$DEB_ROOT/usr/share/icons/hicolor/48x48/apps/tabftp.png"
elif [ -f src/interface/resources/default/48x48/tabftp.png ]; then
    cp src/interface/resources/default/48x48/tabftp.png "$DEB_ROOT/usr/share/icons/hicolor/48x48/apps/tabftp.png"
fi

cat > "$DEB_ROOT/usr/share/applications/tabftp.desktop" << 'DESKTOP_EOF'
[Desktop Entry]
Name=TabFTP
GenericName=FTP Client
Comment=Transfer files via FTP, FTPS, and SFTP
TryExec=/usr/bin/tabftp
Exec=/usr/bin/tabftp
Icon=tabftp
Terminal=false
Type=Application
Categories=Network;FileTransfer;
Keywords=ftp;sftp;ftps;transfer;
StartupNotify=true
X-Deepin-AppID=tabftp
X-AppInstall-Package=tabftp
DESKTOP_EOF

if [ -f src/interface/resources/48x48/tabftp.png ]; then
    cp src/interface/resources/48x48/tabftp.png "$DEB_ROOT/usr/share/icons/hicolor/48x48/apps/"
elif [ -f src/interface/resources/default/48x48/tabftp.png ]; then
    cp src/interface/resources/default/48x48/tabftp.png "$DEB_ROOT/usr/share/icons/hicolor/48x48/apps/"
fi
echo "  Created desktop file and icons"

echo ""
echo "Step 11: Creating DEBIAN control files..."

# Calculate installed size
INSTALLED_SIZE=$(du -sk "$DEB_ROOT" | cut -f1)

cat > "$DEB_ROOT/DEBIAN/control" << CONTROL_EOF
Package: tabftp
Version: $VERSION
Section: net
Priority: optional
Architecture: $ARCH
Installed-Size: $INSTALLED_SIZE
Maintainer: TabFTP Team <support@tabftp.org>
Depends: bash
Description: TabFTP - FTP/SFTP Client
 TabFTP is a graphical FTP, FTPS and SFTP client.
 It provides a user-friendly interface for transferring
 files between your computer and remote servers.
Homepage: https://tabftp.org
CONTROL_EOF

cat > "$DEB_ROOT/DEBIAN/postinst" << 'POSTINST_EOF'
#!/bin/bash
set -e
maybe_remove_orphan_tabftp_desktop() {
    local f="$1"
    [ -f "$f" ] || return 0

    local owner=""
    owner="$(dpkg-query -S "$f" 2>/dev/null | head -n 1 | cut -d: -f1 || true)"
    if [ -n "$owner" ] && [ "$owner" != "tabftp" ]; then
        return 0
    fi

    if grep -q '^Name=TabFTP$' "$f" 2>/dev/null && grep -q '^Icon=tabftp$' "$f" 2>/dev/null; then
        if grep -q '^Exec=tabftp' "$f" 2>/dev/null || grep -q '^Exec=/usr/bin/tabftp' "$f" 2>/dev/null; then
            rm -f "$f" 2>/dev/null || true
        fi
    fi
}

maybe_remove_orphan_tabftp_desktop /usr/local/share/applications/tabftp.desktop
maybe_remove_orphan_tabftp_desktop /usr/local/share/applications/TabFTP.desktop

# Update icon cache
if command -v gtk-update-icon-cache &>/dev/null; then
    gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
fi
# Update desktop database
if command -v update-desktop-database &>/dev/null; then
    update-desktop-database /usr/share/applications 2>/dev/null || true
fi
exit 0
POSTINST_EOF
chmod 755 "$DEB_ROOT/DEBIAN/postinst"

cat > "$DEB_ROOT/DEBIAN/postrm" << 'POSTRM_EOF'
#!/bin/bash
set -e

if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
    maybe_remove_orphan_tabftp_desktop() {
        local f="$1"
        [ -f "$f" ] || return 0

        local owner=""
        owner="$(dpkg-query -S "$f" 2>/dev/null | head -n 1 | cut -d: -f1 || true)"
        if [ -n "$owner" ] && [ "$owner" != "tabftp" ]; then
            return 0
        fi

        if grep -q '^Name=TabFTP$' "$f" 2>/dev/null && grep -q '^Icon=tabftp$' "$f" 2>/dev/null; then
            if grep -q '^Exec=tabftp' "$f" 2>/dev/null || grep -q '^Exec=/usr/bin/tabftp' "$f" 2>/dev/null; then
                rm -f "$f" 2>/dev/null || true
            fi
        fi
    }

    maybe_remove_orphan_tabftp_desktop /usr/local/share/applications/tabftp.desktop
    maybe_remove_orphan_tabftp_desktop /usr/local/share/applications/TabFTP.desktop

    # Update icon cache
    if command -v gtk-update-icon-cache &>/dev/null; then
        gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
    fi
    # Update desktop database
    if command -v update-desktop-database &>/dev/null; then
        update-desktop-database /usr/share/applications 2>/dev/null || true
    fi
fi

exit 0
POSTRM_EOF
chmod 755 "$DEB_ROOT/DEBIAN/postrm"

echo "  Created control files"

echo ""
echo "Step 12: Building DEB package..."
dpkg-deb --build "$DEB_ROOT" "$OUTPUT_DIR/$PACKAGE_NAME.deb"

echo ""
echo "=== DEB Package Build Complete ==="
echo ""
echo "Output: $OUTPUT_DIR/$PACKAGE_NAME.deb"
ls -lh "$OUTPUT_DIR/$PACKAGE_NAME.deb"
