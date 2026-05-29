# Bulk migration: process.env -> config.* across all backend files
# This script adds 'import { config } from '../config/environment';' (or '../../config/environment')
# and replaces hardcoded process.env calls with config.* equivalents.

$basePath = "g:\desktop app genuine\Dukan_x\my-backend\src"

# Files to process with their relative import path
$files = @(
    # --- services/ ---
    @{ Path="services\subscription.service.ts"; Import="../config/environment" },
    @{ Path="services\grace-period.service.ts"; Import="../config/environment" },
    @{ Path="services\kms.service.ts"; Import="../config/environment" },
    @{ Path="services\plan-management.service.ts"; Import="../config/environment" },
    @{ Path="services\product.service.ts"; Import="../config/environment" },
    @{ Path="services\post-payment.service.ts"; Import="../config/environment" },
    @{ Path="services\websocket.service.ts"; Import="../config/environment" },
    @{ Path="services\trial.service.ts"; Import="../config/environment" },
    @{ Path="services\stock.service.ts"; Import="../config/environment" },
    @{ Path="services\secrets-manager.service.ts"; Import="../config/environment" },
    @{ Path="services\presence.service.ts"; Import="../config/environment" },
    @{ Path="services\payment-order.service.ts"; Import="../config/environment" },
    @{ Path="services\payment-config.service.ts"; Import="../config/environment" },
    @{ Path="services\offline-queue.service.ts"; Import="../config/environment" },
    @{ Path="services\loyalty.service.ts"; Import="../config/environment" },
    @{ Path="services\limit-check.service.ts"; Import="../config/environment" },
    @{ Path="services\license.service.ts"; Import="../config/environment" },
    @{ Path="services\invoice.service.ts"; Import="../config/environment" },
    @{ Path="services\import-file-parser.ts"; Import="../config/environment" },
    @{ Path="services\hsn.validator.ts"; Import="../config/environment" },
    @{ Path="services\grocery-batch.service.ts"; Import="../config/environment" },
    @{ Path="services\fraud-detection.service.ts"; Import="../config/environment" },
    @{ Path="services\eventbridge.service.ts"; Import="../config/environment" },
    @{ Path="services\estimate.service.ts"; Import="../config/environment" },
    @{ Path="services\credit-reminder.service.ts"; Import="../config/environment" },
    @{ Path="services\auth.service.ts"; Import="../config/environment" },
    @{ Path="services\pharmacy-batch.service.ts"; Import="../config/environment" },
    # --- handlers/ ---
    @{ Path="handlers\subscription-webhook.ts"; Import="../config/environment" },
    @{ Path="handlers\secret-rotation.ts"; Import="../config/environment" },
    @{ Path="handlers\resto.ts"; Import="../config/environment" },
    @{ Path="handlers\report-dispatch-worker.ts"; Import="../config/environment" },
    @{ Path="handlers\reconciliation.ts"; Import="../config/environment" },
    @{ Path="handlers\products.ts"; Import="../config/environment" },
    @{ Path="handlers\process-import-row.ts"; Import="../config/environment" },
    @{ Path="handlers\pharmacy.ts"; Import="../config/environment" },
    @{ Path="handlers\notification.ts"; Import="../config/environment" },
    @{ Path="handlers\license.ts"; Import="../config/environment" },
    @{ Path="handlers\in-store-streams.ts"; Import="../config/environment" },
    @{ Path="handlers\in-store-checkout.ts"; Import="../config/environment" },
    @{ Path="handlers\in-store-barcode.ts"; Import="../config/environment" },
    @{ Path="handlers\import-product-file.ts"; Import="../config/environment" },
    @{ Path="handlers\websocket.ts"; Import="../config/environment" },
    @{ Path="handlers\clothing.ts"; Import="../config/environment" },
    # --- config/ ---
    @{ Path="config\payment-tables.config.ts"; Import="./environment" },
    @{ Path="config\clinic-api-gateway.ts"; Import="./environment" },
    # --- utils/ ---
    @{ Path="utils\websocket-cleanup.ts"; Import="../config/environment" },
    @{ Path="utils\secrets-manager.ts"; Import="../config/environment" },
    # --- search/ ---
    @{ Path="search\opensearch-client.ts"; Import="../config/environment" }
)

$totalChanged = 0

