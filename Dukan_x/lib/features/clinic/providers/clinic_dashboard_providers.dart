// ============================================================================
// CLINIC DASHBOARD RIVERPOD PROVIDERS
// ============================================================================
// State management for clinic dashboard using Riverpod
// Auto-refresh every 5 minutes
// Error handling with retry mechanism
// ============================================================================

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/clinic_dashboard_models.dart';
import '../services/clinic_dashboard_repository.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';

// ============================================================================
// LICENSE VALIDATION PROVIDER
// ============================================================================

final clinicLicenseProvider = FutureProvider.family<ClinicLicense, String>((
  ref,
  licenseKey,
) async {
  final repository = ref.read(clinicDashboardRepositoryProvider);
  return repository.validateLicense(licenseKey);
});

// ============================================================================
// DASHBOARD OVERVIEW PROVIDER (Auto-refresh)
// ============================================================================

final dashboardOverviewProvider =
    StreamProvider.family<DashboardOverview, String>((ref, date) async* {
      final repository = ref.read(clinicDashboardRepositoryProvider);
      final session = sl<SessionManager>().currentSession;

      // Only fetch if authenticated
      if (!session.isAuthenticated) {
        yield DashboardOverview.empty;
        return;
      }

      // Initial fetch
      try {
        final data = await repository.getDashboardOverview(date);
        yield data;
      } catch (e) {
        yield DashboardOverview.empty;
      }

      // Auto-refresh every 5 minutes
      await for (final _ in Stream.periodic(const Duration(minutes: 5))) {
        try {
          final data = await repository.getDashboardOverview(date);
          yield data;
        } catch (e) {
          // Keep previous data on error
        }
      }
    });

// ============================================================================
// APPOINTMENTS PROVIDER
// ============================================================================

final appointmentsProvider =
    FutureProvider.family<AppointmentList, AppointmentsFilter>((
      ref,
      filter,
    ) async {
      final repository = ref.read(clinicDashboardRepositoryProvider);
      return repository.getAppointments(
        date: filter.date,
        doctorId: filter.doctorId,
        status: filter.status,
      );
    });

class AppointmentsFilter {
  final String date;
  final String? doctorId;
  final String? status;

  const AppointmentsFilter({required this.date, this.doctorId, this.status});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppointmentsFilter &&
        other.date == date &&
        other.doctorId == doctorId &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(date, doctorId, status);
}

// ============================================================================
// PATIENT INSIGHTS PROVIDER
// ============================================================================

final patientInsightsProvider = FutureProvider<PatientInsights>((ref) async {
  final repository = ref.read(clinicDashboardRepositoryProvider);
  return repository.getPatientInsights();
});

// ============================================================================
// STAFF AVAILABILITY PROVIDER (Auto-refresh)
// ============================================================================

final staffAvailabilityProvider = StreamProvider<StaffAvailability>((
  ref,
) async* {
  final repository = ref.read(clinicDashboardRepositoryProvider);
  final session = sl<SessionManager>().currentSession;

  if (!session.isAuthenticated) {
    yield StaffAvailability.empty;
    return;
  }

  // Initial fetch
  try {
    final data = await repository.getStaffAvailability();
    yield data;
  } catch (e) {
    yield StaffAvailability.empty;
  }

  // Auto-refresh every 2 minutes (staff status changes frequently)
  await for (final _ in Stream.periodic(const Duration(minutes: 2))) {
    try {
      final data = await repository.getStaffAvailability();
      yield data;
    } catch (e) {
      // Keep previous data on error
    }
  }
});

// ============================================================================
// ROOMS STATUS PROVIDER (Auto-refresh)
// ============================================================================

final roomsStatusProvider = StreamProvider<RoomsStatus>((ref) async* {
  final repository = ref.read(clinicDashboardRepositoryProvider);
  final session = sl<SessionManager>().currentSession;

  if (!session.isAuthenticated) {
    yield RoomsStatus.empty;
    return;
  }

  // Initial fetch
  try {
    final data = await repository.getRoomsStatus();
    yield data;
  } catch (e) {
    yield RoomsStatus.empty;
  }

  // Auto-refresh every 1 minute (rooms change frequently)
  await for (final _ in Stream.periodic(const Duration(minutes: 1))) {
    try {
      final data = await repository.getRoomsStatus();
      yield data;
    } catch (e) {
      // Keep previous data on error
    }
  }
});

// ============================================================================
// BILLING SUMMARY PROVIDER
// ============================================================================

final billingSummaryProvider = FutureProvider.family<BillingSummary, String?>((
  ref,
  period,
) async {
  final repository = ref.read(clinicDashboardRepositoryProvider);
  return repository.getBillingSummary(period: period ?? 'monthly');
});

// ============================================================================
// INVENTORY ALERTS PROVIDER
// ============================================================================

final inventoryAlertsProvider = FutureProvider<InventoryAlerts>((ref) async {
  final repository = ref.read(clinicDashboardRepositoryProvider);
  return repository.getInventoryAlerts();
});

// ============================================================================
// WEEKLY TRENDS PROVIDER
// ============================================================================

