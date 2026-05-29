// ============================================================================
// CLINIC DASHBOARD API GATEWAY CONFIGURATION
// ============================================================================
// API Gateway REST API routes for clinic dashboard
// Cognito Authorizer on all routes except /license/validate
// CORS enabled for Flutter web/mobile clients
// ============================================================================

import { 
  RestApi, 
  Resource, 
  Method, 
  Integration,
  IntegrationType,
  PassthroughBehavior,
  CfnAuthorizer,
  AuthorizationType,
  CfnMethod,
  RequestValidator,
} from 'aws-cdk-lib/aws-apigateway';
import { Function } from 'aws-cdk-lib/aws-lambda';
import { Construct } from 'constructs';
import { config } from './environment';

// ============================================================================
// ROUTE DEFINITIONS
// ============================================================================

export interface ClinicApiRoute {
  path: string;
  method: 'GET' | 'POST' | 'PUT' | 'DELETE';
  handler: string;
  requireAuth: boolean;
  cacheTtl?: number;  // seconds, undefined = no cache
  rateLimit?: number; // requests per second
}

export const clinicDashboardRoutes: ClinicApiRoute[] = [
  // ── Dashboard Overview ──────────────────────────────────────────────────────
  {
    path: '/dashboard/overview',
    method: 'GET',
    handler: 'getDashboardOverview',
    requireAuth: true,
    cacheTtl: 120,  // 2 minutes
    rateLimit: 50,
  },
  
  // ── Appointments ────────────────────────────────────────────────────────────
  {
    path: '/appointments',
    method: 'GET',
    handler: 'getAppointments',
    requireAuth: true,
    cacheTtl: 60,   // 1 minute
    rateLimit: 100,
  },
  
  // ── Patient Insights ────────────────────────────────────────────────────────
  {
    path: '/patients/insights',
    method: 'GET',
    handler: 'getPatientInsights',
    requireAuth: true,
    cacheTtl: 300,  // 5 minutes
    rateLimit: 30,
  },
  
  // ── Staff Availability ──────────────────────────────────────────────────────
  {
    path: '/staff/availability',
    method: 'GET',
    handler: 'getStaffAvailability',
    requireAuth: true,
    cacheTtl: 60,
    rateLimit: 50,
  },
  
  // ── Rooms ───────────────────────────────────────────────────────────────────
  {
    path: '/rooms',
    method: 'GET',
    handler: 'getRooms',
    requireAuth: true,
    cacheTtl: 30,   // 30 seconds - rooms change frequently
    rateLimit: 50,
  },
  
  // ── Billing Summary ─────────────────────────────────────────────────────────
  {
    path: '/billing/summary',
    method: 'GET',
    handler: 'getBillingSummary',
    requireAuth: true,
    cacheTtl: 300,  // 5 minutes
    rateLimit: 30,
  },
  
  // ── Inventory Alerts ──────────────────────────────────────────────────────────
  {
    path: '/inventory/alerts',
    method: 'GET',
    handler: 'getInventoryAlerts',
    requireAuth: true,
    cacheTtl: 120,
    rateLimit: 30,
  },
  
  // ── Weekly Trends ───────────────────────────────────────────────────────────
  {
    path: '/analytics/performance',
    method: 'GET',
    handler: 'getWeeklyTrends',
    requireAuth: true,
    cacheTtl: 300,
    rateLimit: 20,
  },
  
  // ── Wait Time ───────────────────────────────────────────────────────────────
  {
    path: '/appointments/wait-time',
    method: 'GET',
    handler: 'getWaitTime',
    requireAuth: true,
    cacheTtl: 60,
    rateLimit: 50,
  },
  
  // ── License Validation (PUBLIC - no auth required) ────────────────────────────
  {
    path: '/license/validate',
    method: 'POST',
    handler: 'validateLicense',
    requireAuth: false,
    rateLimit: 10,
  },
];

// ============================================================================
// COGNITO AUTHORIZER CONFIG
// ============================================================================

export interface CognitoAuthorizerConfig {
  providerArns: string[];
  identitySource?: string;
  resultTtlInSeconds?: number;
}

export const createCognitoAuthorizer = (
  scope: Construct,
  api: RestApi,
  config: CognitoAuthorizerConfig
): CfnAuthorizer => {
  return new CfnAuthorizer(scope, 'ClinicDashboardAuthorizer', {
    name: 'ClinicDashboardCognitoAuthorizer',
    type: AuthorizationType.COGNITO,
    identitySource: config.identitySource || 'method.request.header.Authorization',
    providerArns: config.providerArns,
    restApiId: api.restApiId,
    resultTtlInSeconds: config.resultTtlInSeconds || 300,
  });
};

// ============================================================================
// CORS CONFIGURATION
// ============================================================================

export const clinicCorsOptions = {
  allowOrigins: [
    'http://localhost:*',     // Flutter web development
    'https://*.dukanx.app',   // Production domain
    'https://*.amplifyapp.com', // AWS Amplify hosting
  ],
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowHeaders: [
    'Content-Type',
    'Authorization',
    'X-Amz-Date',
    'X-Api-Key',
    'X-Tenant-Id',
    'X-Business-Type',
    'X-Clinic-Id',
  ],
  allowCredentials: true,
  maxAge: 86400, // 24 hours
};

