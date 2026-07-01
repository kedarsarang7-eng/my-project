/// Service Job Service
/// Business logic for service/repair jobs
library;

import 'package:dukanx/core/database/app_database.dart';
import '../data/repositories/service_job_repository.dart';
import '../data/repositories/imei_serial_repository.dart';
import '../models/service_job.dart';
import '../models/imei_serial.dart';

/// Service for managing service jobs and IMEI/Serials
class ServiceJobService {
  final ServiceJobRepository _jobRepository;
  final IMEISerialRepository _imeiRepository;

  ServiceJobService(AppDatabase db)
    : _jobRepository = ServiceJobRepository(db),
      _imeiRepository = IMEISerialRepository(db);

  // ============================================================================
  // SERVICE JOB OPERATIONS
  // ============================================================================

  /// Create a new service job
  Future<String> createServiceJob({
    required String userId,
    required String customerName,
    required String customerPhone,
    String? customerEmail,
    String? customerAddress,
    String? customerId,
    required DeviceType deviceType,
    required String brand,
    required String model,
    String? imeiOrSerial,
    String? color,
    List<String> accessories = const [],
    String? deviceConditionNotes,
    required String problemDescription,
    List<String> symptoms = const [],
    ServicePriority priority = ServicePriority.normal,
    DateTime? expectedDelivery,
    String? internalNotes,
  }) async {
    // Generate job number
    final jobNumber = await _jobRepository.generateJobNumber(userId);

    // Check warranty if IMEI provided
    bool isUnderWarranty = false;
    String? originalBillId;
    String? imeiSerialId;

    if (imeiOrSerial != null && imeiOrSerial.isNotEmpty) {
      final imeiRecord = await _imeiRepository.getByNumber(
        userId,
        imeiOrSerial,
      );
      if (imeiRecord != null) {
        isUnderWarranty = imeiRecord.isWarrantyActive;
        originalBillId = imeiRecord.billId;
        imeiSerialId = imeiRecord.id;

        // Mark IMEI as in service
        await _imeiRepository.markAsInService(imeiRecord.id, userId: userId);
      }
    }

    final now = DateTime.now();
    final job = ServiceJob(
      id: '',
      userId: userId,
      jobNumber: jobNumber,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      customerAddress: customerAddress,
      deviceType: deviceType,
      brand: brand,
      model: model,
      imeiOrSerial: imeiOrSerial,
      color: color,
      accessories: accessories,
      deviceConditionNotes: deviceConditionNotes,
      problemDescription: problemDescription,
      symptoms: symptoms,
      isUnderWarranty: isUnderWarranty,
      originalBillId: originalBillId,
      imeiSerialId: imeiSerialId,
      status: ServiceJobStatus.received,
      priority: priority,
      receivedAt: now,
      expectedDelivery: expectedDelivery,
      internalNotes: internalNotes,
      createdAt: now,
      updatedAt: now,
    );

    return _jobRepository.createServiceJob(job);
  }

  /// Get service job by ID
  Future<ServiceJob?> getServiceJob(String id, {required String userId}) {
    return _jobRepository.getServiceJobById(id, userId: userId);
  }

  /// Get all service jobs
  Future<List<ServiceJob>> getAllServiceJobs(String userId) {
    return _jobRepository.getAllServiceJobs(userId);
  }

  /// Get active service jobs
  Future<List<ServiceJob>> getActiveServiceJobs(String userId) {
    return _jobRepository.getActiveServiceJobs(userId);
  }

  /// Get jobs by status
  Future<List<ServiceJob>> getJobsByStatus(
    String userId,
    ServiceJobStatus status,
  ) {
    return _jobRepository.getServiceJobsByStatus(userId, status);
  }

  /// Watch active jobs
  Stream<List<ServiceJob>> watchActiveJobs(String userId) {
    return _jobRepository.watchActiveServiceJobs(userId);
  }

  /// Watch all jobs
  Stream<List<ServiceJob>> watchAllJobs(String userId) {
    return _jobRepository.watchAllServiceJobs(userId);
  }

