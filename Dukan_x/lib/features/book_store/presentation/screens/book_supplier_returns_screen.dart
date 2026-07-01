import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/repository/purchase_repository.dart';
import '../../../../providers/app_state_providers.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Book Supplier & Returns Management Screen
///
/// Two tabs:
/// 1. Purchase Orders — Restock from publishers
/// 2. Publisher Returns — Return unsold/dead stock
///
/// Data flow:
///   Purchase Orders → PurchaseOrders table → inventory stock update → SyncQueue
///   Publisher Returns → BookReturns table → vendor balance update → SyncQueue
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                    fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 22),
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
      padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
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
  // TAB 2: PUBLISHER RETURNS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildPublisherReturnsTab(bool isDark, Color accent) {
    return Padding(
      padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
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
              const Spacer(),
              _buildFilterChip('All', true, isDark, accent),
              const SizedBox(width: 6),
              _buildFilterChip('Draft', false, isDark, accent),
              const SizedBox(width: 6),
              _buildFilterChip('Sent', false, isDark, accent),
              const SizedBox(width: 6),
              _buildFilterChip('Accepted', false, isDark, accent),
            ],
          ),
          const SizedBox(height: 16),

          // Returns List
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
            ),
          ),
        ],
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1128) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.assignment_return_rounded,
              color: Colors.orange.shade700,
            ),
            const SizedBox(width: 8),
            Text(
              'Publisher Return',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.construction_rounded,
              size: 48,
              color: Colors.orange.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Publisher returns tracking will be available in a future update.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'For now, you can track returns by creating a negative purchase order.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
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
