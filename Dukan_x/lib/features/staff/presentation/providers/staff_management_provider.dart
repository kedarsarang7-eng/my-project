import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../core/services/logger_service.dart';
import '../../data/models/staff_profile_model.dart';
import '../../services/staff_api_service.dart';

/// Staff Management State
class StaffManagementState {
  final List<StaffListItemModel> staff;
  final List<StaffListItemModel> filteredStaff;
  final bool isLoading;
  final String? error;
  final int currentPage;
  final int itemsPerPage;
  final StaffFilters filters;
  final bool isCreating;
  final bool isUpdating;
  final String? updateError;
  final StaffStatsModel? stats;

  // BUG-047 FIX: isLoading=true by default so loading indicator shows immediately
  // Prevents blank screen during initial data load
  const StaffManagementState({
    this.staff = const [],
    this.filteredStaff = const [],
    this.isLoading = true, // Start with loading indicator visible
    this.error,
    this.currentPage = 1,
    this.itemsPerPage = 10,
    this.filters = const StaffFilters(),
    this.isCreating = false,
    this.isUpdating = false,
    this.updateError,
    this.stats,
  });

  StaffManagementState copyWith({
    List<StaffListItemModel>? staff,
    List<StaffListItemModel>? filteredStaff,
    bool? isLoading,
    String? error,
    int? currentPage,
    int? itemsPerPage,
    StaffFilters? filters,
    bool? isCreating,
    bool? isUpdating,
    String? updateError,
    StaffStatsModel? stats,
  }) {
    return StaffManagementState(
      staff: staff ?? this.staff,
      filteredStaff: filteredStaff ?? this.filteredStaff,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      itemsPerPage: itemsPerPage ?? this.itemsPerPage,
      filters: filters ?? this.filters,
      isCreating: isCreating ?? this.isCreating,
      isUpdating: isUpdating ?? this.isUpdating,
      updateError: updateError,
      stats: stats ?? this.stats,
    );
  }

  // BUG-019 FIX: Ensure at least 1 page even when filtered list is empty
  // Prevents goToPage(1) from failing when totalPages would be 0
  int get totalPages =>
      filteredStaff.isEmpty ? 1 : (filteredStaff.length / itemsPerPage).ceil();

  List<StaffListItemModel> get paginatedStaff {
    final startIndex = (currentPage - 1) * itemsPerPage;
    final endIndex = (startIndex + itemsPerPage).clamp(0, filteredStaff.length);
    if (startIndex >= filteredStaff.length) return [];
    return filteredStaff.sublist(startIndex, endIndex);
  }
}

/// Staff Management Provider
final staffManagementProvider =
    StateNotifierProvider<StaffManagementNotifier, StaffManagementState>(
      (ref) => StaffManagementNotifier(),
    );

class StaffManagementNotifier extends StateNotifier<StaffManagementState> {
  final StaffApiService _apiService = StaffApiService();

  StaffManagementNotifier() : super(const StaffManagementState());

