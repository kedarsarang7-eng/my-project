// ============================================================================
// AuditLogEntry Model — Append-only security/config/consent audit record
// ============================================================================
// Mirrors backend entity: AuditLogEntry (entities.ts)
// ============================================================================

/// AuditLogEntry — records who did what, with before/after snapshots.
class AuditLogEntry {
  final String id;
  final String businessId;
  final String tenantId;
  final String actor;
  final String action;
  final String target;
  final dynamic before;
  final dynamic after;
  final DateTime timestamp;

  AuditLogEntry({
    required this.id,
    required this.businessId,
    required this.tenantId,
    required this.actor,
    required this.action,
    required this.target,
    this.before,
    this.after,
    required this.timestamp,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: json['id'] as String,
      businessId: json['businessId'] as String,
      tenantId: json['tenantId'] as String,
      actor: json['actor'] as String,
      action: json['action'] as String,
      target: json['target'] as String,
      before: json['before'],
      after: json['after'],
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'businessId': businessId,
    'tenantId': tenantId,
    'actor': actor,
    'action': action,
    'target': target,
    if (before != null) 'before': before,
    if (after != null) 'after': after,
    'timestamp': timestamp.toIso8601String(),
  };
}
