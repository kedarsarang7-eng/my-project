// ============================================================================
// DeliveryStatusChip Widget — Maps real lifecycle states to colored chips
// ============================================================================
// Only real statuses: queued, sent, delivered, read, failed, expired.
// Never fabricated/synthetic states.
// ============================================================================

import 'package:flutter/material.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../data/models/outbound_message_model.dart';
import '../../data/models/delivery_log_model.dart';

/// Chip for outbound message status.
class DeliveryStatusChip extends StatelessWidget {
  final OutboundMessageStatus status;

  const DeliveryStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _statusStyle(status.value);
    return _buildChip(status.value, color, icon);
  }

  static (Color, IconData) _statusStyle(String status) {
    return switch (status) {
      'queued' => (Colors.blueGrey, Icons.schedule),
      'sent' => (Colors.blue, Icons.check),
      'delivered' => (FuturisticColors.success, Icons.done_all),
      'read' => (Colors.teal, Icons.visibility),
      'failed' => (FuturisticColors.error, Icons.error_outline),
      'expired' => (FuturisticColors.warning, Icons.timer_off),
      _ => (FuturisticColors.textMuted, Icons.help_outline),
    };
  }

  static Widget _buildChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip for delivery log state (includes 'suppressed').
class DeliveryLogStateChip extends StatelessWidget {
  final DeliveryLogState state;

  const DeliveryLogStateChip({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _stateStyle(state.value);
    return DeliveryStatusChip._buildChip(state.value, color, icon);
  }

  static (Color, IconData) _stateStyle(String state) {
    return switch (state) {
      'queued' => (Colors.blueGrey, Icons.schedule),
      'sent' => (Colors.blue, Icons.check),
      'delivered' => (FuturisticColors.success, Icons.done_all),
      'read' => (Colors.teal, Icons.visibility),
      'failed' => (FuturisticColors.error, Icons.error_outline),
      'expired' => (FuturisticColors.warning, Icons.timer_off),
      'suppressed' => (Colors.purple, Icons.block),
      _ => (FuturisticColors.textMuted, Icons.help_outline),
    };
  }
}
