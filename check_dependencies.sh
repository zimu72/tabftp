#!/bin/bash
# TabFTP - Check Build Dependencies
# This script checks for required build dependencies and provides installation instructions

set -e

echo "=== TabFTP: Checking Build Dependencies ==="
echo ""

# Detect distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        DISTRO_LIKE=$ID_LIKE
    elif [ -f /etc/debian_version ]; then
        DISTRO="debian"
    elif [ -f /etc/redhat-release ]; then
        DISTRO="rhel"
    else
        DISTRO="unknown"
    fi
}

detect_distro
echo "Detected distribution: $DISTRO"
echo ""

# Track missing dependencies
MISSING_DEPS=()
ALL_OK=true

# Function to check pkg-config module
check_pkg() {
    local pkg="$1"
    local min_version="$2"
    local description="$3"
    
    printf "Checking %-30s ... " "$description"
    
    if pkg-config --exists "$pkg" 2>/dev/null; then
        local version=$(pkg-config --modversion "$pkg" 2>/dev/null)
        if [ -n "$min_version" ]; then
            if pkg-config --atleast-version="$min_version" "$pkg" 2>/dev/null; then
                echo "OK ($version)"
                return 0
            else
                echo "OUTDATED ($version < $min_version)"
                MISSING_DEPS+=("$pkg >= $min_version")
                ALL_OK=false
                return 1
            fi
        else
            echo "OK ($version)"
            return 0
        fi
    else
        echo "NOT FOUND"
        if [ -n "$min_version" ]; then
            MISSING_DEPS+=("$pkg >= $min_version")
        else
            MISSING_DEPS+=("$pkg")
        fi
        ALL_OK=false
        return 1
    fi
}

# Function to check command exists
check_cmd() {
    local cmd="$1"
    local description="$2"
    
    printf "Checking %-30s ... " "$description"
    
    if command -v "$cmd" &>/dev/null; then
        echo "OK"
        return 0
    else
        echo "NOT FOUND"
        MISSING_DEPS+=("$cmd")
        ALL_OK=false
        return 1
    fi
}

# Function to check wx-config
check_wxwidgets() {
    local min_version="3.2.1"
    
    printf "Checking %-30s ... " "wxWidgets >= $min_version"
    
    if command -v wx-config &>/dev/null; then
        local version=$(wx-config --version 2>/dev/null)
        # Compare versions
        local major=$(echo "$version" | cut -d. -f1)
        local minor=$(echo "$version" | cut -d. -f2)
        local patch=$(echo "$version" | cut -d. -f3)
        
        local req_major=$(echo "$min_version" | cut -d. -f1)
        local req_minor=$(echo "$min_version" | cut -d. -f2)
        local req_patch=$(echo "$min_version" | cut -d. -f3)
        
        if [ "$major" -gt "$req_major" ] || \
           ([ "$major" -eq "$req_major" ] && [ "$minor" -gt "$req_minor" ]) || \
           ([ "$major" -eq "$req_major" ] && [ "$minor" -eq "$req_minor" ] && [ "$patch" -ge "$req_patch" ]); then
            echo "OK ($version)"
            return 0
        else
            echo "OUTDATED ($version < $min_version)"
            MISSING_DEPS+=("wxWidgets >= $min_version")
            ALL_OK=false
            return 1
        fi
    else
        echo "NOT FOUND"
        MISSING_DEPS+=("wxWidgets >= $min_version")
        ALL_OK=false
        return 1
    fi
}

echo "--- Build Tools ---"
check_cmd "g++" "C++ compiler (g++)"
check_cmd "make" "Make"
check_cmd "pkg-config" "pkg-config"
check_cmd "autoreconf" "autoreconf (autoconf)"
check_cmd "libtoolize" "libtoolize (libtool)"
check_cmd "msgfmt" "msgfmt (gettext)"

echo ""
echo "--- Required Libraries ---"
check_pkg "libfilezilla" "0.51.1" "libfilezilla >= 0.51.1"
check_wxwidgets
check_pkg "nettle" "3.1" "nettle >= 3.1"
check_pkg "hogweed" "3.1" "hogweed >= 3.1"
check_pkg "sqlite3" "3.7" "sqlite3 >= 3.7"
check_pkg "dbus-1" "" "libdbus"
check_pkg "gtk+-3.0" "" "GTK+ 3.0"

echo ""
echo "--- Optional Libraries ---"
# Reset ALL_OK before checking optional deps
OPTIONAL_MISSING=()
printf "Checking %-30s ... " "CppUnit (for tests)"
if pkg-config --exists "cppunit" 2>/dev/null; then
    local version=$(pkg-config --modversion "cppunit" 2>/dev/null)
    echo "OK ($version)"
else
    echo "NOT FOUND (optional)"
    OPTIONAL_MISSING+=("cppunit")
fi

echo ""
echo "=== Summary ==="

if [ "$ALL_OK" = true ]; then
    echo "All required dependencies are installed!"
    echo ""
    echo "You can proceed with building:"
    echo "  ./configure"
    echo "  make -j\$(nproc)"
    exit 0
else
    echo "Missing dependencies detected!"
    echo ""
    echo "Missing: ${MISSING_DEPS[*]}"
    echo ""
    
    # Provide installation instructions based on distribution
    case "$DISTRO" in
        ubuntu|debian|linuxmint|pop)
            echo "Install on Ubuntu/Debian with:"
            echo ""
            echo "  sudo apt update"
            echo "  sudo apt install build-essential autoconf automake libtool pkg-config gettext"
            echo "  sudo apt install libfilezilla-dev libwxgtk3.2-dev libnettle-dev"
            echo "  sudo apt install libsqlite3-dev libdbus-1-dev libgtk-3-dev"
            echo ""
            echo "If libfilezilla-dev is not available, you may need to build it from source:"
            echo "  https://lib.filezilla-project.org/"
            ;;
        fedora|rhel|centos|rocky|alma)
            echo "Install on Fedora/RHEL with:"
            echo ""
            echo "  sudo dnf groupinstall 'Development Tools'"
            echo "  sudo dnf install autoconf automake libtool pkgconfig gettext-devel"
            echo "  sudo dnf install libfilezilla-devel wxGTK-devel nettle-devel"
            echo "  sudo dnf install sqlite-devel dbus-devel gtk3-devel"
            ;;
        arch|manjaro)
            echo "Install on Arch Linux with:"
            echo ""
            echo "  sudo pacman -S base-devel autoconf automake libtool pkgconf gettext"
            echo "  sudo pacman -S libfilezilla wxwidgets-gtk3 nettle sqlite dbus gtk3"
            ;;
        opensuse*)
            echo "Install on openSUSE with:"
            echo ""
            echo "  sudo zypper install -t pattern devel_basis"
            echo "  sudo zypper install autoconf automake libtool pkg-config gettext-tools"
            echo "  sudo zypper install libfilezilla-devel wxWidgets-3_2-devel libnettle-devel"
            echo "  sudo zypper install sqlite3-devel dbus-1-devel gtk3-devel"
            ;;
        *)
            echo "Please install the following packages using your distribution's package manager:"
            echo "  - Build tools: g++, make, autoconf, automake, libtool, pkg-config, gettext"
            echo "  - Libraries: libfilezilla-dev, wxWidgets-dev (3.2+), nettle-dev, sqlite3-dev, dbus-dev, gtk3-dev"
            ;;
    esac
    
    exit 1
fi
