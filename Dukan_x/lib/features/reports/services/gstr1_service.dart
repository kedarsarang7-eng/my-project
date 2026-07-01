import 'package:collection/collection.dart';
import '../../../../core/repository/bills_repository.dart';
import '../../../../core/repository/customers_repository.dart';
import '../../../../core/accounting/money_math.dart';

class GSTR1Data {
  final List<B2BInvoice> b2bInvoices;
  final List<B2CSInvoice> b2cSmallInvoices;
  final List<HSNSummary> hsnSummary;

  GSTR1Data({
    required this.b2bInvoices,
    required this.b2cSmallInvoices,
    required this.hsnSummary,
  });
}

class B2BInvoice {
  final String gstIn;
  final String customerName;
  final String invoiceNumber;
  final DateTime date;
  final double invoiceValue;
  final String placeOfSupply;
  final bool reverseCharge;
  final double taxableValue;
  final double taxRate; // Integrated or derived
  final double igst;
  final double cgst;
  final double sgst;
  final double cess;

  B2BInvoice({
    required this.gstIn,
    required this.customerName,
    required this.invoiceNumber,
    required this.date,
    required this.invoiceValue,
    required this.placeOfSupply,
    this.reverseCharge = false,
    required this.taxableValue,
    required this.taxRate,
    this.igst = 0,
    this.cgst = 0,
    this.sgst = 0,
    this.cess = 0,
  });
}

class B2CSInvoice {
  final String placeOfSupply;
  final double taxRate;
  final double taxableValue;
  final double cess;
  final String type = "OE"; // E-Commerce

  B2CSInvoice({
    required this.placeOfSupply,
    required this.taxRate,
    required this.taxableValue,
    this.cess = 0,
  });
}

class HSNSummary {
  final String hsn;
  final String description;
  final String uqc;
  final double totalQuantity;
  final double totalValue;
  final double taxableValue;
  final double igst;
  final double cgst;
  final double sgst;
  final double cess;

  HSNSummary({
    required this.hsn,
    required this.description,
    required this.uqc,
    required this.totalQuantity,
    required this.totalValue,
    required this.taxableValue,
    this.igst = 0,
    this.cgst = 0,
    this.sgst = 0,
    this.cess = 0,
  });
}

class GSTR1Service {
  final BillsRepository _billsRepository;
  final CustomersRepository _customersRepository;

  GSTR1Service(this._billsRepository, this._customersRepository);

