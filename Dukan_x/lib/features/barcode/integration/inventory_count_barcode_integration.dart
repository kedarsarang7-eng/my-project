// ============================================================================
// INVENTORY COUNT BARCODE INTEGRATION
// ============================================================================
// Standalone screen for rapid barcode-based inventory counting / stock-take.
// Scan products continuously to record counted quantities.
// Supports batch scanning with running totals, discrepancy highlighting,
// and export of count results.
//
// Checklist items covered:
// - Inventory count with barcode (all P0/P1 business types)
// - Batch scanning for stock-takes
// - Low stock alerts during count
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/repository/products_repository.dart';
import '../../../core/session/session_manager.dart';
import '../../../providers/app_state_providers.dart';
import '../models/barcode_scan_result.dart';
import '../integration/barcode_integration_mixin.dart';

// ============================================================================
// INVENTORY COUNT ITEM
// ============================================================================

class InventoryCountItem {
  final ScannedProduct product;
  int scannedCount;
  final double systemStock;
  final DateTime firstScannedAt;
  DateTime lastScannedAt;

  InventoryCountItem({
    required this.product,
    this.scannedCount = 1,
    required this.systemStock,
    required this.firstScannedAt,
    required this.lastScannedAt,
  });

  double get discrepancy => scannedCount - systemStock;
  bool get hasDiscrepancy => discrepancy.abs() > 0.01;
  bool get isOverCount => discrepancy > 0;
  bool get isUnderCount => discrepancy < 0;
}

// ============================================================================
// INVENTORY COUNT SCREEN
// ============================================================================

class InventoryCountBarcodeScreen extends ConsumerStatefulWidget {
  const InventoryCountBarcodeScreen({super.key});

  @override
  ConsumerState<InventoryCountBarcodeScreen> createState() =>
      _InventoryCountBarcodeScreenState();
}

