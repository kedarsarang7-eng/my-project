import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/book_repository.dart';
import 'package:dukanx/core/responsive/responsive.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';

class SchoolOrderScreen extends ConsumerStatefulWidget {
  const SchoolOrderScreen({super.key});

  @override
  ConsumerState<SchoolOrderScreen> createState() => _SchoolOrderScreenState();
}

class _SchoolOrderScreenState extends ConsumerState<SchoolOrderScreen> {
  List<SchoolOrder> _orders = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  static const int _pageLimit = 50;

  /// Whether the last fetch returned a full page, suggesting more data exists.
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _hasMore = true;
    });
    final result = await ref
        .read(bookRepositoryProvider)
        .getSchoolOrders(page: _currentPage, limit: _pageLimit);
    if (!mounted) return;
    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load orders: ${failure.message}')),
        );
      },
      (orders) {
        setState(() {
          _orders = orders;
          _hasMore = orders.length >= _pageLimit;
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
        .getSchoolOrders(page: nextPage, limit: _pageLimit);
    if (!mounted) return;
    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load more: ${failure.message}')),
        );
      },
      (orders) {
        setState(() {
          _currentPage = nextPage;
          _orders.addAll(orders);
          _hasMore = orders.length >= _pageLimit;
        });
      },
    );
    setState(() => _isLoadingMore = false);
  }

  void _showFulfillDialog(SchoolOrder order) {
    // In-widget RBAC: verify the acting user holds editStock permission
    // before allowing order fulfillment — enforced independent of the entry
    // path since Content_Host applies no route guard (F28).
    final session = sl<SessionManager>();
    final userRole = session.currentSession.effectiveRole;
    if (!RolePermissions.hasPermission(userRole, Permission.editStock)) {
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

    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Fulfill Order: ${order.schoolName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Grade: ${order.grade}'),
              Text('Pending Sets: ${order.totalSets - order.fulfilledSets}'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Sets to fulfill',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final sets = int.tryParse(controller.text) ?? 0;
                if (sets <= 0 ||
                    sets > (order.totalSets - order.fulfilledSets)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid number of sets')),
                  );
                  return;
                }

                Navigator.pop(context); // Close dialog
                if (!mounted) return;
                final result = await ref
                    .read(bookRepositoryProvider)
                    .fulfillSchoolOrder(order.id, sets);
                if (!mounted) return;
                result.fold(
                  (l) => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${l.message}')),
                  ),
                  (r) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Order fulfilled successfully'),
                      ),
                    );
                    _fetchOrders(); // Refresh list
                  },
                );
              },
              child: const Text('Confirm'),
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
        title: const Text('School Bulk Orders'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchOrders),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _orders.isEmpty
            ? const Center(child: Text('No active school orders'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _orders.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  // "Load More" button at the end of the list
                  if (index == _orders.length) {
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
                  final order = _orders[index];
                  final progress = order.fulfilledSets / order.totalSets;
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
                                order.schoolName,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Chip(label: Text(order.status)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Grade: ${order.grade}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Progress: ${order.fulfilledSets} / ${order.totalSets} sets',
                              ),
                              Text('${(progress * 100).toStringAsFixed(1)}%'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(value: progress),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: order.status == 'completed'
                                  ? null
                                  : () => _showFulfillDialog(order),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Fulfill Sets'),
                            ),
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
