/// Jewellery line item.
///
/// Price is computed from weight x metal-rate + wastage + making charges +
/// stone value - old-gold exchange. This REPLACES the universal
/// qty x unitPrice formula entirely, which is why jewellery is a dedicated
/// template. Purity/Hallmark (BIS/HUID) are first-class regulatory fields.
class JewelleryInvoiceItem {
  final String name;
  final String purity; // e.g. '22K', '916'
  final String? hallmarkHuid; // BIS HUID
  final double grossWeight; // grams
  final double netWeight; // grams (excludes stones)
  final double stoneWeight; // grams
  final double ratePerGram; // metal rate of the day
  final double makingChargePerGram;
  final double wastagePercent;
  final double stoneValue; // flat value of stones/diamonds
  final double oldGoldExchange; // deduction for exchanged old gold
  final double gstPercent;

  const JewelleryInvoiceItem({
    required this.name,
    required this.purity,
    this.hallmarkHuid,
    required this.grossWeight,
    required this.netWeight,
    this.stoneWeight = 0,
    required this.ratePerGram,
    this.makingChargePerGram = 0,
    this.wastagePercent = 0,
    this.stoneValue = 0,
    this.oldGoldExchange = 0,
    this.gstPercent = 3, // gold is typically 3% GST
  });

  double get metalValue => netWeight * ratePerGram;
  double get wastageValue => metalValue * (wastagePercent / 100);
  double get makingCharges => netWeight * makingChargePerGram;

  /// Pre-tax value after adding making/wastage/stones and deducting old gold.
  double get preTax =>
      metalValue + wastageValue + makingCharges + stoneValue - oldGoldExchange;

  double get gstAmount => preTax * (gstPercent / 100);

  double get amount => preTax + gstAmount;
}
