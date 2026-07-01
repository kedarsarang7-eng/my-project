import '../../../core/di/service_locator.dart';
import '../../../core/repository/vendors_repository.dart';
import '../../../core/repository/purchase_repository.dart';
import '../../../core/repository/products_repository.dart';
import '../models/stock_entry_model.dart' as model;

class BuyFlowService {
  final VendorsRepository _vendorsRepository = sl<VendorsRepository>();
  final ProductsRepository _productsRepository = sl<ProductsRepository>();
  final PurchaseRepository _purchaseRepository = sl<PurchaseRepository>();

  // --- VENDORS ---

  // Get Vendor Stream
  Stream<List<Vendor>> streamVendors(String ownerId) {
    return _vendorsRepository.watchAll(ownerId);
  }

  // Create/Update Vendor
  Future<void> saveVendor(Map<String, dynamic> vendorData) async {
    final vendor = Vendor(
      id: vendorData['vendorId'],
      userId: vendorData['ownerId'],
      name: vendorData['name'],
      phone: vendorData['phone'],
      email: vendorData['email'],
      address: vendorData['address'],
      gstin: vendorData['gstin'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _vendorsRepository.createVendor(vendor);
  }

  // --- ITEMS ---
  // In our new architecture, 'stock items' are Products
  Stream<List<Product>> streamItems(String ownerId) {
    // Return domain objects via Repository
    return _productsRepository.watchAll(userId: ownerId);
  }

  // --- STOCK ENTRIES (Atomic) ---

  Future<void> createStockEntry(
    model.StockEntry entry,
    List<model.StockEntryItem> items,
  ) async {
    // 1. Create Purchase Order in Repository
    // This handles local DB insert, stock update, and sync queueing
    final purchaseItems = items
        .map(
          (i) => PurchaseItem(
            id: i.lineId,
            productId: i.itemId,
            productName: i.name,
            quantity: i.quantity,
            costPrice: i.rate,
            totalAmount: i.total,
          ),
        )
        .toList();

    await _purchaseRepository.createPurchaseOrder(
      userId: entry.ownerId,
      vendorId: entry.vendorId,
      vendorName:
          '', // Will be fetched by repository if needed or we can pass it
      invoiceNumber: entry.invoiceNumber,
      totalAmount: entry.totalAmount,
      paidAmount: entry.paidAmount,
      items: purchaseItems,
    );

    // 2. Update Vendor Balance
    await _vendorsRepository.updateVendorAfterPurchase(
      vendorId: entry.vendorId,
      billAmount: entry.totalAmount,
      paidAmount: entry.paidAmount,
    );

    // Ledger entry is handled by sync workers or can be added to repository later.
    // For "True Offline", we prioritize local data consistency.
  }

  // --- STOCK REVERSAL ---
  Future<void> createStockReversal(
    model.StockEntry entry,
    List<model.StockEntryItem> items,
  ) async {
    // Similar to createStockEntry but with negative quantities or a 'Return' status
    // For now, let's just use a similar pattern or implement deletePurchaseOrder
    // Actually, StockReversal should probably be a separate concept in PurchaseRepository if critical.
  }

  // --- VENDOR PAYMENTS ---
  Future<void> recordVendorPayment(
    String ownerId,
    String vendorId,
    double amount,
    String mode,
    List<String> linkedEntries,
  ) async {
    // 1. Update Vendor Balance
    await _vendorsRepository.updateVendorAfterPurchase(
      vendorId: vendorId,
      billAmount: 0,
      paidAmount: amount, // Only update paidAmount to reduce outstanding
    );

    // For now, updating the vendor balance is the priority for offline parity.
  }
}
