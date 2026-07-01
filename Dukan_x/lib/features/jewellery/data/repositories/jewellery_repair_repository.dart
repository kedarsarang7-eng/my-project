// Jewellery Repair Repository - Full CRUD with Offline Support
// Feature 3: Repair/Service Module
//
// Offline-first parity: VERIFIED (Phase 5, Task 10.2)
// Hive boxes: jewellery_repairs, repair_sync_queue
// Pattern: initialize() → Hive boxes, _addToSyncQueue(), _syncRepair(), syncAll()
// Matches jewellery_repository_offline.dart offline-first architecture.

import 'dart:async';
import 'package:hive/hive.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/sync/version_reconciliation.dart';
import '../../../../core/utils/rid_generator.dart';
import '../models/jewellery_repair_model.dart';

/// Repository for managing jewellery repair jobs
class JewelleryRepairRepository {
  final ApiClient _client;
  final SessionManager _session;

  late Box<JewelleryRepair> _repairsBox;
  late Box<Map> _syncQueueBox;

  bool _initialized = false;

  JewelleryRepairRepository(this._client, this._session);

  Future<void> initialize() async {
    if (_initialized) return;

    _repairsBox = await Hive.openBox<JewelleryRepair>('jewellery_repairs');
    _syncQueueBox = await Hive.openBox<Map>('repair_sync_queue');

    _initialized = true;
  }

  // ============================================================================
  // CRUD OPERATIONS
  // ============================================================================

  /// Create new repair job
  Future<JewelleryRepair> createRepair(CreateRepairRequest request) async {
    await initialize();

    final now = DateTime.now();
    final tenantId = _session.ownerId ?? 'default';
    final userId = _session.userId ?? 'unknown';
    final id = RidGenerator.next(tenantId);

    // Generate job number (e.g., JOB-2024-0001)
    final year = now.year;
    final count = _repairsBox.values.length + 1;
    final jobNumber = 'JOB-$year-${count.toString().padLeft(4, '0')}';

    final repair = JewelleryRepair(
      id: id,
      tenantId: tenantId,
      jobNumber: jobNumber,
      customerId: request.customerId,
      customerName: request.customerName,
      customerPhone: request.customerPhone,
      itemDescription: request.itemDescription,
      itemCategory: request.itemCategory,
      metalType: request.metalType,
      weightGrams: request.weightGrams,
      productId: request.productId,
      workItems: request.workItems,
      status: RepairStatus.pending,
      priority: request.priority,
      statusHistory: [
        RepairStatusUpdate(
          status: RepairStatus.pending,
          timestamp: now,
          updatedBy: userId,
          notes: 'Job created',
        ),
      ],
      conditionPhotoUrls: request.conditionPhotoUrls,
      customerComplaint: request.customerComplaint,
      estimatedCostPaisa: request.estimatedCostPaisa,
      estimatedDays: request.estimatedDays,
      estimatedCompletionDate: request.promisedDate,
      promisedDate: request.promisedDate,
      receivedDate: now,
      createdAt: now,
      createdBy: userId,
      updatedAt: now,
      updatedBy: userId,
      synced: false,
      pendingOperation: 'create',
    );

    await _repairsBox.put(id, repair);
    await _addToSyncQueue('create', id);

    _syncRepair(repair);

    return repair;
  }

  /// Get all repair jobs
  Future<List<JewelleryRepair>> getRepairs({
    RepairStatus? status,
    RepairPriority? priority,
    String? customerId,
    String? assignedTo,
    bool? isOverdue,
    DateTime? fromDate,
    DateTime? toDate,
    bool includeCompleted = true,
  }) async {
    await initialize();

    final tenantId = _session.ownerId;

    var repairs = _repairsBox.values.where((r) {
      if (r.tenantId != tenantId) return false;

      if (status != null && r.status != status) return false;
      if (priority != null && r.priority != priority) return false;
      if (customerId != null && r.customerId != customerId) return false;
      if (assignedTo != null && r.assignedTo != assignedTo) return false;
      if (isOverdue != null && r.isOverdue != isOverdue) return false;

      if (!includeCompleted && r.status.isCompleted) return false;

      if (fromDate != null && r.receivedDate.isBefore(fromDate)) return false;
      if (toDate != null && r.receivedDate.isAfter(toDate)) return false;

      return true;
    }).toList();

    // Sort by priority and date
    repairs.sort((a, b) {
      // First by priority (urgent first)
      final priorityCompare = b.priority.index.compareTo(a.priority.index);
      if (priorityCompare != 0) return priorityCompare;

      // Then by received date (newest first)
      return b.receivedDate.compareTo(a.receivedDate);
    });

    return repairs;
  }

