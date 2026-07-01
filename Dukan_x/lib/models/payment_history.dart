class PaymentHistory {
  String id;
  String customerId;
  DateTime paymentDate;
  double amount;
  String paymentType; // Cash, Online, Cheque
  String status; // Pending, Completed, Failed
  String description;
  double duesCleared;

  PaymentHistory({
    required this.id,
    required this.customerId,
    required this.paymentDate,
    required this.amount,
    this.paymentType = 'Cash',
    this.status = 'Completed',
    this.description = '',
    this.duesCleared = 0.0,
  });

  factory PaymentHistory.fromMap(String id, Map<String, dynamic> map) =>
      PaymentHistory(
        id: id,
        customerId: map['customerId'] ?? '',
        paymentDate: DateTime.parse(
          map['paymentDate'] ?? DateTime.now().toIso8601String(),
        ),
        amount: (map['amount'] ?? 0).toDouble(),
        paymentType: map['paymentType'] ?? 'Cash',
        status: map['status'] ?? 'Completed',
        description: map['description'] ?? '',
        duesCleared: (map['duesCleared'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toMap() => {
    'customerId': customerId,
    'paymentDate': paymentDate.toIso8601String(),
    'amount': amount,
    'paymentType': paymentType,
    'status': status,
    'description': description,
    'duesCleared': duesCleared,
  };
}

class DailyBillSummary {
  String date;
  int totalBills;
  double totalRevenue;
  double totalPaid;
  double totalDues;
  double cashSales;
  double onlineSales;
  int vegetableTypes;

  DailyBillSummary({
    required this.date,
    this.totalBills = 0,
    this.totalRevenue = 0.0,
    this.totalPaid = 0.0,
    this.totalDues = 0.0,
    this.cashSales = 0.0,
    this.onlineSales = 0.0,
    this.vegetableTypes = 0,
  });

  factory DailyBillSummary.fromMap(String date, Map<String, dynamic> map) =>
      DailyBillSummary(
        date: date,
        totalBills: map['totalBills'] ?? 0,
        totalRevenue: (map['totalRevenue'] ?? 0).toDouble(),
        totalPaid: (map['totalPaid'] ?? 0).toDouble(),
        totalDues: (map['totalDues'] ?? 0).toDouble(),
        cashSales: (map['cashSales'] ?? 0).toDouble(),
        onlineSales: (map['onlineSales'] ?? 0).toDouble(),
        vegetableTypes: map['vegetableTypes'] ?? 0,
      );

  Map<String, dynamic> toMap() => {
    'totalBills': totalBills,
    'totalRevenue': totalRevenue,
    'totalPaid': totalPaid,
    'totalDues': totalDues,
    'cashSales': cashSales,
    'onlineSales': onlineSales,
    'vegetableTypes': vegetableTypes,
  };
}

class BlacklistedCustomer {
  String customerId;
  String customerName;
  DateTime blacklistDate;
  DateTime? fromDate;
  DateTime? toDate;
  double duesAmount;
  String reason;

  BlacklistedCustomer({
    required this.customerId,
    required this.customerName,
    required this.blacklistDate,
    this.fromDate,
    this.toDate,
    this.duesAmount = 0.0,
    this.reason = 'Non-payment',
  });

  factory BlacklistedCustomer.fromMap(String id, Map<String, dynamic> map) =>
      BlacklistedCustomer(
        customerId: id,
        customerName: map['customerName'] ?? '',
        blacklistDate: DateTime.parse(
          map['blacklistDate'] ?? DateTime.now().toIso8601String(),
        ),
        fromDate: map['fromDate'] != null
            ? DateTime.parse(map['fromDate'])
            : null,
        toDate: map['toDate'] != null ? DateTime.parse(map['toDate']) : null,
        duesAmount: (map['duesAmount'] ?? 0).toDouble(),
        reason: map['reason'] ?? 'Non-payment',
      );

  Map<String, dynamic> toMap() => {
    'customerName': customerName,
    'blacklistDate': blacklistDate.toIso8601String(),
    'fromDate': fromDate?.toIso8601String(),
    'toDate': toDate?.toIso8601String(),
    'duesAmount': duesAmount,
    'reason': reason,
  };
}
