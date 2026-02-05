#!/bin/bash
# TabFTP - Build RPM Package from existing DEB structure

set -e

echo "=== TabFTP: Building RPM Package ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VERSION=$(grep "AC_INIT" configure.ac | sed -n 's/.*\[TabFTP\],\[\([0-9.]*\)\].*/\1/p')
RELEASE="6"
ARCH="x86_64"

echo "Version: $VERSION"
echo "Release: $RELEASE"

OUTPUT_DIR="dist"
RPM_TOPDIR="$SCRIPT_DIR/.packaging/rpmbuild"
DEB_ROOT="$SCRIPT_DIR/.packaging/deb-root"

mkdir -p "$OUTPUT_DIR"

if [ ! -d "$DEB_ROOT/opt/tabftp" ]; then
    echo "DEB structure not found. Building DEB first..."
    ./build_deb.sh
fi

rm -rf "$RPM_TOPDIR"
mkdir -p "$RPM_TOPDIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

echo "Creating spec file..."

CHANGELOG_DATE=$(LC_ALL=C date "+%a %b %d %Y")

cat > "$RPM_TOPDIR/SPECS/tabftp.spec" << 'SPEC_EOF'
Name:           tabftp
Version:        %{rpm_version}
Release:        %{rpm_release}%{?dist}
Summary:        TabFTP - FTP/SFTP Client

License:        GPL-2.0
URL:            https://tabftp.org

AutoReqProv:    no
Requires:       bash

%define __strip /bin/true
%define debug_package %{nil}

%description
TabFTP is a graphical FTP, FTPS and SFTP client.
All dependencies are bundled for maximum compatibility.

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
cp -a %{deb_root}/opt %{buildroot}/
cp -a %{deb_root}/usr %{buildroot}/

cat > %{buildroot}/usr/bin/tabftp << 'TABFTP_LAUNCHER_EOF'
#!/bin/bash

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
SELF_DIR="$(cd "$(dirname "$SELF")" && pwd)"
ROOT="$(readlink -f "$SELF_DIR/../..")"
ROOT="${ROOT%/}"
if [ -z "$ROOT" ]; then
    ROOT="/"
fi

INSTALL_DIR=""
candidate="$ROOT/opt/tabftp"
candidate="/${candidate##/}"
if [ -x "$candidate/bin/tabftp.bin" ]; then
    INSTALL_DIR="$candidate"
elif [ -x "/opt/tabftp/bin/tabftp.bin" ]; then
    INSTALL_DIR="/opt/tabftp"
fi

if [ -z "$INSTALL_DIR" ]; then
    echo "TabFTP install directory not found" 1>&2
    exit 1
fi
INSTALL_DIR="$(readlink -f "$INSTALL_DIR")"
INSTALL_DIR="/${INSTALL_DIR##/}"

EXEC="$INSTALL_DIR/bin/tabftp.bin"
FZSFTP_BIN="$INSTALL_DIR/bin/fzsftp"
FZPUTTYGEN_BIN="$INSTALL_DIR/bin/fzputtygen"
LINKER="$INSTALL_DIR/lib/ld-linux-x86-64.so.2"

DATA_DIR=""
for d in \
    "$INSTALL_DIR/share/tabftp" \
    "$INSTALL_DIR/share/filezilla" \
    "$INSTALL_DIR/usr/share/tabftp" \
    "$INSTALL_DIR/usr/share/filezilla" \
    "/usr/share/tabftp" \
    "/usr/share/filezilla" \
    "$INSTALL_DIR/share"; do
    if [ -f "$d/resources/defaultfilters.xml" ]; then
        DATA_DIR="$d"
        break
    fi
done

if [ -z "$DATA_DIR" ]; then
    if command -v find >/dev/null 2>&1; then
        match="$(find "$INSTALL_DIR" -maxdepth 7 -type f -path "*/resources/defaultfilters.xml" 2>/dev/null | head -n 1)"
    else
        match=""
    fi
    if [ -n "${match:-}" ] && command -v dirname >/dev/null 2>&1; then
        DATA_DIR="$(dirname "$(dirname "$match")")"
    fi
fi

if [ -z "$DATA_DIR" ]; then
    echo "TabFTP resource files not found under: $INSTALL_DIR" 1>&2
    echo "Tried:" 1>&2
    echo "  - $INSTALL_DIR/share/tabftp/resources/defaultfilters.xml" 1>&2
    echo "  - $INSTALL_DIR/share/filezilla/resources/defaultfilters.xml" 1>&2
    exit 1
fi

