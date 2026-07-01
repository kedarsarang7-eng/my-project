import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_manager.dart';
import '../../../core/sync/sync_queue_state_machine.dart';
import '../../inventory/services/inventory_service.dart';
import '../data/exceptions/medicine_quantity_parse_exception.dart';
import '../data/repositories/doctor_repository.dart';
import '../models/prescription_model.dart';

/// Clinic Billing Service
///
/// This service handles the connection between clinical visits/prescriptions
/// and the billing system. It ensures that:
/// 1. Consultation fees are automatically added
/// 2. Prescribed medicines are added as bill items
/// 3. Lab tests are included in the bill
/// 4. Bills are properly linked to visits and prescriptions
class ClinicBillingService {
  final AppDatabase _db;
  final SyncManager _syncManager;
  final InventoryService _inventoryService;
  final DoctorRepository _doctorRepository;

  ClinicBillingService({
    required AppDatabase db,
    required SyncManager syncManager,
    required InventoryService inventoryService,
    required DoctorRepository doctorRepository,
  }) : _db = db,
       _syncManager = syncManager,
       _inventoryService = inventoryService,
       _doctorRepository = doctorRepository;

  static const String collectionName = 'bills';

  /// Fallback consultation fee used when DoctorProfile is unavailable or fee is zero.
  static const double _fallbackConsultationFee = 500.0;

  /// Resolves the consultation fee from the doctor's profile.
  /// Falls back to [_fallbackConsultationFee] if the profile doesn't exist
  /// or its consultationFee is zero/unavailable.
  Future<double> _resolveConsultationFee(String doctorId) async {
    final profile = await _doctorRepository.getProfileByVendorId(doctorId);
    if (profile != null && profile.consultationFee > 0) {
      return profile.consultationFee;
    }
    return _fallbackConsultationFee;
  }

  // ============================================
  // CREATE BILL FROM VISIT
  // ============================================

  /// Creates a bill from a visit with consultation fee
  ///
  /// [visitId] - The visit to create bill for
  /// [doctorId] - The doctor performing the visit
  /// [patientId] - The patient being billed
  /// [patientName] - Patient name for bill display
  /// [consultationFee] - Override default consultation fee
  Future<String> createBillFromVisit({
    required String visitId,
    required String doctorId,
    required String patientId,
    required String patientName,
    double? consultationFee,
  }) async {
    final billId = const Uuid().v4();
    final now = DateTime.now();
    final fee = consultationFee ?? await _resolveConsultationFee(doctorId);

    // Create bill with consultation fee
    final billItems = [
      {
        'id': const Uuid().v4(),
        'productId': null,
        'productName': 'Consultation Fee',
        'quantity': 1.0,
        'unit': 'visit',
        'unitPrice': fee,
        'totalAmount': fee,
        'discountPercent': 0.0,
        'taxPercent': 0.0,
        'type': 'SERVICE',
      },
    ];

    await _db
        .into(_db.bills)
        .insert(
          BillsCompanion.insert(
            id: billId,
            userId: doctorId,
            invoiceNumber: _generateInvoiceNumber(now),
            customerId: Value(patientId),
            customerName: Value(patientName),
            billDate: now,
            subtotal: Value(fee),
            grandTotal: Value(fee),
            paidAmount: const Value(0.0),
            status: const Value('PENDING'),
            businessType: const Value('clinic'),
            itemsJson: jsonEncode(billItems),
            createdAt: now,
            updatedAt: now,
          ),
        );

    // Update visit with billId
    await (_db.update(_db.visits)..where((t) => t.id.equals(visitId))).write(
      VisitsCompanion(billId: Value(billId), updatedAt: Value(now)),
    );

    // Queue sync
    await _syncManager.enqueue(
      SyncQueueItem.create(
        userId: doctorId,
        operationType: SyncOperationType.create,
        targetCollection: collectionName,
        documentId: billId,
        payload: {
          'id': billId,
          'visitId': visitId,
          'patientId': patientId,
          'items': billItems,
          'subtotal': fee,
          'grandTotal': fee,
        },
      ),
    );

    return billId;
  }

  // ============================================
  // ADD PRESCRIPTION TO BILL
  // ============================================

