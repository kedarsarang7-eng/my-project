import '../models/models.dart';
import '../repositories/gst_repository.dart';

/// GSTR-3B Summary Service - Generates summary for GSTR-3B filing
///
/// GSTR-3B is a monthly self-declaration for summarized sales, ITC, and tax liability
class Gstr3bSummaryService {
  final GstRepository _gstRepo;

  Gstr3bSummaryService({GstRepository? gstRepo})
    : _gstRepo = gstRepo ?? GstRepository();

  /// Generate GSTR-3B summary for a period
  Future<Gstr3bSummary> generateSummary({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final invoices = await _gstRepo.getGstInvoicesForPeriod(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
    );

    // Table 3.1: Outward taxable supplies
    final table3_1 = _calculateTable3_1(invoices);

    // Table 3.2: Interstate supplies (B2C)
    final table3_2 = _calculateTable3_2(invoices);

    // Table 5: Interest and late fee (placeholder - needs manual input)
    // Table 6: ITC (placeholder - needs purchase data)

    return Gstr3bSummary(
      period: '${_monthName(startDate.month)} ${startDate.year}',
      table3_1: table3_1,
      table3_2: table3_2,
      totalTaxLiability: TaxLiability(
        cgst: table3_1.totalCgst,
        sgst: table3_1.totalSgst,
        igst: table3_1.totalIgst,
        cess: table3_1.totalCess,
      ),
    );
  }

  /// Calculate Table 3.1 - Outward taxable supplies
  Table31Summary _calculateTable3_1(List<GstInvoiceDetailModel> invoices) {
    // Row (a): Outward taxable supplies (other than zero rated, nil rated and exempted)
    final taxableSupplies = invoices
        .where((i) => i.invoiceType != GstInvoiceType.nil)
        .toList();

    // Row (b): Outward taxable supplies (zero rated)
    final zeroRated = invoices
        .where(
          (i) =>
              i.invoiceType == GstInvoiceType.export ||
              (i.cgstRate == 0 && i.sgstRate == 0 && i.igstRate == 0),
        )
        .toList();

    // Row (c): Other outward supplies (nil rated, exempted)
    final nilExempt = invoices
        .where((i) => i.invoiceType == GstInvoiceType.nil)
        .toList();

    // Row (d): Inward supplies (liable to reverse charge) - placeholder
    // Row (e): Non-GST outward supplies - placeholder

    return Table31Summary(
      // Row (a)
      taxableSuppliesTaxableValue: taxableSupplies.fold(
        0.0,
        (sum, i) => sum + i.taxableValue,
      ),
      taxableSuppliesCgst: taxableSupplies.fold(
        0.0,
        (sum, i) => sum + i.cgstAmount,
      ),
      taxableSuppliesSgst: taxableSupplies.fold(
        0.0,
        (sum, i) => sum + i.sgstAmount,
      ),
      taxableSuppliesIgst: taxableSupplies.fold(
        0.0,
        (sum, i) => sum + i.igstAmount,
      ),
      taxableSuppliesCess: taxableSupplies.fold(
        0.0,
        (sum, i) => sum + i.cessAmount,
      ),

      // Row (b)
      zeroRatedTaxableValue: zeroRated.fold(
        0.0,
        (sum, i) => sum + i.taxableValue,
      ),
      zeroRatedIgst: zeroRated.fold(0.0, (sum, i) => sum + i.igstAmount),

      // Row (c)
      nilExemptTaxableValue: nilExempt.fold(
        0.0,
        (sum, i) => sum + i.taxableValue,
      ),

      // Row (d) - placeholder
      reverseChargeTaxableValue: 0,
      reverseChargeCgst: 0,
      reverseChargeSgst: 0,
      reverseChargeIgst: 0,

      // Row (e) - placeholder
      nonGstTaxableValue: 0,
    );
  }

  /// Calculate Table 3.2 - Interstate supplies to unregistered persons
  List<Table32Item> _calculateTable3_2(List<GstInvoiceDetailModel> invoices) {
    // Filter B2C interstate supplies
    final b2cInterstate = invoices
        .where(
          (i) =>
              i.invoiceType == GstInvoiceType.b2cl &&
              i.supplyType == SupplyType.inter,
        )
        .toList();

    // Group by place of supply
    final groupedByPos = <String, List<GstInvoiceDetailModel>>{};
    for (final inv in b2cInterstate) {
      if (!groupedByPos.containsKey(inv.placeOfSupply)) {
        groupedByPos[inv.placeOfSupply] = [];
      }
      groupedByPos[inv.placeOfSupply]!.add(inv);
    }

    return groupedByPos.entries.map((entry) {
      final invList = entry.value;
      return Table32Item(
        placeOfSupply: entry.key,
        taxableValue: invList.fold(0.0, (sum, i) => sum + i.taxableValue),
        igst: invList.fold(0.0, (sum, i) => sum + i.igstAmount),
      );
    }).toList();
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}

/// GSTR-3B Summary
class Gstr3bSummary {
  final String period;
  final Table31Summary table3_1;
  final List<Table32Item> table3_2;
  final TaxLiability totalTaxLiability;

  Gstr3bSummary({
    required this.period,
    required this.table3_1,
    required this.table3_2,
    required this.totalTaxLiability,
  });
}

/// Table 3.1 - Outward supplies summary
class Table31Summary {
  // Row (a): Outward taxable supplies
  final double taxableSuppliesTaxableValue;
  final double taxableSuppliesCgst;
  final double taxableSuppliesSgst;
  final double taxableSuppliesIgst;
  final double taxableSuppliesCess;

  // Row (b): Zero rated
  final double zeroRatedTaxableValue;
  final double zeroRatedIgst;

  // Row (c): Nil rated / Exempt
  final double nilExemptTaxableValue;

  // Row (d): Reverse charge
  final double reverseChargeTaxableValue;
  final double reverseChargeCgst;
  final double reverseChargeSgst;
  final double reverseChargeIgst;

  // Row (e): Non-GST
  final double nonGstTaxableValue;

  Table31Summary({
    required this.taxableSuppliesTaxableValue,
    required this.taxableSuppliesCgst,
    required this.taxableSuppliesSgst,
    required this.taxableSuppliesIgst,
    required this.taxableSuppliesCess,
    required this.zeroRatedTaxableValue,
    required this.zeroRatedIgst,
    required this.nilExemptTaxableValue,
    required this.reverseChargeTaxableValue,
    required this.reverseChargeCgst,
    required this.reverseChargeSgst,
    required this.reverseChargeIgst,
    required this.nonGstTaxableValue,
  });

  double get totalCgst => taxableSuppliesCgst + reverseChargeCgst;
  double get totalSgst => taxableSuppliesSgst + reverseChargeSgst;
  double get totalIgst =>
      taxableSuppliesIgst + zeroRatedIgst + reverseChargeIgst;
  double get totalCess => taxableSuppliesCess;
  double get totalTaxableValue =>
      taxableSuppliesTaxableValue +
      zeroRatedTaxableValue +
      nilExemptTaxableValue +
      reverseChargeTaxableValue +
      nonGstTaxableValue;
}

/// Table 3.2 - Interstate supplies item
class Table32Item {
  final String placeOfSupply;
  final double taxableValue;
  final double igst;

  Table32Item({
    required this.placeOfSupply,
    required this.taxableValue,
    required this.igst,
  });
}

/// Tax liability breakdown
class TaxLiability {
  final double cgst;
  final double sgst;
  final double igst;
  final double cess;

  TaxLiability({
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.cess,
  });

  double get total => cgst + sgst + igst + cess;
}