GDK_PIXBUF_MODULEDIR="$INSTALL_DIR/lib/gdk-pixbuf-2.0/loaders"
GDK_PIXBUF_TEMPLATE="$GDK_PIXBUF_MODULEDIR/loaders.cache.in"

cache_base="${XDG_CACHE_HOME:-$HOME/.cache}"
if [ -n "${cache_base:-}" ]; then
    RUNTIME_CACHE_DIR="$cache_base/tabftp"
    mkdir -p "$RUNTIME_CACHE_DIR" 2>/dev/null || RUNTIME_CACHE_DIR="/tmp/tabftp-$$"
    mkdir -p "$RUNTIME_CACHE_DIR" 2>/dev/null
else
    RUNTIME_CACHE_DIR="/tmp/tabftp-$$"
    mkdir -p "$RUNTIME_CACHE_DIR" 2>/dev/null
fi

GDK_PIXBUF_MODULE_FILE=""
if [ -f "$GDK_PIXBUF_TEMPLATE" ]; then
    GDK_PIXBUF_CACHE_FILE="$RUNTIME_CACHE_DIR/gdk-pixbuf-loaders.cache"
    sed "s|@GDK_PIXBUF_MODULEDIR@|$GDK_PIXBUF_MODULEDIR|g" "$GDK_PIXBUF_TEMPLATE" > "$GDK_PIXBUF_CACHE_FILE" 2>/dev/null
    GDK_PIXBUF_MODULE_FILE="$GDK_PIXBUF_CACHE_FILE"
fi

RUNNER=("$EXEC")
if [ -x "$LINKER" ]; then
    RUNNER=("$LINKER" --library-path "$INSTALL_DIR/lib" "$EXEC")
fi

exec /usr/bin/env \
    FZ_DATADIR="$DATA_DIR" \
    FZ_FZSFTP="$FZSFTP_BIN" \
    FZ_FZPUTTYGEN="$FZPUTTYGEN_BIN" \
    XDG_DATA_DIRS="$INSTALL_DIR/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" \
    GSETTINGS_SCHEMA_DIR="$INSTALL_DIR/share/glib-2.0/schemas" \
    GDK_PIXBUF_MODULEDIR="$GDK_PIXBUF_MODULEDIR" \
    GDK_PIXBUF_MODULE_FILE="$GDK_PIXBUF_MODULE_FILE" \
    "${RUNNER[@]}" "$@"
TABFTP_LAUNCHER_EOF
chmod 755 %{buildroot}/usr/bin/tabftp

cat > %{buildroot}/opt/tabftp/bin/tabftp << 'TABFTP_OPT_LAUNCHER_EOF'
#!/bin/bash
SELF="$(readlink -f "${BASH_SOURCE[0]}")"
SELF_DIR="$(cd "$(dirname "$SELF")" && pwd)"
ROOT="$(readlink -f "$SELF_DIR/../../..")"
if [ -x "$ROOT/usr/bin/tabftp" ]; then
    exec "$ROOT/usr/bin/tabftp" "$@"
fi
exec /usr/bin/tabftp "$@"
TABFTP_OPT_LAUNCHER_EOF
chmod 755 %{buildroot}/opt/tabftp/bin/tabftp

%post
gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
update-desktop-database /usr/share/applications 2>/dev/null || true

%postun
gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
update-desktop-database /usr/share/applications 2>/dev/null || true

%files
%defattr(-,root,root,-)
/opt/tabftp
/usr/bin/tabftp
/usr/share/applications/tabftp.desktop
/usr/share/icons/hicolor/48x48/apps/tabftp.png
SPEC_EOF

echo "Building RPM..."
rpmbuild --define "_topdir $RPM_TOPDIR" \
         --define "rpm_version $VERSION" \
         --define "rpm_release $RELEASE" \
         --define "deb_root $DEB_ROOT" \
         -bb "$RPM_TOPDIR/SPECS/tabftp.spec"

RPM_FILE=$(find "$RPM_TOPDIR/RPMS" -name "*.rpm" | head -1)
if [ -f "$RPM_FILE" ]; then
    cp "$RPM_FILE" "$OUTPUT_DIR/tabftp-${VERSION}-${RELEASE}.${ARCH}.rpm"
    echo ""
    echo "=== RPM Package Build Complete ==="
    echo "Output: $OUTPUT_DIR/tabftp-${VERSION}-${RELEASE}.${ARCH}.rpm"
    ls -lh "$OUTPUT_DIR/tabftp-${VERSION}-${RELEASE}.${ARCH}.rpm"
else
    echo "ERROR: RPM build failed"
    exit 1
fi
