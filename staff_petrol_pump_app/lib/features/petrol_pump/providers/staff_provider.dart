import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/staff_repository.dart';
import 'license_provider.dart';

/// Staff list state
class StaffListState {
  final List<StaffMember> staff;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int currentPage;
  final bool hasMore;
  final String? filterStatus;
  final String? filterRole;

  const StaffListState({
    this.staff = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.currentPage = 1,
    this.hasMore = true,
    this.filterStatus,
    this.filterRole,
  });

  StaffListState copyWith({
    List<StaffMember>? staff,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? currentPage,
    bool? hasMore,
    String? filterStatus,
    String? filterRole,
  }) {
    return StaffListState(
      staff: staff ?? this.staff,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      filterStatus: filterStatus ?? this.filterStatus,
      filterRole: filterRole ?? this.filterRole,
    );
  }

  List<StaffMember> get activeStaff => staff.where((s) => s.isActive).toList();
  List<StaffMember> get inactiveStaff => staff.where((s) => !s.isActive).toList();
  
  int get totalStaffCount => staff.length;
  int get activeStaffCount => activeStaff.length;
  double get totalStaffRevenue => staff.fold(0, (sum, s) => sum + s.totalRevenue);
  int get totalTransactions => staff.fold(0, (sum, s) => sum + s.transactionsCount);
}

/// Staff list notifier
class StaffListNotifier extends StateNotifier<StaffListState> {
  final Ref _ref;
  final StaffRepository _repository = StaffRepository();

  StaffListNotifier(this._ref) : super(const StaffListState());

