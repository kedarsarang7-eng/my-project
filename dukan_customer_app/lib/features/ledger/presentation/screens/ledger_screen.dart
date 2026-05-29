import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dukanx_shared/dukanx_shared.dart';
import '../../../../core/navigation/app_router.dart';
import '../../data/ledger_repository.dart';

class LedgerScreen extends ConsumerWidget {
  final String? vendorId;
  const LedgerScreen({super.key, this.vendorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(ledgerEntriesProvider(vendorId));
    final balance = ref.watch(ledgerBalanceProvider(vendorId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ledger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.payment_rounded),
            tooltip: 'Record Payment',
            onPressed: () => context.push(
              AppRoutes.recordPayment,
              extra: {'vendorId': vendorId},
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          balance.whenData((b) => _BalanceSummary(balance: b)).valueOrNull ??
              const SizedBox.shrink(),
          Expanded(
            child: entries.when(
              data: (list) => list.isEmpty
                  ? const EmptyStateWidget(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'No transactions yet',
                      subtitle: 'Your ledger entries will appear here',
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(ledgerEntriesProvider(vendorId));
                        ref.invalidate(ledgerBalanceProvider(vendorId));
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _LedgerTile(entry: list[i]),
                      ),
                    ),
              loading: () => const ListLoadingShimmer(itemHeight: 64),
              error: (e, _) => ErrorStateWidget(
                message: 'Could not load ledger',
                onRetry: () => ref.invalidate(ledgerEntriesProvider(vendorId)),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(selectedIndex: 2),
    );
  }
}

class _BalanceSummary extends StatelessWidget {
  final LedgerBalance balance;
  const _BalanceSummary({required this.balance});

  @override
  Widget build(BuildContext context) {
    final isOwed = balance.netBalance > 0;
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _StatCol(
              label: 'Total Billed',
              value: CurrencyFormatter.format(balance.totalDebit),
              color: const Color(0xFFE53935),
            ),
          ),
          Container(width: 1, height: 40, color: Theme.of(context).dividerColor),
          Expanded(
            child: _StatCol(
              label: 'Total Paid',
              value: CurrencyFormatter.format(balance.totalCredit),
              color: const Color(0xFF43A047),
            ),
          ),
          Container(width: 1, height: 40, color: Theme.of(context).dividerColor),
          Expanded(
            child: _StatCol(
              label: 'Balance',
              value: CurrencyFormatter.format(balance.netBalance.abs()),
              color: isOwed ? const Color(0xFFE53935) : const Color(0xFF43A047),
              subtitle: isOwed ? 'You owe' : 'You are owed',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String? subtitle;

  const _StatCol({
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (subtitle != null)
          Text(subtitle!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _LedgerTile extends StatelessWidget {
  final LedgerEntry entry;
  const _LedgerTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isCredit = entry.isCredit;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 48,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: isCredit ? const Color(0xFF43A047) : const Color(0xFFE53935),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description ??
                      (isCredit ? 'Payment received' : 'Invoice raised'),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${DateFormatter.format(entry.entryDate)}'
                  '${entry.referenceNumber != null ? '  ·  # ${entry.referenceNumber}' : ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+ ' : '- '}${CurrencyFormatter.format(entry.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isCredit
                      ? const Color(0xFF43A047)
                      : const Color(0xFFE53935),
                ),
              ),
              Text(
                'Bal: ${CurrencyFormatter.format(entry.runningBalance)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends ConsumerWidget {
  final int selectedIndex;
  const _BottomNav({required this.selectedIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (i) {
        switch (i) {
          case 0: context.go(AppRoutes.home);
          case 1: context.go(AppRoutes.invoices);
          case 2: context.go(AppRoutes.ledger);
          case 3: context.go(AppRoutes.profile);
        }
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Invoices'),
        NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'Ledger'),
        NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
      ],
    );
  }
}
