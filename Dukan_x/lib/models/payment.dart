class Payment {
  String id;
  String billId;
  String customerId;
  double amount;
  DateTime date;
  String method; // cash / upi / other

  Payment({
    required this.id,
    required this.billId,
    required this.customerId,
    required this.amount,
    required this.date,
    required this.method,
  });

  Map<String, dynamic> toMap() => {
    'billId': billId,
    'customerId': customerId,
    'amount': amount,
    'date': date.toIso8601String(),
    'method': method,
  };

  factory Payment.fromMap(String id, Map<String, dynamic> m) => Payment(
    id: id,
    billId: m['billId'] ?? '',
    customerId: m['customerId'] ?? '',
    amount: (m['amount'] ?? 0).toDouble(),
    date: DateTime.parse(m['date'] ?? DateTime.now().toIso8601String()),
    method: m['method'] ?? 'cash',
  );
}
