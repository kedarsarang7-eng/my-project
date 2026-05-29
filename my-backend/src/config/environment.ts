// ============================================================================
// Environment Configuration — Validated, Typed, Frozen
// ============================================================================
// Single source of truth for ALL environment variables in the backend.
// Validates at startup with Zod. Fail-fast on missing required vars.
//
// Usage:
//   import { config } from './config/environment';
//   const table = config.dynamodb.tableName;
//   const region = config.aws.region;
//
// NEVER access process.env directly outside this module.
// ============================================================================

import { z } from 'zod';

// ── Schema Definition ──────────────────────────────────────────────────────

const environmentSchema = z.object({
    // ── AWS Core ──────────────────────────────────────────────────────────
    AWS_REGION: z.string().min(1, 'AWS_REGION is required'),

    // ── DynamoDB ──────────────────────────────────────────────────────────
    DYNAMODB_TABLE: z.string().min(1, 'DYNAMODB_TABLE is required'),
    RATE_LIMIT_TABLE: z.string().optional(),

    // ── Cognito ───────────────────────────────────────────────────────────
    COGNITO_USER_POOL_ID: z.string().min(1, 'COGNITO_USER_POOL_ID is required'),
    COGNITO_CLIENT_ID: z.string().min(1, 'COGNITO_CLIENT_ID is required'),
    COGNITO_REGION: z.string().optional(),
    COGNITO_DESKTOP_CLIENT_ID: z.string().optional().default(''),
    COGNITO_MOBILE_CLIENT_ID: z.string().optional().default(''),
    COGNITO_ADMIN_CLIENT_ID: z.string().optional().default(''),
    COGNITO_IDENTITY_POOL_ID: z.string().optional().default(''),

    // ── S3 Storage ────────────────────────────────────────────────────────
    S3_BUCKET_NAME: z.string().min(1, 'S3_BUCKET_NAME is required'),
    S3_REGION: z.string().optional(),

    // ── WebSocket ─────────────────────────────────────────────────────────
    WEBSOCKET_API_ENDPOINT: z.string().optional().default(''),

    // ── Application ───────────────────────────────────────────────────────
    NODE_ENV: z.enum(['development', 'staging', 'production']).default('development'),
    ENVIRONMENT: z.string().optional().default('development'),
    LOG_LEVEL: z.enum(['error', 'warn', 'info', 'debug']).default('info'),

    // ── Internal Secrets ──────────────────────────────────────────────────
    INTERNAL_API_SECRET: z.string().min(32, 'INTERNAL_API_SECRET must be >= 32 chars'),
    MANIFEST_JWT_SECRET: z.string().min(32, 'MANIFEST_JWT_SECRET must be >= 32 chars'),

    // ── AI Configuration ──────────────────────────────────────────────────
    DUKANX_AI_DEFAULT_PROVIDER: z.string().optional().default('ollama'),
    DUKANX_AI_API_KEY: z.string().optional().default(''),
    ANTHROPIC_API_KEY: z.string().optional().default(''),

    // ── OpenSearch ─────────────────────────────────────────────────────────
    OPENSEARCH_ENDPOINT: z.string().optional().default(''),

    // ── Payment / Razorpay ────────────────────────────────────────────────
    RAZORPAY_KEY_ID: z.string().optional().default(''),
    RAZORPAY_KEY_SECRET: z.string().optional().default(''),
    RAZORPAY_WEBHOOK_SECRET: z.string().optional().default(''),

    // ── Razorpay Subscription Plan IDs ────────────────────────────────────
    RAZORPAY_PLAN_BASIC_MONTHLY: z.string().optional().default(''),
    RAZORPAY_PLAN_BASIC_QUARTERLY: z.string().optional().default(''),
    RAZORPAY_PLAN_BASIC_BIANNUAL: z.string().optional().default(''),
    RAZORPAY_PLAN_BASIC_YEARLY: z.string().optional().default(''),
    RAZORPAY_PLAN_BASIC_BIENNIAL: z.string().optional().default(''),
    RAZORPAY_PLAN_BASIC_TRIENNIAL: z.string().optional().default(''),
    RAZORPAY_PLAN_PRO_MONTHLY: z.string().optional().default(''),
    RAZORPAY_PLAN_PRO_QUARTERLY: z.string().optional().default(''),
    RAZORPAY_PLAN_PRO_BIANNUAL: z.string().optional().default(''),
    RAZORPAY_PLAN_PRO_YEARLY: z.string().optional().default(''),
    RAZORPAY_PLAN_PRO_BIENNIAL: z.string().optional().default(''),
    RAZORPAY_PLAN_PRO_TRIENNIAL: z.string().optional().default(''),
    RAZORPAY_PLAN_PREMIUM_MONTHLY: z.string().optional().default(''),
    RAZORPAY_PLAN_PREMIUM_QUARTERLY: z.string().optional().default(''),
    RAZORPAY_PLAN_PREMIUM_BIANNUAL: z.string().optional().default(''),
    RAZORPAY_PLAN_PREMIUM_YEARLY: z.string().optional().default(''),
    RAZORPAY_PLAN_PREMIUM_BIENNIAL: z.string().optional().default(''),
    RAZORPAY_PLAN_PREMIUM_TRIENNIAL: z.string().optional().default(''),
    RAZORPAY_PLAN_ENTERPRISE_MONTHLY: z.string().optional().default(''),
    RAZORPAY_PLAN_ENTERPRISE_QUARTERLY: z.string().optional().default(''),
    RAZORPAY_PLAN_ENTERPRISE_BIANNUAL: z.string().optional().default(''),
    RAZORPAY_PLAN_ENTERPRISE_YEARLY: z.string().optional().default(''),
    RAZORPAY_PLAN_ENTERPRISE_BIENNIAL: z.string().optional().default(''),
    RAZORPAY_PLAN_ENTERPRISE_TRIENNIAL: z.string().optional().default(''),

    // ── CORS ──────────────────────────────────────────────────────────────
    CORS_ORIGIN_1: z.string().optional().default(''),
    CORS_ORIGIN_2: z.string().optional().default(''),

    // ── Clinic / Domain-specific ──────────────────────────────────────────
    AUDIT_TABLE_NAME: z.string().optional().default(''),
    LICENSE_TABLE_NAME: z.string().optional().default(''),

    // ── Pump / ATG ────────────────────────────────────────────────────────
    PUMP_ATG_CONNECTOR_TOKEN: z.string().optional().default(''),

    // ── Fuzzy Search ──────────────────────────────────────────────────────
    FUZZY_THRESHOLD: z.string().optional().default('0.85'),

    // ── DynamoDB Local ────────────────────────────────────────────────────
    DYNAMODB_LOCAL: z.string().optional().default('false'),
    // ── Missing Injected Vars ─────────────────────────────────────────────
    CREDIT_REMINDER_MIN_AGE_DAYS: z.string().optional().default('15'),
    CREDIT_REMINDER_MIN_BALANCE_CENTS: z.string().optional().default('100'),
    CREDIT_REMINDER_SNS_TOPIC_ARN: z.string().optional().default(''),
    DLQ_URL: z.string().optional().default(''),
    EVENTBRIDGE_BUS_NAME: z.string().optional().default('default'),
    FCM_SNS_TOPIC_ARN: z.string().optional().default(''),
    IMPORT_QUEUE_URL: z.string().optional().default(''),
    INTERNAL_API_KEY: z.string().optional().default(''),
    INTERNAL_SECRET_ARN: z.string().optional().default(''),
    INVOICE_GEN_QUEUE_URL: z.string().optional().default(''),
    KMS_KEY_ID: z.string().optional().default(''),
    LICENSE_CACHE_TTL_MS: z.string().optional().default('300000'),
    NIC_EWAY_BILL_PATH: z.string().optional().default(''),
    OFFLINE_MESSAGES_TABLE: z.string().optional().default(''),
    PAYMENT_GATEWAY: z.string().optional().default(''),
    PHARMACY_FEFO_OVERRIDE_MASTER_PIN: z.string().optional().default(''),
    PHONEPE_SALT_KEY: z.string().optional().default(''),
    PLATFORM_APPLICATION_ARN: z.string().optional().default(''),
    PUMP_ATG_INTEGRATION_ENABLED: z.string().optional().default('false'),
    PUMP_FLEET_INTEGRATION_ENABLED: z.string().optional().default('false'),
    PUMP_FLEET_PROVIDER_API_KEY: z.string().optional().default(''),
    QR_MASTER_SECRET: z.string().optional().default(''),
    RECONCILIATION_S3_BUCKET: z.string().optional().default(''),
    RECONCILIATION_SNS_TOPIC_ARN: z.string().optional().default(''),
    REPORT_DISPATCH_SNS_TOPIC_ARN: z.string().optional().default(''),
    REPORT_DISPATCH_WHATSAPP_WEBHOOK_URL: z.string().optional().default(''),
    REPORT_DISPATCH_WORKER_ENABLED: z.string().optional().default('false'),
    RESTO_BILL_DISCOUNT_CAP_PERCENT: z.string().optional().default('100'),
    RESTO_ITEM_DISCOUNT_CAP_PERCENT: z.string().optional().default('100'),
    RESTO_MANAGER_OVERRIDE_MASTER_PIN: z.string().optional().default(''),
    RESTO_V1_ORDER_SECRET: z.string().optional().default(''),
    RESTO_V1_PUBLIC_ENABLED: z.string().optional().default('false'),
    // P0-02: HS256 secret for table-scoped scan JWTs (PWA QR flow).
    // Generate with: openssl rand -hex 32. Required when RESTO_V1_PUBLIC_ENABLED=true.
    RESTO_SCAN_JWT_SECRET: z.string().optional().default(''),
    SECRET: z.string().optional().default(''),
    SECURITY_ALERT_TOPIC_ARN: z.string().optional().default(''),
    SLS_BACKEND_URL: z.string().optional().default(''),
    TENANT_STORAGE_BUCKET: z.string().optional().default(''),
    WEBSOCKET_CONNECTIONS_TABLE: z.string().optional().default(''),
    WHATSAPP_ACCESS_TOKEN: z.string().optional().default(''),
    WHATSAPP_API_URL: z.string().optional().default('https://graph.facebook.com/v17.0'),
    WHATSAPP_PHONE_NUMBER_ID: z.string().optional().default(''),
    WHATSAPP_TEMPLATE_NAME: z.string().optional().default('invoice_share'),
});