  /// Load staff list
  Future<void> loadStaff({bool refresh = false}) async {
    if (state.isLoading) return;

    final license = _ref.read(licenseProvider).profile;
    if (license == null) {
      state = state.copyWith(error: 'No license profile available');
      return;
    }

    state = state.copyWith(
      isLoading: true,
      error: null,
      currentPage: refresh ? 1 : state.currentPage,
    );

    try {
      final staff = await _repository.getStaffList(
        status: state.filterStatus,
        role: state.filterRole,
        page: refresh ? 1 : state.currentPage,
        limit: 20,
      );

      state = state.copyWith(
        staff: refresh ? staff : [...state.staff, ...staff],
        isLoading: false,
        hasMore: staff.length >= 20,
        currentPage: refresh ? 2 : state.currentPage + 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load more staff (pagination)
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final staff = await _repository.getStaffList(
        status: state.filterStatus,
        role: state.filterRole,
        page: state.currentPage,
        limit: 20,
      );

      state = state.copyWith(
        staff: [...state.staff, ...staff],
        isLoadingMore: false,
        hasMore: staff.length >= 20,
        currentPage: state.currentPage + 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh staff list
  Future<void> refresh() async {
    await loadStaff(refresh: true);
  }

  /// Set filter status
  void setFilterStatus(String? status) {
    state = state.copyWith(filterStatus: status, currentPage: 1, staff: []);
    loadStaff(refresh: true);
  }

  /// Set filter role
  void setFilterRole(String? role) {
    state = state.copyWith(filterRole: role, currentPage: 1, staff: []);
    loadStaff(refresh: true);
  }

  /// Invite new staff
  Future<StaffInvitationResponse?> inviteStaff(StaffInvitation invitation) async {
    try {
      final response = await _repository.inviteStaff(invitation);
      
      // Refresh list after inviting
      await refresh();
      
      return response;
    } catch (e) {
      debugPrint('Failed to invite staff: $e');
      return null;
    }
  }

  /// Deactivate staff
  Future<bool> deactivateStaff(String staffId) async {
    try {
      await _repository.deactivateStaff(staffId);
      
      // Update local state
      final updatedStaff = state.staff.map((s) {
        if (s.id == staffId) {
          return StaffMember(
            id: s.id,
            name: s.name,
            email: s.email,
            phone: s.phone,
            role: s.role,
            status: 'inactive',
            createdAt: s.createdAt,
            lastActiveAt: s.lastActiveAt,
            transactionsCount: s.transactionsCount,
            totalRevenue: s.totalRevenue,
            avatarUrl: s.avatarUrl,
          );
        }
        return s;
      }).toList();
      
      state = state.copyWith(staff: updatedStaff);
      return true;
    } catch (e) {
      debugPrint('Failed to deactivate staff: $e');
      return false;
    }
  }

  /// Reactivate staff
  Future<bool> reactivateStaff(String staffId) async {
    try {
      await _repository.reactivateStaff(staffId);
      
      // Update local state
      final updatedStaff = state.staff.map((s) {
        if (s.id == staffId) {
          return StaffMember(
            id: s.id,
            name: s.name,
            email: s.email,
            phone: s.phone,
            role: s.role,
            status: 'active',
            createdAt: s.createdAt,
            lastActiveAt: s.lastActiveAt,
            transactionsCount: s.transactionsCount,
            totalRevenue: s.totalRevenue,
            avatarUrl: s.avatarUrl,
          );
        }
        return s;
      }).toList();
      
      state = state.copyWith(staff: updatedStaff);
      return true;
    } catch (e) {
      debugPrint('Failed to reactivate staff: $e');
      return false;
    }
  }

  /// Update staff role
  Future<bool> updateStaffRole(String staffId, String newRole) async {
    try {
      await _repository.updateStaff(staffId, role: newRole);
      
      // Update local state
      final updatedStaff = state.staff.map((s) {
        if (s.id == staffId) {
          return StaffMember(
            id: s.id,
            name: s.name,
            email: s.email,
            phone: s.phone,
            role: newRole,
            status: s.status,
            createdAt: s.createdAt,
            lastActiveAt: s.lastActiveAt,
            transactionsCount: s.transactionsCount,
            totalRevenue: s.totalRevenue,
            avatarUrl: s.avatarUrl,
          );
        }
        return s;
      }).toList();
      
      state = state.copyWith(staff: updatedStaff);
      return true;
    } catch (e) {
      debugPrint('Failed to update staff role: $e');
      return false;
    }
  }
}

/// Provider for staff list
final staffListProvider = StateNotifierProvider<StaffListNotifier, StaffListState>((ref) {
  return StaffListNotifier(ref);
});

/// Provider for active staff only
final activeStaffProvider = Provider<List<StaffMember>>((ref) {
  return ref.watch(staffListProvider).activeStaff;
});

/// Provider for staff count summary
final staffSummaryProvider = Provider<Map<String, dynamic>>((ref) {
  final state = ref.watch(staffListProvider);
  return {
    'total': state.totalStaffCount,
    'active': state.activeStaffCount,
    'totalRevenue': state.totalStaffRevenue,
    'totalTransactions': state.totalTransactions,
  };
});

/// Individual staff details state
class StaffDetailsState {
  final StaffMember? staff;
  final List<Map<String, dynamic>> transactions;
  final bool isLoading;
  final bool isLoadingTransactions;
  final String? error;

  const StaffDetailsState({
    this.staff,
    this.transactions = const [],
    this.isLoading = false,
    this.isLoadingTransactions = false,
    this.error,
  });

  StaffDetailsState copyWith({
    StaffMember? staff,
    List<Map<String, dynamic>>? transactions,
    bool? isLoading,
    bool? isLoadingTransactions,
    String? error,
  }) {
    return StaffDetailsState(
      staff: staff ?? this.staff,
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      isLoadingTransactions: isLoadingTransactions ?? this.isLoadingTransactions,
      error: error,
    );
  }
}

/// Staff details notifier
class StaffDetailsNotifier extends StateNotifier<StaffDetailsState> {
  final StaffRepository _repository = StaffRepository();

  StaffDetailsNotifier() : super(const StaffDetailsState());

  /// Load staff details
  Future<void> loadStaffDetails(String staffId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final staff = await _repository.getStaffDetails(staffId);
      state = state.copyWith(
        staff: staff,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load staff transactions
  Future<void> loadTransactions(
    String staffId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    state = state.copyWith(isLoadingTransactions: true);

    try {
      final transactions = await _repository.getStaffTransactions(
        staffId,
        startDate: startDate,
        endDate: endDate,
        page: 1,
        limit: 50,
      );
      
      state = state.copyWith(
        transactions: transactions,
        isLoadingTransactions: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingTransactions: false,
        error: e.toString(),
      );
    }
  }

  /// Clear state
  void clear() {
    state = const StaffDetailsState();
  }
}

/// Provider for staff details
final staffDetailsProvider = StateNotifierProvider<StaffDetailsNotifier, StaffDetailsState>((ref) {
  return StaffDetailsNotifier();
});

/// Staff performance state
class StaffPerformanceState {
  final List<StaffPerformance> performance;
  final bool isLoading;
  final String? error;
  final DateTime? startDate;
  final DateTime? endDate;

  const StaffPerformanceState({
    this.performance = const [],
    this.isLoading = false,
    this.error,
    this.startDate,
    this.endDate,
  });

  StaffPerformanceState copyWith({
    List<StaffPerformance>? performance,
    bool? isLoading,
    String? error,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return StaffPerformanceState(
      performance: performance ?? this.performance,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }

  StaffPerformance? get topPerformer => performance.isNotEmpty
      ? performance.reduce((a, b) => a.totalRevenue > b.totalRevenue ? a : b)
      : null;

  double get totalRevenue => performance.fold(0, (sum, p) => sum + p.totalRevenue);
  int get totalTransactions => performance.fold(0, (sum, p) => sum + p.totalTransactions);
}

/// Staff performance notifier
class StaffPerformanceNotifier extends StateNotifier<StaffPerformanceState> {
  final StaffRepository _repository = StaffRepository();

  StaffPerformanceNotifier() : super(const StaffPerformanceState());

  /// Load staff performance
  Future<void> loadPerformance({
    required DateTime startDate,
    required DateTime endDate,
    String? staffId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final performance = await _repository.getStaffPerformance(
        startDate: startDate,
        endDate: endDate,
        staffId: staffId,
      );

      state = state.copyWith(
        performance: performance,
        isLoading: false,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh performance
  Future<void> refresh() async {
    if (state.startDate != null && state.endDate != null) {
      await loadPerformance(
        startDate: state.startDate!,
        endDate: state.endDate!,
      );
    }
  }
}

/// Provider for staff performance
final staffPerformanceProvider = StateNotifierProvider<StaffPerformanceNotifier, StaffPerformanceState>((ref) {
  return StaffPerformanceNotifier();
});
