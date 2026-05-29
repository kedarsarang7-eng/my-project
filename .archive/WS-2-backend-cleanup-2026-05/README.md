# WS-2 Backend Cleanup Quarantine — 2026-05

Backend folders moved out of `Dukan_x/` (Flutter operator app) to stop them
polluting the Flutter project: `flutter analyze`, `flutter pub get`, IDE
indexing, and CI were all scanning > 1.85 GB of Node/Python/React code.

## Moved (active / canonical)

| Source | Destination | Why |
|--------|------------|-----|
| `Dukan_x/my-backend/` | `my-backend/` (repo root) | Authoritative Serverless TS backend — `serverless.yml` 179 KB, updated 2026-05-17 |

## Archived (obsolete / superseded)

| Folder | Files | Size | Reason |
|--------|-------|------|--------|
| `Dukan_x/sls/` | ~58 000 | 1.31 GB | Old multi-service SLS structure; `app-backend/`, `backend/`, `backend_backup_*/` superseded by `my-backend/`; `admin_panel/` is a stray Flutter app |
| `Dukan_x/amplify/` | ~5 000 | 13.8 MB | Amplify CLI artefacts — auth migrated to Cognito direct |
| `Dukan_x/backend/` | ~14 500 | 82 MB | Python AI backend — superseded or still active? **Verify before deleting** |
| `Dukan_x/functions/` | 6 | 0.4 MB | Legacy Firebase Cloud Functions — superseded by Lambda |
| `Dukan_x/react_dashboard/` | ~26 000 | 135 MB | Old React admin dashboard — if actively maintained move to `admin-panel/` at root |
| `Dukan_x/cloud-middleware/` | 1 | <1 MB | Single file, content unknown |
| `Dukan_x/frontend-cdn/` | ~1 000 | 17 MB | CDN-hosted frontend artefacts |
| `Dukan_x/deploy/` | 5 | <1 MB | Deployment scripts (review against `scripts/` at repo root) |

## How to finalize

1. Verify `my-backend/` at repo root deploys correctly (run `sls deploy` from there).
2. Confirm `backend/` (Python AI) is superseded or document its active usage.
3. Check `react_dashboard/` — if active, move to `admin-panel/` at repo root and set up its own CI.
4. After 2–4 weeks of stable operation, delete this archive folder.
