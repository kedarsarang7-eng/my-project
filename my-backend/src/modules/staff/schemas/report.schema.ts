// ============================================================================
// Staff Module — Report & Search Schemas (Task 13.2)
// ============================================================================
// Zod validation schemas for:
//   • Report export requests (format, entity type, date range)
//   • Global search requests (query, entity types, limit)
//   • Saved filter CRUD (name, entity types, field filters, sort)
//
// Requirements: 9.6 (export), 9.7 (global search + saved filters).
// ============================================================================

import { z } from 'zod';

// ── Export Format ───────────────────────────────────────────────────────────

export const exportFormatSchema = z.enum(['excel', 'pdf', 'csv', 'json']);
export type ExportFormatInput = z.infer<typeof exportFormatSchema>;

// ── Report Export Request ───────────────────────────────────────────────────

export const reportExportSchema = z.object({
    /** The report/entity type to export. */
    reportType: z.enum([
        'employees',
        'departments',
        'designations',
        'attendance',
        'leave_requests',
        'leave_balances',
        'tasks',
        'payslips',
        'performance',
    ]),
    /** Export format. */
    format: exportFormatSchema,
    /** Optional date range filter (ISO dates). */
    from: z.string().optional(),
    to: z.string().optional(),
    /** Optional field filters (key-value pairs). */
    filters: z.record(z.string(), z.string()).optional(),
});

export type ReportExportInput = z.infer<typeof reportExportSchema>;

// ── Search Request ──────────────────────────────────────────────────────────

export const searchQuerySchema = z.object({
    /** The search query string. */
    q: z.string().min(1).max(200),
    /** Optional: restrict to specific entity types. */
    entityTypes: z.array(z.string()).optional(),
    /** Max results to return (default 50, max 200). */
    limit: z.number().int().min(1).max(200).optional(),
    /** Optional field-level filters. */
    filters: z.record(z.string(), z.string()).optional(),
});

export type SearchQueryInput = z.infer<typeof searchQuerySchema>;

// ── Saved Filter ────────────────────────────────────────────────────────────

export const createSavedFilterSchema = z.object({
    /** Display name for the saved filter. */
    name: z.string().min(1).max(100),
    /** Which entity types this filter targets. */
    entityTypes: z.array(z.string()).optional(),
    /** Field-level filter values. */
    filters: z.record(z.string(), z.string()).optional(),
    /** Sort configuration. */
    sort: z
        .object({
            field: z.string().min(1),
            direction: z.enum(['asc', 'desc']),
        })
        .optional(),
});

export type CreateSavedFilterInput = z.infer<typeof createSavedFilterSchema>;
