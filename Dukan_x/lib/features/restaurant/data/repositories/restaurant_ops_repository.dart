import 'package:dukanx/core/api/api_client.dart';
import 'package:dukanx/core/di/service_locator.dart';

class RestoExportResult {
  final bool success;
  final String? csv;
  final String? fileName;
  final String? error;
  final Map<String, dynamic>? raw;

  const RestoExportResult._({
    required this.success,
    this.csv,
    this.fileName,
    this.error,
    this.raw,
  });

  factory RestoExportResult.ok({
    String? csv,
    String? fileName,
    Map<String, dynamic>? raw,
  }) {
    return RestoExportResult._(
      success: true,
      csv: csv,
      fileName: fileName,
      raw: raw,
    );
  }

  factory RestoExportResult.fail(String error) {
    return RestoExportResult._(success: false, error: error);
  }
}

class RestaurantOpsRepository {
  ApiClient get _api => sl<ApiClient>();

  List<Map<String, dynamic>> _readItems(Map<String, dynamic>? data) {
    final root = data ?? const <String, dynamic>{};
    final dynamic items =
        root['data']?['items'] ??
        root['items'] ??
        root['data']?['reservations'] ??
        root['reservations'] ??
        root['data']?['waitlist'] ??
        root['waitlist'] ??
        root['data']?['orders'] ??
        root['orders'] ??
        root['data']?['logs'] ??
        root['logs'] ??
        root['data']?['alerts'] ??
        root['alerts'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listReservations() async {
    final res = await _api.get('/resto/reservations');
    if (!res.isSuccess) return const [];
    return _readItems(res.data);
  }

  Future<bool> createReservation({
    required String guestName,
    required String phone,
    required int peopleCount,
    required String reservationAt,
    String? notes,
  }) async {
    final res = await _api.post('/resto/reservations', body: {
      'guestName': guestName,
      'phone': phone,
      'peopleCount': peopleCount,
      'reservationAt': reservationAt,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
    return res.isSuccess;
  }

  Future<bool> updateReservationStatus({
    required String reservationId,
    required String status,
  }) async {
    final res = await _api.put(
      '/resto/reservations/$reservationId/status',
      body: {'status': status},
    );
    return res.isSuccess;
  }

  Future<List<Map<String, dynamic>>> listWaitlist() async {
    final res = await _api.get('/resto/waitlist');
    if (!res.isSuccess) return const [];
    return _readItems(res.data);
  }

  Future<bool> addToWaitlist({
    required String guestName,
    required String phone,
    required int peopleCount,
    String? notes,
  }) async {
    final res = await _api.post('/resto/waitlist', body: {
      'guestName': guestName,
      'phone': phone,
      'peopleCount': peopleCount,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
    return res.isSuccess;
  }

  Future<bool> seatWaitlist({
    required String waitlistId,
    required String tableId,
  }) async {
    final res = await _api.post(
      '/resto/waitlist/seat',
      body: {'waitlistId': waitlistId, 'tableId': tableId},
    );
    return res.isSuccess;
  }

  Future<bool> transferTable({
    required String fromTableId,
    required String toTableId,
  }) async {
    final res = await _api.post('/resto/tables/transfer', body: {
      'fromTableId': fromTableId,
      'toTableId': toTableId,
    });
    return res.isSuccess;
  }

  Future<bool> mergeTables({
    required List<String> sourceTableIds,
    required String targetTableId,
  }) async {
    final res = await _api.post('/resto/tables/merge', body: {
      'sourceTableIds': sourceTableIds,
      'targetTableId': targetTableId,
    });
    return res.isSuccess;
  }

  Future<bool> splitTable({
    required String tableId,
    required int splitCount,
  }) async {
    final res = await _api.post('/resto/tables/split', body: {
      'tableId': tableId,
      'splitCount': splitCount,
    });
    return res.isSuccess;
  }

  Future<Map<String, dynamic>?> splitBill({
    required String billId,
    required String mode,
    int? peopleCount,
    List<Map<String, dynamic>>? itemSplits,
  }) async {
    final optionalFields = <String, dynamic>{
      'peopleCount': peopleCount,
      'itemSplits': itemSplits,
    }..removeWhere((_, value) => value == null);
    final res = await _api.put('/resto/bills/$billId/split', body: {
      'mode': mode,
      ...optionalFields,
    });
    if (!res.isSuccess) return null;
    return res.data?['data'] is Map
        ? Map<String, dynamic>.from(res.data!['data'] as Map)
        : res.data;
  }

  Future<Map<String, dynamic>?> getSplitBill(String billId) async {
    final res = await _api.get('/resto/bills/$billId/split');
    if (!res.isSuccess) return null;
    return res.data?['data'] is Map
        ? Map<String, dynamic>.from(res.data!['data'] as Map)
        : res.data;
  }

  Future<bool> assignDeliveryRider({
    required String billId,
    required String riderId,
    String? riderName,
    String? riderPhone,
  }) async {
    final res = await _api.post('/resto/bills/$billId/delivery/assign', body: {
      'riderId': riderId,
      if (riderName != null && riderName.trim().isNotEmpty)
        'riderName': riderName.trim(),
      if (riderPhone != null && riderPhone.trim().isNotEmpty)
        'riderPhone': riderPhone.trim(),
    });
    return res.isSuccess;
  }

  Future<bool> updateDeliveryStatus({
    required String billId,
    required String status,
    String? note,
  }) async {
    final res = await _api.post('/resto/bills/$billId/delivery/status', body: {
      'status': status,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    return res.isSuccess;
  }

  Future<Map<String, dynamic>?> getDeliveryTracking(String billId) async {
    final res = await _api.get('/resto/bills/$billId/delivery/tracking');
    if (!res.isSuccess) return null;
    return res.data?['data'] is Map
        ? Map<String, dynamic>.from(res.data!['data'] as Map)
        : res.data;
  }

  Future<List<Map<String, dynamic>>> listAggregatorOrders() async {
    final res = await _api.get('/resto/aggregator/orders');
    if (!res.isSuccess) return const [];
    return _readItems(res.data);
  }

  Future<bool> updateAggregatorOrderStatus({
    required String billId,
    required String status,
  }) async {
    final res = await _api.put(
      '/resto/aggregator/orders/$billId/status',
      body: {'status': status},
    );
    return res.isSuccess;
  }

  Future<bool> sendReceipt({
    required String billId,
    required List<String> channels,
    String? email,
    String? phone,
  }) async {
    final res = await _api.post('/resto/bills/$billId/receipt/send', body: {
      'channels': channels,
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
    });
    return res.isSuccess;
  }

  Future<List<Map<String, dynamic>>> listReceiptLogs() async {
    final res = await _api.get('/resto/receipts/logs');
    if (!res.isSuccess) return const [];
    return _readItems(res.data);
  }

  Future<List<Map<String, dynamic>>> listCombos() async {
    final res = await _api.get('/resto/combos');
    if (!res.isSuccess) return const [];
    return _readItems(res.data);
  }

  Future<bool> createCombo({
    required String name,
    required int bundlePriceCents,
    required List<Map<String, dynamic>> items,
  }) async {
    final res = await _api.post('/resto/combos', body: {
      'name': name,
      'bundlePriceCents': bundlePriceCents,
      'items': items,
    });
    return res.isSuccess;
  }

  Future<bool> updateCombo({
    required String comboId,
    required String name,
    required int bundlePriceCents,
    required List<Map<String, dynamic>> items,
  }) async {
    final res = await _api.put('/resto/combos/$comboId', body: {
      'name': name,
      'bundlePriceCents': bundlePriceCents,
      'items': items,
    });
    return res.isSuccess;
  }

  Future<bool> deleteCombo(String comboId) async {
    final res = await _api.delete('/resto/combos/$comboId');
    return res.isSuccess;
  }

  Future<List<Map<String, dynamic>>> listHappyHours() async {
    final res = await _api.get('/resto/happy-hours');
    if (!res.isSuccess) return const [];
    return _readItems(res.data);
  }

  Future<bool> createHappyHour({
    required String name,
    required String discountType,
    required num discountValue,
    required List<String> menuItemIds,
    required List<int> daysOfWeek,
    required String startTime,
    required String endTime,
  }) async {
    final res = await _api.post('/resto/happy-hours', body: {
      'name': name,
      'discountType': discountType,
      'discountValue': discountValue,
      'menuItemIds': menuItemIds,
      'daysOfWeek': daysOfWeek,
      'startTime': startTime,
      'endTime': endTime,
    });
    return res.isSuccess;
  }

  Future<bool> updateHappyHour({
    required String happyHourId,
    required String name,
    required String discountType,
    required num discountValue,
    required List<String> menuItemIds,
    required List<int> daysOfWeek,
    required String startTime,
    required String endTime,
  }) async {
    final res = await _api.put('/resto/happy-hours/$happyHourId', body: {
      'name': name,
      'discountType': discountType,
      'discountValue': discountValue,
      'menuItemIds': menuItemIds,
      'daysOfWeek': daysOfWeek,
      'startTime': startTime,
      'endTime': endTime,
    });
    return res.isSuccess;
  }

  Future<bool> deleteHappyHour(String happyHourId) async {
    final res = await _api.delete('/resto/happy-hours/$happyHourId');
    return res.isSuccess;
  }

  Future<bool> requestRestoExport({
    required String report,
    String format = 'csv',
  }) async {
    final result = await requestRestoExportDetailed(
      report: report,
      format: format,
    );
    return result.success;
  }

  Future<RestoExportResult> requestRestoExportDetailed({
    required String report,
    String format = 'csv',
  }) async {
    final payload = {'report': report, 'format': format};
    final res = await _api.post('/resto/reports/export', body: payload);
    if (res.isSuccess) {
      final body = _normalizeExportBody(res.data);
      return RestoExportResult.ok(
        csv: body['csv']?.toString(),
        fileName: body['fileName']?.toString(),
        raw: body,
      );
    }

    // Backward-compat fallback for older export route naming
    final fallback = await _api.post('/resto/exports', body: payload);
    if (fallback.isSuccess) {
      final body = _normalizeExportBody(fallback.data);
      return RestoExportResult.ok(
        csv: body['csv']?.toString(),
        fileName: body['fileName']?.toString(),
        raw: body,
      );
    }
    return RestoExportResult.fail(
      'Export API returned non-success response for $report',
    );
  }

  Map<String, dynamic> _normalizeExportBody(Map<String, dynamic>? source) {
    final root = source ?? const <String, dynamic>{};
    if (root['data'] is Map) {
      return Map<String, dynamic>.from(root['data'] as Map);
    }
    return Map<String, dynamic>.from(root);
  }
}
