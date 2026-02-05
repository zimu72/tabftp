#!/bin/bash
# TabFTP - Clean Windows Build Artifacts
# This script removes all Windows build artifacts to prepare for Linux build

set -e

echo "=== TabFTP: Cleaning Windows Build Artifacts ==="
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Counter for deleted files
DELETED_COUNT=0

# Function to count and delete files
delete_files() {
    local pattern="$1"
    local description="$2"
    local count=0
    
    while IFS= read -r -d '' file; do
        rm -f "$file"
        ((count++)) || true
    done < <(find . -name "$pattern" -type f -print0 2>/dev/null)
    
    if [ $count -gt 0 ]; then
        echo "  Deleted $count $description"
        DELETED_COUNT=$((DELETED_COUNT + count))
    fi
}

# Function to clean directory contents
clean_dir_contents() {
    local dir_pattern="$1"
    local description="$2"
    local count=0
    
    while IFS= read -r -d '' dir; do
        if [ -d "$dir" ]; then
            local file_count=$(find "$dir" -type f 2>/dev/null | wc -l)
            if [ $file_count -gt 0 ]; then
                rm -rf "$dir"/*
                count=$((count + file_count))
            fi
        fi
    done < <(find . -name "$dir_pattern" -type d -print0 2>/dev/null)
    
    if [ $count -gt 0 ]; then
        echo "  Cleaned $count files from $description directories"
        DELETED_COUNT=$((DELETED_COUNT + count))
    fi
}

echo "Step 1: Removing object files (.o, .lo, .la)..."
delete_files "*.o" "object files (.o)"
delete_files "*.lo" "libtool object files (.lo)"
delete_files "*.la" "libtool archive files (.la)"

echo ""
echo "Step 2: Removing Windows executables and libraries (.exe, .dll)..."
delete_files "*.exe" "Windows executables (.exe)"
delete_files "*.dll" "Windows DLLs (.dll)"

echo ""
echo "Step 3: Removing configuration cache files..."
# Remove specific config files
for file in config.status config.log config/config.h config/stamp-h1; do
    if [ -f "$file" ]; then
        rm -f "$file"
        echo "  Deleted $file"
        DELETED_COUNT=$((DELETED_COUNT + 1))
    fi
done

echo ""
echo "Step 4: Cleaning .libs and .deps directories..."
clean_dir_contents ".libs" ".libs"
clean_dir_contents ".deps" ".deps"

echo ""
echo "Step 5: Removing precompiled headers (.gch)..."
delete_files "*.gch" "precompiled headers (.gch)"

echo ""
echo "Step 6: Removing static libraries (.a) from build directories..."
# Only remove .a files in src subdirectories (not system libraries)
while IFS= read -r -d '' file; do
    rm -f "$file"
    DELETED_COUNT=$((DELETED_COUNT + 1))
done < <(find ./src -name "*.a" -type f -print0 2>/dev/null)

echo ""
echo "Step 7: Removing libtool script..."
if [ -f "libtool" ]; then
    rm -f "libtool"
    echo "  Deleted libtool"
    DELETED_COUNT=$((DELETED_COUNT + 1))
fi

echo ""
echo "Step 8: Removing autom4te.cache..."
if [ -d "autom4te.cache" ]; then
    rm -rf "autom4te.cache"
    echo "  Deleted autom4te.cache directory"
fi

echo ""
echo "Step 9: Cleaning Makefile generated files in subdirectories..."
# Remove generated Makefiles but keep Makefile.am and Makefile.in
for dir in src src/engine src/interface src/putty src/commonui src/dbus src/pugixml src/storj src/include \
           src/interface/resources src/interface/resources/classic src/interface/resources/cyril \
           src/interface/resources/blukis src/interface/resources/default src/interface/resources/flatzilla \
           src/interface/resources/lone src/interface/resources/minimal src/interface/resources/opencrystal \
           src/interface/resources/sun src/interface/resources/tango src/interface/resources/cyril/16x16 \
           locales data tests src/fzshellext/32 src/fzshellext/64; do
    if [ -f "$dir/Makefile" ]; then
        rm -f "$dir/Makefile"
        DELETED_COUNT=$((DELETED_COUNT + 1))
    fi
done

# Remove root Makefile
if [ -f "Makefile" ]; then
    rm -f "Makefile"
    DELETED_COUNT=$((DELETED_COUNT + 1))
fi

echo ""
echo "=== Cleanup Complete ==="
echo "Total files/directories cleaned: $DELETED_COUNT"
echo ""
echo "Source files preserved. Ready for Linux build."
echo ""
echo "Next steps:"
echo "  1. Run ./check_dependencies.sh to verify build dependencies"
echo "  2. Run autoreconf -i (if configure is outdated)"
echo "  3. Run ./configure"
echo "  4. Run make -j\$(nproc)"
