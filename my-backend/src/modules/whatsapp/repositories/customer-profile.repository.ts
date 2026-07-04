// ============================================================================
// WhatsApp Module — CustomerProfile Repository (Task 3.1)
// ============================================================================
// CRUD for CustomerProfile entities scoped to the authenticated BusinessID.
// Handles customer identification through their profile ID, registered mobile
// number (E.164), and unique identifiers. Cross-business access is impossible by
// design: every operation is scoped by businessPK.
//
// SK: WACUST#{customerId}
//
// CRITICAL DESIGN DECISIONS:
// - Customers are identified by their unique customerId within a business
// - The whatsappNumber is validated E.164 and stored per-profile
// - consentState defaults to 'pending' on creation (Req 2.4)
// - eligible is a derived boolean: valid E.164 && opted_in (Req 2.9)
// - Soft-delete preserves audit trail
//
// Requirements: 2.1, 2.3, 2.4, 2.8, 2.9, 12.1
// ============================================================================

import { randomUUID } from 'crypto';
import {
  getItem,
  putItem,
  queryItems,
  updateItem,
} from '../../../config/dynamodb.config';
import {
  buildCustomerProfileKeys,
  WACUST_SK_PREFIX,
  WA_ENTITY_TYPE,
  type WaEntityKeys,
  type WaEntityType,
} from '../keys';
import type { CustomerProfile, ConsentState } from '../schemas/entities';

/** Stored DynamoDB item shape. */
type CustomerProfileItem = CustomerProfile & {
  PK: string;
  SK: string;
  GSI1PK?: string;
  GSI1SK?: string;
  entityType: string;
};

function toDomain(item: CustomerProfileItem): CustomerProfile {
  return {
    id: item.id,
    businessId: item.businessId,
    tenantId: item.tenantId,
    whatsappNumber: item.whatsappNumber,
    consentState: item.consentState,
    locale: item.locale,
    messagingPreferences: item.messagingPreferences,
    eligible: item.eligible,
    isDeleted: item.isDeleted,
    createdAt: item.createdAt,
    updatedAt: item.updatedAt,
  };
}

/** Derive the 'eligible' flag from profile state (Req 2.9). */
function deriveEligibility(
  whatsappNumber: string,
  consentState: ConsentState,
): boolean {
  // Eligible = valid E.164 number + opted_in consent
  const validE164 = /^\+\d{8,15}$/.test(whatsappNumber);
  return validE164 && consentState === 'opted_in';
}

/** Input for creating a new CustomerProfile. */
export interface CustomerProfileCreateInput {
  /** Optional: provide a specific customerId (e.g. linked from the main customer record). */
  customerId?: string;
  whatsappNumber: string;
  consentState?: ConsentState;
  locale?: string;
  messagingPreferences?: CustomerProfile['messagingPreferences'];
}

export class CustomerProfileRepository {
  /**
   * Create a new customer profile with consent defaulting to 'pending'.
   */
  async create(
    tenantId: string,
    businessId: string,
    data: CustomerProfileCreateInput,
  ): Promise<CustomerProfile> {
    const id = data.customerId ?? randomUUID();
    const now = new Date().toISOString();
    const consentState: ConsentState = data.consentState ?? 'pending';
    const eligible = deriveEligibility(data.whatsappNumber, consentState);

    const keys = buildCustomerProfileKeys(tenantId, businessId, id, now);

    const item: CustomerProfileItem = {
      PK: keys.PK,
      SK: keys.SK,
      GSI1PK: keys.GSI1PK,
      GSI1SK: keys.GSI1SK,
      entityType: WA_ENTITY_TYPE.CUSTOMER,
      id,
      tenantId,
      businessId,
      whatsappNumber: data.whatsappNumber,
      consentState,
      locale: data.locale ?? 'en',
      messagingPreferences: data.messagingPreferences,
      eligible,
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    };

    await putItem(item as unknown as Record<string, unknown>);
    return toDomain(item);
  }

  /**
   * Fetch a single customer profile by ID. Returns null when absent or soft-deleted.
   */
  async get(
    tenantId: string,
    businessId: string,
    customerId: string,
  ): Promise<CustomerProfile | null> {
    const keys = buildCustomerProfileKeys(tenantId, businessId, customerId, '1970-01-01');
    const item = await getItem<CustomerProfileItem>(keys.PK, keys.SK);
    if (!item || item.isDeleted) return null;
    return toDomain(item);
  }

