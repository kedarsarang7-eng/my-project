// Removed cloud_firestore import

enum PaymentStatus { paid, partial, unpaid }

class StockEntry {
  final String entryId;
  final String ownerId;
  final String vendorId;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final double totalAmount;
  final double taxAmount;
  final double discountAmount;
  final double paidAmount;
  final double dueAmount;
  final PaymentStatus paymentStatus;
  final String billImageUrl;
  final DateTime createdAt;
  final bool isDeleted;

  // Local only helper
  final List<StockEntryItem>? items;

  StockEntry({
    required this.entryId,
    required this.ownerId,
    required this.vendorId,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.totalAmount,
    this.taxAmount = 0.0,
    this.discountAmount = 0.0,
    this.paidAmount = 0.0,
    this.dueAmount = 0.0,
    this.paymentStatus = PaymentStatus.unpaid,
    this.billImageUrl = '',
    required this.createdAt,
    this.isDeleted = false,
    this.items,
  });

  Map<String, dynamic> toMap() {
    return {
      'entryId': entryId,
      'ownerId': ownerId,
      'vendorId': vendorId,
      'invoiceNumber': invoiceNumber,
      'invoiceDate': invoiceDate.toIso8601String(),
      'totalAmount': totalAmount,
      'taxAmount': taxAmount,
      'discountAmount': discountAmount,
      'paidAmount': paidAmount,
      'dueAmount': dueAmount,
      'paymentStatus': paymentStatus.name,
      'billImageUrl': billImageUrl,
      'createdAt': createdAt.toIso8601String(),
      'isDeleted': isDeleted,
    };
  }

  factory StockEntry.fromMap(Map<String, dynamic> map) {
    return StockEntry(
      entryId: map['entryId'] ?? '',
      ownerId: map['ownerId'] ?? '',
      vendorId: map['vendorId'] ?? '',
      invoiceNumber: map['invoiceNumber'] ?? '',
      invoiceDate: DateTime.parse(map['invoiceDate']),
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      taxAmount: (map['taxAmount'] ?? 0).toDouble(),
      discountAmount: (map['discountAmount'] ?? 0).toDouble(),
      paidAmount: (map['paidAmount'] ?? 0).toDouble(),
      dueAmount: (map['dueAmount'] ?? 0).toDouble(),
      paymentStatus: PaymentStatus.values.firstWhere(
        (e) => e.name == (map['paymentStatus'] ?? 'unpaid'),
        orElse: () => PaymentStatus.unpaid,
      ),
      billImageUrl: map['billImageUrl'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
      isDeleted: map['isDeleted'] ?? false,
    );
  }
}

class StockEntryItem {
  final String lineId;
  final String entryId;
  final String itemId;
  final String name;
  final double quantity;
  final double rate;
  final double taxPercent;
  final double total;

  StockEntryItem({
    required this.lineId,
    required this.entryId,
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.rate,
    this.taxPercent = 0.0,
    required this.total,
  });

  Map<String, dynamic> toMap() {
    return {
      'lineId': lineId,
      'entryId': entryId,
      'itemId': itemId,
      'name': name,
      'quantity': quantity,
      'rate': rate,
      'taxPercent': taxPercent,
      'total': total,
    };
  }

  factory StockEntryItem.fromMap(Map<String, dynamic> map) {
    return StockEntryItem(
      lineId: map['lineId'] ?? '',
      entryId: map['entryId'] ?? '',
      itemId: map['itemId'] ?? '',
      name: map['name'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      rate: (map['rate'] ?? 0).toDouble(),
      taxPercent: (map['taxPercent'] ?? 0).toDouble(),
      total: (map['total'] ?? 0).toDouble(),
    );
  }
}
