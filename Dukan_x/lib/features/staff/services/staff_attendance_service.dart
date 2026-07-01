// ============================================================================
// STAFF ATTENDANCE SERVICE - API Client for Attendance & ID Card Operations
// ============================================================================

import 'package:dio/dio.dart';

import '../data/models/staff_profile_model.dart';
import '../presentation/bloc/id_card_models.dart';
import '../../../core/errors/io_guard.dart';

/// Service for staff attendance and ID card API operations
class StaffAttendanceService {
  final Dio _dio;

  StaffAttendanceService({required Dio dio}) : _dio = dio;

  // ============================================================================
  // STAFF DASHBOARD
  // ============================================================================

  /// Get comprehensive staff dashboard data
  /// BUG-021 FIX: Validates month is 1-12 before API call
  Future<Map<String, dynamic>> getStaffDashboard({
    required String staffId,
    required int month,
    required int year,
  }) async {
    // BUG-021: Validate month range
    if (month < 1 || month > 12) {
      throw ArgumentError('Month must be between 1 and 12, got: $month');
    }

    return IoGuard.run<Map<String, dynamic>>(
      label: 'staff_attendance.dashboard',
      userMessage:
          'Could not load the staff dashboard. Please check your connection.',
      op: () async {
        final response = await _dio.get(
          '/staff/$staffId/dashboard',
          queryParameters: {
            'month': month.toString().padLeft(2, '0'),
            'year': year.toString(),
          },
        );
        return response.data as Map<String, dynamic>;
      },
    );
  }

  /// Get staff by ID
  Future<StaffProfileModel> getStaffById(String staffId) async {
    return IoGuard.run<StaffProfileModel>(
      label: 'staff_attendance.staff_by_id',
      userMessage:
          'Could not load the staff profile. Please check your connection.',
      op: () async {
        final response = await _dio.get('/staff/$staffId');
        return StaffProfileModel.fromJson(
          response.data['staff'] as Map<String, dynamic>,
        );
      },
    );
  }

  // ============================================================================
  // ATTENDANCE
  // ============================================================================

  /// Get attendance calendar for a month
  /// BUG-021 FIX: Validates month is 1-12 before API call
  Future<Map<String, dynamic>> getAttendanceCalendar({
    required String staffId,
    required int month,
    required int year,
  }) async {
    // BUG-021: Validate month range
    if (month < 1 || month > 12) {
      throw ArgumentError('Month must be between 1 and 12, got: $month');
    }

    final response = await _dio.get(
      '/staff/$staffId/attendance-calendar',
      queryParameters: {
        'month': month.toString().padLeft(2, '0'),
        'year': year.toString(),
      },
    );
    return response.data as Map<String, dynamic>;
  }

  // ============================================================================
  // SHIFTS
  // ============================================================================

  /// Get shift history for a month
  Future<Map<String, dynamic>> getShiftHistory({
    required String staffId,
    required int month,
    required int year,
  }) async {
    final response = await _dio.get(
      '/staff/$staffId/shifts',
      queryParameters: {
        'month': month.toString().padLeft(2, '0'),
        'year': year.toString(),
      },
    );
    return response.data as Map<String, dynamic>;
  }

  // ============================================================================
  // TRANSACTIONS
  // ============================================================================

  /// Get staff transactions for a month
  Future<Map<String, dynamic>> getStaffTransactions({
    required String staffId,
    required int month,
    required int year,
  }) async {
    final response = await _dio.get(
      '/staff/$staffId/transactions',
      queryParameters: {
        'month': month.toString().padLeft(2, '0'),
        'year': year.toString(),
      },
    );
    return response.data as Map<String, dynamic>;
  }

  // ============================================================================
  // LEAVE
  // ============================================================================

  /// Get leave history
  Future<Map<String, dynamic>> getLeaveHistory({
    required String staffId,
  }) async {
    final response = await _dio.get('/staff/$staffId/leave');
    return response.data as Map<String, dynamic>;
  }

  /// Process leave request (approve/reject)
  Future<void> processLeaveRequest({
    required String leaveId,
    required String action,
    String? remarks,
    required String staffId,
  }) async {
    await _dio.put(
      '/owner/leave/$leaveId',
      queryParameters: {'staffId': staffId},
      data: {'action': action, 'remarks': remarks},
    );
  }

  // ============================================================================
  // ID CARD OPERATIONS
  // ============================================================================

  /// Export ID card to file (PDF or PNG)
  Future<Map<String, dynamic>> exportIDCard({
    required String staffId,
    required IDCardSettings settings,
    required String format,
    String? filePath,
  }) async {
    // First, generate the ID card image/PDF locally using Flutter
    // Then upload to backend if cloud storage is needed

    final response = await _dio.post(
      '/staff/$staffId/id-card',
      data: {
        'format': format,
        'template': settings.template.toString().split('.').last,
      },
    );

    return response.data as Map<String, dynamic>;
  }

  /// Upload ID card image to S3
  Future<Map<String, dynamic>> uploadIDCard({
    required String staffId,
    required String imageBase64,
    required String format,
    String? template,
  }) async {
    final response = await _dio.post(
      '/staff/$staffId/id-card',
      data: {
        'imageBase64': imageBase64,
        'format': format,
        'template': template,
      },
    );

    return response.data as Map<String, dynamic>;
  }

  /// Email ID card to staff member
  Future<void> emailIDCard({
    required String staffId,
    required IDCardSettings settings,
    String? email,
  }) async {
    await _dio.post(
      '/staff/$staffId/id-card/email',
      data: {
        'generateOnFly': false,
        'customMessage': 'Your ID card is attached.',
      },
    );
  }

  /// Download ID card template
  Future<void> downloadIDCardTemplate({
    required IDCardTemplate template,
  }) async {
    // ignore: unused_local_variable
    final response = await _dio.get(
      '/templates/id-card',
      queryParameters: {'template': template.toString().split('.').last},
      options: Options(responseType: ResponseType.bytes),
    );

    // Save template locally
    // Implementation depends on platform
  }

  /// Print all staff cards (batch operation)
  Future<void> printAllCards({required String pumpStationId}) async {
    await _dio.post('/owner/station/$pumpStationId/id-cards/print-all');
  }

  // ============================================================================
  // REPORTS
  // ============================================================================

  /// Export report (PDF or CSV)
  Future<Map<String, dynamic>> exportReport({
    required String staffId,
    required int month,
    required int year,
    required String format,
  }) async {
    final response = await _dio.post(
      '/staff/$staffId/reports/export',
      data: {'month': month, 'year': year, 'format': format},
    );

    return response.data as Map<String, dynamic>;
  }
}
