// ============================================================================
// AutomationRule Model — Event-driven rule binding template to recipients
// ============================================================================
// Mirrors backend entity: AutomationRule (entities.ts)
// ============================================================================

/// Condition operator for rule matching.
enum RuleOperator {
  eq('eq'),
  neq('neq'),
  gt('gt'),
  gte('gte'),
  lt('lt'),
  lte('lte'),
  isIn('in'),
  notIn('not_in'),
  exists('exists'),
  notExists('not_exists');

  const RuleOperator(this.value);
  final String value;

  static RuleOperator fromString(String s) {
    return RuleOperator.values.firstWhere(
      (e) => e.value == s,
      orElse: () => RuleOperator.eq,
    );
  }
}

/// A single condition within a rule.
class RuleCondition {
  final String field;
  final RuleOperator operator;
  final dynamic value;

  const RuleCondition({
    required this.field,
    required this.operator,
    this.value,
  });

  factory RuleCondition.fromJson(Map<String, dynamic> json) {
    return RuleCondition(
      field: json['field'] as String,
      operator: RuleOperator.fromString(json['operator'] as String),
      value: json['value'],
    );
  }

  Map<String, dynamic> toJson() => {
    'field': field,
    'operator': operator.value,
    if (value != null) 'value': value,
  };
}

/// Recipient type enum.
enum RecipientType {
  customer('customer'),
  supplier('supplier'),
  staff('staff'),
  segment('segment');

  const RecipientType(this.value);
  final String value;

  static RecipientType fromString(String s) {
    return RecipientType.values.firstWhere(
      (e) => e.value == s,
      orElse: () => RecipientType.customer,
    );
  }
}

/// Recipient specification (who gets the message).
class RecipientSpec {
  final RecipientType type;
  final String? id;
  final Map<String, dynamic>? segmentFilter;

  const RecipientSpec({required this.type, this.id, this.segmentFilter});

  factory RecipientSpec.fromJson(Map<String, dynamic> json) {
    return RecipientSpec(
      type: RecipientType.fromString(json['type'] as String),
      id: json['id'] as String?,
      segmentFilter: json['segmentFilter'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.value,
    if (id != null) 'id': id,
    if (segmentFilter != null) 'segmentFilter': segmentFilter,
  };
}

/// Schedule for delayed or timed message delivery.
class RuleSchedule {
  final int? delaySeconds;
  final String? at;

  const RuleSchedule({this.delaySeconds, this.at});

  factory RuleSchedule.fromJson(Map<String, dynamic> json) {
    return RuleSchedule(
      delaySeconds: json['delaySeconds'] as int?,
      at: json['at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    if (delaySeconds != null) 'delaySeconds': delaySeconds,
    if (at != null) 'at': at,
  };
}

/// Message category (consent classification).
enum MessageCategory {
  transactional('transactional'),
  nonTransactional('non_transactional');

  const MessageCategory(this.value);
  final String value;

  static MessageCategory fromString(String s) {
    return MessageCategory.values.firstWhere(
      (e) => e.value == s,
      orElse: () => MessageCategory.transactional,
    );
  }
}

/// AutomationRule — binds a business event to template dispatch.
class AutomationRule {
  final String id;
  final String businessId;
  final String tenantId;
  final String? branchId;
  final String eventType;
  final List<RuleCondition> conditions;
  final String templateId;
  final RecipientSpec recipients;
  final RuleSchedule? schedule;
  final MessageCategory category;
  final int? maxReminders;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  AutomationRule({
    required this.id,
    required this.businessId,
    required this.tenantId,
    this.branchId,
    required this.eventType,
    required this.conditions,
    required this.templateId,
    required this.recipients,
    this.schedule,
    required this.category,
    this.maxReminders,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AutomationRule.fromJson(Map<String, dynamic> json) {
    return AutomationRule(
      id: json['id'] as String,
      businessId: json['businessId'] as String,
      tenantId: json['tenantId'] as String,
      branchId: json['branchId'] as String?,
      eventType: json['eventType'] as String,
      conditions:
          (json['conditions'] as List<dynamic>?)
              ?.map((e) => RuleCondition.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      templateId: json['templateId'] as String,
      recipients: RecipientSpec.fromJson(
        json['recipients'] as Map<String, dynamic>,
      ),
      schedule: json['schedule'] != null
          ? RuleSchedule.fromJson(json['schedule'] as Map<String, dynamic>)
          : null,
      category: MessageCategory.fromString(
        json['category'] as String? ?? 'transactional',
      ),
      maxReminders: json['maxReminders'] as int?,
      enabled: json['enabled'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'businessId': businessId,
    'tenantId': tenantId,
    if (branchId != null) 'branchId': branchId,
    'eventType': eventType,
    'conditions': conditions.map((c) => c.toJson()).toList(),
    'templateId': templateId,
    'recipients': recipients.toJson(),
    if (schedule != null) 'schedule': schedule!.toJson(),
    'category': category.value,
    if (maxReminders != null) 'maxReminders': maxReminders,
    'enabled': enabled,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  AutomationRule copyWith({
    String? eventType,
    List<RuleCondition>? conditions,
    String? templateId,
    RecipientSpec? recipients,
    RuleSchedule? schedule,
    MessageCategory? category,
    bool? enabled,
  }) {
    return AutomationRule(
      id: id,
      businessId: businessId,
      tenantId: tenantId,
      branchId: branchId,
      eventType: eventType ?? this.eventType,
      conditions: conditions ?? this.conditions,
      templateId: templateId ?? this.templateId,
      recipients: recipients ?? this.recipients,
      schedule: schedule ?? this.schedule,
      category: category ?? this.category,
      maxReminders: maxReminders,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
