// ============================================================================
// OutboundMessage Model — Queued outbound WhatsApp message
// ============================================================================
// Status lifecycle: queued → sent → delivered → read (or failed/expired).
// ONLY these 6 states are valid. Never fabricate others.
// Mirrors backend entity: OutboundMessage (entities.ts)
// ============================================================================

/// Outbound message status — exactly 6 real lifecycle states.
enum OutboundMessageStatus {
  queued('queued'),
  sent('sent'),
  delivered('delivered'),
  read('read'),
  failed('failed'),
  expired('expired');

  const OutboundMessageStatus(this.value);
  final String value;

  static OutboundMessageStatus fromString(String s) {
    return OutboundMessageStatus.values.firstWhere(
      (e) => e.value == s,
      orElse: () => OutboundMessageStatus.queued,
    );
  }
}

/// OutboundMessage — a single outbound WhatsApp message record.
class OutboundMessage {
  final String id;
  final String businessId;
  final String tenantId;
  final String? branchId;
  final String eventId;
  final String recipientId;
  final String recipientNumber;
  final String templateId;
  final int templateVersion;
  final String renderedBody;
  final String? mediaUrl;
  final OutboundMessageStatus status;
  final int attempts;
  final String? lastError;
  final DateTime? nextAttemptAt;
  final DateTime? expiresAt;
  final String? providerMessageId;
  final DateTime createdAt;
  final DateTime updatedAt;

  OutboundMessage({
    required this.id,
    required this.businessId,
    required this.tenantId,
    this.branchId,
    required this.eventId,
    required this.recipientId,
    required this.recipientNumber,
    required this.templateId,
    required this.templateVersion,
    required this.renderedBody,
    this.mediaUrl,
    required this.status,
    required this.attempts,
    this.lastError,
    this.nextAttemptAt,
    this.expiresAt,
    this.providerMessageId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OutboundMessage.fromJson(Map<String, dynamic> json) {
    return OutboundMessage(
      id: json['id'] as String,
      businessId: json['businessId'] as String,
      tenantId: json['tenantId'] as String,
      branchId: json['branchId'] as String?,
      eventId: json['eventId'] as String,
      recipientId: json['recipientId'] as String,
      recipientNumber: json['recipientNumber'] as String,
      templateId: json['templateId'] as String,
      templateVersion: json['templateVersion'] as int? ?? 1,
      renderedBody: json['renderedBody'] as String,
      mediaUrl: json['mediaUrl'] as String?,
      status: OutboundMessageStatus.fromString(json['status'] as String),
      attempts: json['attempts'] as int? ?? 0,
      lastError: json['lastError'] as String?,
      nextAttemptAt: json['nextAttemptAt'] != null
          ? DateTime.parse(json['nextAttemptAt'] as String)
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      providerMessageId: json['providerMessageId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'businessId': businessId,
    'tenantId': tenantId,
    if (branchId != null) 'branchId': branchId,
    'eventId': eventId,
    'recipientId': recipientId,
    'recipientNumber': recipientNumber,
    'templateId': templateId,
    'templateVersion': templateVersion,
    'renderedBody': renderedBody,
    if (mediaUrl != null) 'mediaUrl': mediaUrl,
    'status': status.value,
    'attempts': attempts,
    if (lastError != null) 'lastError': lastError,
    if (nextAttemptAt != null)
      'nextAttemptAt': nextAttemptAt!.toIso8601String(),
    if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
    if (providerMessageId != null) 'providerMessageId': providerMessageId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
