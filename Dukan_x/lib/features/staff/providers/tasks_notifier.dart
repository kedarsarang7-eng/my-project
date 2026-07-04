import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/api/api_client.dart';
import '../../../providers/tenant_config_provider.dart';
import '../data/models/task_model.dart';
import '../data/repositories/staff_management_repository.dart';
import 'staff_feature_keys.dart';

// ─── State ───────────────────────────────────────────────────────────────────

/// State for the tasks sub-area.
class StaffTasksState {
  final List<StaffTaskModel> tasks;
  final bool isLoading;
  final bool isDisabled;
  final String? error;

  const StaffTasksState({
    this.tasks = const [],
    this.isLoading = false,
    this.isDisabled = false,
    this.error,
  });

  StaffTasksState copyWith({
    List<StaffTaskModel>? tasks,
    bool? isLoading,
    bool? isDisabled,
    String? error,
  }) {
    return StaffTasksState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      isDisabled: isDisabled ?? this.isDisabled,
      error: error,
    );
  }

  /// Analytics: count tasks by status.
  Map<String, int> get countByStatus {
    final map = <String, int>{};
    for (final task in tasks) {
      map[task.status] = (map[task.status] ?? 0) + 1;
    }
    return map;
  }

  /// Analytics: count tasks by assignee.
  Map<String, int> get countByAssignee {
    final map = <String, int>{};
    for (final task in tasks) {
      map[task.assigneeId] = (map[task.assigneeId] ?? 0) + 1;
    }
    return map;
  }
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class StaffTasksNotifier extends StateNotifier<StaffTasksState> {
  final Ref _ref;
  late final StaffManagementRepository _repo;

  StaffTasksNotifier(this._ref)
    : super(const StaffTasksState(isLoading: true)) {
    _repo = StaffManagementRepository(sl<ApiClient>());
    _init();
  }

  void _init() {
    final enabled = _ref.read(featureEnabledProvider(StaffFeatureKeys.tasks));
    if (!enabled) {
      state = const StaffTasksState(isDisabled: true);
      return;
    }
    loadTasks();
  }

  /// Load tasks with optional filters.
  Future<void> loadTasks({String? assigneeId, String? status}) async {
    final enabled = _ref.read(featureEnabledProvider(StaffFeatureKeys.tasks));
    if (!enabled) {
      state = const StaffTasksState(isDisabled: true);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final tasks = await _repo.getTasks(
        assigneeId: assigneeId,
        status: status,
      );
      state = StaffTasksState(tasks: tasks);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Create a new task.
  Future<StaffTaskModel?> createTask(Map<String, dynamic> data) async {
    if (state.isDisabled) return null;
    try {
      final task = await _repo.createTask(data);
      state = state.copyWith(tasks: [...state.tasks, task]);
      return task;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Update a task (status change, add comment, etc.).
  Future<StaffTaskModel?> updateTask(
    String id,
    Map<String, dynamic> data,
  ) async {
    if (state.isDisabled) return null;
    try {
      final updated = await _repo.updateTask(id, data);
      state = state.copyWith(
        tasks: state.tasks.map((t) => t.id == id ? updated : t).toList(),
      );
      return updated;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final staffTasksProvider =
    StateNotifierProvider<StaffTasksNotifier, StaffTasksState>((ref) {
      return StaffTasksNotifier(ref);
    });
