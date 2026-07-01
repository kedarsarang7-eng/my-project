class Expense {
  String id;
  String category;
  String description;
  double amount;
  DateTime date;
  String ownerId;

  Expense({
    required this.id,
    required this.category,
    required this.description,
    required this.amount,
    required this.date,
    required this.ownerId,
  });

  Map<String, dynamic> toMap() => {
    'category': category,
    'description': description,
    'amount': amount,
    'date': date.toIso8601String(),
    'ownerId': ownerId,
  };

  factory Expense.fromMap(String id, Map<String, dynamic> map) => Expense(
    id: id,
    category: map['category'] ?? 'General',
    description: map['description'] ?? '',
    amount: (map['amount'] ?? 0).toDouble(),
    date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
    ownerId: map['ownerId'] ?? '',
  );
}
