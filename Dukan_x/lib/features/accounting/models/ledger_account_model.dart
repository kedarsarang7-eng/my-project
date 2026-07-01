/// Ledger Account Model for Chart of Accounts
///
/// Follows Tally-style accounting with 5 main groups:
/// - Assets (Debit balance increases)
/// - Liabilities (Credit balance increases)
/// - Income (Credit balance increases)
/// - Expenses (Debit balance increases)
/// - Equity (Credit balance increases)
library;

/// Account Groups (Top-level classification)
enum AccountGroup { assets, liabilities, income, expenses, equity }

extension AccountGroupExtension on AccountGroup {
  String get displayName {
    switch (this) {
      case AccountGroup.assets:
        return 'Assets';
      case AccountGroup.liabilities:
        return 'Liabilities';
      case AccountGroup.income:
        return 'Income';
      case AccountGroup.expenses:
        return 'Expenses';
      case AccountGroup.equity:
        return 'Equity';
    }
  }

  /// Whether debit increases balance (true for Assets, Expenses)
  bool get isDebitNormal =>
      this == AccountGroup.assets || this == AccountGroup.expenses;

  String get value => name.toUpperCase();

  static AccountGroup fromString(String value) {
    return AccountGroup.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => AccountGroup.assets,
    );
  }
}

/// Account Types (Sub-classification within groups)
enum AccountType {
  cash,
  bank,
  customer, // Sundry Debtor
  supplier, // Sundry Creditor
  sales,
  purchase,
  tax, // Duties & Taxes (GST, TDS, etc.)
  expense, // Indirect/Direct Expenses
  fixedAsset,
  inventory, // Stock-in-Trade
  capital, // Owner's Equity
  reserve, // Retained Earnings
  loan, // Secured/Unsecured Loans
  other,
}

extension AccountTypeExtension on AccountType {
  String get displayName {
    switch (this) {
      case AccountType.cash:
        return 'Cash';
      case AccountType.bank:
        return 'Bank Account';
      case AccountType.customer:
        return 'Sundry Debtor';
      case AccountType.supplier:
        return 'Sundry Creditor';
      case AccountType.sales:
        return 'Sales Account';
      case AccountType.purchase:
        return 'Purchase Account';
      case AccountType.tax:
        return 'Duties & Taxes';
      case AccountType.expense:
        return 'Expense';
      case AccountType.fixedAsset:
        return 'Fixed Asset';
      case AccountType.inventory:
        return 'Stock-in-Trade';
      case AccountType.capital:
        return 'Capital Account';
      case AccountType.reserve:
        return 'Reserves & Surplus';
      case AccountType.loan:
        return 'Loan Account';
      case AccountType.other:
        return 'Other';
    }
  }

  /// Default group for this account type
  AccountGroup get defaultGroup {
    switch (this) {
      case AccountType.cash:
      case AccountType.bank:
      case AccountType.customer:
      case AccountType.fixedAsset:
      case AccountType.inventory:
        return AccountGroup.assets;
      case AccountType.supplier:
      case AccountType.loan:
        return AccountGroup.liabilities;
      case AccountType.sales:
        return AccountGroup.income;
      case AccountType.purchase:
      case AccountType.expense:
        return AccountGroup.expenses;
      case AccountType.tax:
        return AccountGroup.liabilities; // GST payable is liability
      case AccountType.capital:
      case AccountType.reserve:
        return AccountGroup.equity;
      case AccountType.other:
        return AccountGroup.assets;
    }
  }

  String get value => name.toUpperCase();

  static AccountType fromString(String value) {
    return AccountType.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => AccountType.other,
    );
  }
}

/// Ledger Account Model
class LedgerAccountModel {
  final String id;
  final String userId;
  final String name;
  final AccountGroup group;
  final AccountType type;
  final double currentBalance;
  final double openingBalance;
  final bool openingIsDebit;
  final bool isSystem; // Prevent deletion of system ledgers
  final String? parentId; // For sub-ledgers
  final String? linkedEntityType; // CUSTOMER, VENDOR, BANK_ACCOUNT
  final String? linkedEntityId;
  final bool isActive;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;

  LedgerAccountModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.group,
    required this.type,
    this.currentBalance = 0,
    this.openingBalance = 0,
    this.openingIsDebit = true,
    this.isSystem = false,
    this.parentId,
    this.linkedEntityType,
    this.linkedEntityId,
    this.isActive = true,
    this.isSynced = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Effective opening balance (considering normal balance direction)
  double get effectiveOpeningBalance =>
      openingIsDebit ? openingBalance : -openingBalance;

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'name': name,
    'accountGroup': group.value,
    'accountType': type.value,
    'currentBalance': currentBalance,
    'openingBalance': openingBalance,
    'openingIsDebit': openingIsDebit,
    'isSystem': isSystem,
    'parentId': parentId,
    'linkedEntityType': linkedEntityType,
    'linkedEntityId': linkedEntityId,
    'isActive': isActive,
    'isSynced': isSynced,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory LedgerAccountModel.fromMap(Map<String, dynamic> map) =>
      LedgerAccountModel(
        id: map['id'] ?? '',
        userId: map['userId'] ?? '',
        name: map['name'] ?? '',
        group: AccountGroupExtension.fromString(
          map['accountGroup'] ?? 'ASSETS',
        ),
        type: AccountTypeExtension.fromString(map['accountType'] ?? 'OTHER'),
        currentBalance: (map['currentBalance'] ?? 0).toDouble(),
        openingBalance: (map['openingBalance'] ?? 0).toDouble(),
        openingIsDebit: map['openingIsDebit'] ?? true,
        isSystem: map['isSystem'] ?? false,
        parentId: map['parentId'],
        linkedEntityType: map['linkedEntityType'],
        linkedEntityId: map['linkedEntityId'],
        isActive: map['isActive'] ?? true,
        isSynced: map['isSynced'] ?? false,
        createdAt: DateTime.parse(
          map['createdAt'] ?? DateTime.now().toIso8601String(),
        ),
        updatedAt: DateTime.parse(
          map['updatedAt'] ?? DateTime.now().toIso8601String(),
        ),
      );

  LedgerAccountModel copyWith({
    String? id,
    String? userId,
    String? name,
    AccountGroup? group,
    AccountType? type,
    double? currentBalance,
    double? openingBalance,
    bool? openingIsDebit,
    bool? isSystem,
    String? parentId,
    String? linkedEntityType,
    String? linkedEntityId,
    bool? isActive,
    bool? isSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LedgerAccountModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      group: group ?? this.group,
      type: type ?? this.type,
      currentBalance: currentBalance ?? this.currentBalance,
      openingBalance: openingBalance ?? this.openingBalance,
      openingIsDebit: openingIsDebit ?? this.openingIsDebit,
      isSystem: isSystem ?? this.isSystem,
      parentId: parentId ?? this.parentId,
      linkedEntityType: linkedEntityType ?? this.linkedEntityType,
      linkedEntityId: linkedEntityId ?? this.linkedEntityId,
      isActive: isActive ?? this.isActive,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => '$name (${type.displayName})';
}

/// System Ledgers that should be auto-created for every business
class SystemLedgers {
  static const List<Map<String, dynamic>> defaults = [
    // Assets
    {'name': 'Cash in Hand', 'group': 'ASSETS', 'type': 'CASH'},
    {'name': 'Primary Bank Account', 'group': 'ASSETS', 'type': 'BANK'},
    {'name': 'Sundry Debtors', 'group': 'ASSETS', 'type': 'CUSTOMER'},
    {'name': 'Stock-in-Trade', 'group': 'ASSETS', 'type': 'INVENTORY'},

    // Liabilities
    {'name': 'Sundry Creditors', 'group': 'LIABILITIES', 'type': 'SUPPLIER'},
    {'name': 'CGST Payable', 'group': 'LIABILITIES', 'type': 'TAX'},
    {'name': 'SGST Payable', 'group': 'LIABILITIES', 'type': 'TAX'},
    {'name': 'IGST Payable', 'group': 'LIABILITIES', 'type': 'TAX'},
    {'name': 'CGST Receivable', 'group': 'ASSETS', 'type': 'TAX'},
    {'name': 'SGST Receivable', 'group': 'ASSETS', 'type': 'TAX'},
    {'name': 'IGST Receivable', 'group': 'ASSETS', 'type': 'TAX'},

    // Income
    {'name': 'Sales Account', 'group': 'INCOME', 'type': 'SALES'},
    {'name': 'Other Income', 'group': 'INCOME', 'type': 'OTHER'},

    // Expenses
    {'name': 'Purchase Account', 'group': 'EXPENSES', 'type': 'PURCHASE'},
    {'name': 'Discount Allowed', 'group': 'EXPENSES', 'type': 'EXPENSE'},
    {'name': 'Bank Charges', 'group': 'EXPENSES', 'type': 'EXPENSE'},
    {'name': 'Miscellaneous Expenses', 'group': 'EXPENSES', 'type': 'EXPENSE'},

    // Equity
    {'name': 'Capital Account', 'group': 'EQUITY', 'type': 'CAPITAL'},
    {'name': 'Retained Earnings', 'group': 'EQUITY', 'type': 'RESERVE'},
  ];
}