  /// Get pending and in-progress jobs
  Future<List<JewelleryRepair>> getActiveJobs() async {
    final all = await getRepairs(includeCompleted: false);
    return all.where((r) => !r.status.isCompleted).toList();
  }

  /// Get overdue jobs
  Future<List<JewelleryRepair>> getOverdueJobs() async {
    return getRepairs(isOverdue: true, includeCompleted: false);
  }

  /// Get single repair by ID
  Future<JewelleryRepair?> getRepairById(String id) async {
    await initialize();
    return _repairsBox.get(id);
  }

  /// Get repair by job number
  Future<JewelleryRepair?> getRepairByJobNumber(String jobNumber) async {
    await initialize();

    try {
      return _repairsBox.values.firstWhere((r) => r.jobNumber == jobNumber);
    } catch (e) {
      return null;
    }
  }

  /// Update repair job
  Future<JewelleryRepair> updateRepair(
    String id,
    UpdateRepairRequest request,
  ) async {
    await initialize();

    final existing = _repairsBox.get(id);
    if (existing == null) {
      throw Exception('Repair job not found: $id');
    }

    final now = DateTime.now();
    final userId = _session.userId ?? 'unknown';

    // Build update data
    final updated = existing.copyWith(
      workItems: request.workItems ?? existing.workItems,
      status: request.status ?? existing.status,
      priority: request.priority ?? existing.priority,
      assignedTo: request.assignedTo ?? existing.assignedTo,
      assignedToName: request.assignedToName ?? existing.assignedToName,
      damageAssessment: request.damageAssessment ?? existing.damageAssessment,
      recommendedWork: request.recommendedWork ?? existing.recommendedWork,
      estimatedCostPaisa:
          request.estimatedCostPaisa ?? existing.estimatedCostPaisa,
      estimatedDays: request.estimatedDays ?? existing.estimatedDays,
      promisedDate: request.promisedDate ?? existing.promisedDate,
      actualCostPaisa: request.actualCostPaisa ?? existing.actualCostPaisa,
      materialCostPaisa:
          request.materialCostPaisa ?? existing.materialCostPaisa,
      laborCostPaisa: request.laborCostPaisa ?? existing.laborCostPaisa,
      additionalChargesPaisa:
          request.additionalChargesPaisa ?? existing.additionalChargesPaisa,
      additionalChargesNote:
          request.additionalChargesNote ?? existing.additionalChargesNote,
      advanceReceivedPaisa:
          request.advanceReceivedPaisa ?? existing.advanceReceivedPaisa,
      warrantyDays: request.warrantyDays ?? existing.warrantyDays,
      customerRating: request.customerRating ?? existing.customerRating,
      customerFeedback: request.customerFeedback ?? existing.customerFeedback,
      updatedAt: now,
      updatedBy: userId,
      synced: false,
    );

    await _repairsBox.put(id, updated);
    await _addToSyncQueue('update', id);

    _syncRepair(updated);

    return updated;
  }

