// ============================================================================
// WhatsApp Module — MessageTemplate Repository (Task 3.1)
// ============================================================================
// CRUD + deactivate for MessageTemplate entities, plus immutable version history
// via MessageTemplateVersion items. Scoped to the authenticated BusinessID.
//
// SK: WATMPL#{id}  (current pointer)
// SK: WATMPLV#{templateId}#{version}  (immutable version history)
//
// VERSION HISTORY (Req 7.7):
// Every create/update to a template also writes an immutable WATMPLV# version
// item, so the exact template text used by any past Outbound_Message is always
// recoverable from (templateId, version).
//
// Requirements: 7.1, 7.2, 7.6, 7.7, 12.1
// ============================================================================

import { randomUUID } from 'crypto';
import {
  getItem,
  putItem,
  queryItems,
  updateItem,
} from '../../../config/dynamodb.config';
import {
  buildMessageTemplateKeys,
  buildMessageTemplateVersionKeys,
  WATMPL_SK_PREFIX,
  WATMPLV_SK_PREFIX,
  messageTemplateVersionSK,
  WA_ENTITY_TYPE,
  type WaEntityKeys,
} from '../keys';
import type { MessageTemplate, MessageTemplateVersion } from '../schemas/entities';

/** Stored DynamoDB item for current template pointer. */
type MessageTemplateItem = MessageTemplate & {
  PK: string;
  SK: string;
  GSI1PK?: string;
  GSI1SK?: string;
  entityType: string;
  isDeleted: boolean;
};

/** Stored DynamoDB item for immutable version snapshot. */
type MessageTemplateVersionItem = MessageTemplateVersion & {
  PK: string;
  SK: string;
  GSI1PK?: string;
  GSI1SK?: string;
  entityType: string;
};

function toTemplate(item: MessageTemplateItem): MessageTemplate {
  return {
    id: item.id,
    businessId: item.businessId,
    tenantId: item.tenantId,
    name: item.name,
    businessType: item.businessType,
    locale: item.locale,
    body: item.body,
    placeholders: item.placeholders,
    currentVersion: item.currentVersion,
    status: item.status,
    createdAt: item.createdAt,
    updatedAt: item.updatedAt,
  };
}

function toVersion(item: MessageTemplateVersionItem): MessageTemplateVersion {
  return {
    id: item.id,
    templateId: item.templateId,
    businessId: item.businessId,
    tenantId: item.tenantId,
    version: item.version,
    body: item.body,
    placeholders: item.placeholders,
    createdAt: item.createdAt,
    createdBy: item.createdBy,
  };
}

/** Input for creating a new template. */
export interface MessageTemplateCreateInput {
  name: string;
  businessType: string;
  locale: string;
  body: string;
  placeholders: string[];
  createdBy: string;
}

/** Input for updating an existing template. */
export interface MessageTemplateUpdateInput {
  name?: string;
  body?: string;
  placeholders?: string[];
  locale?: string;
  updatedBy: string;
}

export class MessageTemplateRepository {
  /**
   * Create a new template (version 1) and its first immutable version snapshot.
   */
  async create(
    tenantId: string,
    businessId: string,
    data: MessageTemplateCreateInput,
  ): Promise<MessageTemplate> {
    const id = randomUUID();
    const now = new Date().toISOString();
    const version = 1;

    const templateKeys = buildMessageTemplateKeys(tenantId, businessId, id, now);
    const versionKeys = buildMessageTemplateVersionKeys(tenantId, businessId, id, version, now);

    // Write the current-pointer item.
    const templateItem: MessageTemplateItem = {
      PK: templateKeys.PK,
      SK: templateKeys.SK,
      GSI1PK: templateKeys.GSI1PK,
      GSI1SK: templateKeys.GSI1SK,
      entityType: WA_ENTITY_TYPE.TEMPLATE,
      id,
      tenantId,
      businessId,
      name: data.name,
      businessType: data.businessType,
      locale: data.locale,
      body: data.body,
      placeholders: data.placeholders,
      currentVersion: version,
      status: 'active',
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    };

    // Write the immutable version-history item.
    const versionItem: MessageTemplateVersionItem = {
      PK: versionKeys.PK,
      SK: versionKeys.SK,
      GSI1PK: versionKeys.GSI1PK,
      GSI1SK: versionKeys.GSI1SK,
      entityType: WA_ENTITY_TYPE.TEMPLATE_VERSION,
      id: randomUUID(),
      templateId: id,
      tenantId,
      businessId,
      version,
      body: data.body,
      placeholders: data.placeholders,
      createdAt: now,
      createdBy: data.createdBy,
    };

    await putItem(templateItem as unknown as Record<string, unknown>);
    await putItem(versionItem as unknown as Record<string, unknown>);

    return toTemplate(templateItem);
  }

  /**
   * Fetch a single template by ID. Returns null when absent or soft-deleted.
   */
  async get(
    tenantId: string,
    businessId: string,
    templateId: string,
  ): Promise<MessageTemplate | null> {
    const keys = buildMessageTemplateKeys(tenantId, businessId, templateId, '1970-01-01');
    const item = await getItem<MessageTemplateItem>(keys.PK, keys.SK);
    if (!item || item.isDeleted) return null;
    return toTemplate(item);
  }

