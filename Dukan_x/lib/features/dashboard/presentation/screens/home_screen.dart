import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../screens/widgets/sync_status_indicator.dart';

// Strategy Imports
import '../../logic/dashboard_strategies.dart';

import '../../../../models/business_type.dart';
import '../../../../providers/app_state_providers.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class HomeScreenModern extends ConsumerStatefulWidget {
  const HomeScreenModern({super.key});

  @override
  ConsumerState<HomeScreenModern> createState() => _HomeScreenModernState();
}

class _HomeScreenModernState extends ConsumerState<HomeScreenModern>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
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
    // Responsive breakpoint — phone gets a denser grid, tablet/desktop wider.
    final width = MediaQuery.sizeOf(context).width;

    // Get Current Business Type from Riverpod Provider
    final businessType = ref.watch(businessTypeProvider).type;
    final strategy = DashboardStrategyFactory.getStrategy(businessType);
    final quickActions = strategy.quickActions;

    // COMPACT HEADER (Part 5): a smaller, pinned SliverAppBar so KPI/content
    // cards surface above the fold on Android phones. The old expandedHeight
    // of 200 wasted ~25% of vertical space; we now scale it responsively and
    // keep it pinned, collapsing to a tight toolbar on scroll.
    final expandedHeight = responsiveValue<double>(
      context,
      mobile:
          116, // compact on phones — title + sync visible, grid starts sooner
      tablet: 150,
      desktop: 168,
    );

    // Responsive grid density: 2 columns phone, 3 tablet, 4+ desktop.
    final crossAxisCount = responsiveValue<int>(
      context,
      mobile: 2,
      tablet: 3,
      desktop: 4,
    );

    return Scaffold(
      backgroundColor: FuturisticColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Compact, pinned app bar
            SliverAppBar(
              expandedHeight: expandedHeight,
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: FuturisticColors.primary,
              toolbarHeight: 56,
              collapsedHeight: 56,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                title: Text(
                  businessType.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        FuturisticColors.primary,
                        FuturisticColors.primaryDark,
                      ],
                    ),
                  ),
                ),
                centerTitle: true,
                collapseMode: CollapseMode.parallax,
              ),
              actions: const [
                Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: Center(child: SyncStatusIndicator()),
                ),
              ],
            ),
            // Content
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.md),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dynamic Menu Grid — responsive density
                      GridView.count(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: AppSpacing.md,
                        mainAxisSpacing: AppSpacing.md,
                        // Taller tiles on phone for tap targets; wider on desktop.
                        childAspectRatio: responsiveValue<double>(
                          context,
                          mobile: 0.95,
                          tablet: 1.0,
                          desktop: 1.1,
                        ),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: quickActions.map((action) {
                          return AnimatedMenuCard(
                            icon: action.icon,
                            title: action.label,
                            onTap: () {
                              if (action.route.isNotEmpty) {
                                // AD-5/AD-7: dynamic runtime route string via GoRouter.
                                context.push(action.route);
                              }
                            },
                            backgroundColor:
                                (action.color ?? FuturisticColors.primary)
                                    .withOpacity(0.1),
                            iconColor: action.color ?? FuturisticColors.primary,
                            showBadge: false, // Can add later
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Quick Tips Section (compact on mobile)
                      Text(
                        'Quick Tips',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ModernCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTipItem(
                              context,
                              Icons.lightbulb_outline,
                              'Optimize Your Business',
                              'Use ${businessType.displayName} features to track everything efficiently.',
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _buildTipItem(
                              context,
                              strategy.addItemIcon,
                              'Quick Actions',
                              'Use the "${strategy.addItemLabel}" shortcut for faster entry.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: FuturisticColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
          ),
          child: Icon(icon, color: FuturisticColors.primary, size: 20),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: FuturisticColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
