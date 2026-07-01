import 'dart:async';
import 'dart:convert';
import '../../../core/session/session_manager.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/api/api_client.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/logger_service.dart';

/// Backup progress information
class BackupProgress {
  final int totalSteps;
  final int completedSteps;
  final String currentStep;
  final double percentage;

  const BackupProgress({
    required this.totalSteps,
    required this.completedSteps,
    required this.currentStep,
  }) : percentage = totalSteps > 0 ? (completedSteps / totalSteps) * 100 : 0;

  @override
  String toString() =>
      'BackupProgress($completedSteps/$totalSteps - $currentStep)';
}

/// Restore result with statistics
class RestoreResult {
  final bool success;
  final int billsRestored;
  final int customersRestored;
  final int productsRestored;
  final int paymentsRestored;
  final int stockMovementsRestored;
  final int journalEntriesRestored;
  final int skippedDuplicates;
  final List<String> errors;

  const RestoreResult({
    required this.success,
    this.billsRestored = 0,
    this.customersRestored = 0,
    this.productsRestored = 0,
    this.paymentsRestored = 0,
    this.stockMovementsRestored = 0,
    this.journalEntriesRestored = 0,
    this.skippedDuplicates = 0,
    this.errors = const [],
  });

  int get totalRestored =>
      billsRestored +
      customersRestored +
      productsRestored +
      paymentsRestored +
      stockMovementsRestored +
      journalEntriesRestored;

  Map<String, dynamic> toMap() => {
    'success': success,
    'billsRestored': billsRestored,
    'customersRestored': customersRestored,
    'productsRestored': productsRestored,
    'paymentsRestored': paymentsRestored,
    'stockMovementsRestored': stockMovementsRestored,
    'journalEntriesRestored': journalEntriesRestored,
    'skippedDuplicates': skippedDuplicates,
    'totalRestored': totalRestored,
    'errors': errors,
  };
}

/// Full backup data structure
class FullBackupData {
  final String backupId;
  final String userId;
  final DateTime createdAt;
  final String version;
  final List<Map<String, dynamic>> bills;
  final List<Map<String, dynamic>> customers;
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> payments;
  final List<Map<String, dynamic>> stockMovements;
  final List<Map<String, dynamic>> journalEntries;
  final List<Map<String, dynamic>> purchaseOrders;
  final Map<String, dynamic> businessProfile;
  final Map<String, dynamic> vendorProfile;

  const FullBackupData({
    required this.backupId,
    required this.userId,
    required this.createdAt,
    required this.version,
    this.bills = const [],
    this.customers = const [],
    this.products = const [],
    this.payments = const [],
    this.stockMovements = const [],
    this.journalEntries = const [],
    this.purchaseOrders = const [],
    this.businessProfile = const {},
    this.vendorProfile = const {},
  });

  Map<String, dynamic> toMap() => {
    'backupId': backupId,
    'userId': userId,
    'createdAt': createdAt.toIso8601String(),
    'version': version,
    'bills': bills,
    'customers': customers,
    'products': products,
    'payments': payments,
    'stockMovements': stockMovements,
    'journalEntries': journalEntries,
    'purchaseOrders': purchaseOrders,
    'businessProfile': businessProfile,
    'vendorProfile': vendorProfile,
    'counts': {
      'bills': bills.length,
      'customers': customers.length,
      'products': products.length,
      'payments': payments.length,
      'stockMovements': stockMovements.length,
      'journalEntries': journalEntries.length,
      'purchaseOrders': purchaseOrders.length,
    },
  };

  factory FullBackupData.fromMap(Map<String, dynamic> map) {
    return FullBackupData(
      backupId: map['backupId'] ?? '',
      userId: map['userId'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      version: map['version'] ?? '2.0',
      bills: List<Map<String, dynamic>>.from(map['bills'] ?? []),
      customers: List<Map<String, dynamic>>.from(map['customers'] ?? []),
      products: List<Map<String, dynamic>>.from(map['products'] ?? []),
      payments: List<Map<String, dynamic>>.from(map['payments'] ?? []),
      stockMovements: List<Map<String, dynamic>>.from(
        map['stockMovements'] ?? [],
      ),
      journalEntries: List<Map<String, dynamic>>.from(
        map['journalEntries'] ?? [],
      ),
      purchaseOrders: List<Map<String, dynamic>>.from(
        map['purchaseOrders'] ?? [],
      ),
      businessProfile: Map<String, dynamic>.from(map['businessProfile'] ?? {}),
      vendorProfile: Map<String, dynamic>.from(map['vendorProfile'] ?? {}),
    );
  }
}

/// BackupService — All operations via ApiClient ? API Gateway ? DynamoDB
///
/// ## Features
/// - Full data export (bills, customers, products, payments, stock, journal)
/// - Server-side backup/restore via /api/v1/backups
/// - Progress tracking via stream
class BackupService {
  // ignore: unused_field
  final AppDatabase? _localDb;

