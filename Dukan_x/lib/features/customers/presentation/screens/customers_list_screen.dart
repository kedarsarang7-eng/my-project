import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/customers_repository.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/ui/smart_table.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import '../../../../widgets/ui/futuristic_button.dart';
import 'customer_detail_screen.dart';
import 'add_customer_screen.dart';
import '../../../billing/presentation/screens/bill_creation_screen_v2.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class CustomersListScreen extends ConsumerStatefulWidget {
  final bool isSelectionMode;
  const CustomersListScreen({super.key, this.isSelectionMode = false});

  @override
  ConsumerState<CustomersListScreen> createState() =>
      _CustomersListScreenState();
}

class _CustomersListScreenState extends ConsumerState<CustomersListScreen> {
  final _searchCtrl = TextEditingController();
  String _filter = 'All'; // All, Pending, Paid

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authStateProvider).userId;
    final customersAsync = ref.watch(customersStreamProvider(userId));

    return DesktopContentContainer(
      title: widget.isSelectionMode ? 'Select Customer' : 'Customer Database',
      actions: [
        if (!widget.isSelectionMode)
          DesktopActionButton(
            label: 'Add New',
            icon: Icons.person_add,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
            ),
            isPrimary: true,
          ),
      ],
      child: Column(
        children: [
          // Filter & Search Row
          Container(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: FuturisticColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search by Name or Phone...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: FuturisticColors.textSecondary,
                      ),
                      filled: true,
                      fillColor: FuturisticColors.surfaceHighlight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                _buildFilterButton('All'),
                _buildFilterButton('Pending'),
                _buildFilterButton('Paid'),
              ],
            ),
          ),
          Expanded(
            child: customersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Text(
                  'Error: $err',
                  style: const TextStyle(color: FuturisticColors.error),
                ),
              ),
              data: (customers) {
                // Filter Logic
                var filtered = customers.where((c) {
                  final query = _searchCtrl.text.toLowerCase();
                  final matchesSearch =
                      c.name.toLowerCase().contains(query) ||
                      (c.phone?.contains(query) ?? false);

                  if (_filter == 'Pending') {
                    return matchesSearch && c.totalDues > 0;
                  }
                  if (_filter == 'Paid') {
                    return matchesSearch && c.totalDues <= 0;
                  }
                  return matchesSearch;
                }).toList();

                return SmartTable<Customer>(
                  data: filtered,
                  emptyMessage: 'No customers found.',
                  onRowClick: (c) {
                    if (widget.isSelectionMode) {
                      Navigator.pop(context, c);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CustomerDetailScreen(customerId: c.id),
                        ),
                      );
                    }
                  },
                  columns: [
                    SmartTableColumn(
                      title: 'Customer Name',
                      flex: 2,
                      builder: (c) => Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: FuturisticColors.primary
                                .withOpacity(0.2),
                            child: Text(
                              _avatarInitial(c.name),
                              style: const TextStyle(
                                color: FuturisticColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              c.name.trim().isEmpty
                                  ? 'Unnamed Customer'
                                  : c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: FuturisticColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SmartTableColumn(
                      title: 'Phone',
                      flex: 1,
                      valueMapper: (c) => c.phone ?? '--',
                    ),
                    SmartTableColumn(
                      title: 'Outstanding Balance',
                      flex: 1,
                      builder: (c) => Text(
                        c.totalDues > 0
                            ? '₹${c.totalDues.toStringAsFixed(2)}'
                            : 'Settled',
                        style: TextStyle(
                          color: c.totalDues > 0
                              ? FuturisticColors.error
                              : FuturisticColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SmartTableColumn(
                      title: 'Actions',
                      flex: 1,
                      builder: (c) => Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.receipt_long,
                              color: FuturisticColors.accent1,
                              size: 20,
                            ),
                            tooltip: 'New Bill',
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    BillCreationScreenV2(initialCustomer: c),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.payment,
                              color: FuturisticColors.success,
                              size: 20,
                            ),
                            tooltip: 'Record Payment',
                            onPressed: () => _showPaymentDialog(c),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Safe first-letter for avatars — guards against empty/whitespace names
  /// which would otherwise throw a RangeError on `name[0]`.
  String _avatarInitial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }

  Widget _buildFilterButton(String filterName) {
    final isSelected = _filter == filterName;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(filterName),
        selected: isSelected,
        onSelected: (val) => setState(() => _filter = filterName),
        backgroundColor: FuturisticColors.surface,
        selectedColor: FuturisticColors.primary.withOpacity(0.2),
        labelStyle: TextStyle(
          color: isSelected
              ? FuturisticColors.primary
              : FuturisticColors.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        showCheckmark: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected
                ? FuturisticColors.primary
                : FuturisticColors.border,
          ),
        ),
      ),
    );
  }

  void _showPaymentDialog(Customer c) {
    final amountCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FuturisticColors.cardBackground,
        title: Text(
          'Record Payment: ${c.name}',
          style: const TextStyle(color: FuturisticColors.textPrimary),
        ),
        content: TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: FuturisticColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Amount Received',
            prefixText: '₹ ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FuturisticButton.primary(
            label: 'Confirm',
            icon: Icons.check,
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text);
              final userId = sl<SessionManager>().ownerId;
              if (amount != null && amount > 0 && userId != null) {
                final result = await sl<CustomersRepository>().recordPayment(
                  customerId: c.id,
                  amount: amount,
                  userId: userId,
                );
                if (mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        result.isSuccess
                            ? 'Payment Recorded'
                            : 'Failed: ${result.errorMessage}',
                      ),
                      backgroundColor: result.isSuccess
                          ? FuturisticColors.success
                          : FuturisticColors.error,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
