// ============================================================================
// Split Payment Sheet — Sprint 1: Tender Split
// ============================================================================
// Bottom sheet that lets the cashier split a single bill across multiple tender
// types (cash, UPI, card, wallet, cheque, bank transfer, credit). Mirrors the
// `splitPayments` array supported by `createInvoiceSchema` on the backend.
//
// Hard rule: sum of split lines MUST equal bill total before the cashier can
// confirm. Variance is shown live so the cashier can adjust on the fly.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tender method. Strings match the backend `splitPayments[].method` enum.
enum SplitTenderMethod {
  cash('cash', 'Cash', Icons.payments_outlined),
  upi('upi', 'UPI', Icons.qr_code_2),
  card('card', 'Card', Icons.credit_card),
  wallet('wallet', 'Wallet', Icons.account_balance_wallet_outlined),
  bankTransfer('bank_transfer', 'Bank transfer', Icons.account_balance),
  cheque('cheque', 'Cheque', Icons.receipt_long_outlined),
  credit('credit', 'Credit (udhar)', Icons.handshake_outlined);

  final String wireValue;
  final String label;
  final IconData icon;
  const SplitTenderMethod(this.wireValue, this.label, this.icon);
}

/// One tender line in the split.
class SplitTenderLine {
  SplitTenderMethod method;
  /// Amount in rupees (we keep the cashier-facing unit; converted to paise
  /// when sent to the backend).
  double amountRupees;
  String? reference;

  SplitTenderLine({
    required this.method,
    required this.amountRupees,
    this.reference,
  });

  Map<String, dynamic> toApiJson() => <String, dynamic>{
    'method': method.wireValue,
    'amountCents': (amountRupees * 100).round(),
    if (reference != null && reference!.isNotEmpty) 'reference': reference,
  };
}

/// Result returned to the caller when the cashier confirms.
class SplitPaymentResult {
  final List<SplitTenderLine> lines;
  /// Cash sub-tender for downstream cash-change calculation.
  final double cashRupees;
  /// Sum of all non-cash tenders.
  final double nonCashRupees;

  SplitPaymentResult({
    required this.lines,
    required this.cashRupees,
    required this.nonCashRupees,
  });
}

/// Show the split payment sheet. Returns `null` if the cashier dismisses.
Future<SplitPaymentResult?> showSplitPaymentSheet({
  required BuildContext context,
  required double totalRupees,
  List<SplitTenderLine>? initialLines,
}) {
  return showModalBottomSheet<SplitPaymentResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext ctx) => _SplitPaymentSheet(
      totalRupees: totalRupees,
      initialLines: initialLines,
    ),
  );
}

class _SplitPaymentSheet extends StatefulWidget {
  final double totalRupees;
  final List<SplitTenderLine>? initialLines;

  const _SplitPaymentSheet({
    required this.totalRupees,
    this.initialLines,
  });

  @override
  State<_SplitPaymentSheet> createState() => _SplitPaymentSheetState();
}

class _SplitPaymentSheetState extends State<_SplitPaymentSheet> {
  late List<_LineDraft> _drafts;

  @override
  void initState() {
    super.initState();
    if (widget.initialLines != null && widget.initialLines!.isNotEmpty) {
      _drafts = widget.initialLines!
          .map((SplitTenderLine l) => _LineDraft.fromLine(l))
          .toList();
    } else {
      // Default seed: cashier almost always starts with full-cash.
      _drafts = <_LineDraft>[
        _LineDraft(
          method: SplitTenderMethod.cash,
          amountController:
              TextEditingController(text: widget.totalRupees.toStringAsFixed(2)),
        ),
      ];
    }
  }

  @override
  void dispose() {
    for (final _LineDraft d in _drafts) {
      d.amountController.dispose();
      d.referenceController.dispose();
    }
    super.dispose();
  }

  double get _enteredTotal => _drafts.fold<double>(
    0,
    (double acc, _LineDraft d) => acc + (d.amount() ?? 0),
  );

  double get _variance => _enteredTotal - widget.totalRupees;

  bool get _isBalanced => _variance.abs() < 0.005;

  void _addLine([SplitTenderMethod? method]) {
    if (_drafts.length >= 6) return; // backend cap
    final remaining = (widget.totalRupees - _enteredTotal).clamp(0, widget.totalRupees);
    setState(() {
      _drafts.add(_LineDraft(
        method: method ?? _firstUnusedMethod(),
        amountController: TextEditingController(
          text: remaining > 0 ? remaining.toStringAsFixed(2) : '',
        ),
      ));
    });
  }

  SplitTenderMethod _firstUnusedMethod() {
    final used = _drafts.map((_LineDraft d) => d.method).toSet();
    for (final SplitTenderMethod m in SplitTenderMethod.values) {
      if (!used.contains(m)) return m;
    }
    return SplitTenderMethod.cash;
  }

