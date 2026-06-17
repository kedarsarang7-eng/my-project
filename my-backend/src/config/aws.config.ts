// ============================================================================
// AWS Service Configuration — Cognito, S3
// ============================================================================
import { config } from './environment';

export const cognitoConfig = {
    userPoolId: config.cognito.userPoolId,
    region: config.cognito.region,

    // Legacy combined client (backward compat during migration)
    clientId: config.cognito.clientId,

    // Per-platform clients (preferred)
    desktopClientId: config.cognito.desktopClientId,
    mobileClientId: config.cognito.mobileClientId,
    adminClientId: config.cognito.adminClientId,

    // Identity Pool
    identityPoolId: config.cognito.identityPoolId,

    // All valid client IDs the backend should accept tokens from
    get allClientIds(): string[] {
        return config.cognito.allClientIds;
    },
};

export const s3Config = {
    bucketName: config.s3.bucketName,
    region: config.s3.region,
    // HIGH FIX: Reduced from 15 min (900s) to 5 min (300s) for security
    // Leaked URLs now expire much faster, limiting exposure window
    signedUrlExpiry: config.s3.signedUrlExpiry,
};

export const appConfig = {
    stage: config.app.env,
    logLevel: config.app.logLevel,
};

/**
 * Wraps AWS Client configuration options to automatically inject LocalStack
 * endpoint, credentials, and settings when running in local development mode.
 */
export function configureAwsClient<T extends Record<string, any>>(options: T): T {
    if (config.local.isLocal) {
        return {
            ...options,
            endpoint: config.local.localStackEndpoint,
            credentials: {
                accessKeyId: 'test',
                secretAccessKey: 'test',
            },
            // Force path style for local S3 buckets (needed for LocalStack)
            forcePathStyle: true,
        };
    }
    return options;
}

