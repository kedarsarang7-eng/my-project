# =============================================================================
# CHECK FIRESTORE USAGE SCRIPT
# =============================================================================
# This script validates that FirebaseFirestore is not used directly in UI,
# ViewModel, Repository, or Screen files. All Firestore calls must go through
# the SyncEngine (lib/core/sync/).
#
# Run this in CI or as a pre-commit hook.
#
# Usage: pwsh -File scripts/check_firestore_usage.ps1
# Exit code: 0 = pass, 1 = violations found
# =============================================================================

$ErrorActionPreference = "Stop"

Write-Host "============================================"
Write-Host "  DukanX Firestore Usage Checker"
Write-Host "============================================"
Write-Host ""

# Paths where FirebaseFirestore is ALLOWED
$allowedPaths = @(
    "lib/core/sync/",
    "lib/services/firestore/",
    "lib/services/firestore_service.dart",
    "lib/services/sync_service.dart",
    "lib/firebase_options.dart"
)

# Paths where FirebaseFirestore is FORBIDDEN
$forbiddenPatterns = @(
    "lib/screens/",
    "lib/features/*/presentation/",
    "lib/features/*/screens/",
    "lib/widgets/",
    "lib/providers/"
)

# Search for FirebaseFirestore usage
$projectRoot = Split-Path -Parent $PSScriptRoot
$libPath = Join-Path $projectRoot "lib"

if (-not (Test-Path $libPath)) {
    Write-Host "ERROR: lib directory not found at $libPath"
    exit 1
}

Write-Host "Scanning for FirebaseFirestore usage..."
Write-Host ""

# Find all dart files containing FirebaseFirestore
$violations = @()

Get-ChildItem -Path $libPath -Filter "*.dart" -Recurse | ForEach-Object {
    $file = $_
    $relativePath = $file.FullName.Replace($projectRoot, "").Replace("\", "/").TrimStart("/")
    
    # Check if file is in allowed paths
    $isAllowed = $false
    foreach ($allowed in $allowedPaths) {
        if ($relativePath -like "*$allowed*") {
            $isAllowed = $true
            break
        }
    }
    
    if (-not $isAllowed) {
        # Check if file contains FirebaseFirestore
        $content = Get-Content $file.FullName -Raw
        if ($content -match "FirebaseFirestore|cloud_firestore") {
            # Check for actual usage (not just comments)
            $lines = Get-Content $file.FullName
            $lineNumber = 0
            foreach ($line in $lines) {
                $lineNumber++
                if ($line -match "FirebaseFirestore|import.*cloud_firestore") {
                    if ($line -notmatch "^\s*//") {  # Not a comment
                        $violations += [PSCustomObject]@{
                            File = $relativePath
                            Line = $lineNumber
                            Content = $line.Trim()
                        }
                    }
                }
            }
        }
    }
}

# Report results
Write-Host ""
if ($violations.Count -eq 0) {
    Write-Host "SUCCESS: No Firestore violations found!" -ForegroundColor Green
    Write-Host ""
    Write-Host "All Firestore calls are properly isolated in the SyncEngine."
    exit 0
} else {
    Write-Host "FAILURE: Found $($violations.Count) Firestore violations!" -ForegroundColor Red
    Write-Host ""
    Write-Host "The following files use FirebaseFirestore outside of the SyncEngine:"
    Write-Host ""
    
    foreach ($violation in $violations) {
        Write-Host "  $($violation.File):$($violation.Line)" -ForegroundColor Yellow
        Write-Host "    $($violation.Content)" -ForegroundColor DarkGray
        Write-Host ""
    }
    
    Write-Host "============================================"
    Write-Host "  HOW TO FIX:"
    Write-Host "============================================"
    Write-Host ""
    Write-Host "1. Replace direct Firestore calls with Repository pattern:"
    Write-Host "   - Use sl<BillsRepository>() instead of FirebaseFirestore.instance"
    Write-Host "   - All mutations go through local DB first, then sync queue"
    Write-Host ""
    Write-Host "2. Allowed paths for Firestore usage:"
    foreach ($path in $allowedPaths) {
        Write-Host "   - $path"
    }
    Write-Host ""
    
    exit 1
}
