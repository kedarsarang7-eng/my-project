/// Restaurant portion type. The universal line model has no concept of a
/// portion; here it changes both the row schema and the effective price.
enum FoodPortion { full, half }

/// Restaurant line item. The row schema (portion + optional table binding) and
/// the service-charge math differ from the universal qty x unitPrice model,
/// which is why restaurant is a dedicated template.
class RestaurantInvoiceItem {
  final String name;
  final int quantity;
  final FoodPortion portion;
  final double price; // price for the selected portion
  final double gstPercent;
  final double cgst;
  final double sgst;
  final double igst;

  const RestaurantInvoiceItem({
    required this.name,
    required this.quantity,
    this.portion = FoodPortion.full,
    required this.price,
    this.gstPercent = 0,
    this.cgst = 0,
    this.sgst = 0,
    this.igst = 0,
  });

  String get portionLabel => portion == FoodPortion.half ? 'Half' : 'Full';

  double get taxable => quantity * price;
  double get totalTax => cgst + sgst + igst;
  double get amount => taxable + totalTax;
}
