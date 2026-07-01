/// Service Job Repository
/// Handles CRUD operations for service/repair job cards
library;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:dukanx/core/database/app_database.dart';
import '../../models/service_job.dart';

/// Repository for Service Job CRUD operations
class ServiceJobRepository {
  final AppDatabase _db;

  ServiceJobRepository(this._db);

  /// Generate next job number for a user
  Future<String> generateJobNumber(String userId) async {
    final today = DateTime.now();
    final prefix = 'SRV';
    final datePrefix =
        '${today.year.toString().substring(2)}${today.month.toString().padLeft(2, '0')}';

    // Count existing jobs this month
    final count =
        await (_db.selectOnly(_db.serviceJobs)
              ..addColumns([_db.serviceJobs.id.count()])
              ..where(
                _db.serviceJobs.userId.equals(userId) &
                    _db.serviceJobs.createdAt.isBiggerOrEqualValue(
                      DateTime(today.year, today.month, 1),
                    ),
              ))
            .map((row) => row.read(_db.serviceJobs.id.count()) ?? 0)
            .getSingle();

    final nextNumber = (count + 1).toString().padLeft(4, '0');
    return '$prefix-$datePrefix-$nextNumber';
  }

  /// Create a new service job
  Future<String> createServiceJob(ServiceJob job) async {
    final id = job.id.isEmpty ? const Uuid().v4() : job.id;
    final now = DateTime.now();

    await _db
        .into(_db.serviceJobs)
        .insert(
          ServiceJobsCompanion.insert(
            id: id,
            userId: job.userId,
            jobNumber: job.jobNumber,
            customerId: Value(job.customerId),
            customerName: job.customerName,
            customerPhone: job.customerPhone,
            customerEmail: Value(job.customerEmail),
            customerAddress: Value(job.customerAddress),
            deviceType: job.deviceType.value,
            brand: job.brand,
            model: job.model,
            imeiOrSerial: Value(job.imeiOrSerial),
            color: Value(job.color),
            accessories: Value(
              job.accessories.isNotEmpty ? job.accessories.join(', ') : null,
            ),
            deviceConditionNotes: Value(job.deviceConditionNotes),
            devicePhotosJson: Value(
              job.devicePhotos.isNotEmpty ? job.devicePhotos.join(',') : null,
            ),
            problemDescription: job.problemDescription,
            symptomsJson: Value(
              job.symptoms.isNotEmpty ? job.symptoms.join(', ') : null,
            ),
            isUnderWarranty: Value(job.isUnderWarranty),
            originalBillId: Value(job.originalBillId),
            imeiSerialId: Value(job.imeiSerialId),
            status: Value(job.status.value),
            priority: Value(job.priority.value),
            assignedTechnicianId: Value(job.assignedTechnicianId),
            assignedTechnicianName: Value(job.assignedTechnicianName),
            diagnosis: Value(job.diagnosis),
            estimatedLaborCost: Value(job.estimatedLaborCost),
            estimatedPartsCost: Value(job.estimatedPartsCost),
            estimatedTotal: Value(job.estimatedTotal),
            customerApproved: Value(job.customerApproved),
            approvedAt: Value(job.approvedAt),
            actualLaborCost: Value(job.actualLaborCost),
            actualPartsCost: Value(job.actualPartsCost),
            discountAmount: Value(job.discountAmount),
            taxAmount: Value(job.taxAmount),
            grandTotal: Value(job.grandTotal),
            workDone: Value(job.workDone),
            paymentStatus: Value(job.paymentStatus),
            advanceReceived: Value(job.advanceReceived),
            amountPaid: Value(job.amountPaid),
            paymentMode: Value(job.paymentMode),
            billId: Value(job.billId),
            receivedAt: job.receivedAt,
            expectedDelivery: Value(job.expectedDelivery),
            completedAt: Value(job.completedAt),
            deliveredAt: Value(job.deliveredAt),
            cancelledAt: Value(job.cancelledAt),
            cancellationReason: Value(job.cancellationReason),
            smsNotificationsEnabled: Value(job.smsNotificationsEnabled),
            internalNotes: Value(job.internalNotes),
            isSynced: const Value(false),
            createdAt: now,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrReplace,
        );

    return id;
  }

  /// Get a service job by ID (tenant-scoped)
  Future<ServiceJob?> getServiceJobById(
    String id, {
    required String userId,
  }) async {
    final entity =
        await (_db.select(_db.serviceJobs)
              ..where((t) => t.id.equals(id) & t.userId.equals(userId)))
            .getSingleOrNull();

    if (entity == null) return null;
    return _entityToModel(entity);
  }

  /// Get all service jobs for a user
  Future<List<ServiceJob>> getAllServiceJobs(String userId) async {
    final entities =
        await (_db.select(_db.serviceJobs)
              ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.receivedAt)]))
            .get();

    return entities.map(_entityToModel).toList();
  }

  /// Get active service jobs (not delivered/cancelled)
  Future<List<ServiceJob>> getActiveServiceJobs(String userId) async {
    final entities =
        await (_db.select(_db.serviceJobs)
              ..where(
                (t) =>
                    t.userId.equals(userId) &
                    t.deletedAt.isNull() &
                    t.status.isNotIn(['DELIVERED', 'CANCELLED']),
              )
              ..orderBy([
                (t) => OrderingTerm.asc(t.priority),
                (t) => OrderingTerm.asc(t.expectedDelivery),
              ]))
            .get();

    return entities.map(_entityToModel).toList();
  }

  /// Get jobs by status
  Future<List<ServiceJob>> getServiceJobsByStatus(
    String userId,
    ServiceJobStatus status,
  ) async {
    final entities =
        await (_db.select(_db.serviceJobs)
              ..where(
                (t) =>
                    t.userId.equals(userId) &
                    t.deletedAt.isNull() &
                    t.status.equals(status.value),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.receivedAt)]))
            .get();

    return entities.map(_entityToModel).toList();
  }

  /// Get jobs for a customer
  Future<List<ServiceJob>> getServiceJobsForCustomer(
    String userId,
    String customerId,
  ) async {
    final entities =
        await (_db.select(_db.serviceJobs)
              ..where(
                (t) =>
                    t.userId.equals(userId) &
                    t.customerId.equals(customerId) &
                    t.deletedAt.isNull(),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.receivedAt)]))
            .get();

    return entities.map(_entityToModel).toList();
  }

  /// Update service job status (tenant-scoped)
  Future<void> updateStatus(
    String id,
    ServiceJobStatus newStatus, {
    required String userId,
    String? notes,
    String? changedByUserId,
    String? changedByName,
  }) async {
    final job = await getServiceJobById(id, userId: userId);
    if (job == null) return;

    await _db.transaction(() async {
      // Update the job
      await (_db.update(
        _db.serviceJobs,
      )..where((t) => t.id.equals(id) & t.userId.equals(userId))).write(
        ServiceJobsCompanion(
          status: Value(newStatus.value),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ),
      );

      // Add status history entry
      await _db
          .into(_db.serviceJobStatusHistory)
          .insert(
            ServiceJobStatusHistoryCompanion.insert(
              id: const Uuid().v4(),
              serviceJobId: id,
              fromStatus: Value(job.status.value),
              toStatus: newStatus.value,
              changedByUserId: Value(changedByUserId),
              changedByName: Value(changedByName),
              notes: Value(notes),
              changedAt: DateTime.now(),
            ),
          );
    });
  }

  /// Update service job (tenant-scoped)
  Future<void> updateServiceJob(ServiceJob job) async {
    await (_db.update(
      _db.serviceJobs,
    )..where((t) => t.id.equals(job.id) & t.userId.equals(job.userId))).write(
      ServiceJobsCompanion(
        customerName: Value(job.customerName),
        customerPhone: Value(job.customerPhone),
        customerEmail: Value(job.customerEmail),
        customerAddress: Value(job.customerAddress),
        deviceType: Value(job.deviceType.value),
        brand: Value(job.brand),
        model: Value(job.model),
        imeiOrSerial: Value(job.imeiOrSerial),
        color: Value(job.color),
        problemDescription: Value(job.problemDescription),
        status: Value(job.status.value),
        priority: Value(job.priority.value),
        assignedTechnicianId: Value(job.assignedTechnicianId),
        assignedTechnicianName: Value(job.assignedTechnicianName),
        diagnosis: Value(job.diagnosis),
        estimatedLaborCost: Value(job.estimatedLaborCost),
        estimatedPartsCost: Value(job.estimatedPartsCost),
        estimatedTotal: Value(job.estimatedTotal),
        customerApproved: Value(job.customerApproved),
        approvedAt: Value(job.approvedAt),
        actualLaborCost: Value(job.actualLaborCost),
        actualPartsCost: Value(job.actualPartsCost),
        discountAmount: Value(job.discountAmount),
        taxAmount: Value(job.taxAmount),
        grandTotal: Value(job.grandTotal),
        workDone: Value(job.workDone),
        paymentStatus: Value(job.paymentStatus),
        advanceReceived: Value(job.advanceReceived),
        amountPaid: Value(job.amountPaid),
        paymentMode: Value(job.paymentMode),
        billId: Value(job.billId),
        expectedDelivery: Value(job.expectedDelivery),
        completedAt: Value(job.completedAt),
        deliveredAt: Value(job.deliveredAt),
        cancelledAt: Value(job.cancelledAt),
        cancellationReason: Value(job.cancellationReason),
        internalNotes: Value(job.internalNotes),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }

  /// Add diagnosis to job (tenant-scoped)
  Future<void> addDiagnosis(
    String id,
    String diagnosis, {
    required String userId,
  }) async {
    await (_db.update(
      _db.serviceJobs,
    )..where((t) => t.id.equals(id) & t.userId.equals(userId))).write(
      ServiceJobsCompanion(
        diagnosis: Value(diagnosis),
        diagnosedAt: Value(DateTime.now().toIso8601String()),
        status: Value(ServiceJobStatus.diagnosed.value),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }

  /// Mark job as completed (tenant-scoped)
  Future<void> markCompleted(
    String id,
    String workDone, {
    required String userId,
  }) async {
    await (_db.update(
      _db.serviceJobs,
    )..where((t) => t.id.equals(id) & t.userId.equals(userId))).write(
      ServiceJobsCompanion(
        workDone: Value(workDone),
        completedAt: Value(DateTime.now()),
        status: Value(ServiceJobStatus.completed.value),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }

  /// Mark job as delivered (tenant-scoped)
  Future<void> markDelivered(
    String id, {
    required String userId,
    String? deliveredToName,
    String? deliverySignature,
    String? deliveryNotes,
  }) async {
    await (_db.update(
      _db.serviceJobs,
    )..where((t) => t.id.equals(id) & t.userId.equals(userId))).write(
      ServiceJobsCompanion(
        deliveredAt: Value(DateTime.now()),
        deliveredToName: Value(deliveredToName),
        deliverySignature: Value(deliverySignature),
        deliveryNotes: Value(deliveryNotes),
        status: Value(ServiceJobStatus.delivered.value),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }

  /// Cancel job (tenant-scoped)
  Future<void> cancelJob(
    String id,
    String reason, {
    required String userId,
  }) async {
    await (_db.update(
      _db.serviceJobs,
    )..where((t) => t.id.equals(id) & t.userId.equals(userId))).write(
      ServiceJobsCompanion(
        cancelledAt: Value(DateTime.now()),
        cancellationReason: Value(reason),
        status: Value(ServiceJobStatus.cancelled.value),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }

  /// Soft delete job (tenant-scoped)
  Future<void> softDeleteJob(String id, {required String userId}) async {
    await (_db.update(
      _db.serviceJobs,
    )..where((t) => t.id.equals(id) & t.userId.equals(userId))).write(
      ServiceJobsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }

  /// Watch all service jobs
  Stream<List<ServiceJob>> watchAllServiceJobs(String userId) {
    return (_db.select(_db.serviceJobs)
          ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.receivedAt)]))
        .watch()
        .map((entities) => entities.map(_entityToModel).toList());
  }

  /// Watch active service jobs
  Stream<List<ServiceJob>> watchActiveServiceJobs(String userId) {
    return (_db.select(_db.serviceJobs)
          ..where(
            (t) =>
                t.userId.equals(userId) &
                t.deletedAt.isNull() &
                t.status.isNotIn(['DELIVERED', 'CANCELLED']),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.priority),
            (t) => OrderingTerm.asc(t.expectedDelivery),
          ]))
        .watch()
        .map((entities) => entities.map(_entityToModel).toList());
  }

  /// Get job counts by status
  Future<Map<ServiceJobStatus, int>> getJobCountsByStatus(String userId) async {
    final entities = await (_db.select(
      _db.serviceJobs,
    )..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())).get();

    final counts = <ServiceJobStatus, int>{};
    for (final status in ServiceJobStatus.values) {
      counts[status] = 0;
    }

    for (final entity in entities) {
      final status = ServiceJobStatusExtension.fromString(entity.status);
      counts[status] = (counts[status] ?? 0) + 1;
    }

    return counts;
  }

  /// Convert entity to model
  ServiceJob _entityToModel(ServiceJobEntity entity) {
    return ServiceJob(
      id: entity.id,
      userId: entity.userId,
      jobNumber: entity.jobNumber,
      customerId: entity.customerId,
      customerName: entity.customerName,
      customerPhone: entity.customerPhone,
      customerEmail: entity.customerEmail,
      customerAddress: entity.customerAddress,
      deviceType: DeviceTypeExtension.fromString(entity.deviceType),
      brand: entity.brand,
      model: entity.model,
      imeiOrSerial: entity.imeiOrSerial,
      color: entity.color,
      accessories:
          entity.accessories?.split(', ').where((s) => s.isNotEmpty).toList() ??
          [],
      deviceConditionNotes: entity.deviceConditionNotes,
      devicePhotos:
          entity.devicePhotosJson
              ?.split(',')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
      problemDescription: entity.problemDescription,
      symptoms:
          entity.symptomsJson
              ?.split(', ')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
      isUnderWarranty: entity.isUnderWarranty,
      originalBillId: entity.originalBillId,
      imeiSerialId: entity.imeiSerialId,
      status: ServiceJobStatusExtension.fromString(entity.status),
      priority: ServicePriorityExtension.fromString(entity.priority),
      assignedTechnicianId: entity.assignedTechnicianId,
      assignedTechnicianName: entity.assignedTechnicianName,
      diagnosis: entity.diagnosis,
      diagnosedAt: entity.diagnosedAt != null
          ? DateTime.tryParse(entity.diagnosedAt!)
          : null,
      estimatedLaborCost: entity.estimatedLaborCost,
      estimatedPartsCost: entity.estimatedPartsCost,
      estimatedTotal: entity.estimatedTotal,
      customerApproved: entity.customerApproved,
      approvedAt: entity.approvedAt,
      actualLaborCost: entity.actualLaborCost,
      actualPartsCost: entity.actualPartsCost,
      discountAmount: entity.discountAmount,
      taxAmount: entity.taxAmount,
      grandTotal: entity.grandTotal,
      workDone: entity.workDone,
      partsUsed: [], // Parts are fetched separately
      paymentStatus: entity.paymentStatus,
      advanceReceived: entity.advanceReceived,
      amountPaid: entity.amountPaid,
      paymentMode: entity.paymentMode,
      billId: entity.billId,
      receivedAt: entity.receivedAt,
      expectedDelivery: entity.expectedDelivery,
      completedAt: entity.completedAt,
      deliveredAt: entity.deliveredAt,
      cancelledAt: entity.cancelledAt,
      cancellationReason: entity.cancellationReason,
      smsNotificationsEnabled: entity.smsNotificationsEnabled,
      internalNotes: entity.internalNotes,
      isSynced: entity.isSynced,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