// ── Parse & Validate ───────────────────────────────────────────────────────

const parsed = environmentSchema.safeParse(process.env);

if (!parsed.success) {
    const errors = parsed.error.issues
        .map((issue) => `  ✗ ${issue.path.join('.')}: ${issue.message}`)
        .join('\n');

    console.error(
        '\n╔══════════════════════════════════════════════════════════════╗\n' +
        '║  FATAL: Missing/Invalid Environment Variables               ║\n' +
        '╠══════════════════════════════════════════════════════════════╣\n' +
        errors + '\n' +
        '╠══════════════════════════════════════════════════════════════╣\n' +
        '║  Copy .env.example to .env and fill in required values.     ║\n' +
        '╚══════════════════════════════════════════════════════════════╝\n'
    );
    process.exit(1);
}

const env = parsed.data;

// ── Typed Config Object ────────────────────────────────────────────────────

export const config = Object.freeze({
    aws: {
        region: env.AWS_REGION,
    },

    dynamodb: {
        tableName: env.DYNAMODB_TABLE,
        rateLimitTable: env.RATE_LIMIT_TABLE || `${env.DYNAMODB_TABLE}-rate-limits`,
        auditTable: env.AUDIT_TABLE_NAME || env.DYNAMODB_TABLE,
        licenseTable: env.LICENSE_TABLE_NAME || env.DYNAMODB_TABLE,
        local: env.DYNAMODB_LOCAL === 'true',
    },

    cognito: {
        userPoolId: env.COGNITO_USER_POOL_ID,
        clientId: env.COGNITO_CLIENT_ID,
        region: env.COGNITO_REGION || env.AWS_REGION,
        desktopClientId: env.COGNITO_DESKTOP_CLIENT_ID,
        mobileClientId: env.COGNITO_MOBILE_CLIENT_ID,
        adminClientId: env.COGNITO_ADMIN_CLIENT_ID,
        identityPoolId: env.COGNITO_IDENTITY_POOL_ID,
        get allClientIds(): string[] {
            return [
                this.clientId,
                this.desktopClientId,
                this.mobileClientId,
                this.adminClientId,
            ].filter(Boolean);
        },
    },

    s3: {
        bucketName: env.S3_BUCKET_NAME,
        region: env.S3_REGION || env.AWS_REGION,
        signedUrlExpiry: 300, // 5 minutes
    },

    websocket: {
        endpoint: env.WEBSOCKET_API_ENDPOINT,
    },

    app: {
        env: env.NODE_ENV,
        stage: env.ENVIRONMENT,
        logLevel: env.LOG_LEVEL,
        isProduction: env.NODE_ENV === 'production',
        isDevelopment: env.NODE_ENV === 'development',
    },

    secrets: {
        internalApiSecret: env.INTERNAL_API_SECRET,
        manifestJwtSecret: env.MANIFEST_JWT_SECRET,
    },

    ai: {
        defaultProvider: env.DUKANX_AI_DEFAULT_PROVIDER,
        apiKey: env.DUKANX_AI_API_KEY,
        anthropicKey: env.ANTHROPIC_API_KEY,
    },

    search: {
        opensearchEndpoint: env.OPENSEARCH_ENDPOINT,
        fuzzyThreshold: parseFloat(env.FUZZY_THRESHOLD),
    },

    payment: {
        razorpay: {
            keyId: env.RAZORPAY_KEY_ID,
            keySecret: env.RAZORPAY_KEY_SECRET,
            webhookSecret: env.RAZORPAY_WEBHOOK_SECRET,
        },
        plans: {
            basicMonthly: env.RAZORPAY_PLAN_BASIC_MONTHLY,
            basicQuarterly: env.RAZORPAY_PLAN_BASIC_QUARTERLY,
            basicBiannual: env.RAZORPAY_PLAN_BASIC_BIANNUAL,
            basicYearly: env.RAZORPAY_PLAN_BASIC_YEARLY,
            basicBiennial: env.RAZORPAY_PLAN_BASIC_BIENNIAL,
            basicTriennial: env.RAZORPAY_PLAN_BASIC_TRIENNIAL,
            proMonthly: env.RAZORPAY_PLAN_PRO_MONTHLY,
            proQuarterly: env.RAZORPAY_PLAN_PRO_QUARTERLY,
            proBiannual: env.RAZORPAY_PLAN_PRO_BIANNUAL,
            proYearly: env.RAZORPAY_PLAN_PRO_YEARLY,
            proBiennial: env.RAZORPAY_PLAN_PRO_BIENNIAL,
            proTriennial: env.RAZORPAY_PLAN_PRO_TRIENNIAL,
            premiumMonthly: env.RAZORPAY_PLAN_PREMIUM_MONTHLY,
            premiumQuarterly: env.RAZORPAY_PLAN_PREMIUM_QUARTERLY,
            premiumBiannual: env.RAZORPAY_PLAN_PREMIUM_BIANNUAL,
            premiumYearly: env.RAZORPAY_PLAN_PREMIUM_YEARLY,
            premiumBiennial: env.RAZORPAY_PLAN_PREMIUM_BIENNIAL,
            premiumTriennial: env.RAZORPAY_PLAN_PREMIUM_TRIENNIAL,
            enterpriseMonthly: env.RAZORPAY_PLAN_ENTERPRISE_MONTHLY,
            enterpriseQuarterly: env.RAZORPAY_PLAN_ENTERPRISE_QUARTERLY,
            enterpriseBiannual: env.RAZORPAY_PLAN_ENTERPRISE_BIANNUAL,
            enterpriseYearly: env.RAZORPAY_PLAN_ENTERPRISE_YEARLY,
            enterpriseBiennial: env.RAZORPAY_PLAN_ENTERPRISE_BIENNIAL,
            enterpriseTriennial: env.RAZORPAY_PLAN_ENTERPRISE_TRIENNIAL,
        },
    },

    cors: {
        origins: [env.CORS_ORIGIN_1, env.CORS_ORIGIN_2].filter(Boolean),
    },

    pump: {
        atgConnectorToken: env.PUMP_ATG_CONNECTOR_TOKEN,
    },
    creditReminder: {
        minAgeDays: env.CREDIT_REMINDER_MIN_AGE_DAYS,
        minBalanceCents: env.CREDIT_REMINDER_MIN_BALANCE_CENTS,
        snsTopicArn: env.CREDIT_REMINDER_SNS_TOPIC_ARN,
    },
    awsQueue: {
        dlqUrl: env.DLQ_URL,
        importQueueUrl: env.IMPORT_QUEUE_URL,
        invoiceGenQueueUrl: env.INVOICE_GEN_QUEUE_URL,
    },
    awsSns: {
        fcmTopicArn: env.FCM_SNS_TOPIC_ARN,
        platformApplicationArn: env.PLATFORM_APPLICATION_ARN,
        reconciliationTopicArn: env.RECONCILIATION_SNS_TOPIC_ARN,
        reportDispatchTopicArn: env.REPORT_DISPATCH_SNS_TOPIC_ARN,
        securityAlertTopicArn: env.SECURITY_ALERT_TOPIC_ARN,
    },
    awsEventBridge: {
        busName: env.EVENTBRIDGE_BUS_NAME,
    },
    awsKms: {
        keyId: env.KMS_KEY_ID,
    },
    extendedDynamo: {
        offlineMessagesTable: env.OFFLINE_MESSAGES_TABLE,
        websocketConnectionsTable: env.WEBSOCKET_CONNECTIONS_TABLE,
    },
    extendedS3: {
        reconciliationBucket: env.RECONCILIATION_S3_BUCKET,
        tenantStorageBucket: env.TENANT_STORAGE_BUCKET,
    },
    extendedSecrets: {
        internalApiKey: env.INTERNAL_API_KEY,
        internalSecretArn: env.INTERNAL_SECRET_ARN,
        qrMasterSecret: env.QR_MASTER_SECRET,
        genericSecret: env.SECRET,
    },
    license: {
        cacheTtlMs: env.LICENSE_CACHE_TTL_MS,
    },
    einvoice: {
        nicEwayBillPath: env.NIC_EWAY_BILL_PATH,
    },
    pharmacy: {
        fefoOverrideMasterPin: env.PHARMACY_FEFO_OVERRIDE_MASTER_PIN,
    },
    extendedPayment: {
        gateway: env.PAYMENT_GATEWAY,
        phonepeSaltKey: env.PHONEPE_SALT_KEY,
    },
    extendedPump: {
        atgIntegrationEnabled: env.PUMP_ATG_INTEGRATION_ENABLED,
        fleetIntegrationEnabled: env.PUMP_FLEET_INTEGRATION_ENABLED,
        fleetProviderApiKey: env.PUMP_FLEET_PROVIDER_API_KEY,
    },
    resto: {
        billDiscountCapPercent: env.RESTO_BILL_DISCOUNT_CAP_PERCENT,
        itemDiscountCapPercent: env.RESTO_ITEM_DISCOUNT_CAP_PERCENT,
        managerOverrideMasterPin: env.RESTO_MANAGER_OVERRIDE_MASTER_PIN,
        v1OrderSecret: env.RESTO_V1_ORDER_SECRET, // legacy/deprecated
        v1PublicEnabled: env.RESTO_V1_PUBLIC_ENABLED,
        scanJwtSecret: env.RESTO_SCAN_JWT_SECRET,
    },
    extendedApp: {
        slsBackendUrl: env.SLS_BACKEND_URL,
    },
    whatsapp: {
        accessToken: env.WHATSAPP_ACCESS_TOKEN,
        apiUrl: env.WHATSAPP_API_URL,
        phoneNumberId: env.WHATSAPP_PHONE_NUMBER_ID,
        templateName: env.WHATSAPP_TEMPLATE_NAME,
        reportDispatchWebhookUrl: env.REPORT_DISPATCH_WHATSAPP_WEBHOOK_URL,
        reportDispatchWorkerEnabled: env.REPORT_DISPATCH_WORKER_ENABLED,
    },
});

// ── Type Export ─────────────────────────────────────────────────────────────
export type AppConfig = typeof config;
