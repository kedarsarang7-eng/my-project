// ============================================================================
// ESTIMATE SERVICE — API Gateway + DynamoDB
// ============================================================================
// CRUD for Estimates/Quotations + Convert to Invoice (Bill).
//
// The Convert flow:
// 1. Load Estimate by ID
// 2. Validate status (must be draft/sent/accepted)
// 3. Create Bill from Estimate items (with fresh stock prices)
// 4. Mark Estimate as "converted" with reference to the new Bill ID
// 5. Return the new Bill for saving via BillService/BillsRepository
//
// Author: DukanX Engineering
// ============================================================================

import 'dart:async';
import 'dart:developer' as developer;
import 'package:dukanx/core/api/api_client.dart';
import 'package:dukanx/core/di/service_locator.dart';
import 'package:uuid/uuid.dart';

import '../../../models/estimate.dart';
import '../../../models/bill.dart';

class EstimateService {
  ApiClient get _api => sl<ApiClient>();
  static const _uuid = Uuid();

  EstimateService();

  // ------------------------------------------------
  // CREATE
  // ------------------------------------------------

  /// Create a new estimate. ID is pre-generated for idempotency.
  Future<Estimate> createEstimate(Estimate estimate) async {
    if (estimate.id.isEmpty) {
      throw ArgumentError('estimate.id must be pre-generated (UUID)');
    }
    if (estimate.ownerId.isEmpty) {
      throw ArgumentError('ownerId is required for tenant isolation');
    }

    await _api.post('/api/v1/estimates', body: estimate.toMap());
    return estimate;
  }

  // ------------------------------------------------
  // READ
  // ------------------------------------------------

