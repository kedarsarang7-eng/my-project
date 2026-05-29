# Phase 2 Bulk Migration Script: Inject missing Zod schema, extend config object, and replace process.env occurrences

$envFile = "g:\desktop app genuine\Dukan_x\my-backend\src\config\environment.ts"
$srcDir = "g:\desktop app genuine\Dukan_x\my-backend\src"

# 1. Update environment.ts
$envContent = Get-Content $envFile -Raw

# We need to inject the Zod properties into environmentSchema
$zodInject = @"
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
    SECRET: z.string().optional().default(''),
    SECURITY_ALERT_TOPIC_ARN: z.string().optional().default(''),
    SLS_BACKEND_URL: z.string().optional().default(''),
    TENANT_STORAGE_BUCKET: z.string().optional().default(''),
    WEBSOCKET_CONNECTIONS_TABLE: z.string().optional().default(''),
    WHATSAPP_ACCESS_TOKEN: z.string().optional().default(''),
    WHATSAPP_API_URL: z.string().optional().default('https://graph.facebook.com/v17.0'),
    WHATSAPP_PHONE_NUMBER_ID: z.string().optional().default(''),
    WHATSAPP_TEMPLATE_NAME: z.string().optional().default('invoice_share'),
"@

if ($envContent -notmatch "CREDIT_REMINDER_MIN_AGE_DAYS") {
    $envContent = $envContent -replace 'DYNAMODB_LOCAL:\s*z\.string\(\)\.optional\(\)\.default\(''false''\),', "DYNAMODB_LOCAL: z.string().optional().default('false'),`n$zodInject"
}

# We need to inject the config properties into the config object
$configInject = @"
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
        v1OrderSecret: env.RESTO_V1_ORDER_SECRET,
        v1PublicEnabled: env.RESTO_V1_PUBLIC_ENABLED,
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
"@

if ($envContent -notmatch "creditReminder:") {
    $envContent = $envContent -replace 'pump:\s*\{\s*atgConnectorToken:\s*env\.PUMP_ATG_CONNECTOR_TOKEN,\s*\},', "pump: {`n        atgConnectorToken: env.PUMP_ATG_CONNECTOR_TOKEN,`n    },`n$configInject"
}

Set-Content $envFile -Value $envContent -NoNewline
Write-Host "Updated environment.ts"