  /// Get job counts by status
  Future<Map<ServiceJobStatus, int>> getJobCounts(String userId) {
    return _jobRepository.getJobCountsByStatus(userId);
  }

  /// Update job status
  Future<void> updateStatus(
    String jobId,
    ServiceJobStatus newStatus, {
    required String userId,
    String? notes,
    String? changedByUserId,
    String? changedByName,
  }) async {
    await _jobRepository.updateStatus(
      jobId,
      newStatus,
      userId: userId,
      notes: notes,
      changedByUserId: changedByUserId,
      changedByName: changedByName,
    );

    // If delivered, mark IMEI as sold/returned to stock
    if (newStatus == ServiceJobStatus.delivered) {
      final job = await _jobRepository.getServiceJobById(jobId, userId: userId);
      if (job != null && job.imeiSerialId != null) {
        // Return to stock (customer's device returned)
        await _imeiRepository.returnToStock(job.imeiSerialId!, userId: userId);
      }
    }
  }

  /// Add diagnosis
  Future<void> addDiagnosis(
    String jobId,
    String diagnosis, {
    required String userId,
  }) {
    return _jobRepository.addDiagnosis(jobId, diagnosis, userId: userId);
  }

  /// Add cost estimate
  Future<void> addEstimate({
    required String jobId,
    required String userId,
    required double laborCost,
    required double partsCost,
    double taxRate = 0,
  }) async {
    final job = await _jobRepository.getServiceJobById(jobId, userId: userId);
    if (job == null) return;

    final total = laborCost + partsCost;
    final tax = total * (taxRate / 100);
    final grandTotal = total + tax;

    await _jobRepository.updateServiceJob(
      job.copyWith(
        estimatedLaborCost: laborCost,
        estimatedPartsCost: partsCost,
        estimatedTotal: grandTotal,
        status: ServiceJobStatus.waitingApproval,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Customer approves estimate
  Future<void> approveEstimate(String jobId, {required String userId}) async {
    final job = await _jobRepository.getServiceJobById(jobId, userId: userId);
    if (job == null) return;

    await _jobRepository.updateServiceJob(
      job.copyWith(
        customerApproved: true,
        approvedAt: DateTime.now(),
        status: ServiceJobStatus.approved,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Mark job as completed
  Future<void> completeJob({
    required String jobId,
    required String userId,
    required String workDone,
    required double actualLaborCost,
    required double actualPartsCost,
    double discountAmount = 0,
    double taxAmount = 0,
  }) async {
    final job = await _jobRepository.getServiceJobById(jobId, userId: userId);
    if (job == null) return;

    final grandTotal =
        actualLaborCost + actualPartsCost - discountAmount + taxAmount;

    await _jobRepository.updateServiceJob(
      job.copyWith(
        workDone: workDone,
        actualLaborCost: actualLaborCost,
        actualPartsCost: actualPartsCost,
        discountAmount: discountAmount,
        taxAmount: taxAmount,
        grandTotal: grandTotal,
        completedAt: DateTime.now(),
        status: ServiceJobStatus.completed,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Mark as ready for pickup
  Future<void> markReady(String jobId, {required String userId}) {
    return _jobRepository.updateStatus(
      jobId,
      ServiceJobStatus.ready,
      userId: userId,
    );
  }

  /// Deliver job
  Future<void> deliverJob({
    required String jobId,
    required String userId,
    String? deliveredToName,
    String? deliverySignature,
    String? deliveryNotes,
  }) {
    return _jobRepository.markDelivered(
      jobId,
      userId: userId,
      deliveredToName: deliveredToName,
      deliverySignature: deliverySignature,
      deliveryNotes: deliveryNotes,
    );
  }

  /// Cancel job
  Future<void> cancelJob(
    String jobId,
    String reason, {
    required String userId,
  }) async {
    final job = await _jobRepository.getServiceJobById(jobId, userId: userId);
    if (job != null && job.imeiSerialId != null) {
      // Return IMEI to stock
      await _imeiRepository.returnToStock(job.imeiSerialId!, userId: userId);
    }
    return _jobRepository.cancelJob(jobId, reason, userId: userId);
  }

  /// Link a generate bill to this job
  Future<void> linkBillToJob(
    String jobId,
    String billId, {
    required String userId,
  }) async {
    final job = await _jobRepository.getServiceJobById(jobId, userId: userId);
    if (job == null) return;

    await _jobRepository.updateServiceJob(
      job.copyWith(billId: billId, updatedAt: DateTime.now()),
    );
  }

  /// Record payment
  Future<void> recordPayment({
    required String jobId,
    required String userId,
    required double amount,
    String? paymentMode,
    bool isAdvance = false,
  }) async {
    final job = await _jobRepository.getServiceJobById(jobId, userId: userId);
    if (job == null) return;

    final newAdvance = isAdvance
        ? job.advanceReceived + amount
        : job.advanceReceived;
    final newPaid = job.amountPaid + amount;
    final newStatus = newPaid >= job.grandTotal ? 'PAID' : 'PARTIAL';

    await _jobRepository.updateServiceJob(
      job.copyWith(
        advanceReceived: newAdvance,
        amountPaid: newPaid,
        paymentStatus: newStatus,
        paymentMode: paymentMode ?? job.paymentMode,
        updatedAt: DateTime.now(),
      ),
    );
  }

  // ============================================================================
  // IMEI/SERIAL OPERATIONS
  // ============================================================================

  /// Add new IMEI/Serial to inventory
  Future<String> addIMEISerial({
    required String userId,
    required String productId,
    required String imeiOrSerial,
    IMEISerialType type = IMEISerialType.imei,
    String? purchaseOrderId,
    double purchasePrice = 0,
    DateTime? purchaseDate,
    String? supplierName,
    int warrantyMonths = 0,
    String? productName,
    String? brand,
    String? model,
    String? color,
    String? storage,
    String? ram,
  }) async {
    // Check for duplicates
    final exists = await _imeiRepository.exists(userId, imeiOrSerial);
    if (exists) {
      throw Exception('IMEI/Serial already exists: $imeiOrSerial');
    }

    final now = DateTime.now();
    final imei = IMEISerial(
      id: '',
      userId: userId,
      productId: productId,
      imeiOrSerial: imeiOrSerial,
      type: type,
      status: IMEISerialStatus.inStock,
      purchaseOrderId: purchaseOrderId,
      purchasePrice: purchasePrice,
      purchaseDate: purchaseDate ?? now,
      supplierName: supplierName,
      warrantyMonths: warrantyMonths,
      productName: productName,
      brand: brand,
      model: model,
      color: color,
      storage: storage,
      ram: ram,
      createdAt: now,
      updatedAt: now,
    );

    return _imeiRepository.createIMEISerial(imei);
  }

  /// Check if IMEI available for sale
  Future<bool> isIMEIAvailable(String userId, String imeiOrSerial) {
    return _imeiRepository.isAvailableForSale(userId, imeiOrSerial);
  }

  /// Get IMEI by number
  Future<IMEISerial?> getIMEIByNumber(String userId, String imeiOrSerial) {
    return _imeiRepository.getByNumber(userId, imeiOrSerial);
  }

  /// Get customer's purchase history (devices they bought)
  Future<List<IMEISerial>> getCustomerDevices(
    String userId,
    String customerId,
  ) {
    return _imeiRepository.getByCustomer(userId, customerId);
  }

  /// Validate warranty for a device
  Future<bool> validateWarranty(String userId, String imeiOrSerial) {
    return _imeiRepository.isUnderWarranty(imeiOrSerial, userId);
  }

  /// Get in-stock IMEI count for a product
  Future<int> getIMEIStockCount(String userId, String productId) {
    return _imeiRepository.getInStockCount(userId, productId);
  }

  /// Mark IMEI as sold (called during billing)
  Future<void> sellIMEI({
    required String id,
    required String userId,
    required String billId,
    required String customerId,
    required double soldPrice,
    int warrantyMonths = 0,
  }) {
    return _imeiRepository.markAsSold(
      id: id,
      userId: userId,
      billId: billId,
      customerId: customerId,
      soldPrice: soldPrice,
      warrantyMonths: warrantyMonths,
    );
  }
}
