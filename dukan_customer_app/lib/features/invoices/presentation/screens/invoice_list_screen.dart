import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dukanx_shared/dukanx_shared.dart';
import '../../../../core/navigation/app_router.dart';
import '../../data/invoice_repository.dart';

class InvoiceListScreen extends ConsumerStatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  ConsumerState<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends ConsumerState<InvoiceListScreen> {
  InvoiceStatus? _filterStatus;

  @override
  Widget build(BuildContext context) {
    final invoices = ref.watch(invoiceListProvider(_filterStatus));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_filterStatus != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Chip(
                    label: Text(_filterStatus!.name.toUpperCase()),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () =>
                        setState(() => _filterStatus = null),
                  ),
                ],
              ),
            ),
          Expanded(
            child: invoices.when(
              data: (list) => list.isEmpty
                  ? const EmptyStateWidget(
                      icon: Icons.receipt_long_outlined,
                      title: 'No invoices found',
                      subtitle: 'Your invoices from linked shops will appear here',
                    )
                  : RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(invoiceListProvider(_filterStatus)),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) => _InvoiceTile(invoice: list[i]),
                      ),
                    ),
              loading: () => const ListLoadingShimmer(),
              error: (e, _) => ErrorStateWidget(
                message: 'Could not load invoices',
                onRetry: () =>
                    ref.invalidate(invoiceListProvider(_filterStatus)),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(selectedIndex: 1),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All'),
              leading: const Icon(Icons.all_inclusive),
              selected: _filterStatus == null,
              onTap: () {
                setState(() => _filterStatus = null);
                Navigator.pop(context);
              },
            ),
            ...InvoiceStatus.values.map((s) => ListTile(
                  title: Text(s.name.toUpperCase()),
                  leading: InvoiceStatusBadge(status: s, compact: true),
                  selected: _filterStatus == s,
                  onTap: () {
                    setState(() => _filterStatus = s);
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  final CustomerInvoice invoice;
  const _InvoiceTile({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(
          '/invoices/${invoice.id}',
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.vendorBusinessName ?? invoice.vendorName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '# ${invoice.invoiceNumber}  ·  ${DateFormatter.format(invoice.invoiceDate)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(invoice.totalAmount),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  InvoiceStatusBadge(status: invoice.status, compact: true),
                ],
              ),
            ],
          ),
        ),
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
