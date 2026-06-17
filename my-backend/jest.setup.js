process.env.REDIS_URL = 'redis://localhost:6379';
process.env.AWS_REGION = 'ap-south-1';
process.env.JWT_SECRET = 'test-secret';
process.env.S3_BUCKET_NAME = 'test-bucket';
process.env.INTERNAL_API_SECRET = 'test-internal-secret-32chars-padded!!';
process.env.MANIFEST_JWT_SECRET = 'test-manifest-jwt-secret-32chars!!xx';
process.env.DYNAMODB_TABLE = 'DukanX-Table';
process.env.COGNITO_USER_POOL_ID = 'us-east-1_TestPool';
process.env.COGNITO_CLIENT_ID = 'test-client-id';
process.env.NODE_ENV = 'development';

/** Avoid async CloudWatch/logger work racing test teardown */
jest.mock('./src/middleware/cloudwatch-logger', () => ({
    logRequest: jest.fn().mockResolvedValue(undefined),
    logAuthFailure: jest.fn().mockResolvedValue(undefined),
}));

/** Mock software lock to prevent external DB calls and dynamic imports in tests */
jest.mock('./src/middleware/software-lock', () => ({
    checkSoftwareLock: jest.fn().mockResolvedValue({ allowed: true, lockLevel: 'none', userMessage: '' }),
    withSoftwareLock: (handler) => handler,
    LockLevel: {
        NONE: 'none',
        WARNING: 'warning',
        PARTIAL: 'partial',
        FULL: 'full',
    },
}));
