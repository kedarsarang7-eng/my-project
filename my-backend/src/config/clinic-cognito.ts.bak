import { config } from './environment';
// ============================================================================
// CLINIC COGNITO USER POOL CONFIGURATION
// ============================================================================
// Cognito User Pool with custom attributes for clinic roles
// MFA enabled for admin role
// Custom attributes: clinicId, role, doctorId, tenantId
// ============================================================================

import {
  UserPool,
  UserPoolClient,
  UserPoolClientIdentityProvider,
  OAuthScope,
  VerificationEmailStyle,
  CfnUserPoolGroup,
  Mfa,
  AccountRecovery,
  CognitoDomainOptions,
} from 'aws-cdk-lib/aws-cognito';
import { Construct } from 'constructs';

// ============================================================================
// CUSTOM ATTRIBUTES SCHEMA
// ============================================================================

export const clinicCustomAttributes = {
  // Core identity attributes
  tenantId: {
    mutable: true,
    dataType: 'String',
    minLen: 1,
    maxLen: 100,
  },
  clinicId: {
    mutable: true,  // Allow reassigning to different clinic
    dataType: 'String',
    minLen: 1,
    maxLen: 100,
  },
  role: {
    mutable: true,  // Allow role changes
    dataType: 'String',
    minLen: 1,
    maxLen: 20,
  },
  doctorId: {
    mutable: true,
    dataType: 'String',
    minLen: 1,
    maxLen: 100,
  },
  department: {
    mutable: true,
    dataType: 'String',
    minLen: 1,
    maxLen: 50,
  },
  licenseKey: {
    mutable: true,
    dataType: 'String',
    minLen: 10,
    maxLen: 100,
  },
  employeeId: {
    mutable: true,
    dataType: 'String',
    minLen: 1,
    maxLen: 50,
  },
  phoneVerified: {
    mutable: true,
    dataType: 'Boolean',
  },
};

// ============================================================================
// USER POOL GROUPS (RBAC)
// ============================================================================

export const clinicUserPoolGroups = [
  {
    groupName: 'admin',
    description: 'Clinic administrators with full access',
    precedence: 1,
  },
  {
    groupName: 'doctor',
    description: 'Doctors with access to patients and prescriptions',
    precedence: 2,
  },
  {
    groupName: 'nurse',
    description: 'Nurses with access to vitals and rooms',
    precedence: 3,
  },
  {
    groupName: 'receptionist',
    description: 'Front desk with access to appointments and check-in',
    precedence: 4,
  },
  {
    groupName: 'lab_tech',
    description: 'Laboratory technicians',
    precedence: 5,
  },
  {
    groupName: 'pharmacist',
    description: 'Pharmacy staff',
    precedence: 6,
  },
];

// ============================================================================
// USER POOL CONFIG
// ============================================================================

export interface ClinicUserPoolConfig {
  poolName: string;
  selfSignUpEnabled: boolean;
  mfaRequired: boolean;
  mfaSecondFactor?: {
    sms: boolean;
    otp: boolean;
  };
  passwordPolicy?: {
    minLength: number;
    requireLowercase: boolean;
    requireUppercase: boolean;
    requireDigits: boolean;
    requireSymbols: boolean;
  };
  accountRecovery?: AccountRecovery;
  emailVerification?: boolean;
  smsVerification?: boolean;
}

export const defaultClinicUserPoolConfig: ClinicUserPoolConfig = {
  poolName: 'ClinicDashboardUsers',
  selfSignUpEnabled: false,  // Admin-only user creation
  mfaRequired: true,
  mfaSecondFactor: {
    sms: true,
    otp: true,
  },
  passwordPolicy: {
    minLength: 12,
    requireLowercase: true,
    requireUppercase: true,
    requireDigits: true,
    requireSymbols: true,
  },
  accountRecovery: AccountRecovery.EMAIL_ONLY,
  emailVerification: true,
  smsVerification: false,
};

// ============================================================================
// USER POOL CLIENT CONFIG
// ============================================================================

export interface ClinicUserPoolClientConfig {
  clientName: string;
  generateSecret: boolean;
  authFlows: {
    userPassword: boolean;
    userSrp: boolean;
    custom: boolean;
  };
  oauth?: {
    flows: {
      authorizationCodeGrant: boolean;
      implicitCodeGrant: boolean;
    };
    scopes: OAuthScope[];
    callbackUrls: string[];
    logoutUrls: string[];
  };
  accessTokenValidity: number;  // minutes
  idTokenValidity: number;        // minutes
  refreshTokenValidity: number;   // days
}

export const clinicWebClientConfig: ClinicUserPoolClientConfig = {
  clientName: 'ClinicDashboardWeb',
  generateSecret: false,
  authFlows: {
    userPassword: false,  // SRP only for security
    userSrp: true,
    custom: true,
  },
  oauth: {
    flows: {
      authorizationCodeGrant: true,
      implicitCodeGrant: false,
    },
    scopes: [
      OAuthScope.OPENID,
      OAuthScope.EMAIL,
      OAuthScope.PROFILE,
      OAuthScope.COGNITO_ADMIN,
    ],
    callbackUrls: [
      'http://localhost:8080/callback',
      'https://app.dukanx.app/callback',
    ],
    logoutUrls: [
      'http://localhost:8080/logout',
      'https://app.dukanx.app/logout',
    ],
  },
  accessTokenValidity: 60,    // 1 hour
  idTokenValidity: 60,        // 1 hour
  refreshTokenValidity: 30,   // 30 days
};

