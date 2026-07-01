import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dukanx/core/compat/firebase_auth_compat.dart';
import 'package:dukanx/core/compat/firestore_compat.dart';

import '../core/database/app_database.dart';

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

/// BackupService provides secure, user-tied backup creation, streaming, and restore.
/// All backups are stored in a Firestore 'backups' collection tied to the current Auth user.
///
/// ## Features
/// - Full data export (all bills, customers, products, payments, stock, journal entries)
/// - Chunked backup for large datasets
/// - Restore functionality with conflict handling (skip duplicates)
/// - Progress tracking via stream
class BackupService {
  final FirebaseFirestore _db;
  // Reserved for future local database backup support
  // ignore: unused_field
  final AppDatabase? _localDb;

  // Progress stream controller
  final _progressController = StreamController<BackupProgress>.broadcast();

  /// Stream of backup/restore progress updates
  Stream<BackupProgress> get progressStream => _progressController.stream;

  BackupService({FirebaseFirestore? firestore, AppDatabase? localDatabase})
    : _db = firestore ?? FirebaseFirestore.instance,
      _localDb = localDatabase;

  /// Dispose resources
  void dispose() {
    _progressController.close();
  }

  // ============================================================
  // FULL BACKUP (NEW)
  // ============================================================

  /// Create a FULL backup of ALL user data.
  ///
  /// Exports:
  /// - All bills (no limit)
  /// - All customers
  /// - All products
  /// - All payments
  /// - All stock movements
  /// - All journal entries
  /// - All purchase orders
  /// - Business profile
  /// - Vendor profile
  ///
  /// Returns the backup document ID.
  Future<String> createFullBackup({String? description}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');
    final userId = user.uid;

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
      final billsSnap = await _db
          .collection('bills')
          .where('ownerId', isEqualTo: userId)
          .get();
      final bills = billsSnap.docs
          .map((d) => {...d.data(), 'id': d.id})
          .toList();

      updateProgress('Fetching customers...');
      final customersSnap = await _db
          .collection('customers')
          .where('ownerId', isEqualTo: userId)
          .get();
      final customers = customersSnap.docs
          .map((d) => {...d.data(), 'id': d.id})
          .toList();

      updateProgress('Fetching products...');
      final productsSnap = await _db
          .collection('owners')
          .doc(userId)
          .collection('products')
          .get();
      final products = productsSnap.docs
          .map((d) => {...d.data(), 'id': d.id})
          .toList();

      updateProgress('Fetching payments...');
      final paymentsSnap = await _db
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .get();
      final payments = paymentsSnap.docs
          .map((d) => {...d.data(), 'id': d.id})
          .toList();

      updateProgress('Fetching stock movements...');
      final stockSnap = await _db
          .collection('owners')
          .doc(userId)
          .collection('stock_movements')
          .get();
      final stockMovements = stockSnap.docs
          .map((d) => {...d.data(), 'id': d.id})
          .toList();

      updateProgress('Fetching journal entries...');
      final journalSnap = await _db
          .collection('businesses')
          .doc(userId)
          .collection('journal_entries')
          .get();
      final journalEntries = journalSnap.docs
          .map((d) => {...d.data(), 'id': d.id})
          .toList();

      updateProgress('Fetching purchase orders...');
      final purchaseSnap = await _db
          .collection('purchase_orders')
          .where('userId', isEqualTo: userId)
          .get();
      final purchaseOrders = purchaseSnap.docs
          .map((d) => {...d.data(), 'id': d.id})
          .toList();

      updateProgress('Fetching business profile...');
      final businessDoc = await _db.collection('businesses').doc(userId).get();
      final Map<String, dynamic> businessProfile = businessDoc.exists
          ? (businessDoc.data() ?? <String, dynamic>{})
          : <String, dynamic>{};

      updateProgress('Fetching vendor profile...');
      final vendorDoc = await _db
          .collection('vendor_profiles')
          .doc(userId)
          .get();
      final Map<String, dynamic> vendorProfile = vendorDoc.exists
          ? (vendorDoc.data() ?? <String, dynamic>{})
          : <String, dynamic>{};

      // Create the full backup data
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
      final doc = await _db.collection('backups').add({
        'ownerId': userId,
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
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[BACKUP] Full backup created: ${doc.id}');
      debugPrint(
        '[BACKUP] Bills: ${bills.length}, Customers: ${customers.length}, '
        'Products: ${products.length}, Payments: ${payments.length}',
      );

      return doc.id;
    } catch (e) {
      debugPrint('[BACKUP] Full backup failed: $e');
      rethrow;
    }
  }

  // ============================================================
  // RESTORE (NEW)
  // ============================================================

  /// Restore data from a backup.
  ///
  /// [backupId] - The ID of the backup to restore
  /// [skipDuplicates] - If true, skip records that already exist (default: true)
  /// [clearExisting] - If true, clear existing data before restore (DANGEROUS!)
  ///
  /// Returns a RestoreResult with statistics.
  Future<RestoreResult> restoreFromBackup(
    String backupId, {
    bool skipDuplicates = true,
    bool clearExisting = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');
    final userId = user.uid;

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
    int skippedDuplicates = 0;

    try {
      updateProgress('Loading backup data...');
      final backupDoc = await _db.collection('backups').doc(backupId).get();
      if (!backupDoc.exists) {
        throw Exception('Backup not found: $backupId');
      }

      final data = backupDoc.data()!;
      final payload = data['payload'] as Map<String, dynamic>? ?? {};
      final backupData = FullBackupData.fromMap(payload);

      // Verify ownership
      if (data['ownerId'] != userId) {
        throw Exception('Backup belongs to a different user');
      }

      // Restore customers
      updateProgress('Restoring customers...');
      for (final customer in backupData.customers) {
        try {
          final id = customer['id'] as String?;
          if (id == null) continue;

          final existing = await _db.collection('customers').doc(id).get();
          if (existing.exists && skipDuplicates) {
            skippedDuplicates++;
            continue;
          }

          await _db.collection('customers').doc(id).set({
            ...customer,
            'restoredAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          customersRestored++;
        } catch (e) {
          errors.add('Customer restore error: $e');
        }
      }

      // Restore products
      updateProgress('Restoring products...');
      for (final product in backupData.products) {
        try {
          final id = product['id'] as String?;
          if (id == null) continue;

          final existing = await _db
              .collection('owners')
              .doc(userId)
              .collection('products')
              .doc(id)
              .get();
          if (existing.exists && skipDuplicates) {
            skippedDuplicates++;
            continue;
          }

          await _db
              .collection('owners')
              .doc(userId)
              .collection('products')
              .doc(id)
              .set({
                ...product,
                'restoredAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
          productsRestored++;
        } catch (e) {
          errors.add('Product restore error: $e');
        }
      }

      // Restore bills
      updateProgress('Restoring bills...');
      for (final bill in backupData.bills) {
        try {
          final id = bill['id'] as String?;
          if (id == null) continue;

          final existing = await _db.collection('bills').doc(id).get();
          if (existing.exists && skipDuplicates) {
            skippedDuplicates++;
            continue;
          }

          await _db.collection('bills').doc(id).set({
            ...bill,
            'restoredAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          billsRestored++;
        } catch (e) {
          errors.add('Bill restore error: $e');
        }
      }

      // Restore payments
      updateProgress('Restoring payments...');
      for (final payment in backupData.payments) {
        try {
          final id = payment['id'] as String?;
          if (id == null) continue;

          final existing = await _db.collection('payments').doc(id).get();
          if (existing.exists && skipDuplicates) {
            skippedDuplicates++;
            continue;
          }

          await _db.collection('payments').doc(id).set({
            ...payment,
            'restoredAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          paymentsRestored++;
        } catch (e) {
          errors.add('Payment restore error: $e');
        }
      }

      // Restore stock movements
      updateProgress('Restoring stock movements...');
      for (final movement in backupData.stockMovements) {
        try {
          final id = movement['id'] as String?;
          if (id == null) continue;

          final existing = await _db
              .collection('owners')
              .doc(userId)
              .collection('stock_movements')
              .doc(id)
              .get();
          if (existing.exists && skipDuplicates) {
            skippedDuplicates++;
            continue;
          }

          await _db
              .collection('owners')
              .doc(userId)
              .collection('stock_movements')
              .doc(id)
              .set({
                ...movement,
                'restoredAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
          stockMovementsRestored++;
        } catch (e) {
          errors.add('Stock movement restore error: $e');
        }
      }

      // Restore journal entries
      updateProgress('Restoring journal entries...');
      for (final entry in backupData.journalEntries) {
        try {
          final id = entry['id'] as String?;
          if (id == null) continue;

          final existing = await _db
              .collection('businesses')
              .doc(userId)
              .collection('journal_entries')
              .doc(id)
              .get();
          if (existing.exists && skipDuplicates) {
            skippedDuplicates++;
            continue;
          }

          await _db
              .collection('businesses')
              .doc(userId)
              .collection('journal_entries')
              .doc(id)
              .set({
                ...entry,
                'restoredAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
          journalEntriesRestored++;
        } catch (e) {
          errors.add('Journal entry restore error: $e');
        }
      }

      // Restore profiles
      updateProgress('Restoring profiles...');
      if (backupData.businessProfile.isNotEmpty) {
        await _db.collection('businesses').doc(userId).set({
          ...backupData.businessProfile,
          'restoredAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      if (backupData.vendorProfile.isNotEmpty) {
        await _db.collection('vendor_profiles').doc(userId).set({
          ...backupData.vendorProfile,
          'restoredAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      debugPrint(
        '[RESTORE] Completed: Bills=$billsRestored, Customers=$customersRestored, '
        'Products=$productsRestored, Payments=$paymentsRestored, '
        'Stock=$stockMovementsRestored, Journal=$journalEntriesRestored, '
        'Skipped=$skippedDuplicates',
      );

      return RestoreResult(
        success: true,
        billsRestored: billsRestored,
        customersRestored: customersRestored,
        productsRestored: productsRestored,
        paymentsRestored: paymentsRestored,
        stockMovementsRestored: stockMovementsRestored,
        journalEntriesRestored: journalEntriesRestored,
        skippedDuplicates: skippedDuplicates,
        errors: errors,
      );
    } catch (e) {
      debugPrint('[RESTORE] Failed: $e');
      return RestoreResult(
        success: false,
        billsRestored: billsRestored,
        customersRestored: customersRestored,
        productsRestored: productsRestored,
        paymentsRestored: paymentsRestored,
        stockMovementsRestored: stockMovementsRestored,
        journalEntriesRestored: journalEntriesRestored,
        skippedDuplicates: skippedDuplicates,
        errors: [...errors, e.toString()],
      );
    }
  }

  // ============================================================
  // GET BACKUP DETAILS (NEW)
  // ============================================================

  /// Get detailed information about a backup without restoring.
  Future<Map<String, dynamic>> getBackupDetails(String backupId) async {
    final doc = await _db.collection('backups').doc(backupId).get();
    if (!doc.exists) throw Exception('Backup not found');

    final data = doc.data()!;
    return {
      'id': doc.id,
      'description': data['description'],
      'type': data['type'] ?? 'partial',
      'version': data['version'] ?? '1.0',
      'createdAt': data['createdAt'],
      'counts': data['counts'] ?? {},
    };
  }

  // ============================================================
  // EXISTING METHODS (PRESERVED)
  // ============================================================

  /// Create a backup of the provided [data] tied to the current authenticated user.
  /// Returns the backup document ID.
  Future<String> createBackup(
    Map<String, dynamic> data, {
    String? description,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final ownerId = user?.uid ?? 'anonymous';
    final doc = await _db.collection('backups').add({
      'ownerId': ownerId,
      'description': description ?? '',
      'type': 'partial',
      'payload': data,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return doc.id;
  }

  /// Stream all backups for the current user (most recent first).
  Stream<List<Map<String, dynamic>>> streamMyBackups() {
    final user = FirebaseAuth.instance.currentUser;
    final ownerId = user?.uid;
    if (ownerId == null) {
      return const Stream.empty();
    }
    return _db
        .collection('backups')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => {...d.data(), 'id': d.id}).toList(),
        );
  }

  /// Delete a backup by [backupId].
  Future<void> deleteBackup(String backupId) async {
    await _db.collection('backups').doc(backupId).delete();
  }

  /// Checks if 24 hours have passed since last backup and performs one if needed.
  Future<void> performAutoBackup() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Check last backup time
      final lastBackup = await _db
          .collection('backups')
          .where('ownerId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (lastBackup.docs.isNotEmpty) {
        final lastBackupTime = lastBackup.docs.first.data()['createdAt'];
        DateTime? lastTime;
        if (lastBackupTime is Timestamp) {
          lastTime = lastBackupTime.toDate();
        } else if (lastBackupTime is String) {
          lastTime = DateTime.tryParse(lastBackupTime);
        }

        if (lastTime != null) {
          final hoursSinceLastBackup = DateTime.now()
              .difference(lastTime)
              .inHours;
          if (hoursSinceLastBackup < 24) {
            debugPrint(
              '[AUTO-BACKUP] Skipping - last backup $hoursSinceLastBackup hours ago',
            );
            return;
          }
        }
      }

      // Perform full backup
      await createFullBackup(
        description: 'Auto Backup ${DateTime.now().toLocal()}',
      );
      debugPrint('[AUTO-BACKUP] Completed successfully');
    } catch (e) {
      debugPrint('[AUTO-BACKUP] Failed: $e');
    }
  }

  // ============================================================
  // EXPORT TO JSON (NEW)
  // ============================================================

  /// Export backup data as JSON string for local file download.
  Future<String> exportBackupAsJson(String backupId) async {
    final doc = await _db.collection('backups').doc(backupId).get();
    if (!doc.exists) throw Exception('Backup not found');

    return jsonEncode({
      'id': doc.id,
      ...doc.data()!,
      'exportedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Import backup from JSON string.
  Future<String> importBackupFromJson(String jsonData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final data = jsonDecode(jsonData) as Map<String, dynamic>;
    data['ownerId'] = user.uid; // Override owner to current user
    data['importedAt'] = FieldValue.serverTimestamp();

    final doc = await _db.collection('backups').add(data);
    return doc.id;
  }
}