  Future<GSTR1Data> generateReport(
    String userId,
    DateTime from,
    DateTime to,
  ) async {
    // 1. Fetch Bills
    // We fetch all because repo doesn't support date range filtering natively yet in getAll
    // Ideally we would optimize this to fetch by date range at SQL level.
    // For now we filter in memory as per current repo capabilities or use getAll with loop.
    final result = await _billsRepository.getAll(userId: userId);
    if (result.isFailure) throw Exception(result.error);

    final bills =
        result.data?.where((b) {
          final date = b.date; // already DateTime
          return date.isAfter(from.subtract(const Duration(seconds: 1))) &&
              date.isBefore(to.add(const Duration(days: 1)));
        }).toList() ??
        [];

    // 2. Fetch Customers for GSTIN lookup if missing in Bill
    final customersResult = await _customersRepository.getAll(userId: userId);
    final customerMap = {for (var c in (customersResult.data ?? [])) c.id: c};

    final b2bList = <B2BInvoice>[];
    final b2csList = <B2CSInvoice>[];
    final hsnMap = <String, HSNSummary>{};

    for (var bill in bills) {
      // Determine if B2B
      String gstIn = bill.customerGst;
      if (gstIn.isEmpty && bill.customerId.isNotEmpty) {
        gstIn = customerMap[bill.customerId]?.gstin ?? '';
      }

      final isB2B = gstIn.isNotEmpty && gstIn.length >= 15; // Basic validation

      // Calculate Tax breakdown per bill
      // Assuming naive calculation across items if bill level tax is not detailed enough
      // But we need granular data for HSN.

      // -- HSN AGGREGATION --
      for (var item in bill.items) {
        final key = "${item.hsn}_${item.gstRate}";
        final existing = hsnMap[key];

        // Item total value usually includes tax. Taxable = (qty*price)-discount
        final itemTaxable = (item.quantity * item.unitPrice) - item.discount;
        final itemTotal = itemTaxable + item.taxAmount;

        hsnMap[key] = HSNSummary(
          hsn: item.hsn.isEmpty ? "Unknown" : item.hsn, // Default
          description: item.productName, // Can be varied, pick first
          uqc: item.unit.toUpperCase(),
          totalQuantity: (existing?.totalQuantity ?? 0) + item.quantity,
          totalValue: (existing?.totalValue ?? 0) + itemTotal,
          taxableValue: (existing?.taxableValue ?? 0) + itemTaxable,
          igst: (existing?.igst ?? 0) + item.igst,
          cgst: (existing?.cgst ?? 0) + item.cgst,
          sgst: (existing?.sgst ?? 0) + item.sgst,
        );
      }

      // -- INVOICE CATEGORIZATION --
      if (isB2B) {
        // Consolidated tax for the bill
        // B2B usually requires line-item level if rates differ,
        // but often summarized by rate. GSTR1 schema actually asks for Rate-wise breakdown per invoice.
        // For simplicity in this summary version, we aggregate the bill.

        // Find dominant tax rate or create multiple entries if needed?
        // GSTR-1 logic: One Invoice can have multiple lines for different rates.
        // We will simplify: Summarize by Tax Rate for this Invoice.
        final rateGroups = groupBy(bill.items, (i) => i.gstRate);

        for (var entry in rateGroups.entries) {
          final rate = entry.key;
          final items = entry.value;

          final taxable = MoneyMath.sum(items.map((i) => (i.quantity * i.unitPrice) - i.discount));
          final igst = MoneyMath.sum(items.map((i) => i.igst));
          final cgst = MoneyMath.sum(items.map((i) => i.cgst));
          final sgst = MoneyMath.sum(items.map((i) => i.sgst));

          b2bList.add(
            B2BInvoice(
              gstIn: gstIn,
              customerName: bill.customerName,
              invoiceNumber: bill.invoiceNumber,
              date: bill.date,
              invoiceValue: bill
                  .grandTotal, // This repeats for rows of same invoice, standard practice in some CSVs, or just map once.
              // Actually, Invoice Value is total bill value. Taxable is split.
              placeOfSupply: _deducePOS(gstIn, bill.shopAddress),
              taxableValue: taxable,
              taxRate: rate,
              igst: igst,
              cgst: cgst,
              sgst: sgst,
            ),
          );
        }
      } else {
        // B2C Small
        // Aggregated by POS + Rate
        // If invoice > 2.5L and Inter-state -> B2C Large (Ignored for now as per plan "B2C Small")

        final rateGroups = groupBy(bill.items, (i) => i.gstRate);
        for (var entry in rateGroups.entries) {
          final rate = entry.key;
          final items = entry.value;
          final taxable = MoneyMath.sum(items.map((i) => (i.quantity * i.unitPrice) - i.discount));

          // Check if we can aggregate into existing B2CS entry?
          // The output list B2CSInvoice is usually "Type + POS + Rate" unique keys.
          // We will add raw first then aggregate? Or just add all and UI sums them.
          // Let's add raw for now, data processing is easier.
          // Actually, better to aggregate here.

          b2csList.add(
            B2CSInvoice(
              placeOfSupply: "State", // Default, should parse form address
              taxRate: rate,
              taxableValue: taxable,
            ),
          );
        }
      }
    }

    // Aggregate B2CS List by Rate
    final aggregatedB2CS = <String, B2CSInvoice>{};
    for (var item in b2csList) {
      final key = "${item.placeOfSupply}_${item.taxRate}";
      final existing = aggregatedB2CS[key];
      aggregatedB2CS[key] = B2CSInvoice(
        placeOfSupply: item.placeOfSupply,
        taxRate: item.taxRate,
        taxableValue: (existing?.taxableValue ?? 0) + item.taxableValue,
        cess: (existing?.cess ?? 0) + item.cess,
      );
    }

    return GSTR1Data(
      b2bInvoices: b2bList,
      b2cSmallInvoices: aggregatedB2CS.values.toList(),
      hsnSummary: hsnMap.values.toList(),
    );
  }

  String _deducePOS(String gstin, String shopAddress) {
    if (gstin.length >= 2) {
      return gstin.substring(0, 2); // State Code
    }
    return "Unknown";
  }
}
