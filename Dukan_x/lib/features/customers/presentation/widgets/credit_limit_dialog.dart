// ============================================================================
// CREDIT LIMIT DIALOG WIDGET
// ============================================================================
// Dialog for viewing and managing customer credit limits.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Result of credit limit dialog
class CreditLimitDialogResult {
  final double? newLimit;
  final bool removed;

  const CreditLimitDialogResult({this.newLimit, this.removed = false});
}

/// Credit Limit Dialog
///
/// Shows current credit details and allows setting/updating credit limit.
class CreditLimitDialog extends StatefulWidget {
  final String customerName;
  final double currentOutstanding;
  final double currentCreditLimit;

  const CreditLimitDialog({
    super.key,
    required this.customerName,
    required this.currentOutstanding,
    required this.currentCreditLimit,
  });

  /// Show the dialog and return the result
  static Future<CreditLimitDialogResult?> show({
    required BuildContext context,
    required String customerName,
    required double currentOutstanding,
    required double currentCreditLimit,
  }) {
    return showDialog<CreditLimitDialogResult>(
      context: context,
      builder: (context) => CreditLimitDialog(
        customerName: customerName,
        currentOutstanding: currentOutstanding,
        currentCreditLimit: currentCreditLimit,
      ),
    );
  }

  @override
  State<CreditLimitDialog> createState() => _CreditLimitDialogState();
}

class _CreditLimitDialogState extends State<CreditLimitDialog> {
  late TextEditingController _limitController;
  bool _isUnlimited = false;

  @override
  void initState() {
    super.initState();
    _isUnlimited = widget.currentCreditLimit <= 0;
    _limitController = TextEditingController(
      text: _isUnlimited ? '' : widget.currentCreditLimit.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final availableCredit = widget.currentCreditLimit > 0
        ? widget.currentCreditLimit - widget.currentOutstanding
        : null;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.credit_score, color: Colors.blue, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Credit Limit',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  widget.customerName,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    'Current Outstanding',
                    '₹${widget.currentOutstanding.toStringAsFixed(0)}',
                    widget.currentOutstanding > 0
                        ? Colors.orange
                        : Colors.green,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'Current Limit',
                    _isUnlimited
                        ? 'Unlimited'
                        : '₹${widget.currentCreditLimit.toStringAsFixed(0)}',
                    Colors.blue,
                  ),
                  if (availableCredit != null) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Available Credit',
                      '₹${availableCredit.toStringAsFixed(0)}',
                      availableCredit > 0 ? Colors.green : Colors.red,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Unlimited Toggle
            Row(
              children: [
                Switch.adaptive(
                  value: _isUnlimited,
                  onChanged: (val) {
                    setState(() {
                      _isUnlimited = val;
                      if (val) _limitController.clear();
                    });
                  },
                  activeColor: Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  'Unlimited Credit',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Credit Limit Input
            if (!_isUnlimited) ...[
              TextField(
                controller: _limitController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  labelText: 'Credit Limit',
                  prefixText: '₹ ',
                  prefixStyle: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  hintText: 'Enter limit amount',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white30 : Colors.grey,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Quick Preset Buttons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPresetButton('₹5K', 5000),
                  _buildPresetButton('₹10K', 10000),
                  _buildPresetButton('₹25K', 25000),
                  _buildPresetButton('₹50K', 50000),
                  _buildPresetButton('₹1L', 100000),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: isDark ? Colors.white60 : Colors.grey),
          ),
        ),
        if (widget.currentCreditLimit > 0)
          TextButton(
            onPressed: () {
              Navigator.pop(
                context,
                const CreditLimitDialogResult(removed: true),
              );
            },
            child: const Text(
              'Remove Limit',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ElevatedButton(
          onPressed: () {
            final limit = _isUnlimited
                ? 0.0
                : double.tryParse(_limitController.text) ?? 0;
            Navigator.pop(context, CreditLimitDialogResult(newLimit: limit));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.grey,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildPresetButton(String label, double value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () {
        _limitController.text = value.toStringAsFixed(0);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
