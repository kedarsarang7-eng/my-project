import 'package:intl/intl.dart';

class UdharTransaction {
  final String id;
  final double amount;
  final String type; // 'given' or 'taken' (I Gave Money / I Took Money)
  final String reason;
  final DateTime date;

  UdharTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.reason,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'amount': amount,
    'type': type,
    'reason': reason,
    'date': date.toIso8601String(),
  };

  factory UdharTransaction.fromMap(String id, Map<String, dynamic> m) =>
      UdharTransaction(
        id: id,
        amount: (m['amount'] ?? 0).toDouble(),
        type: (m['type'] ?? 'given') as String,
        reason: (m['reason'] ?? '') as String,
        date: m['date'] != null
            ? DateTime.tryParse(m['date']) ?? DateTime.now()
            : DateTime.now(),
      );

  String get formattedDate => DateFormat('dd/MM/yyyy').format(date);
}

class UdharPerson {
  final String id;
  final String name;
  final double
  balance; // positive if customer will receive, negative if customer owes
  final String note;

  UdharPerson({
    required this.id,
    required this.name,
    required this.balance,
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'balance': balance,
    'note': note,
  };

  factory UdharPerson.fromMap(String id, Map<String, dynamic> m) => UdharPerson(
    id: id,
    name: (m['name'] ?? '') as String,
    balance: (m['balance'] ?? 0).toDouble(),
    note: (m['note'] ?? '') as String,
  );
}
