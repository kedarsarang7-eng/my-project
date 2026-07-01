import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../models/bill.dart';
import '../../../../providers/app_state_providers.dart';
import '../widgets/isbn_scanner_widget.dart';
import '../widgets/customer_loyalty_widget.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Book Store POS Screen
///
/// Premium desktop POS layout with:
/// - Left: Product search grid (ISBN/title/author)
/// - Center: Cart with dynamic discount per-item and bill-level
/// - Right: Customer lookup + loyalty + payment
/// - Top bar: ISBN barcode scanner input
///
/// Data flow:
///  ISBN Scan → Products table lookup → BillItems → Bills table → SyncQueue → Server
class BookPosScreen extends ConsumerStatefulWidget {
  const BookPosScreen({super.key});

  @override
  ConsumerState<BookPosScreen> createState() => _BookPosScreenState();
}

class _BookPosScreenState extends ConsumerState<BookPosScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _isbnController = TextEditingController();
  final FocusNode _isbnFocus = FocusNode();

  final List<_CartItem> _cartItems = [];
  double _billDiscount = 0;
  String?
  _selectedCustomerId; // ignore: unused_field — used in onCustomerSelected callback
  String? _selectedCustomerName;
  int _loyaltyPoints = 0;
  String _paymentMode = 'cash';

  @override
  void dispose() {
    _searchController.dispose();
    _isbnController.dispose();
    _isbnFocus.dispose();
    super.dispose();
  }

  double get _subtotal =>
      _cartItems.fold(0.0, (sum, item) => sum + item.lineTotal);

  double get _totalDiscount => _billDiscount;

  double get _grandTotal => _subtotal - _billDiscount;

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;
    final accent = const Color(0xFF8B5CF6);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F0B1A)
          : const Color(0xFFF8F6FF),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
        children: [
          // ── TOP BAR: ISBN Scanner ──
          _buildTopBar(isDark, accent),

          // ── MAIN CONTENT ──
          Expanded(
            child: Row(
              children: [
                // LEFT: Product Search & Grid
                Expanded(flex: 3, child: _buildProductPanel(isDark, accent)),

                // CENTER: Cart
                Expanded(flex: 4, child: _buildCartPanel(isDark, accent)),

                // RIGHT: Customer & Payment
                SizedBox(width: 320, child: _buildPaymentPanel(isDark, accent)),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TOP BAR
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTopBar(bool isDark, Color accent) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1128) : Colors.white,
        border: Border(
          bottom: BorderSide(color: accent.withValues(alpha: 0.15)),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo / Title
          Icon(Icons.menu_book_rounded, color: accent, size: 28),
          const SizedBox(width: 12),
          Text(
            'Book Store POS',
            style: TextStyle(
              fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1E1B4B),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 32),

          // ISBN Scanner Input
          Expanded(
            child: IsbnScannerWidget(
              controller: _isbnController,
              focusNode: _isbnFocus,
              isDark: isDark,
              accent: accent,
              onIsbnScanned: _handleIsbnScan,
            ),
          ),

          const SizedBox(width: 16),

          // Quick Stats
          _buildStatChip(
            isDark,
            accent,
            Icons.shopping_cart_outlined,
            '${_cartItems.length} items',
          ),
          const SizedBox(width: 8),
          _buildStatChip(
            isDark,
            accent,
            Icons.currency_rupee_rounded,
            '₹${_grandTotal.toStringAsFixed(2)}',
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(bool isDark, Color accent, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // LEFT: PRODUCT PANEL
  // ═══════════════════════════════════════════════════════════════
  Widget _buildProductPanel(bool isDark, Color accent) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1128) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by title, author, or ISBN...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.grey.shade400,
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: accent.withValues(alpha: 0.6),
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF8F6FF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // Product Grid
          Expanded(
            child: _cartItems.isEmpty && _searchController.text.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 64,
                          color: accent.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Scan ISBN or search books',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white38
                                : Colors.grey.shade400,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Press F2 or click the scanner',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white24
                                : Colors.grey.shade300,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: 0, // Will be populated from database
                    itemBuilder: (context, index) {
                      return const SizedBox.shrink();
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CENTER: CART PANEL
  // ═══════════════════════════════════════════════════════════════
  Widget _buildCartPanel(bool isDark, Color accent) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1128) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          // Cart Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.shopping_cart_rounded, color: accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Cart',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                  ),
                ),
                const Spacer(),
                if (_cartItems.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => setState(() => _cartItems.clear()),
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade400,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),

          // Cart Items
          Expanded(
            child: _cartItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_shopping_cart_rounded,
                          size: 48,
                          color: accent.withValues(alpha: 0.15),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Cart is empty',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white38
                                : Colors.grey.shade400,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _cartItems.length,
                    itemBuilder: (context, index) {
                      final item = _cartItems[index];
                      return _buildCartItemCard(item, index, isDark, accent);
                    },
                  ),
          ),

          // Cart Totals
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? accent.withValues(alpha: 0.08)
                  : accent.withValues(alpha: 0.04),
              border: Border(
                top: BorderSide(color: accent.withValues(alpha: 0.15)),
              ),
            ),
            child: Column(
              children: [
                _buildTotalRow('Subtotal', _subtotal, isDark),
                if (_totalDiscount > 0)
                  _buildTotalRow(
                    'Discount',
                    -_totalDiscount,
                    isDark,
                    color: Colors.green,
                  ),
                const SizedBox(height: 8),
                _buildTotalRow(
                  'Grand Total',
                  _grandTotal,
                  isDark,
                  isBold: true,
                  color: accent,
                  fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(
    _CartItem item,
    int index,
    bool isDark,
    Color accent,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : const Color(0xFFFAF8FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
        ),
      ),
      child: Row(
        children: [
          // Book Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.menu_book_rounded, color: accent, size: 20),
          ),
          const SizedBox(width: 12),

          // Book Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'ISBN: ${item.isbn}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),

          // Qty Controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    if (item.qty > 1) {
                      item.qty--;
                    } else {
                      _cartItems.removeAt(index);
                    }
                  });
                },
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                color: isDark ? Colors.white54 : Colors.grey,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              Text(
                '${item.qty}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              IconButton(
                onPressed: () => setState(() => item.qty++),
                icon: const Icon(Icons.add_circle_outline, size: 20),
                color: accent,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),

          // Price
          SizedBox(
            width: 80,
            child: Text(
              '₹${item.lineTotal.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    double amount,
    bool isDark, {
    bool isBold = false,
    Color? color,
    double fontSize = 14,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize - 1,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: color ?? (isDark ? Colors.white60 : Colors.grey.shade600),
            ),
          ),
          Text(
            '₹${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: color ?? (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // RIGHT: PAYMENT PANEL
  // ═══════════════════════════════════════════════════════════════
  Widget _buildPaymentPanel(bool isDark, Color accent) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1128) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          // Customer Lookup
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Section
                  CustomerLoyaltyWidget(
                    isDark: isDark,
                    accent: accent,
                    customerName: _selectedCustomerName,
                    loyaltyPoints: _loyaltyPoints,
                    onCustomerSelected: (id, name, points) {
                      setState(() {
                        _selectedCustomerId = id;
                        _selectedCustomerName = name;
                        _loyaltyPoints = points;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // Payment Mode
                  Text(
                    'Payment Mode',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildPaymentChip(
                        'cash',
                        'Cash',
                        Icons.money,
                        isDark,
                        accent,
                      ),
                      _buildPaymentChip(
                        'upi',
                        'UPI',
                        Icons.qr_code,
                        isDark,
                        accent,
                      ),
                      _buildPaymentChip(
                        'card',
                        'Card',
                        Icons.credit_card,
                        isDark,
                        accent,
                      ),
                      _buildPaymentChip(
                        'credit',
                        'Credit',
                        Icons.account_balance_wallet,
                        isDark,
                        accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Bill-Level Discount
                  Text(
                    'Bill Discount',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    decoration: InputDecoration(
                      hintText: '₹0.00',
                      prefixIcon: Icon(
                        Icons.discount_outlined,
                        color: accent,
                        size: 18,
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
                    onChanged: (val) {
                      setState(() {
                        _billDiscount = double.tryParse(val) ?? 0;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // Generate Invoice Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _cartItems.isEmpty ? null : _generateInvoice,
                icon: const Icon(Icons.receipt_long_rounded, size: 20),
                label: Text(
                  'Generate Invoice  ₹${_grandTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade200,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentChip(
    String value,
    String label,
    IconData icon,
    bool isDark,
    Color accent,
  ) {
    final isSelected = _paymentMode == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentMode = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.15)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? accent
                : (isDark ? Colors.white10 : Colors.grey.shade200),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? accent
                  : (isDark ? Colors.white38 : Colors.grey.shade500),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? accent
                    : (isDark ? Colors.white54 : Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════════

  void _handleIsbnScan(String isbn) async {
    final userId = sl<SessionManager>().ownerId;
    if (userId == null) return;

    // Check if already in cart
    final existing = _cartItems.where((i) => i.isbn == isbn).firstOrNull;
    if (existing != null) {
      setState(() => existing.qty++);
      _isbnController.clear();
      _isbnFocus.requestFocus();
      return;
    }

    // Look up book by ISBN/barcode in Products table
    final result = await productsRepository.search(isbn, userId: userId);
    if (!mounted) return;

    if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
      final product = result.data!.first;
      setState(() {
        _cartItems.add(
          _CartItem(
            productId: product.id,
            isbn: product.barcode ?? product.sku ?? isbn,
            title: product.name,
            mrp: product.sellingPrice,
            qty: 1,
          ),
        );
      });
    } else {
      // Product not found — add with ISBN as placeholder
      setState(() {
        _cartItems.add(
          _CartItem(
            productId: isbn,
            isbn: isbn,
            title: 'Book ($isbn)',
            mrp: 0.0,
            qty: 1,
          ),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No product found for ISBN $isbn — added with ₹0 price',
          ),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    }
    _isbnController.clear();
    _isbnFocus.requestFocus();
  }

  void _generateInvoice() async {
    final userId = sl<SessionManager>().ownerId;
    if (userId == null || _cartItems.isEmpty) return;

    // Build BillItems from cart
    final billItems = _cartItems
        .map(
          (item) => BillItem(
            productId: item.productId,
            productName: item.title,
            qty: item.qty.toDouble(),
            price: item.mrp,
          ),
        )
        .toList();

    final billId = const Uuid().v4();
    final now = DateTime.now();

    // Determine payment status based on payment mode
    final isPaid = _paymentMode != 'credit';
    final paidAmount = isPaid ? _grandTotal : 0.0;
    final cashPaid = (_paymentMode == 'cash') ? _grandTotal : 0.0;
    final onlinePaid = (_paymentMode == 'upi' || _paymentMode == 'card')
        ? _grandTotal
        : 0.0;

    final bill = Bill(
      id: billId,
      customerId: _selectedCustomerId ?? '',
      customerName: _selectedCustomerName ?? 'Walk-in Customer',
      date: now,
      items: billItems,
      subtotal: _subtotal,
      grandTotal: _grandTotal,
      discountApplied: _billDiscount,
      paidAmount: paidAmount,
      cashPaid: cashPaid,
      onlinePaid: onlinePaid,
      status: isPaid ? 'Paid' : 'Unpaid',
      paymentType: _paymentMode == 'upi' || _paymentMode == 'card'
          ? 'Online'
          : 'Cash',
      ownerId: userId,
      businessType: 'book_store',
      source: 'POS',
    );

    final result = await billsRepository.createBill(bill);
    if (!mounted) return;

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invoice generated: ₹${_grandTotal.toStringAsFixed(2)} (${_cartItems.length} books)',
          ),
          backgroundColor: const Color(0xFF8B5CF6),
        ),
      );
      setState(() {
        _cartItems.clear();
        _billDiscount = 0;
        _selectedCustomerId = null;
        _selectedCustomerName = null;
        _loyaltyPoints = 0;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create invoice: ${result.errorMessage}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }
}

/// Internal cart item model
class _CartItem {
  final String productId;
  final String isbn;
  final String title;
  final double mrp;
  int qty;

  _CartItem({
    required this.productId,
    required this.isbn,
    required this.title,
    required this.mrp,
    this.qty = 1,
  });

  double get lineTotal => mrp * qty;
}
