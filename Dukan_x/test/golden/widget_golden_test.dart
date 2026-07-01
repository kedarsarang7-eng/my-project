// ============================================================================
// GOLDEN TESTS FOR UI COMPONENTS
// ============================================================================
// Visual regression tests for key UI components
// Run with: flutter test --update-goldens to generate baseline images
//
// NOTE: These tests are skipped by default until golden files are generated.
// To generate goldens: flutter test test/golden --update-goldens
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/widgets/modern_ui_components.dart';
import 'package:dukanx/widgets/glass_container.dart';
import 'package:dukanx/core/theme/futuristic_colors.dart';

// Set to true to enable golden tests (requires running --update-goldens first)
const bool _enableGoldenTests = true;

void main() {
  group('ModernCard Golden Tests', () {
    testWidgets('basic card with text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            backgroundColor: Colors.grey[200],
            body: Center(
              child: SizedBox(
                width: 300,
                height: 150,
                child: ModernCard(
                  child: const Center(
                    child: Text(
                      'Modern Card',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(ModernCard),
        matchesGoldenFile('goldens/modern_card_basic.png'),
      );
    });

    testWidgets('card with custom background', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.grey[200],
            body: Center(
              child: SizedBox(
                width: 300,
                height: 150,
                child: ModernCard(
                  backgroundColor: FuturisticColors.primary.withOpacity(0.1),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.star,
                        size: 40,
                        color: FuturisticColors.primary,
                      ),
                      SizedBox(height: 8),
                      Text('Colored Card'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(ModernCard),
        matchesGoldenFile('goldens/modern_card_colored.png'),
      );
    });
  });

  group(
    'StatisticWidget Golden Tests',
    () {
      testWidgets('sales statistic widget', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.grey[100],
              body: Center(
                child: SizedBox(
                  width: 250,
                  child: StatisticWidget(
                    label: 'Today\'s Sales',
                    value: '₹15,250',
                    icon: Icons.trending_up,
                    iconColor: FuturisticColors.success,
                  ),
                ),
              ),
            ),
          ),
        );

        await expectLater(
          find.byType(StatisticWidget),
          matchesGoldenFile('goldens/statistic_widget_sales.png'),
        );
      });

      testWidgets('pending dues widget', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.grey[100],
              body: Center(
                child: SizedBox(
                  width: 250,
                  child: StatisticWidget(
                    label: 'Pending Dues',
                    value: '₹8,500',
                    icon: Icons.warning_amber_rounded,
                    iconColor: FuturisticColors.warning,
                  ),
                ),
              ),
            ),
          ),
        );

        await expectLater(
          find.byType(StatisticWidget),
          matchesGoldenFile('goldens/statistic_widget_dues.png'),
        );
      });
    },
  );

  group(
    'FuturisticButton Golden Tests',
    () {
      testWidgets('primary button', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: FuturisticButton(
                  label: 'Save Bill',
                  onPressed: () {},
                  icon: Icons.save,
                ),
              ),
            ),
          ),
        );

        await expectLater(
          find.byType(FuturisticButton),
          matchesGoldenFile('goldens/modern_button_primary.png'),
        );
      });

      testWidgets('loading button', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: FuturisticButton(
                  label: 'Processing...',
                  onPressed: () {},
                  isLoading: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 500));

        await expectLater(
          find.byType(FuturisticButton),
          matchesGoldenFile('goldens/modern_button_loading.png'),
        );
      });

      testWidgets('custom colored button', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: FuturisticButton(
                  label: 'Delete',
                  onPressed: () {},
                  icon: Icons.delete,
                  backgroundColor: FuturisticColors.error,
                ),
              ),
            ),
          ),
        );

        await expectLater(
          find.byType(FuturisticButton),
          matchesGoldenFile('goldens/modern_button_danger.png'),
        );
      });
    },
  );

  group(
    'EmptyStateWidget Golden Tests',
    () {
      testWidgets('no items state', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EmptyStateWidget(
                icon: Icons.inbox_outlined,
                title: 'No Bills Yet',
                description: 'Create your first bill to get started.',
                buttonLabel: 'Create Bill',
                onButtonPressed: () {},
              ),
            ),
          ),
        );

        await expectLater(
          find.byType(EmptyStateWidget),
          matchesGoldenFile('goldens/empty_state_no_items.png'),
        );
      });

      testWidgets('search not found state', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EmptyStateWidget(
                icon: Icons.search_off,
                title: 'No Results Found',
                description: 'Try adjusting your search terms.',
              ),
            ),
          ),
        );

        await expectLater(
          find.byType(EmptyStateWidget),
          matchesGoldenFile('goldens/empty_state_search.png'),
        );
      });
    },
  );

  group(
    'ModernListTile Golden Tests',
    () {
      testWidgets('customer list tile', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  ModernListTile(
                    leadingIcon: Icons.person,
                    title: 'John Doe',
                    subtitle: '+91 98765 43210',
                    trailing: const Text(
                      '₹2,500',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: FuturisticColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        await expectLater(
          find.byType(ModernListTile),
          matchesGoldenFile('goldens/list_tile_customer.png'),
        );
      });

      testWidgets('settings list tile', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  ModernListTile(
                    leadingIcon: Icons.notifications,
                    title: 'Notifications',
                    subtitle: 'Manage notification preferences',
                    trailing: Switch(value: true, onChanged: (_) {}),
                  ),
                ],
              ),
            ),
          ),
        );

        await expectLater(
          find.byType(ModernListTile),
          matchesGoldenFile('goldens/list_tile_settings.png'),
        );
      });
    },
  );

  group(
    'GlassContainer Golden Tests',
    () {
      testWidgets('glass container on gradient background', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      FuturisticColors.primary,
                      FuturisticColors.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: GlassContainer(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.lock, color: Colors.white, size: 48),
                        SizedBox(height: 16),
                        Text(
                          'Secure Login',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await expectLater(
          find.byType(GlassContainer),
          matchesGoldenFile('goldens/glass_container_gradient.png'),
        );
      });
    },
  );

  group(
    'AnimatedTabBar Golden Tests',
    () {
      testWidgets('tab bar with three tabs', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  AnimatedTabBar(
                    tabs: const ['Dashboard', 'Bills', 'Customers'],
                    onTabChanged: (_) {},
                  ),
                  const Expanded(child: Center(child: Text('Tab Content'))),
                ],
              ),
            ),
          ),
        );

        await expectLater(
          find.byType(AnimatedTabBar),
          matchesGoldenFile('goldens/tab_bar_three_tabs.png'),
        );
      });
    },
  );

  group(
    'Color Palette Golden Tests',
    () {
      testWidgets('app color palette', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ColorSwatch(
                      color: FuturisticColors.primary,
                      label: 'Primary',
                    ),
                    _ColorSwatch(
                      color: FuturisticColors.secondary,
                      label: 'Secondary',
                    ),
                    _ColorSwatch(
                      color: FuturisticColors.accent,
                      label: 'Accent',
                    ),
                    _ColorSwatch(
                      color: FuturisticColors.success,
                      label: 'Success',
                    ),
                    _ColorSwatch(
                      color: FuturisticColors.warning,
                      label: 'Warning',
                    ),
                    _ColorSwatch(color: FuturisticColors.error, label: 'Error'),
                    _ColorSwatch(
                      color: FuturisticColors.accent2,
                      label: 'Info',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/color_palette.png'),
        );
      });
    },
  );

  group(
    'Dashboard Card Grid Golden Tests',
    () {
      testWidgets('dashboard stats grid', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: FuturisticColors.background,
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  children: [
                    StatisticWidget(
                      label: 'Total Sales',
                      value: '₹45,000',
                      icon: Icons.monetization_on,
                      iconColor: FuturisticColors.success,
                    ),
                    StatisticWidget(
                      label: 'Pending',
                      value: '₹12,500',
                      icon: Icons.pending_actions,
                      iconColor: FuturisticColors.warning,
                    ),
                    StatisticWidget(
                      label: 'Customers',
                      value: '156',
                      icon: Icons.people,
                      iconColor: FuturisticColors.accent2,
                    ),
                    StatisticWidget(
                      label: 'Bills Today',
                      value: '28',
                      icon: Icons.receipt_long,
                      iconColor: FuturisticColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await expectLater(
          find.byType(GridView),
          matchesGoldenFile('goldens/dashboard_stats_grid.png'),
        );
      });
    },
  );
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final String label;

  const _ColorSwatch({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}
