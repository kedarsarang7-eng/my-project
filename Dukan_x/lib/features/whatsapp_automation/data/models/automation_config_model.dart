// ============================================================================
// AutomationConfig Model — Business-type × Tier automation configuration
// ============================================================================
// Maps a business type and subscription tier to enabled automations and channels.
// Mirrors backend entity: AutomationConfig (entities.ts)
// ============================================================================

/// Entry describing a single automation slot (enabled + optional template/rule bindings).
class AutomationEntry {
  final bool enabled;
  final String? templateId;
  final List<String>? ruleIds;

  const AutomationEntry({required this.enabled, this.templateId, this.ruleIds});

  factory AutomationEntry.fromJson(Map<String, dynamic> json) {
    return AutomationEntry(
      enabled: json['enabled'] as bool? ?? false,
      templateId: json['templateId'] as String?,
      ruleIds: (json['ruleIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    if (templateId != null) 'templateId': templateId,
    if (ruleIds != null) 'ruleIds': ruleIds,
  };
}

/// Entry describing a channel's enabled state.
class ChannelEntry {
  final bool enabled;

  const ChannelEntry({required this.enabled});

  factory ChannelEntry.fromJson(Map<String, dynamic> json) {
    return ChannelEntry(enabled: json['enabled'] as bool? ?? false);
  }

  Map<String, dynamic> toJson() => {'enabled': enabled};
}

/// AutomationConfig — maps BusinessType × SubscriptionTier to automations/channels.
class AutomationConfig {
  final String id;
  final String businessId;
  final String tenantId;
  final String businessType;
  final String tier;
  final Map<String, AutomationEntry> automations;
  final Map<String, ChannelEntry> channels;
  final int schemaVersion;
  final DateTime createdAt;
  final DateTime updatedAt;

  AutomationConfig({
    required this.id,
    required this.businessId,
    required this.tenantId,
    required this.businessType,
    required this.tier,
    required this.automations,
    required this.channels,
    required this.schemaVersion,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AutomationConfig.fromJson(Map<String, dynamic> json) {
    return AutomationConfig(
      id: json['id'] as String,
      businessId: json['businessId'] as String,
      tenantId: json['tenantId'] as String,
      businessType: json['businessType'] as String,
      tier: json['tier'] as String,
      automations:
          (json['automations'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(
              k,
              AutomationEntry.fromJson(v as Map<String, dynamic>),
            ),
          ) ??
          {},
      channels:
          (json['channels'] as Map<String, dynamic>?)?.map(
            (k, v) =>
                MapEntry(k, ChannelEntry.fromJson(v as Map<String, dynamic>)),
          ) ??
          {},
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'businessId': businessId,
    'tenantId': tenantId,
    'businessType': businessType,
    'tier': tier,
    'automations': automations.map((k, v) => MapEntry(k, v.toJson())),
    'channels': channels.map((k, v) => MapEntry(k, v.toJson())),
    'schemaVersion': schemaVersion,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
