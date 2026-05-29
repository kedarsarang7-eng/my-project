/**
 * customerOnboardingTrigger/index.mjs
 * Cognito Post-Confirmation trigger.
 * Fires when a new customer confirms their account.
 * Creates idempotent user profile in DynamoDB.
 */

import {
  getItem,
  putItem,
} from '../shared/utils.mjs';

const USERS_TABLE = process.env.USERS_TABLE;

export const handler = async (event) => {
  // Only run for customer role confirmations
  const role = event.request?.userAttributes?.['custom:role'];
  const triggerSource = event.triggerSource;

  // Only handle PostConfirmation_ConfirmSignUp
  if (triggerSource !== 'PostConfirmation_ConfirmSignUp') {
    return event;
  }

  // Only create profiles for customers
  if (role !== 'customer') {
    return event;
  }

  const userId = event.userName;
  const attrs = event.request.userAttributes;
  const now = new Date().toISOString();

  try {
    // Idempotency check: only create if not already exists
    const existing = await getItem(USERS_TABLE, {
      PK: `USER#${userId}`,
      SK: 'PROFILE',
    });

    if (existing) {
      console.log(`Profile already exists for user ${userId}, skipping`);
      return event;
    }

    await putItem(USERS_TABLE, {
      PK: `USER#${userId}`,
      SK: 'PROFILE',
      userId,
      role: 'customer',
      phone: attrs.phone_number || '',
      email: attrs.email || null,
      displayName: attrs.name || attrs.phone_number || '',
      photoUrl: null,
      address: null,
      city: null,
      state: null,
      pincode: null,
      totalDue: 0,
      totalPaid: 0,
      linkedShopsCount: 0,
      createdAt: now,
      updatedAt: now,
      // Prevent schema drift
      _schemaVersion: 1,
    });

    console.log(`Customer profile created for user: ${userId}`);
  } catch (err) {
    // Log but do NOT throw — Cognito will retry which causes duplicate account issues
    console.error(`Failed to create customer profile for ${userId}:`, err);
  }

  return event;
};
