// ============================================================================
// PaymentModeSelector - Widget for selecting payment mode
// ============================================================================

import 'package:flutter/material.dart';

enum SelectedPaymentMode { cash, upi, card, online }

class PaymentModeSelector extends StatelessWidget {
  final SelectedPaymentMode selectedMode;
  final ValueChanged<SelectedPaymentMode> onModeChanged;
  final double totalAmount;
  final bool isMerchantOnboarded;

  const PaymentModeSelector({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
    required this.totalAmount,
    this.isMerchantOnboarded = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Payment Mode',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // CASH Option
            _buildPaymentOption(
              context: context,
              mode: SelectedPaymentMode.cash,
              icon: Icons.money,
              title: 'Cash',
              subtitle: 'Accept cash payment',
              color: Colors.green,
            ),
            
            const SizedBox(height: 8),
            
            // UPI Option (requires onboarding)
            _buildPaymentOption(
              context: context,
              mode: SelectedPaymentMode.upi,
              icon: Icons.qr_code,
              title: 'UPI / QR Code',
              subtitle: isMerchantOnboarded
                  ? 'Scan QR to pay via UPI apps'
                  : 'Merchant onboarding required',
              color: Colors.blue,
              enabled: isMerchantOnboarded,
            ),
            
            const SizedBox(height: 8),
            
            // CARD Option
            _buildPaymentOption(
              context: context,
              mode: SelectedPaymentMode.card,
              icon: Icons.credit_card,
              title: 'Card',
              subtitle: 'Credit/Debit card payment',
              color: Colors.purple,
            ),
            
            const SizedBox(height: 8),
            
            // ONLINE Option
            _buildPaymentOption(
              context: context,
              mode: SelectedPaymentMode.online,
              icon: Icons.language,
              title: 'Online Payment',
              subtitle: 'Other online methods',
              color: Colors.orange,
            ),
            
            const SizedBox(height: 16),
            
            // Amount Display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Amount',
                    style: theme.textTheme.bodyLarge,
                  ),
                  Text(
                    '₹${totalAmount.toStringAsFixed(2)}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required BuildContext context,
    required SelectedPaymentMode mode,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    final isSelected = selectedMode == mode;

    return InkWell(
      onTap: enabled ? () => onModeChanged(mode) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? color : theme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? color.withValues(alpha: 0.1) : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: enabled ? color.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: enabled ? color : Colors.grey,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: enabled ? null : Colors.grey,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: enabled ? theme.hintColor : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: color,
              ),
            if (!enabled)
              const Icon(
                Icons.lock,
                color: Colors.grey,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Compact version for inline use
// ============================================================================
class PaymentModeChips extends StatelessWidget {
  final SelectedPaymentMode selectedMode;
  final ValueChanged<SelectedPaymentMode> onModeChanged;
  final bool showUPI;

  const PaymentModeChips({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
    this.showUPI = true,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _buildChip(
          context: context,
          mode: SelectedPaymentMode.cash,
          label: 'Cash',
          icon: Icons.money,
        ),
        if (showUPI)
          _buildChip(
            context: context,
            mode: SelectedPaymentMode.upi,
            label: 'UPI',
            icon: Icons.qr_code,
          ),
        _buildChip(
          context: context,
          mode: SelectedPaymentMode.card,
          label: 'Card',
          icon: Icons.credit_card,
        ),
        _buildChip(
          context: context,
          mode: SelectedPaymentMode.online,
          label: 'Online',
          icon: Icons.language,
        ),
      ],
    );
  }

  Widget _buildChip({
    required BuildContext context,
    required SelectedPaymentMode mode,
    required String label,
    required IconData icon,
  }) {
    final isSelected = selectedMode == mode;

    return ChoiceChip(
      selected: isSelected,
      onSelected: (_) => onModeChanged(mode),
      avatar: Icon(
        icon,
        size: 18,
        color: isSelected ? Colors.white : null,
      ),
      label: Text(label),
      selectedColor: Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
      ),
    );
  }
}
