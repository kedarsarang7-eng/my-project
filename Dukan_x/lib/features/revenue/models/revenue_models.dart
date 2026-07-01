// Revenue Features - Models
// Contains models for Receipt, Return Inwards, Proforma, Booking, and Dispatch
//
// Author: DukanX Team
// Created: 2024-12-25

/// Helper to parse date from dynamic map (handles both Timestamp and String/ISO)
DateTime _parseDate(dynamic date) {
  if (date == null) return DateTime.now();
  if (date is DateTime) return date;
  if (date.runtimeType.toString() == 'Timestamp') {
    return (date as dynamic).toDate();
  }
  if (date is String) return DateTime.parse(date);
  if (date is int) return DateTime.fromMillisecondsSinceEpoch(date);
  return DateTime.now();
}

/// Helper to format date for map (keeping it as DateTime for repository/local, but allowing flexibility)
dynamic _formatDate(DateTime date) {
  return date; // Repository will handle conversion to specific format if needed
}

/// Receipt Entry Model - Records customer payments against bills
class Receipt {
  final String id;
  final String ownerId;
  final String customerId;
  final String customerName;
  final String? billId; // Optional - can be advance payment
  final String? billNumber;
  final double amount;
  final double? billAmount; // Original bill amount if linked
  final String paymentMode; // Cash, UPI, Bank, Cheque
  final String? chequeNumber;
  final String? bankName;
  final String? upiTransactionId;
  final String notes;
  final DateTime date;
  final DateTime createdAt;
  final bool isAdvancePayment;

  Receipt({
    required this.id,
    required this.ownerId,
    required this.customerId,
    required this.customerName,
    this.billId,
    this.billNumber,
    required this.amount,
    this.billAmount,
    required this.paymentMode,
    this.chequeNumber,
    this.bankName,
    this.upiTransactionId,
    this.notes = '',
    required this.date,
    required this.createdAt,
    this.isAdvancePayment = false,
  });

