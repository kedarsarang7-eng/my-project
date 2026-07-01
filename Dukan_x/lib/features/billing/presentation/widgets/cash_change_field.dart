// ============================================================================
// Cash Change Calculator — Sprint 1: Cashier Safety
// ============================================================================
// Lets the cashier punch in the cash tendered by the customer and shows the
// change due in real time. Works in rupees (NOT paise) for cashier UX.
//
// Quick-fill chips are picked from common Indian denominations greater-or-equal
// to the bill total — pressing one fills the field instantly.
// ============================================================================

import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import 'package:flutter/services.dart';

/// Result emitted to the parent screen whenever the input changes.
@immutable
class CashTenderState {
  /// Amount tendered by the customer in rupees. `null` means the field is
  /// empty (cashier hasn't decided yet).
  final double? tenderedRupees;

  /// Change to return to the customer in rupees. Negative values mean the
  /// tender is short (cashier hasn't received enough yet).
  final double changeRupees;

  /// Whether the tender covers the bill total.
  final bool isSufficient;

  const CashTenderState({
    required this.tenderedRupees,
    required this.changeRupees,
    required this.isSufficient,
  });

  static const empty = CashTenderState(
    tenderedRupees: null,
    changeRupees: 0,
    isSufficient: false,
  );
}

/// Compact cash-received + change-due widget.
///
/// The widget owns its own controller so the parent only needs to react to
/// [onChanged] callbacks.
class CashChangeField extends StatefulWidget {
  /// Bill grand total in rupees. Updates here recompute the change.
  final double totalRupees;

  /// Called whenever the cashier types or clears the field.
  final ValueChanged<CashTenderState> onChanged;

  /// Optional initial tender (e.g. when rehydrating from a held bill).
  final double? initialTenderedRupees;

  /// Compact mode shrinks vertical padding for tight POS layouts.
  final bool compact;

  const CashChangeField({
    super.key,
    required this.totalRupees,
    required this.onChanged,
    this.initialTenderedRupees,
    this.compact = false,
  });

  @override
  State<CashChangeField> createState() => _CashChangeFieldState();
}

class _CashChangeFieldState extends State<CashChangeField> {
  late final TextEditingController _controller;
  double? _tendered;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialTenderedRupees != null
          ? widget.initialTenderedRupees!.toStringAsFixed(0)
          : '',
    );
    _tendered = widget.initialTenderedRupees;
    // Defer first emit until after build — parents often subscribe with setState.
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void didUpdateWidget(covariant CashChangeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totalRupees != widget.totalRupees) {
      _emit();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    final parsed = value.trim().isEmpty ? null : double.tryParse(value.trim());
    setState(() => _tendered = parsed);
    _emit();
  }

  void _emit() {
    final tendered = _tendered;
    final change = (tendered ?? 0) - widget.totalRupees;
    widget.onChanged(CashTenderState(
      tenderedRupees: tendered,
      changeRupees: change,
      isSufficient: tendered != null && change >= -0.001,
    ));
  }

  void _applyQuickFill(double amount) {
    _controller.text = amount.toStringAsFixed(0);
    _onTextChanged(_controller.text);
  }

  /// Common Indian cash denominations the cashier is likely to receive.
  /// We filter to those that actually cover the bill (cashier doesn't need
  /// a "₹100 button" suggestion when the bill is ₹740).
  List<double> _quickFillOptions() {
    const denominations = <double>[100, 200, 500, 1000, 2000];
    final total = widget.totalRupees;
    return denominations.where((double d) => d >= total).take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tendered = _tendered;
    final change = (tendered ?? 0) - widget.totalRupees;
    final hasInput = tendered != null;
    final isShort = hasInput && change < -0.001;
    final isExact = hasInput && change.abs() < 0.001;
    final isExcess = hasInput && change > 0.001;

    final Color statusColor = isShort
        ? cs.error
        : isExact
            ? Colors.green
            : isExcess
                ? cs.primary
                : cs.onSurfaceVariant;

    final String statusLabel = !hasInput
        ? 'Enter cash received'
        : isShort
            ? 'Short by ₹${(-change).toStringAsFixed(2)}'
            : isExact
                ? 'Exact tender — no change due'
                : 'Change due ₹${change.toStringAsFixed(2)}';

    final padding = widget.compact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
        : const EdgeInsets.all(12);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: false,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'Cash received',
                    prefixText: '₹ ',
                    border: const OutlineInputBorder(),
                  ),
                  style: theme.textTheme.titleMedium,
                  onChanged: _onTextChanged,
                ),
              ),
              const SizedBox(width: 12),
              _ChangeBadge(label: statusLabel, color: statusColor),
            ],
          ),
          if (_quickFillOptions().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _quickFillOptions()
                  .map<Widget>((double d) => ActionChip(
                        label: Text('₹${d.toStringAsFixed(0)}'),
                        onPressed: () => _applyQuickFill(d),
                      ))
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChangeBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _ChangeBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
