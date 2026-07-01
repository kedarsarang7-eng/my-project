import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/repository/purchase_repository.dart';
import '../../../../providers/app_state_providers.dart';
import 'package:dukanx/core/responsive/responsive.dart';
import '../../data/book_repository.dart';

/// Book Supplier & Returns Management Screen
///
/// Two tabs:
/// 1. Purchase Orders — Restock from publishers
/// 2. Publisher Returns — Return unsold/dead stock (backed by Book_Repository)
///
/// Data flow:
///   Purchase Orders → PurchaseOrders table → inventory stock update → SyncQueue
///   Publisher Returns → POST/GET /book-store/returns → tenant-scoped, integer Paise
class BookSupplierReturnsScreen extends ConsumerStatefulWidget {
  const BookSupplierReturnsScreen({super.key});

  @override
  ConsumerState<BookSupplierReturnsScreen> createState() =>
      _BookSupplierReturnsScreenState();
}

class _BookSupplierReturnsScreenState
    extends ConsumerState<BookSupplierReturnsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Publisher Returns state
  List<BookReturn> _returns = [];
  bool _returnsLoading = false;
  String? _returnsError;
  String? _selectedStatusFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _returns.isEmpty && !_returnsLoading) {
        _loadReturns();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReturns() async {
    setState(() {
      _returnsLoading = true;
      _returnsError = null;
    });
    final bookRepo = ref.read(bookRepositoryProvider);
    final result = await bookRepo.listReturns(status: _selectedStatusFilter);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _returnsLoading = false;
        _returnsError = failure.message;
      }),
      (items) => setState(() {
        _returnsLoading = false;
        _returns = items;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;
    const accent = Color(0xFF8B5CF6);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F0B1A)
          : const Color(0xFFF8F6FF),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Icon(Icons.local_shipping_rounded, color: accent, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Suppliers & Returns',
                    style: TextStyle(
                      fontSize: responsiveValue<double>(
                        context,
                        mobile: 18,
                        tablet: 20,
                        desktop: 22,
                      ),
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: isDark
                    ? Colors.white54
                    : Colors.grey.shade600,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 18),
                        SizedBox(width: 6),
                        Text('Purchase Orders'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_return_outlined, size: 18),
                        SizedBox(width: 6),
                        Text('Publisher Returns'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPurchaseOrdersTab(isDark, accent),
                  _buildPublisherReturnsTab(isDark, accent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 1: PURCHASE ORDERS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildPurchaseOrdersTab(bool isDark, Color accent) {
    return Padding(
      padding: EdgeInsets.all(
        responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
      ),
      child: Column(
        children: [
          // Action Row
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _showNewPurchaseOrderDialog(isDark, accent),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New Purchase Order'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const Spacer(),
              _buildFilterChip('All', true, isDark, accent),
              const SizedBox(width: 6),
              _buildFilterChip('Pending', false, isDark, accent),
              const SizedBox(width: 6),
              _buildFilterChip('Received', false, isDark, accent),
            ],
          ),
          const SizedBox(height: 16),

          // PO List
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1128) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 48,
                      color: accent.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No purchase orders yet',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white38 : Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create a PO to restock from publishers',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 2: PUBLISHER RETURNS (Functional — backed by Book_Repository)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildPublisherReturnsTab(bool isDark, Color accent) {
    return Padding(
      padding: EdgeInsets.all(
        responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24),
      ),
      child: Column(
        children: [
          // Action Row
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _showNewReturnDialog(isDark, accent),
                icon: const Icon(Icons.assignment_return_rounded, size: 18),
                label: const Text('New Return'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _loadReturns,
                icon: Icon(
                  Icons.refresh_rounded,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
                tooltip: 'Refresh returns',
              ),
              const Spacer(),
              _buildReturnFilterChip(
                'All',
                _selectedStatusFilter == null,
                isDark,
                accent,
                () {
                  setState(() => _selectedStatusFilter = null);
                  _loadReturns();
                },
              ),
              const SizedBox(width: 6),
              _buildReturnFilterChip(
                'Draft',
                _selectedStatusFilter == 'draft',
                isDark,
                accent,
                () {
                  setState(() => _selectedStatusFilter = 'draft');
                  _loadReturns();
                },
              ),
              const SizedBox(width: 6),
              _buildReturnFilterChip(
                'Sent',
                _selectedStatusFilter == 'sent',
                isDark,
                accent,
                () {
                  setState(() => _selectedStatusFilter = 'sent');
                  _loadReturns();
                },
              ),
              const SizedBox(width: 6),
              _buildReturnFilterChip(
                'Accepted',
                _selectedStatusFilter == 'accepted',
                isDark,
                accent,
                () {
                  setState(() => _selectedStatusFilter = 'accepted');
                  _loadReturns();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Returns List
          Expanded(child: _buildReturnsContent(isDark, accent)),
        ],
      ),
    );
  }

  Widget _buildReturnsContent(bool isDark, Color accent) {
    if (_returnsLoading) {
      return Container(
        decoration: _listContainerDecoration(isDark),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_returnsError != null) {
      return Container(
        decoration: _listContainerDecoration(isDark),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 12),
              Text(
                'Failed to load returns',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _returnsError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _loadReturns,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_returns.isEmpty) {
      return Container(
        decoration: _listContainerDecoration(isDark),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.assignment_return_outlined,
                size: 48,
                color: Colors.orange.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 12),
              Text(
                'No publisher returns',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white38 : Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Return unsold books to publishers',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: _listContainerDecoration(isDark),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _returns.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        itemBuilder: (context, index) =>
            _buildReturnCard(_returns[index], isDark),
      ),
    );
  }

  BoxDecoration _listContainerDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? const Color(0xFF1A1128) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
    );
  }

  Widget _buildReturnCard(BookReturn ret, bool isDark) {
    final amountRupees = (ret.totalAmountPaise / 100).toStringAsFixed(2);
    final statusColor = _statusColor(ret.status);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.15),
        child: Icon(
          Icons.assignment_return_rounded,
          color: statusColor,
          size: 20,
        ),
      ),
      title: Text(
        ret.vendorName ?? ret.vendorId,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: isDark ? Colors.white : const Color(0xFF1E1B4B),
        ),
      ),
      subtitle: Text(
        '${ret.returnDate} • ${ret.items.length} item(s)',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white54 : Colors.grey.shade600,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '₹$amountRupees',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: isDark ? Colors.white : const Color(0xFF1E1B4B),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              ret.status.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return Colors.orange;
      case 'sent':
        return Colors.blue;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildReturnFilterChip(
    String label,
    bool isSelected,
    bool isDark,
    Color accent,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.15)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? accent.withValues(alpha: 0.4)
                : (isDark ? Colors.white10 : Colors.grey.shade200),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? accent
                : (isDark ? Colors.white54 : Colors.grey.shade600),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    bool isSelected,
    bool isDark,
    Color accent,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? accent.withValues(alpha: 0.15)
            : (isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? accent.withValues(alpha: 0.4)
              : (isDark ? Colors.white10 : Colors.grey.shade200),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected
              ? accent
              : (isDark ? Colors.white54 : Colors.grey.shade600),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // DIALOGS
  // ═══════════════════════════════════════════════════════════════

  void _showNewPurchaseOrderDialog(bool isDark, Color accent) {
    final vendorCtrl = TextEditingController();
    final invoiceCtrl = TextEditingController();
    final totalCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1128) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.shopping_cart_outlined, color: accent),
            const SizedBox(width: 8),
            Text(
              'New Purchase Order',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _poField(vendorCtrl, 'Publisher / Vendor Name *', isDark),
                const SizedBox(height: 10),
                _poField(invoiceCtrl, 'Invoice Number', isDark),
                const SizedBox(height: 10),
                _poField(
                  totalCtrl,
                  'Total Amount (₹) *',
                  isDark,
                  isNumber: true,
                ),
                const SizedBox(height: 10),
                _poField(notesCtrl, 'Notes', isDark),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final vendor = vendorCtrl.text.trim();
              final total = double.tryParse(totalCtrl.text.trim()) ?? 0;
              if (vendor.isEmpty || total <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vendor name and total amount are required'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final userId = sl<SessionManager>().ownerId;
              if (userId == null) return;

              final result = await purchaseRepository.createPurchaseOrder(
                userId: userId,
                vendorName: vendor,
                invoiceNumber: invoiceCtrl.text.trim().isNotEmpty
                    ? invoiceCtrl.text.trim()
                    : null,
                totalAmount: total,
                paidAmount: total,
                paymentMode: 'Cash',
                notes: notesCtrl.text.trim().isNotEmpty
                    ? notesCtrl.text.trim()
                    : null,
                items: [
                  PurchaseItem(
                    id: const Uuid().v4(),
                    productId: '',
                    productName: 'Books from $vendor',
                    quantity: 1,
                    costPrice: total,
                    totalAmount: total,
                  ),
                ],
              );

              if (ctx.mounted) Navigator.pop(ctx);
              if (!mounted) return;

              if (result.isSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Purchase order from $vendor created'),
                    backgroundColor: accent,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed: ${result.errorMessage}'),
                    backgroundColor: Colors.red.shade700,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create PO'),
          ),
        ],
      ),
    );
  }

  void _showNewReturnDialog(bool isDark, Color accent) {
    final vendorNameCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    // Start with one empty item row
    final itemControllers = <_ReturnItemControllers>[_ReturnItemControllers()];
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1128) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.assignment_return_rounded,
                color: Colors.orange.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                'New Publisher Return',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _poField(vendorNameCtrl, 'Publisher / Vendor Name *', isDark),
                  const SizedBox(height: 14),
                  Text(
                    'Return Items',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(itemControllers.length, (i) {
                    final ic = itemControllers[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _poField(
                              ic.nameCtrl,
                              'Title / ISBN',
                              isDark,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 1,
                            child: _poField(
                              ic.qtyCtrl,
                              'Qty',
                              isDark,
                              isNumber: true,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 2,
                            child: _poField(
                              ic.priceCtrl,
                              'Price (₹)',
                              isDark,
                              isNumber: true,
                            ),
                          ),
                          const SizedBox(width: 4),
                          if (itemControllers.length > 1)
                            IconButton(
                              onPressed: () {
                                setDialogState(
                                  () => itemControllers.removeAt(i),
                                );
                              },
                              icon: Icon(
                                Icons.remove_circle_outline,
                                color: Colors.red.shade400,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Remove item',
                            ),
                        ],
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () {
                      setDialogState(
                        () => itemControllers.add(_ReturnItemControllers()),
                      );
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Item'),
                  ),
                  const SizedBox(height: 10),
                  _poField(notesCtrl, 'Notes (optional)', isDark),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final vendorName = vendorNameCtrl.text.trim();
                      if (vendorName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vendor name is required'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      // Build items — price entered in rupees, convert to Paise
                      final items = <ReturnItem>[];
                      for (final ic in itemControllers) {
                        final name = ic.nameCtrl.text.trim();
                        final qty = int.tryParse(ic.qtyCtrl.text.trim()) ?? 0;
                        final priceRupees =
                            double.tryParse(ic.priceCtrl.text.trim()) ?? 0;
                        if (qty <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Each item must have qty > 0'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        if (priceRupees < 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Price cannot be negative'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        // Convert rupees to integer Paise
                        final pricePaise = (priceRupees * 100).round();
                        items.add(
                          ReturnItem(
                            name: name.isNotEmpty ? name : null,
                            qty: qty,
                            pricePaise: pricePaise,
                          ),
                        );
                      }
                      if (items.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Add at least one item'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => submitting = true);
                      final bookRepo = ref.read(bookRepositoryProvider);
                      final result = await bookRepo.createReturn(
                        vendorId:
                            vendorName, // use name as id when no separate id
                        vendorName: vendorName,
                        items: items,
                        notes: notesCtrl.text.trim().isNotEmpty
                            ? notesCtrl.text.trim()
                            : null,
                      );

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (!mounted) return;

                      result.fold(
                        (failure) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed: ${failure.message}'),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                        },
                        (_) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Return to $vendorName created successfully',
                              ),
                              backgroundColor: Colors.green.shade700,
                            ),
                          );
                          _loadReturns(); // refresh list
                        },
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
              ),
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit Return'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _poField(
    TextEditingController controller,
    String label,
    bool isDark, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber
          ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
          : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? Colors.white54 : Colors.grey.shade600,
          fontSize: 13,
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF8F6FF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 14,
      ),
    );
  }
}

/// Helper class to hold controllers for a single return item row in the dialog.
class _ReturnItemControllers {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController qtyCtrl = TextEditingController();
  final TextEditingController priceCtrl = TextEditingController();
}
