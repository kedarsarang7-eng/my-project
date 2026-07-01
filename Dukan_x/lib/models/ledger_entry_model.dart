class LedgerEntry {
  final String entryId;
  final String businessId;
  final String txnId; // Source Transaction
  final String ledgerId; // Account affected
  final DateTime date;
  final double debit;
  final double credit;
  final String description; // Narration

  LedgerEntry({
    required this.entryId,
    required this.businessId,
    required this.txnId,
    required this.ledgerId,
    required this.date,
    required this.debit,
    required this.credit,
    this.description = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'entryId': entryId,
      'businessId': businessId,
      'txnId': txnId,
      'ledgerId': ledgerId,
      'date': date.toIso8601String(),
      'debit': debit,
      'credit': credit,
      'description': description,
    };
  }

  factory LedgerEntry.fromMap(Map<String, dynamic> map) {
    return LedgerEntry(
      entryId: map['entryId'] ?? '',
      businessId: map['businessId'] ?? '',
      txnId: map['txnId'] ?? '',
      ledgerId: map['ledgerId'] ?? '',
      date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
      debit: (map['debit'] ?? 0).toDouble(),
      credit: (map['credit'] ?? 0).toDouble(),
      description: map['description'] ?? '',
    );
  }
}
