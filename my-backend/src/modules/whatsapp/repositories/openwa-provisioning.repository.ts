// ============================================================================
// WhatsApp Module — OpenWaProvisioning Repository (Task 4)
// ============================================================================
// CRUD for the OpenWaProvisioningConfig STATUS record (singleton per
// business, SK: WAPROV#CONFIG). Holds ONLY non-secret metadata — the actual
// apiKey/webhookSecret live in AWS Secrets Manager via
// services/openwa-provisioning.service.ts, never in this DynamoDB record.
//
// Requirements: 12.1 (business-scoped records), 12.4 (session-authoritative ID)
// ============================================================================

import { getItem, putItem, updateItem, deleteItem } from '../../../config/dynamodb.config';
import {
  buildOpenWaProvisioningKeys,
  WA_ENTITY_TYPE,
} from '../keys';
import type { OpenWaProvisioningConfig } from '../schemas/entities';

type OpenWaProvisioningItem = OpenWaProvisioningConfig & {
  PK: string;
  SK: string;
  GSI1PK?: string;
  GSI1SK?: string;
  entityType: string;
};

function toDomain(item: OpenWaProvisioningItem): OpenWaProvisioningConfig {
  return {
    id: item.id,
    businessId: item.businessId,
    tenantId: item.tenantId,
    sessionId: item.sessionId,
    baseUrl: item.baseUrl,
    status: item.status,
    displayName: item.displayName,
    webhookId: item.webhookId,
    lastError: item.lastError,
    verifiedAt: item.verifiedAt,
    createdAt: item.createdAt,
    updatedAt: item.updatedAt,
  };
}

export class OpenWaProvisioningRepository {
  /** Get the provisioning status record for a business. Returns null when absent. */
  async get(
    tenantId: string,
    businessId: string,
  ): Promise<OpenWaProvisioningConfig | null> {
    const keys = buildOpenWaProvisioningKeys(tenantId, businessId);
    const item = await getItem<OpenWaProvisioningItem>(keys.PK, keys.SK);
    if (!item) return null;
    return toDomain(item);
  }

  /**
   * Create or fully replace the provisioning status record.
   * Called on initial save and on credential rotation (re-save).
   */
  async upsert(
    tenantId: string,
    businessId: string,
    data: {
      id: string;
      sessionId: string;
      baseUrl: string;
      status: OpenWaProvisioningConfig['status'];
      displayName?: string;
      webhookId?: string;
      lastError?: string;
      verifiedAt?: string;
    },
  ): Promise<OpenWaProvisioningConfig> {
    const now = new Date().toISOString();
    const keys = buildOpenWaProvisioningKeys(tenantId, businessId);

    const item: OpenWaProvisioningItem = {
      PK: keys.PK,
      SK: keys.SK,
      GSI1PK: keys.GSI1PK,
      GSI1SK: keys.GSI1SK,
      entityType: WA_ENTITY_TYPE.PROVISIONING,
      id: data.id,
      tenantId,
      businessId,
      sessionId: data.sessionId,
      baseUrl: data.baseUrl,
      status: data.status,
      displayName: data.displayName,
      webhookId: data.webhookId,
      lastError: data.lastError,
      verifiedAt: data.verifiedAt,
      createdAt: now,
      updatedAt: now,
    };

    await putItem(item as unknown as Record<string, unknown>);
    return toDomain(item);
  }

  /** Patch specific fields (e.g. status transitions after verify/activate). */
  async update(
    tenantId: string,
    businessId: string,
    fields: Partial<Pick<OpenWaProvisioningConfig, 'status' | 'webhookId' | 'lastError' | 'verifiedAt'>>,
  ): Promise<OpenWaProvisioningConfig | null> {
    const keys = buildOpenWaProvisioningKeys(tenantId, businessId);
    const now = new Date().toISOString();

    const entries = Object.entries(fields).filter(([, v]) => v !== undefined);
    if (entries.length === 0) return this.get(tenantId, businessId);

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
    return toDomain(updated as unknown as OpenWaProvisioningItem);
  }

  /**
   * Hard-delete the status record. Called after the corresponding secret
   * and registered webhook have been removed (Req: no orphaned metadata).
   */
  async remove(tenantId: string, businessId: string): Promise<void> {
    const keys = buildOpenWaProvisioningKeys(tenantId, businessId);
    await deleteItem(keys.PK, keys.SK);
  }
}
