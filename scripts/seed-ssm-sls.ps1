param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('dev','prod')]
    [string]$Stage,
    [string]$Region = 'ap-south-1'
)

$ErrorActionPreference = 'Stop'

Write-Host "=== Seeding SSM params for stage: $Stage in $Region ===" -ForegroundColor Cyan

function Random-Hex {
    param([int]$Bytes = 32)
    $b = New-Object byte[] $Bytes
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b)
    return ($b | ForEach-Object { '{0:x2}' -f $_ }) -join ''
}

# 32-byte hex secrets
$JWT_A   = Random-Hex 32
$JWT_R   = Random-Hex 32
$AES     = Random-Hex 32
$TOTP    = Random-Hex 32
$LIC     = Random-Hex 32
$APP_SIG = Random-Hex 32

# RSA keypair via Node (cross-platform, no openssl dependency)
$rsaScript = @'
const crypto = require('crypto');
const { publicKey, privateKey } = crypto.generateKeyPairSync('rsa', {
  modulusLength: 2048,
  publicKeyEncoding:  { type: 'spki',  format: 'pem' },
  privateKeyEncoding: { type: 'pkcs8', format: 'pem' }
});
const out = {
  privB64: Buffer.from(privateKey).toString('base64'),
  pubB64:  Buffer.from(publicKey).toString('base64')
};
process.stdout.write(JSON.stringify(out));
'@
$rsaJson = $rsaScript | node
$rsa = $rsaJson | ConvertFrom-Json

function Put-Param {
    param([string]$Name, [string]$Value, [string]$Type = 'SecureString')
    Write-Host "  put $Name ($Type)" -ForegroundColor DarkGray
    aws ssm put-parameter --name $Name --type $Type --value $Value --overwrite --region $Region | Out-Null
}

Put-Param "/sls/$Stage/JWT_ACCESS_SECRET"     $JWT_A
Put-Param "/sls/$Stage/JWT_REFRESH_SECRET"    $JWT_R
Put-Param "/sls/$Stage/AES_ENCRYPTION_KEY"    $AES
Put-Param "/sls/$Stage/TOTP_ENCRYPTION_KEY"   $TOTP
Put-Param "/sls/$Stage/LICENSE_HMAC_SECRET"   $LIC
Put-Param "/sls/$Stage/APP_SIGNATURE_SECRET"  $APP_SIG
Put-Param "/sls/$Stage/RSA_PRIVATE_KEY"       $rsa.privB64
Put-Param "/sls/$Stage/RSA_PUBLIC_KEY"        $rsa.pubB64 'String'

# placeholders for Cognito (filled after Phase 2)
Put-Param "/sls/$Stage/S3_BUCKET_NAME"        "ultra-billing-storage-2026-$Stage" 'String'
Put-Param "/sls/$Stage/COGNITO_USER_POOL_ID"  "PLACEHOLDER" 'String'
Put-Param "/sls/$Stage/COGNITO_CLIENT_ID"     "PLACEHOLDER" 'String'

Write-Host "=== Done: $Stage ===" -ForegroundColor Green
