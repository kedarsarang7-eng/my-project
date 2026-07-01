import 'package:flutter/foundation.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../repositories/e_invoice_repository.dart';
import '../models/e_way_bill_model.dart';

/// e-Way Bill Service
///
/// Handles e-way bill generation for goods transport
/// with offline-first architecture.
class EWayBillService {
  final EInvoiceRepository _repository;

  EWayBillService(this._repository);

  /// Generate e-way bill for a dispatch
  ///
  /// Creates local record immediately,
  /// actual EWB generation happens async when online.
  Future<EWayBillModel?> generateEWayBill({
    required String billId,
    required String fromPlace,
    required String toPlace,
    required int distanceKm,
    String? fromPincode,
    String? toPincode,
    String? vehicleNumber,
    String? transporterId,
    String? transporterName,
  }) async {
    final userId = sl<SessionManager>().ownerId;
    if (userId == null) {
      debugPrint('EWayBillService: No user logged in');
      return null;
    }

    // 1. Create local record first (offline-first)
    final result = await _repository.createEWayBill(
      userId: userId,
      billId: billId,
      fromPlace: fromPlace,
      toPlace: toPlace,
      distanceKm: distanceKm,
      fromPincode: fromPincode,
      toPincode: toPincode,
      vehicleNumber: vehicleNumber,
      transporterId: transporterId,
      transporterName: transporterName,
    );

    if (!result.isSuccess) {
      debugPrint('EWayBillService: Failed to create local record');
      return null;
    }

    final ewayBill = result.data!;

    // 2. Try to generate EWB number (if online)
    _tryGenerateEWB(ewayBill.id, distanceKm);

    return ewayBill;
  }

  /// Attempt to generate e-way bill from GST portal
  Future<void> _tryGenerateEWB(String ewbId, int distanceKm) async {
    try {
      // For MVP, generate a local EWB number
      // In production, this would call the NIC/GST portal API

      final ewbNumber = _generateLocalEWBNumber();
      final ewbDate = DateTime.now();

      // Calculate validity based on distance
      // As per GST rules: 1 day for first 100km, +1 day for each additional 100km
      final validityDays = (distanceKm / 100).ceil().clamp(1, 15);
      final validUntil = ewbDate.add(Duration(days: validityDays));

      await _repository.updateEWayBillGenerated(
        id: ewbId,
        ewbNumber: ewbNumber,
        ewbDate: ewbDate,
        validUntil: validUntil,
      );

      debugPrint(
        'EWayBillService: EWB generated: $ewbNumber (valid until $validUntil)',
      );
    } catch (e) {
      debugPrint('EWayBillService: Failed to generate EWB: $e');
    }
  }

  /// Generate a local EWB number (for offline/demo purposes)
  ///
  /// Real EWB format: 12 digit number from NIC portal
  String _generateLocalEWBNumber() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final number = (timestamp % 1000000000000).toString().padLeft(12, '0');
    return number;
  }

  /// Calculate validity period based on distance
  Duration calculateValidity(int distanceKm) {
    // GST e-way bill validity rules:
    // - Up to 100 km: 1 day
    // - Each additional 100 km: +1 day
    // - Maximum: 15 days for ODC (over dimensional cargo)
    final days = (distanceKm / 100).ceil().clamp(1, 15);
    return Duration(days: days);
  }

  /// Get e-way bill for a bill
  Future<EWayBillModel?> getEWayBillForBill(String billId) async {
    final userId = sl<SessionManager>().ownerId;
    if (userId == null) return null;

    final result = await _repository.getAllEWayBills(userId: userId);
    if (!result.isSuccess) return null;

    return result.data!.firstWhere(
      (ewb) => ewb.billId == billId,
      orElse: () => throw Exception('Not found'),
    );
  }

  /// Get all e-way bills for current user
  Future<List<EWayBillModel>> getAllEWayBills({String? status}) async {
    final userId = sl<SessionManager>().ownerId;
    if (userId == null) return [];

    final result = await _repository.getAllEWayBills(
      userId: userId,
      status: status,
    );

    return result.data ?? [];
  }

  /// Check if e-way bill is about to expire (within 6 hours)
  bool isAboutToExpire(EWayBillModel ewayBill) {
    if (ewayBill.validUntil == null) return false;
    final remaining = ewayBill.validUntil!.difference(DateTime.now());
    return remaining.inHours <= 6 && remaining.inHours > 0;
  }

  /// Check if e-way bill has expired
  bool isExpired(EWayBillModel ewayBill) {
    if (ewayBill.validUntil == null) return false;
    return DateTime.now().isAfter(ewayBill.validUntil!);
  }

  /// Get expiring e-way bills (within 6 hours)
  Future<List<EWayBillModel>> getExpiringEWayBills() async {
    final all = await getAllEWayBills(status: 'GENERATED');
    return all.where((ewb) => isAboutToExpire(ewb)).toList();
  }
}
