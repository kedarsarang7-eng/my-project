import 'package:dukanx/models/bill.dart';

class TaxCalculator {
  /// Calculate GST components for a given price and rate.
  /// [price] is the unit price.
  /// [rate] is the GST percentage (e.g., 18.0 for 18%).
  /// [isInclusive] true if price includes tax.
  /// Returns a map with components.
  static Map<String, double> calculateTax({
    required double price,
    required double quantity,
    required double rate,
    required bool isInclusive,
  }) {
    double totalValue = price * quantity;
    double taxableValue;
    double taxAmount;

    if (isInclusive) {
      // Formula: Tax = (Total * Rate) / (100 + Rate)
      taxAmount = (totalValue * rate) / (100 + rate);
      taxableValue = totalValue - taxAmount;
    } else {
      // Formula: Tax = (Total * Rate) / 100
      taxableValue = totalValue;
      taxAmount = (totalValue * rate) / 100;
    }

    // Split into CGST/SGST or IGST based on supply type (local vs interstate)
    // For MVP, assuming INTRA-STATE (CGST + SGST) by default for now
    // logic can be extended.
    double cgst = taxAmount / 2;
    double sgst = taxAmount / 2;
    double igst = 0.0; // Set valid value if inter-state

    return {
      'taxableValue': taxableValue,
      'taxAmount': taxAmount,
      'cgst': cgst,
      'sgst': sgst,
      'igst': igst,
      'total': isInclusive ? totalValue : (taxableValue + taxAmount),
    };
  }

  /// Recalculate all totals for a Bill and return an updated Bill object
  static Bill recalculateBill(Bill bill, {bool isInterState = false}) {
    double subtotal = 0.0;
    double totalTax = 0.0;
    double grandTotal = 0.0;

    // Note: We need a way to know if items are tax inclusive/exclusive.
    // Assuming BillItem model doesn't track that per item yet, usually it's a global setting
    // or per product. For this utility, we assume EXCLUSIVE if not specified,
    // but typically user enters "Selling Price" which might be inclusive.
    // Let's assume the 'price' in BillItem is the "Unit Price" entered by user.
    // We'll treat it as Exclusive for calculation simplicity unless we add a flag.

    // Actually, looking at BillItem, it has cgst, sgst fields.
    // If they are 0, we should calculate them.

    List<BillItem> updatedItems = [];

    for (var item in bill.items) {
      // Recalc item tax
      final calc = calculateTax(
        price: item.price,
        quantity: item.qty,
        rate: item.gstRate,
        isInclusive: false, // Default to exclusive for B2B; B2C might differ
      );

      double tax = calc['taxAmount']!;
      double itemTotal = calc['total']!;

      // Update item fields
      BillItem updatedItem = item.copyWith(
        cgst: isInterState ? 0 : calc['cgst'],
        sgst: isInterState ? 0 : calc['sgst'],
        igst: isInterState ? tax : 0,
      );

      // Manually set total on item to match calculation
      updatedItem.total =
          itemTotal - updatedItem.discount; // Apply discount if any

      updatedItems.add(updatedItem);

      subtotal += calc['taxableValue']!;
      totalTax += tax;
      grandTotal += updatedItem.total;
    }

    return bill.copyWith(
      items: updatedItems,
      subtotal: subtotal,
      totalTax: totalTax,
      grandTotal: grandTotal - bill.discountApplied,
    );
  }
}
