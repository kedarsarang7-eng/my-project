import 'package:dukanx/core/api/api_client.dart';
import 'package:dukanx/core/di/service_locator.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/logger_service.dart';
import '../../../features/accounting/services/journal_entry_service.dart';

/// Opening Balance Entry for a specific account type
class OpeningBalanceEntry {
  final String accountId;
  final String accountName;
  final String accountType; // 'CASH', 'BANK', 'CUSTOMER', 'SUPPLIER', 'PRODUCT'
  final double balance;
  final DateTime asOfDate;

  const OpeningBalanceEntry({
    required this.accountId,
    required this.accountName,
    required this.accountType,
    required this.balance,
    required this.asOfDate,
  });

  Map<String, dynamic> toMap() => {
    'accountId': accountId,
    'accountName': accountName,
    'accountType': accountType,
    'balance': balance,
    'asOfDate': asOfDate.toIso8601String(),
  };
}

/// Opening Balance Setup Result
class OpeningBalanceResult {
  final bool success;
  final int cashEntriesCreated;
  final int bankEntriesCreated;
  final int customerEntriesCreated;
  final int supplierEntriesCreated;
  final int stockEntriesCreated;
  final List<String> errors;

  const OpeningBalanceResult({
    required this.success,
    this.cashEntriesCreated = 0,
    this.bankEntriesCreated = 0,
    this.customerEntriesCreated = 0,
    this.supplierEntriesCreated = 0,
    this.stockEntriesCreated = 0,
    this.errors = const [],
  });

  int get totalEntriesCreated =>
      cashEntriesCreated +
      bankEntriesCreated +
      customerEntriesCreated +
      supplierEntriesCreated +
      stockEntriesCreated;

  Map<String, dynamic> toMap() => {
    'success': success,
    'cashEntriesCreated': cashEntriesCreated,
    'bankEntriesCreated': bankEntriesCreated,
    'customerEntriesCreated': customerEntriesCreated,
    'supplierEntriesCreated': supplierEntriesCreated,
    'stockEntriesCreated': stockEntriesCreated,
    'totalEntriesCreated': totalEntriesCreated,
    'errors': errors,
  };
}

/// Opening Balance Service - Sets up opening balances via REST API.
///
/// Migrated from Firestore SDK to ApiClient (API Gateway + Lambda + DynamoDB).
///
/// ## Features
/// - Sets opening stock for all products
/// - Sets opening cash balance
/// - Sets opening bank balance
/// - Sets customer opening balances (receivables)
/// - Sets supplier opening balances (payables)
/// - Creates proper ledger entries for all opening balances
/// - Marks onboarding as complete
class OpeningBalanceService {
  ApiClient get _api => sl<ApiClient>();
  // Reserved for future journal entry validation support
  // ignore: unused_field
  final JournalEntryService? _journalService;

  OpeningBalanceService({
    JournalEntryService? journalService,
  }) : _journalService = journalService;

  // ============================================================
  // CASH OPENING BALANCE
  // ============================================================

  /// Set opening cash balance via API.
  Future<void> setCashOpeningBalance({
    required String userId,
    required double amount,
    required DateTime asOfDate,
    String? notes,
  }) async {
    if (amount < 0) throw ArgumentError('Opening balance cannot be negative');

    final response = await _api.post(
      '/opening-balances/cash',
      body: {
        'userId': userId,
        'amount': amount,
        'asOfDate': asOfDate.toIso8601String(),
        'notes': notes ?? 'Opening balance as of ${asOfDate.toString().split(' ')[0]}',
      },
    );

    if (!response.isSuccess) {
      throw Exception('Failed to set cash opening balance: ${response.error}');
    }

    LoggerService.d('OpeningBalance', '[OPENING] Cash balance set: ?$amount as of $asOfDate');
  }

  // ============================================================
  // BANK OPENING BALANCE
  // ============================================================

  /// Set opening bank balance for a bank account.
  Future<void> setBankOpeningBalance({
    required String userId,
    required String bankAccountId,
    required String bankName,
    required double amount,
    required DateTime asOfDate,
    String? accountNumber,
    String? notes,
  }) async {
    if (amount < 0) throw ArgumentError('Opening balance cannot be negative');

    final response = await _api.post(
      '/opening-balances/bank',
      body: {
        'userId': userId,
        'bankAccountId': bankAccountId,
        'bankName': bankName,
        'amount': amount,
        'asOfDate': asOfDate.toIso8601String(),
        'accountNumber': accountNumber,
        'notes': notes ?? 'Opening balance as of ${asOfDate.toString().split(' ')[0]}',
      },
    );

    if (!response.isSuccess) {
      throw Exception('Failed to set bank opening balance: ${response.error}');
    }

    LoggerService.d('OpeningBalance',
      '[OPENING] Bank balance set: $bankName ?$amount as of $asOfDate',
    );
  }

