import 'package:flutter/material.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/desktop/neon_card.dart';
import '../../../dashboard/data/dashboard_analytics_repository.dart';
import '../../../../core/session/session_manager.dart';

class AlertsPanel extends StatefulWidget {
  const AlertsPanel({super.key});

  @override
  State<AlertsPanel> createState() => _AlertsPanelState();
}

class _AlertsPanelState extends State<AlertsPanel> {
  bool _isLoading = true;
  List<ProductEntity> _lowStockItems = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final userId = sl<SessionManager>().userId;
      if (userId == null) return;

      final data = await sl<DashboardAnalyticsRepository>().getLowStockAlerts(
        userId: userId,
        limit: 5,
      );

      if (mounted) {
        setState(() {
          _lowStockItems = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return NeonCard(
      height: null, // Adapts to content
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: FuturisticColors.warning.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active,
                  color: FuturisticColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Action Required',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: FuturisticColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_lowStockItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'No urgent alerts. Good job!',
                style: TextStyle(color: FuturisticColors.textSecondary),
              ),
            )
          else
            Column(
              children: _lowStockItems
                  .map((product) => _buildAlertItem(product))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(ProductEntity product) {
    bool isOutOfStock = product.stockQuantity <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FuturisticColors.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isOutOfStock
                ? FuturisticColors.error
                : FuturisticColors.warning,
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOutOfStock ? 'Out of Stock' : 'Low Stock',
                  style: TextStyle(
                    color: isOutOfStock
                        ? FuturisticColors.error
                        : FuturisticColors.warning,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product.name,
                  style: const TextStyle(
                    color: FuturisticColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${product.stockQuantity.toInt()} left',
                style: const TextStyle(
                  color: FuturisticColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: () {
                  // Navigate to restock
                },
                child: const Text(
                  'Restock',
                  style: TextStyle(
                    color: FuturisticColors.accent1,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
