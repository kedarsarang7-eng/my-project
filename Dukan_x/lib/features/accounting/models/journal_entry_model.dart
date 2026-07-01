import 'dart:convert';

/// Journal Entry Model for Double-Entry Accounting
///
/// Each journal entry records a complete transaction with:
/// - Multiple debit entries
/// - Multiple credit entries
/// - Total debits MUST equal total credits

/// Voucher Types (Transaction categories)
enum VoucherType {
  sales, // Sales invoice
  purchase, // Purchase invoice
  receipt, // Payment received
  payment, // Payment made
  journal, // Manual journal entry
  contra, // Cash/Bank transfer
  debitNote, // Sales return
  creditNote, // Purchase return
}

extension VoucherTypeExtension on VoucherType {
  String get displayName {
    switch (this) {
      case VoucherType.sales:
        return 'Sales';
      case VoucherType.purchase:
        return 'Purchase';
      case VoucherType.receipt:
        return 'Receipt';
      case VoucherType.payment:
        return 'Payment';
      case VoucherType.journal:
        return 'Journal';
      case VoucherType.contra:
        return 'Contra';
      case VoucherType.debitNote:
        return 'Debit Note';
      case VoucherType.creditNote:
        return 'Credit Note';
    }
  }

  /// Prefix for voucher number generation
  String get prefix {
    switch (this) {
      case VoucherType.sales:
        return 'SV';
      case VoucherType.purchase:
        return 'PV';
      case VoucherType.receipt:
        return 'RV';
      case VoucherType.payment:
        return 'PY';
      case VoucherType.journal:
        return 'JV';
      case VoucherType.contra:
        return 'CV';
      case VoucherType.debitNote:
        return 'DN';
      case VoucherType.creditNote:
        return 'CN';
    }
  }

  String get value => name.toUpperCase();

  static VoucherType fromString(String value) {
    return VoucherType.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => VoucherType.journal,
    );
  }
}

/// Source Type - What generated this journal entry
enum SourceType {
  bill,
  purchaseOrder,
  expense,
  payment,
  receipt,
  manual,
  inventory,
  reversal, // Added for audit trail
  returnInward, // Added for sales returns (credit notes)
}

extension SourceTypeExtension on SourceType {
  String get value => name.toUpperCase();

  static SourceType fromString(String value) {
    return SourceType.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => SourceType.manual,
    );
  }
}

/// Individual journal entry line item
class JournalEntryLine {
  final String ledgerId;
  final String ledgerName; // Cached for display
  final double debit;
  final double credit;
  final String? description;

  JournalEntryLine({
    required this.ledgerId,
    required this.ledgerName,
    this.debit = 0,
    this.credit = 0,
    this.description,
  });

  Map<String, dynamic> toMap() => {
    'ledgerId': ledgerId,
    'ledgerName': ledgerName,
    'debit': debit,
    'credit': credit,
    'description': description,
  };

  factory JournalEntryLine.fromMap(Map<String, dynamic> map) =>
      JournalEntryLine(
        ledgerId: map['ledgerId'] ?? '',
        ledgerName: map['ledgerName'] ?? '',
        debit: (map['debit'] ?? 0).toDouble(),
        credit: (map['credit'] ?? 0).toDouble(),
        description: map['description'],
      );
}

/// Complete Journal Entry Model
class JournalEntryModel {
  final String id;
  final String userId;
  final String voucherNumber;
  final VoucherType voucherType;
  final DateTime entryDate;
  final String? narration;
  final SourceType? sourceType;
  final String? sourceId;
  final List<JournalEntryLine> entries;
  final double totalDebit;
  final double totalCredit;
  final bool isLocked;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;

