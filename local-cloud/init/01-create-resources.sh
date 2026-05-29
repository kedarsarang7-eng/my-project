#!/bin/bash
# =============================================================================
# LocalStack Init Hook — Runs after LocalStack health check passes
# =============================================================================
# This script creates all DynamoDB tables, Cognito user pools, S3 buckets,
# SQS queues, SNS topics, Secrets Manager secrets, and SSM parameters
# that mirror template.yaml resources.
# =============================================================================

set -euo pipefail

STACK="dukan-saas-dev"
REGION="ap-south-1"
ENDPOINT="http://localhost:4566"

# Alias for awslocal
aws() {
  command aws --endpoint-url="$ENDPOINT" --region "$REGION" "$@"
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  DukanX LocalStack Initialization"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ─── DynamoDB Tables ────────────────────────────────────────────────────

echo "[1/8] Creating DynamoDB tables..."

# Auth Sessions
aws dynamodb create-table \
  --table-name "${STACK}-auth-sessions" \
  --attribute-definitions AttributeName=sessionId,AttributeType=S \
  --key-schema AttributeName=sessionId,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  2>/dev/null || echo "  ✓ ${STACK}-auth-sessions already exists"

# Tenants
aws dynamodb create-table \
  --table-name "${STACK}-tenants" \
  --attribute-definitions \
    AttributeName=tenantId,AttributeType=S \
    AttributeName=plan,AttributeType=S \
    AttributeName=slug,AttributeType=S \
    AttributeName=createdAt,AttributeType=S \
    AttributeName=ownerUserId,AttributeType=S \
  --key-schema AttributeName=tenantId,KeyType=HASH \
  --global-secondary-indexes \
    '[{"IndexName":"GSI_Plan","KeySchema":[{"AttributeName":"plan","KeyType":"HASH"},{"AttributeName":"createdAt","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}},
      {"IndexName":"GSI_Slug","KeySchema":[{"AttributeName":"slug","KeyType":"HASH"}],"Projection":{"ProjectionType":"ALL"}},
      {"IndexName":"GSI_Owner","KeySchema":[{"AttributeName":"ownerUserId","KeyType":"HASH"},{"AttributeName":"createdAt","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}}]' \
  --billing-mode PAY_PER_REQUEST \
  2>/dev/null || echo "  ✓ ${STACK}-tenants already exists"

# Users
aws dynamodb create-table \
  --table-name "${STACK}-users" \
  --attribute-definitions \
    'AttributeName=tenantId#userId,AttributeType=S' \
    AttributeName=email,AttributeType=S \
    AttributeName=tenantId,AttributeType=S \
    'AttributeName=role#userId,AttributeType=S' \
  --key-schema 'AttributeName=tenantId#userId,KeyType=HASH' \
  --global-secondary-indexes \
    '[{"IndexName":"GSI_Email","KeySchema":[{"AttributeName":"email","KeyType":"HASH"}],"Projection":{"ProjectionType":"ALL"}},
      {"IndexName":"GSI_TenantRole","KeySchema":[{"AttributeName":"tenantId","KeyType":"HASH"},{"AttributeName":"role#userId","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}}]' \
  --billing-mode PAY_PER_REQUEST \
  2>/dev/null || echo "  ✓ ${STACK}-users already exists"

# Billing
aws dynamodb create-table \
  --table-name "${STACK}-billing" \
  --attribute-definitions \
    AttributeName=tenantId,AttributeType=S \
    AttributeName=SK,AttributeType=S \
    AttributeName=status,AttributeType=S \
    AttributeName=dueAt,AttributeType=S \
  --key-schema AttributeName=tenantId,KeyType=HASH AttributeName=SK,KeyType=RANGE \
  --global-secondary-indexes \
    '[{"IndexName":"GSI_BillingStatus","KeySchema":[{"AttributeName":"status","KeyType":"HASH"},{"AttributeName":"dueAt","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}}]' \
  --billing-mode PAY_PER_REQUEST \
  2>/dev/null || echo "  ✓ ${STACK}-billing already exists"

# Audit Logs
aws dynamodb create-table \
  --table-name "${STACK}-audit-logs" \
  --attribute-definitions \
    AttributeName=tenantId,AttributeType=S \
    'AttributeName=tenantId#userId,AttributeType=S' \
    AttributeName=SK,AttributeType=S \
  --key-schema AttributeName=tenantId,KeyType=HASH AttributeName=SK,KeyType=RANGE \
  --global-secondary-indexes \
    '[{"IndexName":"GSI_UserAudit","KeySchema":[{"AttributeName":"tenantId#userId","KeyType":"HASH"},{"AttributeName":"SK","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}}]' \
  --billing-mode PAY_PER_REQUEST \
  2>/dev/null || echo "  ✓ ${STACK}-audit-logs already exists"

# Customer Invoices
aws dynamodb create-table \
  --table-name "${STACK}-customer-invoices" \
  --attribute-definitions \
    AttributeName=PK,AttributeType=S \
    AttributeName=SK,AttributeType=S \
    AttributeName=customerId,AttributeType=S \
    AttributeName=createdAt,AttributeType=S \
  --key-schema AttributeName=PK,KeyType=HASH AttributeName=SK,KeyType=RANGE \
  --global-secondary-indexes \
    '[{"IndexName":"GSI_Customer","KeySchema":[{"AttributeName":"customerId","KeyType":"HASH"},{"AttributeName":"createdAt","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}}]' \
  --billing-mode PAY_PER_REQUEST \
  2>/dev/null || echo "  ✓ ${STACK}-customer-invoices already exists"

# Customer Ledger
aws dynamodb create-table \
  --table-name "${STACK}-customer-ledger" \
  --attribute-definitions \
    AttributeName=PK,AttributeType=S \
    AttributeName=SK,AttributeType=S \
    AttributeName=customerId,AttributeType=S \
    AttributeName=createdAt,AttributeType=S \
  --key-schema AttributeName=PK,KeyType=HASH AttributeName=SK,KeyType=RANGE \
  --global-secondary-indexes \
    '[{"IndexName":"GSI_CustomerLedger","KeySchema":[{"AttributeName":"customerId","KeyType":"HASH"},{"AttributeName":"createdAt","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}}]' \
  --billing-mode PAY_PER_REQUEST \
  2>/dev/null || echo "  ✓ ${STACK}-customer-ledger already exists"

# Customer Payments
aws dynamodb create-table \
  --table-name "${STACK}-customer-payments" \
  --attribute-definitions \
    AttributeName=PK,AttributeType=S \
    AttributeName=SK,AttributeType=S \
    AttributeName=GSI_Customer_PK,AttributeType=S \
    AttributeName=GSI_Customer_SK,AttributeType=S \
    AttributeName=GSI_Vendor_PK,AttributeType=S \
    AttributeName=GSI_Vendor_SK,AttributeType=S \
  --key-schema AttributeName=PK,KeyType=HASH AttributeName=SK,KeyType=RANGE \
  --global-secondary-indexes \
    '[{"IndexName":"GSI_Customer","KeySchema":[{"AttributeName":"GSI_Customer_PK","KeyType":"HASH"},{"AttributeName":"GSI_Customer_SK","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}},
      {"IndexName":"GSI_Vendor","KeySchema":[{"AttributeName":"GSI_Vendor_PK","KeyType":"HASH"},{"AttributeName":"GSI_Vendor_SK","KeyType":"RANGE"}],"Projection":{"ProjectionType":"ALL"}}]' \
  --billing-mode PAY_PER_REQUEST \
  2>/dev/null || echo "  ✓ ${STACK}-customer-payments already exists"

# Customer Notifications
aws dynamodb create-table \
  --table-name "${STACK}-customer-notifications" \
  --attribute-definitions \
    AttributeName=PK,AttributeType=S \
    AttributeName=SK,AttributeType=S \
  --key-schema AttributeName=PK,KeyType=HASH AttributeName=SK,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  2>/dev/null || echo "  ✓ ${STACK}-customer-notifications already exists"

# WebSocket Connections
aws dynamodb create-table \
  --table-name "${STACK}-ws-connections" \
  --attribute-definitions \
    AttributeName=connectionId,AttributeType=S \
    AttributeName=GSI_Customer_PK,AttributeType=S \
  --key-schema AttributeName=connectionId,KeyType=HASH \
  --global-secondary-indexes \
    '[{"IndexName":"GSI_Customer","KeySchema":[{"AttributeName":"GSI_Customer_PK","KeyType":"HASH"}],"Projection":{"ProjectionType":"ALL"}}]' \
  --billing-mode PAY_PER_REQUEST \
  2>/dev/null || echo "  ✓ ${STACK}-ws-connections already exists"

echo "  ✓ All DynamoDB tables created"

# ─── S3 Buckets ─────────────────────────────────────────────────────────

echo "[2/8] Creating S3 buckets..."

aws s3 mb "s3://${STACK}-barcode-labels" 2>/dev/null || echo "  ✓ barcode-labels already exists"
aws s3 mb "s3://${STACK}-uploads" 2>/dev/null || echo "  ✓ uploads already exists"
aws s3 mb "s3://${STACK}-exports" 2>/dev/null || echo "  ✓ exports already exists"

echo "  ✓ All S3 buckets created"

# ─── SQS Queues ─────────────────────────────────────────────────────────

echo "[3/8] Creating SQS queues..."

# Email notification queue
aws sqs create-queue --queue-name "${STACK}-email-notifications" \
  --attributes '{"VisibilityTimeout":"60","MessageRetentionPeriod":"86400"}' \
  2>/dev/null || echo "  ✓ email-notifications already exists"

# Dead letter queue
aws sqs create-queue --queue-name "${STACK}-email-notifications-dlq" \
  --attributes '{"MessageRetentionPeriod":"1209600"}' \
  2>/dev/null || echo "  ✓ email-notifications-dlq already exists"

# Audit event queue
aws sqs create-queue --queue-name "${STACK}-audit-events" \
  --attributes '{"VisibilityTimeout":"30"}' \
  2>/dev/null || echo "  ✓ audit-events already exists"

# Trial provisioning queue
aws sqs create-queue --queue-name "${STACK}-trial-provisioning" \
  --attributes '{"VisibilityTimeout":"120"}' \
  2>/dev/null || echo "  ✓ trial-provisioning already exists"

echo "  ✓ All SQS queues created"

# ─── SNS Topics ─────────────────────────────────────────────────────────

echo "[4/8] Creating SNS topics..."

aws sns create-topic --name "${STACK}-tenant-events" 2>/dev/null || echo "  ✓ tenant-events already exists"
aws sns create-topic --name "${STACK}-billing-events" 2>/dev/null || echo "  ✓ billing-events already exists"
aws sns create-topic --name "${STACK}-user-events" 2>/dev/null || echo "  ✓ user-events already exists"
aws sns create-topic --name "${STACK}-alerts" 2>/dev/null || echo "  ✓ alerts already exists"

echo "  ✓ All SNS topics created"

# ─── EventBridge ────────────────────────────────────────────────────────

echo "[5/8] Creating EventBridge event bus..."

aws events create-event-bus --name "${STACK}-main-bus" 2>/dev/null || echo "  ✓ Event bus already exists"

# Subscription lifecycle rule
aws events put-rule \
  --event-bus-name "${STACK}-main-bus" \
  --name "subscription-lifecycle" \
  --event-pattern '{
    "source": ["dukan.billing"],
    "detail-type": ["SubscriptionCreated", "SubscriptionCancelled", "SubscriptionExpired"]
  }' \
  2>/dev/null || echo "  ✓ subscription-lifecycle rule already exists"

# Tenant onboarding rule
aws events put-rule \
  --event-bus-name "${STACK}-main-bus" \
  --name "tenant-onboarding" \
  --event-pattern '{
    "source": ["dukan.tenants"],
    "detail-type": ["TenantCreated", "TenantDeleted"]
  }' \
  2>/dev/null || echo "  ✓ tenant-onboarding rule already exists"

echo "  ✓ EventBridge bus and rules created"

# ─── Secrets Manager ───────────────────────────────────────────────────

echo "[6/8] Creating Secrets Manager secrets..."

aws secretsmanager create-secret \
  --name "${STACK}/jwt-signing-key" \
  --secret-string '{"key":"local-dev-jwt-secret-256-bit-key-do-not-use-in-prod"}' \
  2>/dev/null || echo "  ✓ jwt-signing-key already exists"

aws secretsmanager create-secret \
  --name "${STACK}/razorpay" \
  --secret-string '{"key_id":"rzp_test_LOCALDEV","key_secret":"localdev_secret_DONOTUSE"}' \
  2>/dev/null || echo "  ✓ razorpay secret already exists"

aws secretsmanager create-secret \
  --name "${STACK}/smtp" \
  --secret-string '{"host":"mailhog","port":1025,"user":"","password":""}' \
  2>/dev/null || echo "  ✓ smtp secret already exists"

echo "  ✓ All secrets created"

# ─── SSM Parameter Store ───────────────────────────────────────────────

echo "[7/8] Creating SSM parameters..."

aws ssm put-parameter --name "/${STACK}/environment" --value "dev" --type String --overwrite 2>/dev/null
aws ssm put-parameter --name "/${STACK}/api-url" --value "http://localhost:4566" --type String --overwrite 2>/dev/null
aws ssm put-parameter --name "/${STACK}/redis-url" --value "redis://redis:6379" --type String --overwrite 2>/dev/null
aws ssm put-parameter --name "/${STACK}/log-level" --value "debug" --type String --overwrite 2>/dev/null
aws ssm put-parameter --name "/${STACK}/feature-flags" --value '{"enableWebSocket":true,"enableBarcode":true,"enableMarketplace":false}' --type String --overwrite 2>/dev/null

echo "  ✓ All SSM parameters created"

# ─── Cognito User Pool ─────────────────────────────────────────────────

echo "[8/8] Creating Cognito user pool..."

POOL_ID=$(aws cognito-idp create-user-pool \
  --pool-name "${STACK}-user-pool" \
  --policies '{"PasswordPolicy":{"MinimumLength":8,"RequireUppercase":true,"RequireLowercase":true,"RequireNumbers":true,"RequireSymbols":true}}' \
  --auto-verified-attributes email \
  --username-attributes email \
  --schema '[{"Name":"email","AttributeDataType":"String","Mutable":true,"Required":true},{"Name":"custom:tenantId","AttributeDataType":"String","Mutable":true},{"Name":"custom:role","AttributeDataType":"String","Mutable":false},{"Name":"custom:plan","AttributeDataType":"String","Mutable":true}]' \
  --query 'UserPool.Id' --output text \
  2>/dev/null) || POOL_ID="existing"

if [ "$POOL_ID" != "existing" ]; then
  echo "  ✓ User Pool created: ${POOL_ID}"

  # App Client
  CLIENT_ID=$(aws cognito-idp create-user-pool-client \
    --user-pool-id "$POOL_ID" \
    --client-name "${STACK}-app-client" \
    --no-generate-secret \
    --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH \
    --query 'UserPoolClient.ClientId' --output text)
  echo "  ✓ App Client: ${CLIENT_ID}"

  # Admin Client
  ADMIN_CLIENT_ID=$(aws cognito-idp create-user-pool-client \
    --user-pool-id "$POOL_ID" \
    --client-name "${STACK}-admin-client" \
    --no-generate-secret \
    --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH \
    --query 'UserPoolClient.ClientId' --output text)
  echo "  ✓ Admin Client: ${ADMIN_CLIENT_ID}"

  # Mobile Client
  MOBILE_CLIENT_ID=$(aws cognito-idp create-user-pool-client \
    --user-pool-id "$POOL_ID" \
    --client-name "${STACK}-mobile-client" \
    --no-generate-secret \
    --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH \
    --query 'UserPoolClient.ClientId' --output text)
  echo "  ✓ Mobile Client: ${MOBILE_CLIENT_ID}"

  # Create test users
  aws cognito-idp admin-create-user \
    --user-pool-id "$POOL_ID" \
    --username "admin@dukan-test.local" \
    --user-attributes Name=email,Value=admin@dukan-test.local Name=email_verified,Value=true Name=custom:tenantId,Value=tenant-001 Name=custom:role,Value=superadmin Name=custom:plan,Value=premium \
    --temporary-password "Test@1234" \
    --message-action SUPPRESS 2>/dev/null || true

  aws cognito-idp admin-create-user \
    --user-pool-id "$POOL_ID" \
    --username "staff@dukan-test.local" \
    --user-attributes Name=email,Value=staff@dukan-test.local Name=email_verified,Value=true Name=custom:tenantId,Value=tenant-001 Name=custom:role,Value=staff Name=custom:plan,Value=premium \
    --temporary-password "Test@1234" \
    --message-action SUPPRESS 2>/dev/null || true

  echo "  ✓ Test users created (admin@dukan-test.local / staff@dukan-test.local)"
else
  echo "  ✓ User Pool already exists"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ LocalStack initialization COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Dashboard:    http://localhost:4566/_localstack/health"
echo "  DynamoDB:     http://localhost:4566 (endpoint)"
echo "  Email UI:     http://localhost:8025"
echo "  Jaeger UI:    http://localhost:16686 (if observability profile)"
echo ""
