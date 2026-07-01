// ============================================================================
// CONSOLIDATED CLINIC DASHBOARD DATA PROVIDER
// ============================================================================
// Single Riverpod FutureProvider that fetches ALL dashboard data in one shot
// and caches it. This eliminates the previous pattern of multiple independent
// FutureBuilders — each hitting the DB on every widget build — which caused
// redundant queries and potential UI flicker on rebuilds.
//
// The provider is `autoDispose` so it releases when the dashboard screen is
// popped, and `family`-parameterized by doctorId for tenant scoping.
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/doctor_dashboard_repository.dart';
import '../../../../core/di/service_locator.dart';

/// Consolidated snapshot of all data needed by `DoctorDashboardScreen`.
///
/// Fetched once per provider evaluation and cached until invalidated or
/// disposed. Contains every piece of data previously fetched by individual
/// FutureBuilders.
class ClinicDashboardData {
  final Map<String, int> patientStats;
  final Map<String, String> smartInsights;
  final Map<String, int> weeklyAnalytics;
  final Map<String, int> monthlyAnalytics;
  final List<Map<String, dynamic>> alerts;

  const ClinicDashboardData({
    required this.patientStats,
    required this.smartInsights,
    required this.weeklyAnalytics,
    required this.monthlyAnalytics,
    required this.alerts,
  });
}

/// Consolidated provider that fetches all doctor-dashboard data once per
/// [doctorId] and caches the result. Replaces the five independent
/// FutureBuilders that previously re-ran on every build.
///
/// Usage in the screen:
/// ```dart
/// final asyncData = ref.watch(clinicDashboardDataProvider(doctorId));
/// asyncData.when(data: ..., loading: ..., error: ...);
/// ```
///
/// Auto-disposed when the screen leaves the widget tree, freeing memory.
final clinicDashboardDataProvider = FutureProvider.autoDispose
    .family<ClinicDashboardData, String>((ref, doctorId) async {
      final repository = sl<DoctorDashboardRepository>();

      // Run all queries concurrently for maximum throughput.
      final results = await Future.wait([
        repository.getPatientStats(doctorId),
        repository.getSmartInsights(doctorId),
        repository.getWeeklyAnalytics(doctorId),
        repository.getMonthlyAnalytics(doctorId),
        repository.getDashboardAlerts(doctorId),
      ]);

      return ClinicDashboardData(
        patientStats: results[0] as Map<String, int>,
        smartInsights: results[1] as Map<String, String>,
        weeklyAnalytics: results[2] as Map<String, int>,
        monthlyAnalytics: results[3] as Map<String, int>,
        alerts: results[4] as List<Map<String, dynamic>>,
      );
    });
