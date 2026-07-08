// ============================================================================
// LOW STOCK CHECKER — Hardware indent creation stock check (bugfix.md 2.14)
// ============================================================================
// Before submitting an indent, checks each requested item's current local
// inventory stock level against its reorder point. Returns low-stock items
// so the UI can surface a warning and optionally suggest a purchase order.
//
// This is a non-blocking check — the indent still proceeds regardless.
// Sufficient-stock indents are unaffected (no warning, no extra step).
// ============================================================================

/// A single item that is below its reorder point at indent creation time.
class LowStockItem {
  /// The product ID as referenced in the indent items list.
  final String productId;

  /// Display name of the product (for UI messaging).
  final String productName;

  /// Current quantity on hand.
  final double currentStock;

  /// The reorder threshold configured for this product.
  final double reorderLevel;

  /// Quantity requested in the indent.
  final double requestedQuantity;

  const LowStockItem({
    required this.productId,
    required this.productName,
    required this.currentStock,
    required this.reorderLevel,
    required this.requestedQuantity,
  });

  /// How much below the reorder level the current stock is.
  double get deficit => reorderLevel - currentStock;

  /// Suggested purchase order quantity: enough to restore stock to reorder
  /// level plus the requested indent quantity.
  double get suggestedPurchaseQuantity =>
      (reorderLevel - currentStock + requestedQuantity).clamp(
        0,
        double.infinity,
      );
}

/// Result of a low-stock check for an indent.
class LowStockCheckResult {
  /// Whether any items in the indent are below their reorder point.
  final bool hasLowStockItems;

  /// List of items that are below their reorder point.
  final List<LowStockItem> lowStockItems;

  const LowStockCheckResult({
    required this.hasLowStockItems,
    required this.lowStockItems,
  });

  /// Convenience constructor for "no warnings" case.
  const LowStockCheckResult.clear()
    : hasLowStockItems = false,
      lowStockItems = const [];

  /// Human-readable warning message for UI display.
  String get warningMessage {
    if (!hasLowStockItems) return '';
    final itemNames = lowStockItems.map((i) => i.productName).join(', ');
    final count = lowStockItems.length;
    return '$count item${count > 1 ? 's' : ''} below reorder level: $itemNames. '
        'Consider creating a purchase order.';
  }

  /// Whether to suggest a purchase order (same as hasLowStockItems).
  bool get suggestPurchaseOrder => hasLowStockItems;
}

/// Represents a product's inventory state for the stock check.
class InventoryStockInfo {
  final String productId;
  final String productName;
  final double quantity;
  final double reorderLevel;

  const InventoryStockInfo({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.reorderLevel,
  });
}

/// Pure-logic low-stock checker for hardware indent creation.
///
/// Usage:
/// ```dart
/// final result = LowStockChecker.check(
///   indentItems: items,
///   inventoryLookup: (productId) => getInventoryStock(productId),
/// );
/// if (result.hasLowStockItems) { /* show warning dialog */ }
/// ```
class LowStockChecker {
  LowStockChecker._();

  /// Check whether any items in the indent are below their reorder point.
  ///
  /// [indentItems] — the list of items being requested in the indent.
  /// Each item map must have a `productId` (or `product_id`) key and a
  /// `quantity` (or `qty`) key.
  ///
  /// [inventoryData] — a map from productId to its inventory stock info.
  /// Products not found in inventory are assumed to have zero stock and
  /// zero reorder level (i.e., no warning for unknown products).
  ///
  /// Rules:
  /// - An item is "low stock" if `currentStock < reorderLevel`.
  /// - Items with `reorderLevel == 0` are never flagged (no threshold set).
  /// - Items not found in inventory are NOT flagged (unknown products skip).
  /// - This is a non-blocking warning — the indent proceeds regardless.
  static LowStockCheckResult check({
    required List<Map<String, dynamic>> indentItems,
    required Map<String, InventoryStockInfo> inventoryData,
  }) {
    final lowStockItems = <LowStockItem>[];

    for (final item in indentItems) {
      final productId = (item['productId'] ?? item['product_id'] ?? '')
          .toString()
          .trim();
      if (productId.isEmpty) continue;

      final stockInfo = inventoryData[productId];
      if (stockInfo == null) continue; // Unknown product — skip

      // No reorder level configured → never warn
      if (stockInfo.reorderLevel <= 0) continue;

      final requestedQty = (item['quantity'] ?? item['qty'] ?? 0).toDouble();

      // Check if current stock is below reorder level
      if (stockInfo.quantity < stockInfo.reorderLevel) {
        lowStockItems.add(
          LowStockItem(
            productId: productId,
            productName: stockInfo.productName,
            currentStock: stockInfo.quantity,
            reorderLevel: stockInfo.reorderLevel,
            requestedQuantity: requestedQty,
          ),
        );
      }
    }

    if (lowStockItems.isEmpty) {
      return const LowStockCheckResult.clear();
    }

    return LowStockCheckResult(
      hasLowStockItems: true,
      lowStockItems: lowStockItems,
    );
  }
}
