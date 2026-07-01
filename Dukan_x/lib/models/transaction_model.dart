import 'package:dukanx/core/compat/firestore_compat.dart';

/// Transaction types supported by the accounting engine.
///
/// Non-accounting types (saleOrder, estimate, deliveryChallan) do not
/// generate ledger entries but may still affect inventory.
enum TransactionType {
  sale,
  purchase,
  saleReturn,
  purchaseReturn,
  paymentIn,
  paymentOut,
  expense,
  journal,
  saleOrder, // Non-accounting
  estimate, // Non-accounting
  deliveryChallan, // Stock only, no ledger
  reversal, // Reversal entry type
}

enum PaymentStatus { paid, partial, unpaid, cancelled }

/// TransactionModel - Core accounting transaction record.
///
/// Every financial event (sale, purchase, payment, etc.) creates a
/// TransactionModel which then generates ledger entries via AccountingEngine.
///
/// ## Immutability & Reversals
/// Transactions are immutable once created. To modify:
/// 1. Call AccountingEngine.reverseTransaction() to create reversing entries
/// 2. Create a new transaction with the updated values
///
/// ## Idempotency
/// The `idempotencyKey` prevents duplicate submissions. The client generates
/// a unique key before submission, and the server rejects duplicates.
class TransactionModel {
  final String txnId;
  final String businessId;
  final DateTime date;
  final TransactionType type;
  final String refNo; // Invoice No
  final String? partyId; // Customer/Supplier ID
  final String? partyName; // Snapshot (for UI speed)
  final double subTotal;
  final double taxAmount;
  final double totalAmount;
  final double balanceAmount;
  final PaymentStatus paymentStatus;
  final DateTime? dueDate;
  final DateTime createdAt;
  final String? notes;

  // === NEW: Idempotency & Versioning ===

  /// Client-generated unique key to prevent duplicate submissions.
  /// Format: "{clientId}_{timestamp}_{random}"
  final String? idempotencyKey;

  /// Optimistic lock version. Incremented on every edit.
  final int version;

  // === NEW: Reversal Tracking ===

  /// True if this transaction has been reversed.
  final bool isReversed;

  /// Reference to the reversal transaction that cancelled this one.
  final String? reversedByTxnId;

  /// Date when this transaction was reversed.
  final DateTime? reversalDate;

  /// If this IS a reversal, reference to the original transaction.
  final String? reversesOriginalTxnId;

  // === NEW: Server Timestamps ===

  /// Server timestamp of creation.
  final DateTime? serverCreatedAt;

  /// Server timestamp of last modification.
  final DateTime? serverUpdatedAt;

  /// User who created this transaction.
  final String? createdBy;

  TransactionModel({
    required this.txnId,
    required this.businessId,
    required this.date,
    required this.type,
    this.refNo = '',
    this.partyId,
    this.partyName,
    required this.subTotal,
    required this.taxAmount,
    required this.totalAmount,
    this.balanceAmount = 0,
    this.paymentStatus = PaymentStatus.unpaid,
    this.dueDate,
    required this.createdAt,
    this.notes,
    // New fields
    this.idempotencyKey,
    this.version = 1,
    this.isReversed = false,
    this.reversedByTxnId,
    this.reversalDate,
    this.reversesOriginalTxnId,
    this.serverCreatedAt,
    this.serverUpdatedAt,
    this.createdBy,
  });

  /// True if this transaction generates ledger entries.
  bool get isAccounting =>
      type != TransactionType.saleOrder &&
      type != TransactionType.estimate &&
      type != TransactionType.deliveryChallan;

  /// True if this transaction affects stock.
  bool get affectsStock =>
      type == TransactionType.sale ||
      type == TransactionType.purchase ||
      type == TransactionType.saleReturn ||
      type == TransactionType.purchaseReturn ||
      type == TransactionType.deliveryChallan ||
      type == TransactionType.reversal;

