import 'dart:async';
import 'dart:convert'; // Added for jsonEncode
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Added
import 'package:drift/drift.dart';
import '../../api/sync_api_client.dart';
import '../data/drift_sync_repository.dart';
import '../models/sync_payloads.dart';
import '../../database/app_database.dart';

class RestSyncEngine {
  static RestSyncEngine? _instance;
  static RestSyncEngine get instance => _instance ??= RestSyncEngine._();

  final StreamController<bool> _licenseInvalidController = StreamController<bool>.broadcast();
  Stream<bool> get onLicenseInvalidated => _licenseInvalidController.stream;

  /// Trigger license invalidation manually
  void invalidateLicense() {
    _licenseInvalidController.add(true);
  }

  RestSyncEngine._();

  late final DriftSyncRepository _repo;
  late final SyncApiClient _api;
  late final AppDatabase _db;

  bool _isInitialized = false;
  bool _isProcessing = false;

  // ignore: unused_field
  Timer? _pullTimer;

  void initialize({
    required DriftSyncRepository repository,
    required SyncApiClient apiClient,
    required AppDatabase db,
  }) {
    if (_isInitialized) return;
    _repo = repository;
    _api = apiClient;
    _db = db;
    _isInitialized = true;

    // Start periodic pull (every 5 minutes)
    _pullTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => triggerPull(),
    );

    debugPrint('RestSyncEngine: Initialized');
  }

  /// Trigger Push and Pull
  Future<void> triggerSync() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      await _push();
      await _pull();
    } catch (e) {
      debugPrint('RestSyncEngine: Sync Error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> triggerPull() async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      await _pull();
    } catch (e) {
      debugPrint('RestSyncEngine: Pull Error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _push() async {
    final pendingItems = await _repo.getPendingItems();
    if (pendingItems.isEmpty) return;

    // Group by Business/User ID (Assuming single user for now, but structure supports multi)
    final businessId = pendingItems.first.userId;

    final pushReq = PushRequest(businessId: businessId);
    final processedIds = <String>[];

    for (final item in pendingItems) {
      // Mark IN PROGRESS
      // await _repo.markInProgress(item.operationId); // Batch this later if optimization needed

      try {
        if (item.targetCollection == 'customers') {
          pushReq.customers.add(CustomerSync.fromJson(item.payload));
        } else if (item.targetCollection == 'products') {
          pushReq.products.add(ProductSync.fromJson(item.payload));
        } else if (item.targetCollection == 'bills') {
          pushReq.bills.add(BillSync.fromJson(item.payload));
        }
        processedIds.add(item.operationId);
      } catch (e) {
        debugPrint(
          'RestSyncEngine: Payload Conversion Error for ${item.operationId}: $e',
        );
        await _repo.markFailed(
          item.operationId,
          e.toString(),
          item.retryCount + 1,
        );
      }
    }

    if (processedIds.isEmpty) return;

    try {
      await _api.pushChanges(pushReq);

      // On Success, mark all as SYNCED
      for (final opId in processedIds) {
        // Need to know collection and docId to mark entity synced
        // We can look up from pendingItems
        final item = pendingItems.firstWhere((e) => e.operationId == opId);
        await _repo.markSynced(
          opId,
          collection: item.targetCollection,
          docId: item.documentId,
        );
      }
      debugPrint(
        'RestSyncEngine: Pushed ${processedIds.length} items successfully',
      );
    } catch (e) {
      debugPrint('RestSyncEngine: API Push Failed: $e');
      // Mark all batch as RETRY
      for (final opId in processedIds) {
        final item = pendingItems.firstWhere((e) => e.operationId == opId);
        await _repo.markFailed(opId, e.toString(), item.retryCount + 1);
      }
    }
  }

  Future<void> _pull() async {
    // Determine last sync timestamp
    final prefs = await SharedPreferences.getInstance();
    final lastSyncMillis = prefs.getInt('last_sync_timestamp') ?? 0;
    final lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSyncMillis);

    const businessId = 'default_business'; // Default until Auth is ready

    final pullReq = PullRequest(
      businessId: businessId,
      lastSyncTimestamp: lastSyncTime,
    );

    try {
      final response = await _api.pullChanges(pullReq);

      // Upsert Customers
      for (final cust in response.customers) {
        await _db.insertCustomer(
          CustomersCompanion.insert(
            id: cust.id,
            userId: businessId,
            name: cust.name,
            phone: Value(cust.phone),
            email: Value(cust.email),
            updatedAt: cust.updatedAt,
            createdAt: cust.updatedAt, // If new
            isSynced: const Value(true), // coming from server, so it is synced
          ),
        );
      }

      // Upsert Products
      for (final prod in response.products) {
        await _db.insertProduct(
          ProductsCompanion.insert(
            id: prod.id,
            userId: businessId,
            name: prod.name,
            sellingPrice: prod.price,
            sku: Value(prod.sku),
            stockQuantity: Value(prod.stockQty ?? 0),
            updatedAt: prod.updatedAt,
            createdAt: prod.updatedAt,
            isSynced: const Value(true),
          ),
        );
      }

      // Upsert Bills
      for (final bill in response.bills) {
        // Bill Logic
        await _db.insertBill(
          BillsCompanion.insert(
            id: bill.id,
            userId: businessId,
            invoiceNumber: bill.invoiceNumber,
            billDate: bill.billDate,
            grandTotal: Value(bill.totalAmount),
            itemsJson: jsonEncode(bill.items.map((e) => e.toJson()).toList()),
            updatedAt: bill.updatedAt,
            createdAt: bill.updatedAt,
            isSynced: const Value(true),
          ),
        );
      }

      // Update Checkpoint
      // save(response.serverTimestamp);

      debugPrint('RestSyncEngine: Pulled changes successfully');
    } catch (e) {
      debugPrint('RestSyncEngine: Pull Failed: $e');
    }
  }
}
