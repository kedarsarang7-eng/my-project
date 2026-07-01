/// Warranty Claim Repository
/// Handles CRUD operations for warranty claims
library;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:dukanx/core/database/app_database.dart';
import '../../models/warranty_claim.dart';

/// Repository for Warranty Claim CRUD operations
class WarrantyClaimRepository {
  final AppDatabase _db;

  WarrantyClaimRepository(this._db);

  /// Generate next claim number for a user
  /// Format: WCL-YYMM-0001
  Future<String> generateClaimNumber(String userId) async {
    final today = DateTime.now();
    final prefix =
        'WCL-${today.year.toString().substring(2)}${today.month.toString().padLeft(2, '0')}';

    // Count existing claims this month
    final count =
        await (_db.selectOnly(_db.warrantyClaims)
              ..addColumns([_db.warrantyClaims.id.count()])
              ..where(
                _db.warrantyClaims.userId.equals(userId) &
                    _db.warrantyClaims.filedAt.isBiggerOrEqualValue(
                      DateTime(today.year, today.month, 1),
                    ),
              ))
            .map((row) => row.read(_db.warrantyClaims.id.count()) ?? 0)
            .getSingle();

    final nextNumber = (count + 1).toString().padLeft(4, '0');
    return '$prefix-$nextNumber';
  }

  /// Create a new warranty claim
  Future<String> createClaim(WarrantyClaim claim) async {
    final id = claim.id.isEmpty ? const Uuid().v4() : claim.id;
    final claimNumber = claim.claimNumber.isEmpty
        ? await generateClaimNumber(claim.userId)
        : claim.claimNumber;
    final now = DateTime.now();

    await _db
        .into(_db.warrantyClaims)
        .insert(
          WarrantyClaimsCompanion.insert(
            id: id,
            userId: claim.userId,
            claimNumber: claimNumber,
            originalBillId: claim.originalBillId,
            originalInvoiceNumber: Value(claim.originalInvoiceNumber),
            originalSaleDate: Value(claim.originalSaleDate),
            productId: claim.productId,
            productName: claim.productName,
            brand: Value(claim.brand),
            model: Value(claim.model),
            imeiOrSerial: claim.imeiOrSerial,
            color: Value(claim.color),
            storage: Value(claim.storage),
            customerId: Value(claim.customerId),
            customerName: claim.customerName,
            customerPhone: claim.customerPhone,
            customerEmail: Value(claim.customerEmail),
            issueDescription: claim.issueDescription,
            symptomsJson: Value(claim.symptoms.join(', ')),
            issuePhotosJson: Value(claim.issuePhotos.join(',')),
            warrantyStartDate: Value(claim.warrantyStartDate),
            warrantyEndDate: Value(claim.warrantyEndDate),
            warrantyPeriodMonths: Value(claim.warrantyPeriodMonths),
            isUnderWarranty: Value(claim.isUnderWarranty),
            warrantyVerificationNotes: Value(claim.warrantyVerificationNotes),
            status: claim.status.value,
            filedAt: claim.filedAt,
            reviewedAt: Value(claim.reviewedAt),
            approvedAt: Value(claim.approvedAt),
            completedAt: Value(claim.completedAt),
            closedAt: Value(claim.closedAt),
            reviewedByUserId: Value(claim.reviewedByUserId),
            reviewedByName: Value(claim.reviewedByName),
            assignedTechnicianId: Value(claim.assignedTechnicianId),
            assignedTechnicianName: Value(claim.assignedTechnicianName),
            partsReplacedJson: Value(
              claim.partsReplaced.map((p) => p.toMap()).toList().toString(),
            ),
            totalPartsCost: Value(claim.totalPartsCost),
            laborCost: Value(claim.laborCost),
            totalClaimCost: Value(claim.totalClaimCost),
            rejectionReason: Value(claim.rejectionReason?.value),
            rejectionNotes: Value(claim.rejectionNotes),
            linkedServiceJobId: Value(claim.linkedServiceJobId),
            resolutionNotes: Value(claim.resolutionNotes),
            workDone: Value(claim.workDone),
            isReimbursedBySupplier: Value(claim.isReimbursedBySupplier),
            reimbursementAmount: Value(claim.reimbursementAmount),
            reimbursedAt: Value(claim.reimbursedAt),
            reimbursementReference: Value(claim.reimbursementReference),
            isSynced: const Value(false),
            createdAt: now,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrReplace,
        );

    return id;
  }

  /// Get a warranty claim by ID (tenant-scoped)
  Future<WarrantyClaim?> getClaimById(
    String id, {
    required String userId,
  }) async {
    final entity =
        await (_db.select(_db.warrantyClaims)
              ..where((t) => t.id.equals(id) & t.userId.equals(userId)))
            .getSingleOrNull();

    if (entity == null) return null;
    return _entityToModel(entity);
  }

  /// Get a warranty claim by number
  Future<WarrantyClaim?> getClaimByNumber(
    String userId,
    String claimNumber,
  ) async {
    final entity =
        await (_db.select(_db.warrantyClaims)..where(
              (t) =>
                  t.userId.equals(userId) & t.claimNumber.equals(claimNumber),
            ))
            .getSingleOrNull();

    if (entity == null) return null;
    return _entityToModel(entity);
  }

  /// Get all warranty claims for a user
  Future<List<WarrantyClaim>> getAllClaims(String userId) async {
    final entities =
        await (_db.select(_db.warrantyClaims)
              ..where((t) => t.userId.equals(userId))
              ..orderBy([(t) => OrderingTerm.desc(t.filedAt)]))
            .get();

    return entities.map(_entityToModel).toList();
  }

  /// Get claims by status
  Future<List<WarrantyClaim>> getClaimsByStatus(
    String userId,
    WarrantyClaimStatus status,
  ) async {
    final entities =
        await (_db.select(_db.warrantyClaims)
              ..where(
                (t) => t.userId.equals(userId) & t.status.equals(status.value),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.filedAt)]))
            .get();

