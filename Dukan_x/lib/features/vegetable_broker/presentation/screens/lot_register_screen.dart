import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Lot Register screen — lists the current tenant's stored vegetable lots
/// showing net weight, rate, grade, and lifecycle status (most recently
/// created first). Uses a reactive Drift `watch()` so lifecycle-status
/// transitions appear within 2 seconds without manual refresh.
///
/// Requirements: 11.1, 11.5, 11.6
class LotRegisterScreen extends StatefulWidget {
  const LotRegisterScreen({super.key});

  @override
  State<LotRegisterScreen> createState() => _LotRegisterScreenState();
}

class _LotRegisterScreenState extends State<LotRegisterScreen> {
  final _db = sl<AppDatabase>();
  final _session = sl<SessionManager>();

  /// Reactive Drift watch query: streams lots for the current user,
  /// ordered by createdAt descending. Drift's watch() automatically
  /// re-emits when underlying data changes, ensuring transitions
  /// appear within 2 seconds (R11.5).
  Stream<List<VegetableLotEntity>> _watchLots(String userId) {
    return (_db.select(_db.vegetableLots)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final userId = _session.ownerId;

    if (userId == null) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: const Center(child: Text('Authentication required')),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        title: Text(
          'Lot Register',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: StreamBuilder<List<VegetableLotEntity>>(
          stream: _watchLots(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading lots: ${snapshot.error}',
                  style: TextStyle(color: colorScheme.error),
                ),
              );
            }

            final lots = snapshot.data ?? [];

            // R11.6: Empty-state indication when no lots exist
            if (lots.isEmpty) {
              return _buildEmptyState(theme, isDark);
            }

            return _buildLotList(lots, theme, isDark);
          },
        ),
      ),
    );
  }

  /// Empty-state widget with icon + descriptive text (R11.6).
  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.4),
            semanticLabel: 'No lots',
          ),
          const SizedBox(height: 16),
          Text(
            'No lots found',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lots will appear here as they arrive at the mandi.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the scrollable list of lots (R11.1).
  Widget _buildLotList(
    List<VegetableLotEntity> lots,
    ThemeData theme,
    bool isDark,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: lots.length,
      itemBuilder: (context, index) {
        final lot = lots[index];
        return _LotCard(lot: lot, theme: theme, isDark: isDark);
      },
    );
  }
}

/// Individual lot card displaying net weight, rate, grade, and status badge.
class _LotCard extends StatelessWidget {
  final VegetableLotEntity lot;
  final ThemeData theme;
  final bool isDark;

  const _LotCard({
    required this.lot,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final rateRupees = lot.rate / 100.0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: theme.colorScheme.surfaceContainerHighest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Left: lot details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Grade as headline
                  Text(
                    lot.grade,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    semanticsLabel: 'Grade: ${lot.grade}',
                  ),
                  const SizedBox(height: 4),
                  // Net weight and rate
                  Text(
                    '${lot.netWeight.toStringAsFixed(1)} Kg  •  ₹${rateRupees.toStringAsFixed(2)}/Kg',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    semanticsLabel:
                        'Net weight ${lot.netWeight.toStringAsFixed(1)} kilograms, '
                        'rate ${rateRupees.toStringAsFixed(2)} rupees per kilogram',
                  ),
                ],
              ),
            ),
            // Right: status badge
            _StatusBadge(status: lot.status, theme: theme),
          ],
        ),
      ),
    );
  }
}

/// Lifecycle status badge/chip with semantically meaningful colors.
/// ARRIVED=blue, AUCTIONED=orange, SOLD=green, SETTLED=grey
class _StatusBadge extends StatelessWidget {
  final String status;
  final ThemeData theme;

  const _StatusBadge({required this.status, required this.theme});

  @override
  Widget build(BuildContext context) {
    final (bgColor, fgColor) = _colorsForStatus(status);

    return Semantics(
      label: 'Status: $status',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: bgColor.withOpacity(0.4)),
        ),
        child: Text(
          status,
          style: theme.textTheme.labelSmall?.copyWith(
            color: fgColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Returns (background tint, foreground text) color for each lifecycle status.
  /// Uses Material 3 semantic colors from the theme where possible.
  (Color, Color) _colorsForStatus(String status) {
    switch (status) {
      case 'ARRIVED':
        return (Colors.blue, Colors.blue.shade700);
      case 'AUCTIONED':
        return (Colors.orange, Colors.orange.shade800);
      case 'SOLD':
        return (Colors.green, Colors.green.shade700);
      case 'SETTLED':
        return (Colors.grey, Colors.grey.shade700);
      default:
        return (Colors.grey, Colors.grey.shade700);
    }
  }
}
