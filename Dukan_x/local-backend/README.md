# DukanX Local_Backend (packaged, offline)

Packaged Node.js/Express + Socket.io backend that powers DukanX **Offline_Lifetime_Mode**. It is
spawned by the Dart `Backend_Supervisor` inside the desktop application and bound **only** to the
Loopback_Address `127.0.0.1:8765`. It mirrors the AWS `my-backend` API contracts so the Flutter
repository layer is mode-agnostic (Requirements 3.1, 3.2, 3.4, 4.2, 4.3).

> Scope of this scaffold (task 2.1): the transport surface and contract **shapes** are real and
> runnable. Route handlers return a `NOT_IMPLEMENTED` envelope until later tasks fill in behavior
> (auth, license signing/activation, gating, object store, queue, sync, reports). Only `/health`
> is functional and public.

## Layout

```
src/
  config/
    constants.ts               Loopback host/port + service identity
    paths.ts                   OS-specific DukanX data directory resolution
  contracts/                   Shapes mirrored verbatim from my-backend
    api.contract.ts            ApiResponse envelope (== AWS)
    license.contract.ts        LicenseKeyPayload / License_Token claims (== AWS)
    websocket.contract.ts      WSEventName / WSEvent / ClientType (== AWS)
  middleware/require-auth.ts    Auth enforcement point (real verification: task 17)
  realtime/socket-gateway.ts    Socket.io gateway (WebSocket equivalent)
  routes/
    health.routes.ts           GET /health (public)
    api.routes.ts              REST contract stubs (authenticated)
  storage/
    local-queue.ts             SQS/SNS equivalent — SQLite-backed FIFO queue
  utils/
    logger.ts                  Structured logger with secret scrubbing
    response.ts                Express adapter of the AWS response envelope
  app.ts                       Express app assembly
  server.ts                    Loopback bind + lifecycle entry point
```

## Offline service equivalents

- **SQS/SNS → `storage/local-queue.ts` (`LocalQueue`)**: SQLite-backed FIFO queue. Messages are
  stored with an `AUTOINCREMENT` key so `ORDER BY id ASC` reproduces enqueue order exactly (FIFO,
  Req 4.6). Supports named topics; ordering is preserved per topic. All SQL is parameterized
  (Req 17.9/17.15) and each mutation runs in a transaction — the seam that task 8.3 extends with
  explicit atomic rollback and service-layer failure reporting (Req 4.7). Persists to
  `<DukanX data dir>/queue/local-queue.db`.

## Scripts

```bash
npm install        # install dependencies
npm run build      # type-check + emit dist/
npm run typecheck  # type-check only
npm start          # run the compiled server (dist/server.js)
npm run dev        # run from source with tsx watch
```

## Contract parity

REST routes mirror `Dukan_x/my-backend/src/server.ts` (auth, dashboard, inventory, invoices, stock,
payments, customers, products, storage, sync, reports) and the response envelope matches
`my-backend/src/utils/response.ts`. Real-time events mirror `my-backend/src/types/websocket.types.ts`.

## Security notes

- Binds to `127.0.0.1` only — never `0.0.0.0` (Req 3.4 / 17.6).
- Every endpoint except `/health` requires authentication (Req 17.7 / 17.14).
- No secrets or keys live in this package; runtime keys are derived by the Dart Security_Layer and
  passed in by the supervisor (Req 17.1). Logs scrub secret/key/license-key fields (Req 17.10).
