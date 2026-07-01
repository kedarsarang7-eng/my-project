import 'package:flutter/material.dart';
import '../../models/business_order_models.dart';

/// Badge widget displaying the visual status of a business order.
class OrderStatusBadge extends StatelessWidget {
  final BusinessOrderStatus status;
  final bool compact;

  const OrderStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final label = _getLabel();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: compact ? 10 : 12,
        ),
      ),
    );
  }

  Color _getColor() {
    switch (status) {
      case BusinessOrderStatus.placed:
        return Colors.blue;
      case BusinessOrderStatus.accepted:
        return Colors.teal;
      case BusinessOrderStatus.preparing:
        return Colors.orange;
      case BusinessOrderStatus.readyForDispatch:
        return Colors.indigo;
      case BusinessOrderStatus.outForDelivery:
        return Colors.purple;
      case BusinessOrderStatus.delivered:
        return Colors.green;
      case BusinessOrderStatus.cancelled:
      case BusinessOrderStatus.rejected:
        return Colors.red;
    }
  }

  String _getLabel() {
    return status.name
        .replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m.group(0)}')
        .trim()
        .toUpperCase();
  }
}
