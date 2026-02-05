#!/bin/bash
# TabFTP - Build All Packages
# This script builds all Linux packages (AppImage, DEB, RPM)

set -e

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           TabFTP Linux Build and Packaging                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Get version
VERSION=$(grep "AC_INIT" configure.ac | sed -n 's/.*\[TabFTP\],\[\([0-9.]*\)\].*/\1/p')
echo "Version: $VERSION"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Parse arguments
BUILD_APPIMAGE=true
BUILD_DEB=true
BUILD_RPM=true
SKIP_CLEAN=false
SKIP_BUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --appimage-only)
            BUILD_DEB=false
            BUILD_RPM=false
            shift
            ;;
        --deb-only)
            BUILD_APPIMAGE=false
            BUILD_RPM=false
            shift
            ;;
        --rpm-only)
            BUILD_APPIMAGE=false
            BUILD_DEB=false
            shift
            ;;
        --skip-clean)
            SKIP_CLEAN=true
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --appimage-only  Build only AppImage"
            echo "  --deb-only       Build only DEB package"
            echo "  --rpm-only       Build only RPM package"
            echo "  --skip-clean     Skip cleaning step"
            echo "  --skip-build     Skip compilation (use existing build)"
            echo "  --help           Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Create output directory
mkdir -p dist

# Track timing
START_TIME=$(date +%s)

# Step 1: Check dependencies
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1/6: Checking dependencies..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -f ./check_dependencies.sh ]; then
    ./check_dependencies.sh || {
        echo ""
        echo "ERROR: Missing dependencies. Please install them and try again."
        exit 1
    }
else
    echo "Warning: check_dependencies.sh not found, skipping dependency check"
fi
echo ""

# Step 2: Clean (optional)
if [ "$SKIP_CLEAN" = false ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Step 2/6: Cleaning previous build artifacts..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [ -f ./clean_windows_build.sh ]; then
        ./clean_windows_build.sh
    else
        make clean 2>/dev/null || true
    fi
    echo ""
else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Step 2/6: Skipping clean (--skip-clean)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
fi

# Step 3: Configure and Build
if [ "$SKIP_BUILD" = false ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Step 3/6: Configuring and building..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Run autoreconf if needed
    if [ ! -f configure ] || [ configure.ac -nt configure ]; then
        echo "Running autoreconf..."
        autoreconf -i
    fi
    
    # Run configure if needed
    if [ ! -f Makefile ] || [ configure -nt Makefile ]; then
        echo "Running configure..."
        ./configure
    fi
    
    # Build
    echo "Building with $(nproc) parallel jobs..."
    make -j$(nproc)
    
    # Verify build
    if [ ! -f src/interface/.libs/tabftp ]; then
        echo "ERROR: Build failed - tabftp executable not found"
        exit 1
    fi
    echo ""
    echo "Build successful!"
    echo ""
else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Step 3/6: Skipping build (--skip-build)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Verify existing build
    if [ ! -f src/interface/.libs/tabftp ]; then
        echo "ERROR: No existing build found. Remove --skip-build flag."
        exit 1
    fi
    echo ""
fi

# Step 4: Build AppImage
if [ "$BUILD_APPIMAGE" = true ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Step 4/6: Building AppImage..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    ./build_appimage.sh || {
        echo "WARNING: AppImage build failed"
    }
    echo ""
else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Step 4/6: Skipping AppImage"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
fi

# Step 5: Build DEB
if [ "$BUILD_DEB" = true ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Step 5/6: Building DEB package..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    ./build_deb.sh || {
        echo "WARNING: DEB build failed"
    }
    echo ""
else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Step 5/6: Skipping DEB package"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
fi

# Step 6: Build RPM
if [ "$BUILD_RPM" = true ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Step 6/6: Building RPM package..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if command -v rpmbuild &>/dev/null; then
        ./build_rpm.sh || {
            echo "WARNING: RPM build failed"
        }
    else
        echo "rpmbuild not found, skipping RPM package"
        echo "Install with: sudo apt install rpm (Debian/Ubuntu)"
    fi
    echo ""
else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Step 6/6: Skipping RPM package"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
fi

# Calculate elapsed time
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED / 60))
SECONDS=$((ELAPSED % 60))

# Summary
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    Build Complete!                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Time elapsed: ${MINUTES}m ${SECONDS}s"
echo ""
echo "Output files in dist/:"
echo ""
ls -lh dist/ 2>/dev/null || echo "  (no files)"
echo ""
echo "Installation instructions:"
echo ""
echo "  AppImage: chmod +x TabFTP-*.AppImage && ./TabFTP-*.AppImage"
echo "  DEB:      sudo dpkg -i tabftp_*.deb"
echo "  RPM:      sudo rpm -i tabftp-*.rpm"
