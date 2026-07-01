import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../models/reorder_prediction.dart'; // Keep model, verify path
import '../../../../widgets/modern_ui_components.dart';
import '../../../../core/theme/futuristic_colors.dart';

// Verify path for Multiplatform and ReorderPrediction

class ReorderTab extends StatefulWidget {
  const ReorderTab({super.key});

  @override
  State<ReorderTab> createState() => _ReorderTabState();
}

class _ReorderTabState extends State<ReorderTab> {
  bool _isLoading = true;
  List<ReorderPrediction> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _fetchSuggestions();
  }

  Future<void> _fetchSuggestions() async {
    setState(() => _isLoading = true);
    try {
      final userId = sl<SessionManager>().ownerId;
      if (userId != null) {
        final result = await sl<ProductsRepository>()
            .getSmartReorderSuggestions(userId: userId);
        if (result.isSuccess) {
          setState(() => _suggestions = result.data ?? []);
        }
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_suggestions.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.check_circle_outline,
        title: "All sets!",
        description: "Stock levels look healthy based on sales velocity.",
        buttonLabel: "Refresh",
        onButtonPressed: _fetchSuggestions,
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchSuggestions,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          final prediction = _suggestions[index];
          return _buildPredictionCard(prediction);
        },
      ),
    );
  }

  Widget _buildPredictionCard(ReorderPrediction item) {
    final isCritical = item.isCritical;
    final color = isCritical
        ? FuturisticColors.error
        : FuturisticColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ModernCard(
        onTap: () {
          // Navigate to product details
          context.push('/product-details', extra: item.product.id);
        },
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.timelapse, color: color),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Stock: ${item.product.stockQuantity.toStringAsFixed(0)} ${item.product.unit}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    item.daysUntilEmpty == 0
                        ? "Empty!"
                        : "${item.daysUntilEmpty} Days Left",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Sales Velocity: ${item.dailyVelocity.toStringAsFixed(1)} / day",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _createDraftPurchaseOrder(item),
                  icon: const Icon(Icons.shopping_cart, size: 16),
                  label: const Text("Order Now"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FuturisticColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createDraftPurchaseOrder(ReorderPrediction item) async {
    // Calculate suggested order quantity (7 days worth + buffer)
    final suggestedQty = (item.dailyVelocity * 7).ceil();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create Purchase Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Product: ${item.product.name}'),
            const SizedBox(height: 8),
            Text(
              'Current Stock: ${item.product.stockQuantity.toStringAsFixed(0)} ${item.product.unit}',
            ),
            Text(
              'Daily Sales: ${item.dailyVelocity.toStringAsFixed(1)} ${item.product.unit}/day',
            ),
            const SizedBox(height: 12),
            Text(
              'Suggested Order: $suggestedQty ${item.product.unit}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create Order'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Navigate to purchase screen with pre-filled data
      context.push(
        '/add-purchase',
        extra: {
          'productId': item.product.id,
          'productName': item.product.name,
          'suggestedQty': suggestedQty,
        },
      );
    }
  }
}
