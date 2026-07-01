import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../models/bill.dart';
import '../../../../providers/app_state_providers.dart';
import '../widgets/isbn_scanner_widget.dart';
import '../widgets/customer_loyalty_widget.dart';
import 'package:dukanx/core/responsive/responsive.dart';
import '../../utils/book_gst_resolver.dart';
import '../../utils/book_store_business_rules.dart';
import '../../data/book_repository.dart';

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
///
/// Accessibility (F35, Requirement 12.6):
/// - Icon-only buttons carry tooltips and Semantics labels.
/// - Low-contrast hint/secondary text uses at least Colors.white60 (dark mode).
/// - Note: Full WCAG AA validation requires manual assistive-technology testing.
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
  int _billDiscountPaise = 0;
  String?
  _selectedCustomerId; // ignore: unused_field — used in onCustomerSelected callback
  String? _selectedCustomerName;
  int _loyaltyPoints = 0;
  int _loyaltyRedemptionPaise =
      0; // Loyalty discount in Paise (1 point = ₹1 = 100 Paise)
  String _paymentMode = 'cash';

  // ── Product grid state (tenant-scoped, loaded from Drift) ──
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoadingProducts = true;
  String? _productsError;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterProducts);
    _searchController.dispose();
    _isbnController.dispose();
    _isbnFocus.dispose();
    super.dispose();
  }

  /// Loads all products for the current tenant from the local Drift Products table.
  Future<void> _loadProducts() async {
    final userId = sl<SessionManager>().ownerId;
    if (userId == null || userId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
          _productsError = 'Unresolved tenant: unable to load products.';
        });
      }
      return;
    }

    setState(() {
      _isLoadingProducts = true;
      _productsError = null;
    });

    try {
      final result = await productsRepository.getAll(userId: userId);
      if (!mounted) return;

      if (result.isSuccess) {
        setState(() {
          _products = result.data ?? [];
          _isLoadingProducts = false;
          _filterProducts();
        });
      } else {
        setState(() {
          _isLoadingProducts = false;
          _productsError = result.errorMessage ?? 'Failed to load products.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingProducts = false;
        _productsError = 'Error loading products: $e';
      });
    }
  }

  /// Filters the loaded products by the current search term (title, author/brand, ISBN/barcode, category).
  void _filterProducts() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = List.of(_products);
      } else {
        _filteredProducts = _products.where((p) {
          return p.name.toLowerCase().contains(query) ||
              (p.brand?.toLowerCase().contains(query) ?? false) ||
              (p.barcode?.toLowerCase().contains(query) ?? false) ||
              (p.sku?.toLowerCase().contains(query) ?? false) ||
              (p.category?.toLowerCase().contains(query) ?? false);
        }).toList();
      }
    });
  }

  // ── All money computed in integer Paise ──
  int get _subtotalPaise =>
      _cartItems.fold(0, (sum, item) => sum + item.lineTotalPaise);

  int get _discountPaise => _billDiscountPaise;

  int get _taxPaise =>
      _cartItems.fold(0, (sum, item) => sum + item.lineTaxPaise);

  /// Grand total includes loyalty redemption discount (in Paise). (Req 9.6)
  /// Loyalty redemption is applied to the bill total in integer Paise.
  int get _grandTotalPaise {
    final total =
        _subtotalPaise - _discountPaise + _taxPaise - _loyaltyRedemptionPaise;
    return total < 0 ? 0 : total;
  }

  // ── Presentation helpers: Paise → ₹ display ──
  String _formatPaise(int paise) => '₹${(paise / 100).toStringAsFixed(2)}';

  String _formatPaiseAbs(int paise) =>
      '₹${(paise.abs() / 100).toStringAsFixed(2)}';

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

            // ── MAIN CONTENT (responsive: stacked on narrow, 3-pane on wide) ──
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Narrow window (< 700px): stack panels vertically in a
                  // scrollable column to prevent horizontal overflow (F30).
                  if (constraints.maxWidth < 700) {
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          // Product panel with fixed height
                          SizedBox(
                            height: 350,
                            child: _buildProductPanel(isDark, accent),
                          ),
                          // Cart panel with fixed height
                          SizedBox(
                            height: 400,
                            child: _buildCartPanel(isDark, accent),
                          ),
                          // Payment panel with intrinsic height
                          _buildPaymentPanel(isDark, accent),
                        ],
                      ),
                    );
                  }

                  // Wide window (>= 700px): original 3-pane horizontal Row.
                  return Row(
                    children: [
                      // LEFT: Product Search & Grid
                      Expanded(
                        flex: 3,
                        child: _buildProductPanel(isDark, accent),
                      ),

                      // CENTER: Cart
                      Expanded(flex: 4, child: _buildCartPanel(isDark, accent)),

                      // RIGHT: Customer & Payment (flexible, max 320)
                      Flexible(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 320,
                            minWidth: 200,
                          ),
                          child: _buildPaymentPanel(isDark, accent),
                        ),
                      ),
                    ],
                  );
                },
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
              fontSize: responsiveValue<double>(
                context,
                mobile: 14.0,
                tablet: 16.0,
                desktop: 18.0, // PRESERVED: Desktop uses exactly 18 as before
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
            _formatPaise(_grandTotalPaise),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(bool isDark, Color accent, IconData icon, String text) {
    return Semantics(
      label: text,
      child: Container(
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
                  color: isDark ? Colors.white60 : Colors.grey.shade400,
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
              onChanged: (_) {},
            ),
          ),

          // Product Grid
          Expanded(
            child: _isLoadingProducts
                ? Center(
                    child: CircularProgressIndicator(
                      color: accent,
                      strokeWidth: 2,
                    ),
                  )
                : _productsError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: Colors.red.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _productsError!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white54
                                  : Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: _loadProducts,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Retry'),
                            style: TextButton.styleFrom(
                              foregroundColor: accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _searchController.text.isNotEmpty
                              ? Icons.search_off_rounded
                              : Icons.qr_code_scanner_rounded,
                          size: 64,
                          color: accent.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isNotEmpty
                              ? 'No books match your search'
                              : 'No products in catalogue',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white60
                                : Colors.grey.shade400,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchController.text.isNotEmpty
                              ? 'Try a different search term'
                              : 'Add books via Inventory screen',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white54
                                : Colors.grey.shade300,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      return _buildProductGridItem(product, isDark, accent);
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
                                ? Colors.white60
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
                _buildTotalRowPaise('Subtotal', _subtotalPaise, isDark),
                if (_discountPaise > 0)
                  _buildTotalRowPaise(
                    'Discount',
                    -_discountPaise,
                    isDark,
                    color: Colors.green,
                  ),
                if (_taxPaise > 0)
                  _buildTotalRowPaise(
                    'Tax (GST)',
                    _taxPaise,
                    isDark,
                    color: Colors.orange.shade700,
                  ),
                if (_loyaltyRedemptionPaise > 0)
                  _buildTotalRowPaise(
                    'Loyalty Discount',
                    -_loyaltyRedemptionPaise,
                    isDark,
                    color: Colors.amber.shade700,
                  ),
                const SizedBox(height: 8),
                _buildTotalRowPaise(
                  'Grand Total',
                  _grandTotalPaise,
                  isDark,
                  isBold: true,
                  color: accent,
                  fontSize: responsiveValue<double>(
                    context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop:
                        18.0, // PRESERVED: Desktop uses exactly 18 as before
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
                    color: isDark ? Colors.white60 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),

          // Qty Controls (a11y: tooltips on icon-only buttons, F35)
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
                tooltip: 'Decrease quantity',
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
                tooltip: 'Increase quantity',
                color: accent,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),

          // Price
          SizedBox(
            width: 80,
            child: Text(
              _formatPaise(item.lineTotalPaise),
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

  Widget _buildTotalRowPaise(
    String label,
    int amountPaise,
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
            _formatPaiseAbs(amountPaise),
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
                        _loyaltyRedemptionPaise = 0; // Reset on customer change
                      });
                    },
                    onRedeemPoints:
                        _selectedCustomerId != null &&
                            _selectedCustomerId!.isNotEmpty
                        ? (pointsToRedeem) async {
                            // Validate: redemption cannot exceed available balance (Req 9.7)
                            if (pointsToRedeem > _loyaltyPoints) {
                              return false;
                            }
                            final bookRepo = ref.read(bookRepositoryProvider);
                            final result = await bookRepo.redeemPoints(
                              customerId: _selectedCustomerId!,
                              pointsToRedeem: pointsToRedeem,
                            );
                            return result.fold(
                              (_) => false, // Rejected — nothing applied
                              (newBalance) {
                                setState(() {
                                  // Apply redemption discount in integer Paise
                                  // 1 point = ₹1 = 100 Paise
                                  _loyaltyRedemptionPaise =
                                      pointsToRedeem * 100;
                                  _loyaltyPoints = newBalance;
                                });
                                return true;
                              },
                            );
                          }
                        : null,
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
                        // Convert rupee input to Paise (integer)
                        final rupees = double.tryParse(val) ?? 0;
                        _billDiscountPaise = (rupees * 100).round();
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
                  'Generate Invoice  ${_formatPaise(_grandTotalPaise)}',
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
                  : (isDark ? Colors.white60 : Colors.grey.shade500),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? accent
                    : (isDark ? Colors.white60 : Colors.grey.shade600),
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

  /// Builds a single product tile in the left product grid.
  Widget _buildProductGridItem(Product product, bool isDark, Color accent) {
    final pricePaise = (product.sellingPrice * 100).round();
    final isbn = product.barcode ?? product.sku ?? '';
    final author = product.brand ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
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
          // Book icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.menu_book_rounded, color: accent, size: 18),
          ),
          const SizedBox(width: 10),

          // Title + Author
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (author.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    author,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Price
          Text(
            _formatPaise(pricePaise),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(width: 8),

          // Add to Cart button
          SizedBox(
            height: 28,
            child: TextButton(
              onPressed: () => _addProductToCart(product),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                backgroundColor: accent.withValues(alpha: 0.1),
                foregroundColor: accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('+ Add'),
            ),
          ),
        ],
      ),
    );
  }

  /// Adds a product from the grid to the cart, incrementing qty if already present.
  void _addProductToCart(Product product) {
    final isbn = product.barcode ?? product.sku ?? product.id;

    // Check if already in cart
    final existing = _cartItems
        .where((i) => i.productId == product.id)
        .firstOrNull;
    if (existing != null) {
      setState(() => existing.qty++);
      return;
    }

    setState(() {
      _cartItems.add(
        _CartItem(
          productId: product.id,
          isbn: isbn,
          title: product.name,
          mrpPaise: (product.sellingPrice * 100).round(),
          hsnCode: product.hsnCode,
          storedTaxRate: product.taxRate,
          qty: 1,
        ),
      );
    });
  }

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

    // Validate ISBN checksum before proceeding (R8.5)
    if (!BookStoreBusinessRules.isValidIsbn(isbn)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid ISBN: $isbn failed checksum validation'),
          backgroundColor: Colors.red.shade700,
        ),
      );
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
            mrpPaise: (product.sellingPrice * 100).round(),
            hsnCode: product.hsnCode,
            storedTaxRate: product.taxRate,
            qty: 1,
          ),
        );
      });
    } else {
      // Valid ISBN but no product found — prompt operator to create it first (R8.6)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No book found for ISBN $isbn. Please add it via the Catalogue first.',
          ),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
      // Do NOT add a cart line
    }
    _isbnController.clear();
    _isbnFocus.requestFocus();
  }

  void _generateInvoice() async {
    final session = sl<SessionManager>();
    final userId = session.ownerId;
    if (userId == null || _cartItems.isEmpty) return;

    // In-widget RBAC: verify the acting user holds createBill permission
    // before persisting — enforced independent of the entry path (F27).
    final userRole = session.currentSession.effectiveRole;
    if (!RolePermissions.hasPermission(userRole, Permission.createBill)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Access denied: you don\'t have permission to perform this action',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Build BillItems from cart — convert Paise back to double for the
    // existing Bill model (Bill still uses double; this file's internal
    // computation is integer Paise per Requirement 1.1/1.2).
    final billItems = _cartItems.map((item) {
      final gstRate = BookGstResolver.resolveGstRate(
        hsnCode: item.hsnCode,
        storedTaxRate: item.storedTaxRate,
      );
      final lineTotalRupees = item.lineTotalPaise / 100.0;
      final lineTaxRupees = item.lineTaxPaise / 100.0;
      final halfTax = lineTaxRupees / 2.0;
      return BillItem(
        productId: item.productId,
        productName: item.title,
        qty: item.qty.toDouble(),
        price: item.mrpPaise / 100.0,
        hsn: item.hsnCode ?? '',
        gstRate: gstRate,
        cgst: halfTax,
        sgst: halfTax,
        totalOverride: lineTotalRupees + lineTaxRupees,
      );
    }).toList();

    final billId = const Uuid().v4();
    final now = DateTime.now();

    // Convert Paise totals to rupees for Bill model
    final subtotalRupees = _subtotalPaise / 100.0;
    final grandTotalRupees = _grandTotalPaise / 100.0;
    // Total discount includes manual discount + loyalty redemption (Paise → ₹)
    final discountRupees = (_discountPaise + _loyaltyRedemptionPaise) / 100.0;
    final taxRupees = _taxPaise / 100.0;

    // Determine payment status based on payment mode
    final isPaid = _paymentMode != 'credit';
    final paidAmount = isPaid ? grandTotalRupees : 0.0;
    final cashPaid = (_paymentMode == 'cash') ? grandTotalRupees : 0.0;
    final onlinePaid = (_paymentMode == 'upi' || _paymentMode == 'card')
        ? grandTotalRupees
        : 0.0;

    final bill = Bill(
      id: billId,
      customerId: _selectedCustomerId ?? '',
      customerName: _selectedCustomerName ?? 'Walk-in Customer',
      date: now,
      items: billItems,
      subtotal: subtotalRupees,
      totalTax: taxRupees,
      grandTotal: grandTotalRupees,
      discountApplied: discountRupees,
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
      // ── Loyalty accrual after successful sale (Req 9.5) ──
      // Accrual rule: 1 point per ₹100 spent (rounded down).
      // Only accrue if a customer is selected.
      if (_selectedCustomerId != null && _selectedCustomerId!.isNotEmpty) {
        final bookRepo = ref.read(bookRepositoryProvider);
        // Use the grand total (before loyalty discount was applied, since
        // the customer earns points on what they actually paid).
        await bookRepo.accruePoints(
          customerId: _selectedCustomerId!,
          saleAmountPaise: _grandTotalPaise,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invoice generated: ${_formatPaise(_grandTotalPaise)} (${_cartItems.length} books)',
          ),
          backgroundColor: const Color(0xFF8B5CF6),
        ),
      );
      setState(() {
        _cartItems.clear();
        _billDiscountPaise = 0;
        _selectedCustomerId = null;
        _selectedCustomerName = null;
        _loyaltyPoints = 0;
        _loyaltyRedemptionPaise = 0;
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

/// Internal cart item model — all money is integer Paise (Requirement 1.1/1.2).
class _CartItem {
  final String productId;
  final String isbn;
  final String title;

  /// Selling price in integer Paise (1 rupee = 100 Paise).
  final int mrpPaise;

  /// HSN code for GST resolution (nullable — fallback to storedTaxRate).
  final String? hsnCode;

  /// Product's persisted taxRate (percentage), used as fallback when HSN is
  /// absent or unrecognized.
  final double storedTaxRate;
  int qty;

  _CartItem({
    required this.productId,
    required this.isbn,
    required this.title,
    required this.mrpPaise,
    this.hsnCode,
    this.storedTaxRate = 0,
    this.qty = 1,
  });

  /// Line subtotal in Paise (before tax).
  int get lineTotalPaise => mrpPaise * qty;

  /// Resolved GST rate (percentage) for this item via BookGstResolver.
  double get _resolvedGstRate => BookGstResolver.resolveGstRate(
    hsnCode: hsnCode,
    storedTaxRate: storedTaxRate,
  );

  /// Per-line tax in Paise, computed from the resolved GST rate.
  int get lineTaxPaise => (lineTotalPaise * _resolvedGstRate / 100).round();
}