final weeklyTrendsProvider =
    FutureProvider.family<WeeklyAppointmentTrends, int>((ref, weeks) async {
      final repository = ref.read(clinicDashboardRepositoryProvider);
      return repository.getWeeklyTrends(weeks: weeks);
    });

// ============================================================================
// WAIT TIME PROVIDER (Auto-refresh)
// ============================================================================

final waitTimeProvider = StreamProvider.family<WaitTimeInfo, String>((
  ref,
  date,
) async* {
  final repository = ref.read(clinicDashboardRepositoryProvider);
  final session = sl<SessionManager>().currentSession;

  if (!session.isAuthenticated) {
    yield WaitTimeInfo.empty;
    return;
  }

  // Initial fetch
  try {
    final data = await repository.getWaitTime(date);
    yield data;
  } catch (e) {
    yield WaitTimeInfo.empty;
  }

  // Auto-refresh every 30 seconds (wait time changes quickly)
  await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
    try {
      final data = await repository.getWaitTime(date);
      yield data;
    } catch (e) {
      // Keep previous data on error
    }
  }
});

// ============================================================================
// COMBINED DASHBOARD STATE PROVIDER
// ============================================================================

final combinedDashboardStateProvider =
    Provider<AsyncValue<CombinedDashboardState>>((ref) {
      final date = DateTime.now().toIso8601String().split('T')[0];

      final overview = ref.watch(dashboardOverviewProvider(date));
      final appointments = ref.watch(
        appointmentsProvider(AppointmentsFilter(date: date)),
      );
      final patientInsights = ref.watch(patientInsightsProvider);
      final staffAvailability = ref.watch(staffAvailabilityProvider);
      final roomsStatus = ref.watch(roomsStatusProvider);
      final billingSummary = ref.watch(billingSummaryProvider('monthly'));
      final inventoryAlerts = ref.watch(inventoryAlertsProvider);
      final weeklyTrends = ref.watch(weeklyTrendsProvider(2));
      final waitTime = ref.watch(waitTimeProvider(date));

      if (overview.hasError ||
          appointments.hasError ||
          patientInsights.hasError ||
          staffAvailability.hasError ||
          roomsStatus.hasError) {
        return AsyncValue.error(
          overview.error ?? appointments.error ?? 'Dashboard load error',
          StackTrace.current,
        );
      }

      if (overview.hasValue &&
          appointments.hasValue &&
          patientInsights.hasValue &&
          staffAvailability.hasValue &&
          roomsStatus.hasValue) {
        return AsyncValue.data(
          CombinedDashboardState(
            overview: overview.value!,
            appointments: appointments.value!,
            patientInsights: patientInsights.value!,
            staffAvailability: staffAvailability.value!,
            roomsStatus: roomsStatus.value!,
            billingSummary: billingSummary.value ?? BillingSummary.empty,
            inventoryAlerts: inventoryAlerts.value ?? InventoryAlerts.empty,
            weeklyTrends: weeklyTrends.value ?? WeeklyAppointmentTrends.empty,
            waitTime: waitTime.value ?? WaitTimeInfo.empty,
            isLoading:
                overview.isLoading ||
                appointments.isLoading ||
                patientInsights.isLoading ||
                staffAvailability.isLoading ||
                roomsStatus.isLoading,
          ),
        );
      }

      return const AsyncValue.loading();
    });

class CombinedDashboardState {
  final DashboardOverview overview;
  final AppointmentList appointments;
  final PatientInsights patientInsights;
  final StaffAvailability staffAvailability;
  final RoomsStatus roomsStatus;
  final BillingSummary billingSummary;
  final InventoryAlerts inventoryAlerts;
  final WeeklyAppointmentTrends weeklyTrends;
  final WaitTimeInfo waitTime;
  final bool isLoading;

  const CombinedDashboardState({
    required this.overview,
    required this.appointments,
    required this.patientInsights,
    required this.staffAvailability,
    required this.roomsStatus,
    required this.billingSummary,
    required this.inventoryAlerts,
    required this.weeklyTrends,
    required this.waitTime,
    required this.isLoading,
  });

  static const empty = CombinedDashboardState(
    overview: DashboardOverview.empty,
    appointments: AppointmentList.empty,
    patientInsights: PatientInsights.empty,
    staffAvailability: StaffAvailability.empty,
    roomsStatus: RoomsStatus.empty,
    billingSummary: BillingSummary.empty,
    inventoryAlerts: InventoryAlerts.empty,
    weeklyTrends: WeeklyAppointmentTrends.empty,
    waitTime: WaitTimeInfo.empty,
    isLoading: false,
  );
}

// ============================================================================
// ROLE-BASED WIDGET VISIBILITY PROVIDER
// ============================================================================

