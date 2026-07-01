import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/book_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';

class ConsignmentSettlementScreen extends ConsumerStatefulWidget {
  const ConsignmentSettlementScreen({super.key});

  @override
  ConsumerState<ConsignmentSettlementScreen> createState() =>
      _ConsignmentSettlementScreenState();
}

class _ConsignmentSettlementScreenState
    extends ConsumerState<ConsignmentSettlementScreen> {
  List<Consignment> _consignments = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  static const int _pageLimit = 50;

  /// Whether the last fetch returned a full page, suggesting more data exists.
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchConsignments();
  }

  Future<void> _fetchConsignments() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _hasMore = true;
    });
    final result = await ref
        .read(bookRepositoryProvider)
        .getConsignments(page: _currentPage, limit: _pageLimit);
    if (!mounted) return;
    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load consignments: ${failure.message}'),
          ),
        );
      },
      (items) {
        setState(() {
          _consignments = items;
          _hasMore = items.length >= _pageLimit;
        });
      },
    );
    setState(() => _isLoading = false);
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    final nextPage = _currentPage + 1;
    final result = await ref
        .read(bookRepositoryProvider)
        .getConsignments(page: nextPage, limit: _pageLimit);
    if (!mounted) return;
    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load more: ${failure.message}')),
        );
      },
      (items) {
        setState(() {
          _currentPage = nextPage;
          _consignments.addAll(items);
          _hasMore = items.length >= _pageLimit;
        });
      },
    );
    setState(() => _isLoadingMore = false);
  }

  /// Derives the unit settlement price in integer Paise from the server-provided
  /// settlementAmount (rupees, double) divided by totalBooksSold.
  /// Returns null if totalBooksSold is zero (cannot compute a per-unit price).
  int? _unitSettlementPricePaise(Consignment item) {
    if (item.totalBooksSold <= 0) return null;
    // settlementAmount is the total expected settlement in rupees (double).
    // Convert to Paise and divide by books sold to get per-unit price in Paise.
    return (item.settlementAmount * 100 / item.totalBooksSold).round();
  }

  /// Computes the settlement cap in integer Paise:
  /// settlementCapPaise = totalBooksSold × unitSettlementPricePaise.
  /// Returns null when totalBooksSold is zero.
  int? _settlementCapPaise(Consignment item) {
    final unitPricePaise = _unitSettlementPricePaise(item);
    if (unitPricePaise == null) return null;
    return item.totalBooksSold * unitPricePaise;
  }

  /// Formats an integer Paise value as a rupee string (e.g. 12345 → "123.45").
  String _formatPaiseAsRupees(int paise) {
    final rupees = paise / 100;
    return rupees.toStringAsFixed(2);
  }

  void _showSettlementDialog(Consignment item) {
    // In-widget RBAC: verify the acting user holds makePayment permission
    // before allowing settlement — enforced independent of the entry path
    // since Content_Host applies no route guard (F28).
    final session = sl<SessionManager>();
    final userRole = session.currentSession.effectiveRole;
    if (!RolePermissions.hasPermission(userRole, Permission.makePayment)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Access denied: you don\'t have permission to perform this action',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Compute the settlement cap in integer Paise.
    final int? capPaise = _settlementCapPaise(item);

    // Pre-fill with the expected settlement in rupees (derived from the cap).
    final String prefillRupees = capPaise != null
        ? _formatPaiseAsRupees(capPaise)
        : item.settlementAmount.toStringAsFixed(2);

    final controller = TextEditingController(text: prefillRupees);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Settle with ${item.publisherName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Books Sold: ${item.totalBooksSold} / ${item.totalBooksReceived}',
              ),
              const SizedBox(height: 8),
              if (capPaise != null)
                Text(
                  'Expected settlement: ₹${_formatPaiseAsRupees(capPaise)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Settlement Amount (₹)',
                  border: OutlineInputBorder(),
                  prefixText: '₹ ',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final enteredRupees = double.tryParse(controller.text);
                // Convert user-entered rupees to integer Paise for all validation.
                final int proposedPaise = enteredRupees != null
                    ? (enteredRupees * 100).round()
                    : 0;

                // Reject zero-or-negative amount (persist nothing, validation error).
                if (proposedPaise <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Settlement amount must be greater than zero.',
                      ),
                    ),
                  );
                  return;
                }

                // Reject over-settlement (persist nothing, over-settlement error).
                if (capPaise != null && proposedPaise > capPaise) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Settlement amount exceeds the cap of '
                        '₹${_formatPaiseAsRupees(capPaise)}. Cannot over-settle.',
                      ),
                    ),
                  );
                  return;
                }

                // Valid: 0 < proposedPaise <= capPaise. Proceed with settlement.
                // Convert back to double at the call site (repository API takes double;
                // the signature will be updated in Phase 7 to use Paise).
                final double amountForRepo = proposedPaise / 100;

                Navigator.pop(dialogContext); // Close dialog
                if (!mounted) return;
                final result = await ref
                    .read(bookRepositoryProvider)
                    .processSettlement(item.id, amountForRepo);
                if (!mounted) return;
                result.fold(
                  (l) => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${l.message}')),
                  ),
                  (r) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Settlement processed successfully'),
                      ),
                    );
                    _fetchConsignments(); // Refresh list
                  },
                );
              },
              child: const Text('Confirm Settlement'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Publisher Consignments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchConsignments,
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _consignments.isEmpty
            ? const Center(child: Text('No active consignments'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _consignments.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  // "Load More" button at the end of the list
                  if (index == _consignments.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: _isLoadingMore
                            ? const CircularProgressIndicator()
                            : TextButton.icon(
                                onPressed: _loadMore,
                                icon: const Icon(Icons.expand_more),
                                label: const Text('Load More'),
                              ),
                      ),
                    );
                  }
                  final item = _consignments[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.publisherName,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Chip(
                                label: Text(item.status),
                                backgroundColor: item.status == 'settled'
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Received',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  Text(
                                    '${item.totalBooksReceived} books',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Sold',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  Text(
                                    '${item.totalBooksSold} books',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Unsold Return',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  Text(
                                    '${item.totalBooksReceived - item.totalBooksSold} books',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Amount Due: ₹${item.settlementAmount.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              ElevatedButton.icon(
                                onPressed: item.status == 'settled'
                                    ? null
                                    : () => _showSettlementDialog(item),
                                icon: const Icon(Icons.payment),
                                label: const Text('Settle'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
