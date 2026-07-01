# ============================================================================
# DukanX Windows Build & Verification Script
# ============================================================================
# Performs a clean Release build and verifies all deployment artifacts.
#
# Usage: powershell -ExecutionPolicy Bypass -File scripts\build_windows.ps1
# ============================================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " DUKANX WINDOWS BUILD & VERIFICATION" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$ProjectDir = Split-Path -Parent $PSScriptRoot
$BuildDir = Join-Path $ProjectDir "build\windows\x64\runner\Release"
$InstallerDir = Join-Path $ProjectDir "installer"
$VCRedistDir = Join-Path $InstallerDir "vcredist"

# Step 1: Clean previous build
Write-Host "[1/6] Cleaning previous build..." -ForegroundColor Yellow
Push-Location $ProjectDir
try {
    flutter clean
    Write-Host "  -> Clean complete" -ForegroundColor Green
} catch {
    Write-Host "  -> Clean failed or warning occurred (continuing anyway): $_" -ForegroundColor Yellow
}

# Step 2: Get dependencies
Write-Host "[2/6] Getting dependencies..." -ForegroundColor Yellow
flutter pub get
Write-Host "  -> Dependencies resolved" -ForegroundColor Green

# Step 3: Build Release
Write-Host "[3/6] Building Windows Release..." -ForegroundColor Yellow
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "  -> BUILD FAILED!" -ForegroundColor Red
    Pop-Location
    exit 1
}
Write-Host "  -> Build successful" -ForegroundColor Green

# Step 4: Verify build output
Write-Host "[4/6] Verifying build artifacts..." -ForegroundColor Yellow

$requiredFiles = @(
    "dukanx.exe",
    "flutter_windows.dll",
    "data\icudtl.dat",
    "data\app.so",
    "data\flutter_assets\AssetManifest.bin",
    "data\flutter_assets\FontManifest.json",
    "data\flutter_assets\NOTICES.Z"
)

$missing = @()
foreach ($file in $requiredFiles) {
    $fullPath = Join-Path $BuildDir $file
    if (Test-Path $fullPath) {
        $size = (Get-Item $fullPath).Length
        Write-Host "  [OK] $file ($([math]::Round($size/1KB, 1)) KB)" -ForegroundColor Green
    } else {
        Write-Host "  [MISSING] $file" -ForegroundColor Red
        $missing += $file
    }
}

# Check DLLs
$dlls = Get-ChildItem -Path $BuildDir -Filter "*.dll" -File
Write-Host "  [INFO] Found $($dlls.Count) DLL files:" -ForegroundColor Cyan
foreach ($dll in $dlls) {
    Write-Host "    - $($dll.Name) ($([math]::Round($dll.Length/1KB, 1)) KB)" -ForegroundColor Gray
}

# Check data directory
$dataDir = Join-Path $BuildDir "data"
if (Test-Path $dataDir) {
    $dataFiles = Get-ChildItem -Path $dataDir -Recurse -File
    Write-Host "  [INFO] data/ contains $($dataFiles.Count) files" -ForegroundColor Cyan
} else {
    Write-Host "  [MISSING] data/ directory!" -ForegroundColor Red
    $missing += "data/"
}

if ($missing.Count -gt 0) {
    Write-Host ""
    Write-Host "WARNING: $($missing.Count) required files are missing!" -ForegroundColor Red
    foreach ($m in $missing) {
        Write-Host "  -> $m" -ForegroundColor Red
    }
}

# Step 5: Check VC++ Redistributable for installer
Write-Host "[5/6] Checking VC++ Redistributable for installer..." -ForegroundColor Yellow
if (-not (Test-Path $VCRedistDir)) {
    New-Item -ItemType Directory -Path $VCRedistDir -Force | Out-Null
}

$vcRedistExe = Join-Path $VCRedistDir "vc_redist.x64.exe"
if (Test-Path $vcRedistExe) {
    Write-Host "  [OK] VC++ Redistributable found" -ForegroundColor Green
} else {
    Write-Host "  [WARN] VC++ Redistributable not found at:" -ForegroundColor Yellow
    Write-Host "    $vcRedistExe" -ForegroundColor Gray
    Write-Host "  Download from: https://aka.ms/vs/17/release/vc_redist.x64.exe" -ForegroundColor Cyan
    Write-Host "  Place it in: $VCRedistDir" -ForegroundColor Cyan
}

# Step 6: Calculate total size
Write-Host "[6/6] Build summary..." -ForegroundColor Yellow
$totalSize = (Get-ChildItem -Path $BuildDir -Recurse -File | Measure-Object -Property Length -Sum).Sum
Write-Host "  Total Release size: $([math]::Round($totalSize/1MB, 1)) MB" -ForegroundColor Cyan
Write-Host "  Build directory: $BuildDir" -ForegroundColor Cyan

Pop-Location

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
if ($missing.Count -eq 0) {
    Write-Host " BUILD VERIFICATION: ALL CHECKS PASSED" -ForegroundColor Green
    Write-Host " Ready for deployment!" -ForegroundColor Green
} else {
    Write-Host " BUILD VERIFICATION: $($missing.Count) ISSUES FOUND" -ForegroundColor Red
    Write-Host " Fix the issues above before deploying." -ForegroundColor Red
}
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Copy the entire Release folder to target machine" -ForegroundColor White
Write-Host "     OR" -ForegroundColor Gray
Write-Host "  2. Build installer: iscc installer\dukanx_installer.iss" -ForegroundColor White
Write-Host ""
Write-Host "  To run diagnostics on target machine:" -ForegroundColor Yellow
Write-Host "    dukanx.exe --diagnostics" -ForegroundColor White
Write-Host ""
Write-Host "  To check logs after a crash:" -ForegroundColor Yellow
Write-Host "    type %APPDATA%\DukanX\logs\startup.log" -ForegroundColor White
Write-Host ""
