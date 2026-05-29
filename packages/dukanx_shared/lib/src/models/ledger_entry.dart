import 'package:equatable/equatable.dart';

enum LedgerEntryType { debit, credit, opening, adjustment }

class LedgerEntry extends Equatable {
  final String id;
  final String customerId;
  final String vendorId;
  final String vendorName;
  final LedgerEntryType entryType;
  final double amount;
  final double runningBalance;
  final String? referenceType;
  final String? referenceId;
  final String? referenceNumber;
  final String? description;
  final String? notes;
  final DateTime entryDate;
  final DateTime createdAt;

  const LedgerEntry({
    required this.id,
    required this.customerId,
    required this.vendorId,
    required this.vendorName,
    required this.entryType,
    required this.amount,
    required this.runningBalance,
    this.referenceType,
    this.referenceId,
    this.referenceNumber,
    this.description,
    this.notes,
    required this.entryDate,
    required this.createdAt,
  });

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    return LedgerEntry(
      id: json['id'] as String,
      customerId: json['customerId'] as String,
      vendorId: json['vendorId'] as String,
      vendorName: json['vendorName'] as String? ?? '',
      entryType: _typeFromString(json['entryType'] as String),
      amount: (json['amount'] as num).toDouble(),
      runningBalance: (json['runningBalance'] as num).toDouble(),
      referenceType: json['referenceType'] as String?,
      referenceId: json['referenceId'] as String?,
      referenceNumber: json['referenceNumber'] as String?,
      description: json['description'] as String?,
      notes: json['notes'] as String?,
      entryDate: DateTime.parse(json['entryDate'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static LedgerEntryType _typeFromString(String s) {
    switch (s.toLowerCase()) {
      case 'credit':
        return LedgerEntryType.credit;
      case 'opening':
        return LedgerEntryType.opening;
      case 'adjustment':
        return LedgerEntryType.adjustment;
      default:
        return LedgerEntryType.debit;
    }
  }

  bool get isCredit =>
      entryType == LedgerEntryType.credit || entryType == LedgerEntryType.opening;

  @override
  List<Object?> get props => [id, customerId, vendorId, entryType, amount, entryDate];
}