  // ============================================================
  // CUSTOMER OPENING BALANCE (Receivables)
  // ============================================================

  /// Set opening balance for a customer (amount they owe us).
  Future<void> setCustomerOpeningBalance({
    required String userId,
    required String customerId,
    required String customerName,
    required double amount,
    required DateTime asOfDate,
    String? notes,
  }) async {
    if (amount < 0) throw ArgumentError('Opening balance cannot be negative');

    final response = await _api.post(
      '/opening-balances/customer',
      body: {
        'userId': userId,
        'customerId': customerId,
        'customerName': customerName,
        'amount': amount,
        'asOfDate': asOfDate.toIso8601String(),
        'notes': notes ?? 'Opening balance as of ${asOfDate.toString().split(' ')[0]}',
      },
    );

    if (!response.isSuccess) {
      throw Exception('Failed to set customer opening balance: ${response.error}');
    }

    LoggerService.d('OpeningBalance', '[OPENING] Customer balance set: $customerName ?$amount');
  }

  // ============================================================
  // SUPPLIER OPENING BALANCE (Payables)
  // ============================================================

  /// Set opening balance for a supplier (amount we owe them).
  Future<void> setSupplierOpeningBalance({
    required String userId,
    required String supplierId,
    required String supplierName,
    required double amount,
    required DateTime asOfDate,
    String? notes,
  }) async {
    if (amount < 0) throw ArgumentError('Opening balance cannot be negative');

    final response = await _api.post(
      '/opening-balances/supplier',
      body: {
        'userId': userId,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'amount': amount,
        'asOfDate': asOfDate.toIso8601String(),
        'notes': notes ?? 'Opening balance as of ${asOfDate.toString().split(' ')[0]}',
      },
    );

    if (!response.isSuccess) {
      throw Exception('Failed to set supplier opening balance: ${response.error}');
    }

    LoggerService.d('OpeningBalance', '[OPENING] Supplier balance set: $supplierName ?$amount');
  }

  // ============================================================
  // STOCK OPENING BALANCE
  // ============================================================

  /// Set opening stock for a product.
  Future<void> setProductOpeningStock({
    required String userId,
    required String productId,
    required String productName,
    required double quantity,
    required double costPrice,
    required DateTime asOfDate,
    String? notes,
  }) async {
    if (quantity < 0) {
      throw ArgumentError('Opening quantity cannot be negative');
    }
    if (costPrice < 0) {
      throw ArgumentError('Cost price cannot be negative');
    }

    final response = await _api.post(
      '/opening-balances/stock',
      body: {
        'userId': userId,
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'costPrice': costPrice,
        'asOfDate': asOfDate.toIso8601String(),
        'notes': notes ?? 'Opening stock: $quantity units @ ?$costPrice',
      },
    );

    if (!response.isSuccess) {
      throw Exception('Failed to set product opening stock: ${response.error}');
    }

    LoggerService.d('OpeningBalance', '[OPENING] Stock set: $productName $quantity @ ?$costPrice');
  }

  // ============================================================
  // BULK OPENING BALANCE SETUP
  // ============================================================

