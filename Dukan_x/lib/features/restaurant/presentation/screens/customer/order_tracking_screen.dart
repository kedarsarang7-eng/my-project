// ============================================================================
// ORDER TRACKING SCREEN (CUSTOMER)
// ============================================================================
// Shows real-time order status for customer

import 'package:flutter/material.dart';
import '../../../../../core/theme/futuristic_colors.dart';
import '../../../data/models/food_order_model.dart';
import '../../../data/repositories/food_order_repository.dart';
import 'rate_review_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final String? tableNumber;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    this.tableNumber,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with SingleTickerProviderStateMixin {
  final FoodOrderRepository _orderRepo = FoodOrderRepository();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.orderId.substring(0, 8)}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: StreamBuilder<FoodOrder?>(
        stream: _orderRepo.watchOrder(widget.orderId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final order = snapshot.data;
          if (order == null) {
            return const Center(child: Text('Order not found'));
          }

          return _buildOrderTrackingContent(order);
        },
      ),
      ),
    );
  }

  Widget _buildOrderTrackingContent(FoodOrder order) {
    final statusInfo = _getStatusInfo(order.orderStatus);

    return Column(
      children: [
        // Status header
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                statusInfo.color.withValues(alpha: 0.2),
                Colors.transparent,
              ],
            ),
          ),
          child: Column(
            children: [
              // Animated status icon
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_pulseController.value * 0.1),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusInfo.color.withValues(alpha: 0.2),
                        border: Border.all(color: statusInfo.color, width: 3),
                      ),
                      child: Icon(
                        statusInfo.icon,
                        size: 50,
                        color: statusInfo.color,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                statusInfo.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: statusInfo.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                statusInfo.subtitle,
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        // Progress tracker
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _buildProgressTracker(order),
        ),

        const SizedBox(height: 24),

        // Order details
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order Details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (order.tableNumber != null)
                      Chip(
                        label: Text('Table ${order.tableNumber}'),
                        avatar: const Icon(Icons.table_restaurant, size: 16),
                      ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: order.items.length,
                    itemBuilder: (context, index) {
                      final item = order.items[index];
                      return ListTile(
                        leading: CircleAvatar(child: Text('${item.quantity}')),
                        title: Text(item.itemName),
                        trailing: Text(
                          '₹${item.totalPrice.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(),
                // Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '₹${order.grandTotal.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Bill request button
                if (order.orderStatus == FoodOrderStatus.served &&
                    !order.billRequested)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _requestBill(order.id),
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('REQUEST BILL'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                if (order.billRequested && order.billId == null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.hourglass_empty, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Bill requested - Waiter will bring it soon',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ],
                    ),
                  ),

                // Rate & Review button
                if (order.orderStatus == FoodOrderStatus.completed ||
                    order.orderStatus == FoodOrderStatus.served)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RateReviewScreen(
                              orderId: order.id,
                              restaurantName: 'Restaurant',
                              review: order.reviewRating != null
                                  ? {
                                      'rating': order.reviewRating,
                                      'text': order.reviewText,
                                    }
                                  : null,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.star),
                        label: Text(
                          order.reviewRating != null
                              ? 'EDIT REVIEW'
                              : 'RATE & REVIEW',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressTracker(FoodOrder order) {
    final steps = [
      _ProgressStep(
        icon: Icons.receipt_long,
        label: 'Placed',
        isCompleted: true,
        time: order.orderTime,
      ),
      _ProgressStep(
        icon: Icons.check_circle,
        label: 'Accepted',
        isCompleted: order.acceptedAt != null,
        time: order.acceptedAt,
      ),
      _ProgressStep(
        icon: Icons.soup_kitchen,
        label: 'Cooking',
        isCompleted: order.cookingStartedAt != null,
        time: order.cookingStartedAt,
      ),
      _ProgressStep(
        icon: Icons.done_all,
        label: 'Ready',
        isCompleted: order.readyAt != null,
        time: order.readyAt,
      ),
      _ProgressStep(
        icon: Icons.room_service,
        label: 'Served',
        isCompleted: order.servedAt != null,
        time: order.servedAt,
      ),
    ];

    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          // Connector line
          final stepIndex = index ~/ 2;
          final isCompleted = steps[stepIndex + 1].isCompleted;
          return Expanded(
            child: Container(
              height: 3,
              color: isCompleted
                  ? FuturisticColors.success
                  : Colors.grey.shade300,
            ),
          );
        }

        // Step circle
        final step = steps[index ~/ 2];
        return _buildStepIndicator(step);
      }),
    );
  }

  Widget _buildStepIndicator(_ProgressStep step) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: step.isCompleted
                ? FuturisticColors.success
                : Colors.grey.shade300,
          ),
          child: Icon(
            step.icon,
            color: step.isCompleted ? Colors.white : Colors.grey,
            size: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          step.label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: step.isCompleted ? FontWeight.bold : FontWeight.normal,
            color: step.isCompleted ? FuturisticColors.success : Colors.grey,
          ),
        ),
        if (step.time != null)
          Text(
            _formatTime(step.time!),
            style: const TextStyle(fontSize: 9, color: Colors.grey),
          ),
      ],
    );
  }

  _StatusInfo _getStatusInfo(FoodOrderStatus status) {
    switch (status) {
      case FoodOrderStatus.pending:
        return _StatusInfo(
          icon: Icons.hourglass_empty,
          title: 'Order Placed',
          subtitle: 'Waiting for restaurant to accept',
          color: Colors.orange,
        );
      case FoodOrderStatus.accepted:
        return _StatusInfo(
          icon: Icons.thumb_up,
          title: 'Order Accepted',
          subtitle: 'Restaurant is preparing your order',
          color: Colors.blue,
        );
      case FoodOrderStatus.cooking:
        return _StatusInfo(
          icon: Icons.soup_kitchen,
          title: 'Being Prepared',
          subtitle: 'Your delicious food is being cooked',
          color: Colors.deepOrange,
        );
      case FoodOrderStatus.ready:
        return _StatusInfo(
          icon: Icons.done_all,
          title: 'Ready!',
          subtitle: 'Your order is ready and will be served shortly',
          color: FuturisticColors.success,
        );
      case FoodOrderStatus.served:
        return _StatusInfo(
          icon: Icons.restaurant,
          title: 'Enjoy Your Meal!',
          subtitle: 'Your order has been served',
          color: Colors.teal,
        );
      case FoodOrderStatus.completed:
        return _StatusInfo(
          icon: Icons.check_circle,
          title: 'Completed',
          subtitle: 'Thank you for dining with us!',
          color: FuturisticColors.success,
        );
      case FoodOrderStatus.cancelled:
        return _StatusInfo(
          icon: Icons.cancel,
          title: 'Cancelled',
          subtitle: 'This order was cancelled',
          color: FuturisticColors.error,
        );
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _requestBill(String orderId) async {
    await _orderRepo.requestBill(orderId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bill requested! Waiter will bring it shortly.'),
          backgroundColor: FuturisticColors.success,
        ),
      );
    }
  }
}

class _ProgressStep {
  final IconData icon;
  final String label;
  final bool isCompleted;
  final DateTime? time;

  _ProgressStep({
    required this.icon,
    required this.label,
    required this.isCompleted,
    this.time,
  });
}

class _StatusInfo {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  _StatusInfo({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}
