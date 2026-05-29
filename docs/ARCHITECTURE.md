# DukanX — System Architecture & Backend Ownership Map

> **Last updated:** 2026-05-17 (WS-7 backend consolidation)

---

## Applications

| App | Path | Platform | Purpose |
|-----|------|----------|---------|
| **Operator Desktop App** | `Dukan_x/` | Flutter Windows/macOS | POS, billing, inventory, business-type dashboards |
| **Customer Mobile App** | `dukan_customer_app/` | Flutter Android/iOS | Ledger, invoices, payments, shop linking |
| **Restaurant PWA** | `dukan_restro_pwa/` | Flutter Web | Dine-in ordering, self-scan checkout |
| **Petrol Pump Staff App** | `staff_petrol_pump_app/` | Flutter Android | Shift management, fuel dispensing |

---

## Backend Stacks

### §4.1 — Authoritative API Backend (`my-backend/`)

**Owner:** `my-backend/` (Serverless Framework, TypeScript)  
**IaC file:** `my-backend/serverless.yml` (5,367 lines — single source of truth for all operator API routes)  
**Deployment:** `sls deploy --stage prod` from `my-backend/`  
**Region:** `ap-south-1`

This stack owns **all business logic** — billing, inventory, pharmacy, clinic, restaurant, petrol pump, clothing, hardware, bookstore, GST, reports, AI assistant, staff, and more.

Do **not** add new business features to `lambda/` — use `my-backend/src/handlers/`.

### §4.2 — Customer App + Specialized Lambda (`lambda/`)

**Owner:** `lambda/` (SAM, JavaScript ESM `.mjs`)  
**IaC file:** `template.yaml` (repo root)  
**Deployment:** `sam deploy` from repo root  

This stack owns the customer-facing APIs and a set of cross-cutting functions:

| Handler | Routes | Status |
|---------|--------|--------|
| `authHandler` | `POST /auth/refresh`, `POST /auth/logout` | **DEPRECATED** — both routes live in `my-backend/src/handlers/auth.ts` |
| `tenantHandler` | `GET/POST /tenants` | Active (SAM) |
| `userHandler` | `GET/PATCH /users/:id` | Active (SAM) |
| `billingHandler` | `POST /billing/...` | Active — verify no overlap with `my-backend/billing.ts` |
| `auditHandler` | `POST /audit` | Active (SAM) |
| `barcodeLookup` | `GET /barcode/:code` | Active (SAM) |
| `customerHandler` | `GET/PATCH /customer/v1/profile`, `GET /customer/v1/summary` | Active (SAM) |
| `customerInvoiceHandler` | `GET /customer/v1/invoices` | Active (SAM) |
| `customerLedgerHandler` | `GET /customer/v1/ledger` | Active (SAM) |
| `customerPaymentHandler` | `POST/GET /customer/v1/payments` | Active (SAM) |
| `customerNotificationHandler` | `GET/PATCH /customer/v1/notifications` | Active (SAM) |
| `customerWsHandler` | WebSocket `$connect/$disconnect/$default` | Active (SAM) |
| `customerOnboardingTrigger` | Cognito post-confirmation trigger | Active (SAM) |
| `cognitoPreTokenTrigger` | Cognito pre-token-generation trigger | Active (SAM) |
| `fuelposHandler` | Petrol pump specific routes | Active (SAM) — review vs `my-backend/pump*.ts` |
| `jewelryDashboardHandler` | Jewelry dashboard aggregations | Active (SAM) |
| `marketplace` | Marketplace routes | Active (SAM) |
| `adminStaffHandler` | Staff admin | Active (SAM) |
| `staffAuthHandler` | Staff authentication | Active (SAM) |
| `staff-attendance` | Attendance tracking | Active (SAM) |
| `staff-management` | Staff management | Active (SAM) |
| `transactionValidator` | Transaction validation | Active (SAM) |
| `rbac` | Role-based access check | Active (SAM) |

### §4.3 — Deprecated / Do Not Redeploy

| File | Reason |
|------|--------|
| `lambda/authHandler/index.mjs` | Superseded by `my-backend/src/handlers/auth.ts` — security-hardened with audit IDs and correlation IDs |

---

## §4.4 — Shared Packages

| Package | Path | Consumers |
|---------|------|-----------|
| `dukanx_shared` | `packages/dukanx_shared/` | Operator app, customer app |
| `shared_core` | `packages/shared_core/` | TBD — verify consumers |

---

## §4.5 — Infrastructure as Code

