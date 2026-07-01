// ============================================================================
// STOCK VALUATION STATEMENT SCREEN - Phase 1.2
// ============================================================================
// Generate comprehensive stock valuation with real inventory data
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/statements_service.dart';
import '../../../../services/pdf_service.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../core/theme/futuristic_colors.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class StockValuationStatementScreen extends ConsumerStatefulWidget {
  const StockValuationStatementScreen({super.key});

  @override
  ConsumerState<StockValuationStatementScreen> createState() =>
      _StockValuationStatementScreenState();
}

class _StockValuationStatementScreenState
    extends ConsumerState<StockValuationStatementScreen> {
  final StatementsService _statementsService = sl<StatementsService>();
  final PdfService _pdfService = sl<PdfService>();
  final ProductsRepository _productsRepository = sl<ProductsRepository>();

  bool _isLoading = true;
  StockValuationStatement? _statement;
  String? _error;
  
  String? _selectedCategory;
  bool _includeZeroStock = false;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadStatement();
  }

  Future<void> _loadCategories() async {
    try {
      final userId = sl<SessionManager>().ownerId;
      if (userId == null) return;
      
      final productsResult = await _productsRepository.getAll(userId: userId);
      final products = productsResult.data ?? [];
      final cats = products.map((p) => p.category ?? 'Uncategorized').toSet().toList();
      cats.sort();
      
      setState(() {
        _categories = cats;
      });
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Future<void> _loadStatement() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final statement = await _statementsService.generateStockValuationStatement(
        category: _selectedCategory,
        includeZeroStock: _includeZeroStock,
      );

      setState(() {
        _statement = statement;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _exportPdf() async {
    if (_statement == null) return;

    try {
      final pdfBytes = await _pdfService.generateStockValuationPdf(
        title: 'Stock Valuation Statement',
        businessName: sl<SessionManager>().currentSession.displayName ?? 'Business',
        generatedAt: _statement!.generatedAt,
        summary: {
          'Total Items': _statement!.totalItems.toString(),
          'Total Stock Qty': _statement!.totalStockQuantity.toString(),
          'Total Stock Value': _formatCurrency(_statement!.totalStockValue),
          'Total Cost Value': _formatCurrency(_statement!.totalCostValue),
          'Potential Profit': _formatCurrency(_statement!.potentialProfit),
          'Low Stock Items': _statement!.lowStockCount.toString(),
        },
        categorySummary: _statement!.categorySummary,
        items: _statement!.items.map((i) => {
          'name': i.name,
          'category': i.category,
          'sku': i.sku ?? '-',
          'barcode': i.barcode ?? '-',
          'quantity': '${i.stockQuantity.toStringAsFixed(2)} ${i.unit}',
          'purchase_price': _formatCurrency(i.purchasePrice),
          'selling_price': _formatCurrency(i.sellingPrice),
          'stock_value': _formatCurrency(i.stockValue),
          'cost_value': _formatCurrency(i.costValue),
          'is_low_stock': i.isLowStock,
        }).toList(),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'StockValuation_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stock Valuation',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Real-time inventory valuation',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _statement != null ? _exportPdf : null,
            tooltip: 'Export PDF',
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
        children: [
          // Filter Bar
          _buildFilterBar(isDark),
          
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : _statement == null || _statement!.items.isEmpty
                        ? _buildEmptyState()
                        : _buildStatementContent(isDark),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white24 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildCategoryDropdown(isDark),
              ),
              const SizedBox(width: 16),
              _buildZeroStockToggle(isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.grey.shade300,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: _selectedCategory,
          hint: Text(
            'All Categories',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
          ),
          onChanged: (value) {
            setState(() {
              _selectedCategory = value;
            });
            _loadStatement();
          },
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('All Categories'),
            ),
            ..._categories.map((cat) => DropdownMenuItem(
              value: cat,
              child: Text(cat),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildZeroStockToggle(bool isDark) {
    return GlassCard(
      borderRadius: 8,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Include Zero Stock',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: _includeZeroStock,
            onChanged: (value) {
              setState(() {
                _includeZeroStock = value;
              });
              _loadStatement();
            },
            activeColor: FuturisticColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error loading statement',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadStatement,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 16),
          Text(
            'No products found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _includeZeroStock 
                ? 'Add products to see valuation'
                : 'Try including zero stock items',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).disabledColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatementContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          _buildSummaryCards(isDark),
          
          const SizedBox(height: 24),
          
          // Category Summary
          if (_statement!.categorySummary.isNotEmpty) ...[
            _buildCategorySummary(isDark),
            const SizedBox(height: 24),
          ],
          
          // Low Stock Alert
          if (_statement!.lowStockCount > 0) ...[
            _buildLowStockAlert(isDark),
            const SizedBox(height: 24),
          ],
          
          // Stock List Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Stock Details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                '${_statement!.items.length} items',
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Stock Items
          ..._statement!.items.map((item) => _buildStockItem(item, isDark)),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(bool isDark) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: responsiveValue<int>(context,
        mobile: 1,
        tablet: 2,
        desktop: 2,  // PRESERVED: Desktop uses exactly 2 columns as before
      ),
      childAspectRatio: responsiveValue<double>(context,
        mobile: 2.0,
        tablet: 1.3,
        desktop: 1.3,  // PRESERVED: Desktop uses exactly 1.3 aspect ratio as before
      ),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildSummaryCard(
          'Total Items',
          '${_statement!.totalItems}',
          '${_statement!.totalStockQuantity} units',
          Colors.blue,
          isDark,
        ),
        _buildSummaryCard(
          'Stock Value',
          _formatCurrency(_statement!.totalStockValue),
          'At selling price',
          Colors.green,
          isDark,
        ),
        _buildSummaryCard(
          'Cost Value',
          _formatCurrency(_statement!.totalCostValue),
          'At purchase price',
          Colors.orange,
          isDark,
        ),
        _buildSummaryCard(
          'Potential Profit',
          _formatCurrency(_statement!.potentialProfit),
          '${((_statement!.potentialProfit / (_statement!.totalStockValue > 0 ? _statement!.totalStockValue : 1)) * 100).toStringAsFixed(1)}% margin',
          _statement!.potentialProfit >= 0 ? Colors.green : Colors.red,
          isDark,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    String subtitle,
    Color color,
    bool isDark,
  ) {
    return GlassCard(
      borderRadius: 12,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySummary(bool isDark) {
    final sortedCategories = _statement!.categorySummary.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return GlassCard(
      borderRadius: 12,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category-wise Valuation',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...sortedCategories.map((entry) => _buildCategoryRow(
            entry.key,
            entry.value,
            _statement!.totalStockValue,
            isDark,
          )),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(String category, double value, double total, bool isDark) {
    final percentage = total > 0 ? (value / total) * 100 : 0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              category,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  FuturisticColors.primary.withOpacity(0.7),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatCurrency(value),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockAlert(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.red),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Low Stock Alert',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  '${_statement!.lowStockCount} items below reorder level',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockItem(StockValuationItem item, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: item.isLowStock
              ? Colors.red.withOpacity(0.5)
              : (isDark ? Colors.white24 : Colors.grey.shade200),
        ),
      ),
      child: ExpansionTile(
        leading: item.isLowStock
            ? Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber, color: Colors.red, size: 16),
              )
            : null,
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${item.category} • ${item.stockQuantity.toStringAsFixed(0)} ${item.unit}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _formatCurrency(item.stockValue),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: item.isLowStock ? Colors.red : FuturisticColors.primary,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Text(
                'Cost: ${_formatCurrency(item.costValue)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.grey.shade500,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Profit: ${_formatCurrency(item.profitPotential)}',
                style: TextStyle(
                  fontSize: 12,
                  color: item.profitPotential >= 0 ? Colors.green.shade600 : Colors.red.shade600,
                ),
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                _buildDetailRow('SKU', item.sku ?? '-', isDark),
                _buildDetailRow('Barcode', item.barcode ?? '-', isDark),
                _buildDetailRow('Purchase Price', _formatCurrency(item.purchasePrice), isDark),
                _buildDetailRow('Selling Price', _formatCurrency(item.sellingPrice), isDark),
                _buildDetailRow('Reorder Level', '${item.lowStockThreshold.toStringAsFixed(0)} ${item.unit}', isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    return sl<CurrencyService>().format(amount);
  }
}