  void _removeLine(int index) {
    if (_drafts.length <= 1) return;
    setState(() {
      _drafts[index].amountController.dispose();
      _drafts[index].referenceController.dispose();
      _drafts.removeAt(index);
    });
  }

  void _autoBalance() {
    // Stuff the variance into the FIRST line — most natural cashier behaviour.
    if (_drafts.isEmpty) return;
    final first = _drafts.first;
    final current = first.amount() ?? 0;
    final adjusted = (current - _variance).clamp(0, double.infinity).toDouble();
    setState(() {
      first.amountController.text = adjusted.toStringAsFixed(2);
    });
  }

  void _confirm() {
    if (!_isBalanced) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _variance > 0
                ? 'Tender exceeds total by ₹${_variance.toStringAsFixed(2)}'
                : 'Tender short by ₹${(-_variance).toStringAsFixed(2)}',
          ),
        ),
      );
      return;
    }

    final lines = <SplitTenderLine>[];
    double cash = 0;
    double nonCash = 0;
    for (final _LineDraft d in _drafts) {
      final amt = d.amount() ?? 0;
      if (amt <= 0) continue;
      lines.add(SplitTenderLine(
        method: d.method,
        amountRupees: amt,
        reference: d.referenceController.text.trim().isEmpty
            ? null
            : d.referenceController.text.trim(),
      ));
      if (d.method == SplitTenderMethod.cash) {
        cash += amt;
      } else {
        nonCash += amt;
      }
    }

    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one tender line')),
      );
      return;
    }

    Navigator.of(context).pop(SplitPaymentResult(
      lines: lines,
      cashRupees: cash,
      nonCashRupees: nonCash,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.call_split, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Split tender',
                    style: theme.textTheme.titleLarge,
                  ),
                  const Spacer(),
                  Text(
                    'Total ₹${widget.totalRupees.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _drafts.length,
                  separatorBuilder: (BuildContext _, int _) =>
                      const SizedBox(height: 8),
                  itemBuilder: (BuildContext ctx, int idx) =>
                      _buildLineTile(idx),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  TextButton.icon(
                    onPressed: _drafts.length < 6 ? _addLine : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Add tender'),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _isBalanced ? null : _autoBalance,
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('Auto-balance'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildVarianceBanner(theme),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: _isBalanced ? _confirm : null,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(_isBalanced
                      ? 'Confirm split'
                      : 'Balance to ₹${widget.totalRupees.toStringAsFixed(2)} first'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVarianceBanner(ThemeData theme) {
    final cs = theme.colorScheme;
    final isOver = _variance > 0.005;
    // Under-tender path is implicit: !_isBalanced && !isOver implies under.
    final color = _isBalanced ? Colors.green : (isOver ? cs.error : cs.tertiary);
    final label = _isBalanced
        ? 'Balanced. Entered ₹${_enteredTotal.toStringAsFixed(2)}'
        : isOver
            ? 'Over by ₹${_variance.toStringAsFixed(2)}'
            : 'Remaining ₹${(-_variance).toStringAsFixed(2)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            _isBalanced
                ? Icons.check_circle
                : (isOver
                    ? Icons.warning_amber_outlined
                    : Icons.timelapse_outlined),
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildLineTile(int idx) {
    final draft = _drafts[idx];
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: <Widget>[
          DropdownButton<SplitTenderMethod>(
            value: draft.method,
            underline: const SizedBox.shrink(),
            items: SplitTenderMethod.values
                .map<DropdownMenuItem<SplitTenderMethod>>(
                  (SplitTenderMethod m) => DropdownMenuItem<SplitTenderMethod>(
                    value: m,
                    child: Row(
                      children: <Widget>[
                        Icon(m.icon, size: 18),
                        const SizedBox(width: 6),
                        Text(m.label),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (SplitTenderMethod? m) {
              if (m == null) return;
              setState(() => draft.method = m);
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: draft.amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                isDense: true,
                prefixText: '₹ ',
                hintText: 'Amount',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          IconButton(
            tooltip: 'Remove tender',
            onPressed: _drafts.length > 1 ? () => _removeLine(idx) : null,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _LineDraft {
  SplitTenderMethod method;
  TextEditingController amountController;
  TextEditingController referenceController;

  _LineDraft({
    required this.method,
    required this.amountController,
    TextEditingController? referenceController,
  }) : referenceController = referenceController ?? TextEditingController();

  factory _LineDraft.fromLine(SplitTenderLine line) => _LineDraft(
    method: line.method,
    amountController:
        TextEditingController(text: line.amountRupees.toStringAsFixed(2)),
    referenceController: TextEditingController(text: line.reference ?? ''),
  );

  double? amount() {
    final text = amountController.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }
}
