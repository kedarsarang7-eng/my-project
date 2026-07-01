/// Exchange Model
/// Represents a device exchange/trade-in transaction
library;

/// Exchange status lifecycle
enum ExchangeStatus {
  draft, // Exchange being created
  completed, // Exchange completed with new device sold
  cancelled, // Exchange cancelled
}

extension ExchangeStatusExtension on ExchangeStatus {
  String get value {
    switch (this) {
      case ExchangeStatus.draft:
        return 'DRAFT';
      case ExchangeStatus.completed:
        return 'COMPLETED';
      case ExchangeStatus.cancelled:
        return 'CANCELLED';
    }
  }

  String get displayName {
    switch (this) {
      case ExchangeStatus.draft:
        return 'Draft';
      case ExchangeStatus.completed:
        return 'Completed';
      case ExchangeStatus.cancelled:
        return 'Cancelled';
    }
  }

  static ExchangeStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'DRAFT':
        return ExchangeStatus.draft;
      case 'COMPLETED':
        return ExchangeStatus.completed;
      case 'CANCELLED':
        return ExchangeStatus.cancelled;
      default:
        return ExchangeStatus.draft;
    }
  }
}

/// Payment status for exchange
enum ExchangePaymentStatus { pending, paid, partial }

extension ExchangePaymentStatusExtension on ExchangePaymentStatus {
  String get value {
    switch (this) {
      case ExchangePaymentStatus.pending:
        return 'PENDING';
      case ExchangePaymentStatus.paid:
        return 'PAID';
      case ExchangePaymentStatus.partial:
        return 'PARTIAL';
    }
  }

  static ExchangePaymentStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'PENDING':
        return ExchangePaymentStatus.pending;
      case 'PAID':
        return ExchangePaymentStatus.paid;
      case 'PARTIAL':
        return ExchangePaymentStatus.partial;
      default:
        return ExchangePaymentStatus.pending;
    }
  }
}

/// Exchange model for device trade-in transactions
class Exchange {
  final String id;
  final String userId;
  final String? exchangeNumber;

  // Customer info
  final String? customerId;
  final String customerName;
  final String customerPhone;

  // Old device (being traded in)
  final String oldDeviceName;
  final String? oldDeviceBrand;
  final String? oldDeviceModel;
  final String? oldImeiSerial;
  final String? oldDeviceCondition;
  final String? oldDeviceNotes;
  final double estimatedValue; // Initial estimate
  final double finalExchangeValue; // Final agreed value

  // New device (being purchased)
  final String? newProductId;
  final String? newImeiSerialId;
  final String newProductName;
  final String? newImeiSerial;
  final double newDevicePrice;

  // Calculation
  final double exchangeValue; // Old device value credited
  final double priceDifference; // newPrice - exchangeValue
  final double additionalDiscount;
  final double amountToPay; // Final amount customer pays

  // Payment
  final ExchangePaymentStatus paymentStatus;
  final double amountPaid;
  final String? paymentMode;
  final String? billId;

  // Status
  final ExchangeStatus status;

  // Timestamps
  final DateTime exchangeDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Sync
  final bool isSynced;

  Exchange({
    required this.id,
    required this.userId,
    this.exchangeNumber,
    this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.oldDeviceName,
    this.oldDeviceBrand,
    this.oldDeviceModel,
    this.oldImeiSerial,
    this.oldDeviceCondition,
    this.oldDeviceNotes,
    this.estimatedValue = 0,
    this.finalExchangeValue = 0,
    this.newProductId,
    this.newImeiSerialId,
    required this.newProductName,
    this.newImeiSerial,
    required this.newDevicePrice,
    required this.exchangeValue,
    required this.priceDifference,
    this.additionalDiscount = 0,
    required this.amountToPay,
    this.paymentStatus = ExchangePaymentStatus.pending,
    this.amountPaid = 0,
    this.paymentMode,
    this.billId,
    this.status = ExchangeStatus.draft,
    required this.exchangeDate,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
  });

  /// Balance amount customer still owes
  double get balanceAmount => amountToPay - amountPaid;

  /// Whether full payment received
  bool get isFullyPaid => amountPaid >= amountToPay;

  /// Whether exchange is still in draft
  bool get isDraft => status == ExchangeStatus.draft;

  /// Whether exchange is completed
  bool get isCompleted => status == ExchangeStatus.completed;

