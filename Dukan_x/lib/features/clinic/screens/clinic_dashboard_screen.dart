// ============================================================================
// CLINIC DASHBOARD SCREEN
// ============================================================================
// Main dashboard page matching the reference image
// Responsive layout with all panels:
// - Overview Panel (4 KPI cards)
// - Appointment Activity Panel (line chart + button)
// - Patient Insights Panel (donut chart + table)
// - Clinic Performance Panel (bar chart + table + gauge)
// - Staff & Rooms Panel (staff list + room grid)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/futuristic_colors.dart';
import '../models/clinic_dashboard_models.dart';
import '../providers/clinic_dashboard_providers.dart';

// Panel widgets
import '../widgets/dashboard_app_bar.dart';
import '../widgets/side_navigation.dart';
import '../widgets/overview_panel.dart';
import '../widgets/appointment_activity_panel.dart';
import '../widgets/patient_insights_panel.dart';
import '../widgets/clinic_performance_panel.dart';
import '../widgets/staff_rooms_panel.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class ClinicDashboardScreen extends ConsumerStatefulWidget {
  const ClinicDashboardScreen({super.key});

  @override
  ConsumerState<ClinicDashboardScreen> createState() => _ClinicDashboardScreenState();
}

class _ClinicDashboardScreenState extends ConsumerState<ClinicDashboardScreen> {
  int _selectedNavIndex = 0;
  bool _sidebarCollapsed = false;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Desktop keyboard shortcuts
  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      // F5 or Ctrl+R to refresh
      if (event.logicalKey == LogicalKeyboardKey.f5 ||
          (event.logicalKey == LogicalKeyboardKey.keyR && 
           HardwareKeyboard.instance.isControlPressed)) {
        ref.invalidate(combinedDashboardStateProvider);
      }
      // Ctrl+B to toggle sidebar
      if (event.logicalKey == LogicalKeyboardKey.keyB && 
          HardwareKeyboard.instance.isControlPressed) {
        setState(() => _sidebarCollapsed = !_sidebarCollapsed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(combinedDashboardStateProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Responsive breakpoints for desktop
    final isLargeDesktop = screenWidth >= 1440;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (_, event) {
        _handleKeyEvent(event);
        return KeyEventResult.handled;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        // On mobile, provide navigation via Drawer instead of permanent sidebar
        drawer: context.isMobile
            ? Drawer(
                child: SideNavigation(
                  selectedIndex: _selectedNavIndex,
                  onItemSelected: (index) {
                    setState(() => _selectedNavIndex = index);
                    Navigator.pop(context);
                  },
                  collapsed: false,
                  onToggleCollapse: () {},
                ),
              )
            : null,
        body: Row(
          children: [
            // Left Sidebar - Only visible on tablet/desktop
            if (!context.isMobile)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                width: _sidebarCollapsed ? 72 : (isLargeDesktop ? 280 : 240),
                child: SideNavigation(
                  selectedIndex: _selectedNavIndex,
                  onItemSelected: (index) => setState(() => _selectedNavIndex = index),
                  collapsed: _sidebarCollapsed,
                  onToggleCollapse: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                ),
              ),

            // Main Content
            Expanded(
              child: Column(
                children: [
                  // Top App Bar with collapse/drawer button
                  DashboardAppBar(
                    onToggleSidebar: () {
                      if (context.isMobile) {
                        Scaffold.of(context).openDrawer();
                      } else {
                        setState(() => _sidebarCollapsed = !_sidebarCollapsed);
                      }
                    },
                    sidebarCollapsed: _sidebarCollapsed,
                  ),

                  // Dashboard Content
                  Expanded(
                    child: Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: !context.isMobile,
                      trackVisibility: !context.isMobile,
                      child: dashboardState.when(
                        data: (state) => _buildDashboardContent(
                          state, 
                          isLargeDesktop: isLargeDesktop,
                          isDesktop: isDesktop,
                          isTablet: isTablet,
                        ),
                        loading: () => _buildLoadingSkeleton(isLargeDesktop: isLargeDesktop),
                        error: (err, stack) => _buildErrorWidget(err),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent(
    CombinedDashboardState state, {
    required bool isLargeDesktop,
    required bool isDesktop,
    required bool isTablet,
  }) {
    // Responsive padding based on screen size
    final horizontalPadding = isLargeDesktop ? 32.0 : (isDesktop ? 24.0 : 16.0);
    
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardOverviewProvider);
        ref.invalidate(appointmentsProvider);
        ref.invalidate(patientInsightsProvider);
        ref.invalidate(staffAvailabilityProvider);
        ref.invalidate(roomsStatusProvider);
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Today's Overview (4 KPI Cards)
            // On large desktop, show 4 cards in a row
            // On smaller screens, show 2x2 grid
            if (isLargeDesktop || isDesktop)
              OverviewPanel(data: state.overview)
            else
              _buildResponsiveOverview(state.overview),

            SizedBox(height: isLargeDesktop ? 32 : 24),

            // Middle Section: Appointment Activity + Patient Insights
            // For large desktop, use 3:2 ratio
            // For smaller screens, stack vertically
            if (isLargeDesktop || isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: isLargeDesktop ? 3 : 2,
                    child: AppointmentActivityPanel(
                      trends: state.weeklyTrends,
                    ),
                  ),
                  SizedBox(width: isLargeDesktop ? 32 : 24),
                  Expanded(
                    flex: isLargeDesktop ? 2 : 1,
                    child: PatientInsightsPanel(
                      insights: state.patientInsights,
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  AppointmentActivityPanel(trends: state.weeklyTrends),
                  const SizedBox(height: 16),
                  PatientInsightsPanel(insights: state.patientInsights),
                ],
              ),

            SizedBox(height: isLargeDesktop ? 32 : 24),

            // Bottom Section: Clinic Performance + Staff & Rooms
            if (isLargeDesktop || isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: isLargeDesktop ? 3 : 2,
                    child: ClinicPerformancePanel(
                      billing: state.billingSummary,
                      appointments: state.appointments,
                      waitTime: state.waitTime,
                      isLargeDesktop: isLargeDesktop,
                    ),
                  ),
                  SizedBox(width: isLargeDesktop ? 32 : 24),
                  Expanded(
                    flex: isLargeDesktop ? 2 : 1,
                    child: StaffRoomsPanel(
                      staff: state.staffAvailability,
                      rooms: state.roomsStatus,
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  ClinicPerformancePanel(
                    billing: state.billingSummary,
                    appointments: state.appointments,
                    waitTime: state.waitTime,
                    isLargeDesktop: false,
                  ),
                  const SizedBox(height: 16),
                  StaffRoomsPanel(
                    staff: state.staffAvailability,
                    rooms: state.roomsStatus,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // Responsive 2x2 grid for smaller screens
  Widget _buildResponsiveOverview(DashboardOverview data) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _SingleKpiCard(data.totalPatients, 'Total Patients', Icons.people_outline)),
            const SizedBox(width: 16),
            Expanded(child: _SingleKpiCard(data.appointmentsToday.total, "Today's Appointments", Icons.calendar_today_outlined, subtitle: '${data.appointmentsToday.completed} Completed')),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _SingleKpiCard('${data.staffOnDuty.onDuty}/${data.staffOnDuty.total}', 'Staff On Duty', Icons.person_outline)),
            const SizedBox(width: 16),
            Expanded(child: _SingleKpiCard(data.revenueToday.formattedAmount, 'Total Revenue Today', Icons.attach_money)),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingSkeleton({bool isLargeDesktop = false}) {
    final padding = isLargeDesktop ? 32.0 : 24.0;
    final gap = isLargeDesktop ? 32.0 : 24.0;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        children: [
          // Overview Skeleton
          Row(
            children: List.generate(
              4,
              (index) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index < 3 ? 16 : 0),
                  child: _SkeletonCard(height: 100),
                ),
              ),
            ),
          ),
          SizedBox(height: gap),
          // Charts Skeleton
          Row(
            children: [
              Expanded(flex: 3, child: _SkeletonCard(height: 350)),
              SizedBox(width: gap),
              Expanded(flex: 2, child: _SkeletonCard(height: 350)),
            ],
          ),
          SizedBox(height: gap),
          Row(
            children: [
              Expanded(flex: 3, child: _SkeletonCard(height: 300)),
              SizedBox(width: gap),
              Expanded(flex: 2, child: _SkeletonCard(height: 300)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(Object error) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: FuturisticColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load dashboard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: FuturisticColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: FuturisticColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.invalidate(combinedDashboardStateProvider);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: FuturisticColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final double height;

  const _SkeletonCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const _ShimmerLoading(),
    );
  }
}

class _ShimmerLoading extends StatelessWidget {
  const _ShimmerLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade200,
            Colors.grey.shade100,
            Colors.grey.shade200,
          ],
          stops: const [0.0, 0.5, 1.0],
          begin: const Alignment(-1.0, -0.3),
          end: const Alignment(1.0, 0.3),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

// Simple KPI card for responsive layout
class _SingleKpiCard extends StatelessWidget {
  final dynamic value;
  final String title;
  final IconData icon;
  final String? subtitle;

  const _SingleKpiCard(this.value, this.title, this.icon, {this.subtitle});

  @override
  Widget build(BuildContext context) {
    final displayValue = value is int || value is String ? value.toString() : '0';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: FuturisticColors.primary, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: FuturisticColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            displayValue,
            style: TextStyle(
                  fontSize: responsiveValue<double>(context,
                    mobile: 16,
                    tablet: 18,
                    desktop: 20,  // PRESERVED: Desktop uses exactly 20 as before
                  ),
              fontWeight: FontWeight.bold,
              color: FuturisticColors.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 11,
                color: FuturisticColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