# 2. File Replacements
$replacements = @{
    "process.env.ANTHROPIC_API_KEY" = "config.ai.anthropicKey"
    "process.env.API_BASE_URL" = "config.app.slsBackendUrl"
    "process.env.CREDIT_REMINDER_MIN_AGE_DAYS" = "config.creditReminder.minAgeDays"
    "process.env.CREDIT_REMINDER_MIN_BALANCE_CENTS" = "config.creditReminder.minBalanceCents"
    "process.env.CREDIT_REMINDER_SNS_TOPIC_ARN" = "config.creditReminder.snsTopicArn"
    "process.env.DLQ_URL" = "config.awsQueue.dlqUrl"
    "process.env.DUKANX_AI_DEFAULT_PROVIDER" = "config.ai.defaultProvider"
    "process.env.EVENTBRIDGE_BUS_NAME" = "config.awsEventBridge.busName"
    "process.env.FCM_SNS_TOPIC_ARN" = "config.awsSns.fcmTopicArn"
    "process.env.FUZZY_THRESHOLD" = "config.search.fuzzyThreshold.toString()"
    "process.env.IMPORT_QUEUE_URL" = "config.awsQueue.importQueueUrl"
    "process.env.INTERNAL_API_KEY" = "config.extendedSecrets.internalApiKey"
    "process.env.INTERNAL_SECRET_ARN" = "config.extendedSecrets.internalSecretArn"
    "process.env.INVOICE_GEN_QUEUE_URL" = "config.awsQueue.invoiceGenQueueUrl"
    "process.env.KMS_KEY_ID" = "config.awsKms.keyId"
    "process.env.LICENSE_CACHE_TTL_MS" = "config.license.cacheTtlMs"
    "process.env.LOG_LEVEL" = "config.app.logLevel"
    "process.env.NIC_EWAY_BILL_PATH" = "config.einvoice.nicEwayBillPath"
    "process.env.NODE_ENV" = "config.app.env"
    "process.env.OFFLINE_MESSAGES_TABLE" = "config.extendedDynamo.offlineMessagesTable"
    "process.env.OPENSEARCH_ENDPOINT" = "config.search.opensearchEndpoint"
    "process.env.PAYMENT_GATEWAY" = "config.extendedPayment.gateway"
    "process.env.PHARMACY_FEFO_OVERRIDE_MASTER_PIN" = "config.pharmacy.fefoOverrideMasterPin"
    "process.env.PHONEPE_SALT_KEY" = "config.extendedPayment.phonepeSaltKey"
    "process.env.PLATFORM_APPLICATION_ARN" = "config.awsSns.platformApplicationArn"
    "process.env.PUMP_ATG_CONNECTOR_TOKEN" = "config.pump.atgConnectorToken"
    "process.env.PUMP_ATG_INTEGRATION_ENABLED" = "config.extendedPump.atgIntegrationEnabled"
    "process.env.PUMP_FLEET_INTEGRATION_ENABLED" = "config.extendedPump.fleetIntegrationEnabled"
    "process.env.PUMP_FLEET_PROVIDER_API_KEY" = "config.extendedPump.fleetProviderApiKey"
    "process.env.QR_MASTER_SECRET" = "config.extendedSecrets.qrMasterSecret"
    "process.env.RAZORPAY_KEY_ID" = "config.payment.razorpay.keyId"
    "process.env.RAZORPAY_KEY_SECRET" = "config.payment.razorpay.keySecret"
    "process.env.RAZORPAY_WEBHOOK_SECRET" = "config.payment.razorpay.webhookSecret"
    "process.env.RAZORPAY_PLAN_BASIC_MONTHLY" = "config.payment.plans.basicMonthly"
    "process.env.RAZORPAY_PLAN_BASIC_YEARLY" = "config.payment.plans.basicYearly"
    "process.env.RAZORPAY_PLAN_PRO_MONTHLY" = "config.payment.plans.proMonthly"
    "process.env.RAZORPAY_PLAN_PRO_YEARLY" = "config.payment.plans.proYearly"
    "process.env.RAZORPAY_PLAN_PREMIUM_MONTHLY" = "config.payment.plans.premiumMonthly"
    "process.env.RAZORPAY_PLAN_PREMIUM_YEARLY" = "config.payment.plans.premiumYearly"
    "process.env.RAZORPAY_PLAN_ENTERPRISE_MONTHLY" = "config.payment.plans.enterpriseMonthly"
    "process.env.RAZORPAY_PLAN_ENTERPRISE_YEARLY" = "config.payment.plans.enterpriseYearly"
    "process.env.RECONCILIATION_S3_BUCKET" = "config.extendedS3.reconciliationBucket"
    "process.env.RECONCILIATION_SNS_TOPIC_ARN" = "config.awsSns.reconciliationTopicArn"
    "process.env.REPORT_DISPATCH_SNS_TOPIC_ARN" = "config.awsSns.reportDispatchTopicArn"
    "process.env.REPORT_DISPATCH_WHATSAPP_WEBHOOK_URL" = "config.whatsapp.reportDispatchWebhookUrl"
    "process.env.REPORT_DISPATCH_WORKER_ENABLED" = "config.whatsapp.reportDispatchWorkerEnabled"
    "process.env.RESTO_BILL_DISCOUNT_CAP_PERCENT" = "config.resto.billDiscountCapPercent"
    "process.env.RESTO_ITEM_DISCOUNT_CAP_PERCENT" = "config.resto.itemDiscountCapPercent"
    "process.env.RESTO_MANAGER_OVERRIDE_MASTER_PIN" = "config.resto.managerOverrideMasterPin"
    "process.env.RESTO_V1_ORDER_SECRET" = "config.resto.v1OrderSecret"
    "process.env.RESTO_V1_PUBLIC_ENABLED" = "config.resto.v1PublicEnabled"
    "process.env.SECRET" = "config.extendedSecrets.genericSecret"
    "process.env.SECURITY_ALERT_TOPIC_ARN" = "config.awsSns.securityAlertTopicArn"
    "process.env.SLS_BACKEND_URL" = "config.extendedApp.slsBackendUrl"
    "process.env.STAGE" = "config.app.stage"
    "process.env.TENANT_STORAGE_BUCKET" = "config.extendedS3.tenantStorageBucket"
    "process.env.WEBSOCKET_API_ENDPOINT" = "config.websocket.endpoint"
    "process.env.WEBSOCKET_CONNECTIONS_TABLE" = "config.extendedDynamo.websocketConnectionsTable"
    "process.env.WHATSAPP_ACCESS_TOKEN" = "config.whatsapp.accessToken"
    "process.env.WHATSAPP_API_URL" = "config.whatsapp.apiUrl"
    "process.env.WHATSAPP_PHONE_NUMBER_ID" = "config.whatsapp.phoneNumberId"
    "process.env.WHATSAPP_TEMPLATE_NAME" = "config.whatsapp.templateName"
}

Get-ChildItem -Path $srcDir -Filter "*.ts" -Recurse | Where-Object { $_.FullName -notmatch "\\__tests__\\" } | ForEach-Object {
    $filePath = $_.FullName
    $content = Get-Content $filePath -Raw
    $original = $content
    $changed = $false

    # Make sure we add import config if missing, but only if we actually replace something
    $needsImport = $false

    foreach ($key in $replacements.Keys) {
        if ($content.Contains($key)) {
            $content = $content.Replace($key, $replacements[$key])
            $changed = $true
            $needsImport = $true
        }
    }

    if ($changed) {
        if ($content -notmatch "from\s+['""].*config/environment['""]" -and $filePath -notmatch "environment\.ts") {
            # Find a relative path for import
            $relativePath = ""
            if ($filePath -match "my-backend[\\/]src[\\/]([^\\/]+)[\\/]") {
                $relativePath = "../config/environment"
            } else {
                $relativePath = "./config/environment"
            }
            $importLine = "import { config } from '$relativePath';"
            $content = "$importLine`n" + $content
        }
        
        Set-Content $filePath -Value $content -NoNewline
        Write-Host "Updated: $filePath"
    }
}
Write-Host "Migration complete!"
