import 'package:flutter/material.dart';
import '../../data/models/dc_models.dart';

class DcStatusBadge extends StatelessWidget {
  final EventStatus status;
  const DcStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final dummy = EventBooking(
      id: '', customerId: '', customerName: '', customerPhone: '',
      eventType: EventType.other, eventTitle: '', eventDate: DateTime.now(),
      venue: '', guestCount: 0, quotedAmount: 0, createdAt: DateTime.now(),
      status: status,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: dummy.statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dummy.statusColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        dummy.statusLabel,
        style: TextStyle(fontSize: 11, color: dummy.statusColor, fontWeight: FontWeight.w600),
      ),
    );
  }
}