  /**
   * List all non-deleted customer profiles in a business.
   */
  async list(
    tenantId: string,
    businessId: string,
    opts?: { limit?: number; scanIndexForward?: boolean },
  ): Promise<CustomerProfile[]> {
    const keys = buildCustomerProfileKeys(tenantId, businessId, 'x', '1970-01-01');
    const result = await queryItems<CustomerProfileItem>(keys.PK, WACUST_SK_PREFIX, {
      filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
      expressionAttributeValues: { ':false': false },
      limit: opts?.limit,
      scanIndexForward: opts?.scanIndexForward,
    });
    return result.items.map(toDomain);
  }

  /**
   * Update customer profile fields. Automatically recomputes 'eligible' when
   * whatsappNumber or consentState changes.
   */
  async update(
    tenantId: string,
    businessId: string,
    customerId: string,
    fields: Record<string, unknown>,
  ): Promise<CustomerProfile | null> {
    // If consent or number are changing, recompute eligibility.
    const needsEligibilityRecompute =
      'consentState' in fields || 'whatsappNumber' in fields;

    let finalFields = { ...fields };

    if (needsEligibilityRecompute) {
      // Read the current state to compute eligibility.
      const current = await this.get(tenantId, businessId, customerId);
      if (!current) return null;

      const number = (fields.whatsappNumber as string) ?? current.whatsappNumber;
      const consent = (fields.consentState as ConsentState) ?? current.consentState;
      finalFields.eligible = deriveEligibility(number, consent);
    }

    const keys = buildCustomerProfileKeys(tenantId, businessId, customerId, '1970-01-01');
    const now = new Date().toISOString();

    const entries = Object.entries(finalFields).filter(([, v]) => v !== undefined);
    if (entries.length === 0) return this.get(tenantId, businessId, customerId);

    const exprParts: string[] = ['#updatedAt = :updatedAt'];
    const exprValues: Record<string, unknown> = { ':updatedAt': now };
    const exprNames: Record<string, string> = { '#updatedAt': 'updatedAt' };

    for (const [key, value] of entries) {
      const placeholder = `:f_${key}`;
      const alias = `#f_${key}`;
      exprParts.push(`${alias} = ${placeholder}`);
      exprValues[placeholder] = value;
      exprNames[alias] = key;
    }

    const updated = await updateItem(keys.PK, keys.SK, {
      updateExpression: `SET ${exprParts.join(', ')}`,
      expressionAttributeValues: exprValues,
      expressionAttributeNames: exprNames,
      conditionExpression: 'attribute_exists(SK)',
    });
    if (!updated) return null;
    return toDomain(updated as unknown as CustomerProfileItem);
  }

  /**
   * Update consent state specifically. Recomputes eligibility.
   */
  async setConsentState(
    tenantId: string,
    businessId: string,
    customerId: string,
    consentState: ConsentState,
  ): Promise<CustomerProfile | null> {
    return this.update(tenantId, businessId, customerId, { consentState });
  }

  /**
   * Look up a customer profile by their WhatsApp number within a business.
   * Useful for inbound message processing where we only know the phone number.
   * Returns the first match (there should be exactly one per business).
   */
  async findByWhatsappNumber(
    tenantId: string,
    businessId: string,
    whatsappNumber: string,
  ): Promise<CustomerProfile | null> {
    const keys = buildCustomerProfileKeys(tenantId, businessId, 'x', '1970-01-01');
    const result = await queryItems<CustomerProfileItem>(keys.PK, WACUST_SK_PREFIX, {
      filterExpression:
        '(attribute_not_exists(isDeleted) OR isDeleted = :false) AND whatsappNumber = :phone',
      expressionAttributeValues: { ':false': false, ':phone': whatsappNumber },
      limit: 1,
    });
    return result.items.length > 0 ? toDomain(result.items[0]) : null;
  }

  /**
   * Soft-delete a customer profile. Preserves audit trail.
   */
  async deactivate(
    tenantId: string,
    businessId: string,
    customerId: string,
  ): Promise<boolean> {
    const keys = buildCustomerProfileKeys(tenantId, businessId, customerId, '1970-01-01');
    const now = new Date().toISOString();
    try {
      await updateItem(keys.PK, keys.SK, {
        updateExpression: 'SET isDeleted = :true, updatedAt = :now',
        expressionAttributeValues: { ':true': true, ':now': now },
        conditionExpression: 'attribute_exists(SK)',
      });
      return true;
    } catch (err) {
      if ((err as { name?: string }).name === 'ConditionalCheckFailedException') {
        return false;
      }
      throw err;
    }
  }
}
