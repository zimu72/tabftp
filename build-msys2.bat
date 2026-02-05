@echo off
REM TabFTP Windows Build Script using MSYS2 MinGW64
REM This script will install missing dependencies and build TabFTP

echo ============================================
echo TabFTP Windows Build Script (MSYS2 MinGW64)
echo ============================================
echo.

REM Check if MSYS2 exists
if not exist "C:\msys64\msys2_shell.cmd" (
    echo ERROR: MSYS2 not found at C:\msys64
    echo Please install MSYS2 from https://www.msys2.org/
    exit /b 1
)

echo Step 1: Installing missing dependencies...
C:\msys64\usr\bin\bash.exe -lc "pacman -S --noconfirm --needed mingw-w64-x86_64-sqlite3 mingw-w64-x86_64-pugixml mingw-w64-x86_64-pkg-config"

echo.
echo Step 2: Building TabFTP in MinGW64 environment...
echo Please wait, this may take several minutes...
echo.

REM Run the build in MinGW64 shell
C:\msys64\usr\bin\env.exe MSYSTEM=MINGW64 C:\msys64\usr\bin\bash.exe -lc "cd '%CD%' && ./configure --disable-locales && make -j4"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Build failed! Check the error messages above.
    exit /b 1
)

echo.
echo ============================================
echo Build completed successfully!
echo The executable should be in src/interface/
echo ============================================
