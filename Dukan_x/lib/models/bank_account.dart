class BankAccount {
  String id;
  String accountName; // e.g., "HDFC Savings"
  String accountNumber;
  String? ifscCode;
  String bankName;
  double balance;
  DateTime lastUpdated;

  BankAccount({
    required this.id,
    required this.accountName,
    required this.accountNumber,
    this.ifscCode,
    required this.bankName,
    required this.balance,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'accountName': accountName,
      'accountNumber': accountNumber,
      'ifscCode': ifscCode,
      'bankName': bankName,
      'balance': balance,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory BankAccount.fromMap(String id, Map<String, dynamic> map) {
    return BankAccount(
      id: id,
      accountName: map['accountName'] ?? '',
      accountNumber: map['accountNumber'] ?? '',
      ifscCode: map['ifscCode'],
      bankName: map['bankName'] ?? '',
      balance: (map['balance'] ?? 0).toDouble(),
      lastUpdated:
          DateTime.tryParse(map['lastUpdated'] ?? '') ?? DateTime.now(),
    );
  }
}

class BankTransaction {
  String id;
  String bankAccountId;
  double amount;
  String type; // 'credit', 'debit'
  String description;
  DateTime date;
  String? relatedEntityId; // Customer or Vendor ID

  BankTransaction({
    required this.id,
    required this.bankAccountId,
    required this.amount,
    required this.type,
    required this.description,
    required this.date,
    this.relatedEntityId,
  });

  // toMap and fromMap implementations...
  Map<String, dynamic> toMap() {
    return {
      'bankAccountId': bankAccountId,
      'amount': amount,
      'type': type,
      'description': description,
      'date': date.toIso8601String(),
      'relatedEntityId': relatedEntityId,
    };
  }

  factory BankTransaction.fromMap(String id, Map<String, dynamic> map) {
    return BankTransaction(
      id: id,
      bankAccountId: map['bankAccountId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      type: map['type'] ?? 'debit',
      description: map['description'] ?? '',
      date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
      relatedEntityId: map['relatedEntityId'],
    );
  }
}
