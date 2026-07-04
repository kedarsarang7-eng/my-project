import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/api/api_client.dart';
import '../../../providers/tenant_config_provider.dart';
import '../data/models/attendance_event_model.dart';
import '../data/models/shift_model.dart';
import '../data/models/roster_model.dart';
import '../data/repositories/staff_management_repository.dart';
import 'staff_feature_keys.dart';

// ─── State ───────────────────────────────────────────────────────────────────

/// State for the attendance sub-area (events, shifts, rosters).
class AttendanceState {
  final List<AttendanceEventModel> events;
  final List<ShiftModel> shifts;
  final List<RosterModel> rosters;
  final bool isLoading;
  final bool isDisabled;
  final String? error;

  const AttendanceState({
    this.events = const [],
    this.shifts = const [],
    this.rosters = const [],
    this.isLoading = false,
    this.isDisabled = false,
    this.error,
  });

  AttendanceState copyWith({
    List<AttendanceEventModel>? events,
    List<ShiftModel>? shifts,
    List<RosterModel>? rosters,
    bool? isLoading,
    bool? isDisabled,
    String? error,
  }) {
    return AttendanceState(
      events: events ?? this.events,
      shifts: shifts ?? this.shifts,
      rosters: rosters ?? this.rosters,
      isLoading: isLoading ?? this.isLoading,
      isDisabled: isDisabled ?? this.isDisabled,
      error: error,
    );
  }
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class AttendanceNotifier extends StateNotifier<AttendanceState> {
  final Ref _ref;
  late final StaffManagementRepository _repo;

  AttendanceNotifier(this._ref)
    : super(const AttendanceState(isLoading: true)) {
    _repo = StaffManagementRepository(sl<ApiClient>());
    _init();
  }

  void _init() {
    final enabled = _ref.read(
      featureEnabledProvider(StaffFeatureKeys.attendance),
    );
    if (!enabled) {
      state = const AttendanceState(isDisabled: true);
      return;
    }
    loadAll();
  }

  /// Load attendance events, shifts, and rosters.
  Future<void> loadAll({String? employeeId, String? from, String? to}) async {
    final enabled = _ref.read(
      featureEnabledProvider(StaffFeatureKeys.attendance),
    );
    if (!enabled) {
      state = const AttendanceState(isDisabled: true);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        _repo.getAttendanceEvents(employeeId: employeeId, from: from, to: to),
        _repo.getShifts(),
        _repo.getRosters(),
      ]);

      state = AttendanceState(
        events: results[0] as List<AttendanceEventModel>,
        shifts: results[1] as List<ShiftModel>,
        rosters: results[2] as List<RosterModel>,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Record a new attendance event (check-in/check-out).
  Future<AttendanceEventModel?> recordEvent(Map<String, dynamic> data) async {
    if (state.isDisabled) return null;
    try {
      final event = await _repo.createAttendanceEvent(data);
      state = state.copyWith(events: [event, ...state.events]);
      return event;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Load events for a specific employee and date range.
  Future<void> loadEventsFor({
    required String employeeId,
    String? from,
    String? to,
  }) async {
    if (state.isDisabled) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final events = await _repo.getAttendanceEvents(
        employeeId: employeeId,
        from: from,
        to: to,
      );
      state = state.copyWith(events: events, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final attendanceProvider =
    StateNotifierProvider<AttendanceNotifier, AttendanceState>((ref) {
      return AttendanceNotifier(ref);
    });