    return entities.map(_entityToModel).toList();
  }

  /// Get active claims (not closed or rejected)
  Future<List<WarrantyClaim>> getActiveClaims(String userId) async {
    final entities =
        await (_db.select(_db.warrantyClaims)
              ..where(
                (t) =>
                    t.userId.equals(userId) &
                    t.status.isNotIn(['CLOSED', 'REJECTED']),
              )
              ..orderBy([
                (t) => OrderingTerm.asc(t.warrantyEndDate),
                (t) => OrderingTerm.desc(t.filedAt),
              ]))
            .get();

    return entities.map(_entityToModel).toList();
  }

  /// Get claims for a specific customer
  Future<List<WarrantyClaim>> getClaimsByCustomer(
    String userId,
    String customerId,
  ) async {
    final entities =
        await (_db.select(_db.warrantyClaims)
              ..where(
                (t) =>
                    t.userId.equals(userId) & t.customerId.equals(customerId),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.filedAt)]))
            .get();

    return entities.map(_entityToModel).toList();
  }

  /// Get claims for a specific IMEI/Serial
  Future<List<WarrantyClaim>> getClaimsByIMEI(
    String userId,
    String imeiOrSerial,
  ) async {
    final entities =
        await (_db.select(_db.warrantyClaims)
              ..where(
                (t) =>
                    t.userId.equals(userId) &
                    t.imeiOrSerial.equals(imeiOrSerial),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.filedAt)]))
            .get();

    return entities.map(_entityToModel).toList();
  }

  /// Get claims under review (pending approval)
  Future<List<WarrantyClaim>> getPendingReviewClaims(String userId) async {
    return getClaimsByStatus(userId, WarrantyClaimStatus.filed);
  }

  /// Get claims awaiting parts
  Future<List<WarrantyClaim>> getAwaitingPartsClaims(String userId) async {
    return getClaimsByStatus(userId, WarrantyClaimStatus.partsOrdered);
  }

  /// Get claims in repair
  Future<List<WarrantyClaim>> getInRepairClaims(String userId) async {
    return getClaimsByStatus(userId, WarrantyClaimStatus.inRepair);
  }

  /// Get completed but not closed claims
  Future<List<WarrantyClaim>> getPendingDeliveryClaims(String userId) async {
    return getClaimsByStatus(userId, WarrantyClaimStatus.completed);
  }

  /// Get claims statistics
  Future<Map<String, dynamic>> getClaimsStats(String userId) async {
    final allClaims = await getAllClaims(userId);

    int filed = 0;
    int underReview = 0;
    int approved = 0;
    int inRepair = 0;
    int completed = 0;
    int rejected = 0;
    int closed = 0;

    double totalClaimCosts = 0;
    double totalReimbursed = 0;

    for (final claim in allClaims) {
      switch (claim.status) {
        case WarrantyClaimStatus.filed:
          filed++;
          break;
        case WarrantyClaimStatus.underReview:
          underReview++;
          break;
        case WarrantyClaimStatus.approved:
          approved++;
          break;
        case WarrantyClaimStatus.partsOrdered:
        case WarrantyClaimStatus.inRepair:
          inRepair++;
          break;
        case WarrantyClaimStatus.completed:
          completed++;
          break;
        case WarrantyClaimStatus.rejected:
          rejected++;
          break;
        case WarrantyClaimStatus.closed:
          closed++;
          break;
      }

      totalClaimCosts += claim.totalClaimCost;
      if (claim.isReimbursedBySupplier) {
        totalReimbursed += claim.reimbursementAmount ?? 0;
      }
    }

    return {
      'total': allClaims.length,
      'filed': filed,
      'underReview': underReview,
      'approved': approved,
      'inRepair': inRepair,
      'completed': completed,
      'rejected': rejected,
      'closed': closed,
      'active': filed + underReview + approved + inRepair + completed,
      'totalClaimCosts': totalClaimCosts,
      'totalReimbursed': totalReimbursed,
      'netWarrantyCost': totalClaimCosts - totalReimbursed,
    };
  }

  /// Update claim status (tenant-scoped)
  Future<void> updateStatus(
    String id,
    WarrantyClaimStatus newStatus, {
    required String userId,
    String? reviewedByUserId,
    String? reviewedByName,
    String? notes,
  }) async {
    final now = DateTime.now();

    final updates = <String, dynamic>{
      'status': newStatus.value,
      'updatedAt': now.toIso8601String(),
      'isSynced': false,
    };

    // Update timestamp fields based on status
    switch (newStatus) {
      case WarrantyClaimStatus.underReview:
        updates['reviewedAt'] = now.toIso8601String();
        if (reviewedByUserId != null)
          updates['reviewedByUserId'] = reviewedByUserId;
        if (reviewedByName != null) updates['reviewedByName'] = reviewedByName;
        break;
      case WarrantyClaimStatus.approved:
        updates['approvedAt'] = now.toIso8601String();
        if (reviewedByUserId != null)
          updates['reviewedByUserId'] = reviewedByUserId;
        if (reviewedByName != null) updates['reviewedByName'] = reviewedByName;
        break;
      case WarrantyClaimStatus.completed:
        updates['completedAt'] = now.toIso8601String();
        break;
      case WarrantyClaimStatus.closed:
        updates['closedAt'] = now.toIso8601String();
        break;
      default:
        break;
    }

    if (notes != null) {
      updates['warrantyVerificationNotes'] = notes;
    }

    await (_db.update(
      _db.warrantyClaims,
    )..where((t) => t.id.equals(id) & t.userId.equals(userId))).write(
      WarrantyClaimsCompanion(
        status: updates.containsKey('status')
            ? Value(updates['status'] as String)
            : const Value.absent(),
        reviewedAt: updates.containsKey('reviewedAt')
            ? Value(DateTime.parse(updates['reviewedAt'] as String))
            : const Value.absent(),
        reviewedByUserId: updates.containsKey('reviewedByUserId')
            ? Value(updates['reviewedByUserId'] as String)
            : const Value.absent(),
        reviewedByName: updates.containsKey('reviewedByName')
            ? Value(updates['reviewedByName'] as String)
            : const Value.absent(),
        approvedAt: updates.containsKey('approvedAt')
            ? Value(DateTime.parse(updates['approvedAt'] as String))
            : const Value.absent(),
        completedAt: updates.containsKey('completedAt')
            ? Value(DateTime.parse(updates['completedAt'] as String))
            : const Value.absent(),
        closedAt: updates.containsKey('closedAt')
            ? Value(DateTime.parse(updates['closedAt'] as String))
            : const Value.absent(),
        warrantyVerificationNotes:
            updates.containsKey('warrantyVerificationNotes')
            ? Value(updates['warrantyVerificationNotes'] as String)
            : const Value.absent(),
        updatedAt: Value(now),
        isSynced: const Value(false),
      ),
    );
  }

  /// Assign technician to claim (tenant-scoped)
  Future<void> assignTechnician(
    String id, {
    required String userId,
    required String technicianId,
    required String technicianName,
  }) async {
    await (_db.update(
      _db.warrantyClaims,
    )..where((t) => t.id.equals(id) & t.userId.equals(userId))).write(
      WarrantyClaimsCompanion(
        assignedTechnicianId: Value(technicianId),
        assignedTechnicianName: Value(technicianName),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }

  /// Add parts replaced to claim (tenant-scoped)
  Future<void> addPartsReplaced(
    String id,
    List<WarrantyClaimPart> parts, {
    required String userId,
    double? laborCost,
  }) async {
    final existing = await getClaimById(id, userId: userId);
    if (existing == null) return;

    final allParts = [...existing.partsReplaced, ...parts];
    final totalPartsCost = allParts.fold<double>(
      0,
      (sum, p) => sum + p.totalCost,
    );

    final totalClaimCost = totalPartsCost + (laborCost ?? existing.laborCost);

    await (_db.update(
      _db.warrantyClaims,
    )..where((t) => t.id.equals(id) & t.userId.equals(userId))).write(
      WarrantyClaimsCompanion(
        partsReplacedJson: Value(
          allParts.map((p) => p.toMap()).toList().toString(),
        ),
        totalPartsCost: Value(totalPartsCost),
        totalClaimCost: Value(totalClaimCost),
        laborCost: laborCost != null ? Value(laborCost) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }

  /// Update reimbursement info (tenant-scoped)
  Future<void> updateReimbursement(
    String id, {
    required String userId,
    required bool isReimbursed,
    double? amount,
    String? reference,
  }) async {
    await (_db.update(
      _db.warrantyClaims,
    )..where((t) => t.id.equals(id) & t.userId.equals(userId))).write(
      WarrantyClaimsCompanion(
        isReimbursedBySupplier: Value(isReimbursed),
        reimbursementAmount: amount != null
            ? Value(amount)
            : const Value.absent(),
        reimbursedAt: isReimbursed ? Value(DateTime.now()) : const Value(null),
        reimbursementReference: reference != null
            ? Value(reference)
            : const Value.absent(),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }

  /// Reject claim (tenant-scoped)
  Future<void> rejectClaim(
    String id, {
    required String userId,
    required RejectionReason reason,
    required String notes,
    String? reviewedByUserId,
    String? reviewedByName,
  }) async {
    final now = DateTime.now();

    await (_db.update(
      _db.warrantyClaims,
    )..where((t) => t.id.equals(id) & t.userId.equals(userId))).write(
      WarrantyClaimsCompanion(
        status: const Value('REJECTED'),
        rejectionReason: Value(reason.value),
        rejectionNotes: Value(notes),
        reviewedAt: Value(now),
        reviewedByUserId: reviewedByUserId != null
            ? Value(reviewedByUserId)
            : const Value.absent(),
        reviewedByName: reviewedByName != null
            ? Value(reviewedByName)
            : const Value.absent(),
        updatedAt: Value(now),
        isSynced: const Value(false),
      ),
    );
  }

  /// Link to service job (tenant-scoped)
  Future<void> linkServiceJob(
    String claimId,
    String serviceJobId, {
    required String userId,
  }) async {
    await (_db.update(
      _db.warrantyClaims,
    )..where((t) => t.id.equals(claimId) & t.userId.equals(userId))).write(
      WarrantyClaimsCompanion(
        linkedServiceJobId: Value(serviceJobId),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }

  /// Update work done and resolution (tenant-scoped)
  Future<void> updateResolution(
    String id, {
    required String userId,
    required String workDone,
    String? resolutionNotes,
  }) async {
    await (_db.update(
      _db.warrantyClaims,
    )..where((t) => t.id.equals(id) & t.userId.equals(userId))).write(
      WarrantyClaimsCompanion(
        workDone: Value(workDone),
        resolutionNotes: resolutionNotes != null
            ? Value(resolutionNotes)
            : const Value.absent(),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }

  /// Watch all claims as stream
  Stream<List<WarrantyClaim>> watchAllClaims(String userId) {
    return (_db.select(_db.warrantyClaims)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.filedAt)]))
        .watch()
        .map((entities) => entities.map(_entityToModel).toList());
  }

  /// Watch active claims as stream
  Stream<List<WarrantyClaim>> watchActiveClaims(String userId) {
    return (_db.select(_db.warrantyClaims)
          ..where(
            (t) =>
                t.userId.equals(userId) &
                t.status.isNotIn(['CLOSED', 'REJECTED']),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.warrantyEndDate),
            (t) => OrderingTerm.desc(t.filedAt),
          ]))
        .watch()
        .map((entities) => entities.map(_entityToModel).toList());
  }

  /// Convert entity to model
  WarrantyClaim _entityToModel(WarrantyClaimEntity entity) {
    return WarrantyClaim(
      id: entity.id,
      userId: entity.userId,
      claimNumber: entity.claimNumber,
      originalBillId: entity.originalBillId,
      originalInvoiceNumber: entity.originalInvoiceNumber,
      originalSaleDate: entity.originalSaleDate,
      productId: entity.productId,
      productName: entity.productName,
      brand: entity.brand,
      model: entity.model,
      imeiOrSerial: entity.imeiOrSerial,
      color: entity.color,
      storage: entity.storage,
      customerId: entity.customerId,
      customerName: entity.customerName,
      customerPhone: entity.customerPhone,
      customerEmail: entity.customerEmail,
      issueDescription: entity.issueDescription,
      symptoms:
          entity.symptomsJson
              ?.split(', ')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
      issuePhotos:
          entity.issuePhotosJson
              ?.split(',')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
      warrantyStartDate: entity.warrantyStartDate,
      warrantyEndDate: entity.warrantyEndDate,
      warrantyPeriodMonths: entity.warrantyPeriodMonths ?? 0,
      isUnderWarranty: entity.isUnderWarranty ?? false,
      warrantyVerificationNotes: entity.warrantyVerificationNotes,
      status: WarrantyClaimStatusExtension.fromString(entity.status),
      filedAt: entity.filedAt,
      reviewedAt: entity.reviewedAt,
      approvedAt: entity.approvedAt,
      completedAt: entity.completedAt,
      closedAt: entity.closedAt,
      reviewedByUserId: entity.reviewedByUserId,
      reviewedByName: entity.reviewedByName,
      assignedTechnicianId: entity.assignedTechnicianId,
      assignedTechnicianName: entity.assignedTechnicianName,
      partsReplaced: [], // Parsed from JSON if needed
      totalPartsCost: entity.totalPartsCost ?? 0,
      laborCost: entity.laborCost ?? 0,
      totalClaimCost: entity.totalClaimCost ?? 0,
      rejectionReason: entity.rejectionReason != null
          ? RejectionReason.values.firstWhere(
              (r) => r.value == entity.rejectionReason,
              orElse: () => RejectionReason.other,
            )
          : null,
      rejectionNotes: entity.rejectionNotes,
      linkedServiceJobId: entity.linkedServiceJobId,
      resolutionNotes: entity.resolutionNotes,
      workDone: entity.workDone,
      isReimbursedBySupplier: entity.isReimbursedBySupplier ?? false,
      reimbursementAmount: entity.reimbursementAmount,
      reimbursedAt: entity.reimbursedAt,
      reimbursementReference: entity.reimbursementReference,
      isSynced: entity.isSynced ?? false,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
