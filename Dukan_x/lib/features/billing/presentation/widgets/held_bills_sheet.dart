// ============================================================================
// Held Bills Sheet — Sprint 1: Resume Picker
// ============================================================================
// Bottom sheet that lists every held (parked) bill for the tenant. The cashier
// taps one to resume (atomically deletes the hold and returns the cart) or
// long-presses to discard.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/held_bills_service.dart';

/// Show the held-bills picker. Returns the held bill the cashier picked, or
/// `null` if they dismissed.
Future<HeldBill?> showHeldBillsSheet({
  required BuildContext context,
  HeldBillsService? service,
}) {
  return showModalBottomSheet<HeldBill>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext ctx) => _HeldBillsSheet(
      service: service ?? HeldBillsService(),
    ),
  );
}

class _HeldBillsSheet extends StatefulWidget {
  final HeldBillsService service;
  const _HeldBillsSheet({required this.service});

  @override
  State<_HeldBillsSheet> createState() => _HeldBillsSheetState();
}

class _HeldBillsSheetState extends State<_HeldBillsSheet> {
  late Future<List<HeldBill>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.service.list();
  }

  void _refresh() {
    setState(() {
      _future = widget.service.list();
    });
  }

  Future<void> _resume(HeldBill bill) async {
    try {
      final HeldBill resumed = await widget.service.resume(bill.id);
      if (!mounted) return;
      Navigator.of(context).pop(resumed);
    } on HeldBillException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not resume: ${e.message}')),
      );
      _refresh();
    }
  }

  Future<void> _confirmDiscard(HeldBill bill) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Discard held bill?'),
        content: Text('"${bill.label}" will be permanently removed.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await widget.service.discard(bill.id);
      if (!mounted) return;
      _refresh();
    } on HeldBillException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not discard: ${e.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.pause_circle_outline, color: cs.primary),
                  const SizedBox(width: 8),
                  Text('Held bills', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: FutureBuilder<List<HeldBill>>(
                  future: _future,
                  builder: (BuildContext ctx,
                      AsyncSnapshot<List<HeldBill>> snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return _ErrorState(
                        message: snapshot.error.toString(),
                        onRetry: _refresh,
                      );
                    }
                    final bills = snapshot.data ?? const <HeldBill>[];
                    if (bills.isEmpty) {
                      return const _EmptyState();
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: bills.length,
                      separatorBuilder: (BuildContext _, int _) => const Divider(height: 1),
                      itemBuilder: (BuildContext ctx, int idx) {
                        final HeldBill bill = bills[idx];
                        return _HeldBillTile(
                          bill: bill,
                          onTap: () => _resume(bill),
                          onDiscard: () => _confirmDiscard(bill),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeldBillTile extends StatelessWidget {
  final HeldBill bill;
  final VoidCallback onTap;
  final VoidCallback onDiscard;

  const _HeldBillTile({
    required this.bill,
    required this.onTap,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFmt = DateFormat('h:mm a').format(bill.createdAt.toLocal());
    final age = DateTime.now().difference(bill.createdAt);
    final ageLabel = age.inMinutes < 1
        ? 'just now'
        : age.inMinutes < 60
            ? '${age.inMinutes}m ago'
            : age.inHours < 24
                ? '${age.inHours}h ago'
                : '${age.inDays}d ago';

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      title: Text(
        bill.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (bill.customerName != null)
            Text(
              '${bill.customerName}'
              '${bill.customerPhone != null ? ' · ${bill.customerPhone}' : ''}',
              style: theme.textTheme.bodySmall,
            ),
          Text(
            '${bill.itemCount} item${bill.itemCount == 1 ? '' : 's'} · '
            '$timeFmt · $ageLabel',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '₹${(bill.totalCents / 100).toStringAsFixed(2)}',
            style: theme.textTheme.titleMedium,
          ),
          IconButton(
            tooltip: 'Discard',
            onPressed: onDiscard,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.pause_circle_outline,
            size: 48,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            'No held bills',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Press Hold on the billing screen to park the current cart and free the lane.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.error_outline,
              size: 40, color: theme.colorScheme.error),
          const SizedBox(height: 8),
          Text('Could not load held bills',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(message,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
