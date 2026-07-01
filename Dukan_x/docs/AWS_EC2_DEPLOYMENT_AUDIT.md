# DukanX — AWS EC2 Production Deployment Audit

> Generated: 2026-02-16 | Target: AWS EC2 Free Tier (t2.micro)

## Architecture Overview

| Backend | Port | Runtime | Purpose |
|---------|------|---------|---------|
| `sls/backend` | 4000 | Express (Node.js) | Admin Panel + Licensing |
| `sls/app-backend` | 5000 | Express (Node.js) | Customer App + Staff App + RBAC |
| `my-backend` | 8000 | Serverless Lambda | Vendor-side billing, inventory, sync |

All three backends share **one PostgreSQL database** and **one Cognito User Pool**.

---

## Audit Status Table

### 1. AWS SDK

| Feature | sls/backend | sls/app-backend | my-backend |
|---------|-------------|-----------------|------------|
| `@aws-sdk/client-cognito-identity-provider` | ✅ v3.990 | ✅ v3.990 | ✅ v3.500 |
| `@aws-sdk/client-dynamodb` | ✅ v3.989 | ❌ Not needed | ❌ Not needed |
| `@aws-sdk/client-s3` | ❌ **MISSING** | ❌ **MISSING** | ✅ v3.500 |
| `@aws-sdk/s3-request-presigner` | ❌ **MISSING** | ❌ **MISSING** | ✅ v3.500 |
| `@aws-sdk/client-sns` | ❌ Not needed | ❌ Not needed | ✅ v3.989 |
| `aws-jwt-verify` | ✅ v4.0.1 | ✅ v4.0.1 | ✅ v4.0.1 |

### 2. Authentication

| Feature | sls/backend | sls/app-backend | my-backend |
|---------|-------------|-----------------|------------|
| Cognito JWT middleware (admin) | ✅ `cognitoAuth.ts` | ✅ `cognitoAuth.ts` | ✅ `cognito-auth.ts` |
| Cognito JWT middleware (customer) | ✅ `cognitoCustomerAuth.ts` | ✅ `cognitoCustomerAuth.ts` | N/A |
| All controllers use Cognito | ✅ (11/11) | ✅ (6/6) | ✅ (all handlers) |
| Legacy Firebase `customerAuth.ts` | ⚠️ File exists, **NOT imported** | ❌ No file | ❌ No file |
| Legacy custom JWT `auth.ts` | ⚠️ Still imported by `authController.ts` | ❌ No file | ❌ No file |
| `firebase-admin` dependency | ⚠️ In package.json (dead) | ✅ Not present | ⚠️ In package.json |

### 3. Database

| Feature | sls/backend | sls/app-backend | my-backend |
|---------|-------------|-----------------|------------|
| PostgreSQL (`pg`) | ✅ | ✅ | ✅ |
| Connection via env var | ✅ `DATABASE_URL` | ✅ `DATABASE_URL` | ✅ `DB_HOST` etc. |
| SSL toggle | ✅ `DB_SSL` | ✅ `DB_SSL` | ✅ `DB_SSL` |
| Pool size | ⚠️ **20** (too high for EC2) | ⚠️ **20** (too high for EC2) | ✅ **5** |
| Graceful pool drain on shutdown | ❌ **MISSING** | ❌ **MISSING** | N/A (Lambda) |
| RLS tenant isolation | ✅ | ✅ | ✅ |

### 4. File Storage (S3)

| Feature | sls/backend | sls/app-backend | my-backend |
|---------|-------------|-----------------|------------|
| S3 storage service | ❌ **MISSING** | ❌ **MISSING** | ✅ `storage.service.ts` |
| S3 signed URL endpoint | ❌ **MISSING** | ❌ **MISSING** | ✅ `handlers/storage.ts` |
| Local file upload (multer) | ✅ Not present | ✅ Not present | ✅ Not present |
| S3 env vars in .env | N/A | N/A | ✅ |

### 5. Environment Configuration

| Feature | sls/backend | sls/app-backend | my-backend |
|---------|-------------|-----------------|------------|
| `.env.example` | ❌ **MISSING** | ✅ Exists | ✅ Exists |
| S3 vars in .env template | ❌ | ❌ | ✅ |
| Production DB URL support | ✅ `DATABASE_URL` | ✅ `DATABASE_URL` | ✅ `DB_HOST` |
| Real creds in `.env` committed | N/A | N/A | 🔴 **CRITICAL** |

### 6. Production Infrastructure

| Feature | Status | Action |
|---------|--------|--------|
| PM2 `ecosystem.config.js` | ❌ **MISSING** | Create for EC2 |
| Nginx reverse proxy config | ❌ **MISSING** | Create template |
| Health check endpoints | ✅ Both backends have `/api/health` | — |
| CORS configuration | ✅ Configurable via env | — |
| Rate limiting | ✅ `express-rate-limit` on both | — |
| Helmet security headers | ✅ Both backends | — |
| Compression | ✅ Both backends | — |
| Trust proxy | ✅ Both backends (`trust proxy: 1`) | — |
| Winston logging | ✅ Both backends | — |

---

## 🔴 Critical Security Issue

**`my-backend/.env` contains real production database credentials committed to Git:**
- RDS hostname, username, password, Cognito Pool ID, S3 bucket name
- **Action:** Immediately rotate credentials, add `.env` to `.gitignore`, use `git filter-branch` or BFG to purge from history

---

## Implementation Summary

| # | Item | Files Created/Modified |
|---|------|----------------------|
| 1 | `.env.example` for `sls/backend` | Created: `sls/backend/.env.example` |
| 2 | S3 storage service for Express backends | Created: `sls/backend/src/services/storageService.ts` |
| 3 | S3 signed-URL controller | Created: `sls/backend/src/controllers/storageController.ts` |
| 4 | S3 packages added | Modified: `sls/backend/package.json`, `sls/app-backend/package.json` |
| 5 | DB pool size reduced (20→8) | Modified: `sls/backend/src/config/database.ts`, `sls/app-backend/src/config/database.ts` |
| 6 | Graceful shutdown + pool drain | Modified: `sls/backend/src/app.ts`, `sls/app-backend/src/app.ts` |
| 7 | PM2 ecosystem config | Created: `ecosystem.config.js` (project root) |
| 8 | Nginx config template | Created: `deploy/nginx.conf` |
| 9 | Dead Firebase code removed | Modified: `sls/backend/package.json` (removed `firebase-admin`) |
| 10 | Updated `.env.example` for app-backend | Modified: `sls/app-backend/.env.example` |
