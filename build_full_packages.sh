#!/bin/bash
# TabFTP - Build All Packages with Full Dependencies
# This script builds DEB, AppImage, and RPM packages with ALL dependencies bundled
# for maximum cross-distribution compatibility

set -e

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     TabFTP Full Package Builder (All Dependencies)          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VERSION=$(grep "AC_INIT" configure.ac | sed -n 's/.*\[TabFTP\],\[\([0-9.]*\)\].*/\1/p')
ARCH="x86_64"
OUTPUT_DIR="dist"
COMMON_DIR=".packaging/common"

echo "Version: $VERSION"
echo "Architecture: $ARCH"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

mkdir -p "$OUTPUT_DIR"
rm -rf "$COMMON_DIR"
mkdir -p "$COMMON_DIR/lib"
mkdir -p "$COMMON_DIR/lib/gdk-pixbuf-2.0/loaders"
mkdir -p "$COMMON_DIR/lib/gtk-3.0/modules"
mkdir -p "$COMMON_DIR/share/glib-2.0/schemas"
mkdir -p "$COMMON_DIR/share/tabftp/locales"
mkdir -p "$COMMON_DIR/share/locale"

# Minimal exclusion list - only truly kernel/system specific libs
EXCLUDE_LIBS=(
    "linux-vdso.so"
    "libnss_"
    "libnsl.so"
    "libresolv.so"
)

should_exclude() {
    local lib="$1"
    for exclude in "${EXCLUDE_LIBS[@]}"; do
        if [[ "$lib" == *"$exclude"* ]]; then
            return 0
        fi
    done
    return 1
}

copy_lib() {
    local lib="$1"
    local dest="$2"
    
    [ ! -f "$lib" ] && return
    
    local reallib=$(readlink -f "$lib")
    local basename=$(basename "$reallib")
    
    if [ ! -f "$dest/$basename" ]; then
        cp -a "$reallib" "$dest/"
        strip --strip-unneeded "$dest/$basename" 2>/dev/null || true
    fi
    
    local libname=$(basename "$lib")
    if [ "$libname" != "$basename" ] && [ ! -e "$dest/$libname" ]; then
        ln -sf "$basename" "$dest/$libname"
    fi
}

collect_deps() {
    local binary="$1"
    local dest="$2"
    
    ldd "$binary" 2>/dev/null | while read -r line; do
        if [[ "$line" =~ "=>" ]]; then
            local lib=$(echo "$line" | awk '{print $3}')
            if [ -f "$lib" ] && ! should_exclude "$lib"; then
                copy_lib "$lib" "$dest"
            fi
        fi
    done
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Building TabFTP..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ! -f configure ]; then
    autoreconf -i
fi
if [ ! -f Makefile ]; then
    ./configure
fi
make -j$(nproc)

if [ ! -f src/interface/.libs/tabftp ]; then
    echo "ERROR: Build failed!"
    exit 1
fi
echo "Build complete!"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Collecting ALL dependencies..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Copy executables
cp src/interface/.libs/tabftp "$COMMON_DIR/tabftp.bin"
cp src/putty/fzsftp "$COMMON_DIR/"
cp src/putty/fzputtygen "$COMMON_DIR/"
strip --strip-all "$COMMON_DIR/tabftp.bin" 2>/dev/null || true
strip --strip-all "$COMMON_DIR/fzsftp" 2>/dev/null || true
strip --strip-all "$COMMON_DIR/fzputtygen" 2>/dev/null || true

# Copy private libraries
cp -a src/engine/.libs/libfzclient-private*.so* "$COMMON_DIR/lib/"
cp -a src/commonui/.libs/libfzclient-commonui-private*.so* "$COMMON_DIR/lib/"

# Collect all dependencies
echo "Collecting dependencies for tabftp..."
collect_deps "src/interface/.libs/tabftp" "$COMMON_DIR/lib"
echo "Collecting dependencies for fzsftp..."
collect_deps "src/putty/fzsftp" "$COMMON_DIR/lib"
echo "Collecting dependencies for fzputtygen..."
collect_deps "src/putty/fzputtygen" "$COMMON_DIR/lib"

# Collect dependencies for private libraries
for lib in "$COMMON_DIR/lib"/libfzclient*.so*; do
    if [ -f "$lib" ] && [ ! -L "$lib" ]; then
        collect_deps "$lib" "$COMMON_DIR/lib"
    fi
