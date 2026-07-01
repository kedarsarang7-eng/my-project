class KotService {
  // In a real app, we inject a PrinterService here
  // final PrinterService _printerService;

  KotService();

  /// Generate KOT (Kitchen Order Ticket) and Route to Printers
  Future<void> generateAndPrintKot({
    required String orderId,
    required List<FoodOrderItemEntity>
    items, // Items to print (e.g. only new ones)
    required String tableNumber,
    required String waiterName,
  }) async {
    // 1. Group items by Category/Printer
    final kitchenItems = <FoodOrderItemEntity>[];
    final barItems = <FoodOrderItemEntity>[];

    for (final item in items) {
      // Logic to determine printer.
      // Ideally Product or Category has 'printerTag'.
      // For now, simple check:
      if (_isBarItem(item)) {
        barItems.add(item);
      } else {
        kitchenItems.add(item);
      }
    }

    // 2. Print to Kitchen
    if (kitchenItems.isNotEmpty) {
      await _printTicket(
        "KITCHEN PRINTER",
        tableNumber,
        waiterName,
        kitchenItems,
      );
    }

    // 3. Print to Bar
    if (barItems.isNotEmpty) {
      await _printTicket("BAR PRINTER", tableNumber, waiterName, barItems);
    }
  }

  bool _isBarItem(FoodOrderItemEntity item) {
    // This logic relies on product category naming convention
    // or we fetch Product details.
    // Assuming simple check for demo:
    final name = item.productName.toLowerCase();
    return name.contains('beer') ||
        name.contains('whisky') ||
        name.contains('cocktail');
  }

  Future<void> _printTicket(
    String printerName,
    String table,
    String waiter,
    List<FoodOrderItemEntity> items,
  ) async {
    // Log intent to print
    // print("PRINTING TO $printerName for Table $table");
    // Call actual printer service
  }
}

// Stub for Entity since we might not have it generated in this file context yet
class FoodOrderItemEntity {
  final String productName;
  final double quantity;
  final String? variant;

  FoodOrderItemEntity({
    required this.productName,
    required this.quantity,
    this.variant,
  });
}
