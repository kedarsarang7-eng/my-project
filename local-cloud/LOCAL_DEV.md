# 🏗️ DukanX Local Development Guide

> Complete guide to running the entire DukanX platform locally with **LocalStack** (AWS emulation) and **Keycloak** (Cognito replacement).

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    LOCAL DEVELOPMENT STACK                      │
├─────────────────┬───────────────────────────────────────────────┤
│ LocalStack :4566│ DynamoDB, S3, Lambda, API Gateway,            │
│                 │ SQS, SNS, EventBridge, SecretsManager         │
├─────────────────┼───────────────────────────────────────────────┤
│ Keycloak :8080  │ Replaces Cognito (User Pools, JWT, Groups,    │
│                 │ OIDC, PKCE, Custom Claims)                    │
├─────────────────┼───────────────────────────────────────────────┤
│ Redis :6379     │ Caching & Rate Limiting                       │
├─────────────────┼───────────────────────────────────────────────┤
│ Mailhog :8025   │ Email trap (SES replacement)                  │
├─────────────────┼───────────────────────────────────────────────┤
│ my-backend :8000│ Backend API server (Serverless offline)       │
├─────────────────┼───────────────────────────────────────────────┤
│ local-backend   │ Offline Express server (:8765 loopback)       │
│ :8765           │                                               │
├─────────────────┼───────────────────────────────────────────────┤
│ Flutter App     │ Desktop/Mobile pointed to localhost            │
└─────────────────┴───────────────────────────────────────────────┘
```

## Prerequisites

### Required

| Tool | Version | Install |
|------|---------|---------|
| Docker Desktop | Latest | `winget install Docker.DockerDesktop` |
| Node.js | 22+ | `winget install OpenJS.NodeJS.LTS` |
| AWS CLI v2 | Latest | `winget install Amazon.AWSCLI` |
| Flutter | 3.x | Already installed |

### Docker Desktop Settings

- **Settings → Resources → Memory**: Minimum 6GB (8GB recommended)
- **Settings → Resources → CPUs**: Minimum 4
- **Settings → General**: Enable WSL2 backend

## Quick Start

```powershell
# 1. Start Docker services (LocalStack + Keycloak + Redis + Mailhog)
cd local-cloud
docker compose up -d

# 2. Wait for services (Keycloak takes ~60s on first boot)
# Check LocalStack:
curl http://localhost:4566/_localstack/health
# Check Keycloak:
curl http://localhost:8080/health/ready

# 3. Validate everything is working
node scripts/validate-local-env.mjs

# 4. Start the backend with local env
cd ../my-backend
# Option A: use dotenv
NODE_ENV=local npx dotenv -e .env.local -- npx ts-node src/server.ts
# Option B: set env vars manually
$env:USE_LOCALSTACK="true"; $env:AUTH_PROVIDER="keycloak"; npm run dev

# 5. Run Flutter app in local mode
cd ../Dukan_x
flutter run -d windows --dart-define=DUKANX_ENV=dev
```

## Services & Ports

| Service | Port | URL | Credentials |
|---------|------|-----|-------------|
| LocalStack | 4566 | http://localhost:4566 | `test` / `test` |
| Keycloak Admin | 8080 | http://localhost:8080 | `admin` / `admin123` |
| Keycloak OIDC | 8080 | http://localhost:8080/realms/dukanx | - |
| Redis | 6379 | redis://localhost:6379 | - |
| Mailhog UI | 8025 | http://localhost:8025 | - |
| Mailhog SMTP | 1025 | smtp://localhost:1025 | - |
| Backend API | 8000 | http://localhost:8000 | JWT required |
| Local Backend | 8765 | http://127.0.0.1:8765 | License key |

## Test Users (Keycloak)

All users are auto-created on first Keycloak startup via realm import.

| Username | Password | Tenant | Vertical | Role | Plan |
|----------|----------|--------|----------|------|------|
| `owner_test_001` | `Test@1234` | tenant-001 | electronics | superadmin | premium |
| `owner_test_002` | `Test@1234` | tenant-002 | fuelStation | admin | pro |
| `staff_test_001` | `Staff@1234` | tenant-001 | electronics | staff | premium |
| `school_admin_001` | `School@1234` | tenant-school-001 | school | superadmin | premium |
| `trial_user_001` | `Trial@1234` | tenant-003 | clinic | admin | basic (trial) |
| `customer_test_001` | `Cust@1234` | tenant-001 | - | customer | - |

## Getting a JWT Token

```bash
# Get token from Keycloak (Resource Owner Password flow)
curl -X POST http://localhost:8080/realms/dukanx/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=dukanx-flutter-app" \
  -d "username=owner_test_001" \
  -d "password=Test@1234"

# Use the access_token in API calls:
curl http://localhost:8000/tenants \
  -H "Authorization: Bearer <ACCESS_TOKEN>"
