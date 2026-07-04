// ============================================================================
// WhatsApp Module — AutomationConfig Repository (Task 3.1)
// ============================================================================
// CRUD for AutomationConfig entities scoped to the authenticated BusinessID.
//
// SK: WACFG#{businessType}#{tier}
// Key structure: one config per (businessType, tier) combination within a business.
//
// Requirements: 1.1, 1.8, 12.1
// ============================================================================

import {
  getItem,
  putItem,
  queryItems,
  updateItem,
} from '../../../config/dynamodb.config';
import {
  buildAutomationConfigKeys,
  WACFG_SK_PREFIX,
  automationConfigSK,
  WA_ENTITY_TYPE,
  type WaEntityKeys,
  type WaEntityType,
} from '../keys';
import type { AutomationConfig } from '../schemas/entities';

/** The stored DynamoDB item shape. */
type AutomationConfigItem = AutomationConfig & {
  PK: string;
  SK: string;
  GSI1PK?: string;
  GSI1SK?: string;
  entityType: string;
  isDeleted: boolean;
};

function toDomain(item: AutomationConfigItem): AutomationConfig {
  return {
    id: item.id,
    businessId: item.businessId,
    tenantId: item.tenantId,
    businessType: item.businessType,
    tier: item.tier,
    automations: item.automations,
    channels: item.channels,
    schemaVersion: item.schemaVersion,
    createdAt: item.createdAt,
    updatedAt: item.updatedAt,
  };
}

/**
 * Repository for AutomationConfig entities.
 *
 * Unlike most entities keyed by a random UUID, AutomationConfig is keyed by
 * (businessType, tier) — so it uses upsert semantics (put-or-replace) and
 * does NOT extend the generic WaBaseRepository (which generates random IDs).
 */
export class AutomationConfigRepository {
  /**
   * Get the config for a specific (businessType, tier) combination.
   * Returns null when absent.
   */
  async get(
    tenantId: string,
    businessId: string,
    businessType: string,
    tier: string,
  ): Promise<AutomationConfig | null> {
    const keys = buildAutomationConfigKeys(tenantId, businessId, businessType, tier);
    const item = await getItem<AutomationConfigItem>(keys.PK, keys.SK);
    if (!item || item.isDeleted) return null;
    return toDomain(item);
  }

  /**
   * Upsert an AutomationConfig. If the config already exists for this
   * (businessType, tier) it is replaced (idempotent put).
   */
  async upsert(
    tenantId: string,
    businessId: string,
    data: Omit<AutomationConfig, 'createdAt' | 'updatedAt'>,
  ): Promise<AutomationConfig> {
    const now = new Date().toISOString();
    const keys = buildAutomationConfigKeys(tenantId, businessId, data.businessType, data.tier);

    const item: AutomationConfigItem = {
      PK: keys.PK,
      SK: keys.SK,
      GSI1PK: keys.GSI1PK,
      GSI1SK: keys.GSI1SK,
      entityType: WA_ENTITY_TYPE.CONFIG,
      id: data.id,
      tenantId,
      businessId,
      businessType: data.businessType,
      tier: data.tier,
      automations: data.automations,
      channels: data.channels,
      schemaVersion: data.schemaVersion,
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    };

    await putItem(item as unknown as Record<string, unknown>);
    return toDomain(item);
  }

  /**
   * List all configs for a business (across all businessType/tier combos).
   */
  async list(
    tenantId: string,
    businessId: string,
  ): Promise<AutomationConfig[]> {
    const keys = buildAutomationConfigKeys(tenantId, businessId, 'x', 'x');
    const result = await queryItems<AutomationConfigItem>(keys.PK, WACFG_SK_PREFIX, {
      filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
      expressionAttributeValues: { ':false': false },
    });
    return result.items.map(toDomain);
  }

  /**
   * Update specific fields on a config. Returns the updated config or null.
   */
  async update(
    tenantId: string,
    businessId: string,
    businessType: string,
    tier: string,
    fields: Record<string, unknown>,
  ): Promise<AutomationConfig | null> {
    const keys = buildAutomationConfigKeys(tenantId, businessId, businessType, tier);
    const now = new Date().toISOString();

    const entries = Object.entries(fields).filter(([, v]) => v !== undefined);
    if (entries.length === 0) return this.get(tenantId, businessId, businessType, tier);

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
    return toDomain(updated as unknown as AutomationConfigItem);
  }

  /**
   * Soft-delete a config.
   */
  async deactivate(
    tenantId: string,
    businessId: string,
    businessType: string,
    tier: string,
  ): Promise<boolean> {
    const keys = buildAutomationConfigKeys(tenantId, businessId, businessType, tier);
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
