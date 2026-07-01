// ============================================================================
// Day-End Cash Close Screen — Sprint 1 (Desktop UI Pass)
// ============================================================================
// Follows the same enterprise desktop pattern as DesktopInvoicesScreen:
//   - DesktopContentContainer for the page chrome (title + subtitle + actions)
//   - NeonCard wrappers for each section
//   - FuturisticColors palette throughout
//   - Two-column layout on wide viewports, stacked on narrow ones
//
// Cashier UX:
//   1. Server pre-computes "expected cash" (Σ cash leg of today's invoices).
//   2. Cashier counts the drawer using the denomination grid; we sum live.
//   3. Variance shown live; matched closes go straight through, mismatches
//      land in `mismatch_pending` and the owner can approve in-place.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import '../../../../widgets/desktop/neon_card.dart';
import '../../data/day_end_cash_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class DayEndCloseScreen extends StatefulWidget {
  final DayEndCashService? service;

  /// Optional ISO date (YYYY-MM-DD). Defaults to today.
  final String? closingDate;

  const DayEndCloseScreen({super.key, this.service, this.closingDate});

  @override
  State<DayEndCloseScreen> createState() => _DayEndCloseScreenState();
}

class _DayEndCloseScreenState extends State<DayEndCloseScreen> {
  late final DayEndCashService _service;
  late final String _closingDate;

  Future<CashClosingPreview>? _previewFuture;
  CashClosingRecord? _existingRecord;

  /// Per-denomination count, keyed by paise face value.
  final Map<int, int> _counts = <int, int>{
    for (final int v in kIndianCashDenominationsPaise) v: 0,
  };

  /// Per-denomination text controller — let cashier punch numbers naturally.
  final Map<int, TextEditingController> _controllers =
      <int, TextEditingController>{};

