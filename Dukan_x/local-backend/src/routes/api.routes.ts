// ============================================================================
// API Routes — REST contract stubs mirroring the AWS backend
// ============================================================================
// Requirements 3.2 / 4.2: the Local_Backend serves the SAME REST contracts the
// AWS backend exposes (Lambda + REST API Gateway equivalent), via Express
// routes bound to the loopback interface.
//
// The route paths and HTTP methods below mirror my-backend's Express route map
// (see Dukan_x/my-backend/src/server.ts). Each handler currently returns the
// standard NOT_IMPLEMENTED envelope — the SHAPE (path, method, response
// envelope) is the deliverable of this scaffold task; the BEHAVIOR is filled
// in by later tasks (auth, gating, store, queue, sync, reports, etc.).
//
// Every route here is mounted behind requireAuth in server.ts; only /health
// (a separate router) is public.
//
// Req 17.8 / 17.15: every route is registered WITH schema-validation middleware
// (validateRequest) ahead of its handler, so request input is validated before
// any processing/persistence and schema-invalid input is rejected (with no
// store write) via the standard VALIDATION_ERROR envelope. Routes whose schema
// is empty still pass through the middleware, keeping the "validate every
// input" guarantee uniform across the surface.
// ============================================================================

import { Router, Request, Response } from 'express';
import * as response from '../utils/response';
import { validateRequest } from '../middleware/validate-request';
import { API_REQUEST_SCHEMAS } from './api.schemas';

/**
 * Register a stub that documents the mirrored contract, with schema validation
 * (Req 17.8 / 17.15) applied BEFORE the handler. The schema is resolved by the
 * `METHOD path` key; a route with no declared schema is validated against an
 * empty schema so the validation stage is always present.
 */
function stub(
    router: Router,
    method: 'get' | 'post' | 'put' | 'delete' | 'patch',
    path: string,
    feature: string,
): void {
    const schema = API_REQUEST_SCHEMAS[`${method.toUpperCase()} ${path}`] ?? {};
    router[method](path, validateRequest(schema), (_req: Request, res: Response) => {
        response.notImplemented(res, feature);
    });
}

export function buildApiRouter(): Router {
    const router = Router();

    // ── Auth (Cognito equivalent → Offline_Auth_Service) ────────────────────
    // Auth endpoints are PUBLIC (pre-token) and live in auth.routes.ts, mounted
    // before requireAuth — a caller cannot hold a JWT before logging in.

    // ── License (activation/validation/status; signing layer in task 3) ─────
    stub(router, 'post', '/license/validate', 'license.validate');
    stub(router, 'post', '/license/activate', 'license.activate');
    stub(router, 'get', '/license/status', 'license.status');

    // ── Dashboard ───────────────────────────────────────────────────────────
    stub(router, 'get', '/dashboard', 'dashboard.get');

    // ── Inventory ─────────────────────────────────────────────────────────────
    stub(router, 'get', '/inventory', 'inventory.list');
    stub(router, 'post', '/inventory', 'inventory.create');
    stub(router, 'put', '/inventory/:id', 'inventory.update');
    stub(router, 'delete', '/inventory/:id', 'inventory.delete');

    // ── Invoices ──────────────────────────────────────────────────────────────
    stub(router, 'post', '/invoices', 'invoices.create');
    stub(router, 'post', '/invoices/:id/finalize', 'invoices.finalize');
    stub(router, 'post', '/invoices/:id/void', 'invoices.void');
    stub(router, 'post', '/invoices/:id/send', 'invoices.send');

    // ── Stock ─────────────────────────────────────────────────────────────────
    stub(router, 'post', '/stock/lookup-barcode', 'stock.lookupBarcode');
    stub(router, 'post', '/stock/add', 'stock.add');

    // ── Payments (CRUD) ─────────────────────────────────────────────────────
    stub(router, 'get', '/payments', 'payments.list');
    stub(router, 'get', '/payments/:id', 'payments.get');
    stub(router, 'post', '/payments', 'payments.record');

    // ── Customers ─────────────────────────────────────────────────────────────
    stub(router, 'get', '/customers', 'customers.list');
    stub(router, 'get', '/customers/:id/ledger', 'customers.ledger');

    // ── Products ──────────────────────────────────────────────────────────────
    stub(router, 'get', '/products', 'products.list');

    // ── Storage (S3 equivalent → Object_Store, task 8) ──────────────────────
    stub(router, 'get', '/storage/signed-url', 'storage.signedUrl');

    // ── Sync (Sync_Foundation, task 11 — inert this version) ────────────────
    stub(router, 'post', '/sync/push', 'sync.push');
    stub(router, 'post', '/sync/pull', 'sync.pull');

    // ── Reports ───────────────────────────────────────────────────────────────
    stub(router, 'get', '/reports/sales', 'reports.sales');
    stub(router, 'get', '/reports/gstr1', 'reports.gstr1');

    return router;
}