  /// Adds prescription medicines to an existing bill
  ///
  /// [billId] - The bill to add items to
  /// [prescription] - The prescription with medicines
  /// [includeProducts] - If true, fetches actual product prices from inventory
  Future<void> addPrescriptionToBill({
    required String billId,
    required PrescriptionModel prescription,
    bool includeProducts = true,
  }) async {
    await _db.transaction(() async {
      final now = DateTime.now();
      final syncOps = <SyncQueueItem>[];

      // Get existing bill
      final bill = await (_db.select(
        _db.bills,
      )..where((t) => t.id.equals(billId))).getSingleOrNull();

      if (bill == null) {
        throw Exception('Bill not found: $billId');
      }

      // Parse existing items
      List<Map<String, dynamic>> existingItems = [];
      if (bill.itemsJson.isNotEmpty) {
        try {
          existingItems = List<Map<String, dynamic>>.from(
            jsonDecode(bill.itemsJson) as List,
          );
        } catch (_) {
          existingItems = [];
        }
      }

      // Add medicine items
      double medicineTotal = 0.0;

      for (final medicine in prescription.items) {
        double unitPrice = 0.0;
        double quantity = 1.0;

        // Try to get price from inventory if productId exists
        if (includeProducts && medicine.productId != null) {
          final product = await (_db.select(
            _db.products,
          )..where((t) => t.id.equals(medicine.productId!))).getSingleOrNull();

          if (product != null) {
            unitPrice = product.sellingPrice;
            // Parse quantity from duration
            quantity = _calculateMedicineQuantity(medicine);

            // DEDUCT STOCK (Atomic)
            if (quantity > 0) {
              final ops = await _inventoryService.deductStockInTransaction(
                userId: bill.userId, // Doctor is the user
                productId: medicine.productId!,
                quantity: quantity,
                referenceId: billId,
                invoiceNumber: bill.invoiceNumber,
                date: now,
                reason: 'PRESCRIPTION_SALE',
                description: 'Prescribed to ${bill.customerName}',
              );
              syncOps.addAll(ops);
            }
          }
        }

        final itemTotal = unitPrice * quantity;
        medicineTotal += itemTotal;

        existingItems.add({
          'id': const Uuid().v4(),
          'productId': medicine.productId,
          'productName': medicine.medicineName,
          'quantity': quantity,
          'unit': 'pcs',
          'unitPrice': unitPrice,
          'totalAmount': itemTotal,
          'discountPercent': 0.0,
          'taxPercent': 0.0,
          'type': 'MEDICINE',
          'prescriptionItemId': medicine.id,
          'dosage': medicine.dosage,
          'duration': medicine.duration,
        });
      }

      // Calculate new totals
      final newSubtotal = bill.subtotal + medicineTotal;
      final newGrandTotal = bill.grandTotal + medicineTotal;

      // Update bill
      await (_db.update(_db.bills)..where((t) => t.id.equals(billId))).write(
        BillsCompanion(
          itemsJson: Value(jsonEncode(existingItems)),
          subtotal: Value(newSubtotal),
          grandTotal: Value(newGrandTotal),
          prescriptionId: Value(prescription.id),
          updatedAt: Value(now),
        ),
      );

      // Collect sync op for bill update
      syncOps.add(
        SyncQueueItem.create(
          userId: bill.userId,
          operationType: SyncOperationType.update,
          targetCollection: collectionName,
          documentId: billId,
          payload: {
            'id': billId,
            'prescriptionId': prescription.id,
            'subtotal': newSubtotal,
            'grandTotal': newGrandTotal,
            'items': existingItems, // Include items updates
          },
        ),
      );

      // Execute all sync ops via manager (post-transaction or here?
      // SyncManager usually handles its own async, but we want to ensure these are queued.
      // queueStockSyncOperations is helper in InventoryService but we have syncManager directly)

      for (final op in syncOps) {
        await _syncManager.enqueue(op);
      }
    });
  }

  // ============================================
  // ADD LAB TESTS TO BILL
  // ============================================

