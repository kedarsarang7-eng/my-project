# deploy_web.ps1
# Automates Flutter Web build and S3 sync with CloudFront Invalidation

$ErrorActionPreference = "Stop"

$STAGE = "prod"
$REGION = "us-east-1"
$STACK_NAME = "dukanx-frontend-cdn-$STAGE"

Write-Host "Starting Flutter Web Build..." -ForegroundColor Cyan
flutter build web --release

if ($LASTEXITCODE -ne 0) {
    Write-Error "❌ Flutter build failed!"
    exit $LASTEXITCODE
}

Write-Host "Fetching S3 Bucket and CloudFront Dist ID from AWS..." -ForegroundColor Cyan
$Outputs = aws cloudformation describe-stacks --region $REGION --stack-name $STACK_NAME --query "Stacks[0].Outputs" | ConvertFrom-Json

$BucketName = ($Outputs | Where-Object { $_.OutputKey -eq 'FrontendBucketName' }).OutputValue
$DistributionId = ($Outputs | Where-Object { $_.OutputKey -eq 'CloudFrontDistributionId' }).OutputValue
$CloudFrontURL = ($Outputs | Where-Object { $_.OutputKey -eq 'CloudFrontURL' }).OutputValue

if ([string]::IsNullOrEmpty($BucketName) -or [string]::IsNullOrEmpty($DistributionId)) {
    Write-Error "❌ Failed to retrieve AWS resources. Has the frontend-cdn stack been deployed?"
    exit 1
}

Write-Host "Syncing build/web to S3 Bucket: s3://$BucketName" -ForegroundColor Cyan
aws s3 sync build/web s3://$BucketName --delete

Write-Host "Invalidating CloudFront Cache for Distribution: $DistributionId" -ForegroundColor Cyan
aws cloudfront create-invalidation --distribution-id $DistributionId --paths "/*"

Write-Host "Deployment Complete! The frontend is live at https://$CloudFrontURL" -ForegroundColor Green