export const clinicMobileClientConfig: ClinicUserPoolClientConfig = {
  clientName: 'ClinicDashboardMobile',
  generateSecret: false,
  authFlows: {
    userPassword: false,
    userSrp: true,
    custom: true,
  },
  accessTokenValidity: 60,
  idTokenValidity: 60,
  refreshTokenValidity: 30,
};

// ============================================================================
// HOSTED UI CONFIG
// ============================================================================

export const clinicHostedUiConfig: CognitoDomainOptions = {
  domainPrefix: 'clinic-dashboard-auth',
};

// ============================================================================
// PRE TOKEN GENERATION LAMBDA TRIGGER
// ============================================================================
// This Lambda adds custom claims to the JWT token

export const preTokenGenerationLambdaCode = `
exports.handler = async (event) => {
  event.response = {
    claimsOverrideDetails: {
      claimsToAddOrOverride: {
        'custom:clinicId': event.request.userAttributes['custom:clinicId'] || '',
        'custom:role': event.request.userAttributes['custom:role'] || '',
        'custom:tenantId': event.request.userAttributes['custom:tenantId'] || '',
        'custom:doctorId': event.request.userAttributes['custom:doctorId'] || '',
      },
      groupOverrideDetails: {
        groupsToOverride: event.request.groupConfiguration?.groupsToOverride || [],
      },
    },
  };
  return event;
};
`;

// ============================================================================
// POST AUTHENTICATION LAMBDA TRIGGER
// ============================================================================
// Tracks login activity and validates license

export const postAuthenticationLambdaCode = `
const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
  const userId = event.userName;
  const clinicId = event.request.userAttributes['custom:clinicId'];
  const licenseKey = event.request.userAttributes['custom:licenseKey'];
  
  // Log authentication event
  await dynamodb.put({
    TableName: config.dynamodb.auditTable,
    Item: {
      PK: 'AUDIT#AUTH',
      SK: 'AUTH#' + new Date().toISOString() + '#' + userId,
      userId,
      clinicId,
      action: 'LOGIN',
      timestamp: new Date().toISOString(),
      sourceIp: event.request?.clientMetadata?.sourceIp,
    },
  }).promise();
  
  // Validate license if provided
  if (licenseKey) {
    const licenseResult = await dynamodb.get({
      TableName: config.dynamodb.licenseTable,
      Key: { PK: 'LICENSE#' + licenseKey, SK: 'META' },
    }).promise();
    
    if (!licenseResult.Item || 
        licenseResult.Item.businessType !== 'clinic' ||
        licenseResult.Item.isActive !== true ||
        new Date(licenseResult.Item.expiresAt) < new Date()) {
      throw new Error('Invalid or expired clinic license');
    }
  }
  
  return event;
};
`;

// ============================================================================
// COGNITO AUTHORIZER POLICY
// ============================================================================

export const generateAuthPolicy = (
  principalId: string,
  effect: 'Allow' | 'Deny',
  resource: string,
  context?: Record<string, string>
) => {
  return {
    principalId,
    policyDocument: {
      Version: '2012-10-17',
      Statement: [
        {
          Action: 'execute-api:Invoke',
          Effect: effect,
          Resource: resource,
        },
      ],
    },
    context: context || {},
  };
};

// ============================================================================
// ROLE-BASED PERMISSIONS MAP
// ============================================================================

export const clinicRolePermissions: Record<string, string[]> = {
  admin: [
    'dashboard:overview',
    'appointments:read',
    'appointments:write',
    'patients:read',
    'patients:write',
    'staff:read',
    'staff:write',
    'billing:read',
    'billing:write',
    'inventory:read',
    'inventory:write',
    'rooms:read',
    'rooms:write',
    'reports:read',
    'settings:read',
    'settings:write',
  ],
  doctor: [
    'dashboard:overview',
    'appointments:read',
    'appointments:write',
    'patients:read',
    'patients:write',
    'prescriptions:write',
    'staff:read',
    'rooms:read',
    'inventory:read',
  ],
  nurse: [
    'dashboard:overview',
    'appointments:read',
    'patients:read',
    'patients:vitals:write',
    'staff:read',
    'rooms:read',
    'rooms:write',
    'inventory:read',
    'inventory:write',
  ],
  receptionist: [
    'dashboard:overview',
    'appointments:read',
    'appointments:write',
    'patients:read',
    'patients:write',
    'billing:read',
    'billing:write',
    'rooms:read',
  ],
  lab_tech: [
    'dashboard:overview',
    'patients:read',
    'lab:write',
    'inventory:read',
  ],
  pharmacist: [
    'dashboard:overview',
    'patients:read',
    'prescriptions:read',
    'pharmacy:write',
    'inventory:read',
  ],
};

export function hasPermission(role: string, permission: string): boolean {
  const permissions = clinicRolePermissions[role] || [];
  return permissions.includes(permission) || permissions.includes('*');
}
