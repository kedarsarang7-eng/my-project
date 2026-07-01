// ============================================================================
// CLINIC DASHBOARD REPOSITORY
// ============================================================================
// Repository layer for clinic dashboard API calls
// Uses Dio with JWT injection and error handling
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/di/service_locator.dart';
import '../models/clinic_dashboard_models.dart';

final clinicDashboardRepositoryProvider = Provider<ClinicDashboardRepository>(
  (_) => ClinicDashboardRepository(),
);

class ClinicDashboardRepository {
  final ApiClient _api;

  ClinicDashboardRepository({ApiClient? api})
      : _api = api ?? sl<ApiClient>();

  // Base path for clinic API
  String get _basePath => '/clinic';

  // ============================================================================
  // LICENSE VALIDATION
  // ============================================================================

  Future<ClinicLicense> validateLicense(String licenseKey) async {
    try {
      final response = await _api.post(
        '$_basePath/license/validate',
        body: {'licenseKey': licenseKey},
      );
      if (response.isSuccess && response.data != null) {
        return ClinicLicense.fromJson(response.data!);
      }
      if (response.statusCode == 403) {
        return ClinicLicense(valid: false, status: 'invalid', error: 'Invalid or expired license');
      }
      throw ClinicDashboardException('Failed to validate license', type: ClinicDashboardErrorType.unknown);
    } catch (e) {
      if (e is ClinicDashboardException) rethrow;
      throw ClinicDashboardException('Failed to validate license', type: ClinicDashboardErrorType.network);
    }
  }

  // ============================================================================
  // DASHBOARD OVERVIEW
  // ============================================================================

  Future<DashboardOverview> getDashboardOverview(String date) async {
    final r = await _api.get('$_basePath/dashboard/overview', queryParams: {'date': date});
    if (r.isSuccess && r.data != null) return DashboardOverview.fromJson(r.data!);
    throw ClinicDashboardException('Failed to load dashboard overview', type: ClinicDashboardErrorType.unknown);
  }

  // ============================================================================
  // APPOINTMENTS
  // ============================================================================

  Future<AppointmentList> getAppointments({
    required String date,
    String? doctorId,
    String? status,
  }) async {
    final params = <String, String>{'date': date};
    if (doctorId != null) params['doctorId'] = doctorId;
    if (status != null) params['status'] = status;
    final r = await _api.get('$_basePath/appointments', queryParams: params);
    if (r.isSuccess && r.data != null) return AppointmentList.fromJson(r.data!);
    throw ClinicDashboardException('Failed to load appointments', type: ClinicDashboardErrorType.unknown);
  }

  // ============================================================================
  // PATIENT INSIGHTS
  // ============================================================================

  Future<PatientInsights> getPatientInsights() async {
    final r = await _api.get('$_basePath/patients/insights');
    if (r.isSuccess && r.data != null) return PatientInsights.fromJson(r.data!);
    throw ClinicDashboardException('Failed to load patient insights', type: ClinicDashboardErrorType.unknown);
  }

  // ============================================================================
  // STAFF AVAILABILITY
  // ============================================================================

  Future<StaffAvailability> getStaffAvailability() async {
    final r = await _api.get('$_basePath/staff/availability');
    if (r.isSuccess && r.data != null) return StaffAvailability.fromJson(r.data!);
    throw ClinicDashboardException('Failed to load staff availability', type: ClinicDashboardErrorType.unknown);
  }

  // ============================================================================
  // ROOMS STATUS
  // ============================================================================

  Future<RoomsStatus> getRoomsStatus() async {
    final r = await _api.get('$_basePath/rooms');
    if (r.isSuccess && r.data != null) return RoomsStatus.fromJson(r.data!);
    throw ClinicDashboardException('Failed to load room status', type: ClinicDashboardErrorType.unknown);
  }

  // ============================================================================
  // BILLING SUMMARY
  // ============================================================================

  Future<BillingSummary> getBillingSummary({required String period}) async {
    final r = await _api.get('$_basePath/billing/summary', queryParams: {'period': period});
    if (r.isSuccess && r.data != null) return BillingSummary.fromJson(r.data!);
    if (r.statusCode == 403) return BillingSummary.empty;
    throw ClinicDashboardException('Failed to load billing summary', type: ClinicDashboardErrorType.unknown);
  }

  // ============================================================================
  // INVENTORY ALERTS
  // ============================================================================

  Future<InventoryAlerts> getInventoryAlerts() async {
    final r = await _api.get('$_basePath/inventory/alerts');
    if (r.isSuccess && r.data != null) return InventoryAlerts.fromJson(r.data!);
    throw ClinicDashboardException('Failed to load inventory alerts', type: ClinicDashboardErrorType.unknown);
  }

  // ============================================================================
  // WEEKLY TRENDS
  // ============================================================================

  Future<WeeklyAppointmentTrends> getWeeklyTrends({required int weeks}) async {
    final r = await _api.get('$_basePath/analytics/performance', queryParams: {'weeks': weeks.toString()});
    if (r.isSuccess && r.data != null) return WeeklyAppointmentTrends.fromJson(r.data!);
    throw ClinicDashboardException('Failed to load appointment trends', type: ClinicDashboardErrorType.unknown);
  }

  // ============================================================================
  // WAIT TIME
  // ============================================================================

  Future<WaitTimeInfo> getWaitTime(String date) async {
    final r = await _api.get('$_basePath/appointments/wait-time', queryParams: {'date': date});
    if (r.isSuccess && r.data != null) return WaitTimeInfo.fromJson(r.data!);
    throw ClinicDashboardException('Failed to load wait time', type: ClinicDashboardErrorType.unknown);
  }

  // ============================================================================
  // ERROR HANDLING
  // ============================================================================

}

// ============================================================================
// CUSTOM EXCEPTION
// ============================================================================

class ClinicDashboardException implements Exception {
  final String message;
  final ClinicDashboardErrorType type;

  ClinicDashboardException(
    this.message, {
    this.type = ClinicDashboardErrorType.unknown,
  });

  bool get isRetryable =>
      type == ClinicDashboardErrorType.timeout ||
      type == ClinicDashboardErrorType.network ||
      type == ClinicDashboardErrorType.rateLimited;

  @override
  String toString() => 'ClinicDashboardException: $message (type: $type)';
}

enum ClinicDashboardErrorType {
  timeout,
  network,
  unauthorized,
  forbidden,
  notFound,
  rateLimited,
  unknown,
}
