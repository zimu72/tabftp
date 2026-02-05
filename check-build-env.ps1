# Check Windows Build Environment for TabFTP

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "TabFTP - Build Environment Check" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check Visual Studio
Write-Host "=== Visual Studio Installation ===" -ForegroundColor Yellow
$vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vsWhere) {
    $vsInstalls = & $vsWhere -all -format json | ConvertFrom-Json
    foreach ($vs in $vsInstalls) {
        Write-Host "  Found: $($vs.displayName)" -ForegroundColor Green
        Write-Host "    Path: $($vs.installationPath)"
        Write-Host "    Version: $($vs.installationVersion)"
    }
} else {
    Write-Host "  [WARNING] vswhere not found" -ForegroundColor Red
}
Write-Host ""

# Check MSBuild
Write-Host "=== MSBuild ===" -ForegroundColor Yellow
$msbuildLocations = @(
    "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe",
    "C:\Program Files\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe",
    "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe",
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe",
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\MSBuild\Current\Bin\MSBuild.exe",
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\MSBuild\Current\Bin\MSBuild.exe"
)
$msbuildFound = $false
foreach ($path in $msbuildLocations) {
    if (Test-Path $path) {
        Write-Host "  Found: $path" -ForegroundColor Green
        $msbuildFound = $true
        break
    }
}
if (-not $msbuildFound) {
    Write-Host "  [WARNING] MSBuild not found in standard locations" -ForegroundColor Red
}
Write-Host ""

# Check NSIS
Write-Host "=== NSIS (Installer Creator) ===" -ForegroundColor Yellow
$nsisLocations = @(
    "C:\Program Files (x86)\NSIS\makensis.exe",
    "C:\Program Files\NSIS\makensis.exe",
    "$env:LOCALAPPDATA\NSIS\makensis.exe"
)
$nsisFound = $false
foreach ($path in $nsisLocations) {
    if (Test-Path $path) {
        Write-Host "  Found: $path" -ForegroundColor Green
        $nsisFound = $true
        break
    }
}
# Also check in PATH
$nsisInPath = Get-Command makensis -ErrorAction SilentlyContinue
if ($nsisInPath) {
    Write-Host "  Found in PATH: $($nsisInPath.Source)" -ForegroundColor Green
    $nsisFound = $true
}
# Check local nsis-3.10-src
if (Test-Path "nsis-3.10-src\build\urelease\makensis\makensis") {
    Write-Host "  Found local build: nsis-3.10-src\build\urelease\makensis\makensis" -ForegroundColor Green
    $nsisFound = $true
}
if (-not $nsisFound) {
    Write-Host "  [WARNING] NSIS not found - needed for creating installer" -ForegroundColor Red
}
Write-Host ""

# Check for vcpkg
Write-Host "=== vcpkg (Package Manager) ===" -ForegroundColor Yellow
$vcpkgLocations = @(
    "C:\vcpkg\vcpkg.exe",
    "C:\src\vcpkg\vcpkg.exe",
    "$env:USERPROFILE\vcpkg\vcpkg.exe"
)
$vcpkgFound = $false
foreach ($path in $vcpkgLocations) {
    if (Test-Path $path) {
        Write-Host "  Found: $path" -ForegroundColor Green
        $vcpkgFound = $true
        break
    }
}
$vcpkgInPath = Get-Command vcpkg -ErrorAction SilentlyContinue
if ($vcpkgInPath) {
    Write-Host "  Found in PATH: $($vcpkgInPath.Source)" -ForegroundColor Green
    $vcpkgFound = $true
}
if (-not $vcpkgFound) {
    Write-Host "  [INFO] vcpkg not found - can be used to install dependencies" -ForegroundColor Yellow
}
Write-Host ""

# Check for existing Dependencies.props
Write-Host "=== Dependencies Configuration ===" -ForegroundColor Yellow
if (Test-Path "src\Dependencies.props") {
    Write-Host "  Found: src\Dependencies.props" -ForegroundColor Green
    Write-Host "  Content preview:"
    Get-Content "src\Dependencies.props" | Select-Object -First 20 | ForEach-Object { Write-Host "    $_" }
} else {
    Write-Host "  [WARNING] src\Dependencies.props not found" -ForegroundColor Red
    Write-Host "  You need to create this file from Dependencies.props.example" -ForegroundColor Yellow
}
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
$ready = $true
if (-not $msbuildFound) {
    Write-Host "  [X] MSBuild - NOT FOUND" -ForegroundColor Red
    $ready = $false
} else {
    Write-Host "  [OK] MSBuild" -ForegroundColor Green
}
if (-not $nsisFound) {
    Write-Host "  [X] NSIS - NOT FOUND (needed for installer)" -ForegroundColor Yellow
} else {
    Write-Host "  [OK] NSIS" -ForegroundColor Green
}
if (-not (Test-Path "src\Dependencies.props")) {
    Write-Host "  [X] Dependencies.props - NOT CONFIGURED" -ForegroundColor Red
    $ready = $false
} else {
    Write-Host "  [OK] Dependencies.props" -ForegroundColor Green
}
Write-Host ""
if ($ready) {
    Write-Host "Build environment is ready!" -ForegroundColor Green
} else {
    Write-Host "Some components are missing. Please configure them before building." -ForegroundColor Yellow
}
