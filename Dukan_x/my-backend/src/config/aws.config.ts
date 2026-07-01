// ============================================================================
// AWS Service Configuration — Cognito, S3
// ============================================================================

export const cognitoConfig = {
    userPoolId: process.env.COGNITO_USER_POOL_ID || '',
    region: process.env.COGNITO_REGION || 'us-east-1',

    // Legacy combined client (backward compat during migration)
    clientId: process.env.COGNITO_CLIENT_ID || '',

    // Per-platform clients (preferred)
    desktopClientId: process.env.COGNITO_DESKTOP_CLIENT_ID || '',
    mobileClientId: process.env.COGNITO_MOBILE_CLIENT_ID || '',
    adminClientId: process.env.COGNITO_ADMIN_CLIENT_ID || '',

    // Identity Pool
    identityPoolId: process.env.COGNITO_IDENTITY_POOL_ID || '',

    // All valid client IDs the backend should accept tokens from
    get allClientIds(): string[] {
        return [
            this.clientId,
            this.desktopClientId,
            this.mobileClientId,
            this.adminClientId,
        ].filter(Boolean);
    },
};

export const s3Config = {
    bucketName: process.env.S3_BUCKET_NAME || 'bizmate-tenant-storage',
    region: process.env.S3_REGION || 'us-east-1',
    signedUrlExpiry: 900, // 15 minutes
};

export const appConfig = {
    stage: process.env.NODE_ENV || 'development',
    logLevel: process.env.LOG_LEVEL || 'info',
};