| Tool | File | Scope |
|------|------|-------|
| SAM | `template.yaml` (root) | `lambda/` handlers, API Gateway, DynamoDB tables, Cognito |
| Serverless Framework | `my-backend/serverless.yml` | `my-backend/` handlers, operator API Gateway |
| CloudFormation | `cloudformation/*.yml` | Alarms, dashboards, marketplace API gateway |

**Principle:** Each infrastructure tool manages its own resources. Do not cross-reference SAM resources from `serverless.yml` by hardcoded ARN — use SSM Parameter Store exports.

---

## §4.6 — Route Ownership Rule

> When adding or modifying a route:
> 1. Operator app features → `my-backend/src/handlers/`
> 2. Customer app features → `lambda/<handler>/index.mjs` + `template.yaml`
> 3. Shared infrastructure (Cognito triggers, DynamoDB streams) → `template.yaml` + `lambda/`
> 4. Update this table and open a PR for review.

---

## §4.7 — Removed / Quarantined Backends (2026-05 cleanup)

Previously these backends lived inside `Dukan_x/` (the Flutter operator app folder),
causing IDE indexing, `flutter analyze`, and CI to scan > 1.85 GB of non-Dart code.

| Former path | Final disposition | Verdict |
|-------------|------------------|--------|
| `Dukan_x/my-backend/` | ✅ **`my-backend/`** (repo root) | Canonical Serverless TS backend — deploy from here |
| `Dukan_x/backend/` | 📦 `.archive/WS-2-.../backend/` | **Python FastAPI + Whisper voice backend** — NOT superseded by `my-backend/src/agents/`. Serves speech-to-text + TTS for the desktop app (`temp_audio/`). See §4.8. |
| `Dukan_x/deploy/` | ✅ **`scripts/backend-ec2/`** | EC2 deploy scripts for the Python voice backend — absorbed into `scripts/backend-ec2/` |
| `Dukan_x/sls/` | 🗑️ `.archive/WS-2-.../sls/` | Old multi-service SLS repo — all routes superseded by `my-backend/`. Contains a stray `admin_panel/` Flutter app. **Safe to delete after 30 days.** |
| `Dukan_x/amplify/` | 🗑️ `.archive/WS-2-.../amplify/` | Amplify CLI artefacts — auth migrated to Cognito direct. **Safe to delete.** |
| `Dukan_x/functions/` | 🗑️ `.archive/WS-2-.../functions/` | Legacy Firebase Cloud Functions — superseded by `lambda/`. **Safe to delete.** |
| `Dukan_x/react_dashboard/` | 🗑️ `.archive/WS-2-.../react_dashboard/` | Only a compiled `dist/` build + `aws-exports.js` (no source). Cognito creds quarantined to `.archive/WS-1-.../react-dashboard-creds/`. **Safe to delete.** |
| `Dukan_x/cloud-middleware/` | 🗑️ `.archive/WS-2-.../cloud-middleware/` | Single `.env.example` file — content covered by `unified-api.env.example`. **Safe to delete.** |
| `Dukan_x/frontend-cdn/` | 📦 `.archive/WS-2-.../frontend-cdn/` | CDN-hosted frontend artefacts — review before deleting; may contain active Cloudfront config. |

---

## §4.8 — Python Voice Backend (`backend/`)

**Location:** `voice-backend/` (repo root) — promoted from archive 2026-05  
**Tech:** Python, FastAPI, Whisper (OpenAI), edge-tts, librosa  
**Purpose:** Speech-to-text + TTS for the desktop app's voice features (`Dukan_x/temp_audio/`)  
**Status:** Separate service — **NOT superseded** by `my-backend/src/agents/` (which is a TypeScript LLM agent layer).  

**Flutter integration:**  
- `AppConfig.sttBaseUrl` reads `STT_BASE_URL` from `Dukan_x/.env`  
- Set `STT_BASE_URL=http://<EC2_IP>:8000` after deploying via `scripts/backend-ec2/`  
- Falls back to `$API_BASE_URL/stt` when env var is unset

---

## §4.9 — EC2 Deploy Scripts (`scripts/backend-ec2/`)

| File | Purpose |
|------|---------|
| `ec2-setup.sh` | One-time EC2 instance bootstrap (installs Node, Python, PM2, nginx) |
| `deploy.sh` | Application deploy: clone → install → build → PM2 restart |
| `nginx.conf` | Reverse proxy config for the Python voice backend |
| `iam-policy.json` | Minimum IAM policy for the EC2 instance role |
