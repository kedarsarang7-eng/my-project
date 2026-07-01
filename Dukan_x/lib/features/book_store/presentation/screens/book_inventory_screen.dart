import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../barcode/widgets/desktop_usb_scanner.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Book Inventory Screen
///
/// DataTable-based book catalogue with:
/// - Columns: ISBN, Title, Author, Publisher, Category, MRP, Stock
/// - Low-stock rows highlighted in amber
/// - Search/filter by all fields
/// - Add/Edit book dialog
///
/// Data flow: Products table (isbn, author, publisher columns) → UI
///            UI Add/Edit → Products table → SyncQueue → Server inventory table
class BookInventoryScreen extends ConsumerStatefulWidget {
  const BookInventoryScreen({super.key});

  @override
  ConsumerState<BookInventoryScreen> createState() =>
      _BookInventoryScreenState();
}

class _BookInventoryScreenState extends ConsumerState<BookInventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filterCategory = 'All';

  // Sample data - will be replaced with DB query
  final List<_BookRow> _books = [
    _BookRow(
      '978-0-06-112008-4',
      'To Kill a Mockingbird',
      'Harper Lee',
      'HarperCollins',
      'Fiction',
      350,
      12,
      5,
    ),
    _BookRow(
      '978-0-14-028329-7',
      '1984',
      'George Orwell',
      'Penguin',
      'Fiction',
      299,
      3,
      5,
    ),
    _BookRow(
      '978-0-7432-7356-5',
      'The Great Gatsby',
      'F. Scott Fitzgerald',
      'Scribner',
      'Classic',
      250,
      8,
      5,
    ),
    _BookRow(
      '978-0-06-093546-7',
      'To Kill a Mockingbird',
      'Harper Lee',
      'HarperCollins',
      'Textbook',
      450,
      2,
      5,
    ),
    _BookRow(
      '978-0-7352-1129-2',
      'Atomic Habits',
      'James Clear',
      'Avery',
      'Self-Help',
      499,
      25,
      5,
    ),
  ];

  List<_BookRow> get _filteredBooks {
    final query = _searchController.text.toLowerCase();
    return _books.where((b) {
      final matchesSearch =
          query.isEmpty ||
          b.isbn.toLowerCase().contains(query) ||
          b.title.toLowerCase().contains(query) ||
          b.author.toLowerCase().contains(query) ||
          b.publisher.toLowerCase().contains(query);
      final matchesCategory =
          _filterCategory == 'All' || b.category == _filterCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _scanIsbnToSearch(bool isDark, Color accent) async {
    final isbn = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.qr_code_scanner, size: 24, color: accent),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Scan ISBN Barcode',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Scan book ISBN barcode to filter catalogue.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              DesktopUsbScanner(
                onProductScanned: (p) => Navigator.pop(ctx, p.barcode),
                onProductNotFound: (code) => Navigator.pop(ctx, code),
              ),
            ],
          ),
        ),
      ),
    );

    if (isbn == null || isbn.isEmpty) return;

    // Validate ISBN format (10 or 13 digits)
    final digits = isbn.replaceAll(RegExp(r'[^0-9Xx]'), '');
    if (digits.length != 10 && digits.length != 13) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid ISBN format: $isbn'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Check local DB first
    try {
      final userId = sl<SessionManager>().ownerId ?? '';
      final result = await sl<ProductsRepository>().search(isbn, userId: userId);
      final products = result.data ?? [];
      if (products.isNotEmpty) {
        final match = products.firstWhere(
          (p) => p.barcode == isbn || (p.sku ?? '') == isbn,
          orElse: () => products.first,
        );
        setState(() => _searchController.text = match.name);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Showing: ${match.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Not in local DB — use ISBN as search term directly
        setState(() => _searchController.text = isbn);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No book found for ISBN: $isbn'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan error: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
          _buildHeader(isDark, accent),

          // Stats Row
          _buildStatsRow(isDark, accent),

          // Data Table
          Expanded(child: _buildDataTable(isDark, accent)),
        ],
      ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddBookDialog(isDark, accent),
        backgroundColor: accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Book',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, Color accent) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Row(
        children: [
          Icon(Icons.library_books_rounded, color: accent, size: 28),
          const SizedBox(width: 12),
          Text(
            'Book Catalogue',
            style: TextStyle(
              fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 22),
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E1B4B),
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),

          // Search
          SizedBox(
            width: 300,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search ISBN, title, author...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white30 : Colors.grey.shade400,
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: accent.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 13,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),

          // ISBN Scan button
          IconButton.filled(
            onPressed: () => _scanIsbnToSearch(isDark, accent),
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan ISBN barcode to search',
            style: IconButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),

          // Category Filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filterCategory,
                items: ['All', 'Fiction', 'Classic', 'Textbook', 'Self-Help']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _filterCategory = v!),
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 13,
                ),
                dropdownColor: isDark ? const Color(0xFF1A1128) : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(bool isDark, Color accent) {
    final totalBooks = _books.length;
    final totalStock = _books.fold<int>(0, (sum, b) => sum + b.stock);
    final lowStockCount = _books.where((b) => b.stock <= b.reorderLevel).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          _buildStatCard(
            isDark,
            accent,
            Icons.menu_book,
            'Total Titles',
            '$totalBooks',
            accent,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            isDark,
            accent,
            Icons.inventory_2_outlined,
            'Total Stock',
            '$totalStock',
            Colors.teal,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            isDark,
            accent,
            Icons.warning_amber_rounded,
            'Low Stock',
            '$lowStockCount',
            Colors.amber,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    bool isDark,
    Color accent,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(bool isDark, Color accent) {
    final books = _filteredBooks;

    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1128) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              isDark
                  ? accent.withValues(alpha: 0.08)
                  : accent.withValues(alpha: 0.04),
            ),
            dataRowColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) {
                return accent.withValues(alpha: 0.04);
              }
              return null;
            }),
            columns: [
              DataColumn(
                label: Text('ISBN', style: _headerStyle(isDark, accent)),
              ),
              DataColumn(
                label: Text('Title', style: _headerStyle(isDark, accent)),
              ),
              DataColumn(
                label: Text('Author', style: _headerStyle(isDark, accent)),
              ),
              DataColumn(
                label: Text('Publisher', style: _headerStyle(isDark, accent)),
              ),
              DataColumn(
                label: Text('Category', style: _headerStyle(isDark, accent)),
              ),
              DataColumn(
                label: Text('MRP', style: _headerStyle(isDark, accent)),
                numeric: true,
              ),
              DataColumn(
                label: Text('Stock', style: _headerStyle(isDark, accent)),
                numeric: true,
              ),
            ],
            rows: books.map((book) {
              final isLowStock = book.stock <= book.reorderLevel;
              return DataRow(
                color: isLowStock
                    ? WidgetStateProperty.all(
                        Colors.amber.withValues(alpha: isDark ? 0.08 : 0.06),
                      )
                    : null,
                cells: [
                  DataCell(
                    Text(book.isbn, style: _cellStyle(isDark, fontMono: true)),
                  ),
                  DataCell(
                    Text(book.title, style: _cellStyle(isDark, bold: true)),
                  ),
                  DataCell(Text(book.author, style: _cellStyle(isDark))),
                  DataCell(Text(book.publisher, style: _cellStyle(isDark))),
                  DataCell(_buildCategoryChip(book.category, isDark, accent)),
                  DataCell(Text('₹${book.mrp}', style: _cellStyle(isDark))),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${book.stock}', style: _cellStyle(isDark)),
                        if (isLowStock) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 14,
                            color: Colors.amber.shade700,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  TextStyle _headerStyle(bool isDark, Color accent) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: accent,
    letterSpacing: 0.3,
  );

  TextStyle _cellStyle(
    bool isDark, {
    bool bold = false,
    bool fontMono = false,
  }) => TextStyle(
    fontSize: 13,
    fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
    color: isDark ? Colors.white70 : Colors.black87,
    fontFamily: fontMono ? 'monospace' : null,
  );

  Widget _buildCategoryChip(String category, bool isDark, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        category,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: accent,
        ),
      ),
    );
  }

  void _showAddBookDialog(bool isDark, Color accent) {
    final isbnCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final authorCtrl = TextEditingController();
    final publisherCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: 'Fiction');
    final mrpCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1128) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.menu_book_rounded, color: accent),
            const SizedBox(width: 8),
            Text(
              'Add New Book',
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
                _dialogField(isbnCtrl, 'ISBN *', isDark),
                const SizedBox(height: 10),
                _dialogField(titleCtrl, 'Title *', isDark),
                const SizedBox(height: 10),
                _dialogField(authorCtrl, 'Author', isDark),
                const SizedBox(height: 10),
                _dialogField(publisherCtrl, 'Publisher', isDark),
                const SizedBox(height: 10),
                _dialogField(categoryCtrl, 'Category', isDark),
                const SizedBox(height: 10),
                _dialogField(mrpCtrl, 'MRP (₹) *', isDark, isNumber: true),
                const SizedBox(height: 10),
                _dialogField(
                  stockCtrl,
                  'Stock Quantity',
                  isDark,
                  isNumber: true,
                ),
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
              final isbn = isbnCtrl.text.trim();
              final title = titleCtrl.text.trim();
              final mrp = double.tryParse(mrpCtrl.text.trim()) ?? 0;
              if (isbn.isEmpty || title.isEmpty || mrp <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('ISBN, Title, and MRP are required'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final userId = sl<SessionManager>().ownerId;
              if (userId == null) return;

              final result = await productsRepository.createProduct(
                userId: userId,
                name: title,
                barcode: isbn,
                category: categoryCtrl.text.trim().isNotEmpty
                    ? categoryCtrl.text.trim()
                    : 'Fiction',
                sellingPrice: mrp,
                costPrice: mrp * 0.6,
                stockQuantity: double.tryParse(stockCtrl.text.trim()) ?? 1,
              );

              if (ctx.mounted) Navigator.pop(ctx);
              if (!mounted) return;

              if (result.isSuccess && result.data != null) {
                setState(() {
                  _books.add(
                    _BookRow(
                      isbn,
                      title,
                      authorCtrl.text.trim(),
                      publisherCtrl.text.trim(),
                      categoryCtrl.text.trim().isNotEmpty
                          ? categoryCtrl.text.trim()
                          : 'Fiction',
                      mrp.toInt(),
                      int.tryParse(stockCtrl.text.trim()) ?? 1,
                      5,
                    ),
                  );
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('"$title" added to catalogue'),
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
            child: const Text('Save Book'),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(
    TextEditingController controller,
    String label,
    bool isDark, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
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

class _BookRow {
  final String isbn;
  final String title;
  final String author;
  final String publisher;
  final String category;
  final int mrp;
  final int stock;
  final int reorderLevel;

  _BookRow(
    this.isbn,
    this.title,
    this.author,
    this.publisher,
    this.category,
    this.mrp,
    this.stock,
    this.reorderLevel,
  );
}