  final _progressController = StreamController<BackupProgress>.broadcast();
  Stream<BackupProgress> get progressStream => _progressController.stream;

  ApiClient get _api => sl<ApiClient>();

  BackupService({AppDatabase? localDatabase})
    : _localDb = localDatabase;

  void dispose() {
    _progressController.close();
  }

  // ============================================================
  // HELPER: Fetch list from API
  // ============================================================
  Future<List<Map<String, dynamic>>> _fetchList(String endpoint) async {
    final res = await _api.get(endpoint);
    if (res.isSuccess && res.data != null) {
      final items = res.data!['items'];
      if (items is List) {
        return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }
    return [];
  }

  // ============================================================
  // FULL BACKUP
  // ============================================================
  Future<String> createFullBackup({String? description}) async {
    final userId = sl<SessionManager>().userId;
    if (userId == null) throw Exception('User not authenticated');

    const totalSteps = 10;
    var completedSteps = 0;

    void updateProgress(String step) {
      completedSteps++;
      _progressController.add(
        BackupProgress(
          totalSteps: totalSteps,
          completedSteps: completedSteps,
          currentStep: step,
        ),
      );
    }

    try {
      updateProgress('Fetching bills...');
      final bills = await _fetchList('/api/v1/bills');

      updateProgress('Fetching customers...');
      final customers = await _fetchList('/api/v1/customers');

      updateProgress('Fetching products...');
      final products = await _fetchList('/api/v1/products');

      updateProgress('Fetching payments...');
      final payments = await _fetchList('/api/v1/payments');

      updateProgress('Fetching stock movements...');
      final stockMovements = await _fetchList('/api/v1/stock-movements');

      updateProgress('Fetching journal entries...');
      final journalEntries = await _fetchList('/api/v1/journal-entries');

      updateProgress('Fetching purchase orders...');
      // Purchase orders may not have endpoint yet — empty fallback
      final purchaseOrders = <Map<String, dynamic>>[];

      updateProgress('Fetching business profile...');
      Map<String, dynamic> businessProfile = {};
      try {
        final bizRes = await _api.get('/api/v1/businesses');
        if (bizRes.isSuccess && bizRes.data != null) {
          final items = bizRes.data!['items'];
          if (items is List && items.isNotEmpty) {
            businessProfile = Map<String, dynamic>.from(items.first as Map);
          }
        }
      } catch (_) {}

      updateProgress('Fetching vendor profile...');
      Map<String, dynamic> vendorProfile = {};
      try {
        final vpRes = await _api.get('/api/v1/vendor-profiles');
        if (vpRes.isSuccess && vpRes.data != null) {
          final items = vpRes.data!['items'];
          if (items is List && items.isNotEmpty) {
            vendorProfile = Map<String, dynamic>.from(items.first as Map);
          }
        }
      } catch (_) {}

      final backupData = FullBackupData(
        backupId: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        createdAt: DateTime.now(),
        version: '2.0',
        bills: bills,
        customers: customers,
        products: products,
        payments: payments,
        stockMovements: stockMovements,
        journalEntries: journalEntries,
        purchaseOrders: purchaseOrders,
        businessProfile: businessProfile,
        vendorProfile: vendorProfile,
      );

      updateProgress('Saving backup to cloud...');
      final res = await _api.post('/api/v1/backups', body: {
        'description': description ?? 'Full Backup ${DateTime.now().toLocal()}',
        'type': 'full',
        'version': '2.0',
        'payload': backupData.toMap(),
        'counts': {
          'bills': bills.length,
          'customers': customers.length,
          'products': products.length,
          'payments': payments.length,
          'stockMovements': stockMovements.length,
          'journalEntries': journalEntries.length,
          'purchaseOrders': purchaseOrders.length,
        },
      });

      final backupId = res.data?['backup']?['id'] ?? backupData.backupId;
      LoggerService.d('BackupService', '[BACKUP] Full backup created: $backupId');
      LoggerService.d('BackupService', 
        '[BACKUP] Bills: ${bills.length}, Customers: ${customers.length}, '
        'Products: ${products.length}, Payments: ${payments.length}',
      );

      return backupId.toString();
    } catch (e) {
      LoggerService.d('BackupService', '[BACKUP] Full backup failed: $e');
      rethrow;
    }
  }

  // ============================================================
  // RESTORE
  // ============================================================
  Future<RestoreResult> restoreFromBackup(
    String backupId, {
    bool skipDuplicates = true,
    bool clearExisting = false,
  }) async {
    final userId = sl<SessionManager>().userId;
    if (userId == null) throw Exception('User not authenticated');

    const totalSteps = 8;
    var completedSteps = 0;
    final errors = <String>[];

    void updateProgress(String step) {
      completedSteps++;
      _progressController.add(
        BackupProgress(
          totalSteps: totalSteps,
          completedSteps: completedSteps,
          currentStep: step,
        ),
      );
    }

    int billsRestored = 0;
    int customersRestored = 0;
    int productsRestored = 0;
    int paymentsRestored = 0;
    int stockMovementsRestored = 0;
    int journalEntriesRestored = 0;
    int skippedDuplicates_ = 0;

    try {
      updateProgress('Loading backup data...');
      final res = await _api.get('/api/v1/backups/$backupId');
      if (!res.isSuccess || res.data == null) {
        throw Exception('Backup not found: $backupId');
      }

      final data = res.data!['backup'] ?? res.data!;
      final payload = data['payload'] as Map<String, dynamic>? ?? {};
      final backupData = FullBackupData.fromMap(payload);

      // Restore entities via API
      updateProgress('Restoring customers...');
      for (final customer in backupData.customers) {
        try {
          await _api.post('/api/v1/customers', body: customer);
          customersRestored++;
        } catch (e) {
          if (skipDuplicates && e.toString().contains('already exists')) {
            skippedDuplicates_++;
          } else {
            errors.add('Customer restore error: $e');
          }
        }
      }

      updateProgress('Restoring products...');
      for (final product in backupData.products) {
        try {
          await _api.post('/api/v1/products', body: product);
          productsRestored++;
        } catch (e) {
          if (skipDuplicates && e.toString().contains('already exists')) {
            skippedDuplicates_++;
          } else {
            errors.add('Product restore error: $e');
          }
        }
      }

      updateProgress('Restoring bills...');
      for (final bill in backupData.bills) {
        try {
          await _api.post('/api/v1/bills', body: bill);
          billsRestored++;
        } catch (e) {
          if (skipDuplicates && e.toString().contains('already exists')) {
            skippedDuplicates_++;
          } else {
            errors.add('Bill restore error: $e');
          }
        }
      }

      updateProgress('Restoring payments...');
      for (final payment in backupData.payments) {
        try {
          await _api.post('/api/v1/payments', body: payment);
          paymentsRestored++;
        } catch (e) {
          if (skipDuplicates && e.toString().contains('already exists')) {
            skippedDuplicates_++;
          } else {
            errors.add('Payment restore error: $e');
          }
        }
      }

      updateProgress('Restoring stock movements...');
      for (final movement in backupData.stockMovements) {
        try {
          await _api.post('/api/v1/stock-movements', body: movement);
          stockMovementsRestored++;
        } catch (e) {
          if (skipDuplicates && e.toString().contains('already exists')) {
            skippedDuplicates_++;
          } else {
            errors.add('Stock movement restore error: $e');
          }
        }
      }

      updateProgress('Restoring journal entries...');
      for (final entry in backupData.journalEntries) {
        try {
          await _api.post('/api/v1/journal-entries', body: entry);
          journalEntriesRestored++;
        } catch (e) {
          if (skipDuplicates && e.toString().contains('already exists')) {
            skippedDuplicates_++;
          } else {
            errors.add('Journal entry restore error: $e');
          }
        }
      }

      updateProgress('Restoring profiles...');
      if (backupData.businessProfile.isNotEmpty) {
        try {
          await _api.put('/api/v1/businesses/${backupData.businessProfile['id'] ?? userId}',
              body: backupData.businessProfile);
        } catch (_) {}
      }
      if (backupData.vendorProfile.isNotEmpty) {
        try {
          await _api.put('/api/v1/vendor-profiles/${backupData.vendorProfile['id'] ?? userId}',
              body: backupData.vendorProfile);
        } catch (_) {}
      }

      LoggerService.d('BackupService', 
        '[RESTORE] Completed: Bills=$billsRestored, Customers=$customersRestored, '
        'Products=$productsRestored, Payments=$paymentsRestored, '
        'Stock=$stockMovementsRestored, Journal=$journalEntriesRestored, '
        'Skipped=$skippedDuplicates_',
      );

      return RestoreResult(
        success: true,
        billsRestored: billsRestored,
        customersRestored: customersRestored,
        productsRestored: productsRestored,
        paymentsRestored: paymentsRestored,
        stockMovementsRestored: stockMovementsRestored,
        journalEntriesRestored: journalEntriesRestored,
        skippedDuplicates: skippedDuplicates_,
        errors: errors,
      );
    } catch (e) {
      LoggerService.d('BackupService', '[RESTORE] Failed: $e');
      return RestoreResult(
        success: false,
        billsRestored: billsRestored,
        customersRestored: customersRestored,
        productsRestored: productsRestored,
        paymentsRestored: paymentsRestored,
        stockMovementsRestored: stockMovementsRestored,
        journalEntriesRestored: journalEntriesRestored,
        skippedDuplicates: skippedDuplicates_,
        errors: [...errors, e.toString()],
      );
    }
  }

  // ============================================================
  // GET BACKUP DETAILS
  // ============================================================
  Future<Map<String, dynamic>> getBackupDetails(String backupId) async {
    final res = await _api.get('/api/v1/backups/$backupId');
    if (!res.isSuccess || res.data == null) {
      throw Exception('Backup not found');
    }
    final data = res.data!['backup'] ?? res.data!;
    return {
      'id': backupId,
      'description': data['description'],
      'type': data['type'] ?? 'partial',
      'version': data['version'] ?? '1.0',
      'createdAt': data['createdAt'] ?? data['created_at'],
      'counts': data['counts'] ?? {},
    };
  }

  // ============================================================
  // SIMPLE BACKUP
  // ============================================================
  Future<String> createBackup(
    Map<String, dynamic> data, {
    String? description,
  }) async {
    final res = await _api.post('/api/v1/backups', body: {
      'description': description ?? '',
      'type': 'partial',
      'payload': data,
    });
    return res.data?['backup']?['id']?.toString() ?? '';
  }

  /// Stream all backups for current user.
  /// Returns single snapshot (polling not real-time).
  Stream<List<Map<String, dynamic>>> streamMyBackups() {
    return Stream.fromFuture(_fetchBackupList());
  }

  Future<List<Map<String, dynamic>>> _fetchBackupList() async {
    final items = await _fetchList('/api/v1/backups');
    return items;
  }

  Future<void> deleteBackup(String backupId) async {
    await _api.delete('/api/v1/backups/$backupId');
  }

  /// Auto backup if 24 hours since last
  Future<void> performAutoBackup() async {
    try {
      final userId = sl<SessionManager>().userId;
      if (userId == null) return;

      final backups = await _fetchBackupList();
      if (backups.isNotEmpty) {
        final lastTime = backups.first['createdAt'] ?? backups.first['created_at'];
        if (lastTime != null) {
          DateTime? parsed;
          if (lastTime is String) parsed = DateTime.tryParse(lastTime);
          if (parsed != null) {
            final hoursSince = DateTime.now().difference(parsed).inHours;
            if (hoursSince < 24) {
              LoggerService.d('BackupService', '[AUTO-BACKUP] Skipping - last backup $hoursSince hours ago');
              return;
            }
          }
        }
      }

      await createFullBackup(
        description: 'Auto Backup ${DateTime.now().toLocal()}',
      );
      LoggerService.d('BackupService', '[AUTO-BACKUP] Completed successfully');
    } catch (e) {
      LoggerService.d('BackupService', '[AUTO-BACKUP] Failed: $e');
    }
  }

  // ============================================================
  // EXPORT/IMPORT JSON
  // ============================================================
  Future<String> exportBackupAsJson(String backupId) async {
    final res = await _api.get('/api/v1/backups/$backupId');
    if (!res.isSuccess || res.data == null) throw Exception('Backup not found');

    return jsonEncode({
      'id': backupId,
      ...res.data!,
      'exportedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<String> importBackupFromJson(String jsonData) async {
    final data = jsonDecode(jsonData) as Map<String, dynamic>;

    final res = await _api.post('/api/v1/backups', body: {
      ...data,
      'type': data['type'] ?? 'imported',
    });
    return res.data?['backup']?['id']?.toString() ?? '';
  }
}