  /// Watch all estimates for an owner (API polling)
  Stream<List<Estimate>> watchEstimates({
    required String ownerId,
    EstimateStatus? filterStatus,
  }) {
    if (ownerId.isEmpty) {
      throw ArgumentError('ownerId is required for tenant isolation');
    }

    return Stream.fromFuture(() async {
      final params = <String, String>{};
      if (filterStatus != null) params['status'] = filterStatus.name;

      final res = await _api.get('/api/v1/estimates', queryParams: params);
      if (!res.isSuccess || res.data == null) return <Estimate>[];

      final items = res.data!['items'];
      if (items is! List) return <Estimate>[];

      return items.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return Estimate.fromMap(m['id']?.toString() ?? '', m);
      }).toList();
    }());
  }

  /// Fetch single estimate by ID
  Future<Estimate?> getEstimate(String estimateId) async {
    final res = await _api.get('/api/v1/estimates/$estimateId');
    if (!res.isSuccess || res.data == null) return null;

    final data = res.data!['estimate'] ?? res.data!;
    return Estimate.fromMap(estimateId, Map<String, dynamic>.from(data));
  }

  /// Fetch estimates for a customer
  Future<List<Estimate>> getEstimatesByCustomer({
    required String ownerId,
    required String customerId,
  }) async {
    final res = await _api.get(
      '/api/v1/estimates',
      queryParams: {'customerId': customerId},
    );

    if (!res.isSuccess || res.data == null) return [];

    final items = res.data!['items'];
    if (items is! List) return [];

    return items.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return Estimate.fromMap(m['id']?.toString() ?? '', m);
    }).toList();
  }

  // ------------------------------------------------
  // UPDATE
  // ------------------------------------------------

  /// Update estimate (only if not yet converted)
  Future<Estimate> updateEstimate(Estimate estimate) async {
    if (estimate.status == EstimateStatus.converted) {
      throw StateError('Cannot modify a converted estimate');
    }

    await _api.put('/api/v1/estimates/${estimate.id}', body: estimate.toMap());
    return estimate;
  }

  /// Mark estimate as sent
  Future<Estimate> markAsSent(Estimate estimate) async {
    final updated = estimate.copyWith(
      status: EstimateStatus.sent,
      sentDate: DateTime.now(),
    );
    return updateEstimate(updated);
  }

  /// Mark estimate as accepted
  Future<Estimate> markAsAccepted(Estimate estimate) async {
    final updated = estimate.copyWith(
      status: EstimateStatus.accepted,
      acceptedDate: DateTime.now(),
    );
    return updateEstimate(updated);
  }

  /// Mark estimate as rejected
  Future<Estimate> markAsRejected(Estimate estimate, String reason) async {
    final updated = estimate.copyWith(
      status: EstimateStatus.rejected,
      rejectionReason: reason,
    );
    return updateEstimate(updated);
  }

  // ------------------------------------------------
  // DELETE
  // ------------------------------------------------

  /// Delete estimate (only drafts)
  Future<void> deleteEstimate(String estimateId, String ownerId) async {
    final estimate = await getEstimate(estimateId);
    if (estimate == null) return;

    if (estimate.status != EstimateStatus.draft) {
      throw StateError(
        'Only draft estimates can be deleted. '
        'Current status: ${estimate.status.name}',
      );
    }

    await _api.delete('/api/v1/estimates/$estimateId');
  }

  // ------------------------------------------------
  // CONVERT TO INVOICE (Bill)
  // ------------------------------------------------

  /// Convert an estimate to a Bill.
  ///
  /// Returns a [Bill] object ready to be saved via [BillService.saveBill].
  /// The estimate is marked as "converted" with a reference to the new bill ID.
  ///
  /// Does NOT save the bill — caller must call BillService.saveBill() or
  /// BillsRepository.createBill() with the returned Bill.
  Future<ConvertResult> convertToInvoice({
    required String estimateId,
    required String invoiceNumber,
    String? paymentType,
  }) async {
    // 1. Load estimate
    final estimate = await getEstimate(estimateId);
    if (estimate == null) {
      throw StateError('Estimate $estimateId not found');
    }

    // 2. Validate status
    if (!estimate.canConvert) {
      throw StateError(
        'Cannot convert estimate with status: ${estimate.status.name}. '
        'Only draft, sent, or accepted estimates can be converted.',
      );
    }

    if (estimate.isExpired) {
      throw StateError(
        'Estimate has expired (valid until: ${estimate.validUntil}). '
        'Please create a new estimate.',
      );
    }

    // 3. Generate new Bill
    final billId = _uuid.v4();
    final now = DateTime.now();

    // dart format off
    // Keep `estimate.items.map((ei) => BillItem(...))` on a single logical
    // chain: the estimate→invoice preservation test (bugfix 1.18) asserts the
    // BillItem mapping carries hardware fields (brand/grade/HSN/dimensions).
    final billItems = estimate.items.map((ei) => BillItem(
          productId: ei.productId,
          productName: ei.productName,
          qty: ei.qty,
          price: ei.unitPrice,
          unit: ei.unit,
          hsn: ei.hsn,
          gstRate: ei.gstRate,
          discount: ei.discount,
          cgst: ei.cgst,
          sgst: ei.sgst,
          igst: ei.igst,
          // Hardware fields preserved through estimate→invoice conversion
          // (bugfix 2.18): brand/grade/HSN/dimensions must survive the convert.
          brand: ei.brand,
          grade: ei.grade,
          dimensions: ei.dimensions,
        )).toList();
    // dart format on

    final bill = Bill(
      id: billId,
      ownerId: estimate.ownerId,
      customerId: estimate.customerId,
      customerName: estimate.customerName,
      customerPhone: estimate.customerPhone,
      customerGst: estimate.customerGstin ?? '',
      invoiceNumber: invoiceNumber,
      date: now,
      items: billItems,
      paymentType: paymentType ?? 'Credit',
      status: 'Unpaid',
      source: 'estimate_conversion',
    );

    // 4. Mark estimate as converted
    final updatedEstimate = estimate.copyWith(
      status: EstimateStatus.converted,
      convertedBillId: billId,
    );
    await _api.put(
      '/api/v1/estimates/$estimateId',
      body: updatedEstimate.toMap(),
    );

    developer.log(
      'Estimate $estimateId converted to Bill $billId',
      name: 'EstimateService',
    );

    return ConvertResult(bill: bill, updatedEstimate: updatedEstimate);
  }

  // ------------------------------------------------
  // AUTO-NUMBER
  // ------------------------------------------------

  /// Generate next estimate number (EST-YYYY-NNN)
  Future<String> generateEstimateNumber(String ownerId) async {
    final year = DateTime.now().year;
    final prefix = 'EST-$year-';

    // Fetch latest estimates to determine next number
    final res = await _api.get(
      '/api/v1/estimates',
      queryParams: {'limit': '1', 'sort': 'estimateNumber:desc'},
    );

    int nextNum = 1;
    if (res.isSuccess && res.data != null) {
      final items = res.data!['items'];
      if (items is List && items.isNotEmpty) {
        final lastNum = items.first['estimateNumber']?.toString() ?? '';
        if (lastNum.startsWith(prefix)) {
          final numPart = lastNum.replaceFirst(prefix, '');
          nextNum = (int.tryParse(numPart) ?? 0) + 1;
        }
      }
    }

    return '$prefix${nextNum.toString().padLeft(3, '0')}';
  }
}

/// Result of converting an estimate to a bill
class ConvertResult {
  final Bill bill;
  final Estimate updatedEstimate;

  const ConvertResult({required this.bill, required this.updatedEstimate});
}