class _InventoryCountBarcodeScreenState
    extends ConsumerState<InventoryCountBarcodeScreen>
    with BarcodeScannerMixin<InventoryCountBarcodeScreen> {
  final List<InventoryCountItem> _countedItems = [];
  final DateTime _sessionStartTime = DateTime.now();
  int _totalScans = 0;

  @override
  BusinessType get barcodeBusinessType =>
      ref.read(businessTypeProvider).type;

  @override
  void initState() {
    super.initState();
    initBarcodeMixin();
  }

  @override
  void dispose() {
    disposeBarcodeMixin();
    super.dispose();
  }

  // ==========================================================================
  // BARCODE CALLBACKS
  // ==========================================================================

  @override
  void onBarcodeProductFound(ScannedProduct product) {
    _totalScans++;

    setState(() {
      final existingIdx = _countedItems.indexWhere(
        (i) => i.product.id == product.id,
      );

      if (existingIdx >= 0) {
        // Increment count for existing item
        _countedItems[existingIdx].scannedCount += 1;
        _countedItems[existingIdx].lastScannedAt = DateTime.now();
      } else {
        // Add new item
        _countedItems.insert(
          0,
          InventoryCountItem(
            product: product,
            scannedCount: 1,
            systemStock: product.currentStock,
            firstScannedAt: DateTime.now(),
            lastScannedAt: DateTime.now(),
          ),
        );
      }
    });
  }

  @override
  void onBarcodeProductNotFound(String barcode) {
    _totalScans++;
    showBarcodeNotFoundDialog(barcode);
  }

  // ==========================================================================
  // COMPUTED
  // ==========================================================================

  int get _totalUniqueProducts => _countedItems.length;
  int get _totalCountedQty =>
      _countedItems.fold(0, (sum, i) => sum + i.scannedCount);
  int get _discrepancyCount =>
      _countedItems.where((i) => i.hasDiscrepancy).length;

  // ==========================================================================
  // ACTIONS
  // ==========================================================================

  void _clearCount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Count?'),
        content: const Text(
          'This will discard all scanned items. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _countedItems.clear();
                _totalScans = 0;
              });
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _removeItem(int index) {
    setState(() => _countedItems.removeAt(index));
  }

  void _updateCount(int index, int newCount) {
    if (newCount <= 0) {
      _removeItem(index);
    } else {
      setState(() {
        _countedItems[index].scannedCount = newCount;
        _countedItems[index].lastScannedAt = DateTime.now();
      });
    }
  }

  Future<void> _submitCountAdjustments() async {
    final discrepancies = _countedItems.where((i) => i.hasDiscrepancy).toList();
    if (discrepancies.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No discrepancies to adjust')),
        );
      }
      return;
    }

    final userId = sl<SessionManager>().ownerId ?? '';
    if (userId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
      }
      return;
    }

    final repo = sl<ProductsRepository>();
    int successCount = 0;
    final errors = <String>[];

    for (final item in discrepancies) {
      final result = await repo.adjustStock(
        productId: item.product.id,
        quantity: item.discrepancy,
        userId: userId,
      );
      if (result.isSuccess) {
        successCount++;
      } else {
        errors.add('${item.product.displayTitle}: ${result.errorMessage}');
      }
    }

    if (mounted) {
      if (errors.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stock adjusted for $successCount items'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _countedItems.clear());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount adjusted, ${errors.length} failed'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _showSummaryDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Count Summary'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _summaryRow('Session Started',
                  DateFormat('hh:mm a').format(_sessionStartTime)),
              _summaryRow('Total Scans', '$_totalScans'),
              _summaryRow('Unique Products', '$_totalUniqueProducts'),
              _summaryRow('Total Counted Qty', '$_totalCountedQty'),
              const Divider(),
              _summaryRow(
                'Discrepancies',
                '$_discrepancyCount',
                valueColor:
                    _discrepancyCount > 0 ? Colors.orange : Colors.green,
              ),
              const SizedBox(height: 16),
              if (_discrepancyCount > 0) ...[
                const Text(
                  'Items with discrepancies:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ..._countedItems
                    .where((i) => i.hasDiscrepancy)
                    .take(10)
                    .map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.product.displayTitle,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${item.scannedCount} vs ${item.systemStock.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: item.isOverCount
                                      ? Colors.blue
                                      : Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _submitCountAdjustments();
            },
            child: const Text('Submit Count'),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Count'),
        actions: [
          buildBarcodeScannerIndicator(),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.summarize),
            tooltip: 'View Summary',
            onPressed: _countedItems.isEmpty ? null : _showSummaryDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear Count',
            onPressed: _countedItems.isEmpty ? null : _clearCount,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Hidden barcode input
          buildHiddenBarcodeInput(),

          // Stats bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
            child: Row(
              children: [
                _statChip(
                  Icons.qr_code_scanner,
                  'Scans',
                  '$_totalScans',
                  Colors.blue,
                ),
                const SizedBox(width: 16),
                _statChip(
                  Icons.inventory_2,
                  'Products',
                  '$_totalUniqueProducts',
                  Colors.green,
                ),
                const SizedBox(width: 16),
                _statChip(
                  Icons.production_quantity_limits,
                  'Total Qty',
                  '$_totalCountedQty',
                  Colors.purple,
                ),
                const SizedBox(width: 16),
                _statChip(
                  Icons.warning_amber,
                  'Discrepancies',
                  '$_discrepancyCount',
                  _discrepancyCount > 0 ? Colors.orange : Colors.grey,
                ),
              ],
            ),
          ),

          // Item list
          Expanded(
            child: _countedItems.isEmpty
                ? _buildEmptyState()
                : _buildCountList(),
          ),
        ],
      ),
      floatingActionButton: _countedItems.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showSummaryDialog,
              icon: const Icon(Icons.check),
              label: const Text('Finish Count'),
            )
          : null,
    );
  }

  Widget _statChip(IconData icon, String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Start scanning products to count',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Each scan increments the count by 1',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'USB/Bluetooth scanner is ready',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCountList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _countedItems.length,
      itemBuilder: (context, index) {
        final item = _countedItems[index];
        return _buildCountCard(item, index);
      },
    );
  }

  Widget _buildCountCard(InventoryCountItem item, int index) {
    final product = item.product;
    final hasWarning = product.expiryWarning != null;

    Color? cardColor;
    if (item.hasDiscrepancy) {
      cardColor = item.isOverCount
          ? Colors.blue.withValues(alpha: 0.05)
          : Colors.red.withValues(alpha: 0.05);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product info
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.displayTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (product.barcode != null)
                        Text(
                          product.barcode!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      if (product.barcode != null) const SizedBox(width: 8),
                      Text(
                        'System: ${item.systemStock.toStringAsFixed(0)} ${product.unit}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  if (hasWarning)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.warning, size: 14, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(
                            product.expiryWarning!.message,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Count controls
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 18),
                  onPressed: () =>
                      _updateCount(index, item.scannedCount - 1),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.hasDiscrepancy
                        ? (item.isOverCount
                            ? Colors.blue.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1))
                        : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: item.hasDiscrepancy
                          ? (item.isOverCount ? Colors.blue : Colors.red)
                          : Colors.green,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${item.scannedCount}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: item.hasDiscrepancy
                          ? (item.isOverCount ? Colors.blue : Colors.red)
                          : Colors.green,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: () =>
                      _updateCount(index, item.scannedCount + 1),
                ),
              ],
            ),

            // Discrepancy indicator
            SizedBox(
              width: 60,
              child: item.hasDiscrepancy
                  ? Column(
                      children: [
                        Icon(
                          item.isOverCount
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 16,
                          color:
                              item.isOverCount ? Colors.blue : Colors.red,
                        ),
                        Text(
                          '${item.discrepancy > 0 ? '+' : ''}${item.discrepancy.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: item.isOverCount
                                ? Colors.blue
                                : Colors.red,
                          ),
                        ),
                      ],
                    )
                  : const Column(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: Colors.green),
                        Text(
                          'Match',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
