import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../core/database/app_database.dart'; // For StockMovementEntity
import '../../../../widgets/desktop/desktop_content_container.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Damage & Adjustment Logs Screen
///
/// Shows history of stock adjustments due to:
/// - Damage
/// - Expiry
/// - Theft/Loss
class DamageLogsScreen extends ConsumerStatefulWidget {
  const DamageLogsScreen({super.key});

  @override
  ConsumerState<DamageLogsScreen> createState() => _DamageLogsScreenState();
}

class _DamageLogsScreenState extends ConsumerState<DamageLogsScreen> {
  bool _loading = true;
  List<StockMovementEntity> _logs = [];
  Map<String, String> _productNames = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final userId = ref.read(authStateProvider).userId ?? '';
    if (userId.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    try {
      final repo = sl<ProductsRepository>();

      // Load logs
      final result = await repo.getDamageLogs(userId);
      _logs = result.data ?? [];

      // Load products for names
      final productsResult = await repo.getAll(userId: userId);
      final products = productsResult.data ?? [];
      _productNames = {for (var p in products) p.id: p.name};

      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DesktopContentContainer(
      title: 'Damage Logs',
      subtitle: '${_logs.length} incidents recorded',
      actions: [
        DesktopIconButton(
          icon: Icons.refresh,
          tooltip: 'Refresh',
          onPressed: _loadData,
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
          ? _buildEmptyState(isDark)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _logs.length,
              itemBuilder: (context, index) =>
                  _buildLogCard(_logs[index], isDark),
            ),
    );
  }

  // Header removed

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: isDark ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No damage or loss recorded',
            style: TextStyle(
              fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
              color: isDark ? Colors.white60 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(StockMovementEntity log, bool isDark) {
    final productName = _productNames[log.productId] ?? 'Unknown Product';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.remove,
                color: Color(0xFFEF4444),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    log.reason,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  if (log.description != null &&
                      log.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      log.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.grey[600],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('dd MMM yyyy, hh:mm a').format(log.date),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '-${log.quantity.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEF4444),
                  ),
                ),
                Text(
                  'Qty',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