  /// Load staff list from API
  Future<void> loadStaff({bool refresh = false}) async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      error: null,
      currentPage: refresh ? 1 : state.currentPage,
    );

    try {
      final staff = await _apiService.listStaff(
        filters: state.filters,
        page: refresh ? 1 : state.currentPage,
        limit: 100, // Load all and paginate locally for better UX
      );

      // Apply local filtering
      final filtered = _applyFilters(staff, state.filters);

      state = state.copyWith(
        staff: staff,
        filteredStaff: filtered,
        isLoading: false,
      );

      // Also load stats
      await loadStats();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refresh staff list
  Future<void> refresh() async {
    await loadStaff(refresh: true);
  }

  /// Load staff stats
  /// BUG-020 FIX: Proper error handling with user feedback
  Future<void> loadStats() async {
    try {
      final stats = await _apiService.getStaffStats();
      state = state.copyWith(
        stats: stats,
        // Clear any previous stats error on success
        updateError: state.updateError?.contains('stats') == true
            ? null
            : state.updateError,
      );
    } catch (e) {
      // BUG-020 FIX: Don't just log - provide user-friendly error
      final errorMessage = e is Exception
          ? 'Failed to load staff statistics. Some data may be unavailable.'
          : 'Failed to load stats: $e';

      LoggerService.d('StaffMgmt', 'Failed to load stats: $e');

      // Show error to user but don't fail the main operation
      state = state.copyWith(updateError: errorMessage);
    }
  }

  /// Set role filter
  void setRoleFilter(StaffRole? role) {
    final newFilters = state.filters.copyWith(role: role);
    final filtered = _applyFilters(state.staff, newFilters);

    state = state.copyWith(
      filters: newFilters,
      filteredStaff: filtered,
      currentPage: 1,
    );
  }

  /// Set status filter
  void setStatusFilter(StaffStatus? status) {
    final newFilters = state.filters.copyWith(status: status);
    final filtered = _applyFilters(state.staff, newFilters);

    state = state.copyWith(
      filters: newFilters,
      filteredStaff: filtered,
      currentPage: 1,
    );
  }

  /// Set search query
  void setSearchQuery(String query) {
    final newFilters = state.filters.copyWith(searchQuery: query);
    final filtered = _applyFilters(state.staff, newFilters);

    state = state.copyWith(
      filters: newFilters,
      filteredStaff: filtered,
      currentPage: 1,
    );
  }

  /// Go to specific page
  void goToPage(int page) {
    if (page < 1 || page > state.totalPages) return;
    state = state.copyWith(currentPage: page);
  }

  /// Create new staff member
  Future<CreateStaffResponse?> createStaff(CreateStaffRequest request) async {
    state = state.copyWith(isCreating: true, updateError: null);

    try {
      final response = await _apiService.createStaff(request);

      // Refresh list
      await refresh();

      state = state.copyWith(isCreating: false);
      return response;
    } catch (e) {
      state = state.copyWith(isCreating: false, updateError: e.toString());
      return null;
    }
  }

  /// Update staff member
  Future<bool> updateStaff(String staffId, UpdateStaffRequest request) async {
    state = state.copyWith(isUpdating: true, updateError: null);

    try {
      await _apiService.updateStaff(staffId, request);

      // Update local state
      final updatedStaff = state.staff.map((s) {
        if (s.staffId == staffId) {
          return s.copyWith(
            fullName: request.fullName ?? s.fullName,
            phoneNumber: request.phoneNumber ?? s.phoneNumber,
            email: request.email ?? s.email,
            role: request.role ?? s.role,
            isActive: request.isActive ?? s.isActive,
          );
        }
        return s;
      }).toList();

      final filtered = _applyFilters(updatedStaff, state.filters);

      state = state.copyWith(
        staff: updatedStaff,
        filteredStaff: filtered,
        isUpdating: false,
      );

      return true;
    } catch (e) {
      state = state.copyWith(isUpdating: false, updateError: e.toString());
      return false;
    }
  }

  /// Deactivate staff member
  Future<bool> deactivateStaff(String staffId) async {
    state = state.copyWith(isUpdating: true, updateError: null);

    try {
      await _apiService.deactivateStaff(staffId);

      // Update local state
      final updatedStaff = state.staff.map((s) {
        if (s.staffId == staffId) {
          return s.copyWith(isActive: false);
        }
        return s;
      }).toList();

      final filtered = _applyFilters(updatedStaff, state.filters);

      state = state.copyWith(
        staff: updatedStaff,
        filteredStaff: filtered,
        isUpdating: false,
      );

      return true;
    } catch (e) {
      state = state.copyWith(isUpdating: false, updateError: e.toString());
      return false;
    }
  }

  /// Reactivate staff member
  Future<bool> reactivateStaff(String staffId) async {
    state = state.copyWith(isUpdating: true, updateError: null);

    try {
      await _apiService.reactivateStaff(staffId);

      // Update local state
      final updatedStaff = state.staff.map((s) {
        if (s.staffId == staffId) {
          return s.copyWith(isActive: true);
        }
        return s;
      }).toList();

      final filtered = _applyFilters(updatedStaff, state.filters);

      state = state.copyWith(
        staff: updatedStaff,
        filteredStaff: filtered,
        isUpdating: false,
      );

      return true;
    } catch (e) {
      state = state.copyWith(isUpdating: false, updateError: e.toString());
      return false;
    }
  }

  /// Reset staff password
  Future<ResetPasswordResponse?> resetPassword(String staffId) async {
    state = state.copyWith(isUpdating: true, updateError: null);

    try {
      final response = await _apiService.resetPassword(staffId);
      state = state.copyWith(isUpdating: false);
      return response;
    } catch (e) {
      state = state.copyWith(isUpdating: false, updateError: e.toString());
      return null;
    }
  }

  /// Apply filters to staff list
  List<StaffListItemModel> _applyFilters(
    List<StaffListItemModel> staff,
    StaffFilters filters,
  ) {
    return staff.where((s) {
      // Role filter
      if (filters.role != null && s.role != filters.role) {
        return false;
      }

      // Status filter
      if (filters.status != null) {
        if (filters.status == StaffStatus.active && !s.isActive) {
          return false;
        }
        if (filters.status == StaffStatus.inactive && s.isActive) {
          return false;
        }
        // Note: Deactivated maps to inactive for this check
        if (filters.status == StaffStatus.deactivated && s.isActive) {
          return false;
        }
      }

      // Search filter
      if (filters.searchQuery?.isNotEmpty == true) {
        final query = filters.searchQuery!.toLowerCase();
        final matchesName = s.fullName.toLowerCase().contains(query);
        final matchesPhone = s.phoneNumber.toLowerCase().contains(query);
        final matchesEmail = s.email?.toLowerCase().contains(query) ?? false;
        final matchesId = s.staffId.toLowerCase().contains(query);

        if (!matchesName && !matchesPhone && !matchesEmail && !matchesId) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void clearError() {
    state = state.copyWith(error: null, updateError: null);
  }
}

/// Selected staff provider for detail view
final selectedStaffProvider =
    StateNotifierProvider<SelectedStaffNotifier, StaffProfileModel?>((ref) {
      return SelectedStaffNotifier();
    });

class SelectedStaffNotifier extends StateNotifier<StaffProfileModel?> {
  final StaffApiService _apiService = StaffApiService();

  SelectedStaffNotifier() : super(null);

  Future<void> loadStaff(String staffId) async {
    try {
      final staff = await _apiService.getStaffById(staffId);
      state = staff;
    } catch (e) {
      LoggerService.d('StaffMgmt', 'Failed to load staff details: $e');
      state = null;
    }
  }

  void clear() {
    state = null;
  }
}