foreach ($fileInfo in $files) {
    $filePath = Join-Path $basePath $fileInfo.Path
    if (-not (Test-Path $filePath)) {
        Write-Host "SKIP (not found): $($fileInfo.Path)" -ForegroundColor Yellow
        continue
    }
    
    $content = Get-Content $filePath -Raw -Encoding UTF8
    $original = $content
    
    # Step 1: Add import if not already present
    if ($content -notmatch "from\s+['""].*config/environment['""]") {
        # Find a good insertion point (after the last import statement)
        $importLine = "import { config } from '$($fileInfo.Import)';"
        
        # Insert after the last import line
        $lines = $content -split "`r?`n"
        $lastImportIdx = -1
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match "^import\s+" -or $lines[$i] -match "^} from\s+") {
                $lastImportIdx = $i
            }
        }
        
        if ($lastImportIdx -ge 0) {
            $newLines = @()
            for ($i = 0; $i -lt $lines.Count; $i++) {
                $newLines += $lines[$i]
                if ($i -eq $lastImportIdx) {
                    $newLines += $importLine
                }
            }
            $content = $newLines -join "`r`n"
        }
    }
    
    # Step 2: Replace patterns
    # AWS_REGION patterns
    $content = $content -replace "process\.env\.AWS_REGION\s*\|\|\s*'ap-south-1'", "config.aws.region"
    $content = $content -replace "process\.env\.AWS_REGION\s*\?\?\s*'ap-south-1'", "config.aws.region"
    $content = $content -replace "process\.env\.AWS_REGION\s*\|\|\s*'us-east-1'", "config.aws.region"
    $content = $content -replace "process\.env\.AWS_REGION\b(?!\s*[\|?])", "config.aws.region"
    
    # DYNAMODB_TABLE patterns  
    $content = $content -replace "process\.env\.DYNAMODB_TABLE\s*\|\|\s*'DukanXTable'", "config.dynamodb.tableName"
    $content = $content -replace "process\.env\.DYNAMODB_TABLE\s*\|\|\s*'DukanX'", "config.dynamodb.tableName"
    $content = $content -replace "process\.env\.DYNAMODB_TABLE\s*\|\|\s*'Tenants'", "config.dynamodb.tableName"
    $content = $content -replace "process\.env\.DYNAMODB_TABLE\s*\|\|\s*TABLE_NAME", "config.dynamodb.tableName"
    $content = $content -replace "process\.env\.DYNAMODB_TABLE\s*\?\?\s*'DukanXTable'", "config.dynamodb.tableName"
    $content = $content -replace "process\.env\.DYNAMODB_TABLE\s*\?\?\s*'DukanX'", "config.dynamodb.tableName"
    $content = $content -replace "process\.env\.DYNAMODB_TABLE!", "config.dynamodb.tableName"
    $content = $content -replace "process\.env\.DYNAMODB_TABLE\b(?!\s*[\|?!])", "config.dynamodb.tableName"
    
    # COGNITO patterns
    $content = $content -replace "process\.env\.COGNITO_USER_POOL_ID\s*\|\|\s*''", "config.cognito.userPoolId"
    $content = $content -replace "process\.env\.COGNITO_USER_POOL_ID\b(?!\s*[\|])", "config.cognito.userPoolId"
    $content = $content -replace "process\.env\.COGNITO_CLIENT_ID\s*\|\|\s*''", "config.cognito.clientId"
    $content = $content -replace "process\.env\.COGNITO_CLIENT_ID\b(?!\s*[\|])", "config.cognito.clientId"
    $content = $content -replace "process\.env\.COGNITO_DESKTOP_CLIENT_ID\b", "config.cognito.desktopClientId"
    $content = $content -replace "process\.env\.COGNITO_MOBILE_CLIENT_ID\b", "config.cognito.mobileClientId"
    $content = $content -replace "process\.env\.COGNITO_ADMIN_CLIENT_ID\b", "config.cognito.adminClientId"
    
    # S3 patterns
    $content = $content -replace "process\.env\.S3_BUCKET_NAME\s*\|\|\s*''", "config.s3.bucketName"
    $content = $content -replace "process\.env\.S3_BUCKET_NAME\s*\?\?\s*''", "config.s3.bucketName"
    $content = $content -replace "process\.env\.S3_BUCKET\s*\|\|\s*'dukanx-media'", "config.s3.bucketName"
    
    # INTERNAL_API_SECRET
    $content = $content -replace "process\.env\.INTERNAL_API_SECRET!", "config.secrets.internalApiSecret"
    $content = $content -replace "process\.env\.INTERNAL_API_SECRET\b", "config.secrets.internalApiSecret"
    
    # Check if anything changed
    if ($content -ne $original) {
        Set-Content -Path $filePath -Value $content -Encoding UTF8 -NoNewline
        $totalChanged++
        Write-Host "FIXED: $($fileInfo.Path)" -ForegroundColor Green
    } else {
        Write-Host "NO CHANGE: $($fileInfo.Path)" -ForegroundColor Gray
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Total files modified: $totalChanged" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
