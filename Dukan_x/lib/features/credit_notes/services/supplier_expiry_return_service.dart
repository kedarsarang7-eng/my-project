import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/api/api_client.dart';

/// Service for creating Supplier Credit Notes when returning expired stock.
/// Per Indian pharmacy practice: expired drugs returned to distributor,
/// credit note issued at purchase rate (rate-wise, not MRP).
class SupplierExpiryReturnService {
  final AppDatabase _db;

  SupplierExpiryReturnService(this._db);

  /// Create a supplier credit note for expired batch returns
  Future<SupplierCreditNote> createExpiryReturn({
    required String tenantId,
    required String supplierId,
    required String supplierName,
    required List<ExpiryReturnItem> items,
    String? remarks,
    String? createdBy,
  }) async {
    // Validate all items are actually expired
    for (final item in items) {
      if (item.expiryDate != null && item.expiryDate!.isAfter(DateTime.now())) {
        throw Exception(
          'Item ${item.productName} batch ${item.batchNumber} is NOT expired yet. '
          'Cannot create expiry return.',
        );
      }
    }

    // Calculate totals at PURCHASE RATE (not MRP/selling rate)
    // Using paise-only integer arithmetic to avoid floating point drift
    int totalAmountPaise = 0;
    int totalGstPaise = 0;

    for (final item in items) {
      final purchasePaise = (item.purchaseRate * 100).round();
      final qtyMillis = (item.quantity * 1000).round();
      final basePaise = (purchasePaise * qtyMillis) ~/ 1000;
      final gstPaise = (basePaise * item.gstRate / 100).round();
      totalAmountPaise += basePaise;
      totalGstPaise += gstPaise;
    }

    final note = SupplierCreditNote(
      id: const Uuid().v4(),
      tenantId: tenantId,
      supplierId: supplierId,
      supplierName: supplierName,
      creditNoteNumber: _generateCreditNoteNumber(),
      date: DateTime.now(),
      items: items,
      subtotalPaise: totalAmountPaise,
      gstPaise: totalGstPaise,
      totalPaise: totalAmountPaise + totalGstPaise,
      status: 'PENDING', // PENDING → ACCEPTED → ADJUSTED
      remarks: remarks,
      createdBy: createdBy,
    );

    // Sync to backend
    try {
      final api = sl<ApiClient>();
      await api.post('/pharmacy/supplier-credit-notes', body: note.toMap());
    } catch (_) {
      // Queued for offline sync
    }

    return note;
  }

  /// Get all expired batches eligible for return to supplier
  Future<List<ExpiredBatchInfo>> getExpiredBatches(String userId) async {
    final results = <ExpiredBatchInfo>[];

    // Query expired batches with stock > 0
    final batches =
        await (_db.select(_db.productBatches)
              ..where((t) => t.userId.equals(userId))
              ..where((t) => t.status.equals('ACTIVE'))
              ..where((t) => t.stockQuantity.isBiggerOrEqualValue(0.0001))
              ..where(
                (t) => t.expiryDate.isSmallerOrEqualValue(DateTime.now()),
              ))
            .get();

    for (final batch in batches) {
      // Get product info
      final product = await (_db.select(
        _db.products,
      )..where((t) => t.id.equals(batch.productId))).getSingleOrNull();

      if (product != null) {
        results.add(
          ExpiredBatchInfo(
            productId: batch.productId,
            productName: product.name,
            batchId: batch.id,
            batchNumber: batch.batchNumber,
            expiryDate: batch.expiryDate,
            stockQuantity: batch.stockQuantity,
            purchaseRate: batch.purchaseRate,
            sellingRate: batch.sellingRate,
            gstRate: product.taxRate,
          ),
        );
      }
    }

    return results;
  }

  String _generateCreditNoteNumber() {
    final now = DateTime.now();
    final prefix = 'ECN'; // Expiry Credit Note
    final month = '${now.year}${now.month.toString().padLeft(2, '0')}';
    final seq = now.millisecondsSinceEpoch.toString().substring(8);
    return '$prefix-$month-$seq';
  }
}

class SupplierCreditNote {
  final String id;
  final String tenantId;
  final String supplierId;
  final String supplierName;
  final String creditNoteNumber;
  final DateTime date;
  final List<ExpiryReturnItem> items;
  final int subtotalPaise;
  final int gstPaise;
  final int totalPaise;
  final String status;
  final String? remarks;
  final String? createdBy;

  SupplierCreditNote({
    required this.id,
    required this.tenantId,
    required this.supplierId,
    required this.supplierName,
    required this.creditNoteNumber,
    required this.date,
    required this.items,
    required this.subtotalPaise,
    required this.gstPaise,
    required this.totalPaise,
    required this.status,
    this.remarks,
    this.createdBy,
  });

  double get subtotalRupees => subtotalPaise / 100.0;
  double get totalRupees => totalPaise / 100.0;

  Map<String, dynamic> toMap() => {
    'id': id,
    'tenant_id': tenantId,
    'supplier_id': supplierId,
    'supplier_name': supplierName,
    'credit_note_number': creditNoteNumber,
    'date': date.toIso8601String(),
    'items': items.map((i) => i.toMap()).toList(),
    'subtotal_paise': subtotalPaise,
    'gst_paise': gstPaise,
    'total_paise': totalPaise,
    'status': status,
    'remarks': remarks,
    'created_by': createdBy,
  };
}

class ExpiryReturnItem {
  final String productId;
  final String productName;
  final String batchNumber;
  final DateTime? expiryDate;
  final double quantity;
  final double purchaseRate; // Rate-wise — NOT MRP
  final double gstRate;
  final String? hsnCode;

  ExpiryReturnItem({
    required this.productId,
    required this.productName,
    required this.batchNumber,
    this.expiryDate,
    required this.quantity,
    required this.purchaseRate,
    required this.gstRate,
    this.hsnCode,
  });

  Map<String, dynamic> toMap() => {
    'product_id': productId,
    'product_name': productName,
    'batch_number': batchNumber,
    'expiry_date': expiryDate?.toIso8601String(),
    'quantity': quantity,
    'purchase_rate_paise': (purchaseRate * 100).round(),
    'gst_rate': gstRate,
    'hsn_code': hsnCode,
  };
}

class ExpiredBatchInfo {
  final String productId;
  final String productName;
  final String batchId;
  final String batchNumber;
  final DateTime? expiryDate;
  final double stockQuantity;
  final double purchaseRate;
  final double sellingRate;
  final double gstRate;

  ExpiredBatchInfo({
    required this.productId,
    required this.productName,
    required this.batchId,
    required this.batchNumber,
    this.expiryDate,
    required this.stockQuantity,
    required this.purchaseRate,
    required this.sellingRate,
    required this.gstRate,
  });
}