  /**
   * List all active (non-deleted) templates for a business.
   */
  async list(
    tenantId: string,
    businessId: string,
    opts?: { limit?: number; scanIndexForward?: boolean },
  ): Promise<MessageTemplate[]> {
    const keys = buildMessageTemplateKeys(tenantId, businessId, 'x', '1970-01-01');
    const result = await queryItems<MessageTemplateItem>(keys.PK, WATMPL_SK_PREFIX, {
      filterExpression: '(attribute_not_exists(isDeleted) OR isDeleted = :false)',
      expressionAttributeValues: { ':false': false },
      limit: opts?.limit,
      scanIndexForward: opts?.scanIndexForward,
    });
    return result.items.map(toTemplate);
  }

  /**
   * Update a template's mutable fields. Increments version and writes a new
   * immutable version-history item (Req 7.7).
   */
  async update(
    tenantId: string,
    businessId: string,
    templateId: string,
    data: MessageTemplateUpdateInput,
  ): Promise<MessageTemplate | null> {
    // Read the current template to get the version.
    const current = await this.get(tenantId, businessId, templateId);
    if (!current) return null;

    const newVersion = current.currentVersion + 1;
    const now = new Date().toISOString();

    // Fields to update on the current pointer.
    const fieldsToSet: Record<string, unknown> = {
      currentVersion: newVersion,
    };
    if (data.name !== undefined) fieldsToSet.name = data.name;
    if (data.body !== undefined) fieldsToSet.body = data.body;
    if (data.placeholders !== undefined) fieldsToSet.placeholders = data.placeholders;
    if (data.locale !== undefined) fieldsToSet.locale = data.locale;

    const keys = buildMessageTemplateKeys(tenantId, businessId, templateId, now);

    const exprParts: string[] = ['#updatedAt = :updatedAt'];
    const exprValues: Record<string, unknown> = { ':updatedAt': now };
    const exprNames: Record<string, string> = { '#updatedAt': 'updatedAt' };

    for (const [key, value] of Object.entries(fieldsToSet)) {
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

    // Write the immutable version-history snapshot.
    const versionKeys = buildMessageTemplateVersionKeys(
      tenantId, businessId, templateId, newVersion, now,
    );
    const versionItem: MessageTemplateVersionItem = {
      PK: versionKeys.PK,
      SK: versionKeys.SK,
      GSI1PK: versionKeys.GSI1PK,
      GSI1SK: versionKeys.GSI1SK,
      entityType: WA_ENTITY_TYPE.TEMPLATE_VERSION,
      id: randomUUID(),
      templateId,
      tenantId,
      businessId,
      version: newVersion,
      body: data.body ?? current.body,
      placeholders: data.placeholders ?? current.placeholders,
      createdAt: now,
      createdBy: data.updatedBy,
    };
    await putItem(versionItem as unknown as Record<string, unknown>);

    return toTemplate(updated as unknown as MessageTemplateItem);
  }

  /**
   * Deactivate (soft-delete) a template. Does NOT remove version history.
   */
  async deactivate(
    tenantId: string,
    businessId: string,
    templateId: string,
  ): Promise<boolean> {
    const keys = buildMessageTemplateKeys(tenantId, businessId, templateId, '1970-01-01');
    const now = new Date().toISOString();
    try {
      await updateItem(keys.PK, keys.SK, {
        updateExpression:
          'SET isDeleted = :true, #status = :inactive, updatedAt = :now',
        expressionAttributeValues: {
          ':true': true,
          ':inactive': 'inactive',
          ':now': now,
        },
        expressionAttributeNames: { '#status': 'status' },
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

  // ── Version History ───────────────────────────────────────────────────────

  /**
   * Get a specific version snapshot of a template (Req 7.7).
   * Enables exact recoverability of the template text used by a past message.
   */
  async getVersion(
    tenantId: string,
    businessId: string,
    templateId: string,
    version: number,
  ): Promise<MessageTemplateVersion | null> {
    const keys = buildMessageTemplateVersionKeys(
      tenantId, businessId, templateId, version, '1970-01-01',
    );
    const item = await getItem<MessageTemplateVersionItem>(keys.PK, keys.SK);
    return item ? toVersion(item) : null;
  }

  /**
   * List all version snapshots of a template, chronologically.
   */
  async listVersions(
    tenantId: string,
    businessId: string,
    templateId: string,
    opts?: { limit?: number; scanIndexForward?: boolean },
  ): Promise<MessageTemplateVersion[]> {
    const keys = buildMessageTemplateVersionKeys(
      tenantId, businessId, templateId, 1, '1970-01-01',
    );
    // Query using the WATMPLV#{templateId}# prefix to get all versions of this template.
    const skPrefix = `${WATMPLV_SK_PREFIX}${templateId}#`;
    const result = await queryItems<MessageTemplateVersionItem>(keys.PK, skPrefix, {
      limit: opts?.limit,
      scanIndexForward: opts?.scanIndexForward ?? true,
    });
    return result.items.map(toVersion);
  }
}