  /// Adds lab tests to an existing bill
  Future<void> addLabTestsToBill({
    required String billId,
    required List<Map<String, dynamic>> labTests,
  }) async {
    final now = DateTime.now();

    final bill = await (_db.select(
      _db.bills,
    )..where((t) => t.id.equals(billId))).getSingleOrNull();

    if (bill == null) {
      throw Exception('Bill not found: $billId');
    }

    // Parse existing items
    // Parse existing items
    List<Map<String, dynamic>> existingItems = [];
    if (bill.itemsJson.isNotEmpty) {
      try {
        existingItems = List<Map<String, dynamic>>.from(
          jsonDecode(bill.itemsJson) as List,
        );
      } catch (_) {
        existingItems = [];
      }
    }

    double testsTotal = 0.0;

    for (final test in labTests) {
      final testPrice = (test['price'] as num?)?.toDouble() ?? 0.0;
      testsTotal += testPrice;

      existingItems.add({
        'id': const Uuid().v4(),
        'productId': null,
        'productName': test['name'] ?? 'Lab Test',
        'quantity': 1.0,
        'unit': 'test',
        'unitPrice': testPrice,
        'totalAmount': testPrice,
        'discountPercent': 0.0,
        'taxPercent': 0.0,
        'type': 'LAB_TEST',
        'labReportId': test['id'],
      });
    }

    final newSubtotal = bill.subtotal + testsTotal;
    final newGrandTotal = bill.grandTotal + testsTotal;

    await (_db.update(_db.bills)..where((t) => t.id.equals(billId))).write(
      BillsCompanion(
        itemsJson: Value(jsonEncode(existingItems)),
        subtotal: Value(newSubtotal),
        grandTotal: Value(newGrandTotal),
        updatedAt: Value(now),
      ),
    );
  }

  // ============================================
  // GET BILL FOR VISIT
  // ============================================

  /// Get bill associated with a visit
  Future<BillEntity?> getBillForVisit(String visitId) async {
    final visit = await (_db.select(
      _db.visits,
    )..where((t) => t.id.equals(visitId))).getSingleOrNull();

    if (visit?.billId == null) return null;

    return await (_db.select(
      _db.bills,
    )..where((t) => t.id.equals(visit!.billId!))).getSingleOrNull();
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  /// Generate invoice number
  String _generateInvoiceNumber(DateTime date) {
    final timestamp = date.millisecondsSinceEpoch.toString();
    return 'CONS-${timestamp.substring(timestamp.length - 8)}';
  }

  /// Calculate medicine quantity from dosage and duration
  /// e.g., "1-0-1" (twice daily) × "5 days" = 10 units
  ///
  /// Throws [MedicineQuantityParseException] when dosage or duration cannot be
  /// parsed into a numeric quantity. Callers must surface this to the user.
  double _calculateMedicineQuantity(PrescriptionItemModel medicine) {
    // Parse dosage like "1-0-1" (morning-afternoon-evening)
    int dosesPerDay = 0;
    if (medicine.dosage != null && medicine.dosage!.trim().isNotEmpty) {
      final parts = medicine.dosage!.split('-');
      for (final part in parts) {
        final parsed = int.tryParse(part.trim());
        if (parsed != null) {
          dosesPerDay += parsed;
        }
      }
    }

    if (dosesPerDay == 0) {
      throw MedicineQuantityParseException(
        medicineName: medicine.medicineName,
        dosage: medicine.dosage,
        duration: medicine.duration,
        reason:
            'Could not extract doses-per-day from dosage '
            '"${medicine.dosage ?? "(empty)"}" — no numeric parts found',
      );
    }

    // Parse duration like "5 days" or "1 week"
    int days = 0;
    if (medicine.duration != null && medicine.duration!.trim().isNotEmpty) {
      final durationLower = medicine.duration!.toLowerCase();
      final match = RegExp(r'(\d+)').firstMatch(durationLower);
      if (match != null) {
        final number = int.tryParse(match.group(1)!);
        if (number != null && number > 0) {
          if (durationLower.contains('week')) {
            days = number * 7;
          } else if (durationLower.contains('month')) {
            days = number * 30;
          } else {
            days = number;
          }
        }
      }
    }

    if (days == 0) {
      throw MedicineQuantityParseException(
        medicineName: medicine.medicineName,
        dosage: medicine.dosage,
        duration: medicine.duration,
        reason:
            'Could not extract duration-in-days from duration '
            '"${medicine.duration ?? "(empty)"}" — no positive number found',
      );
    }

    return (dosesPerDay * days).toDouble();
  }
}