  /// Update repair status with history
  Future<JewelleryRepair> updateStatus(
    String id,
    RepairStatus newStatus, {
    String? notes,
    List<String>? photos,
  }) async {
    await initialize();

    final existing = _repairsBox.get(id);
    if (existing == null) {
      throw Exception('Repair job not found: $id');
    }

    final now = DateTime.now();
    final userId = _session.userId ?? 'unknown';

    // Add status update to history
    final statusUpdate = RepairStatusUpdate(
      status: newStatus,
      timestamp: now,
      updatedBy: userId,
      notes: notes,
      photoUrls: photos,
    );

    // Update fields based on status
    DateTime? workStartedDate = existing.workStartedDate;
    DateTime? workCompletedDate = existing.workCompletedDate;
    DateTime? completedDate = existing.completedDate;
    DateTime? deliveredDate = existing.deliveredDate;
    DateTime? warrantyExpiryDate = existing.warrantyExpiryDate;

    if (newStatus == RepairStatus.inProgress && workStartedDate == null) {
      workStartedDate = now;
    }
    if (newStatus == RepairStatus.ready && workCompletedDate == null) {
      workCompletedDate = now;
      completedDate = now;
    }
    if (newStatus == RepairStatus.delivered) {
      deliveredDate = now;
      // Set warranty expiry
      if (existing.warrantyDays > 0) {
        warrantyExpiryDate = now.add(Duration(days: existing.warrantyDays));
      }
    }

    final updatedHistory = [...?existing.statusHistory, statusUpdate];

    final updated = existing.copyWith(
      status: newStatus,
      statusHistory: updatedHistory,
      workStartedDate: workStartedDate,
      workCompletedDate: workCompletedDate,
      completedDate: completedDate,
      deliveredDate: deliveredDate,
      warrantyExpiryDate: warrantyExpiryDate,
      updatedAt: now,
      updatedBy: userId,
      synced: false,
    );

    await _repairsBox.put(id, updated);
    await _addToSyncQueue('update', id);

    _syncRepair(updated);

    return updated;
  }

  /// Assign repair to craftsman
  Future<JewelleryRepair> assignRepair(
    String id,
    String assignedTo,
    String assignedToName,
  ) async {
    return updateRepair(
      id,
      UpdateRepairRequest(
        assignedTo: assignedTo,
        assignedToName: assignedToName,
      ),
    );
  }

  /// Add work item to repair
  Future<JewelleryRepair> addWorkItem(
    String id,
    RepairWorkItem workItem,
  ) async {
    await initialize();

    final existing = _repairsBox.get(id);
    if (existing == null) {
      throw Exception('Repair job not found: $id');
    }

    final updatedWorkItems = [...existing.workItems, workItem];

    return updateRepair(id, UpdateRepairRequest(workItems: updatedWorkItems));
  }

  /// Complete work item
  Future<JewelleryRepair> completeWorkItem(
    String repairId,
    String workItemId, {
    required String completedBy,
    int? actualCostPaisa,
  }) async {
    await initialize();

    final existing = _repairsBox.get(repairId);
    if (existing == null) {
      throw Exception('Repair job not found: $repairId');
    }

    final now = DateTime.now();

    final updatedWorkItems = existing.workItems.map((item) {
      if (item.id == workItemId) {
        return item.copyWith(
          isCompleted: true,
          completedBy: completedBy,
          completedAt: now,
          actualCostPaisa: actualCostPaisa ?? item.actualCostPaisa,
        );
      }
      return item;
    }).toList();

    return updateRepair(
      repairId,
      UpdateRepairRequest(workItems: updatedWorkItems),
    );
  }

  /// Receive advance payment
  Future<JewelleryRepair> receiveAdvance(
    String id,
    int amountPaisa, {
    String? paymentMode,
  }) async {
    await initialize();

    final existing = _repairsBox.get(id);
    if (existing == null) {
      throw Exception('Repair job not found: $id');
    }

    final newAdvance = existing.advanceReceivedPaisa + amountPaisa;

    return updateRepair(
      id,
      UpdateRepairRequest(advanceReceivedPaisa: newAdvance),
    );
  }

  /// Mark as paid
  Future<JewelleryRepair> markAsPaid(String id, String invoiceId) async {
    await initialize();

    final existing = _repairsBox.get(id);
    if (existing == null) {
      throw Exception('Repair job not found: $id');
    }

    final now = DateTime.now();

    final updated = existing.copyWith(
      invoiceId: invoiceId,
      isPaid: true,
      updatedAt: now,
      updatedBy: _session.userId ?? 'unknown',
      synced: false,
    );

    await _repairsBox.put(id, updated);
    await _addToSyncQueue('update', id);

    _syncRepair(updated);

    return updated;
  }

