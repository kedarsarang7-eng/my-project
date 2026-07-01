// ============================================================================
// KOT HISTORY & REPORT SCREEN
// ============================================================================

import 'package:flutter/material.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/modern_ui_components.dart';
import '../../data/models/restaurant_kot_model.dart';
import '../../data/repositories/restaurant_kot_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class KotReportScreen extends StatefulWidget {
  final String vendorId;
  const KotReportScreen({super.key, this.vendorId = 'SYSTEM'});
  @override
  State<KotReportScreen> createState() => _KotReportScreenState();
}

class _KotReportScreenState extends State<KotReportScreen> {
  final RestaurantKotRepository _repo = RestaurantKotRepository();
  final _orange = const Color(0xFFEA580C);
  String get _vendorId => widget.vendorId;

  Color _statusColor(KotStatus s) {
    switch (s) {
      case KotStatus.pending:
        return Colors.amber;
      case KotStatus.sent:
        return const Color(0xFF3B82F6);
      case KotStatus.printed:
        return Colors.green;
      case KotStatus.cancelled:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? FuturisticColors.darkBackground
          : FuturisticColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark
            ? FuturisticColors.darkSurface
            : FuturisticColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _orange.withValues(alpha: 0.3)),
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                color: _orange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'KOT History & Reports',
              style: AppTypography.headlineMedium.copyWith(
                color: isDark
                    ? FuturisticColors.darkTextPrimary
                    : FuturisticColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: StreamBuilder<List<RestaurantKot>>(
        stream: _repo.watchActiveKots(_vendorId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _orange));
          }
          final kots = snapshot.data ?? [];
          if (kots.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No KOTs for today',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }
          final active = kots
              .where((k) => k.status != KotStatus.cancelled)
              .length;
          final cancelled = kots
              .where((k) => k.status == KotStatus.cancelled)
              .length;
          final totalItems = kots.fold<int>(
            0,
            (sum, k) => sum + k.items.fold(0, (s, i) => s + i.qty),
          );

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                color: isDark
                    ? FuturisticColors.darkSurface
                    : FuturisticColors.surface,
                child: Row(
                  children: [
                    _statChip('Total KOTs', '${kots.length}', Colors.blue),
                    const SizedBox(width: 8),
                    _statChip('Active', '$active', Colors.green),
                    const SizedBox(width: 8),
                    _statChip('Cancelled', '$cancelled', Colors.red),
                    const SizedBox(width: 8),
                    _statChip('Items', '$totalItems', _orange),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: kots.length,
                  itemBuilder: (ctx, i) => _buildKotCard(kots[i], isDark),
                ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            TextSpan(
              text: ' $label',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKotCard(RestaurantKot kot, bool isDark) {
    final statusColor = _statusColor(kot.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ModernCard(
        backgroundColor: isDark
            ? FuturisticColors.darkSurface
            : FuturisticColors.surface,
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _orange.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Text(
                  '#${kot.kotNumber}',
                  style: TextStyle(
                    color: _orange,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (kot.tableNumber != null)
                        Text(
                          'Table ${kot.tableNumber}',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          kot.status.displayName,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ...kot.items.map(
                    (item) => Text(
                      '• ${item.qty}x ${item.itemName}'
                      '${item.variationName != null ? ' (${item.variationName})' : ''}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(kot.createdAt),
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}  $h:$m';
  }
}