done

# Recursively collect dependencies (some libs depend on other libs)
echo "Recursively collecting nested dependencies..."
for i in 1 2 3; do
    for lib in "$COMMON_DIR/lib"/*.so*; do
        if [ -f "$lib" ] && [ ! -L "$lib" ]; then
            collect_deps "$lib" "$COMMON_DIR/lib"
        fi
    done
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Copying GTK/GDK resources..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Copy gdk-pixbuf loaders
GDK_PIXBUF_DIR=""
for dir in /usr/lib/x86_64-linux-gnu/gdk-pixbuf-2.0 /usr/lib64/gdk-pixbuf-2.0 /usr/lib/gdk-pixbuf-2.0; do
    if [ -d "$dir" ]; then
        GDK_PIXBUF_DIR="$dir"
        break
    fi
done

if [ -n "$GDK_PIXBUF_DIR" ]; then
    echo "Copying pixbuf loaders from $GDK_PIXBUF_DIR..."
    find "$GDK_PIXBUF_DIR" -name "libpixbufloader-*.so" -exec cp {} "$COMMON_DIR/lib/gdk-pixbuf-2.0/loaders/" \;
    
    for loader in "$COMMON_DIR/lib/gdk-pixbuf-2.0/loaders"/*.so; do
        [ -f "$loader" ] && collect_deps "$loader" "$COMMON_DIR/lib"
    done
    
    CACHE_FILE=$(find "$GDK_PIXBUF_DIR" -name "loaders.cache" 2>/dev/null | head -1)
    if [ -f "$CACHE_FILE" ]; then
        sed -E 's|"(/usr/lib[^"]*/gdk-pixbuf-2.0/[^"]*/loaders)/|"@GDK_PIXBUF_MODULEDIR@/|g' \
            "$CACHE_FILE" > "$COMMON_DIR/lib/gdk-pixbuf-2.0/loaders/loaders.cache.in"
    fi
fi

# Copy glib schemas
echo "Copying glib schemas..."
if [ -d /usr/share/glib-2.0/schemas ]; then
    cp /usr/share/glib-2.0/schemas/gschemas.compiled "$COMMON_DIR/share/glib-2.0/schemas/" 2>/dev/null || true
fi

# Copy resources
echo "Copying resources..."
cp -a src/interface/resources "$COMMON_DIR/share/tabftp/"

# Copy translations
echo "Copying translations..."
if [ -d locales ]; then
    for mo in locales/*.mo; do
        if [ -f "$mo" ]; then
            locale=$(basename "$mo" .mo)
            mkdir -p "$COMMON_DIR/share/tabftp/locales/$locale"
            mkdir -p "$COMMON_DIR/share/locale/$locale/LC_MESSAGES"
            cp "$mo" "$COMMON_DIR/share/tabftp/locales/$locale/tabftp.mo"
            cp "$mo" "$COMMON_DIR/share/locale/$locale/LC_MESSAGES/tabftp.mo"
        fi
    done
fi

LFZ_PREFIX=$(pkg-config --variable=prefix libfilezilla 2>/dev/null || echo "/usr/local")
if [ -d "$LFZ_PREFIX/share/locale" ]; then
    for mo in "$LFZ_PREFIX"/share/locale/*/LC_MESSAGES/libfilezilla.mo; do
        if [ -f "$mo" ]; then
            locale=$(echo "$mo" | sed 's/.*\/\([^\/]*\)\/LC_MESSAGES\/libfilezilla.mo/\1/')
            mkdir -p "$COMMON_DIR/share/tabftp/locales/$locale"
            mkdir -p "$COMMON_DIR/share/locale/$locale/LC_MESSAGES"
            cp "$mo" "$COMMON_DIR/share/tabftp/locales/$locale/libfilezilla.mo"
            cp "$mo" "$COMMON_DIR/share/locale/$locale/LC_MESSAGES/libfilezilla.mo"
        fi
    done
fi

LIB_COUNT=$(find "$COMMON_DIR/lib" -name "*.so*" -type f | wc -l)
echo "Collected $LIB_COUNT library files"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4: Building AppImage..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

APPDIR=".packaging/AppDir"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/lib"
mkdir -p "$APPDIR/usr/share"

# Copy from common
cp "$COMMON_DIR/tabftp.bin" "$APPDIR/usr/bin/tabftp"
cp "$COMMON_DIR/fzsftp" "$APPDIR/usr/bin/"
cp "$COMMON_DIR/fzputtygen" "$APPDIR/usr/bin/"
cp -a "$COMMON_DIR/lib"/* "$APPDIR/usr/lib/"
cp -a "$COMMON_DIR/share"/* "$APPDIR/usr/share/"

# Create AppRun script using LD_LIBRARY_PATH
cat > "$APPDIR/AppRun" << 'APPRUN_EOF'
#!/bin/bash
THIS_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
EXEC="$THIS_DIR/usr/bin/tabftp"
GDK_PIXBUF_MODULEDIR="$THIS_DIR/usr/lib/gdk-pixbuf-2.0/loaders"
GDK_PIXBUF_TEMPLATE="$GDK_PIXBUF_MODULEDIR/loaders.cache.in"

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tabftp"
mkdir -p "$CACHE_DIR" 2>/dev/null || CACHE_DIR="/tmp/tabftp-$$"
mkdir -p "$CACHE_DIR" 2>/dev/null

GDK_PIXBUF_MODULE_FILE=""
if [ -f "$GDK_PIXBUF_TEMPLATE" ]; then
    GDK_PIXBUF_MODULE_FILE="$CACHE_DIR/loaders.cache"
    sed "s|@GDK_PIXBUF_MODULEDIR@|$GDK_PIXBUF_MODULEDIR|g" "$GDK_PIXBUF_TEMPLATE" > "$GDK_PIXBUF_MODULE_FILE"
fi

FZSFTP_W="$CACHE_DIR/fzsftp"
cat > "$FZSFTP_W" << EOF2
#!/bin/bash
export LD_LIBRARY_PATH="$THIS_DIR/usr/lib:\$LD_LIBRARY_PATH"
exec "$THIS_DIR/usr/bin/fzsftp" "\$@"
EOF2
chmod +x "$FZSFTP_W"

FZPUTTYGEN_W="$CACHE_DIR/fzputtygen"
cat > "$FZPUTTYGEN_W" << EOF2
#!/bin/bash
export LD_LIBRARY_PATH="$THIS_DIR/usr/lib:\$LD_LIBRARY_PATH"
exec "$THIS_DIR/usr/bin/fzputtygen" "\$@"
EOF2
chmod +x "$FZPUTTYGEN_W"

exec env \
    LD_LIBRARY_PATH="$THIS_DIR/usr/lib:$LD_LIBRARY_PATH" \
    FZ_DATADIR="$THIS_DIR/usr/share/tabftp" \
    FZ_FZSFTP="$FZSFTP_W" \
    FZ_FZPUTTYGEN="$FZPUTTYGEN_W" \
    XDG_DATA_DIRS="$THIS_DIR/usr/share:${XDG_DATA_DIRS:-/usr/share}" \
    GSETTINGS_SCHEMA_DIR="$THIS_DIR/usr/share/glib-2.0/schemas" \
    GDK_PIXBUF_MODULEDIR="$GDK_PIXBUF_MODULEDIR" \
    GDK_PIXBUF_MODULE_FILE="$GDK_PIXBUF_MODULE_FILE" \
    "$EXEC" "$@"
APPRUN_EOF
chmod +x "$APPDIR/AppRun"

# Desktop file and icon
cp data/tabftp.desktop "$APPDIR/"
if [ -f src/interface/resources/48x48/tabftp.png ]; then
    cp src/interface/resources/48x48/tabftp.png "$APPDIR/tabftp.png"
elif [ -f 图标/48x48.png ]; then
    cp 图标/48x48.png "$APPDIR/tabftp.png"
fi
ln -sf tabftp.png "$APPDIR/.DirIcon" 2>/dev/null || true

# Download appimagetool if needed
APPIMAGETOOL="./appimagetool-x86_64.AppImage"
if [ ! -f "$APPIMAGETOOL" ]; then
    echo "Downloading appimagetool..."
    wget -q "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage" -O "$APPIMAGETOOL"
    chmod +x "$APPIMAGETOOL"
fi

APPIMAGE_NAME="TabFTP-${VERSION}-x86_64.AppImage"
ARCH=x86_64 "$APPIMAGETOOL" "$APPDIR" "$OUTPUT_DIR/$APPIMAGE_NAME" 2>/dev/null || \
ARCH=x86_64 "$APPIMAGETOOL" --no-appstream "$APPDIR" "$OUTPUT_DIR/$APPIMAGE_NAME"
echo "AppImage created: $OUTPUT_DIR/$APPIMAGE_NAME"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5: Building DEB package..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

DEB_ROOT=".packaging/deb-root"
rm -rf "$DEB_ROOT"
mkdir -p "$DEB_ROOT/DEBIAN"
mkdir -p "$DEB_ROOT/opt/tabftp/bin"
mkdir -p "$DEB_ROOT/opt/tabftp/lib"
mkdir -p "$DEB_ROOT/opt/tabftp/share"
mkdir -p "$DEB_ROOT/usr/bin"
mkdir -p "$DEB_ROOT/usr/share/applications"
mkdir -p "$DEB_ROOT/usr/share/icons/hicolor/48x48/apps"

# Copy from common
cp "$COMMON_DIR/tabftp.bin" "$DEB_ROOT/opt/tabftp/bin/"
cp "$COMMON_DIR/fzsftp" "$DEB_ROOT/opt/tabftp/bin/"
cp "$COMMON_DIR/fzputtygen" "$DEB_ROOT/opt/tabftp/bin/"
cp -a "$COMMON_DIR/lib"/* "$DEB_ROOT/opt/tabftp/lib/"
cp -a "$COMMON_DIR/share"/* "$DEB_ROOT/opt/tabftp/share/"

# Launcher script - uses LD_LIBRARY_PATH for reliable library loading
cat > "$DEB_ROOT/usr/bin/tabftp" << 'LAUNCHER_EOF'
#!/bin/bash
INSTALL_DIR="/opt/tabftp"
EXEC="$INSTALL_DIR/bin/tabftp.bin"
GDK_PIXBUF_MODULEDIR="$INSTALL_DIR/lib/gdk-pixbuf-2.0/loaders"
GDK_PIXBUF_TEMPLATE="$GDK_PIXBUF_MODULEDIR/loaders.cache.in"

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tabftp"
mkdir -p "$CACHE_DIR" 2>/dev/null || CACHE_DIR="/tmp/tabftp-$$"
mkdir -p "$CACHE_DIR" 2>/dev/null

GDK_PIXBUF_MODULE_FILE=""
if [ -f "$GDK_PIXBUF_TEMPLATE" ]; then
    GDK_PIXBUF_MODULE_FILE="$CACHE_DIR/loaders.cache"
    sed "s|@GDK_PIXBUF_MODULEDIR@|$GDK_PIXBUF_MODULEDIR|g" "$GDK_PIXBUF_TEMPLATE" > "$GDK_PIXBUF_MODULE_FILE"
fi

FZSFTP_W="$CACHE_DIR/fzsftp"
cat > "$FZSFTP_W" << EOF2
#!/bin/bash
export LD_LIBRARY_PATH="$INSTALL_DIR/lib:\$LD_LIBRARY_PATH"
exec "$INSTALL_DIR/bin/fzsftp" "\$@"
EOF2
chmod +x "$FZSFTP_W"

FZPUTTYGEN_W="$CACHE_DIR/fzputtygen"
cat > "$FZPUTTYGEN_W" << EOF2
#!/bin/bash
export LD_LIBRARY_PATH="$INSTALL_DIR/lib:\$LD_LIBRARY_PATH"
exec "$INSTALL_DIR/bin/fzputtygen" "\$@"
EOF2
chmod +x "$FZPUTTYGEN_W"

exec env \
    LD_LIBRARY_PATH="$INSTALL_DIR/lib:$LD_LIBRARY_PATH" \
    FZ_DATADIR="$INSTALL_DIR/share/tabftp" \
    FZ_FZSFTP="$FZSFTP_W" \
    FZ_FZPUTTYGEN="$FZPUTTYGEN_W" \
    XDG_DATA_DIRS="$INSTALL_DIR/share:${XDG_DATA_DIRS:-/usr/share}" \
    GSETTINGS_SCHEMA_DIR="$INSTALL_DIR/share/glib-2.0/schemas" \
    GDK_PIXBUF_MODULEDIR="$GDK_PIXBUF_MODULEDIR" \
    GDK_PIXBUF_MODULE_FILE="$GDK_PIXBUF_MODULE_FILE" \
    "$EXEC" "$@"
LAUNCHER_EOF
chmod +x "$DEB_ROOT/usr/bin/tabftp"

# Desktop file and icon
cat > "$DEB_ROOT/usr/share/applications/tabftp.desktop" << 'DESKTOP_EOF'
[Desktop Entry]
Name=TabFTP
GenericName=FTP Client
Comment=Transfer files via FTP, FTPS, and SFTP
Exec=tabftp
Icon=tabftp
Terminal=false
Type=Application
Categories=Network;FileTransfer;
DESKTOP_EOF

if [ -f src/interface/resources/48x48/tabftp.png ]; then
    cp src/interface/resources/48x48/tabftp.png "$DEB_ROOT/usr/share/icons/hicolor/48x48/apps/"
elif [ -f 图标/48x48.png ]; then
    cp 图标/48x48.png "$DEB_ROOT/usr/share/icons/hicolor/48x48/apps/tabftp.png"
fi

INSTALLED_SIZE=$(du -sk "$DEB_ROOT" | cut -f1)
cat > "$DEB_ROOT/DEBIAN/control" << CONTROL_EOF
Package: tabftp
Version: $VERSION
Section: net
Priority: optional
Architecture: amd64
Installed-Size: $INSTALLED_SIZE
Maintainer: TabFTP Team <support@tabftp.org>
Depends: libc6, bash
Description: TabFTP - FTP/SFTP Client with bundled dependencies
 TabFTP is a graphical FTP, FTPS and SFTP client.
 All dependencies are bundled for maximum compatibility.
CONTROL_EOF

cat > "$DEB_ROOT/DEBIAN/postinst" << 'POSTINST_EOF'
#!/bin/bash
gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
update-desktop-database /usr/share/applications 2>/dev/null || true
exit 0
POSTINST_EOF
chmod 755 "$DEB_ROOT/DEBIAN/postinst"

dpkg-deb --build "$DEB_ROOT" "$OUTPUT_DIR/tabftp_${VERSION}_amd64.deb"
echo "DEB created: $OUTPUT_DIR/tabftp_${VERSION}_amd64.deb"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 6: Building RPM package..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v rpmbuild &>/dev/null; then
    RPM_TOPDIR=".packaging/rpmbuild"
    rm -rf "$RPM_TOPDIR"
    mkdir -p "$RPM_TOPDIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

    cat > "$RPM_TOPDIR/SPECS/tabftp.spec" << SPEC_EOF
Name:           tabftp
Version:        %{rpm_version}
Release:        1%{?dist}
Summary:        TabFTP - FTP/SFTP Client
License:        GPL-2.0
AutoReqProv:    no
Requires:       bash
%define __strip /bin/true
%define debug_package %{nil}

%description
TabFTP is a graphical FTP, FTPS and SFTP client with bundled dependencies.

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
cp -a %{deb_root}/opt %{buildroot}/
cp -a %{deb_root}/usr %{buildroot}/

%post
gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
update-desktop-database /usr/share/applications 2>/dev/null || true

%files
%defattr(-,root,root,-)
/opt/tabftp
/usr/bin/tabftp
/usr/share/applications/tabftp.desktop
/usr/share/icons/hicolor/48x48/apps/tabftp.png
SPEC_EOF

    rpmbuild --define "_topdir $SCRIPT_DIR/$RPM_TOPDIR" \
             --define "rpm_version $VERSION" \
             --define "deb_root $SCRIPT_DIR/$DEB_ROOT" \
             -bb "$RPM_TOPDIR/SPECS/tabftp.spec"

    RPM_FILE=$(find "$RPM_TOPDIR/RPMS" -name "*.rpm" | head -1)
    if [ -f "$RPM_FILE" ]; then
        cp "$RPM_FILE" "$OUTPUT_DIR/tabftp-${VERSION}-1.x86_64.rpm"
        echo "RPM created: $OUTPUT_DIR/tabftp-${VERSION}-1.x86_64.rpm"
    fi
else
    echo "rpmbuild not found, skipping RPM"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    Build Complete!                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Output files:"
ls -lh "$OUTPUT_DIR"/*.AppImage "$OUTPUT_DIR"/*.deb "$OUTPUT_DIR"/*.rpm 2>/dev/null || true