  factory Receipt.fromMap(Map<String, dynamic> map, String id) {
    return Receipt(
      id: id,
      ownerId: map['ownerId'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      billId: map['billId'],
      billNumber: map['billNumber'],
      amount: (map['amount'] ?? 0).toDouble(),
      billAmount: map['billAmount']?.toDouble(),
      paymentMode: map['paymentMode'] ?? 'Cash',
      chequeNumber: map['chequeNumber'],
      bankName: map['bankName'],
      upiTransactionId: map['upiTransactionId'],
      notes: map['notes'] ?? '',
      date: _parseDate(map['date']),
      createdAt: _parseDate(map['createdAt']),
      isAdvancePayment: map['isAdvancePayment'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'customerId': customerId,
      'customerName': customerName,
      'billId': billId,
      'billNumber': billNumber,
      'amount': amount,
      'billAmount': billAmount,
      'paymentMode': paymentMode,
      'chequeNumber': chequeNumber,
      'bankName': bankName,
      'upiTransactionId': upiTransactionId,
      'notes': notes,
      'date': _formatDate(date),
      'createdAt': _formatDate(createdAt),
      'isAdvancePayment': isAdvancePayment,
    };
  }
}

/// Return Inwards Model - Records goods returned by customers
class ReturnInward {
  final String id;
  final String ownerId;
  final String customerId;
  final String customerName;
  final String billId;
  final String billNumber;
  final List<ReturnItem> items;
  final double totalReturnAmount;
  final String reason;
  final String creditNoteNumber;
  final ReturnStatus status;
  final DateTime date;
  final DateTime createdAt;

  ReturnInward({
    required this.id,
    required this.ownerId,
    required this.customerId,
    required this.customerName,
    required this.billId,
    required this.billNumber,
    required this.items,
    required this.totalReturnAmount,
    required this.reason,
    required this.creditNoteNumber,
    required this.status,
    required this.date,
    required this.createdAt,
  });

  factory ReturnInward.fromMap(Map<String, dynamic> map, String id) {
    return ReturnInward(
      id: id,
      ownerId: map['ownerId'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      billId: map['billId'] ?? '',
      billNumber: map['billNumber'] ?? '',
      items:
          (map['items'] as List<dynamic>?)
              ?.map((e) => ReturnItem.fromMap(e))
              .toList() ??
          [],
      totalReturnAmount: (map['totalReturnAmount'] ?? 0).toDouble(),
      reason: map['reason'] ?? '',
      creditNoteNumber: map['creditNoteNumber'] ?? '',
      status: ReturnStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ReturnStatus.pending,
      ),
      date: _parseDate(map['date']),
      createdAt: _parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'customerId': customerId,
      'customerName': customerName,
      'billId': billId,
      'billNumber': billNumber,
      'items': items.map((e) => e.toMap()).toList(),
      'totalReturnAmount': totalReturnAmount,
      'reason': reason,
      'creditNoteNumber': creditNoteNumber,
      'status': status.name,
      'date': _formatDate(date),
      'createdAt': _formatDate(createdAt),
    };
  }
}

class ReturnItem {
  final String itemId;
  final String itemName;
  final double quantity;
  final double rate;
  final double amount;

  ReturnItem({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.rate,
    required this.amount,
  });

  factory ReturnItem.fromMap(Map<String, dynamic> map) {
    return ReturnItem(
      itemId: map['itemId'] ?? '',
      itemName: map['itemName'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      rate: (map['rate'] ?? 0).toDouble(),
      amount: (map['amount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'quantity': quantity,
      'rate': rate,
      'amount': amount,
    };
  }
}

enum ReturnStatus { pending, approved, rejected, processed }

/// Proforma Invoice Model - Estimates/Quotations
class ProformaInvoice {
  final String id;
  final String ownerId;
  final String customerId;
  final String customerName;
  final String proformaNumber;
  final List<ProformaItem> items;
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double totalAmount;
  final DateTime validUntil;
  final ProformaStatus status;
  final String? convertedBillId;
  final String terms;
  final String notes;
  final DateTime date;
  final DateTime createdAt;

  ProformaInvoice({
    required this.id,
    required this.ownerId,
    required this.customerId,
    required this.customerName,
    required this.proformaNumber,
    required this.items,
    required this.subtotal,
    required this.taxAmount,
    required this.discountAmount,
    required this.totalAmount,
    required this.validUntil,
    required this.status,
    this.convertedBillId,
    this.terms = '',
    this.notes = '',
    required this.date,
    required this.createdAt,
  });

  factory ProformaInvoice.fromMap(Map<String, dynamic> map, String id) {
    return ProformaInvoice(
      id: id,
      ownerId: map['ownerId'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      proformaNumber: map['proformaNumber'] ?? '',
      items:
          (map['items'] as List<dynamic>?)
              ?.map((e) => ProformaItem.fromMap(e))
              .toList() ??
          [],
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      taxAmount: (map['taxAmount'] ?? 0).toDouble(),
      discountAmount: (map['discountAmount'] ?? 0).toDouble(),
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      validUntil: _parseDate(map['validUntil']),
      status: ProformaStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ProformaStatus.draft,
      ),
      convertedBillId: map['convertedBillId'],
      terms: map['terms'] ?? '',
      notes: map['notes'] ?? '',
      date: _parseDate(map['date']),
      createdAt: _parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'customerId': customerId,
      'customerName': customerName,
      'proformaNumber': proformaNumber,
      'items': items.map((e) => e.toMap()).toList(),
      'subtotal': subtotal,
      'taxAmount': taxAmount,
      'discountAmount': discountAmount,
      'totalAmount': totalAmount,
      'validUntil': _formatDate(validUntil),
      'status': status.name,
      'convertedBillId': convertedBillId,
      'terms': terms,
      'notes': notes,
      'date': _formatDate(date),
      'createdAt': _formatDate(createdAt),
    };
  }
}

class ProformaItem {
  final String itemId;
  final String itemName;
  final double quantity;
  final String unit;
  final double rate;
  final double discount;
  final double taxPercent;
  final double amount;

  ProformaItem({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    this.unit = 'pcs',
    required this.rate,
    this.discount = 0,
    this.taxPercent = 0,
    required this.amount,
  });

  factory ProformaItem.fromMap(Map<String, dynamic> map) {
    return ProformaItem(
      itemId: map['itemId'] ?? '',
      itemName: map['itemName'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      unit: map['unit'] ?? 'pcs',
      rate: (map['rate'] ?? 0).toDouble(),
      discount: (map['discount'] ?? 0).toDouble(),
      taxPercent: (map['taxPercent'] ?? 0).toDouble(),
      amount: (map['amount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'quantity': quantity,
      'unit': unit,
      'rate': rate,
      'discount': discount,
      'taxPercent': taxPercent,
      'amount': amount,
    };
  }
}

enum ProformaStatus { draft, sent, accepted, rejected, converted, expired }

/// Booking Order Model - Advance bookings with delivery tracking
class BookingOrder {
  final String id;
  final String ownerId;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String bookingNumber;
  final List<BookingItem> items;
  final double totalAmount;
  final double advanceAmount;
  final double balanceAmount;
  final DateTime deliveryDate;
  final String deliveryAddress;
  final BookingStatus status;
  final String? convertedBillId;
  final String notes;
  final DateTime date;
  final DateTime createdAt;

  BookingOrder({
    required this.id,
    required this.ownerId,
    required this.customerId,
    required this.customerName,
    this.customerPhone = '',
    required this.bookingNumber,
    required this.items,
    required this.totalAmount,
    required this.advanceAmount,
    required this.balanceAmount,
    required this.deliveryDate,
    this.deliveryAddress = '',
    required this.status,
    this.convertedBillId,
    this.notes = '',
    required this.date,
    required this.createdAt,
  });

  factory BookingOrder.fromMap(Map<String, dynamic> map, String id) {
    return BookingOrder(
      id: id,
      ownerId: map['ownerId'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      bookingNumber: map['bookingNumber'] ?? '',
      items:
          (map['items'] as List<dynamic>?)
              ?.map((e) => BookingItem.fromMap(e))
              .toList() ??
          [],
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      advanceAmount: (map['advanceAmount'] ?? 0).toDouble(),
      balanceAmount: (map['balanceAmount'] ?? 0).toDouble(),
      deliveryDate: _parseDate(map['deliveryDate']),
      deliveryAddress: map['deliveryAddress'] ?? '',
      status: BookingStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => BookingStatus.pending,
      ),
      convertedBillId: map['convertedBillId'],
      notes: map['notes'] ?? '',
      date: _parseDate(map['date']),
      createdAt: _parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'bookingNumber': bookingNumber,
      'items': items.map((e) => e.toMap()).toList(),
      'totalAmount': totalAmount,
      'advanceAmount': advanceAmount,
      'balanceAmount': balanceAmount,
      'deliveryDate': _formatDate(deliveryDate),
      'deliveryAddress': deliveryAddress,
      'status': status.name,
      'convertedBillId': convertedBillId,
      'notes': notes,
      'date': _formatDate(date),
      'createdAt': _formatDate(createdAt),
    };
  }
}

class BookingItem {
  final String itemId;
  final String itemName;
  final double quantity;
  final String unit;
  final double rate;
  final double amount;

  BookingItem({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    this.unit = 'pcs',
    required this.rate,
    required this.amount,
  });

  factory BookingItem.fromMap(Map<String, dynamic> map) {
    return BookingItem(
      itemId: map['itemId'] ?? '',
      itemName: map['itemName'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      unit: map['unit'] ?? 'pcs',
      rate: (map['rate'] ?? 0).toDouble(),
      amount: (map['amount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'quantity': quantity,
      'unit': unit,
      'rate': rate,
      'amount': amount,
    };
  }
}

enum BookingStatus {
  pending,
  confirmed,
  ready,
  delivered,
  cancelled,
  converted,
}

/// Dispatch Note Model - Delivery tracking for goods
class DispatchNote {
  final String id;
  final String ownerId;
  final String billId;
  final String billNumber;
  final String customerId;
  final String customerName;
  final String dispatchNumber;
  final List<DispatchItem> items;
  final String vehicleNumber;
  final String driverName;
  final String driverPhone;
  final String deliveryAddress;
  final DispatchStatus status;
  final DateTime? deliveredAt;
  final String? receiverName;
  final String? receiverSignature; // Base64 or URL
  final String notes;
  final DateTime date;
  final DateTime createdAt;

  DispatchNote({
    required this.id,
    required this.ownerId,
    required this.billId,
    required this.billNumber,
    required this.customerId,
    required this.customerName,
    required this.dispatchNumber,
    required this.items,
    this.vehicleNumber = '',
    this.driverName = '',
    this.driverPhone = '',
    required this.deliveryAddress,
    required this.status,
    this.deliveredAt,
    this.receiverName,
    this.receiverSignature,
    this.notes = '',
    required this.date,
    required this.createdAt,
  });

  factory DispatchNote.fromMap(Map<String, dynamic> map, String id) {
    return DispatchNote(
      id: id,
      ownerId: map['ownerId'] ?? '',
      billId: map['billId'] ?? '',
      billNumber: map['billNumber'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      dispatchNumber: map['dispatchNumber'] ?? '',
      items:
          (map['items'] as List<dynamic>?)
              ?.map((e) => DispatchItem.fromMap(e))
              .toList() ??
          [],
      vehicleNumber: map['vehicleNumber'] ?? '',
      driverName: map['driverName'] ?? '',
      driverPhone: map['driverPhone'] ?? '',
      deliveryAddress: map['deliveryAddress'] ?? '',
      status: DispatchStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => DispatchStatus.pending,
      ),
      deliveredAt: map['deliveredAt'] != null
          ? _parseDate(map['deliveredAt'])
          : null,
      receiverName: map['receiverName'],
      receiverSignature: map['receiverSignature'],
      notes: map['notes'] ?? '',
      date: _parseDate(map['date']),
      createdAt: _parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'billId': billId,
      'billNumber': billNumber,
      'customerId': customerId,
      'customerName': customerName,
      'dispatchNumber': dispatchNumber,
      'items': items.map((e) => e.toMap()).toList(),
      'vehicleNumber': vehicleNumber,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'deliveryAddress': deliveryAddress,
      'status': status.name,
      'deliveredAt': deliveredAt != null ? _formatDate(deliveredAt!) : null,
      'receiverName': receiverName,
      'receiverSignature': receiverSignature,
      'notes': notes,
      'date': _formatDate(date),
      'createdAt': _formatDate(createdAt),
    };
  }
}

class DispatchItem {
  final String itemId;
  final String itemName;
  final double quantity;
  final String unit;

  DispatchItem({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    this.unit = 'pcs',
  });

  factory DispatchItem.fromMap(Map<String, dynamic> map) {
    return DispatchItem(
      itemId: map['itemId'] ?? '',
      itemName: map['itemName'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      unit: map['unit'] ?? 'pcs',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'quantity': quantity,
      'unit': unit,
    };
  }
}

enum DispatchStatus { pending, inTransit, delivered, returned }
