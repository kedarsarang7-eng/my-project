import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../data/models/staff_profile_model.dart';
import '../../services/staff_api_service.dart';
import '../../../../core/di/service_locator.dart';

/// Provider for loading and holding a single selected staff member.
///
/// Used by [EditStaffDialog] to load staff data before editing.
class SelectedStaffNotifier extends StateNotifier<StaffProfileModel?> {
  SelectedStaffNotifier() : super(null);

  /// Loads a staff member by ID. Returns the loaded model or null on failure.
  Future<StaffProfileModel?> loadStaff(String staffId) async {
    try {
      final service = sl<StaffApiService>();
      final staff = await service.getStaffById(staffId);
      state = staff;
      return staff;
    } catch (_) {
      return null;
    }
  }
}

final selectedStaffProvider =
    StateNotifierProvider<SelectedStaffNotifier, StaffProfileModel?>(
      (ref) => SelectedStaffNotifier(),
    );
