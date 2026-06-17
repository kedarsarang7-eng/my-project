// ============================================================================
// Business Type Guard — Per-API Business Type Authorization
// ============================================================================
// CRITICAL SECURITY LAYER: Ensures that API endpoints for specific business
// types (petrol_pump, restaurant, clinic, etc.) can only be accessed by
// users whose license includes that business type.
//
// This works at the backend level — even if the UI is hacked to show
// unauthorized modules, the API will block access.
//
// ENHANCED: Now supports multi-business licenses by checking against the
// license's allowedBusinessTypes array from DynamoDB.
//
// Usage:
//   export const handler = authorizedHandler(
//       [UserRole.OWNER, UserRole.STAFF],
//       myHandlerFn,
//       { requiredBusinessType: 'petrol_pump' }
//   );
// ============================================================================

import { configureAwsClient } from '../config/aws.config';
import { BusinessType, AuthContext, normalizeBusinessType } from '../types/tenant.types';
import { logger } from '../utils/logger';
import { CloudWatchClient, PutMetricDataCommand } from '@aws-sdk/client-cloudwatch';
import { getItem, Keys } from '../config/dynamodb.config';
import { isValidBusinessType } from '../config/business-types.config';
import { config } from '../config/environment';
import { AppError } from '../utils/errors';

let _cloudwatchClient: CloudWatchClient | null = null;
function getCloudWatchClient(): CloudWatchClient {
    if (!_cloudwatchClient) _cloudwatchClient = new CloudWatchClient(configureAwsClient({ region: config.aws.region }));
    return _cloudwatchClient;
}

/**
 * Validate that the authenticated user's license includes the required business type.
 * 
 * ENHANCED: Now supports multi-business licenses by checking against the license's
 * allowedBusinessTypes array from DynamoDB. Falls back to JWT business type for
 * backward compatibility.
 *
 * @throws Error with 403 status if business type is unauthorized
 */
export async function validateBusinessType(
    auth: AuthContext,
    requiredBusinessType: BusinessType,
    correlationId: string,
    requestPath: string,
): Promise<void> {
    // Validate the required business type is supported
    if (!isValidBusinessType(requiredBusinessType)) {
        logger.error('INVALID BUSINESS TYPE CONFIGURATION', {
            requiredBusinessType,
            requestPath,
            correlationId,
        });
        throw new AppError(`Invalid business type configuration: "${requiredBusinessType}"`, 500, 'INVALID_BUSINESS_TYPE');
    }

    const normalizedRequiredType = normalizeBusinessType(requiredBusinessType);
    let isAuthorized = false;
    let allowedBusinessTypes: string[] = [];
    let licenseSource = 'jwt'; // For logging

    try {
        // TRY 1: Check license from DynamoDB (multi-business support)
        if (auth.tenantId) {
            const licenseRecord = await getItem<Record<string, any>>(
                Keys.tenantPK(auth.tenantId),
                Keys.tenantLicenseSK()
            );

            if (licenseRecord && licenseRecord.allowedBusinessTypes && Array.isArray(licenseRecord.allowedBusinessTypes)) {
                allowedBusinessTypes = licenseRecord.allowedBusinessTypes;
                isAuthorized = allowedBusinessTypes.includes(normalizedRequiredType);
                licenseSource = 'dynamodb';
                logger.debug('License validation from DynamoDB', {
                    tenantId: auth.tenantId,
                    allowedBusinessTypes,
                    requiredType: normalizedRequiredType,
                    isAuthorized,
                });
            }
        }

        // TRY 2: Fallback to JWT business type (backward compatibility)
        if (!isAuthorized && auth.businessType) {
            const normalizedUserType = normalizeBusinessType(auth.businessType);
            isAuthorized = normalizedUserType === normalizedRequiredType;
            allowedBusinessTypes = [normalizedUserType];
            licenseSource = 'jwt';
            logger.debug('License validation from JWT fallback', {
                userId: auth.sub,
                userBusinessType: normalizedUserType,
                requiredType: normalizedRequiredType,
                isAuthorized,
            });
        }

    } catch (dbError) {
        logger.warn('License database check failed, using JWT fallback', {
            tenantId: auth.tenantId,
            error: (dbError as Error).message,
            correlationId,
        });
        // Fallback to JWT business type
        const normalizedUserType = normalizeBusinessType(auth.businessType);
        isAuthorized = normalizedUserType === normalizedRequiredType;
        allowedBusinessTypes = [normalizedUserType];
        licenseSource = 'jwt_fallback';
    }

    // Final authorization check
    if (!isAuthorized) {
        logger.error('BUSINESS TYPE AUTHORIZATION FAILED', {
            userId: auth.sub,
            email: auth.email,
            tenantId: auth.tenantId,
            userBusinessType: auth.businessType,
            allowedBusinessTypes,
            requiredBusinessType: normalizedRequiredType,
            requestPath,
            correlationId,
            licenseSource,
        });

        // Emit CloudWatch metric for security monitoring
        try {
            await getCloudWatchClient().send(new PutMetricDataCommand({
                Namespace: 'DukanX/Security',
                MetricData: [{
                    MetricName: 'UnauthorizedBusinessAccess',
                    Value: 1,
                    Unit: 'Count',
                    Dimensions: [
                        { Name: 'TenantId', Value: auth.tenantId },
                        { Name: 'RequiredType', Value: normalizedRequiredType },
                        { Name: 'LicenseSource', Value: licenseSource },
                        { Name: 'AllowedTypes', Value: allowedBusinessTypes.join(',') },
                    ],
                }],
            }));
        } catch (metricErr) {
            logger.warn('Failed to emit business type guard metric', {
                error: (metricErr as Error).message,
            });
        }

        throw new AppError(
            `ACCESS_DENIED: Your license does not include access to the "${normalizedRequiredType}" business type. ` +
            `Current license includes: ${allowedBusinessTypes.join(', ') || 'none'}`,
            403,
            'BUSINESS_TYPE_NOT_LICENSED',
            {
                requiredBusinessType: normalizedRequiredType,
                allowedBusinessTypes,
                licenseSource,
            }
        );
    }

    logger.debug('Business type authorization successful', {
        userId: auth.sub,
        tenantId: auth.tenantId,
        requiredBusinessType: normalizedRequiredType,
        licenseSource,
        correlationId,
    });
}

/**
 * Options for the authorized handler, including optional business type restriction.
 */
export interface HandlerOptions {
    /** If set, the API will only be accessible to users with this business type */
    requiredBusinessType?: BusinessType;
    /** If set, the API will only be accessible to users whose plan includes this feature */
    requiredFeature?: string;
    /** If set, validates BOTH role AND plan via PermissionMatrix */
    requiredPermission?: string;
}
