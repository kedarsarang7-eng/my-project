import 'package:flutter/material.dart';
import '../models/customer_invoice.dart';

class InvoiceStatusBadge extends StatelessWidget {
  final InvoiceStatus status;
  final bool compact;

  const InvoiceStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color) = _config(status);
    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  static (String, Color) _config(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return ('PAID', const Color(0xFF43A047));
      case InvoiceStatus.partial:
        return ('PARTIAL', const Color(0xFFFB8C00));
      case InvoiceStatus.overdue:
        return ('OVERDUE', const Color(0xFFE53935));
      case InvoiceStatus.cancelled:
        return ('CANCELLED', const Color(0xFF9E9E9E));
      case InvoiceStatus.unpaid:
        return ('UNPAID', const Color(0xFFE53935));
    }
  }
}
