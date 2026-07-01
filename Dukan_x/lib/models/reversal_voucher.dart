import 'package:dukanx/core/compat/firestore_compat.dart';

/// Reversal Voucher - Links original transaction to its reversal.
///
/// When a transaction is edited or deleted, we don't modify/remove the
/// original ledger entries. Instead, we:
/// 1. Create reversing entries (Debit ↔ Credit swapped)
/// 2. Mark the original as reversed
/// 3. Create a ReversalVoucher for audit trail
///
/// This ensures:
/// - Complete audit trail
/// - Immutable historical records
/// - Easy reconciliation
class ReversalVoucher {
  final String id;
  final String businessId;
  final String originalTxnId;
  final String? reversalTxnId; // The new transaction ID created for reversal
  final ReversalReason reason;
  final String? notes;
  final DateTime reversalDate;
  final String createdBy;
  final DateTime createdAt;

  const ReversalVoucher({
    required this.id,
    required this.businessId,
    required this.originalTxnId,
    this.reversalTxnId,
    required this.reason,
    this.notes,
    required this.reversalDate,
    required this.createdBy,
    required this.createdAt,
  });

  factory ReversalVoucher.fromMap(String id, Map<String, dynamic> map) {
    return ReversalVoucher(
      id: id,
      businessId: map['businessId'] ?? '',
      originalTxnId: map['originalTxnId'] ?? '',
      reversalTxnId: map['reversalTxnId'],
      reason: ReversalReason.values.firstWhere(
        (e) => e.name == map['reason'],
        orElse: () => ReversalReason.other,
      ),
      notes: map['notes'],
      reversalDate: _parseDate(map['reversalDate']) ?? DateTime.now(),
      createdBy: map['createdBy'] ?? '',
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
    );
  }

  factory ReversalVoucher.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ReversalVoucher.fromMap(doc.id, data);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'businessId': businessId,
      'originalTxnId': originalTxnId,
      'reversalTxnId': reversalTxnId,
      'reason': reason.name,
      'notes': notes,
      'reversalDate': reversalDate.toIso8601String(),
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'businessId': businessId,
      'originalTxnId': originalTxnId,
      'reversalTxnId': reversalTxnId,
      'reason': reason.name,
      'notes': notes,
      'reversalDate': Timestamp.fromDate(reversalDate),
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  @override
  String toString() =>
      'ReversalVoucher(id: $id, original: $originalTxnId, reason: ${reason.name})';
}

/// Reasons for reversing a transaction
enum ReversalReason {
  /// Bill was edited - reversal is automatic before applying changes
  edited,

  /// Bill was deleted/cancelled
  deleted,

  /// Return processed (sales return / purchase return)
  returned,

  /// Correction by accountant
  correction,

  /// Entry was duplicated and needs reversal
  duplicate,

  /// Other reason (specify in notes)
  other,
}

/// Extension for display names
extension ReversalReasonExtension on ReversalReason {
  String get displayName {
    switch (this) {
      case ReversalReason.edited:
        return 'Bill Edited';
      case ReversalReason.deleted:
        return 'Bill Deleted';
      case ReversalReason.returned:
        return 'Return Processed';
      case ReversalReason.correction:
        return 'Correction';
      case ReversalReason.duplicate:
        return 'Duplicate Entry';
      case ReversalReason.other:
        return 'Other';
    }
  }
}
