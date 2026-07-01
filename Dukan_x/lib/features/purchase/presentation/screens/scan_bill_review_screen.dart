// ============================================================================
// Scan Bill Review Screen
// ============================================================================
// Third screen in the scan bill flow - Core screen:
// - Shows thumbnail of original bill (tappable for full view)
// - List of extracted line items with match confidence indicators
// - Inline editing of product name, quantity, unit price
// - Product search/select for unmatched items
// - Add new items manually
// - Delete items (swipe or button)
// - Validation before proceeding
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../core/session/session_manager.dart';
import '../../services/scan_bill_api_client.dart';
import '../../../../core/services/logger_service.dart';
import '../../models/scan_bill_models.dart';
import '../../providers/scan_bill_session_provider.dart';
import 'scan_bill_supplier_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class ScanBillReviewScreen extends ConsumerStatefulWidget {
  final String verticalType;

  const ScanBillReviewScreen({
    super.key,
    required this.verticalType,
  });

  @override
  ConsumerState<ScanBillReviewScreen> createState() => 
      _ScanBillReviewScreenState();
}

class _ScanBillReviewScreenState extends ConsumerState<ScanBillReviewScreen> {
  final LoggerService _logger = sl<LoggerService>();
  
  bool _isLoading = false;
  bool _isSelectionMode = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final sessionState = ref.watch(scanBillSessionProvider(widget.verticalType));
    final validCount = sessionState.validItemCount;
    final unresolvedCount = sessionState.unresolvedItemCount;
    final totalAmount = sessionState.totalAmount;

    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode 
            ? Text('${ref.watch(selectedItemCountProvider(widget.verticalType))} selected')
            : const Text('Review Items'),
        actions: [
          // Selection mode toggle
          if (!_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.checklist),
              onPressed: () => setState(() => _isSelectionMode = true),
              tooltip: 'Select Items',
            ),
            // Add item button
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _showAddItemDialog,
              tooltip: 'Add Item',
            ),
            // Reset button
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _confirmReset,
              tooltip: 'Start Over',
            ),
          ] else ...[
            // Select All
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: _selectAll,
              tooltip: 'Select All',
            ),
            // Clear selection
            IconButton(
              icon: const Icon(Icons.deselect),
              onPressed: _clearSelection,
              tooltip: 'Clear Selection',
            ),
            // Close selection mode
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _isSelectionMode = false),
              tooltip: 'Done',
            ),
          ],
        ],
      ),
      body: Center(
        child: BoundedBox(
          maxWidth: 800,
          child: Column(
            children: [
              // Bill thumbnail and summary
              _buildHeader(sessionState, colorScheme),
              
              // Unresolved warning
              if (unresolvedCount > 0)
                _buildUnresolvedWarning(unresolvedCount, colorScheme),
              
              // Line items list
              Expanded(
                child: _buildItemsList(sessionState),
              ),
              
              // Bulk actions bar (when in selection mode)
              if (_isSelectionMode)
                _buildBulkActionsBar(colorScheme)
              else
                // Bottom action bar
                _buildBottomBar(validCount, unresolvedCount, totalAmount, colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ScanBillSessionState state, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Thumbnail of bill
          if (state.presignedUrl != null)
            GestureDetector(
              onTap: () => _showFullImage(state.presignedUrl!),
              child: Hero(
                tag: 'bill_image',
                child: Container(
                  width: 80,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                    image: DecorationImage(
                      image: NetworkImage(state.presignedUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: const Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.zoom_in, size: 16, color: Colors.white70),
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              width: 80,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[200],
              ),
              child: Icon(Icons.receipt_long, color: Colors.grey[400]),
            ),
          const SizedBox(width: 16),
          
          // Summary stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Extracted Items',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${state.reviewLineItems?.where((i) => !i.isDeleted).length ?? 0} items',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildStatChip(
                      label: 'Total',
                      count: state.reviewLineItems
                          ?.where((i) => !i.isDeleted)
                          .length ?? 0,
                      color: Colors.blue,
                    ),
                    _buildStatChip(
                      label: 'Matched',
                      count: state.reviewLineItems
                          ?.where((i) => !i.isDeleted && !i.isNewProduct)
                          .length ?? 0,
                      color: Colors.green,
                    ),
                    _buildStatChip(
                      label: 'New',
                      count: state.reviewLineItems
                          ?.where((i) => !i.isDeleted && i.isNewProduct)
                          .length ?? 0,
                      color: Colors.orange,
                    ),
                    if (state.unresolvedItemCount > 0)
                      _buildStatChip(
                        label: 'Need Review',
                        count: state.unresolvedItemCount,
                        color: Colors.red,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
          fontSize: 12,
          color: color.withOpacity(0.8),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildUnresolvedWarning(int count, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count item${count > 1 ? 's' : ''} need${count == 1 ? 's' : ''} review. '
              'Please resolve before confirming.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.orange[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(ScanBillSessionState state) {
    final items = state.reviewLineItems;
    
    if (items == null || items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No items extracted',
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _showAddItemDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Item Manually'),
            ),
          ],
        ),
      );
    }

    // Filter out deleted items for display
    final visibleItems = items.where((i) => !i.isDeleted).toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: visibleItems.length,
      itemBuilder: (context, index) {
        final item = visibleItems[index];
        return _LineItemCard(
          item: item,
          onEdit: () => _showEditItemDialog(item),
          onDelete: () => _confirmDeleteItem(item),
          showCheckbox: _isSelectionMode,
          onSelect: () => _toggleItemSelection(item.id),
        );
      },
    );
  }

  void _toggleItemSelection(String itemId) {
    ref.read(scanBillSessionProvider(widget.verticalType).notifier)
        .toggleItemSelection(itemId);
  }

  void _selectAll() {
    ref.read(scanBillSessionProvider(widget.verticalType).notifier)
        .selectAllItems();
  }

  void _clearSelection() {
    ref.read(scanBillSessionProvider(widget.verticalType).notifier)
        .deselectAllItems();
  }

  Widget _buildBottomBar(
    int validCount,
    int unresolvedCount,
    double totalAmount,
    ColorScheme colorScheme,
  ) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Total row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Amount',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '₹${totalAmount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Confirm button
            FilledButton.icon(
              onPressed: (validCount > 0 && unresolvedCount == 0 && !_isLoading)
                  ? _proceedToSupplier
                  : null,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.arrow_forward),
              label: Text(
                unresolvedCount > 0
                    ? 'Review $unresolvedCount item${unresolvedCount > 1 ? 's' : ''}'
                    : validCount == 0
                        ? 'Add at least 1 item'
                        : 'Confirm ($validCount items)',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkActionsBar(ColorScheme colorScheme) {
    final selectedCount = ref.watch(selectedItemCountProvider(widget.verticalType));
    
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Selected count
            Text(
              '$selectedCount item${selectedCount != 1 ? 's' : ''} selected',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            
            // Bulk action buttons
            Row(
              children: [
                // Delete selected
                Expanded(
                  child: FilledButton.icon(
                    onPressed: selectedCount > 0 
                        ? () {
                            _showDeleteConfirmation(selectedCount);
                          }
                        : null,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Mark as verified
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: selectedCount > 0
                        ? () {
                            ref.read(scanBillSessionProvider(widget.verticalType).notifier)
                                .markSelectedAsVerified();
                            setState(() => _isSelectionMode = false);
                          }
                        : null,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Verify'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(int count) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Selected?'),
        content: Text('Delete $count selected item${count != 1 ? 's' : ''}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(scanBillSessionProvider(widget.verticalType).notifier)
                  .deleteSelectedItems();
              if (ref.read(selectedItemCountProvider(widget.verticalType)) == 0) {
                setState(() => _isSelectionMode = false);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showFullImage(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Image.network(url),
        ),
      ),
    );
  }

  Future<void> _showEditItemDialog(ReviewLineItem item) async {
    final ReviewLineItem? result;
    if (context.isDesktop || context.isTablet) {
      result = await showDialog<ReviewLineItem>(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: BoundedBox(
            maxWidth: 600,
            child: _EditItemBottomSheet(
              item: item,
              verticalType: widget.verticalType,
              isDialog: true,
            ),
          ),
        ),
      );
    } else {
      result = await showModalBottomSheet<ReviewLineItem>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _EditItemBottomSheet(
          item: item,
          verticalType: widget.verticalType,
          isDialog: false,
        ),
      );
    }

    if (result != null && mounted) {
      ref.read(scanBillSessionProvider(widget.verticalType).notifier)
          .updateLineItem(item.id, result);
    }
  }

  Future<void> _showAddItemDialog() async {
    final newItem = ReviewLineItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      productName: '',
      quantity: 1,
      unit: 'pcs',
      unitPrice: 0,
      totalPrice: 0,
      isNewProduct: true,
      matchConfidence: 'none',
    );

    final ReviewLineItem? result;
    if (context.isDesktop || context.isTablet) {
      result = await showDialog<ReviewLineItem>(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: BoundedBox(
            maxWidth: 600,
            child: _EditItemBottomSheet(
              item: newItem,
              verticalType: widget.verticalType,
              isNewItem: true,
              isDialog: true,
            ),
          ),
        ),
      );
    } else {
      result = await showModalBottomSheet<ReviewLineItem>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _EditItemBottomSheet(
          item: newItem,
          verticalType: widget.verticalType,
          isNewItem: true,
          isDialog: false,
        ),
      );
    }

    if (result != null && mounted) {
      ref.read(scanBillSessionProvider(widget.verticalType).notifier)
          .addLineItem(result);
    }
  }

  Future<void> _confirmDeleteItem(ReviewLineItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Text('Remove "${item.productName}" from the list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      ref.read(scanBillSessionProvider(widget.verticalType).notifier)
          .deleteLineItem(item.id);
    }
  }

  Future<void> _confirmReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start Over?'),
        content: const Text(
          'All current progress will be lost. Are you sure?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(scanBillSessionProvider(widget.verticalType).notifier).reset();
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _proceedToSupplier() async {
    setState(() => _isLoading = true);
    
    // Navigate to supplier details screen
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScanBillSupplierScreen(
            verticalType: widget.verticalType,
          ),
        ),
      );
    }
    
    setState(() => _isLoading = false);
  }
}

