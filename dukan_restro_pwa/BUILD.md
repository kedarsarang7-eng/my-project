# dukan_restro_pwa — Build Guide

Customer-facing QR ordering PWA.  
Flutter Web app. Anonymous-by-default (no Cognito required for ordering).

---

## Required `--dart-define` keys

All keys must be supplied at build time. There are **no defaults** for production.

| Key | Example | Notes |
|---|---|---|
| `DUKANX_API_URL` | `https://api.dukanx.com` | API Gateway base URL, **no trailing slash** |
| `DUKANX_WS_URL` | `wss://xyz.execute-api.ap-south-1.amazonaws.com/prod` | WebSocket endpoint for live order tracking |
| `COGNITO_USER_POOL_ID` | `ap-south-1_XXXXXXX` | Cognito User Pool for restaurant customers (separate from staff pool) |
| `COGNITO_RESTRO_CLIENT_ID` | `xxxxxxxxxxxxxxxxxxxxxxxxxx` | App client ID — **no client secret** (public web client) |

> `RESTO_SCAN_JWT_SECRET` is server-side only (Lambda SSM param). Never put it in the Flutter build.

---

## Local development

```bash
flutter run -d chrome \
  --dart-define=DUKANX_API_URL=https://api-dev.dukanx.com \
  --dart-define=DUKANX_WS_URL=wss://dev-ws.execute-api.ap-south-1.amazonaws.com/dev \
  --dart-define=COGNITO_USER_POOL_ID=ap-south-1_XXXXXXX \
  --dart-define=COGNITO_RESTRO_CLIENT_ID=xxxxxxxxxxxxxxxxxxxxxxxxxx
```

## Production web build

```bash
flutter build web \
  --release \
  --dart-define=DUKANX_API_URL=https://api.dukanx.com \
  --dart-define=DUKANX_WS_URL=wss://prod-ws.execute-api.ap-south-1.amazonaws.com/prod \
  --dart-define=COGNITO_USER_POOL_ID=ap-south-1_XXXXXXX \
  --dart-define=COGNITO_RESTRO_CLIENT_ID=xxxxxxxxxxxxxxxxxxxxxxxxxx
```

Output: `build/web/` — deploy to S3 + CloudFront or any static host.

---

## Backend environment variable

Set `RESTO_SCAN_JWT_SECRET` in AWS Parameter Store or Secrets Manager:

```
/dukanx/prod/resto-scan-jwt-secret   → strong random 64-char hex
```

Or via Serverless:

```bash
aws ssm put-parameter \
  --name /dukanx/prod/RESTO_SCAN_JWT_SECRET \
  --value "$(openssl rand -hex 32)" \
  --type SecureString
```

---

## Running tests

```bash
flutter test
```

---

## Feature flags (backend)

| Flag | SSM path | Effect |
|---|---|---|
| `RESTO_V1_PUBLIC_ENABLED` | `serverless.yml` env | Gates all `/api/v1/restaurant/*` routes |
| `RESTO_SCAN_JWT_SECRET` | SSM SecureString | Must be set or scan endpoint returns 500 |
