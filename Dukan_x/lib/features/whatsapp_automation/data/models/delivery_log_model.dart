// ============================================================================
// DeliveryLogEntry Model — Append-only delivery state transition record
// ============================================================================
// Mirrors backend entity: DeliveryLogEntry (entities.ts)
// ============================================================================

/// Delivery log state — extends outbound status with 'suppressed'.
enum DeliveryLogState {
  queued('queued'),
  sent('sent'),
  delivered('delivered'),
  read('read'),
  failed('failed'),
  expired('expired'),
  suppressed('suppressed');

  const DeliveryLogState(this.value);
  final String value;

  static DeliveryLogState fromString(String s) {
    return DeliveryLogState.values.firstWhere(
      (e) => e.value == s,
      orElse: () => DeliveryLogState.queued,
    );
  }
}

/// DeliveryLogEntry — a single state transition for an outbound message.
class DeliveryLogEntry {
  final String id;
  final String businessId;
  final String tenantId;
  final String outboundMessageId;
  final DeliveryLogState state;
  final String? reason;
  final DateTime timestamp;

  DeliveryLogEntry({
    required this.id,
    required this.businessId,
    required this.tenantId,
    required this.outboundMessageId,
    required this.state,
    this.reason,
    required this.timestamp,
  });

  factory DeliveryLogEntry.fromJson(Map<String, dynamic> json) {
    return DeliveryLogEntry(
      id: json['id'] as String,
      businessId: json['businessId'] as String,
      tenantId: json['tenantId'] as String,
      outboundMessageId: json['outboundMessageId'] as String,
      state: DeliveryLogState.fromString(json['state'] as String),
      reason: json['reason'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'businessId': businessId,
    'tenantId': tenantId,
    'outboundMessageId': outboundMessageId,
    'state': state.value,
    if (reason != null) 'reason': reason,
    'timestamp': timestamp.toIso8601String(),
  };
}
