// =============================================================================
// LocalizedResponse — locale-aware API response builders
// =============================================================================
// Drop-in replacements for response.ts helpers that include translated messages.
//
// Usage in handlers:
//   import { localizedResponse as lr } from '../i18n/localized-response';
//   return lr.success(data, getCurrentLocale());
//   return lr.notFound(getCurrentLocale(), 'Invoice');
//   return lr.badRequest(getCurrentLocale(), 'billing.stockInsufficient', vars);
// =============================================================================

import { APIGatewayProxyResultV2 } from 'aws-lambda';
import * as baseResponse from '../utils/response';
import { t, i18n, TranslationVars } from './i18n.service';
import { getCurrentLocale } from './i18n.middleware';

// ---------------------------------------------------------------------------
// Success responses
// ---------------------------------------------------------------------------

export function success<T>(
    data: T,
    localeOrKey: string = 'en',
    messageKey = 'common.success',
    vars?: TranslationVars,
    statusCode = 200,
): APIGatewayProxyResultV2 {
    const locale = localeOrKey || getCurrentLocale();
    const message = t(messageKey, locale, vars);
    return {
        statusCode,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            status: 'success',
            code: statusCode,
            message,
            success: true,
            data,
            meta: { timestamp: new Date().toISOString() },
        }),
    };
}

export function paginated<T>(
    data: T[],
    total: number,
    page: number,
    limit: number,
    locale?: string,
): APIGatewayProxyResultV2 {
    return baseResponse.paginated(data, total, page, limit);
}

// ---------------------------------------------------------------------------
// Error responses — auto-localized
// ---------------------------------------------------------------------------

export function notFound(locale: string, resource: string): APIGatewayProxyResultV2 {
    return baseResponse.error(
        404,
        'NOT_FOUND',
        i18n.notFound(locale, resource),
    );
}

export function conflict(locale: string, resource: string): APIGatewayProxyResultV2 {
    return baseResponse.error(
        409,
        'CONFLICT',
        i18n.conflict(locale, resource),
    );
}

export function forbidden(locale: string): APIGatewayProxyResultV2 {
    return baseResponse.error(403, 'FORBIDDEN', i18n.forbidden(locale));
}

export function unauthorized(locale: string): APIGatewayProxyResultV2 {
    return baseResponse.error(401, 'UNAUTHORIZED', i18n.unauthorized(locale));
}

export function limitExceeded(locale: string): APIGatewayProxyResultV2 {
    return baseResponse.error(429, 'LIMIT_EXCEEDED', i18n.limitExceeded(locale));
}

export function planExpired(locale: string): APIGatewayProxyResultV2 {
    return baseResponse.error(402, 'PLAN_EXPIRED', i18n.planExpired(locale));
}

export function stockInsufficient(
    locale: string,
    productName: string,
    available: number,
    unit: string,
): APIGatewayProxyResultV2 {
    return baseResponse.error(
        400,
        'INSUFFICIENT_STOCK',
        i18n.stockInsufficient(locale, productName, available, unit),
    );
}

export function expiredProduct(locale: string, productName: string): APIGatewayProxyResultV2 {
    return baseResponse.error(
        400,
        'EXPIRED_PRODUCT',
        i18n.expiredProduct(locale, productName),
    );
}

export function badRequest(
    locale: string,
    messageKey: string,
    vars?: TranslationVars,
): APIGatewayProxyResultV2 {
    return baseResponse.error(
        400,
        'BAD_REQUEST',
        t(messageKey, locale, vars),
    );
}

export function validationError(
    locale: string,
    errors: Array<{ field: string; message: string }>,
): APIGatewayProxyResultV2 {
    return baseResponse.error(
        422,
        'VALIDATION_ERROR',
        t('common.badRequest', locale),
        { errors },
    );
}

export function serverError(locale: string): APIGatewayProxyResultV2 {
    return baseResponse.error(500, 'INTERNAL_ERROR', i18n.serverError(locale));
}

// ---------------------------------------------------------------------------
// Convenience — uses getCurrentLocale() automatically
// ---------------------------------------------------------------------------

/** Auto-locale success: picks locale from AsyncLocalStorage context */
export function autoSuccess<T>(
    data: T,
    messageKey = 'common.success',
    vars?: TranslationVars,
    statusCode = 200,
): APIGatewayProxyResultV2 {
    return success(data, getCurrentLocale(), messageKey, vars, statusCode);
}

/** Auto-locale not found */
export function autoNotFound(resource: string): APIGatewayProxyResultV2 {
    return notFound(getCurrentLocale(), resource);
}

/** Auto-locale conflict */
export function autoConflict(resource: string): APIGatewayProxyResultV2 {
    return conflict(getCurrentLocale(), resource);
}

/** Auto-locale forbidden */
export function autoForbidden(): APIGatewayProxyResultV2 {
    return forbidden(getCurrentLocale());
}

/** Auto-locale bad request */
export function autoBadRequest(
    messageKey: string,
    vars?: TranslationVars,
): APIGatewayProxyResultV2 {
    return badRequest(getCurrentLocale(), messageKey, vars);
}

// Namespace export for drop-in usage
export const localizedResponse = {
    success,
    autoSuccess,
    paginated,
    notFound,
    autoNotFound,
    conflict,
    autoConflict,
    forbidden,
    autoForbidden,
    unauthorized,
    limitExceeded,
    planExpired,
    stockInsufficient,
    expiredProduct,
    badRequest,
    autoBadRequest,
    validationError,
    serverError,
};