  final TextEditingController _noteController = TextEditingController();

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? DayEndCashService();
    _closingDate = widget.closingDate ?? _today();
    for (final int v in kIndianCashDenominationsPaise) {
      _controllers[v] = TextEditingController();
    }
    _refresh();
  }

  @override
  void dispose() {
    for (final TextEditingController c in _controllers.values) {
      c.dispose();
    }
    _noteController.dispose();
    super.dispose();
  }

  String _today() => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> _refresh() async {
    setState(() {
      _previewFuture = _service.preview(date: _closingDate);
      _existingRecord = null;
    });

    try {
      final CashClosingRecord? existing =
          await _service.getByDate(_closingDate);
      if (!mounted) return;
      setState(() => _existingRecord = existing);
    } on CashClosingException {
      // 404 already returns null; other errors surface via FutureBuilder.
    }
  }

  int get _countedPaise => _counts.entries.fold<int>(
    0,
    (int acc, MapEntry<int, int> e) => acc + e.key * e.value,
  );

  void _setCount(int valuePaise, String raw) {
    final parsed = int.tryParse(raw.trim());
    setState(() => _counts[valuePaise] = parsed ?? 0);
  }

  Future<void> _submit(int expectedPaise, int tolerancePaise) async {
    if (_existingRecord != null) return;
    if (_countedPaise <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Count at least one denomination')),
      );
      return;
    }
    final variancePaise = expectedPaise - _countedPaise;
    final isOver = variancePaise.abs() > tolerancePaise;
    if (isOver) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          backgroundColor: FuturisticColors.surface,
          title: const Text(
            'Variance exceeds tolerance',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            variancePaise > 0
                ? 'Drawer is short by ₹${(variancePaise / 100).toStringAsFixed(2)}.\n'
                      'Closing will be recorded as MISMATCH and require owner approval.'
                : 'Drawer is over by ₹${(-variancePaise / 100).toStringAsFixed(2)}.\n'
                      'Closing will be recorded as MISMATCH and require owner approval.',
            style: TextStyle(color: FuturisticColors.textSecondary),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Recount'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Submit anyway'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _submitting = true);
    try {
      final List<CashDenomination> denoms = _counts.entries
          .where((MapEntry<int, int> e) => e.value > 0)
          .map(
            (MapEntry<int, int> e) =>
                CashDenomination(valuePaise: e.key, count: e.value),
          )
          .toList(growable: false);
      final record = await _service.recordClose(
        countedCashPaise: _countedPaise,
        denominations: denoms,
        cashierNote: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        closingDate: _closingDate,
      );
      if (!mounted) return;
      setState(() => _existingRecord = record);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Day closed — ${record.status.label}'),
          backgroundColor: record.status == CashClosingStatus.matched
              ? FuturisticColors.success
              : FuturisticColors.error,
        ),
      );
    } on CashClosingException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${e.message}')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _approveExisting() async {
    final c = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: FuturisticColors.surface,
        title: const Text(
          'Approve variance',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 500,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Reason',
            border: OutlineInputBorder(),
            hintText: 'Why is the variance acceptable?',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(c.text.trim()),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    c.dispose();
    if (reason == null || reason.isEmpty) return;

    setState(() => _submitting = true);
    try {
      final record = await _service.approve(date: _closingDate, reason: reason);
      if (!mounted) return;
      setState(() => _existingRecord = record);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Variance approved')),
      );
    } on CashClosingException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approve failed: ${e.message}')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat.yMMMMEEEEd().format(
      DateTime.parse('${_closingDate}T00:00:00'),
    );

    return Container(
      decoration: BoxDecoration(
        gradient: FuturisticColors.darkBackgroundGradient,
      ),
      child: DesktopContentContainer(
        title: 'Day-End Cash Close',
        subtitle: 'Reconcile counted drawer against expected cash · $dateLabel',
        actions: <Widget>[
          DesktopIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh',
            onPressed: _submitting ? null : _refresh,
          ),
        ],
        child: FutureBuilder<CashClosingPreview>(
          future: _previewFuture,
          builder: (BuildContext ctx, AsyncSnapshot<CashClosingPreview> snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(
                  child: CircularProgressIndicator(
                    color: FuturisticColors.premiumBlue,
                  ),
                ),
              );
            }
            if (snap.hasError) {
              return _ErrorPanel(
                message: snap.error.toString(),
                onRetry: _refresh,
              );
            }
            final preview = snap.data!;
            final variancePaise =
                _existingRecord?.variancePaise ??
                (preview.expectedCashPaise - _countedPaise);
            final isExisting = _existingRecord != null;
            final tolerance = preview.tolerancePaise;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _MetricsRow(
                  expectedPaise: preview.expectedCashPaise,
                  countedPaise: _existingRecord?.countedCashPaise ?? _countedPaise,
                  variancePaise: variancePaise,
                  tolerancePaise: tolerance,
                ),
                const SizedBox(height: 24),

                // Body — two columns on wide, stacked on narrow.
                LayoutBuilder(
                  builder: (BuildContext ctx, BoxConstraints constraints) {
                    final isWide = constraints.maxWidth >= 1100;
                    final left = _DenominationCard(
                      counts: _counts,
                      controllers: _controllers,
                      onChanged: _setCount,
                      enabled: !_submitting && !isExisting,
                      lockedRecord: _existingRecord,
                    );
                    final right = _SidePanel(
                      preview: preview,
                      countedPaise: _existingRecord?.countedCashPaise ?? _countedPaise,
                      variancePaise: variancePaise,
                      noteController: _noteController,
                      submitting: _submitting,
                      existingRecord: _existingRecord,
                      onSubmit: () => _submit(preview.expectedCashPaise, tolerance),
                      onApprove: _approveExisting,
                    );
                    if (!isWide) {
                      return Column(
                        children: <Widget>[
                          left,
                          const SizedBox(height: 16),
                          right,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(flex: 3, child: left),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: right),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Top metrics row ───────────────────────────────────────────────────────

class _MetricsRow extends StatelessWidget {
  final int expectedPaise;
  final int countedPaise;
  final int variancePaise;
  final int tolerancePaise;

  const _MetricsRow({
    required this.expectedPaise,
    required this.countedPaise,
    required this.variancePaise,
    required this.tolerancePaise,
  });

  @override
  Widget build(BuildContext context) {
    final isMatched = variancePaise == 0;
    final isOver = variancePaise.abs() > tolerancePaise;
    final varianceColor = isMatched
        ? FuturisticColors.success
        : isOver
        ? FuturisticColors.error
        : FuturisticColors.warning;
    final varianceLabel = isMatched
        ? 'Exact match'
        : (variancePaise > 0
              ? 'Short by ₹${(variancePaise / 100).toStringAsFixed(2)}'
              : 'Over by ₹${(-variancePaise / 100).toStringAsFixed(2)}');

    return Row(
      children: <Widget>[
        Expanded(
          child: _MetricCard(
            label: 'Expected cash',
            valueRupees: expectedPaise / 100.0,
            icon: Icons.account_balance_wallet_outlined,
            color: FuturisticColors.premiumBlue,
            footer: 'From today\'s cash sales',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _MetricCard(
            label: 'Counted drawer',
            valueRupees: countedPaise / 100.0,
            icon: Icons.payments_outlined,
            color: FuturisticColors.accent1,
            footer: 'Sum of denominations',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _MetricCard(
            label: 'Variance',
            valueRupees: variancePaise / 100.0,
            icon: isMatched
                ? Icons.check_circle_outline
                : Icons.warning_amber_outlined,
            color: varianceColor,
            footer:
                '$varianceLabel · tol ₹${(tolerancePaise / 100).toStringAsFixed(0)}',
            showSign: true,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatefulWidget {
  final String label;
  final double valueRupees;
  final IconData icon;
  final Color color;
  final String footer;
  final bool showSign;

  const _MetricCard({
    required this.label,
    required this.valueRupees,
    required this.icon,
    required this.color,
    required this.footer,
    this.showSign = false,
  });

  @override
  State<_MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<_MetricCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final formatted = widget.showSign
        ? '${widget.valueRupees >= 0 ? '+' : ''}₹${widget.valueRupees.abs().toStringAsFixed(2)}'
        : '₹${widget.valueRupees.toStringAsFixed(2)}';

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              FuturisticColors.surface,
              FuturisticColors.surface.withValues(alpha: 0.85),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.color.withValues(alpha: _hover ? 0.55 : 0.25),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: widget.color.withValues(alpha: _hover ? 0.25 : 0.1),
              blurRadius: _hover ? 24 : 14,
              spreadRadius: _hover ? 1 : 0,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        widget.color.withValues(alpha: 0.25),
                        widget.color.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: widget.color.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 22),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              widget.label,
              style: TextStyle(
                color: FuturisticColors.textSecondary,
                fontSize: 13,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              formatted,
              style: TextStyle(
                color: widget.showSign ? widget.color : Colors.white,
                fontSize: responsiveValue<double>(context, mobile: 20, tablet: 22, desktop: 26),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.footer,
              style: TextStyle(
                color: FuturisticColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Denomination card ────────────────────────────────────────────────────

class _DenominationCard extends StatelessWidget {
  final Map<int, int> counts;
  final Map<int, TextEditingController> controllers;
  final void Function(int valuePaise, String raw) onChanged;
  final bool enabled;
  final CashClosingRecord? lockedRecord;

  const _DenominationCard({
    required this.counts,
    required this.controllers,
    required this.onChanged,
    required this.enabled,
    this.lockedRecord,
  });

  @override
  Widget build(BuildContext context) {
    final isLocked = lockedRecord != null;
    return NeonCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.grid_view_rounded,
                color: FuturisticColors.premiumBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Drawer count',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (isLocked)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: FuturisticColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: FuturisticColors.warning.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.lock_outline,
                        size: 14,
                        color: FuturisticColors.warning,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Read-only',
                        style: TextStyle(
                          color: FuturisticColors.warning,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isLocked
                ? 'Day already closed — counts shown for audit reference'
                : 'Enter how many of each note/coin are in the drawer',
            style: TextStyle(
              color: FuturisticColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          // Header strip
          _denomHeaderRow(),
          const Divider(color: Colors.white12, height: 1),
          ...kIndianCashDenominationsPaise.map<Widget>(
            (int valuePaise) =>
                _denomRow(valuePaise, isLocked: isLocked),
          ),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),
          _grandTotalRow(context),
        ],
      ),
    );
  }

  Widget _denomHeaderRow() {
    final labelStyle = TextStyle(
      color: FuturisticColors.textSecondary,
      fontSize: 12,
      letterSpacing: 0.5,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          SizedBox(width: 96, child: Text('DENOMINATION', style: labelStyle)),
          SizedBox(width: 130, child: Text('COUNT', style: labelStyle)),
          Expanded(
            child: Text(
              'SUBTOTAL',
              style: labelStyle,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _denomRow(int valuePaise, {required bool isLocked}) {
    final count = counts[valuePaise] ?? 0;
    final subtotalRupees = (valuePaise * count) / 100.0;
    final faceRupees = valuePaise ~/ 100;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          // Face value pill
          SizedBox(
            width: 96,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: FuturisticColors.premiumBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: FuturisticColors.premiumBlue.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                '₹$faceRupees',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          // Count input
          SizedBox(
            width: 130,
            child: TextField(
              controller: controllers[valuePaise],
              enabled: !isLocked,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                isDense: true,
                hintText: '0',
                hintStyle: TextStyle(
                  color: FuturisticColors.textSecondary,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: FuturisticColors.premiumBlue,
                  ),
                ),
              ),
              onChanged: (String v) => onChanged(valuePaise, v),
            ),
          ),
          // Subtotal
          Expanded(
            child: Text(
              '₹${subtotalRupees.toStringAsFixed(2)}',
              textAlign: TextAlign.end,
              style: TextStyle(
                color: count > 0
                    ? Colors.white
                    : FuturisticColors.textSecondary,
                fontSize: 15,
                fontWeight: count > 0 ? FontWeight.w600 : FontWeight.normal,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _grandTotalRow(BuildContext context) {
    final total = counts.entries.fold<int>(
      0,
      (int acc, MapEntry<int, int> e) => acc + e.key * e.value,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: FuturisticColors.premiumBlue.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: FuturisticColors.premiumBlue.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.functions,
            color: FuturisticColors.premiumBlue,
            size: 18,
          ),
          const SizedBox(width: 8),
          const Text(
            'Total counted',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '₹${(total / 100).toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
              fontWeight: FontWeight.w700,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Side panel (note + actions OR existing record) ──────────────────────

class _SidePanel extends StatelessWidget {
  final CashClosingPreview preview;
  final int countedPaise;
  final int variancePaise;
  final TextEditingController noteController;
  final bool submitting;
  final CashClosingRecord? existingRecord;
  final VoidCallback onSubmit;
  final VoidCallback onApprove;

  const _SidePanel({
    required this.preview,
    required this.countedPaise,
    required this.variancePaise,
    required this.noteController,
    required this.submitting,
    required this.existingRecord,
    required this.onSubmit,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    if (existingRecord != null) {
      return _ExistingRecordCard(
        record: existingRecord!,
        onApprove: submitting ? null : onApprove,
      );
    }

    final isOver = variancePaise.abs() > preview.tolerancePaise;
    final canSubmit = countedPaise > 0;

    return NeonCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: const <Widget>[
              Icon(
                Icons.fact_check_outlined,
                color: FuturisticColors.premiumBlue,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Close summary',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SummaryRow(
            label: 'Expected',
            value: '₹${(preview.expectedCashPaise / 100).toStringAsFixed(2)}',
          ),
          _SummaryRow(
            label: 'Counted',
            value: '₹${(countedPaise / 100).toStringAsFixed(2)}',
          ),
          const Divider(color: Colors.white12, height: 24),
          _SummaryRow(
            label: 'Variance',
            value: variancePaise == 0
                ? '₹0.00'
                : (variancePaise > 0
                      ? '-₹${(variancePaise / 100).toStringAsFixed(2)}'
                      : '+₹${(-variancePaise / 100).toStringAsFixed(2)}'),
            valueColor: variancePaise == 0
                ? FuturisticColors.success
                : (isOver ? FuturisticColors.error : FuturisticColors.warning),
            emphasize: true,
          ),
          _SummaryRow(
            label: 'Tolerance',
            value: '±₹${(preview.tolerancePaise / 100).toStringAsFixed(2)}',
          ),
          const SizedBox(height: 18),
          if (isOver) _MismatchHintBanner(),
          if (isOver) const SizedBox(height: 12),
          TextField(
            controller: noteController,
            enabled: !submitting,
            maxLength: 500,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Cashier note (optional)',
              labelStyle: TextStyle(
                color: FuturisticColors.textSecondary,
              ),
              hintText: 'e.g. ₹50 from petty cash float',
              hintStyle: TextStyle(
                color: FuturisticColors.textSecondary,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: FuturisticColors.premiumBlue,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _PrimaryActionButton(
            label: submitting
                ? 'Closing day…'
                : (isOver ? 'Submit with mismatch' : 'Close day'),
            icon: isOver ? Icons.warning_amber_rounded : Icons.lock_outlined,
            color: isOver
                ? FuturisticColors.warning
                : FuturisticColors.premiumBlue,
            loading: submitting,
            enabled: canSubmit && !submitting,
            onPressed: onSubmit,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasize;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: FuturisticColors.textSecondary,
              fontSize: 13,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: emphasize ? 18 : 14,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _MismatchHintBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FuturisticColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: FuturisticColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.warning_amber_rounded,
            color: FuturisticColors.warning,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Variance exceeds tolerance — close will require owner approval before being treated as final.',
              style: TextStyle(
                color: FuturisticColors.textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Existing record card ─────────────────────────────────────────────────

class _ExistingRecordCard extends StatelessWidget {
  final CashClosingRecord record;
  final VoidCallback? onApprove;

  const _ExistingRecordCard({required this.record, this.onApprove});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (record.status) {
      CashClosingStatus.matched => FuturisticColors.success,
      CashClosingStatus.mismatchPending => FuturisticColors.error,
      CashClosingStatus.mismatchApproved => FuturisticColors.warning,
    };
    final statusIcon = switch (record.status) {
      CashClosingStatus.matched => Icons.check_circle_outline,
      CashClosingStatus.mismatchPending => Icons.warning_amber_rounded,
      CashClosingStatus.mismatchApproved => Icons.verified_outlined,
    };

    return NeonCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.lock_outlined,
                color: FuturisticColors.premiumBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Already closed',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _StatusBadge(
                status: record.status,
                color: statusColor,
                icon: statusIcon,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SummaryRow(
            label: 'Expected',
            value: '₹${record.expectedCashRupees.toStringAsFixed(2)}',
          ),
          _SummaryRow(
            label: 'Counted',
            value: '₹${record.countedCashRupees.toStringAsFixed(2)}',
          ),
          _SummaryRow(
            label: 'Variance',
            value: record.variancePaise == 0
                ? '₹0.00'
                : (record.variancePaise > 0
                      ? '-₹${(record.variancePaise / 100).toStringAsFixed(2)}'
                      : '+₹${(-record.variancePaise / 100).toStringAsFixed(2)}'),
            valueColor: statusColor,
            emphasize: true,
          ),
          _SummaryRow(
            label: 'Tolerance',
            value: '±₹${(record.tolerancePaise / 100).toStringAsFixed(2)}',
          ),
          const Divider(color: Colors.white12, height: 24),
          _SummaryRow(
            label: 'Closed at',
            value: DateFormat('MMM d, yyyy · h:mm a')
                .format(record.createdAt.toLocal()),
          ),
          if (record.cashierNote != null && record.cashierNote!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _NotePanel(
              label: 'Cashier note',
              text: record.cashierNote!,
              color: FuturisticColors.premiumBlue,
            ),
          ],
          if (record.approvedBy != null && record.approvedAt != null) ...<Widget>[
            const SizedBox(height: 12),
            _NotePanel(
              label:
                  'Approved by ${record.approvedBy} · ${DateFormat('MMM d, h:mm a').format(record.approvedAt!.toLocal())}',
              text: record.approvalReason ?? '',
              color: FuturisticColors.warning,
            ),
          ],
          if (record.needsApproval && onApprove != null) ...<Widget>[
            const SizedBox(height: 18),
            _PrimaryActionButton(
              label: 'Approve variance (owner)',
              icon: Icons.verified_outlined,
              color: FuturisticColors.warning,
              onPressed: onApprove!,
              enabled: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final CashClosingStatus status;
  final Color color;
  final IconData icon;

  const _StatusBadge({
    required this.status,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotePanel extends StatelessWidget {
  final String label;
  final String text;
  final Color color;

  const _NotePanel({
    required this.label,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          if (text.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Primary action button ────────────────────────────────────────────────

class _PrimaryActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.enabled = true,
    this.loading = false,
  });

  @override
  State<_PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<_PrimaryActionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final disabled = !widget.enabled;
    final c = disabled ? widget.color.withValues(alpha: 0.4) : widget.color;
    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: disabled ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                c.withValues(alpha: _hover && !disabled ? 1.0 : 0.85),
                c.withValues(alpha: _hover && !disabled ? 0.9 : 0.75),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: <BoxShadow>[
              if (!disabled)
                BoxShadow(
                  color: c.withValues(alpha: _hover ? 0.45 : 0.3),
                  blurRadius: _hover ? 18 : 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (widget.loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Icon(widget.icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Error panel ──────────────────────────────────────────────────────────

class _ErrorPanel extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorPanel({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return NeonCard(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(
            Icons.error_outline,
            size: 48,
            color: FuturisticColors.error,
          ),
          const SizedBox(height: 12),
          const Text(
            'Could not load expected cash',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: TextStyle(
              color: FuturisticColors.textSecondary,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          DesktopActionButton(
            icon: Icons.refresh_rounded,
            label: 'Retry',
            onPressed: onRetry,
            isPrimary: true,
          ),
        ],
      ),
    );
  }
}