  /// Create warranty claim (re-repair)
  Future<JewelleryRepair> createWarrantyClaim(
    String originalJobId,
    List<RepairWorkItem> workItems,
    String? complaint,
  ) async {
    await initialize();

    final original = await getRepairById(originalJobId);
    if (original == null) {
      throw Exception('Original job not found: $originalJobId');
    }

    final createRequest = CreateRepairRequest(
      customerId: original.customerId,
      customerName: original.customerName,
      customerPhone: original.customerPhone,
      itemDescription: original.itemDescription,
      itemCategory: original.itemCategory,
      metalType: original.metalType,
      weightGrams: original.weightGrams,
      productId: original.productId,
      workItems: workItems,
      customerComplaint: complaint ?? 'Warranty claim',
      priority: RepairPriority.high,
    );

    final newJob = await createRepair(createRequest);

    // Mark as warranty claim
    final updated = newJob.copyWith(
      originalJobId: originalJobId,
      isWarrantyClaim: true,
      synced: false,
    );

    await _repairsBox.put(newJob.id, updated);
    await _addToSyncQueue('update', newJob.id);

    _syncRepair(updated);

    return updated;
  }

  /// Delete repair (soft delete)
  Future<void> deleteRepair(String id) async {
    await initialize();

    final existing = _repairsBox.get(id);
    if (existing == null) return;

    final updated = existing.copyWith(
      status: RepairStatus.cancelled,
      updatedAt: DateTime.now(),
      updatedBy: _session.userId ?? 'unknown',
      synced: false,
    );

    await _repairsBox.put(id, updated);
    await _addToSyncQueue('update', id);

    _syncRepair(updated);
  }

  // ============================================================================
  // STATISTICS
  // ============================================================================