/// Derives the current clinic staff role from the unified UserRole system,
/// falling back to SessionManager metadata strings for legacy compatibility.
///
/// Integration bridge: Maps [UserRole.doctor], [UserRole.receptionist],
/// [UserRole.nurse] (from the main RBAC system) to the corresponding
/// [ClinicRole] used by clinic widgets. Also maps [UserRole.owner] to
/// [ClinicRole.admin] for clinic contexts.
///
/// Fallback: if effectiveRole is generic (staff/manager/etc.), tries the
/// metadata 'staffRole'/'clinicRole' string for legacy clinic role resolution.
final clinicRoleProvider = Provider<ClinicRole?>((ref) {
  final session = sl<SessionManager>().currentSession;
  if (!session.isAuthenticated) return null;

  // Primary: derive from the unified effectiveRole (new system).
  final effectiveRole = session.effectiveRole;
  final clinicRole = clinicRoleFromUserRole(effectiveRole);
  if (clinicRole != null) return clinicRole;

  // Fallback: legacy metadata string lookup.
  final meta = session.metadata;
  if (meta == null) return null;
  final roleStr =
      meta['staffRole'] as String? ?? meta['clinicRole'] as String? ?? '';
  if (roleStr.isEmpty) return null;
  return ClinicRole.fromString(roleStr);
});

/// Maps a [UserRole] to the corresponding [ClinicRole], or null if the
/// UserRole has no direct clinic-role equivalent.
///
/// This function is the single integration point between the main RBAC
/// system and the clinic widget-level role guard. It can be used by any
/// code that needs to check clinical permissions (e.g., task 5.2 gating
/// diagnosis/private notes on visit_screen).
ClinicRole? clinicRoleFromUserRole(UserRole role) {
  switch (role) {
    case UserRole.doctor:
      return ClinicRole.doctor;
    case UserRole.receptionist:
      return ClinicRole.receptionist;
    case UserRole.nurse:
      return ClinicRole.nurse;
    case UserRole.owner:
      // Clinic owners get admin-level access to all clinical content.
      return ClinicRole.admin;
    default:
      return null;
  }
}

/// Whether the given [ClinicRole] has access to clinical content
/// (diagnosis, private notes, prescription authoring).
///
/// Only [ClinicRole.doctor] and [ClinicRole.admin] may view/edit diagnosis
/// and private clinical notes. Used by task 5.2 to gate visit_screen content.
bool hasClinicalContentAccess(ClinicRole? role) {
  return role == ClinicRole.doctor || role == ClinicRole.admin;
}

/// Provider that exposes whether the current user can access clinical content
/// (diagnosis and private notes). Consumed by visit_screen role gates.
final canAccessClinicalContentProvider = Provider<bool>((ref) {
  final clinicRole = ref.watch(clinicRoleProvider);
  return hasClinicalContentAccess(clinicRole);
});

final widgetVisibilityProvider = Provider<WidgetVisibilityState>((ref) {
  final role = ref.watch(clinicRoleProvider);
  return WidgetVisibilityState.fromRole(role);
});

class WidgetVisibilityState {
  final bool canViewRevenue;
  final bool canViewStaffManagement;
  final bool canViewBilling;
  final bool canViewInventory;
  final bool canViewAllPatients;
  final bool canViewAnalytics;
  final bool canManageAppointments;
  final bool canPrescribe;

  const WidgetVisibilityState({
    required this.canViewRevenue,
    required this.canViewStaffManagement,
    required this.canViewBilling,
    required this.canViewInventory,
    required this.canViewAllPatients,
    required this.canViewAnalytics,
    required this.canManageAppointments,
    required this.canPrescribe,
  });

  factory WidgetVisibilityState.fromRole(ClinicRole? role) {
    switch (role) {
      case ClinicRole.admin:
        return const WidgetVisibilityState(
          canViewRevenue: true,
          canViewStaffManagement: true,
          canViewBilling: true,
          canViewInventory: true,
          canViewAllPatients: true,
          canViewAnalytics: true,
          canManageAppointments: true,
          canPrescribe: true,
        );
      case ClinicRole.doctor:
        return const WidgetVisibilityState(
          canViewRevenue: false,
          canViewStaffManagement: false,
          canViewBilling: false,
          canViewInventory: true,
          canViewAllPatients: true,
          canViewAnalytics: true,
          canManageAppointments: true,
          canPrescribe: true,
        );
      case ClinicRole.nurse:
        return const WidgetVisibilityState(
          canViewRevenue: false,
          canViewStaffManagement: false,
          canViewBilling: false,
          canViewInventory: true,
          canViewAllPatients: true,
          canViewAnalytics: false,
          canManageAppointments: false,
          canPrescribe: false,
        );
      case ClinicRole.receptionist:
        return const WidgetVisibilityState(
          canViewRevenue: false,
          canViewStaffManagement: false,
          canViewBilling: true,
          canViewInventory: false,
          canViewAllPatients: true,
          canViewAnalytics: false,
          canManageAppointments: true,
          canPrescribe: false,
        );
      default:
        return const WidgetVisibilityState(
          canViewRevenue: false,
          canViewStaffManagement: false,
          canViewBilling: false,
          canViewInventory: false,
          canViewAllPatients: false,
          canViewAnalytics: false,
          canManageAppointments: false,
          canPrescribe: false,
        );
    }
  }
}
