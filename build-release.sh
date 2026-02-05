#!/bin/bash
# TabFTP Release Build Script
# This script strips debug symbols and creates installer

set -e

echo "=== TabFTP Release Build ==="

# Step 1: Re-link interface with -mwindows flag
echo ""
echo "Step 1: Re-linking interface with -mwindows flag..."
cd src/interface
# Remove only the exe to force re-link
rm -f tabftp.exe .libs/tabftp.exe
make -j$(nproc)
cd ../..

# Step 2: Strip debug symbols from executables
echo ""
echo "Step 2: Stripping debug symbols from executables..."
echo "Before stripping:"
ls -lh src/interface/.libs/tabftp.exe src/putty/.libs/fzsftp.exe src/putty/.libs/fzputtygen.exe

strip --strip-all src/interface/.libs/tabftp.exe
strip --strip-all src/putty/.libs/fzsftp.exe
strip --strip-all src/putty/.libs/fzputtygen.exe

echo "After stripping:"
ls -lh src/interface/.libs/tabftp.exe src/putty/.libs/fzsftp.exe src/putty/.libs/fzputtygen.exe

# Step 3: Strip debug symbols from DLLs
echo ""
echo "Step 3: Stripping debug symbols from DLLs..."
echo "Before stripping:"
du -sh data/dlls_gui/

for dll in data/dlls_gui/*.dll; do
    if [ -f "$dll" ]; then
        strip --strip-all "$dll" 2>/dev/null || true
    fi
done

echo "After stripping:"
du -sh data/dlls_gui/

# Step 4: Build installer
echo ""
echo "Step 4: Building installer..."
cd data
make install.nsi
"/c/Program Files (x86)/NSIS/makensis.exe" install.nsi
cd ..

# Show final installer size
echo ""
echo "=== Build Complete ==="
ls -lh data/TabFTP_setup.exe
echo ""
echo "Installer created: data/TabFTP_setup.exe"
