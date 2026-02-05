# TabFTP - Clean Linux Build Artifacts
# This script removes all Linux-specific build artifacts to prepare for Windows build

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "TabFTP - Cleaning Linux Build Artifacts" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Continue"
$totalRemoved = 0

# Function to safely remove items
function Remove-SafeItem {
    param([string]$Path, [string]$Description)
    
    if (Test-Path $Path) {
        try {
            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
            Write-Host "  [REMOVED] $Path" -ForegroundColor Green
            return 1
        }
        catch {
            Write-Host "  [WARNING] Could not remove: $Path - $_" -ForegroundColor Yellow
            return 0
        }
    }
    return 0
}

# 1. Remove object files (.o)
Write-Host "Removing .o object files..." -ForegroundColor White
$oFiles = Get-ChildItem -Path . -Filter "*.o" -Recurse -File -ErrorAction SilentlyContinue
foreach ($file in $oFiles) {
    $totalRemoved += Remove-SafeItem $file.FullName "Object file"
}
Write-Host "  Found and processed $($oFiles.Count) .o files" -ForegroundColor Gray

# 2. Remove libtool object files (.lo)
Write-Host "Removing .lo libtool object files..." -ForegroundColor White
$loFiles = Get-ChildItem -Path . -Filter "*.lo" -Recurse -File -ErrorAction SilentlyContinue
foreach ($file in $loFiles) {
    $totalRemoved += Remove-SafeItem $file.FullName "Libtool object"
}
Write-Host "  Found and processed $($loFiles.Count) .lo files" -ForegroundColor Gray

# 3. Remove libtool archive files (.la)
Write-Host "Removing .la libtool archive files..." -ForegroundColor White
$laFiles = Get-ChildItem -Path . -Filter "*.la" -Recurse -File -ErrorAction SilentlyContinue
foreach ($file in $laFiles) {
    $totalRemoved += Remove-SafeItem $file.FullName "Libtool archive"
}
Write-Host "  Found and processed $($laFiles.Count) .la files" -ForegroundColor Gray

# 4. Remove precompiled headers (.gch)
Write-Host "Removing .gch precompiled header files..." -ForegroundColor White
$gchFiles = Get-ChildItem -Path . -Filter "*.gch" -Recurse -File -ErrorAction SilentlyContinue
foreach ($file in $gchFiles) {
    $totalRemoved += Remove-SafeItem $file.FullName "Precompiled header"
}
Write-Host "  Found and processed $($gchFiles.Count) .gch files" -ForegroundColor Gray

# 5. Remove .deps directories
Write-Host "Removing .deps directories..." -ForegroundColor White
$depsDirectories = Get-ChildItem -Path . -Filter ".deps" -Recurse -Directory -ErrorAction SilentlyContinue
foreach ($dir in $depsDirectories) {
    $totalRemoved += Remove-SafeItem $dir.FullName "Deps directory"
}
Write-Host "  Found and processed $($depsDirectories.Count) .deps directories" -ForegroundColor Gray

# 6. Remove .libs directories
Write-Host "Removing .libs directories..." -ForegroundColor White
$libsDirectories = Get-ChildItem -Path . -Filter ".libs" -Recurse -Directory -ErrorAction SilentlyContinue
foreach ($dir in $libsDirectories) {
    $totalRemoved += Remove-SafeItem $dir.FullName "Libs directory"
}
Write-Host "  Found and processed $($libsDirectories.Count) .libs directories" -ForegroundColor Gray

# 7. Remove AppImage files
Write-Host "Removing AppImage files..." -ForegroundColor White
$appImageFiles = Get-ChildItem -Path . -Filter "*.AppImage" -File -ErrorAction SilentlyContinue
foreach ($file in $appImageFiles) {
    $totalRemoved += Remove-SafeItem $file.FullName "AppImage"
}
Write-Host "  Found and processed $($appImageFiles.Count) .AppImage files" -ForegroundColor Gray

# 8. Remove AppDir directory
Write-Host "Removing AppDir directory..." -ForegroundColor White
if (Test-Path "AppDir") {
    $totalRemoved += Remove-SafeItem "AppDir" "AppDir"
}

# 9. Remove squashfs-root directory
Write-Host "Removing squashfs-root directory..." -ForegroundColor White
if (Test-Path "squashfs-root") {
    $totalRemoved += Remove-SafeItem "squashfs-root" "squashfs-root"
}

# 10. Remove Linux executables without extension in src/interface
Write-Host "Removing Linux executables in src/interface..." -ForegroundColor White
$linuxExecs = @("src/interface/filezilla", "src/interface/tabftp")
foreach ($exec in $linuxExecs) {
    if (Test-Path $exec) {
        # Check if it's a file without extension (Linux executable)
        $item = Get-Item $exec -ErrorAction SilentlyContinue
        if ($item -and !$item.PSIsContainer -and $item.Extension -eq "") {
            $totalRemoved += Remove-SafeItem $exec "Linux executable"
        }
    }
}

# 11. Remove .deb package files
Write-Host "Removing .deb package files..." -ForegroundColor White
$debFiles = Get-ChildItem -Path . -Filter "*.deb" -File -ErrorAction SilentlyContinue
foreach ($file in $debFiles) {
    $totalRemoved += Remove-SafeItem $file.FullName "Deb package"
}
Write-Host "  Found and processed $($debFiles.Count) .deb files" -ForegroundColor Gray

# 12. Remove .mo files in locales (will be regenerated)
Write-Host "Removing .mo compiled locale files..." -ForegroundColor White
$moFiles = Get-ChildItem -Path "locales" -Filter "*.mo" -File -ErrorAction SilentlyContinue
foreach ($file in $moFiles) {
    $totalRemoved += Remove-SafeItem $file.FullName "Compiled locale"
}
Write-Host "  Found and processed $($moFiles.Count) .mo files" -ForegroundColor Gray

# 13. Remove deb_package directory
Write-Host "Removing deb_package directory..." -ForegroundColor White
if (Test-Path "deb_package") {
    $totalRemoved += Remove-SafeItem "deb_package" "deb_package"
}

# 14. Remove .packaging directory
Write-Host "Removing .packaging directory..." -ForegroundColor White
if (Test-Path ".packaging") {
    $totalRemoved += Remove-SafeItem ".packaging" ".packaging"
}

# 15. Remove autom4te.cache directory
Write-Host "Removing autom4te.cache directory..." -ForegroundColor White
if (Test-Path "autom4te.cache") {
    $totalRemoved += Remove-SafeItem "autom4te.cache" "autom4te.cache"
}

# 16. Remove lockfile
Write-Host "Removing lockfile..." -ForegroundColor White
if (Test-Path "lockfile") {
    $totalRemoved += Remove-SafeItem "lockfile" "lockfile"
}

# 17. Remove src/interface/lockfile
Write-Host "Removing src/interface/lockfile..." -ForegroundColor White
if (Test-Path "src/interface/lockfile") {
    $totalRemoved += Remove-SafeItem "src/interface/lockfile" "lockfile"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Cleanup Complete!" -ForegroundColor Green
Write-Host "Total items removed: $totalRemoved" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Configure Dependencies.props with your library paths" -ForegroundColor White
Write-Host "2. Open src/FileZilla.sln in Visual Studio" -ForegroundColor White
Write-Host "3. Build the solution in Release|x64 configuration" -ForegroundColor White
