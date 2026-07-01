import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/logger_service.dart';
// Cross-platform responsive system (consolidated single source of truth) plus
// the desktop window-comfort helpers that defer to it.
import 'package:dukanx/core/responsive/responsive.dart';
import '../../../../core/theme/responsive_layout.dart';
import '../../data/models/staff_profile_model.dart';
import '../../services/staff_attendance_service.dart';
import '../bloc/id_card_designer_bloc.dart';
import '../bloc/staff_detail_bloc.dart';
import '../providers/staff_management_provider.dart';
import '../widgets/create_staff_dialog.dart';
import '../widgets/edit_staff_dialog.dart';
import '../widgets/deactivate_staff_dialog.dart';
import '../widgets/reset_password_dialog.dart';
import 'id_card_designer_screen.dart';
import 'unified_staff_detail_screen.dart';

/// Staff Management Screen - Pixel Perfect Implementation
///
/// Matches the reference image with:
/// - "Staff Members" title with blue "Create New Staff Account" button
/// - Filter bar with Role dropdown, Status tabs, and Search
/// - Data table with Photo, Full Name, Role, Contact Number, Join Date, Status, Actions
/// - Pagination at bottom
class StaffManagementScreen extends ConsumerStatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  ConsumerState<StaffManagementScreen> createState() =>
      _StaffManagementScreenState();
}