  /// Calculate exchange values (static helper)
  static Map<String, double> calculateExchange({
    required double newDevicePrice,
    required double oldDeviceValue,
    double additionalDiscount = 0,
  }) {
    final priceDiff = newDevicePrice - oldDeviceValue;
    final amountToPay = (priceDiff - additionalDiscount).clamp(
      0.0,
      double.infinity,
    );
    return {
      'exchangeValue': oldDeviceValue,
      'priceDifference': priceDiff,
      'amountToPay': amountToPay,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'exchangeNumber': exchangeNumber,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'oldDeviceName': oldDeviceName,
      'oldDeviceBrand': oldDeviceBrand,
      'oldDeviceModel': oldDeviceModel,
      'oldImeiSerial': oldImeiSerial,
      'oldDeviceCondition': oldDeviceCondition,
      'oldDeviceNotes': oldDeviceNotes,
      'estimatedValue': estimatedValue,
      'finalExchangeValue': finalExchangeValue,
      'newProductId': newProductId,
      'newImeiSerialId': newImeiSerialId,
      'newProductName': newProductName,
      'newImeiSerial': newImeiSerial,
      'newDevicePrice': newDevicePrice,
      'exchangeValue': exchangeValue,
      'priceDifference': priceDifference,
      'additionalDiscount': additionalDiscount,
      'amountToPay': amountToPay,
      'paymentStatus': paymentStatus.value,
      'amountPaid': amountPaid,
      'paymentMode': paymentMode,
      'billId': billId,
      'status': status.value,
      'exchangeDate': exchangeDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isSynced': isSynced,
    };
  }

  factory Exchange.fromMap(Map<String, dynamic> map) {
    return Exchange(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      exchangeNumber: map['exchangeNumber'],
      customerId: map['customerId'],
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      oldDeviceName: map['oldDeviceName'] ?? '',
      oldDeviceBrand: map['oldDeviceBrand'],
      oldDeviceModel: map['oldDeviceModel'],
      oldImeiSerial: map['oldImeiSerial'],
      oldDeviceCondition: map['oldDeviceCondition'],
      oldDeviceNotes: map['oldDeviceNotes'],
      estimatedValue: (map['estimatedValue'] ?? 0).toDouble(),
      finalExchangeValue: (map['finalExchangeValue'] ?? 0).toDouble(),
      newProductId: map['newProductId'],
      newImeiSerialId: map['newImeiSerialId'],
      newProductName: map['newProductName'] ?? '',
      newImeiSerial: map['newImeiSerial'],
      newDevicePrice: (map['newDevicePrice'] ?? 0).toDouble(),
      exchangeValue: (map['exchangeValue'] ?? 0).toDouble(),
      priceDifference: (map['priceDifference'] ?? 0).toDouble(),
      additionalDiscount: (map['additionalDiscount'] ?? 0).toDouble(),
      amountToPay: (map['amountToPay'] ?? 0).toDouble(),
      paymentStatus: ExchangePaymentStatusExtension.fromString(
        map['paymentStatus'] ?? 'PENDING',
      ),
      amountPaid: (map['amountPaid'] ?? 0).toDouble(),
      paymentMode: map['paymentMode'],
      billId: map['billId'],
      status: ExchangeStatusExtension.fromString(map['status'] ?? 'DRAFT'),
      exchangeDate:
          DateTime.tryParse(map['exchangeDate'] ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
      isSynced: map['isSynced'] == true,
    );
  }

  Exchange copyWith({
    String? id,
    String? userId,
    String? exchangeNumber,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? oldDeviceName,
    String? oldDeviceBrand,
    String? oldDeviceModel,
    String? oldImeiSerial,
    String? oldDeviceCondition,
    String? oldDeviceNotes,
    double? estimatedValue,
    double? finalExchangeValue,
    String? newProductId,
    String? newImeiSerialId,
    String? newProductName,
    String? newImeiSerial,
    double? newDevicePrice,
    double? exchangeValue,
    double? priceDifference,
    double? additionalDiscount,
    double? amountToPay,
    ExchangePaymentStatus? paymentStatus,
    double? amountPaid,
    String? paymentMode,
    String? billId,
    ExchangeStatus? status,
    DateTime? exchangeDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return Exchange(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      exchangeNumber: exchangeNumber ?? this.exchangeNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      oldDeviceName: oldDeviceName ?? this.oldDeviceName,
      oldDeviceBrand: oldDeviceBrand ?? this.oldDeviceBrand,
      oldDeviceModel: oldDeviceModel ?? this.oldDeviceModel,
      oldImeiSerial: oldImeiSerial ?? this.oldImeiSerial,
      oldDeviceCondition: oldDeviceCondition ?? this.oldDeviceCondition,
      oldDeviceNotes: oldDeviceNotes ?? this.oldDeviceNotes,
      estimatedValue: estimatedValue ?? this.estimatedValue,
      finalExchangeValue: finalExchangeValue ?? this.finalExchangeValue,
      newProductId: newProductId ?? this.newProductId,
      newImeiSerialId: newImeiSerialId ?? this.newImeiSerialId,
      newProductName: newProductName ?? this.newProductName,
      newImeiSerial: newImeiSerial ?? this.newImeiSerial,
      newDevicePrice: newDevicePrice ?? this.newDevicePrice,
      exchangeValue: exchangeValue ?? this.exchangeValue,
      priceDifference: priceDifference ?? this.priceDifference,
      additionalDiscount: additionalDiscount ?? this.additionalDiscount,
      amountToPay: amountToPay ?? this.amountToPay,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      amountPaid: amountPaid ?? this.amountPaid,
      paymentMode: paymentMode ?? this.paymentMode,
      billId: billId ?? this.billId,
      status: status ?? this.status,
      exchangeDate: exchangeDate ?? this.exchangeDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