  /// Set all opening balances in bulk.
  ///
  /// This is the main method for onboarding wizard.
  Future<OpeningBalanceResult> setAllOpeningBalances({
    required String userId,
    required DateTime asOfDate,
    double? cashBalance,
    List<Map<String, dynamic>>? bankAccounts,
    List<Map<String, dynamic>>? customerBalances,
    List<Map<String, dynamic>>? supplierBalances,
    List<Map<String, dynamic>>? stockBalances,
  }) async {
    final errors = <String>[];
    int cashEntries = 0;
    int bankEntries = 0;
    int customerEntries = 0;
    int supplierEntries = 0;
    int stockEntries = 0;

    try {
      // 1. Set Cash Balance
      if (cashBalance != null && cashBalance > 0) {
        try {
          await setCashOpeningBalance(
            userId: userId,
            amount: cashBalance,
            asOfDate: asOfDate,
          );
          cashEntries = 1;
        } catch (e) {
          errors.add('Cash balance error: $e');
        }
      }

      // 2. Set Bank Balances
      if (bankAccounts != null) {
        for (final bank in bankAccounts) {
          try {
            await setBankOpeningBalance(
              userId: userId,
              bankAccountId: bank['id'] ?? const Uuid().v4(),
              bankName: bank['name'] ?? 'Bank Account',
              amount: (bank['balance'] as num?)?.toDouble() ?? 0,
              asOfDate: asOfDate,
              accountNumber: bank['accountNumber'],
            );
            bankEntries++;
          } catch (e) {
            errors.add('Bank ${bank['name']} error: $e');
          }
        }
      }

      // 3. Set Customer Balances
      if (customerBalances != null) {
        for (final customer in customerBalances) {
          try {
            await setCustomerOpeningBalance(
              userId: userId,
              customerId: customer['id'] ?? '',
              customerName: customer['name'] ?? 'Customer',
              amount: (customer['balance'] as num?)?.toDouble() ?? 0,
              asOfDate: asOfDate,
            );
            customerEntries++;
          } catch (e) {
            errors.add('Customer ${customer['name']} error: $e');
          }
        }
      }

      // 4. Set Supplier Balances
      if (supplierBalances != null) {
        for (final supplier in supplierBalances) {
          try {
            await setSupplierOpeningBalance(
              userId: userId,
              supplierId: supplier['id'] ?? '',
              supplierName: supplier['name'] ?? 'Supplier',
              amount: (supplier['balance'] as num?)?.toDouble() ?? 0,
              asOfDate: asOfDate,
            );
            supplierEntries++;
          } catch (e) {
            errors.add('Supplier ${supplier['name']} error: $e');
          }
        }
      }

      // 5. Set Stock Balances
      if (stockBalances != null) {
        for (final product in stockBalances) {
          try {
            await setProductOpeningStock(
              userId: userId,
              productId: product['id'] ?? '',
              productName: product['name'] ?? 'Product',
              quantity: (product['quantity'] as num?)?.toDouble() ?? 0,
              costPrice: (product['costPrice'] as num?)?.toDouble() ?? 0,
              asOfDate: asOfDate,
            );
            stockEntries++;
          } catch (e) {
            errors.add('Product ${product['name']} error: $e');
          }
        }
      }

      // 6. Mark Onboarding Complete
      await _api.post(
        '/opening-balances/complete',
        body: {
          'userId': userId,
          'asOfDate': asOfDate.toIso8601String(),
        },
      );

      LoggerService.d('OpeningBalance',
        '[OPENING] Bulk setup complete: Cash=$cashEntries, '
        'Banks=$bankEntries, Customers=$customerEntries, '
        'Suppliers=$supplierEntries, Stock=$stockEntries',
      );

      return OpeningBalanceResult(
        success: errors.isEmpty,
        cashEntriesCreated: cashEntries,
        bankEntriesCreated: bankEntries,
        customerEntriesCreated: customerEntries,
        supplierEntriesCreated: supplierEntries,
        stockEntriesCreated: stockEntries,
        errors: errors,
      );
    } catch (e) {
      LoggerService.d('OpeningBalance', '[OPENING] Bulk setup failed: $e');
      return OpeningBalanceResult(
        success: false,
        cashEntriesCreated: cashEntries,
        bankEntriesCreated: bankEntries,
        customerEntriesCreated: customerEntries,
        supplierEntriesCreated: supplierEntries,
        stockEntriesCreated: stockEntries,
        errors: [...errors, e.toString()],
      );
    }
  }

  // ============================================================
  // UTILITIES
  // ============================================================

  /// Check if opening balance setup is complete for a user.
  Future<bool> isSetupComplete(String userId) async {
    final response = await _api.get('/opening-balances/status');
    if (!response.isSuccess) return false;
    return response.data?['openingBalanceSetupComplete'] == true;
  }

  /// Get opening balance setup date for a user.
  Future<DateTime?> getSetupDate(String userId) async {
    final response = await _api.get('/opening-balances/status');
    if (!response.isSuccess) return null;
    final dateStr = response.data?['openingBalanceDate'] as String?;
    if (dateStr == null) return null;
    return DateTime.tryParse(dateStr);
  }

  /// Clear all opening balances (for testing/reset).
  ///
  /// WARNING: This is destructive!
  Future<void> clearAllOpeningBalances(String userId) async {
    final response = await _api.delete('/opening-balances');
    if (!response.isSuccess) {
      throw Exception('Failed to clear opening balances: ${response.error}');
    }
    LoggerService.d('OpeningBalance', '[OPENING] All opening balances cleared for $userId');
  }
}
