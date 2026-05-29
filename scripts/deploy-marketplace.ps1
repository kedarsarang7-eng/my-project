# ============================================================
# Dukan Marketplace Deployment Script
# Deploys Lambda functions and DynamoDB using AWS CLI
# ============================================================

param(
    [string]$Environment = "prod",
    [string]$Region = "ap-south-1",
    [string]$TableName = "DukanMarketplace",
    [switch]$SkipLambdaDeploy
)

$ErrorActionPreference = "Stop"

Write-Host "Dukan Marketplace Deployment" -ForegroundColor Green
Write-Host "Environment: $Environment"
Write-Host "Region: $Region"
Write-Host ""

# Check AWS CLI
Write-Host "Checking AWS CLI..." -ForegroundColor Yellow
$awsVersion = aws --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "AWS CLI not found. Please install AWS CLI."
    exit 1
}
Write-Host "AWS CLI found: $awsVersion" -ForegroundColor Green
Write-Host ""

# ============================================================
# Step 1: Create DynamoDB Table
# ============================================================
Write-Host "Step 1: Creating DynamoDB Table..." -ForegroundColor Cyan

try {
    $tableExists = aws dynamodb describe-table --table-name $TableName --region $Region 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Table $TableName already exists" -ForegroundColor Yellow
    }
} catch {
    # Table doesn't exist, create it
    Write-Host "Creating table $TableName..."
    
    aws dynamodb create-table `
        --table-name $TableName `
        --attribute-definitions `
            AttributeName=PK,AttributeType=S `
            AttributeName=SK,AttributeType=S `
            AttributeName=GSI1PK,AttributeType=S `
            AttributeName=GSI1SK,AttributeType=S `
            AttributeName=GSI2PK,AttributeType=S `
            AttributeName=GSI2SK,AttributeType=S `
        --key-schema `
            AttributeName=PK,KeyType=HASH `
            AttributeName=SK,KeyType=RANGE `
        --global-secondary-indexes `
            "IndexName=GSI1,KeySchema=[{AttributeName=GSI1PK,KeyType=HASH},{AttributeName=GSI1SK,KeyType=RANGE}],Projection={ProjectionType=ALL}" `
            "IndexName=GSI2,KeySchema=[{AttributeName=GSI2PK,KeyType=HASH},{AttributeName=GSI2SK,KeyType=RANGE}],Projection={ProjectionType=ALL}" `
        --billing-mode PAY_PER_REQUEST `
        --stream-specification StreamEnabled=true,StreamViewType=NEW_AND_OLD_IMAGES `
        --region $Region
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Table $TableName created successfully" -ForegroundColor Green
    } else {
        Write-Error "Failed to create table"
    }
}
Write-Host ""

# ============================================================
# Step 2: Deploy Lambda Functions
# ============================================================
if (-not $SkipLambdaDeploy) {
    Write-Host "Step 2: Deploying Lambda Functions..." -ForegroundColor Cyan
    
    $lambdaFunctions = @(
        @{ Name = "marketplace-store-handler"; Folder = "storeHandler"; Handler = "index.handler"; Timeout = 10 },
        @{ Name = "marketplace-inventory-handler"; Folder = "inventoryHandler"; Handler = "index.handler"; Timeout = 10 },
        @{ Name = "marketplace-cart-handler"; Folder = "cartHandler"; Handler = "index.handler"; Timeout = 10 },
        @{ Name = "marketplace-orders-handler"; Folder = "ordersHandler"; Handler = "index.handler"; Timeout = 30 },
        @{ Name = "marketplace-delivery-handler"; Folder = "deliveryHandler"; Handler = "index.handler"; Timeout = 10 },
        @{ Name = "marketplace-ws-handler"; Folder = "wsHandler"; Handler = "index.handler"; Timeout = 10 }
    )
    
    $basePath = "lambda/marketplace"
    
    foreach ($func in $lambdaFunctions) {
        $funcName = $func.Name
        $funcFolder = $func.Folder
        $funcPath = "$basePath/$funcFolder"
        
        Write-Host "Deploying $funcName..." -ForegroundColor Yellow
        
        # Check if function exists
        $funcExists = $false
        try {
            $funcInfo = aws lambda get-function --function-name $funcName --region $Region 2>$null
            if ($LASTEXITCODE -eq 0) {
                $funcExists = $true
            }
        } catch {
            $funcExists = $false
        }
        
        if ($funcExists) {
            Write-Host "  Updating existing function..."
            
            # Create deployment package
            $zipPath = ".temp-$funcName.zip"
            if (Test-Path $zipPath) { Remove-Item $zipPath }
            
            # Zip the function code
            Compress-Archive -Path "$funcPath/*" -DestinationPath $zipPath -Force
            
            # Update function code
            aws lambda update-function-code `
                --function-name $funcName `
                --zip-file fileb://$zipPath `
                --region $Region
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  $funcName updated" -ForegroundColor Green
            } else {
                Write-Host "  Failed to update $funcName" -ForegroundColor Red
            }
            
            Remove-Item $zipPath -ErrorAction SilentlyContinue
        } else {
            Write-Host "Creating new function $funcName..."
            
            # Create zip file
            $zipPath = ".temp-$funcName.zip"
            if (Test-Path $zipPath) { Remove-Item $zipPath }
            Compress-Archive -Path "$funcPath/*" -DestinationPath $zipPath -Force
            
            # Create Lambda function with Node.js 24.x
            aws lambda create-function `
                --function-name $funcName `
                --runtime nodejs24.x `
                --handler index.handler `
                --zip-file fileb://$zipPath `
                --role $LambdaRoleArn `
                --region $Region `
                --timeout $func.Timeout `
                --environment Variables="{\"TABLE_NAME\":\"$TableName\",\"ENVIRONMENT\":\"$Environment\",\"REGION\":\"$Region\"}" 2>&1 | Out-Null
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  $funcName created with Node.js 24.x" -ForegroundColor Green
            } else {
                Write-Host "  Failed to create $funcName" -ForegroundColor Red
            }
            
            Remove-Item $zipPath -ErrorAction SilentlyContinue
        }
    }
} else {
    Write-Host "Step 2: Skipping Lambda deployment (--SkipLambdaDeploy specified)" -ForegroundColor Yellow
}
Write-Host ""

# ============================================================
# Step 3: Set Lambda Environment Variables
# ============================================================
Write-Host "Step 3: Setting Lambda Environment Variables..." -ForegroundColor Cyan

$envVars = @{
    TABLE_NAME = $TableName
    ENVIRONMENT = $Environment
    REGION = $Region
}

$envVarsJson = $envVars | ConvertTo-Json -Compress

foreach ($func in $lambdaFunctions) {
    $funcName = $func.Name
    
    # Check if function exists first
    $funcExists = $false
    try {
        aws lambda get-function --function-name $funcName --region $Region 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $funcExists = $true
        }
    } catch {
        $funcExists = $false
    }
    
    if ($funcExists) {
        Write-Host "  Setting env vars for $funcName..."
        
        aws lambda update-function-configuration `
            --function-name $funcName `
            --environment Variables="{\"TABLE_NAME\":\"$TableName\",\"ENVIRONMENT\":\"$Environment\",\"REGION\":\"$Region\"}" `
            --region $Region 2>&1 | Out-Null
    } else {
        Write-Host "  Skipping $funcName (does not exist)" -ForegroundColor Yellow
    }
}
Write-Host "Environment variables set" -ForegroundColor Green
Write-Host ""

# ============================================================
# Step 4: Deploy API Gateway (REST)
# ============================================================
Write-Host "Step 4: Deploying API Gateway..." -ForegroundColor Cyan
Write-Host "  API Gateway deployment requires manual setup or CloudFormation" -ForegroundColor Yellow
Write-Host "  Template available at: cloudformation/api-gateway-marketplace.yml" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# Summary
# ============================================================
Write-Host "========================================" -ForegroundColor Green
Write-Host "Deployment Summary" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "DynamoDB Table: $TableName"
if (-not $SkipLambdaDeploy) {
    Write-Host "Lambda Functions: $($lambdaFunctions.Count) functions configured"
}
Write-Host "Environment: $Environment"
Write-Host "Region: $Region"
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. Deploy API Gateway using CloudFormation template" -ForegroundColor Yellow
Write-Host "2. Configure Cognito Authorizers" -ForegroundColor Yellow
Write-Host "3. Update Flutter app .env with API endpoints" -ForegroundColor Yellow
Write-Host ""
Write-Host 'Deployment complete!' -ForegroundColor Green
