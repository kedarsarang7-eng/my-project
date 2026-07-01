/// StockTransaction - Append-only audit log for stock changes.
/// NEVER update. NEVER delete. Used for audit + analytics.
class StockTransaction {
  final String txnId;
  final String vendorId;
  final String itemId;
  final double deltaQty; // e.g., -2 for sale, +5 for restock
  final StockTransactionReason reason;
  final String? referenceId; // e.g., billId, adjustmentId
  final String? description;
  final DateTime createdAt;
  final String? createdBy; // userId who triggered this

  StockTransaction({
    required this.txnId,
    required this.vendorId,
    required this.itemId,
    required this.deltaQty,
    required this.reason,
    this.referenceId,
    this.description,
    required this.createdAt,
    this.createdBy,
  });

  factory StockTransaction.fromMap(String txnId, Map<String, dynamic> map) {
    return StockTransaction(
      txnId: txnId,
      vendorId: map['vendorId'] ?? '',
      itemId: map['itemId'] ?? '',
      deltaQty: (map['deltaQty'] ?? 0).toDouble(),
      reason: StockTransactionReason.fromString(map['reason'] ?? 'OTHER'),
      referenceId: map['referenceId'],
      description: map['description'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      createdBy: map['createdBy'],
    );
  }

  Map<String, dynamic> toMap() => {
    'vendorId': vendorId,
    'itemId': itemId,
    'deltaQty': deltaQty,
    'reason': reason.name,
    'referenceId': referenceId,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'createdBy': createdBy,
  };

  /// Create a SALE transaction (stock out)
  factory StockTransaction.sale({
    required String txnId,
    required String vendorId,
    required String itemId,
    required double qty,
    required String billId,
    String? createdBy,
  }) {
    return StockTransaction(
      txnId: txnId,
      vendorId: vendorId,
      itemId: itemId,
      deltaQty: -qty.abs(), // Always negative for sales
      reason: StockTransactionReason.bill,
      referenceId: billId,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );
  }

  /// Create a RESTOCK transaction (stock in)
  factory StockTransaction.restock({
    required String txnId,
    required String vendorId,
    required String itemId,
    required double qty,
    String? purchaseId,
    String? createdBy,
  }) {
    return StockTransaction(
      txnId: txnId,
      vendorId: vendorId,
      itemId: itemId,
      deltaQty: qty.abs(), // Always positive for restock
      reason: StockTransactionReason.restock,
      referenceId: purchaseId,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );
  }

  /// Create an ADJUSTMENT transaction (manual correction)
  factory StockTransaction.adjustment({
    required String txnId,
    required String vendorId,
    required String itemId,
    required double deltaQty,
    String? description,
    String? createdBy,
  }) {
    return StockTransaction(
      txnId: txnId,
      vendorId: vendorId,
      itemId: itemId,
      deltaQty: deltaQty,
      reason: StockTransactionReason.adjustment,
      description: description,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );
  }
}

/// Reason for stock change
enum StockTransactionReason {
  bill, // Sale (stock out)
  restock, // Purchase/restock (stock in)
  adjustment, // Manual correction
  returnIn, // Customer return (stock in)
  damage, // Damaged goods (stock out)
  other;

  static StockTransactionReason fromString(String value) {
    return StockTransactionReason.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => StockTransactionReason.other,
    );
  }
}