  Map<String, dynamic> toMap() {
    return {
      'txnId': txnId,
      'businessId': businessId,
      'date': date.toIso8601String(),
      'type': type.name,
      'refNo': refNo,
      'partyId': partyId,
      'partyName': partyName,
      'subTotal': subTotal,
      'taxAmount': taxAmount,
      'totalAmount': totalAmount,
      'balanceAmount': balanceAmount,
      'paymentStatus': paymentStatus.name,
      'dueDate': dueDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'notes': notes,
      'idempotencyKey': idempotencyKey,
      'version': version,
      'isReversed': isReversed,
      'reversedByTxnId': reversedByTxnId,
      'reversalDate': reversalDate?.toIso8601String(),
      'reversesOriginalTxnId': reversesOriginalTxnId,
      'serverCreatedAt': serverCreatedAt?.toIso8601String(),
      'serverUpdatedAt': serverUpdatedAt?.toIso8601String(),
      'createdBy': createdBy,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'txnId': txnId,
      'businessId': businessId,
      'date': Timestamp.fromDate(date),
      'type': type.name,
      'refNo': refNo,
      'partyId': partyId,
      'partyName': partyName,
      'subTotal': subTotal,
      'taxAmount': taxAmount,
      'totalAmount': totalAmount,
      'balanceAmount': balanceAmount,
      'paymentStatus': paymentStatus.name,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'notes': notes,
      'idempotencyKey': idempotencyKey,
      'version': version,
      'isReversed': isReversed,
      'reversedByTxnId': reversedByTxnId,
      'reversalDate': reversalDate != null
          ? Timestamp.fromDate(reversalDate!)
          : null,
      'reversesOriginalTxnId': reversesOriginalTxnId,
      'serverCreatedAt': serverCreatedAt != null
          ? Timestamp.fromDate(serverCreatedAt!)
          : FieldValue.serverTimestamp(),
      'serverUpdatedAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      txnId: map['txnId'] ?? '',
      businessId: map['businessId'] ?? '',
      date: _parseDate(map['date']) ?? DateTime.now(),
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.sale,
      ),
      refNo: map['refNo'] ?? '',
      partyId: map['partyId'],
      partyName: map['partyName'],
      subTotal: (map['subTotal'] ?? 0).toDouble(),
      taxAmount: (map['taxAmount'] ?? 0).toDouble(),
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      balanceAmount: (map['balanceAmount'] ?? 0).toDouble(),
      paymentStatus: PaymentStatus.values.firstWhere(
        (e) => e.name == map['paymentStatus'],
        orElse: () => PaymentStatus.unpaid,
      ),
      dueDate: _parseDate(map['dueDate']),
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      notes: map['notes'],
      idempotencyKey: map['idempotencyKey'],
      version: map['version'] ?? 1,
      isReversed: map['isReversed'] ?? false,
      reversedByTxnId: map['reversedByTxnId'],
      reversalDate: _parseDate(map['reversalDate']),
      reversesOriginalTxnId: map['reversesOriginalTxnId'],
      serverCreatedAt: _parseDate(map['serverCreatedAt']),
      serverUpdatedAt: _parseDate(map['serverUpdatedAt']),
      createdBy: map['createdBy'],
    );
  }

  TransactionModel copyWith({
    String? txnId,
    String? businessId,
    DateTime? date,
    TransactionType? type,
    String? refNo,
    String? partyId,
    String? partyName,
    double? subTotal,
    double? taxAmount,
    double? totalAmount,
    double? balanceAmount,
    PaymentStatus? paymentStatus,
    DateTime? dueDate,
    DateTime? createdAt,
    String? notes,
    String? idempotencyKey,
    int? version,
    bool? isReversed,
    String? reversedByTxnId,
    DateTime? reversalDate,
    String? reversesOriginalTxnId,
    DateTime? serverCreatedAt,
    DateTime? serverUpdatedAt,
    String? createdBy,
  }) {
    return TransactionModel(
      txnId: txnId ?? this.txnId,
      businessId: businessId ?? this.businessId,
      date: date ?? this.date,
      type: type ?? this.type,
      refNo: refNo ?? this.refNo,
      partyId: partyId ?? this.partyId,
      partyName: partyName ?? this.partyName,
      subTotal: subTotal ?? this.subTotal,
      taxAmount: taxAmount ?? this.taxAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      balanceAmount: balanceAmount ?? this.balanceAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      version: version ?? this.version,
      isReversed: isReversed ?? this.isReversed,
      reversedByTxnId: reversedByTxnId ?? this.reversedByTxnId,
      reversalDate: reversalDate ?? this.reversalDate,
      reversesOriginalTxnId:
          reversesOriginalTxnId ?? this.reversesOriginalTxnId,
      serverCreatedAt: serverCreatedAt ?? this.serverCreatedAt,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
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
      'TransactionModel(id: $txnId, type: ${type.name}, amount: $totalAmount)';
}
