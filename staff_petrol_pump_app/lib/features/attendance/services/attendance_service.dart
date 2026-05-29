// ============================================================================
// ATTENDANCE SERVICE - Manages staff shift check-in/out and transaction recording
// ============================================================================

import 'package:dio/dio.dart';
import '../../../core/services/api_service.dart';
import '../domain/attendance_exception.dart';

class AttendanceService {
  final ApiService _apiService;

  AttendanceService({required ApiService apiService})
      : _apiService = apiService;

  Future<Map<String, dynamic>> validateStaffId(String staffId) async {
    final response = await _apiService.get(
      '/attendance/validate-staff',
      queryParameters: {'staffId': staffId},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Sends a check-in request.
  ///
  /// [clientRequestId] is a UUID v4 generated once per logical check-in
  /// attempt and persisted by the caller until a successful response is
  /// received.  The backend uses it to deduplicate concurrent or retried
  /// requests atomically, preventing duplicate open shifts.
  ///
  /// HTTP 409 `SHIFT_ALREADY_ACTIVE` is treated as a soft-success: the shift
  /// already exists on the server. The method returns the existing shift
  /// payload (with `alreadyActive: true`) so the caller can navigate to the
  /// dashboard without extra catch logic.
  ///
  /// All other errors are thrown as [AttendanceException].
  Future<Map<String, dynamic>> checkIn({
    required String staffId,
    required String stationId,
    String? clientRequestId,
  }) async {
    try {
      final body = <String, dynamic>{
        'staffId': staffId,
        'stationId': stationId,
        if (clientRequestId != null) 'clientRequestId': clientRequestId,
      };
      final response = await _apiService.post(
        '/attendance/check-in',
        data: body,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _toAttendanceException(e);
    }
  }

  /// Converts a raw [DioException] into a typed [AttendanceException] by
  /// reading the `errorCode` field from the response body.
  ///
  /// 409 `SHIFT_ALREADY_ACTIVE` with a `shiftId` present is NOT thrown here —
  /// callers that want the soft-success path (e.g. IDScannerBloc) should catch
  /// [AttendanceException] with code == [AttendanceErrorCode.shiftAlreadyActive]
  /// and treat it as a success.
  AttendanceException _toAttendanceException(DioException e) {
    final response = e.response;
    if (response == null) {
      return AttendanceException(
        code: AttendanceErrorCode.networkError,
        message: 'No response from server. Check your connection.',
      );
    }
    final data = response.data;
    final rawCode = data is Map<String, dynamic> ? data['errorCode'] as String? : null;
    final message = data is Map<String, dynamic>
        ? (data['error'] as String? ?? 'Request failed')
        : 'Request failed';
    final extra = data is Map<String, dynamic>
        ? (Map<String, dynamic>.from(data)..removeWhere((k, _) => k == 'error' || k == 'errorCode'))
        : <String, dynamic>{};

    return AttendanceException(
      code: parseErrorCode(rawCode),
      message: message,
      statusCode: response.statusCode,
      extra: extra,
    );
  }

  Future<Map<String, dynamic>> checkOut({
    required String shiftId,
  }) async {
    try {
      final response = await _apiService.post(
        '/attendance/check-out',
        data: {'shiftId': shiftId},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _toAttendanceException(e);
    }
  }

  Future<Map<String, dynamic>> getShiftDetails(String shiftId) async {
    try {
      final response = await _apiService.get('/attendance/shift/$shiftId');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _toAttendanceException(e);
    }
  }

  Future<Map<String, dynamic>> getShiftStats(String shiftId) async {
    try {
      final response = await _apiService.get('/attendance/shift/$shiftId/stats');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _toAttendanceException(e);
    }
  }

  Future<Map<String, dynamic>> getRecentTransactions({
    required String shiftId,
    int limit = 10,
  }) async {
    try {
      final response = await _apiService.get(
        '/attendance/shift/$shiftId/transactions',
        queryParameters: {'limit': limit},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _toAttendanceException(e);
    }
  }

  Future<void> recordTransaction({
    required String shiftId,
    required String fuelType,
    required double litres,
    required double amount,
    required String paymentMethod,
  }) async {
    try {
      await _apiService.post(
        '/attendance/shift/$shiftId/transaction',
        data: {
          'fuelType': fuelType,
          'litres': litres,
          'amount': amount,
          'paymentMethod': paymentMethod,
        },
      );
    } on DioException catch (e) {
      throw _toAttendanceException(e);
    }
  }

  Future<String> getStationId() async {
    try {
      final response = await _apiService.get('/attendance/station-id');
      return response.data['stationId'] as String;
    } on DioException catch (e) {
      throw _toAttendanceException(e);
    }
  }
}