  JournalEntryModel({
    required this.id,
    required this.userId,
    required this.voucherNumber,
    required this.voucherType,
    required this.entryDate,
    this.narration,
    this.sourceType,
    this.sourceId,
    required this.entries,
    required this.totalDebit,
    required this.totalCredit,
    this.isLocked = false,
    this.isSynced = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Validate that debits equal credits
  bool get isBalanced => (totalDebit - totalCredit).abs() < 0.01;

  /// Get all debit entries
  List<JournalEntryLine> get debitEntries =>
      entries.where((e) => e.debit > 0).toList();

  /// Get all credit entries
  List<JournalEntryLine> get creditEntries =>
      entries.where((e) => e.credit > 0).toList();

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'voucherNumber': voucherNumber,
    'voucherType': voucherType.value,
    'entryDate': entryDate.toIso8601String(),
    'narration': narration,
    'sourceType': sourceType?.value,
    'sourceId': sourceId,
    'entriesJson': jsonEncode(entries.map((e) => e.toMap()).toList()),
    'totalDebit': totalDebit,
    'totalCredit': totalCredit,
    'isLocked': isLocked,
    'isSynced': isSynced,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory JournalEntryModel.fromMap(Map<String, dynamic> map) {
    List<JournalEntryLine> entryLines = [];
    if (map['entriesJson'] != null) {
      try {
        final List<dynamic> decoded = map['entriesJson'] is String
            ? jsonDecode(map['entriesJson'])
            : map['entriesJson'];
        entryLines = decoded.map((e) => JournalEntryLine.fromMap(e)).toList();
      } catch (_) {}
    }

    return JournalEntryModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      voucherNumber: map['voucherNumber'] ?? '',
      voucherType: VoucherTypeExtension.fromString(
        map['voucherType'] ?? 'JOURNAL',
      ),
      entryDate: DateTime.parse(
        map['entryDate'] ?? DateTime.now().toIso8601String(),
      ),
      narration: map['narration'],
      sourceType: map['sourceType'] != null
          ? SourceTypeExtension.fromString(map['sourceType'])
          : null,
      sourceId: map['sourceId'],
      entries: entryLines,
      totalDebit: (map['totalDebit'] ?? 0).toDouble(),
      totalCredit: (map['totalCredit'] ?? 0).toDouble(),
      isLocked: map['isLocked'] ?? false,
      isSynced: map['isSynced'] ?? false,
      createdAt: DateTime.parse(
        map['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        map['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  JournalEntryModel copyWith({
    String? id,
    String? userId,
    String? voucherNumber,
    VoucherType? voucherType,
    DateTime? entryDate,
    String? narration,
    SourceType? sourceType,
    String? sourceId,
    List<JournalEntryLine>? entries,
    double? totalDebit,
    double? totalCredit,
    bool? isLocked,
    bool? isSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JournalEntryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      voucherNumber: voucherNumber ?? this.voucherNumber,
      voucherType: voucherType ?? this.voucherType,
      entryDate: entryDate ?? this.entryDate,
      narration: narration ?? this.narration,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      entries: entries ?? this.entries,
      totalDebit: totalDebit ?? this.totalDebit,
      totalCredit: totalCredit ?? this.totalCredit,
      isLocked: isLocked ?? this.isLocked,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Logical Classification of Accounting Entries
/// (Non-breaking, derived classification)
enum AccountingEntryClassification {
  bill,
  purchase,
  expense,
  payment,
  receipt,
  adjustment,
  depreciation,
  contra,
  openingBalance,
  systemGenerated,
}

extension JournalEntryClassification on JournalEntryModel {
  AccountingEntryClassification get classification {
    // 1. Check SourceType (More specific)
    if (sourceType == SourceType.expense) {
      return AccountingEntryClassification.expense;
    }
    if (sourceType == SourceType.reversal) {
      return AccountingEntryClassification.adjustment;
    }
    if (sourceType == SourceType.inventory) {
      if ((narration ?? '').toUpperCase().contains('OPENING')) {
        return AccountingEntryClassification.openingBalance;
      }
      return AccountingEntryClassification.adjustment;
    }

    // 2. Check VoucherType
    switch (voucherType) {
      case VoucherType.sales:
        return AccountingEntryClassification.bill;
      case VoucherType.purchase:
        return AccountingEntryClassification.purchase;
      case VoucherType.payment:
        return AccountingEntryClassification.payment;
      case VoucherType.receipt:
        return AccountingEntryClassification.receipt;
      case VoucherType.contra:
        return AccountingEntryClassification.contra;
      case VoucherType.journal:
        // Try to detect special cases
        final nar = (narration ?? '').toLowerCase();
        if (nar.contains('depreciation')) {
          return AccountingEntryClassification.depreciation;
        }
        if (nar.contains('opening balance')) {
          return AccountingEntryClassification.openingBalance;
        }
        return AccountingEntryClassification.adjustment;
      case VoucherType.debitNote:
      case VoucherType.creditNote:
        return AccountingEntryClassification.adjustment;
    }
    // Dead code removed
  }
}
