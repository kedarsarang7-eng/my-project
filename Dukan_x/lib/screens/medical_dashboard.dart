import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/futuristic_colors.dart';
import '../widgets/modern_ui_components.dart';
import '../features/patients/screens/patient_list_screen.dart';

class MedicalDashboard extends ConsumerStatefulWidget {
  const MedicalDashboard({super.key});

  @override
  ConsumerState<MedicalDashboard> createState() => _MedicalDashboardState();
}

class _MedicalDashboardState extends ConsumerState<MedicalDashboard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Medical Theme: Clean, Blue/Teal gradients (Futuristic Palette)
    // Access futuristic colors via extension or static class.

    return Scaffold(
      backgroundColor: FuturisticColors.background,
      body: CustomScrollView(
        slivers: [
          // 1. Futuristic Header (Glassy with Medical Gradient)
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: FuturisticColors.accent2, // Sky Blue
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0EA5E9), // Sky 500
                      Color(0xFF6366F1), // Indigo 500
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Doctor Greeting
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.local_hospital,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Dr. Dashboard',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Clinic Queue & Patient Records',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Dashboard Content
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildQuickStats(context),
                const SizedBox(height: AppSpacing.xl),
                _buildActionGrid(context),
                const SizedBox(height: AppSpacing.xl),
                _buildRecentQueue(context),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatisticWidget(
            label: 'Waiting',
            value: '12',
            icon: Icons.timer,
            iconColor: FuturisticColors.warning,
            backgroundColor: FuturisticColors.surface,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: StatisticWidget(
            label: 'Completed',
            value: '24',
            icon: Icons.check_circle_outline,
            iconColor: FuturisticColors.success,
            backgroundColor: FuturisticColors.surface,
          ),
        ),
      ],
    );
  }

  Widget _buildActionGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      children: [
        AnimatedMenuCard(
          icon: Icons.add_circle_outline,
          title: 'New Visit',
          subtitle: 'Walk-in Patient',
          onTap: () {
            // Navigator.pushNamed(context, '/visit/new');
          },
          iconColor: FuturisticColors.primary,
        ),
        AnimatedMenuCard(
          icon: Icons.people_outline,
          title: 'Patients',
          subtitle: 'Search Records',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PatientListScreen(),
              ),
            );
          },
          iconColor: FuturisticColors.secondary,
        ),
        AnimatedMenuCard(
          icon: Icons.calendar_today,
          title: 'Appointments',
          subtitle: 'Today\'s Schedule',
          onTap: () {},
          iconColor: FuturisticColors.accent,
        ),
        AnimatedMenuCard(
          icon: Icons.settings,
          title: 'Clinic Settings',
          onTap: () {},
          iconColor: FuturisticColors.textSecondary,
          backgroundColor: FuturisticColors.surface,
        ),
      ],
    );
  }

  Widget _buildRecentQueue(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Current Queue',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.md),
        // Empty State for now
        ModernCard(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Icon(Icons.coffee, size: 48, color: FuturisticColors.textHint),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No patients in queue',
                  style: TextStyle(color: FuturisticColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
