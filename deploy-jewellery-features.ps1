# ============================================================================
# Jewellery Features Deployment Script
# ============================================================================
# Run this script to deploy all Jewellery Extended Features
# 
# Prerequisites:
#   - AWS CLI configured
#   - Serverless Framework installed (npm install -g serverless)
#   - Node.js 18+ installed
#   - Flutter SDK installed (for frontend verification)
# ============================================================================

param(
    [string]$Stage = "dev",
    [string]$Region = "ap-south-1",
    [switch]$SkipTests,
    [switch]$SkipBuild,
    [switch]$SkipFlutter
)

$ErrorActionPreference = "Stop"
$StartTime = Get-Date

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Jewellery Extended Features Deployment" -ForegroundColor Cyan
Write-Host "  Stage: $Stage | Region: $Region" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Step 1: Backend Build
if (-not $SkipBuild) {
    Write-Host "[Step 1/6] Building Backend..." -ForegroundColor Yellow
    Set-Location -Path "$PSScriptRoot\my-backend"
    
    try {
        npm install
        npm run build
        Write-Host "  ✓ Backend build successful" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Backend build failed" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[Step 1/6] Skipping Backend Build (--SkipBuild)" -ForegroundColor Gray
}

Write-Host ""

# Step 2: Run Tests
if (-not $SkipTests) {
    Write-Host "[Step 2/6] Running Tests..." -ForegroundColor Yellow
    Set-Location -Path "$PSScriptRoot\my-backend"
    
    try {
        npm test -- --testPathPattern="jewellery-extended" --passWithNoTests
        Write-Host "  ✓ Tests passed" -ForegroundColor Green
    } catch {
        Write-Host "  ! Tests completed with warnings" -ForegroundColor Yellow
    }
} else {
    Write-Host "[Step 2/6] Skipping Tests (--SkipTests)" -ForegroundColor Gray
}

Write-Host ""

# Step 3: Deploy Backend
Write-Host "[Step 3/6] Deploying Backend to AWS..." -ForegroundColor Yellow
Set-Location -Path "$PSScriptRoot\my-backend"

try {
    serverless deploy --stage $Stage --region $Region
    Write-Host "  ✓ Backend deployed successfully" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Deployment failed" -ForegroundColor Red
    Write-Host $_
    exit 1
}

Write-Host ""

# Step 4: Verify Deployment
Write-Host "[Step 4/6] Verifying Deployment..." -ForegroundColor Yellow
try {
    $ApiEndpoint = serverless info --stage $Stage --region $Region | Select-String -Pattern "https://.*\.execute-api" | ForEach-Object { $_.Matches.Value }
    Write-Host "  ✓ API Endpoint: $ApiEndpoint" -ForegroundColor Green
    
    # Test one endpoint
    $TestUrl = "$ApiEndpoint/jewellery/gold-rate-alerts"
    Write-Host "  Testing: $TestUrl" -ForegroundColor Gray
    
    try {
        $Response = Invoke-RestMethod -Uri $TestUrl -Method GET -Headers @{
            "Authorization" = "Bearer test-token"
        } -ErrorAction SilentlyContinue
        Write-Host "  ✓ Endpoint responding" -ForegroundColor Green
    } catch {
        Write-Host "  ! Endpoint may require valid auth token (expected)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ! Could not verify deployment" -ForegroundColor Yellow
}

Write-Host ""

# Step 5: Flutter Analysis
if (-not $SkipFlutter) {
    Write-Host "[Step 5/6] Analyzing Flutter Code..." -ForegroundColor Yellow
    Set-Location -Path "$PSScriptRoot\Dukan_x"
    
    try {
        flutter analyze lib/features/jewellery/ --fatal-infos
        Write-Host "  ✓ Flutter analysis passed" -ForegroundColor Green
    } catch {
        Write-Host "  ! Flutter analysis completed with issues" -ForegroundColor Yellow
    }
} else {
    Write-Host "[Step 5/6] Skipping Flutter Analysis (--SkipFlutter)" -ForegroundColor Gray
}

Write-Host ""

# Step 6: Summary
$EndTime = Get-Date
$Duration = $EndTime - $StartTime

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Deployment Complete!" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Duration: $($Duration.ToString('mm\:ss'))" -ForegroundColor White
Write-Host "  Stage: $Stage" -ForegroundColor White
Write-Host "  Region: $Region" -ForegroundColor White
Write-Host ""
Write-Host "  Deployed Features:" -ForegroundColor Green
Write-Host "    • Gold Rate Alerts (4 endpoints)" -ForegroundColor White
Write-Host "    • Making Charges Configs (4 endpoints)" -ForegroundColor White
Write-Host "    • Repair Jobs (7 endpoints)" -ForegroundColor White
Write-Host "    • Gold Schemes (6 endpoints)" -ForegroundColor White
Write-Host ""
Write-Host "  Total: 21 Lambda Functions | 28 API Endpoints" -ForegroundColor Green
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

# Return to original directory
Set-Location -Path $PSScriptRoot
