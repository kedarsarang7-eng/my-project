// ============================================================================
// CUSTOMER ACTION BUTTONS WIDGET
// ============================================================================
// Action buttons panel for Customer Profile page.
// Provides quick actions: Create Bill, Estimate, Challan, Payment, Credit Note
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';

/// Customer action button data
class CustomerAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const CustomerAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

/// Customer Action Buttons Widget
///
/// A grid of action buttons for common customer operations.
/// Used in Customer Profile screen.
class CustomerActionButtons extends StatelessWidget {
  final String customerId;
  final String customerName;
  final VoidCallback onCreateBill;
  final VoidCallback onCreateEstimate;
  final VoidCallback onDeliveryChallan;
  final VoidCallback onReceivePayment;
  final VoidCallback onIssueCreditNote;
  final VoidCallback onAddRemark;

  const CustomerActionButtons({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.onCreateBill,
    required this.onCreateEstimate,
    required this.onDeliveryChallan,
    required this.onReceivePayment,
    required this.onIssueCreditNote,
    required this.onAddRemark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final actions = [
      CustomerAction(
        icon: Icons.receipt_long_rounded,
        label: 'Create Bill',
        color: Colors.green,
        onTap: onCreateBill,
      ),
      CustomerAction(
        icon: Icons.description_rounded,
        label: 'Estimate',
        color: Colors.blue,
        onTap: onCreateEstimate,
      ),
      CustomerAction(
        icon: Icons.local_shipping_rounded,
        label: 'Challan',
        color: Colors.orange,
        onTap: onDeliveryChallan,
      ),
      CustomerAction(
        icon: Icons.payments_rounded,
        label: 'Payment',
        color: Colors.teal,
        onTap: onReceivePayment,
      ),
      CustomerAction(
        icon: Icons.assignment_return_rounded,
        label: 'Credit Note',
        color: Colors.purple,
        onTap: onIssueCreditNote,
      ),
      CustomerAction(
        icon: Icons.note_add_rounded,
        label: 'Add Note',
        color: Colors.indigo,
        onTap: onAddRemark,
      ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              return _ActionButton(
                icon: action.icon,
                label: action.label,
                color: action.color,
                onTap: action.onTap,
                isDark: isDark,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
