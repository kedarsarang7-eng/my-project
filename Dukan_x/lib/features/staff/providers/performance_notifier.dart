import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/api/api_client.dart';
import '../../../providers/tenant_config_provider.dart';
import '../data/models/performance_score_model.dart';
import '../data/models/commission_rule_model.dart';
import '../data/repositories/staff_management_repository.dart';
import 'staff_feature_keys.dart';

// ─── State ───────────────────────────────────────────────────────────────────

/// State for the performance and commission sub-area.
class PerformanceState {
  final List<PerformanceScoreModel> scores;
  final List<CommissionRuleModel> commissionRules;
  final bool isLoading;
  final bool isDisabled;
  final String? error;

  const PerformanceState({
    this.scores = const [],
    this.commissionRules = const [],
    this.isLoading = false,
    this.isDisabled = false,
    this.error,
  });

  PerformanceState copyWith({
    List<PerformanceScoreModel>? scores,
    List<CommissionRuleModel>? commissionRules,
    bool? isLoading,
    bool? isDisabled,
    String? error,
  }) {
    return PerformanceState(
      scores: scores ?? this.scores,
      commissionRules: commissionRules ?? this.commissionRules,
      isLoading: isLoading ?? this.isLoading,
      isDisabled: isDisabled ?? this.isDisabled,
      error: error,
    );
  }
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class PerformanceNotifier extends StateNotifier<PerformanceState> {
  final Ref _ref;
  late final StaffManagementRepository _repo;

  PerformanceNotifier(this._ref)
    : super(const PerformanceState(isLoading: true)) {
    _repo = StaffManagementRepository(sl<ApiClient>());
    _init();
  }

  void _init() {
    final enabled = _ref.read(
      featureEnabledProvider(StaffFeatureKeys.performance),
    );
    if (!enabled) {
      state = const PerformanceState(isDisabled: true);
      return;
    }
    loadAll();
  }

  /// Load performance scores and commission rules.
  Future<void> loadAll({String? employeeId, String? period}) async {
    final enabled = _ref.read(
      featureEnabledProvider(StaffFeatureKeys.performance),
    );
    if (!enabled) {
      state = const PerformanceState(isDisabled: true);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        _repo.getPerformanceScores(employeeId: employeeId, period: period),
        _repo.getCommissionRules(),
      ]);

      state = PerformanceState(
        scores: results[0] as List<PerformanceScoreModel>,
        commissionRules: results[1] as List<CommissionRuleModel>,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Load scores for a specific employee/period.
  Future<void> loadScores({String? employeeId, String? period}) async {
    if (state.isDisabled) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final scores = await _repo.getPerformanceScores(
        employeeId: employeeId,
        period: period,
      );
      state = state.copyWith(scores: scores, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Create or update a commission rule.
  Future<CommissionRuleModel?> createCommissionRule(
    Map<String, dynamic> data,
  ) async {
    if (state.isDisabled) return null;
    try {
      final rule = await _repo.createCommissionRule(data);
      state = state.copyWith(commissionRules: [...state.commissionRules, rule]);
      return rule;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Update an existing commission rule.
  Future<CommissionRuleModel?> updateCommissionRule(
    String id,
    Map<String, dynamic> data,
  ) async {
    if (state.isDisabled) return null;
    try {
      final updated = await _repo.updateCommissionRule(id, data);
      state = state.copyWith(
        commissionRules: state.commissionRules
            .map((r) => r.id == id ? updated : r)
            .toList(),
      );
      return updated;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final performanceProvider =
    StateNotifierProvider<PerformanceNotifier, PerformanceState>((ref) {
      return PerformanceNotifier(ref);
    });
