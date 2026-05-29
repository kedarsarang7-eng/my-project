#!/bin/bash
# =============================================================================
# Seed DynamoDB with test data for local development
# =============================================================================

set -euo pipefail

STACK="dukan-saas-dev"
REGION="ap-south-1"
ENDPOINT="http://localhost:4566"

aws() {
  command aws --endpoint-url="$ENDPOINT" --region "$REGION" "$@"
}

echo "Seeding DynamoDB with test data..."

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ─── Seed Tenants ──────────────────────────────────────────────────────

aws dynamodb put-item --table-name "${STACK}-tenants" --item '{
  "tenantId": {"S": "tenant-001"},
  "name": {"S": "Sharma Electronics"},
  "slug": {"S": "sharma-electronics"},
  "plan": {"S": "premium"},
  "businessType": {"S": "electronics"},
  "ownerUserId": {"S": "user-admin-001"},
  "status": {"S": "active"},
  "maxUsers": {"N": "10"},
  "createdAt": {"S": "'"$NOW"'"},
  "updatedAt": {"S": "'"$NOW"'"}
}'

aws dynamodb put-item --table-name "${STACK}-tenants" --item '{
  "tenantId": {"S": "tenant-002"},
  "name": {"S": "Patel Fuel Station"},
  "slug": {"S": "patel-fuel"},
  "plan": {"S": "pro"},
  "businessType": {"S": "fuelStation"},
  "ownerUserId": {"S": "user-admin-002"},
  "status": {"S": "active"},
  "maxUsers": {"N": "3"},
  "createdAt": {"S": "'"$NOW"'"},
  "updatedAt": {"S": "'"$NOW"'"}
}'

aws dynamodb put-item --table-name "${STACK}-tenants" --item '{
  "tenantId": {"S": "tenant-003"},
  "name": {"S": "City Clinic"},
  "slug": {"S": "city-clinic"},
  "plan": {"S": "basic"},
  "businessType": {"S": "clinic"},
  "ownerUserId": {"S": "user-admin-003"},
  "status": {"S": "trial"},
  "maxUsers": {"N": "1"},
  "trialExpiresAt": {"S": "2026-06-23T00:00:00Z"},
  "createdAt": {"S": "'"$NOW"'"},
  "updatedAt": {"S": "'"$NOW"'"}
}'

echo "  ✓ 3 tenants seeded"

# ─── Seed Users ────────────────────────────────────────────────────────

aws dynamodb put-item --table-name "${STACK}-users" --item '{
  "tenantId#userId": {"S": "tenant-001#user-admin-001"},
  "email": {"S": "admin@sharma.local"},
  "tenantId": {"S": "tenant-001"},
  "role#userId": {"S": "superadmin#user-admin-001"},
  "name": {"S": "Rajesh Sharma"},
  "role": {"S": "superadmin"},
  "status": {"S": "active"},
  "createdAt": {"S": "'"$NOW"'"},
  "updatedAt": {"S": "'"$NOW"'"}
}'

aws dynamodb put-item --table-name "${STACK}-users" --item '{
  "tenantId#userId": {"S": "tenant-001#user-staff-001"},
  "email": {"S": "cashier@sharma.local"},
  "tenantId": {"S": "tenant-001"},
  "role#userId": {"S": "staff#user-staff-001"},
  "name": {"S": "Priya Verma"},
  "role": {"S": "staff"},
  "status": {"S": "active"},
  "createdAt": {"S": "'"$NOW"'"},
  "updatedAt": {"S": "'"$NOW"'"}
}'

aws dynamodb put-item --table-name "${STACK}-users" --item '{
  "tenantId#userId": {"S": "tenant-002#user-admin-002"},
  "email": {"S": "admin@patel-fuel.local"},
  "tenantId": {"S": "tenant-002"},
  "role#userId": {"S": "admin#user-admin-002"},
  "name": {"S": "Amit Patel"},
  "role": {"S": "admin"},
  "status": {"S": "active"},
  "createdAt": {"S": "'"$NOW"'"},
  "updatedAt": {"S": "'"$NOW"'"}
}'

echo "  ✓ 3 users seeded"

# ─── Seed Billing ──────────────────────────────────────────────────────

aws dynamodb put-item --table-name "${STACK}-billing" --item '{
  "tenantId": {"S": "tenant-001"},
  "SK": {"S": "SUB"},
  "subscriptionId": {"S": "sub-001"},
  "plan": {"S": "premium"},
  "status": {"S": "active"},
  "seats": {"N": "5"},
  "pricePerSeat": {"N": "999"},
  "currency": {"S": "INR"},
  "startDate": {"S": "'"$NOW"'"},
  "createdAt": {"S": "'"$NOW"'"},
  "updatedAt": {"S": "'"$NOW"'"}
}'

aws dynamodb put-item --table-name "${STACK}-billing" --item '{
  "tenantId": {"S": "tenant-001"},
  "SK": {"S": "INV#inv-001"},
  "invoiceId": {"S": "inv-001"},
  "amount": {"N": "4995"},
  "currency": {"S": "INR"},
  "status": {"S": "paid"},
  "dueAt": {"S": "2026-06-01T00:00:00Z"},
  "createdAt": {"S": "'"$NOW"'"}
}'

echo "  ✓ Billing data seeded"

# ─── Seed Audit Log ───────────────────────────────────────────────────

aws dynamodb put-item --table-name "${STACK}-audit-logs" --item '{
  "tenantId": {"S": "tenant-001"},
  "tenantId#userId": {"S": "tenant-001#user-admin-001"},
  "SK": {"S": "'"$NOW"'#seed-event"},
  "action": {"S": "TENANT_CREATED"},
  "resource": {"S": "tenants"},
  "resourceId": {"S": "tenant-001"},
  "ipAddress": {"S": "127.0.0.1"},
  "userAgent": {"S": "localstack-seed"},
  "createdAt": {"S": "'"$NOW"'"}
}'

echo "  ✓ Audit log seeded"

echo ""
echo "  ✅ Database seeding complete!"
echo "  Total records: 3 tenants, 3 users, 2 billing items, 1 audit log"
