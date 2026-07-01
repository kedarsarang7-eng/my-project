import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Tally Ledger Configuration Model
/// Maps DukanX accounts to Tally ledger names for seamless import
class TallyLedgerConfig {
  // Sales Ledgers
  final String salesLedger;
  final String outputCgstLedger;
  final String outputSgstLedger;
  final String outputIgstLedger;

  // Purchase Ledgers
  final String purchaseLedger;
  final String inputCgstLedger;
  final String inputSgstLedger;
  final String inputIgstLedger;

  // Cash & Bank
  final String cashLedger;
  final String bankLedger;

  // Default Party Ledgers
  final String defaultCustomerLedger;
  final String defaultSupplierLedger;

  const TallyLedgerConfig({
    this.salesLedger = 'Sales',
    this.outputCgstLedger = 'Output CGST',
    this.outputSgstLedger = 'Output SGST',
    this.outputIgstLedger = 'Output IGST',
    this.purchaseLedger = 'Purchase Accounts',
    this.inputCgstLedger = 'Input CGST',
    this.inputSgstLedger = 'Input SGST',
    this.inputIgstLedger = 'Input IGST',
    this.cashLedger = 'Cash',
    this.bankLedger = 'Bank Accounts',
    this.defaultCustomerLedger = 'Cash Customer',
    this.defaultSupplierLedger = 'Cash Purchase',
  });

  /// Create from JSON
  factory TallyLedgerConfig.fromJson(Map<String, dynamic> json) {
    return TallyLedgerConfig(
      salesLedger: json['salesLedger'] ?? 'Sales',
      outputCgstLedger: json['outputCgstLedger'] ?? 'Output CGST',
      outputSgstLedger: json['outputSgstLedger'] ?? 'Output SGST',
      outputIgstLedger: json['outputIgstLedger'] ?? 'Output IGST',
      purchaseLedger: json['purchaseLedger'] ?? 'Purchase Accounts',
      inputCgstLedger: json['inputCgstLedger'] ?? 'Input CGST',
      inputSgstLedger: json['inputSgstLedger'] ?? 'Input SGST',
      inputIgstLedger: json['inputIgstLedger'] ?? 'Input IGST',
      cashLedger: json['cashLedger'] ?? 'Cash',
      bankLedger: json['bankLedger'] ?? 'Bank Accounts',
      defaultCustomerLedger: json['defaultCustomerLedger'] ?? 'Cash Customer',
      defaultSupplierLedger: json['defaultSupplierLedger'] ?? 'Cash Purchase',
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'salesLedger': salesLedger,
      'outputCgstLedger': outputCgstLedger,
      'outputSgstLedger': outputSgstLedger,
      'outputIgstLedger': outputIgstLedger,
      'purchaseLedger': purchaseLedger,
      'inputCgstLedger': inputCgstLedger,
      'inputSgstLedger': inputSgstLedger,
      'inputIgstLedger': inputIgstLedger,
      'cashLedger': cashLedger,
      'bankLedger': bankLedger,
      'defaultCustomerLedger': defaultCustomerLedger,
      'defaultSupplierLedger': defaultSupplierLedger,
    };
  }

  /// Copy with modifications
  TallyLedgerConfig copyWith({
    String? salesLedger,
    String? outputCgstLedger,
    String? outputSgstLedger,
    String? outputIgstLedger,
    String? purchaseLedger,
    String? inputCgstLedger,
    String? inputSgstLedger,
    String? inputIgstLedger,
    String? cashLedger,
    String? bankLedger,
    String? defaultCustomerLedger,
    String? defaultSupplierLedger,
  }) {
    return TallyLedgerConfig(
      salesLedger: salesLedger ?? this.salesLedger,
      outputCgstLedger: outputCgstLedger ?? this.outputCgstLedger,
      outputSgstLedger: outputSgstLedger ?? this.outputSgstLedger,
      outputIgstLedger: outputIgstLedger ?? this.outputIgstLedger,
      purchaseLedger: purchaseLedger ?? this.purchaseLedger,
      inputCgstLedger: inputCgstLedger ?? this.inputCgstLedger,
      inputSgstLedger: inputSgstLedger ?? this.inputSgstLedger,
      inputIgstLedger: inputIgstLedger ?? this.inputIgstLedger,
      cashLedger: cashLedger ?? this.cashLedger,
      bankLedger: bankLedger ?? this.bankLedger,
      defaultCustomerLedger:
          defaultCustomerLedger ?? this.defaultCustomerLedger,
      defaultSupplierLedger:
          defaultSupplierLedger ?? this.defaultSupplierLedger,
    );
  }
}

/// Tally Ledger Configuration Service
/// Persists and retrieves ledger mapping configuration
class TallyLedgerConfigService {
  static const _storageKey = 'tally_ledger_config';

  /// Get current configuration
  Future<TallyLedgerConfig> getConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);

    if (jsonStr == null) {
      return const TallyLedgerConfig(); // Default
    }

    try {
      return TallyLedgerConfig.fromJson(jsonDecode(jsonStr));
    } catch (e) {
      return const TallyLedgerConfig();
    }
  }

  /// Save configuration
  Future<bool> saveConfig(TallyLedgerConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_storageKey, jsonEncode(config.toJson()));
  }

  /// Reset to defaults
  Future<bool> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.remove(_storageKey);
  }
}
