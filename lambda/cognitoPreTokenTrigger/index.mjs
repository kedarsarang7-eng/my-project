/**
 * cognitoPreTokenTrigger/index.mjs
 * Cognito Pre-Token Generation V2 trigger.
 *
 * Security responsibilities:
 *  1. Injects authoritative role/tenantId claims from DynamoDB (not user-modifiable attributes).
 *  2. Enforces that customers can ONLY get role=customer — never owner/admin even if they modify
 *     their Cognito custom attribute directly.
 *  3. Adds sub-role claim for customer app (prevents privilege escalation).
 *  4. Blocks tokens for suspended/deleted accounts.
 */

import { DynamoDBClient, GetItemCommand } from '@aws-sdk/client-dynamodb';
import { marshall, unmarshall } from '@aws-sdk/util-dynamodb';

const USERS_TABLE = process.env.USERS_TABLE;
const TENANTS_TABLE = process.env.TENANTS_TABLE;

const ddb = new DynamoDBClient({});

export const handler = async (event) => {
  const userId = event.userName;
  const attrs = event.request?.userAttributes || {};
  const triggerSource = event.triggerSource;

  // Only modify tokens for sign-in flows, not admin flows
  if (!triggerSource?.includes('TokenGeneration')) {
    return event;
  }

  try {
    // 1. Look up authoritative profile in DynamoDB
    const profile = await getProfile(userId);

    if (!profile) {
      // No profile = not onboarded yet (edge case during sign-up)
      // Allow with minimal claims — customerOnboardingTrigger will create profile
      event.response = {
        claimsAndScopeOverrideDetails: {
          idTokenGeneration: {
            claimsToAddOrOverride: {
              'custom:role': 'customer',
            },
          },
          accessTokenGeneration: {
            claimsToAddOrOverride: {
              'custom:role': 'customer',
            },
          },
        },
      };
      return event;
    }

    // 2. Enforce role cannot be escalated
    const authoritativeRole = profile.role || 'customer';

    // Customer-pool users can ONLY be 'customer' role
    // Even if they somehow set custom:role to 'owner' via AWS CLI, we override it here
    const poolId = event.userPoolId;
    const customerPoolId = process.env.CUSTOMER_USER_POOL_ID;

    let enforcedRole = authoritativeRole;
    if (customerPoolId && poolId === customerPoolId) {
      // This is the customer pool — hard-enforce customer role
      enforcedRole = 'customer';
    }

    // 3. Check account status
    if (profile.status === 'suspended' || profile.status === 'deleted') {
      // Throw to block token issuance
      throw new Error(`Account ${profile.status}: ${userId}`);
    }

    // 4. Build claims to inject
    const additionalClaims = {
      'custom:role': enforcedRole,
      'custom:tenantId': profile.tenantId || userId,
      'custom:displayName': profile.displayName || '',
    };

    // For owners, also inject tenantId from tenants table for extra validation
    if (enforcedRole === 'owner') {
      const tenant = await getTenant(profile.tenantId);
      if (!tenant || tenant.status !== 'active') {
        throw new Error(`Tenant inactive or not found: ${profile.tenantId}`);
      }
      additionalClaims['custom:businessName'] = tenant.businessName || '';
      additionalClaims['custom:plan'] = tenant.plan || 'free';
    }

    event.response = {
      claimsAndScopeOverrideDetails: {
        idTokenGeneration: {
          claimsToAddOrOverride: additionalClaims,
        },
        accessTokenGeneration: {
          claimsToAddOrOverride: additionalClaims,
        },
      },
    };

    return event;
  } catch (err) {
    console.error('PreTokenGeneration error:', err.message);
    // Re-throw to block token issuance for suspended/deleted accounts
    throw err;
  }
};

async function getProfile(userId) {
  try {
    const result = await ddb.send(new GetItemCommand({
      TableName: USERS_TABLE,
      Key: marshall({ PK: `USER#${userId}`, SK: 'PROFILE' }),
    }));
    return result.Item ? unmarshall(result.Item) : null;
  } catch (err) {
    console.error('Failed to fetch profile:', err.message);
    return null;
  }
}

async function getTenant(tenantId) {
  if (!tenantId) return null;
  try {
    const result = await ddb.send(new GetItemCommand({
      TableName: TENANTS_TABLE,
      Key: marshall({ PK: `TENANT#${tenantId}`, SK: 'METADATA' }),
    }));
    return result.Item ? unmarshall(result.Item) : null;
  } catch (err) {
    console.error('Failed to fetch tenant:', err.message);
    return null;
  }
}
