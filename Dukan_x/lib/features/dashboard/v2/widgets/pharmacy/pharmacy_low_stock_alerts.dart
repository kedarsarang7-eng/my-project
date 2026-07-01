import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../core/theme/futuristic_colors.dart';
import '../../models/pharmacy_dashboard_models.dart';
import '../../providers/pharmacy_dashboard_providers.dart';

class PharmacyLowStockAlerts extends ConsumerWidget {
  const PharmacyLowStockAlerts({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(pharmacyLowStockAlertsProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          _buildHeader(),
          const SizedBox(height: 16),
          Expanded(
            child: alertsAsync.when(
              data: (data) => _buildAlertsList(context, ref, data),
              loading: () => _buildLoadingList(),
              error: (_, _) => _buildErrorList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: FuturisticColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.warning_amber_rounded,
            color: FuturisticColors.error,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Low Stock Alerts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: FuturisticColors.textPrimary,
                ),
              ),
              Text(
                'Items below reorder point',
                style: TextStyle(
                  fontSize: 12,
                  color: FuturisticColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: FuturisticColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Auto-refresh',
            style: TextStyle(
              fontSize: 10,
              color: FuturisticColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlertsList(BuildContext context, WidgetRef ref, LowStockAlertsData data) {
    if (data.isEmpty || data.items.isEmpty) {
      return _buildEmptyList();
    }

    return ListView.builder(
      itemCount: data.items.length,
      itemBuilder: (context, index) {
        final item = data.items[index];
        return _LowStockItem(
          item: item,
          onReorder: () => _handleReorder(context, ref, item),
        );
      },
    );
  }

  Widget _buildLoadingList() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            children: [
              // Status indicator skeleton
              Container(
                width: 8,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              
              // Product info skeleton
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 100,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Button skeleton
              Container(
                width: 80,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorList() {
    return Container(
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: FuturisticColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Unable to load stock alerts',
            style: TextStyle(
              color: FuturisticColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyList() {
    return Container(
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 48,
            color: FuturisticColors.success,
          ),
          const SizedBox(height: 16),
          Text(
            'All stock levels are healthy',
            style: TextStyle(
              color: FuturisticColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _handleReorder(BuildContext context, WidgetRef ref, LowStockItem item) {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reorder ${item.name}'),
        content: Text('Are you sure you want to place a reorder for ${item.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              try {
                await ref.read(reorderProductProvider(item.id).future);
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Reorder placed for ${item.name}'),
                      backgroundColor: FuturisticColors.success,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to reorder ${item.name}: $e'),
                      backgroundColor: FuturisticColors.error,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
            child: const Text('Reorder'),
          ),
        ],
      ),
    );
  }
}

// ── Low Stock Item Widget ─────────────────────────────────────────────────────

class _LowStockItem extends StatelessWidget {
  final LowStockItem item;
  final VoidCallback onReorder;

  const _LowStockItem({
    required this.item,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final severityColor = _getSeverityColor(item.status);
    final severityBgColor = _getSeverityBgColor(item.status);
    final isCritical = item.status == 'critical';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: severityBgColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: severityBgColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Status Indicator
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: severityColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          
          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: FuturisticColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Stock: ${item.qty}',
                      style: TextStyle(
                        fontSize: 12,
                        color: FuturisticColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Reorder at: ${item.reorderPoint}',
                      style: TextStyle(
                        fontSize: 12,
                        color: FuturisticColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Reorder Button
          ElevatedButton(
            onPressed: onReorder,
            style: ElevatedButton.styleFrom(
              backgroundColor: isCritical ? FuturisticColors.error : FuturisticColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Text(
              'Reorder',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(String status) {
    switch (status.toLowerCase()) {
      case 'critical':
        return FuturisticColors.error;
      case 'warning':
        return FuturisticColors.warning;
      default:
        return FuturisticColors.textSecondary;
    }
  }

  Color _getSeverityBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'critical':
        return FuturisticColors.error;
      case 'warning':
        return FuturisticColors.warning;
      default:
        return FuturisticColors.textSecondary;
    }
  }
}