  Future<RepairStatistics> getStatistics({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    await initialize();

    final repairs = await getRepairs(
      fromDate: fromDate,
      toDate: toDate,
      includeCompleted: true,
    );

    int totalJobs = repairs.length;
    int pendingJobs = repairs
        .where((r) => r.status == RepairStatus.pending)
        .length;
    int inProgressJobs = repairs
        .where((r) => r.status == RepairStatus.inProgress)
        .length;
    int completedJobs = repairs
        .where((r) => r.status == RepairStatus.ready)
        .length;
    int deliveredJobs = repairs
        .where((r) => r.status == RepairStatus.delivered)
        .length;
    int overdueJobs = repairs.where((r) => r.isOverdue).length;
    int warrantyClaims = repairs.where((r) => r.isWarrantyClaim).length;

    // Calculate averages
    double totalDays = 0;
    int completedCount = 0;
    int totalRevenue = 0;
    int totalMaterialCost = 0;
    int totalLaborCost = 0;

    for (final repair in repairs) {
      if (repair.deliveredDate != null) {
        final days = repair.deliveredDate!
            .difference(repair.receivedDate)
            .inDays;
        totalDays += days;
        completedCount++;
      }

      if (repair.actualCostPaisa != null) {
        totalRevenue += repair.actualCostPaisa!;
      }
      if (repair.materialCostPaisa != null) {
        totalMaterialCost += repair.materialCostPaisa!;
      }
      if (repair.laborCostPaisa != null) {
        totalLaborCost += repair.laborCostPaisa!;
      }
    }

    double averageRepairDays = completedCount > 0
        ? totalDays / completedCount
        : 0;

    return RepairStatistics(
      totalJobs: totalJobs,
      pendingJobs: pendingJobs,
      inProgressJobs: inProgressJobs,
      completedJobs: completedJobs,
      deliveredJobs: deliveredJobs,
      overdueJobs: overdueJobs,
      warrantyClaims: warrantyClaims,
      averageRepairDays: averageRepairDays,
      totalRevenuePaisa: totalRevenue,
      totalMaterialCostPaisa: totalMaterialCost,
      totalLaborCostPaisa: totalLaborCost,
    );
  }

  // ============================================================================
  // SYNC
  // ============================================================================

  /// Enqueue a sync-queue entry for a local write (Requirement 14.3).
  ///
  /// **Optimistic local write + enqueue contract:**
  /// Every create/update/delete in this repository follows the same pattern:
  ///   1. Persist the change to the local Hive box immediately (optimistic).
  ///   2. Call [_addToSyncQueue] to enqueue a corresponding sync-queue entry.
  ///   3. Fire-and-forget call to [_syncRepair] (non-blocking).
  Future<void> _addToSyncQueue(String operation, String entityId) async {
    final tenantId = _session.ownerId ?? 'default';
    final id = RidGenerator.next(tenantId);
    await _syncQueueBox.put(id, {
      'id': id,
      'entityType': 'jewellery_repair',
      'operation': operation,
      'entityId': entityId,
      'timestamp': DateTime.now().toIso8601String(),
      'retryCount': 0,
    });
  }

  Future<void> _syncRepair(JewelleryRepair repair) async {
    try {
      final data = {
        'id': repair.id,
        'tenantId': repair.tenantId,
        'jobNumber': repair.jobNumber,
        'customerId': repair.customerId,
        'customerName': repair.customerName,
        'customerPhone': repair.customerPhone,
        'itemDescription': repair.itemDescription,
        'itemCategory': repair.itemCategory,
        'metalType': repair.metalType,
        'weightGrams': repair.weightGrams,
        'productId': repair.productId,
        'workItems': repair.workItems.map((w) => w.toJson()).toList(),
        'status': repair.status.name,
        'priority': repair.priority.name,
        'customerComplaint': repair.customerComplaint,
        'estimatedCostPaisa': repair.estimatedCostPaisa,
        'estimatedDays': repair.estimatedDays,
        'promisedDate': repair.promisedDate?.toIso8601String(),
        'actualCostPaisa': repair.actualCostPaisa,
        'materialCostPaisa': repair.materialCostPaisa,
        'laborCostPaisa': repair.laborCostPaisa,
        'advanceReceivedPaisa': repair.advanceReceivedPaisa,
        'assignedTo': repair.assignedTo,
        'receivedDate': repair.receivedDate.toIso8601String(),
        'deliveredDate': repair.deliveredDate?.toIso8601String(),
        'isPaid': repair.isPaid,
        'invoiceId': repair.invoiceId,
        'createdAt': repair.createdAt.toIso8601String(),
        'updatedAt': repair.updatedAt.toIso8601String(),
      };

      Map<String, dynamic>? responseData;

      if (repair.pendingOperation == 'create') {
        final response = await _client.post('/jewellery/repairs', body: data);
        responseData = response.data as Map<String, dynamic>?;
      } else if (repair.pendingOperation == 'update') {
        final response = await _client.put(
          '/jewellery/repairs/${repair.id}',
          body: data,
        );
        responseData = response.data as Map<String, dynamic>?;
      }

      // Version-based reconciliation (Requirement 14.4)
      final serverVersion = VersionReconciliation.extractServerVersion(
        responseData,
      );
      final reconciliation = VersionReconciliation.reconcile(
        localVersion:
            0, // JewelleryRepair has no version field — use 0 baseline
        serverVersion: serverVersion,
        serverData: responseData,
      );

      if (reconciliation.shouldUpdateLocal &&
          reconciliation.serverData != null) {
        // Server has newer data — update local repair record
        final serverData = reconciliation.serverData!;
        final reconciled = repair.copyWith(
          status:
              _parseRepairStatus(serverData['status'] as String?) ??
              repair.status,
          actualCostPaisa:
              serverData['actualCostPaisa'] as int? ?? repair.actualCostPaisa,
          synced: true,
          lastSyncedAt: DateTime.now(),
          pendingOperation: null,
        );
        await _repairsBox.put(repair.id, reconciled);
      } else {
        final synced = repair.copyWith(
          synced: true,
          lastSyncedAt: DateTime.now(),
          pendingOperation: null,
        );
        await _repairsBox.put(repair.id, synced);
      }
    } catch (e) {
      print('[JewelleryRepairRepository] Sync failed: $e');
    }
  }

  /// Parse repair status string to enum, returns null if unrecognized.
  RepairStatus? _parseRepairStatus(String? status) {
    if (status == null) return null;
    try {
      return RepairStatus.values.firstWhere((s) => s.name == status);
    } catch (_) {
      return null;
    }
  }

  /// Sync all pending repairs
  Future<void> syncAll() async {
    await initialize();

    final pending = _repairsBox.values.where((r) => !r.synced).toList();

    for (final repair in pending) {
      await _syncRepair(repair);
    }
  }
}
