# AGENT_NOTES.md — QA Audit Trail

## Phase 0 — Project Report

### Stack Overview
| Component | Technology | Location |
|---|---|---|
| **Main Flutter App** | Flutter (Dart), Material 3, Riverpod | `Dukan_x/` |
| **Customer PWA** | Flutter Web, Riverpod, go_router | `dukan_restro_pwa/` |
| **Backend** | Node.js/TypeScript, Serverless Framework, AWS Lambda + DynamoDB | `my-backend/` |
| **Voice Backend** | Python, FastAPI | `voice-backend/` |
| **Lambda Functions** | Node.js (ESM) | `lambda/` |
| **Shared Packages** | Dart shared_core, dukanx_shared | `packages/` |

### Testable Web Target
- **dukan_restro_pwa** — Flutter Web PWA with a pre-built `build/web/` directory
  - This is the primary Playwright test target
  - Static assets already compiled to `dukan_restro_pwa/build/web/`
  - Routes discovered from `app.dart`:
    - `/` — ScanLandingScreen (QR scan entry, accepts `?v=VENDOR_ID&t=TABLE_ID`)
    - `/login` — LoginScreen
    - `/signup` — SignupScreen
    - `/verify` — VerificationScreen
    - `/menu` — MenuScreen (requires vendorId/tableId via `state.extra`)
    - `/bag` — OrderBagScreen
    - `/payment` — PaymentScreen
    - `/track` — OrderTrackingScreen
    - `/bill` — LiveBillScreen

### Package Manager
- Root: **npm** (package.json with `@playwright/test` already installed as devDep)
- Backend: **npm** (separate package.json in `my-backend/`)

### Dev Server
- No root-level dev server — we'll serve the Flutter web build using a static HTTP server
- PWA build output: `dukan_restro_pwa/build/web/`

### Existing Tests
- `tests/example.spec.ts` — Playwright boilerplate (tests playwright.dev site — placeholder)
- `my-backend/` — Jest tests present
- Flutter widget tests in `Dukan_x/test/`, `dukan_restro_pwa/test/`

### Config Issues Noted
- Root `package.json` has no `scripts` section (no `dev`, `build`, `test` commands)
- Root `package.json` dependencies include dubious packages: `aws`, `cli`, `graphify`, `vscode`
- Playwright config has `baseURL` and `webServer` commented out
- No static file server configured for the Flutter web build

---

## Phase 1 — Playwright Setup
(To be filled during Phase 1)

---

## Phase 2 — Static Analysis
(To be filled during Phase 2)
