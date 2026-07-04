// ============================================================================
// MessageTemplate Model — WhatsApp message template with placeholders
// ============================================================================
// Body: 1..4096 chars, placeholders: 0..50
// Mirrors backend entity: MessageTemplate (entities.ts)
// ============================================================================

/// Template status (active/inactive).
enum TemplateStatus {
  active('active'),
  inactive('inactive');

  const TemplateStatus(this.value);
  final String value;

  static TemplateStatus fromString(String s) {
    return TemplateStatus.values.firstWhere(
      (e) => e.value == s,
      orElse: () => TemplateStatus.active,
    );
  }
}

/// MessageTemplate — admin-created template with placeholder support.
class MessageTemplate {
  final String id;
  final String businessId;
  final String tenantId;
  final String name;
  final String businessType;
  final String locale;
  final String body;
  final List<String> placeholders;
  final int currentVersion;
  final TemplateStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  MessageTemplate({
    required this.id,
    required this.businessId,
    required this.tenantId,
    required this.name,
    required this.businessType,
    required this.locale,
    required this.body,
    required this.placeholders,
    required this.currentVersion,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MessageTemplate.fromJson(Map<String, dynamic> json) {
    return MessageTemplate(
      id: json['id'] as String,
      businessId: json['businessId'] as String,
      tenantId: json['tenantId'] as String,
      name: json['name'] as String,
      businessType: json['businessType'] as String? ?? '',
      locale: json['locale'] as String? ?? 'en',
      body: json['body'] as String,
      placeholders:
          (json['placeholders'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      currentVersion: json['currentVersion'] as int? ?? 1,
      status: TemplateStatus.fromString(json['status'] as String? ?? 'active'),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'businessId': businessId,
    'tenantId': tenantId,
    'name': name,
    'businessType': businessType,
    'locale': locale,
    'body': body,
    'placeholders': placeholders,
    'currentVersion': currentVersion,
    'status': status.value,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  MessageTemplate copyWith({
    String? name,
    String? body,
    List<String>? placeholders,
    String? locale,
    TemplateStatus? status,
  }) {
    return MessageTemplate(
      id: id,
      businessId: businessId,
      tenantId: tenantId,
      name: name ?? this.name,
      businessType: businessType,
      locale: locale ?? this.locale,
      body: body ?? this.body,
      placeholders: placeholders ?? this.placeholders,
      currentVersion: currentVersion,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
