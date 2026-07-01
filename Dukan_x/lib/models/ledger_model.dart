import 'package:dukanx/core/compat/firestore_compat.dart';

/// Ledger Account Groups following standard accounting classification.
///
/// Used to categorize accounts for financial statements:
/// - Assets & Expenses have Debit normal balance
/// - Liabilities, Income & Equity have Credit normal balance
enum LedgerGroup { assets, liabilities, income, expenses, equity }

/// Specific ledger types for quick filtering and behavior.
enum LedgerType {
  cash,
  bank,
  customer, // Sundry Debtor
  supplier, // Sundry Creditor
  sales,
  purchase,
  tax, // Duties & Taxes
  expense, // Indirect/Direct
  fixedAsset,
  capital,
  other,
}

/// Ledger Account Model - Chart of Accounts entry.
///
/// Each ledger represents an account in the double-entry system.
/// The balance is derived from ledger entries, not cached.
///
/// ## Balance Formula
/// For Assets/Expenses (Debit normal):
///   Balance = Opening + SUM(Debit) - SUM(Credit)
///
/// For Liabilities/Income/Equity (Credit normal):
///   Balance = Opening + SUM(Credit) - SUM(Debit)
class LedgerModel {
  final String ledgerId;
  final String businessId;
  final String name;
  final LedgerGroup group;
  final LedgerType type;

  /// Opening balance as of openingBalanceDate.
  /// This is the starting point for the accounting equation.
  final double openingBalance;

  /// Date from which openingBalance is effective.
  /// Usually the start of the financial year or ledger creation date.
  final DateTime? openingBalanceDate;

  /// @deprecated Use LedgerService.calculateBalance() instead.
  /// Cached balance for backward compatibility. Do not rely on this.
  @Deprecated('Derive balance from ledger entries using LedgerService')
  final double currentBalance;

  /// Link to Customer or Supplier if this is a party ledger.
  /// Null for system ledgers like Cash, Sales, etc.
  final String? partyId;

  /// True for system-generated ledgers that cannot be deleted.
  /// Examples: Cash Account, Sales Account, Output GST
  final bool isSystem;

  /// Version for optimistic locking
  final int version;

  /// Creation timestamp
  final DateTime? createdAt;

  LedgerModel({
    required this.ledgerId,
    required this.businessId,
    required this.name,
    required this.group,
    required this.type,
    this.openingBalance = 0,
    this.openingBalanceDate,
    @Deprecated('Use LedgerService.calculateBalance()') this.currentBalance = 0,
    this.partyId,
    this.isSystem = false,
    this.version = 1,
    this.createdAt,
  });

  /// True if this ledger has a Debit normal balance (Assets, Expenses).
  /// Used by LedgerService to calculate running balance correctly.
  bool get isDebitNormal =>
      group == LedgerGroup.assets || group == LedgerGroup.expenses;

  /// True if this is a party ledger (Customer or Supplier).
  bool get isPartyLedger =>
      type == LedgerType.customer || type == LedgerType.supplier;

  Map<String, dynamic> toMap() {
    return {
      'ledgerId': ledgerId,
      'businessId': businessId,
      'name': name,
      'group': group.name,
      'type': type.name,
      'openingBalance': openingBalance,
      'openingBalanceDate': openingBalanceDate?.toIso8601String(),
      'currentBalance': currentBalance, // Keep for backward compat
      'partyId': partyId,
      'isSystem': isSystem,
      'version': version,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ledgerId': ledgerId,
      'businessId': businessId,
      'name': name,
      'group': group.name,
      'type': type.name,
      'openingBalance': openingBalance,
      'openingBalanceDate': openingBalanceDate != null
          ? Timestamp.fromDate(openingBalanceDate!)
          : null,
      'currentBalance': currentBalance,
      'partyId': partyId,
      'isSystem': isSystem,
      'version': version,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory LedgerModel.fromMap(Map<String, dynamic> map) {
    return LedgerModel(
      ledgerId: map['ledgerId'] ?? '',
      businessId: map['businessId'] ?? '',
      name: map['name'] ?? '',
      group: LedgerGroup.values.firstWhere(
        (e) => e.name == map['group'],
        orElse: () => LedgerGroup.assets,
      ),
      type: LedgerType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => LedgerType.other,
      ),
      openingBalance: (map['openingBalance'] ?? 0).toDouble(),
      openingBalanceDate: _parseDate(map['openingBalanceDate']),
      currentBalance: (map['currentBalance'] ?? 0).toDouble(),
      partyId: map['partyId'],
      isSystem: map['isSystem'] ?? false,
      version: map['version'] ?? 1,
      createdAt: _parseDate(map['createdAt']),
    );
  }

  LedgerModel copyWith({
    String? ledgerId,
    String? businessId,
    String? name,
    LedgerGroup? group,
    LedgerType? type,
    double? openingBalance,
    DateTime? openingBalanceDate,
    double? currentBalance,
    String? partyId,
    bool? isSystem,
    int? version,
    DateTime? createdAt,
  }) {
    return LedgerModel(
      ledgerId: ledgerId ?? this.ledgerId,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      group: group ?? this.group,
      type: type ?? this.type,
      openingBalance: openingBalance ?? this.openingBalance,
      openingBalanceDate: openingBalanceDate ?? this.openingBalanceDate,
      currentBalance: currentBalance ?? this.currentBalance,
      partyId: partyId ?? this.partyId,
      isSystem: isSystem ?? this.isSystem,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  @override
  String toString() =>
      'LedgerModel(id: $ledgerId, name: $name, group: ${group.name})';
}