// ============================================================================
// WAF RULES (Web Application Firewall)
// ============================================================================

export const clinicWafRules = [
  // Rate limiting per IP
  {
    name: 'RateLimitRule',
    priority: 1,
    statement: {
      rateBasedStatement: {
        limit: 2000,  // requests per 5 minutes per IP
        aggregateKeyType: 'IP',
      },
    },
    action: { block: {} },
    visibilityConfig: {
      sampledRequestsEnabled: true,
      cloudWatchMetricsEnabled: true,
      metricName: 'RateLimitRule',
    },
  },
  
  // AWS Managed Rules - Common Rule Set
  {
    name: 'AWSManagedRulesCommonRuleSet',
    priority: 2,
    statement: {
      managedRuleGroupStatement: {
        vendorName: 'AWS',
        name: 'AWSManagedRulesCommonRuleSet',
      },
    },
    overrideAction: { none: {} },
    visibilityConfig: {
      sampledRequestsEnabled: true,
      cloudWatchMetricsEnabled: true,
      metricName: 'AWSManagedRulesCommonRuleSet',
    },
  },
  
  // AWS Managed Rules - Known Bad Inputs
  {
    name: 'AWSManagedRulesKnownBadInputsRuleSet',
    priority: 3,
    statement: {
      managedRuleGroupStatement: {
        vendorName: 'AWS',
        name: 'AWSManagedRulesKnownBadInputsRuleSet',
      },
    },
    overrideAction: { none: {} },
    visibilityConfig: {
      sampledRequestsEnabled: true,
      cloudWatchMetricsEnabled: true,
      metricName: 'AWSManagedRulesKnownBadInputsRuleSet',
    },
  },
];

// ============================================================================
// API GATEWAY STAGE CONFIG
// ============================================================================

export interface ClinicApiStageConfig {
  stageName: 'dev' | 'staging' | 'prod';
  throttlingBurstLimit: number;
  throttlingRateLimit: number;
  cacheClusterEnabled: boolean;
  cacheClusterSize?: string;
  loggingLevel: 'ERROR' | 'INFO' | 'OFF';
  dataTraceEnabled: boolean;
  metricsEnabled: boolean;
}

export const clinicApiStageConfigs: Record<string, ClinicApiStageConfig> = {
  dev: {
    stageName: 'dev',
    throttlingBurstLimit: 1000,
    throttlingRateLimit: 500,
    cacheClusterEnabled: false,
    loggingLevel: 'INFO',
    dataTraceEnabled: true,
    metricsEnabled: true,
  },
  staging: {
    stageName: 'staging',
    throttlingBurstLimit: 2000,
    throttlingRateLimit: 1000,
    cacheClusterEnabled: true,
    cacheClusterSize: '0.5',
    loggingLevel: 'INFO',
    dataTraceEnabled: true,
    metricsEnabled: true,
  },
  prod: {
    stageName: 'prod',
    throttlingBurstLimit: 5000,
    throttlingRateLimit: 2000,
    cacheClusterEnabled: true,
    cacheClusterSize: '1.6',
    loggingLevel: 'ERROR',
    dataTraceEnabled: false,
    metricsEnabled: true,
  },
};

// ============================================================================
// REQUEST VALIDATION SCHEMAS
// ============================================================================

export const clinicRequestModels = {
  overviewRequest: {
    type: 'object',
    properties: {
      date: { type: 'string', pattern: '^\d{4}-\d{2}-\d{2}$' },
    },
  },
  appointmentsRequest: {
    type: 'object',
    properties: {
      date: { type: 'string', pattern: '^\d{4}-\d{2}-\d{2}$' },
      doctorId: { type: 'string' },
      status: { 
        type: 'string', 
        enum: ['scheduled', 'completed', 'cancelled', 'no-show', 'in-progress'] 
      },
    },
  },
  licenseValidateRequest: {
    type: 'object',
    required: ['licenseKey'],
    properties: {
      licenseKey: { type: 'string', minLength: 10, maxLength: 100 },
    },
  },
};

// ============================================================================
// LAMBDA INTEGRATION CONFIG
// ============================================================================

export const createLambdaIntegration = (
  lambdaFunction: Function,
  cacheTtl?: number
): Integration => {
  return new Integration({
    type: IntegrationType.LAMBDA_PROXY,
    integrationHttpMethod: 'POST',
    uri: `arn:aws:apigateway:${config.aws.region}:lambda:path/2015-03-31/functions/${lambdaFunction.functionArn}/invocations`,
    options: {
      passthroughBehavior: PassthroughBehavior.WHEN_NO_MATCH,
      integrationResponses: [
        {
          statusCode: '200',
          responseParameters: {
            'method.response.header.Access-Control-Allow-Origin': "'*'",
          },
        },
        {
          selectionPattern: '4\\d{2}',
          statusCode: '400',
          responseParameters: {
            'method.response.header.Access-Control-Allow-Origin': "'*'",
          },
        },
        {
          selectionPattern: '5\\d{2}',
          statusCode: '500',
          responseParameters: {
            'method.response.header.Access-Control-Allow-Origin': "'*'",
          },
        },
      ],
      ...(cacheTtl && {
        cacheKeyParameters: ['method.request.querystring.date'],
        cacheNamespace: 'clinic-dashboard',
      }),
    },
  });
};
