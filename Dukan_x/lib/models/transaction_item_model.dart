class TransactionItem {
  final String txnItemId;
  final String txnId;
  final String itemId; // Link to Item Master
  final String itemName;
  final double qty;
  final double rate;
  final double costPrice; // Crucial for Profit Calc (FIFO/Avg)
  final double gstAmount;
  final double gstRate; // %
  final double netAmount; // (Qty * Rate) + Tax

  TransactionItem({
    required this.txnItemId,
    required this.txnId,
    required this.itemId,
    required this.itemName,
    required this.qty,
    required this.rate,
    required this.costPrice,
    required this.gstAmount,
    required this.gstRate,
    required this.netAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'txnItemId': txnItemId,
      'txnId': txnId,
      'itemId': itemId,
      'itemName': itemName,
      'qty': qty,
      'rate': rate,
      'costPrice': costPrice,
      'gstAmount': gstAmount,
      'gstRate': gstRate,
      'netAmount': netAmount,
    };
  }

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    return TransactionItem(
      txnItemId: map['txnItemId'] ?? '',
      txnId: map['txnId'] ?? '',
      itemId: map['itemId'] ?? '',
      itemName: map['itemName'] ?? '',
      qty: (map['qty'] ?? 0).toDouble(),
      rate: (map['rate'] ?? 0).toDouble(),
      costPrice: (map['costPrice'] ?? 0).toDouble(),
      gstAmount: (map['gstAmount'] ?? 0).toDouble(),
      gstRate: (map['gstRate'] ?? 0).toDouble(),
      netAmount: (map['netAmount'] ?? 0).toDouble(),
    );
  }

  TransactionItem copyWith({
    String? txnItemId,
    String? txnId,
    String? itemId,
    String? itemName,
    double? qty,
    double? rate,
    double? costPrice,
    double? gstAmount,
    double? gstRate,
    double? netAmount,
  }) {
    return TransactionItem(
      txnItemId: txnItemId ?? this.txnItemId,
      txnId: txnId ?? this.txnId,
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      qty: qty ?? this.qty,
      rate: rate ?? this.rate,
      costPrice: costPrice ?? this.costPrice,
      gstAmount: gstAmount ?? this.gstAmount,
      gstRate: gstRate ?? this.gstRate,
      netAmount: netAmount ?? this.netAmount,
    );
  }
}