```

## How Auth Works Locally

### Production (AWS)
```
Flutter → Cognito SDK → Cognito User Pool → JWT (custom:tenant_id, custom:role)
Backend → aws-jwt-verify → Cognito JWKS → Verified claims
```

### Local (Keycloak)
```
Flutter → HTTP → Keycloak OIDC → JWT (custom:tenant_id, custom:role via mappers)
Backend → jose/JWKS → Keycloak JWKS → Same verified claims
```

The Keycloak realm includes **protocol mappers** that emit JWT claims in the same `custom:*` format as Cognito custom attributes. This means the backend auth middleware works identically in both modes — the only difference is which JWKS endpoint is queried.

## DynamoDB Tables

All tables are created automatically by `init/01-create-resources.sh` with the `dukan-saas-dev-` prefix:

| Table | Primary Key | GSIs |
|-------|------------|------|
| `dukan-saas-dev-auth-sessions` | `sessionId` (HASH) | - |
| `dukan-saas-dev-tenants` | `tenantId` (HASH) | GSI_Plan, GSI_Slug, GSI_Owner |
| `dukan-saas-dev-users` | `tenantId#userId` (HASH) | GSI_Email, GSI_TenantRole |
| `dukan-saas-dev-billing` | `tenantId` (HASH) + `SK` (RANGE) | GSI_BillingStatus |
| `dukan-saas-dev-audit-logs` | `tenantId` (HASH) + `SK` (RANGE) | GSI_UserAudit |
| `dukan-saas-dev-customer-invoices` | `PK` (HASH) + `SK` (RANGE) | GSI_Customer |
| `dukan-saas-dev-customer-ledger` | `PK` (HASH) + `SK` (RANGE) | GSI_CustomerLedger |
| `dukan-saas-dev-customer-payments` | `PK` (HASH) + `SK` (RANGE) | GSI_Customer, GSI_Vendor |
| `dukan-saas-dev-customer-notifications` | `PK` (HASH) + `SK` (RANGE) | - |
| `dukan-saas-dev-ws-connections` | `connectionId` (HASH) | GSI_Customer |

## S3 Buckets

| Bucket | Purpose |
|--------|---------|
| `dukan-saas-dev-uploads` | Tenant file uploads |
| `dukan-saas-dev-exports` | Report exports |
| `dukan-saas-dev-barcode-labels` | Barcode label PDFs |

## Commands Reference

### Docker Services

```powershell
# Start all services
docker compose -f local-cloud/docker-compose.yml up -d

# Stop all services (preserves data)
docker compose -f local-cloud/docker-compose.yml down

# Stop and delete all data
docker compose -f local-cloud/docker-compose.yml down -v

# View logs
docker compose -f local-cloud/docker-compose.yml logs -f localstack
docker compose -f local-cloud/docker-compose.yml logs -f keycloak

# Restart a specific service
docker compose -f local-cloud/docker-compose.yml restart keycloak
```

### DynamoDB CLI

```powershell
# List all tables
aws --endpoint-url=http://localhost:4566 --region ap-south-1 dynamodb list-tables

# Scan a table
aws --endpoint-url=http://localhost:4566 --region ap-south-1 dynamodb scan --table-name dukan-saas-dev-tenants

# Put an item
aws --endpoint-url=http://localhost:4566 --region ap-south-1 dynamodb put-item --table-name dukan-saas-dev-tenants --item '{"tenantId":{"S":"test"}}'
```

### Validation

```powershell
# Full validation
node local-cloud/scripts/validate-local-env.mjs

# Quick smoke test
node local-cloud/scripts/smoke-test.mjs

# Get auth token
node local-cloud/scripts/local-auth.mjs
```

## Troubleshooting

### Keycloak Won't Start
- **Symptom**: Container restarts or health check fails
- **Fix**: Ensure port 8080 is free (`netstat -ano | findstr :8080`)
- **Fix**: Give it more time on first boot (imports realm on startup)
- **Fix**: Check logs: `docker compose logs keycloak`

### "MODULE_NOT_FOUND: jose"
- **Symptom**: Auth middleware fails in local mode
- **Fix**: Install jose: `cd my-backend && npm install jose`
- **Note**: Without jose, tokens are decoded but not cryptographically verified (safe for local dev)

### DynamoDB Tables Missing
- **Symptom**: 400 errors when calling API
- **Fix**: Check if init script ran: `docker compose logs localstack | grep "DynamoDB"`
- **Fix**: Re-run init: `docker compose restart localstack` or manually run `bash local-cloud/init/01-create-resources.sh`

### "COGNITO_USER_POOL_ID is required"
- **Symptom**: Backend won't start
- **Fix**: Use `.env.local` not `.env`: `npx dotenv -e .env.local -- npx ts-node src/server.ts`

### Keycloak Token Missing tenant_id
- **Symptom**: 403 "Token missing tenantId claim"
- **Fix**: Check that Keycloak user has `tenantId` attribute set
- **Fix**: Check that the client has the protocol mappers configured (realm import should handle this)

### LocalStack Data Lost After Restart
- **Symptom**: Tables/buckets gone after Docker restart
- **Fix**: Ensure `PERSISTENCE=1` is set in docker-compose
- **Fix**: Check volume mount: `docker volume ls | grep dukan`

### Low RAM / Slow Machine
- **Use** `docker-compose.override.yml` to reduce resource usage
- **Disable** optional services: `docker compose up localstack keycloak redis -d`

## Environment Modes

| Mode | NODE_ENV | USE_LOCALSTACK | AUTH_PROVIDER | DynamoDB | Auth |
|------|----------|----------------|---------------|----------|------|
| **Local** | `local` | `true` | `keycloak` | LocalStack :4566 | Keycloak :8080 |
| **Development** | `development` | `false` | `cognito` | AWS (dev account) | Cognito |
| **Staging** | `staging` | `false` | `cognito` | AWS (staging) | Cognito |
| **Production** | `production` | `false` | `cognito` | AWS (prod) | Cognito |
