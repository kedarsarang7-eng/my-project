// ============================================================================
// validate-request — schema-validation middleware (Req 17.8 / 17.15)
// ============================================================================
// Requirement 17.8: the Local_Backend validates ALL request inputs using schema
// validation BEFORE processing them.
// Requirement 17.15: IF a request input fails schema validation, THEN the
// Local_Backend rejects the request WITHOUT persisting any data and returns an
// error response indicating the validation failure.
//
// This middleware factory turns a declarative {@link RequestSchema} into an
// Express handler that validates `req.body` / `req.query` / `req.params` and,
// on failure, short-circuits with the standard VALIDATION_ERROR envelope —
// `next()` is NEVER called, so the route handler (and therefore any store
// write) does not run. Because it is mounted per route AHEAD of every handler,
// validation always precedes persistence (the property exercised by task 17.4).
//
// It composes cleanly behind requireAuth: auth runs first (Req 17.7/17.14),
// then input validation, then the handler. Both are pure gate stages with no
// store access, so a request that fails either is rejected before any
// side effect.
// ============================================================================

import { Request, Response, NextFunction } from 'express';
import * as response from '../utils/response';
import { RequestSchema, validateRequestParts } from './schema';

/**
 * Build an Express middleware that validates the request against `schema`
 * before the route handler runs. On any validation failure it responds with the
 * VALIDATION_ERROR envelope and does NOT call `next()`, guaranteeing no
 * downstream processing or persistence occurs (Req 17.8 / 17.15).
 */
export function validateRequest(schema: RequestSchema) {
    return (req: Request, res: Response, next: NextFunction): void => {
        const result = validateRequestParts(
            { body: req.body, query: req.query, params: req.params },
            schema,
        );

        if (!result.ok) {
            // Reject before any handler/store access — nothing is persisted.
            response.validationError(res, result.errors);
            return;
        }

        next();
    };
}
