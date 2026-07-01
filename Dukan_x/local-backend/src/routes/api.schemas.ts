// ============================================================================
// api.schemas — request-input schemas for the Local_Backend REST surface
// ============================================================================
// Requirement 17.8 / 17.15: every request input is validated against a schema
// before processing, and schema-invalid input is rejected with no persistence.
//
// Each schema below mirrors the input shape of the corresponding AWS contract
// route (see my-backend route map and the contracts in src/contracts). They are
// intentionally minimal — they assert the SHAPE the handler depends on (types,
// required fields, simple bounds) without re-encoding business rules that live
// deeper in the domain layer.
//
// Notes on Express input types:
//   • req.params values are always strings → path-id schemas use `string`.
//   • req.query values are strings (or arrays) → numeric query fields are
//     validated as patterned strings rather than `integer`, so we never need to
//     coerce before validating.
//   • req.body is parsed JSON → body fields use their real JSON types.
// ============================================================================

import { RequestSchema } from '../middleware/schema';

/** A non-empty path identifier (UUID or opaque id) carried in `:id`. */
const idParam = { type: 'string', required: true, nonEmpty: true, maxLength: 128 } as const;

/** Optional numeric query field (Express delivers query values as strings). */
const numericQuery = { type: 'string', pattern: /^\d+$/ } as const;

/** Shared, all-optional pagination query (page/limit/sort), as strings. */
const paginationQuery = {
    page: numericQuery,
    limit: numericQuery,
    sortBy: { type: 'string', maxLength: 64 },
    sortOrder: { type: 'string', enum: ['ASC', 'DESC', 'asc', 'desc'] },
} as const;

/**
 * Schemas keyed by `METHOD path` — the exact method+path registered in
 * api.routes.ts. A route without an entry here takes no meaningful input and is
 * validated against an empty schema (still routed through the middleware so the
 * "validate every input" guarantee holds uniformly).
 */
export const API_REQUEST_SCHEMAS: Record<string, RequestSchema> = {
    // ── License ──────────────────────────────────────────────────────────────
    'POST /license/validate': {
        body: {
            licenseKey: { type: 'string', required: true, nonEmpty: true, maxLength: 4096 },
        },
    },
    'POST /license/activate': {
        body: {
            licenseKey: { type: 'string', required: true, nonEmpty: true, maxLength: 4096 },
            fingerprint: { type: 'object', required: true },
        },
    },
    'GET /license/status': {},

    // ── Dashboard ──────────────────────────────────────────────────────────────
    'GET /dashboard': { query: { ...paginationQuery } },

    // ── Inventory ──────────────────────────────────────────────────────────────
    'GET /inventory': { query: { ...paginationQuery, search: { type: 'string', maxLength: 256 } } },
    'POST /inventory': {
        body: {
            name: { type: 'string', required: true, nonEmpty: true, maxLength: 256 },
            sku: { type: 'string', maxLength: 128 },
            price: { type: 'number', min: 0 },
            quantity: { type: 'integer', min: 0 },
        },
    },
    'PUT /inventory/:id': {
        params: { id: idParam },
        body: {
            name: { type: 'string', nonEmpty: true, maxLength: 256 },
            sku: { type: 'string', maxLength: 128 },
            price: { type: 'number', min: 0 },
            quantity: { type: 'integer', min: 0 },
        },
    },
    'DELETE /inventory/:id': { params: { id: idParam } },

    // ── Invoices ──────────────────────────────────────────────────────────────
    'POST /invoices': {
        body: {
            items: { type: 'array', required: true, minLength: 1 },
            customerId: { type: 'string', maxLength: 128 },
        },
    },
    'POST /invoices/:id/finalize': { params: { id: idParam } },
    'POST /invoices/:id/void': { params: { id: idParam } },
    'POST /invoices/:id/send': { params: { id: idParam } },

    // ── Stock ─────────────────────────────────────────────────────────────────
    'POST /stock/lookup-barcode': {
        body: {
            barcode: { type: 'string', required: true, nonEmpty: true, maxLength: 128 },
        },
    },
    'POST /stock/add': {
        body: {
            productId: { type: 'string', required: true, nonEmpty: true, maxLength: 128 },
            quantity: { type: 'integer', required: true, min: 1 },
        },
    },

    // ── Payments ──────────────────────────────────────────────────────────────
    'GET /payments': { query: { ...paginationQuery } },
    'GET /payments/:id': { params: { id: idParam } },
    'POST /payments': {
        body: {
            amount: { type: 'number', required: true, min: 0 },
            method: { type: 'string', maxLength: 32 },
            invoiceId: { type: 'string', maxLength: 128 },
        },
    },

    // ── Customers ──────────────────────────────────────────────────────────────
    'GET /customers': { query: { ...paginationQuery, search: { type: 'string', maxLength: 256 } } },
    'GET /customers/:id/ledger': { params: { id: idParam } },

    // ── Products ──────────────────────────────────────────────────────────────
    'GET /products': { query: { ...paginationQuery, search: { type: 'string', maxLength: 256 } } },

    // ── Storage (S3 equivalent) ─────────────────────────────────────────────
    'GET /storage/signed-url': {
        query: {
            key: { type: 'string', required: true, nonEmpty: true, maxLength: 1024 },
        },
    },

    // ── Sync (inert this version) ───────────────────────────────────────────
    'POST /sync/push': {
        body: {
            changes: { type: 'array', required: true },
        },
    },
    'POST /sync/pull': {
        body: {
            since: { type: 'string', maxLength: 64 },
        },
    },

    // ── Reports ─────────────────────────────────────────────────────────────
    'GET /reports/sales': {
        query: { from: { type: 'string', maxLength: 32 }, to: { type: 'string', maxLength: 32 } },
    },
    'GET /reports/gstr1': {
        query: { month: { type: 'string', maxLength: 16 } },
    },
};