// ============================================================================
// Line Item Card Widget
// ============================================================================

class _LineItemCard extends StatelessWidget {
  final ReviewLineItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onSelect;
  final bool showCheckbox;

  const _LineItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    this.onSelect,
    this.showCheckbox = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Determine status color
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    if (item.isNewProduct || item.matchConfidence == 'none') {
      statusColor = Colors.red;
      statusIcon = Icons.help_outline;
      statusText = 'New Product';
    } else if (item.matchConfidence == 'low') {
      statusColor = Colors.orange;
      statusIcon = Icons.warning_amber;
      statusText = 'Low Match';
    } else if (item.matchConfidence == 'medium') {
      statusColor = Colors.amber;
      statusIcon = Icons.info_outline;
      statusText = 'Medium Match';
    } else {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_outline;
      statusText = 'Matched';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: item.isSelected ? Colors.blue.withOpacity(0.05) : null,
      child: InkWell(
        onTap: showCheckbox ? null : onEdit,
        onLongPress: showCheckbox ? onSelect : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Status, checkbox, and actions
              Row(
                children: [
                  // Checkbox for bulk selection
                  if (showCheckbox)
                    Checkbox(
                      value: item.isSelected,
                      onChanged: (_) => onSelect?.call(),
                    ),
                  // Status indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 11,
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Delete button
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Colors.red[400],
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Product name
              Text(
                item.productName.isEmpty ? 'Unknown Product' : item.productName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              // Details row
              Row(
                children: [
                  // Quantity
                  _buildDetailChip(
                    icon: Icons.format_list_numbered,
                    label: '${item.quantity} ${item.unit}',
                  ),
                  const SizedBox(width: 12),
                  
                  // Unit price
                  _buildDetailChip(
                    icon: Icons.currency_rupee,
                    label: '₹${item.unitPrice.toStringAsFixed(2)}',
                  ),
                  const SizedBox(width: 12),
                  
                  // Total
                  Text(
                    '= ₹${item.totalPrice.toStringAsFixed(2)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              
              // Pharmacy-specific: batch and expiry
              if (item.batchNo != null || item.expiryDate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (item.batchNo != null)
                      _buildDetailChip(
                        icon: Icons.label_outline,
                        label: 'Batch: ${item.batchNo}',
                        isSmall: true,
                      ),
                    if (item.expiryDate != null) ...[
                      const SizedBox(width: 8),
                      _buildDetailChip(
                        icon: Icons.event,
                        label: 'Exp: ${item.expiryDate}',
                        isSmall: true,
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailChip({
    required IconData icon,
    required String label,
    bool isSmall = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: isSmall ? 12 : 14,
          color: Colors.grey[500],
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: isSmall ? 11 : 13,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Edit Item Bottom Sheet / Dialog
// ============================================================================

class _EditItemBottomSheet extends StatefulWidget {
  final ReviewLineItem item;
  final String verticalType;
  final bool isNewItem;
  final bool isDialog;

  const _EditItemBottomSheet({
    required this.item,
    required this.verticalType,
    this.isNewItem = false,
    this.isDialog = false,
  });

  @override
  State<_EditItemBottomSheet> createState() => _EditItemBottomSheetState();
}

class _EditItemBottomSheetState extends State<_EditItemBottomSheet> {
  late TextEditingController _nameController;
  late TextEditingController _qtyController;
  late TextEditingController _priceController;
  late TextEditingController _batchController;
  late TextEditingController _expiryController;
  
  String _selectedUnit = 'pcs';
  bool _isNewProduct = false;
  Product? _selectedProduct;
  List<Product> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.productName);
    _qtyController = TextEditingController(
      text: widget.item.quantity > 0 ? widget.item.quantity.toString() : '1',
    );
    _priceController = TextEditingController(
      text: widget.item.unitPrice > 0 ? widget.item.unitPrice.toString() : '',
    );
    _batchController = TextEditingController(text: widget.item.batchNo ?? '');
    _expiryController = TextEditingController(text: widget.item.expiryDate ?? '');
    _selectedUnit = widget.item.unit;
    _isNewProduct = widget.item.isNewProduct;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _batchController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  Future<void> _searchProducts(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    
    setState(() => _isSearching = true);
    
    try {
      final sessionManager = sl<SessionManager>();
      final userId = sessionManager.ownerId;
      if (userId == null) {
        setState(() => _isSearching = false);
        return;
      }
      final productsRepository = sl<ProductsRepository>();
      final results = await productsRepository.search(query, userId: userId);
      
      setState(() {
        _searchResults = results.data ?? [];
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  void _selectProduct(Product product) {
    setState(() {
      _selectedProduct = product;
      _nameController.text = product.name;
      _selectedUnit = product.unit;
      _isNewProduct = false;
      _searchResults = [];
    });
  }

  void _save() {
    final qty = double.tryParse(_qtyController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0;
    
    final updatedItem = ReviewLineItem(
      id: widget.item.id,
      productId: _selectedProduct?.id ?? widget.item.productId,
      productName: _nameController.text.trim(),
      quantity: qty,
      unit: _selectedUnit,
      unitPrice: price,
      totalPrice: qty * price,
      hsnCode: widget.item.hsnCode,
      batchNo: _batchController.text.isEmpty ? null : _batchController.text,
      expiryDate: _expiryController.text.isEmpty ? null : _expiryController.text,
      isNewProduct: _isNewProduct,
      matchConfidence: _isNewProduct ? 'none' : widget.item.matchConfidence,
    );

    Navigator.pop(context, updatedItem);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding + 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.isDialog
            ? BorderRadius.circular(24)
            : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            if (!widget.isDialog) ...[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            // Title
            Text(
              widget.isNewItem ? 'Add New Item' : 'Edit Item',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            // Product name field with search
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Product Name',
                hintText: 'Enter product name',
                prefixIcon: const Icon(Icons.inventory_2_outlined),
                suffixIcon: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _searchProducts,
            ),
            
            // Search results
            if (_searchResults.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _searchResults.length,
                  itemBuilder: (ctx, index) {
                    final product = _searchResults[index];
                    return ListTile(
                      title: Text(product.name),
                      subtitle: Text(product.category ?? ''),
                      onTap: () => _selectProduct(product),
                    );
                  },
                ),
              ),
            
            // New product toggle
            if (!widget.isNewItem)
              CheckboxListTile(
                value: _isNewProduct,
                onChanged: (v) => setState(() => _isNewProduct = v ?? false),
                title: const Text('Mark as new product'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            
            const SizedBox(height: 16),
            
            // Quantity and Unit row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedUnit,
                    decoration: InputDecoration(
                      labelText: 'Unit',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: ['pcs', 'kg', 'g', 'L', 'ml', 'box', 'bag', 'dozen']
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedUnit = v ?? 'pcs'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Unit price
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Unit Price (₹)',
                prefixIcon: const Icon(Icons.currency_rupee),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Pharmacy fields
            if (widget.verticalType == 'pharmacy') ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _batchController,
                      decoration: InputDecoration(
                        labelText: 'Batch No',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _expiryController,
                      decoration: InputDecoration(
                        labelText: 'Expiry (MM/YY)',
                        hintText: '12/25',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
            
            // Save button
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Save Item'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
