import '../utils/number_utils.dart';

class PurchaseBillItem {
  String itemId; // Stock Item ID
  String itemName;
  double qty;
  double rate; // Purchase Rate
  double total;
  String unit;
  double gstRate; // %
  double discount; // Amount
  double cgst;
  double sgst;
  double igst;

  PurchaseBillItem({
    required this.itemId,
    required this.itemName,
    required this.qty,
    required this.rate,
    required this.total,
    this.unit = 'kg',
    this.gstRate = 0.0,
    this.discount = 0.0,
    this.cgst = 0.0,
    this.sgst = 0.0,
    this.igst = 0.0,
  });

  Map<String, dynamic> toMap() => {
    'itemId': itemId,
    'itemName': itemName,
    'qty': qty,
    'rate': rate,
    'total': total,
    'unit': unit,
    'gstRate': gstRate,
    'discount': discount,
    'cgst': cgst,
    'sgst': sgst,
    'igst': igst,
  };

  factory PurchaseBillItem.fromMap(Map<String, dynamic> m) {
    return PurchaseBillItem(
      itemId: m['itemId']?.toString() ?? '',
      itemName: m['itemName']?.toString() ?? '',
      qty: parseDouble(m['qty']),
      rate: parseDouble(m['rate']),
      total: parseDouble(m['total']),
      unit: m['unit']?.toString() ?? 'kg',
      gstRate: parseDouble(m['gstRate']),
      discount: parseDouble(m['discount']),
      cgst: parseDouble(m['cgst']),
      sgst: parseDouble(m['sgst']),
      igst: parseDouble(m['igst']),
    );
  }
}

class PurchaseBill {
  String id;
  String billNumber; // Supplier's Bill Number
  String supplierId;
  String supplierName;
  String supplierPhone;
  DateTime date;
  DateTime? dueDate;
  List<PurchaseBillItem> items;
  double subtotal;
  double totalTax;
  double grandTotal;
  double paidAmount;
  String status; // Paid, Unpaid, Partial
  String paymentMode; // Cash, UPI, Bank, Credit
  String notes;
  String? attachmentUrl;
  String ownerId;

  PurchaseBill({
    required this.id,
    required this.billNumber,
    required this.supplierId,
    required this.supplierName,
    this.supplierPhone = '',
    required this.date,
    this.dueDate,
    required this.items,
    this.subtotal = 0.0,
    this.totalTax = 0.0,
    this.grandTotal = 0.0,
    this.paidAmount = 0.0,
    this.status = 'Unpaid',
    this.paymentMode = 'Credit',
    this.notes = '',
    this.attachmentUrl,
    required this.ownerId,
  });

  double get pendingAmount =>
      (grandTotal - paidAmount).clamp(0, double.infinity);

  Map<String, dynamic> toMap() => {
    'billNumber': billNumber,
    'supplierId': supplierId,
    'supplierName': supplierName,
    'supplierPhone': supplierPhone,
    'date': date.toIso8601String(),
    'dueDate': dueDate?.toIso8601String(),
    'items': items.map((e) => e.toMap()).toList(),
    'subtotal': subtotal,
    'totalTax': totalTax,
    'grandTotal': grandTotal,
    'paidAmount': paidAmount,
    'status': status,
    'paymentMode': paymentMode,
    'notes': notes,
    'attachmentUrl': attachmentUrl,
    'ownerId': ownerId,
  };

  factory PurchaseBill.fromMap(String id, Map<String, dynamic> m) {
    return PurchaseBill(
      id: id,
      billNumber: m['billNumber']?.toString() ?? '',
      supplierId: m['supplierId']?.toString() ?? '',
      supplierName: m['supplierName']?.toString() ?? '',
      supplierPhone: m['supplierPhone']?.toString() ?? '',
      date: DateTime.tryParse(m['date']?.toString() ?? '') ?? DateTime.now(),
      dueDate: m['dueDate'] != null
          ? DateTime.tryParse(m['dueDate'].toString())
          : null,
      items:
          (m['items'] as List?)
              ?.map((e) => PurchaseBillItem.fromMap(e))
              .toList() ??
          [],
      subtotal: parseDouble(m['subtotal']),
      totalTax: parseDouble(m['totalTax']),
      grandTotal: parseDouble(m['grandTotal']),
      paidAmount: parseDouble(m['paidAmount']),
      status: m['status']?.toString() ?? 'Unpaid',
      paymentMode: m['paymentMode']?.toString() ?? 'Credit',
      notes: m['notes']?.toString() ?? '',
      attachmentUrl: m['attachmentUrl']?.toString(),
      ownerId: m['ownerId']?.toString() ?? '',
    );
  }

  PurchaseBill copyWith({
    String? id,
    String? billNumber,
    String? supplierId,
    String? supplierName,
    String? supplierPhone,
    DateTime? date,
    DateTime? dueDate,
    List<PurchaseBillItem>? items,
    double? subtotal,
    double? totalTax,
    double? grandTotal,
    double? paidAmount,
    String? status,
    String? paymentMode,
    String? notes,
    String? attachmentUrl,
    String? ownerId,
  }) {
    return PurchaseBill(
      id: id ?? this.id,
      billNumber: billNumber ?? this.billNumber,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      supplierPhone: supplierPhone ?? this.supplierPhone,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      totalTax: totalTax ?? this.totalTax,
      grandTotal: grandTotal ?? this.grandTotal,
      paidAmount: paidAmount ?? this.paidAmount,
      status: status ?? this.status,
      paymentMode: paymentMode ?? this.paymentMode,
      notes: notes ?? this.notes,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      ownerId: ownerId ?? this.ownerId,
    );
  }
}
