/// Godown / Multi-location logic
/// Handles warehouse/branch based inventory isolation.
class GodownService {
  
  /// Transfers stock from one godown to another
  Future<void> transferStock({
    required String userId,
    required String productId,
    required String fromWarehouseId,
    required String toWarehouseId,
    required double quantity,
  }) async {
    if (quantity <= 0) throw Exception("Quantity must be positive");
    
    // Logic: 
    // 1. Check stock in fromWarehouseId
    // 2. Add 'OUT' transaction to fromWarehouseId
    // 3. Add 'IN' transaction to toWarehouseId
    
    // StockMovements table in Drift supports warehouseId (which was added via PH2)
    // This allows exact reporting per branch.
  }

  Future<double> getStockAtLocation(String productId, String warehouseId) async {
    // Return aggregated sum from StockMovements for given warehouseId
    return 0.0;
  }
}
