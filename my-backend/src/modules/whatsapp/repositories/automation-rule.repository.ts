// ============================================================================
// WhatsApp Module — AutomationRule Repository (Task 3.1)
// ============================================================================
// CRUD + enable/disable for AutomationRule entities scoped to the authenticated
// BusinessID.
//
// SK: WARULE#{id}
//
// Requirements: 7.5, 7.6, 12.1
// ============================================================================

import { queryItems } from '../../../config/dynamodb.config';
import {
  buildAutomationRuleKeys,
  WARULE_SK_PREFIX,
  WA_ENTITY_TYPE,
  type WaEntityKeys,
  type WaEntityType,
} from '../keys';
import { WaBaseRepository, type WaBaseItem } from './base.repository';
import type { AutomationRule } from '../schemas/entities';

/** Input for creating a new AutomationRule. */
export interface AutomationRuleCreateInput {
  branchId?: string;
  eventType: string;
  conditions: AutomationRule['conditions'];
  templateId: string;
  recipients: AutomationRule['recipients'];
  schedule?: AutomationRule['schedule'];
  category: AutomationRule['category'];
  maxReminders?: number;
  enabled: boolean;
}

export class AutomationRuleRepository extends WaBaseRepository<AutomationRule, AutomationRuleCreateInput> {
  protected readonly entityType: WaEntityType = WA_ENTITY_TYPE.RULE;
  protected readonly skPrefix = WARULE_SK_PREFIX;

  protected buildKeys(
    tenantId: string,
    businessId: string,
    id: string,
    extras?: Record<string, string>,
  ): WaEntityKeys {
    const isoDate = extras?.isoDate ?? new Date().toISOString();
    return buildAutomationRuleKeys(tenantId, businessId, id, isoDate);
  }

  protected toDomain(item: WaBaseItem & Record<string, unknown>): AutomationRule {
    return {
      id: item.id,
      businessId: item.businessId,
      tenantId: item.tenantId as string,
      branchId: item.branchId as string | undefined,
      eventType: item.eventType as string,
      conditions: (item.conditions as AutomationRule['conditions']) ?? [],
      templateId: item.templateId as string,
      recipients: item.recipients as AutomationRule['recipients'],
      schedule: item.schedule as AutomationRule['schedule'] | undefined,
      category: item.category as AutomationRule['category'],
      maxReminders: item.maxReminders as number | undefined,
      enabled: item.enabled as boolean,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    };
  }

  protected buildCreateItem(
    tenantId: string,
    businessId: string,
    id: string,
    keys: WaEntityKeys,
    data: AutomationRuleCreateInput,
    now: string,
  ): WaBaseItem & Record<string, unknown> {
    return {
      PK: keys.PK,
      SK: keys.SK,
      GSI1PK: keys.GSI1PK,
      GSI1SK: keys.GSI1SK,
      entityType: this.entityType,
      tenantId,
      businessId,
      id,
      branchId: data.branchId,
      eventType: data.eventType,
      conditions: data.conditions,
      templateId: data.templateId,
      recipients: data.recipients,
      schedule: data.schedule,
      category: data.category,
      maxReminders: data.maxReminders,
      enabled: data.enabled,
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    };
  }

  /**
   * Enable or disable a rule without modifying other fields.
   */
  async setEnabled(
    tenantId: string,
    businessId: string,
    ruleId: string,
    enabled: boolean,
  ): Promise<AutomationRule | null> {
    return this.update(tenantId, businessId, ruleId, { enabled });
  }

  /**
   * List rules filtered by event type (for engine evaluation).
   */
  async listByEventType(
    tenantId: string,
    businessId: string,
    eventType: string,
  ): Promise<AutomationRule[]> {
    const keys = this.buildKeys(tenantId, businessId, 'x');
    const result = await queryItems<WaBaseItem & Record<string, unknown>>(keys.PK, WARULE_SK_PREFIX, {
      filterExpression:
        '(attribute_not_exists(isDeleted) OR isDeleted = :false) AND #eventType = :eventType',
      expressionAttributeValues: { ':false': false, ':eventType': eventType },
      expressionAttributeNames: { '#eventType': 'eventType' },
    });
    return result.items.map((item) => this.toDomain(item));
  }
}