class _StaffManagementScreenState extends ConsumerState<StaffManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Load staff list on mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(staffManagementProvider.notifier).loadStaff();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(staffManagementProvider);

    // Responsive padding from the consolidated desktop window-comfort helper.
    final responsivePadding = DesktopWindowComfort.padding(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Light gray background
      body: BoundedBox(
        maxWidth: 800,
        child: SafeResponsiveArea(
        child: Padding(
          padding: responsivePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and Create button
              _buildHeader(),
              SizedBox(
                height: responsiveValue<double>(
                  context,
                  mobile: 16,
                  tablet: 16,
                  desktop: 24,
                ),
              ),

              // Filter bar with Role, Status, and Search
              _buildFilterBar(state),
              const SizedBox(height: 16),

              // Staff count indicator
              _buildCountIndicator(state),
              const SizedBox(height: 8),

              // Data Table
              Expanded(child: _buildDataTable(state)),

              const SizedBox(height: 16),

              // Pagination
              _buildPagination(state),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildHeader() {
    // Responsive font size, button label, and padding via the consolidated
    // selector: compact variants on mobile/tablet, full variants on desktop.
    final titleSize = responsiveValue<double>(
      context,
      mobile: 22.0,
      tablet: 22.0,
      desktop: 28.0,
    );
    final buttonText = responsiveValue<String>(
      context,
      mobile: 'Add Staff',
      tablet: 'Add Staff',
      desktop: 'Create New Staff Account',
    );
    final buttonPadding = responsiveValue<EdgeInsets>(
      context,
      mobile: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      tablet: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      desktop: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'Staff Members',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1A2E),
            ),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: () => _showCreateStaffDialog(),
          icon: const Icon(Icons.add, size: 20),
          label: Text(
            buttonText,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB), // Blue color from image
            foregroundColor: Colors.white,
            padding: buttonPadding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar(StaffManagementState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Role Dropdown
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Role',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<StaffRole?>(
                    value: state.filters.role,
                    isDense: true,
                    hint: const Text('All Members'),
                    items: [
                      const DropdownMenuItem<StaffRole?>(
                        value: null,
                        child: Text('All Members'),
                      ),
                      ...StaffRole.values.map(
                        (role) => DropdownMenuItem(
                          value: role,
                          child: Text(role.displayName),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      ref
                          .read(staffManagementProvider.notifier)
                          .setRoleFilter(value);
                    },
                  ),
                ),
              ),
            ],
          ),

          // Status Tabs
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Status',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(width: 12),
              _buildStatusTab('All', null, state.filters.status),
              _buildStatusTab(
                'Active',
                StaffStatus.active,
                state.filters.status,
              ),
              _buildStatusTab(
                'Inactive',
                StaffStatus.inactive,
                state.filters.status,
              ),
              _buildStatusTab(
                'Deactivated',
                StaffStatus.deactivated,
                state.filters.status,
              ),
            ],
          ),

          // Search
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Search',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 200,
                height: 36,
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    ref
                        .read(staffManagementProvider.notifier)
                        .setSearchQuery(value);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search',
                    hintStyle: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 18,
                      color: Color(0xFF9CA3AF),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFF2563EB)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTab(
    String label,
    StaffStatus? status,
    StaffStatus? currentStatus,
  ) {
    final isSelected = status == currentStatus;
    return InkWell(
      onTap: () {
        ref.read(staffManagementProvider.notifier).setStatusFilter(status);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? Colors.white : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }

  Widget _buildCountIndicator(StaffManagementState state) {
    final filteredCount = state.filteredStaff.length;
    final totalCount = state.staff.length;

    return Text(
      'Showing $filteredCount of $totalCount staff members',
      style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
    );
  }

  Widget _buildDataTable(StaffManagementState state) {
    if (state.isLoading && state.staff.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // BUG-048 FIX: Improved error state with user-friendly styling
    if (state.error != null && state.staff.isEmpty) {
      return Center(
        child: Container(
          padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
          margin: EdgeInsets.all(responsiveValue<double>(context,
              mobile: 16,
              tablet: 20,
              desktop: 24,  // PRESERVED: Desktop uses exactly 24 as before
            )),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red[200]!, width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
              const SizedBox(height: 16),
              Text(
                'Unable to Load Staff',
                style: TextStyle(
                  fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
                  fontWeight: FontWeight.w600,
                  color: Colors.red[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getUserFriendlyErrorMessage(state.error!),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.red[600]),
              ),
              const SizedBox(height: 4),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.red[400]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () =>
                    ref.read(staffManagementProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (state.filteredStaff.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No staff members found',
              style: TextStyle(fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ), color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              state.filters.searchQuery?.isNotEmpty == true
                  ? 'Try adjusting your search'
                  : 'Add your first staff member to get started',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 48), // Photo column
                Expanded(flex: 3, child: _buildHeaderCell('Full Name')),
                Expanded(flex: 2, child: _buildHeaderCell('Role')),
                Expanded(flex: 2, child: _buildHeaderCell('Contact Number')),
                Expanded(flex: 2, child: _buildHeaderCell('Join Date')),
                Expanded(flex: 1, child: _buildHeaderCell('Status')),
                const SizedBox(width: 100), // Actions column
              ],
            ),
          ),

          // Table Body
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: state.filteredStaff.length,
              itemBuilder: (context, index) {
                final staff = state.filteredStaff[index];
                return _buildStaffRow(staff, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF6B7280),
      ),
    );
  }

  Widget _buildStaffRow(StaffListItemModel staff, int index) {
    final isEven = index % 2 == 0;
    final dateFormat = DateFormat('MMM d, yyyy');
    final joinDate = DateTime.tryParse(staff.joiningDate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isEven ? Colors.white : const Color(0xFFF9FAFB),
        border: Border(
          bottom: BorderSide(
            color:
                index ==
                    ref.read(staffManagementProvider).filteredStaff.length - 1
                ? Colors.transparent
                : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        children: [
          // Photo
          _buildAvatar(staff),
          const SizedBox(width: 16),

          // Full Name
          Expanded(
            flex: 3,
            child: Text(
              staff.fullName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1F2937),
              ),
            ),
          ),

          // Role
          Expanded(flex: 2, child: _buildRoleChip(staff.role)),

          // Contact Number
          Expanded(
            flex: 2,
            child: Text(
              staff.phoneNumber,
              style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
            ),
          ),

          // Join Date
          Expanded(
            flex: 2,
            child: Text(
              joinDate != null
                  ? dateFormat.format(joinDate)
                  : staff.joiningDate,
              style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
            ),
          ),

          // Status
          Expanded(flex: 1, child: _buildStatusBadge(staff.status)),

          // Actions
          SizedBox(
            width: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildActionButton(staff),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(StaffListItemModel staff) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: staff.profilePhotoUrl != null
            ? null
            : _getRoleColor(staff.role).withValues(alpha: 0.1),
        image: staff.profilePhotoUrl != null
            ? DecorationImage(
                image: NetworkImage(staff.profilePhotoUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: staff.profilePhotoUrl == null
          ? Center(
              child: Text(
                staff.initials,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _getRoleColor(staff.role),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildRoleChip(StaffRole role) {
    final color = _getRoleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        role.displayName,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Color _getRoleColor(StaffRole role) {
    switch (role) {
      case StaffRole.cashier:
        return const Color(0xFF10B981); // Green
      case StaffRole.pumpOperator:
        return const Color(0xFFF59E0B); // Orange
      case StaffRole.supervisor:
        return const Color(0xFF8B5CF6); // Purple
      case StaffRole.manager:
        return const Color(0xFF3B82F6); // Blue
      case StaffRole.admin:
        return const Color(0xFFEF4444); // Red
    }
  }

  Widget _buildStatusBadge(StaffStatus status) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (status) {
      case StaffStatus.active:
        backgroundColor = const Color(0xFFD1FAE5);
        textColor = const Color(0xFF065F46);
        label = 'Active';
        break;
      case StaffStatus.inactive:
        backgroundColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFF991B1B);
        label = 'Inactive';
        break;
      case StaffStatus.deactivated:
        backgroundColor = const Color(0xFFF3F4F6);
        textColor = const Color(0xFF4B5563);
        label = 'Deactivated';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildActionButton(StaffListItemModel staff) {
    final isActive = staff.isActive;

    return PopupMenuButton<String>(
      offset: const Offset(0, 40),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFD1D5DB),
          ),
        ),
        child: const Icon(
          Icons.more_vert,
          size: 16,
          color: Color(0xFF374151),
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: const [
              Icon(
                Icons.edit_outlined,
                size: 18,
                color: Color(0xFF374151),
              ),
              SizedBox(width: 8),
              Text('Edit Account'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'view_details',
          child: Row(
            children: const [
              Icon(
                Icons.visibility_outlined,
                size: 18,
                color: Color(0xFF2563EB),
              ),
              SizedBox(width: 8),
              Text('View Full Details'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'id_card',
          child: Row(
            children: const [
              Icon(Icons.badge_outlined, size: 18, color: Color(0xFF8B5CF6)),
              SizedBox(width: 8),
              Text('Design ID Card'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: isActive ? 'deactivate' : 'activate',
          child: Row(
            children: [
              Icon(
                isActive ? Icons.block : Icons.check_circle,
                size: 18,
                color: isActive
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF059669),
              ),
              const SizedBox(width: 8),
              Text(
                isActive ? 'Deactivate Account' : 'Activate Account',
                style: TextStyle(
                  color: isActive
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF059669),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'reset_password',
          child: Row(
            children: const [
              Icon(Icons.key, size: 18, color: Color(0xFF6B7280)),
              SizedBox(width: 8),
              Text('Reset Password'),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'edit':
            _showEditStaffDialog(staff);
            break;
          case 'view_details':
            _navigateToStaffDetails(staff);
            break;
          case 'id_card':
            _navigateToIDCardDesigner(staff);
            break;
          case 'deactivate':
            _showDeactivateDialog(staff);
            break;
          case 'activate':
            _showReactivateDialog(staff);
            break;
          case 'reset_password':
            _showResetPasswordDialog(staff);
            break;
        }
      },
    );
  }

  Widget _buildPagination(StaffManagementState state) {
    final currentPage = state.currentPage;
    final totalPages = (state.filteredStaff.length / state.itemsPerPage).ceil();
    final startItem = state.filteredStaff.isEmpty ? 0 : (currentPage - 1) * state.itemsPerPage + 1;
    final endItem = (currentPage * state.itemsPerPage).clamp(
      0,
      state.filteredStaff.length,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Showing $startItem-$endItem of ${state.filteredStaff.length} staff members',
          style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
        Row(
          children: [
            IconButton(
              onPressed: currentPage > 1
                  ? () => ref
                        .read(staffManagementProvider.notifier)
                        .goToPage(currentPage - 1)
                  : null,
              icon: const Icon(Icons.chevron_left),
              color: currentPage > 1
                  ? const Color(0xFF374151)
                  : const Color(0xFF9CA3AF),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$currentPage',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            IconButton(
              onPressed: currentPage < totalPages
                  ? () => ref
                        .read(staffManagementProvider.notifier)
                        .goToPage(currentPage + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
              color: currentPage < totalPages
                  ? const Color(0xFF374151)
                  : const Color(0xFF9CA3AF),
            ),
            IconButton(
              onPressed: () => ref
                  .read(staffManagementProvider.notifier)
                  .goToPage(totalPages),
              icon: const Icon(Icons.last_page),
              color: currentPage < totalPages
                  ? const Color(0xFF374151)
                  : const Color(0xFF9CA3AF),
            ),
          ],
        ),
      ],
    );
  }

  void _showCreateStaffDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CreateStaffDialog(),
    );
  }

  void _showEditStaffDialog(StaffListItemModel staff) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditStaffDialog(staffId: staff.staffId),
    );
  }

  void _showDeactivateDialog(StaffListItemModel staff) {
    showDialog(
      context: context,
      builder: (context) => DeactivateStaffDialog(
        staffId: staff.staffId,
        staffName: staff.fullName,
      ),
    );
  }

  void _showReactivateDialog(StaffListItemModel staff) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activate Staff'),
        content: Text('Are you sure you want to reactivate ${staff.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(staffManagementProvider.notifier)
                  .reactivateStaff(staff.staffId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
            ),
            child: const Text('Activate'),
          ),
        ],
      ),
    );
  }

  void _showResetPasswordDialog(StaffListItemModel staff) {
    showDialog(
      context: context,
      builder: (context) => ResetPasswordDialog(
        staffId: staff.staffId,
        staffName: staff.fullName,
      ),
    );
  }

  /// BUG-048: Convert technical error messages to user-friendly ones
  String _getUserFriendlyErrorMessage(String error) {
    final lowerError = error.toLowerCase();

    if (lowerError.contains('socket') || lowerError.contains('connection')) {
      return 'Network connection issue. Please check your internet connection and try again.';
    }
    if (lowerError.contains('timeout')) {
      return 'The server is taking too long to respond. Please try again later.';
    }
    if (lowerError.contains('unauthorized') || lowerError.contains('401')) {
      return 'Your session has expired. Please log in again.';
    }
    if (lowerError.contains('permission') || lowerError.contains('403')) {
      return 'You don\'t have permission to view staff members.';
    }
    if (lowerError.contains('not found') || lowerError.contains('404')) {
      return 'The staff service is currently unavailable. Please try again later.';
    }

    // Generic fallback
    return 'Something went wrong while loading staff data. Please try again.';
  }

  /// Navigate to Unified Staff Detail Screen
  /// Validates BLoC registration before navigation to prevent crashes
  void _navigateToStaffDetails(StaffListItemModel staff) {
    try {
      // Validate service locator has required dependencies
      if (!sl.isRegistered<StaffDetailBloc>()) {
        throw StateError('StaffDetailBloc not registered in service locator');
      }
      if (!sl.isRegistered<StaffAttendanceService>()) {
        throw StateError(
          'StaffAttendanceService not registered in service locator',
        );
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              UnifiedStaffDetailScreen(staffId: staff.staffId),
        ),
      );
    } catch (e, stackTrace) {
      // Log error for debugging
      LoggerService.d(
        'StaffMgmt',
        'ERROR: Failed to navigate to staff details: $e',
      );
      LoggerService.d('StaffMgmt', 'Stack trace: $stackTrace');

      // Show user-friendly error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open staff details. Please try again.'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _navigateToStaffDetails(staff),
            ),
          ),
        );
      }
    }
  }

  /// Navigate to ID Card Designer Screen
  /// Validates BLoC registration before navigation to prevent crashes
  void _navigateToIDCardDesigner(StaffListItemModel staff) {
    try {
      // Validate service locator has required dependencies
      if (!sl.isRegistered<IDCardDesignerBloc>()) {
        throw StateError(
          'IDCardDesignerBloc not registered in service locator',
        );
      }
      if (!sl.isRegistered<StaffAttendanceService>()) {
        throw StateError(
          'StaffAttendanceService not registered in service locator',
        );
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IDCardDesignerScreen(staffId: staff.staffId),
        ),
      );
    } catch (e, stackTrace) {
      // Log error for debugging
      LoggerService.d(
        'StaffMgmt',
        'ERROR: Failed to navigate to ID card designer: $e',
      );
      LoggerService.d('StaffMgmt', 'Stack trace: $stackTrace');

      // Show user-friendly error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open ID card designer. Please try again.'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _navigateToIDCardDesigner(staff),
            ),
          ),
        );
      }
    }
  }
}
