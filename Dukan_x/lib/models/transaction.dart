// Transaction Model for Sales, Purchases, and Expenses

class Transaction {
  String id;
  String type; // 'sale', 'purchase', 'expense'
  String category; // e.g., 'vegetables', 'equipment', 'rent', 'utilities'
  String description;
  double amount;
  DateTime date;
  String? relatedCustomerId; // For sales transactions
  String? relatedVegetableId; // For purchase/sale transactions
  String paymentMethod; // 'cash', 'online', 'bank'
  String status; // 'pending', 'completed', 'cancelled'
  String? notes;

  Transaction({
    required this.id,
    required this.type,
    required this.category,
    required this.description,
    required this.amount,
    required this.date,
    this.relatedCustomerId,
    this.relatedVegetableId,
    this.paymentMethod = 'cash',
    this.status = 'completed',
    this.notes,
  });

  factory Transaction.fromMap(String id, Map<String, dynamic> map) =>
      Transaction(
        id: id,
        type: map['type'] ?? 'sale',
        category: map['category'] ?? '',
        description: map['description'] ?? '',
        amount: (map['amount'] ?? 0).toDouble(),
        date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
        relatedCustomerId: map['relatedCustomerId'],
        relatedVegetableId: map['relatedVegetableId'],
        paymentMethod: map['paymentMethod'] ?? 'cash',
        status: map['status'] ?? 'completed',
        notes: map['notes'],
      );

  Map<String, dynamic> toMap() => {
    'type': type,
    'category': category,
    'description': description,
    'amount': amount,
    'date': date.toIso8601String(),
    'relatedCustomerId': relatedCustomerId,
    'relatedVegetableId': relatedVegetableId,
    'paymentMethod': paymentMethod,
    'status': status,
    'notes': notes,
  };
}

// Summary class for financial reporting
class FinancialSummary {
  double totalSales;
  double totalPurchases;
  double totalExpenses;
  double netProfit;
  int saleCount;
  int purchaseCount;
  int expenseCount;
  DateTime periodStart;
  DateTime periodEnd;

  FinancialSummary({
    required this.totalSales,
    required this.totalPurchases,
    required this.totalExpenses,
    required this.netProfit,
    required this.saleCount,
    required this.purchaseCount,
    required this.expenseCount,
    required this.periodStart,
    required this.periodEnd,
  });

  factory FinancialSummary.calculate(
    List<Transaction> transactions,
    DateTime start,
    DateTime end,
  ) {
    final filtered = transactions
        .where(
          (t) =>
              t.date.isAfter(start) &&
              t.date.isBefore(end.add(const Duration(days: 1))),
        )
        .toList();

    double totalSales = 0, totalPurchases = 0, totalExpenses = 0;
    int saleCount = 0, purchaseCount = 0, expenseCount = 0;

    for (var t in filtered) {
      if (t.status == 'completed') {
        if (t.type == 'sale') {
          totalSales += t.amount;
          saleCount++;
        } else if (t.type == 'purchase') {
          totalPurchases += t.amount;
          purchaseCount++;
        } else if (t.type == 'expense') {
          totalExpenses += t.amount;
          expenseCount++;
        }
      }
    }

    final netProfit = totalSales - totalPurchases - totalExpenses;

    return FinancialSummary(
      totalSales: totalSales,
      totalPurchases: totalPurchases,
      totalExpenses: totalExpenses,
      netProfit: netProfit,
      saleCount: saleCount,
      purchaseCount: purchaseCount,
      expenseCount: expenseCount,
      periodStart: start,
      periodEnd: end,
    );
  }
}
