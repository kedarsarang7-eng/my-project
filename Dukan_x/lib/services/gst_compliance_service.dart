import 'package:dukanx/core/compat/firestore_compat.dart';
import '../core/accounting/money_math.dart';

/// GST Compliance Service - GSTR-1, GSTR-3B mapping and reconciliation.
///
/// Provides automated GST return data generation and reconciliation
/// for Indian businesses as per GST Council guidelines.
class GstComplianceService {
  final FirebaseFirestore _firestore;

  GstComplianceService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  // ============================================================
  // GSTR-1 (Outward Supplies)
  // ============================================================

  /// Generate GSTR-1 data for a tax period.
  ///
  /// GSTR-1 contains:
  /// - B2B Invoices (with recipient GSTIN)
  /// - B2C Large (>Rs.2.5L, inter-state)
  /// - B2C Small (other B2C)
  /// - Credit/Debit Notes
  /// - Exports
  Future<Gstr1Data> generateGstr1(
    String businessId,
    int month, // 1-12
    int year,
  ) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

    // Get all sales for the period
    final salesSnapshot = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('sales')
        .where('date', isGreaterThanOrEqualTo: startDate.toIso8601String())
        .where('date', isLessThanOrEqualTo: endDate.toIso8601String())
        .where('isReversed', isNotEqualTo: true)
        .get();

    final b2bInvoices = <B2BInvoice>[];
    final b2cLarge = <B2CInvoice>[];
    final b2cSmall = <B2CInvoice>[];
    final creditNotes = <CreditNote>[];
    final exportInvoices = <ExportInvoice>[];

    for (final doc in salesSnapshot.docs) {
      final data = doc.data();
      final type = data['type'] ?? 'sale';
      final gstin = data['customerGstin'] as String?;
      final amount = (data['totalAmount'] ?? 0).toDouble();
      final taxable = (data['subTotal'] ?? 0).toDouble();
      final isInterState = data['isInterState'] ?? false;

      if (type == 'saleReturn') {
        // Credit Note
        creditNotes.add(
          CreditNote(
            noteNo: data['refNo'] ?? '',
            noteDate: DateTime.parse(
              data['date'] ?? DateTime.now().toIso8601String(),
            ),
            originalInvoiceNo: data['originalInvoiceNo'] ?? '',
            originalInvoiceDate: _parseDate(data['originalInvoiceDate']),
            gstin: gstin,
            taxableValue: taxable.abs(),
            cgst: (data['cgstTotal'] ?? 0).toDouble().abs(),
            sgst: (data['sgstTotal'] ?? 0).toDouble().abs(),
            igst: (data['igstTotal'] ?? 0).toDouble().abs(),
            total: amount.abs(),
          ),
        );
      } else if (gstin != null && gstin.isNotEmpty && gstin.length == 15) {
        // B2B - has valid GSTIN
        b2bInvoices.add(
          B2BInvoice(
            gstin: gstin,
            invoiceNo: data['refNo'] ?? '',
            invoiceDate: DateTime.parse(
              data['date'] ?? DateTime.now().toIso8601String(),
            ),
            taxableValue: taxable,
            cgst: (data['cgstTotal'] ?? 0).toDouble(),
            sgst: (data['sgstTotal'] ?? 0).toDouble(),
            igst: (data['igstTotal'] ?? 0).toDouble(),
            total: amount,
            placeOfSupply: data['placeOfSupply'] ?? '',
            isReverseCharge: data['isReverseCharge'] ?? false,
          ),
        );
      } else if (amount > 250000 && isInterState) {
        // B2C Large - Inter-state > Rs.2.5L
        b2cLarge.add(
          B2CInvoice(
            invoiceNo: data['refNo'] ?? '',
            invoiceDate: DateTime.parse(
              data['date'] ?? DateTime.now().toIso8601String(),
            ),
            taxableValue: taxable,
            igst: (data['igstTotal'] ?? 0).toDouble(),
            total: amount,
            placeOfSupply: data['placeOfSupply'] ?? '',
          ),
        );
      } else if (type == 'export') {
        // Export Invoice
        // We assume export invoices have type='export' and shipping details in data
        exportInvoices.add(
          ExportInvoice(
            invoiceNo: data['refNo'] ?? '',
            invoiceDate: DateTime.parse(
              data['date'] ?? DateTime.now().toIso8601String(),
            ),
            taxableValue: taxable,
            igst: (data['igstTotal'] ?? 0).toDouble(),
            portCode: data['portCode'] ?? '',
            shippingBillNo: data['shippingBillNo'] ?? '',
          ),
        );
      } else {
        // B2C Small
        b2cSmall.add(
          B2CInvoice(
            invoiceNo: data['refNo'] ?? '',
            invoiceDate: DateTime.parse(
              data['date'] ?? DateTime.now().toIso8601String(),
            ),
            taxableValue: taxable,
            cgst: (data['cgstTotal'] ?? 0).toDouble(),
            sgst: (data['sgstTotal'] ?? 0).toDouble(),
            igst: (data['igstTotal'] ?? 0).toDouble(),
            total: amount,
            placeOfSupply: data['placeOfSupply'] ?? '',
          ),
        );
      }
    }

    // Calculate totals using MoneyMath
    final totalTaxable = MoneyMath.sum([
      ...b2bInvoices.map((inv) => inv.taxableValue),
      ...b2cLarge.map((inv) => inv.taxableValue),
      ...b2cSmall.map((inv) => inv.taxableValue),
      ...exportInvoices.map((inv) => inv.taxableValue),
    ]);
    final totalCgst = MoneyMath.sum([
      ...b2bInvoices.map((inv) => inv.cgst),
      ...b2cSmall.map((inv) => inv.cgst ?? 0),
    ]);
    final totalSgst = MoneyMath.sum([
      ...b2bInvoices.map((inv) => inv.sgst),
      ...b2cSmall.map((inv) => inv.sgst ?? 0),
    ]);
    final totalIgst = MoneyMath.sum([
      ...b2bInvoices.map((inv) => inv.igst),
      ...b2cLarge.map((inv) => inv.igst ?? 0),
      ...b2cSmall.map((inv) => inv.igst ?? 0),
      ...exportInvoices.map((inv) => inv.igst),
    ]);

    return Gstr1Data(
      businessId: businessId,
      month: month,
      year: year,
      b2bInvoices: b2bInvoices,
      b2cLarge: b2cLarge,
      b2cSmall: b2cSmall,
      creditNotes: creditNotes,
      exportInvoices: exportInvoices,
      totalTaxableValue: totalTaxable,
      totalCgst: totalCgst,
      totalSgst: totalSgst,
      totalIgst: totalIgst,
      totalTax: totalCgst + totalSgst + totalIgst,
    );
  }

  // ============================================================
  // GSTR-3B (Summary Return)
  // ============================================================

  /// Generate GSTR-3B summary data for a tax period.
  Future<Gstr3bData> generateGstr3b(
    String businessId,
    int month,
    int year,
  ) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

    // 1. Outward supplies (from sales)
    final salesSnapshot = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('sales')
        .where('date', isGreaterThanOrEqualTo: startDate.toIso8601String())
        .where('date', isLessThanOrEqualTo: endDate.toIso8601String())
        .where('type', isEqualTo: 'sale')
        .where('isReversed', isNotEqualTo: true)
        .get();

    final outwardTaxable = MoneyMath.sum(salesSnapshot.docs.map((doc) => (doc.data()['subTotal'] ?? 0).toDouble()));
    final outwardCgst = MoneyMath.sum(salesSnapshot.docs.map((doc) => (doc.data()['cgstTotal'] ?? 0).toDouble()));
    final outwardSgst = MoneyMath.sum(salesSnapshot.docs.map((doc) => (doc.data()['sgstTotal'] ?? 0).toDouble()));
    final outwardIgst = MoneyMath.sum(salesSnapshot.docs.map((doc) => (doc.data()['igstTotal'] ?? 0).toDouble()));

    // 2. Inward supplies (from purchases) - for ITC
    final purchaseSnapshot = await _firestore
        .collection('purchase_bills')
        .where('ownerId', isEqualTo: businessId)
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThanOrEqualTo: endDate)
        .get();

    final eligiblePurchases = purchaseSnapshot.docs.where((doc) {
      final supplierGstin = doc.data()['supplierGstin'] as String?;
      return supplierGstin != null && supplierGstin.length == 15;
    });
    final itcCgst = MoneyMath.sum(eligiblePurchases.map((doc) => (doc.data()['cgstTotal'] ?? 0).toDouble()));
    final itcSgst = MoneyMath.sum(eligiblePurchases.map((doc) => (doc.data()['sgstTotal'] ?? 0).toDouble()));
    final itcIgst = MoneyMath.sum(eligiblePurchases.map((doc) => (doc.data()['igstTotal'] ?? 0).toDouble()));

    // 3. Calculate liability
    final cgstLiability = outwardCgst - itcCgst;
    final sgstLiability = outwardSgst - itcSgst;
    final igstLiability = outwardIgst - itcIgst;

    return Gstr3bData(
      businessId: businessId,
      month: month,
      year: year,
      outwardTaxableValue: outwardTaxable,
      outwardCgst: outwardCgst,
      outwardSgst: outwardSgst,
      outwardIgst: outwardIgst,
      itcCgst: itcCgst,
      itcSgst: itcSgst,
      itcIgst: itcIgst,
      cgstPayable: cgstLiability > 0 ? cgstLiability : 0,
      sgstPayable: sgstLiability > 0 ? sgstLiability : 0,
      igstPayable: igstLiability > 0 ? igstLiability : 0,
      totalPayable:
          (cgstLiability > 0 ? cgstLiability : 0) +
          (sgstLiability > 0 ? sgstLiability : 0) +
          (igstLiability > 0 ? igstLiability : 0),
    );
  }

  // ============================================================
  // GST RECONCILIATION
  // ============================================================

  /// Reconcile GST collected (sales) with GST payable.
  Future<GstReconciliation> reconcileGst(
    String businessId,
    int month,
    int year,
  ) async {
    final gstr1 = await generateGstr1(businessId, month, year);
    final gstr3b = await generateGstr3b(businessId, month, year);

    // Check if GSTR-1 totals match GSTR-3B
    final salesDifference =
        gstr1.totalTaxableValue - gstr3b.outwardTaxableValue;
    final cgstDifference = gstr1.totalCgst - gstr3b.outwardCgst;
    final sgstDifference = gstr1.totalSgst - gstr3b.outwardSgst;
    final igstDifference = gstr1.totalIgst - gstr3b.outwardIgst;

    final isReconciled =
        salesDifference.abs() < 1 &&
        cgstDifference.abs() < 1 &&
        sgstDifference.abs() < 1 &&
        igstDifference.abs() < 1;

    return GstReconciliation(
      businessId: businessId,
      month: month,
      year: year,
      gstr1TaxableValue: gstr1.totalTaxableValue,
      gstr3bTaxableValue: gstr3b.outwardTaxableValue,
      taxableDifference: salesDifference,
      gstr1Cgst: gstr1.totalCgst,
      gstr3bCgst: gstr3b.outwardCgst,
      cgstDifference: cgstDifference,
      gstr1Sgst: gstr1.totalSgst,
      gstr3bSgst: gstr3b.outwardSgst,
      sgstDifference: sgstDifference,
      gstr1Igst: gstr1.totalIgst,
      gstr3bIgst: gstr3b.outwardIgst,
      igstDifference: igstDifference,
      isReconciled: isReconciled,
    );
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}

// ============================================================
// DATA MODELS
// ============================================================

/// GSTR-1 complete data
class Gstr1Data {
  final String businessId;
  final int month;
  final int year;
  final List<B2BInvoice> b2bInvoices;
  final List<B2CInvoice> b2cLarge;
  final List<B2CInvoice> b2cSmall;
  final List<CreditNote> creditNotes;
  final List<ExportInvoice> exportInvoices;
  final double totalTaxableValue;
  final double totalCgst;
  final double totalSgst;
  final double totalIgst;
  final double totalTax;

  const Gstr1Data({
    required this.businessId,
    required this.month,
    required this.year,
    required this.b2bInvoices,
    required this.b2cLarge,
    required this.b2cSmall,
    required this.creditNotes,
    required this.exportInvoices,
    required this.totalTaxableValue,
    required this.totalCgst,
    required this.totalSgst,
    required this.totalIgst,
    required this.totalTax,
  });

  int get totalInvoiceCount =>
      b2bInvoices.length + b2cLarge.length + b2cSmall.length;
}

/// B2B Invoice for GSTR-1
class B2BInvoice {
  final String gstin;
  final String invoiceNo;
  final DateTime invoiceDate;
  final double taxableValue;
  final double cgst;
  final double sgst;
  final double igst;
  final double total;
  final String placeOfSupply;
  final bool isReverseCharge;

  const B2BInvoice({
    required this.gstin,
    required this.invoiceNo,
    required this.invoiceDate,
    required this.taxableValue,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.total,
    required this.placeOfSupply,
    required this.isReverseCharge,
  });
}

/// B2C Invoice for GSTR-1
class B2CInvoice {
  final String invoiceNo;
  final DateTime invoiceDate;
  final double taxableValue;
  final double? cgst;
  final double? sgst;
  final double? igst;
  final double total;
  final String placeOfSupply;

  const B2CInvoice({
    required this.invoiceNo,
    required this.invoiceDate,
    required this.taxableValue,
    this.cgst,
    this.sgst,
    this.igst,
    required this.total,
    required this.placeOfSupply,
  });
}

/// Credit/Debit Note for GSTR-1
class CreditNote {
  final String noteNo;
  final DateTime noteDate;
  final String originalInvoiceNo;
  final DateTime? originalInvoiceDate;
  final String? gstin;
  final double taxableValue;
  final double cgst;
  final double sgst;
  final double igst;
  final double total;

  const CreditNote({
    required this.noteNo,
    required this.noteDate,
    required this.originalInvoiceNo,
    this.originalInvoiceDate,
    this.gstin,
    required this.taxableValue,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.total,
  });
}

/// Export Invoice for GSTR-1
class ExportInvoice {
  final String invoiceNo;
  final DateTime invoiceDate;
  final double taxableValue;
  final double igst;
  final String portCode;
  final String shippingBillNo;

  const ExportInvoice({
    required this.invoiceNo,
    required this.invoiceDate,
    required this.taxableValue,
    required this.igst,
    required this.portCode,
    required this.shippingBillNo,
  });
}

/// GSTR-3B summary data
class Gstr3bData {
  final String businessId;
  final int month;
  final int year;
  final double outwardTaxableValue;
  final double outwardCgst;
  final double outwardSgst;
  final double outwardIgst;
  final double itcCgst;
  final double itcSgst;
  final double itcIgst;
  final double cgstPayable;
  final double sgstPayable;
  final double igstPayable;
  final double totalPayable;

  const Gstr3bData({
    required this.businessId,
    required this.month,
    required this.year,
    required this.outwardTaxableValue,
    required this.outwardCgst,
    required this.outwardSgst,
    required this.outwardIgst,
    required this.itcCgst,
    required this.itcSgst,
    required this.itcIgst,
    required this.cgstPayable,
    required this.sgstPayable,
    required this.igstPayable,
    required this.totalPayable,
  });

  double get totalOutwardTax => outwardCgst + outwardSgst + outwardIgst;
  double get totalItc => itcCgst + itcSgst + itcIgst;
}

/// GST Reconciliation result
class GstReconciliation {
  final String businessId;
  final int month;
  final int year;
  final double gstr1TaxableValue;
  final double gstr3bTaxableValue;
  final double taxableDifference;
  final double gstr1Cgst;
  final double gstr3bCgst;
  final double cgstDifference;
  final double gstr1Sgst;
  final double gstr3bSgst;
  final double sgstDifference;
  final double gstr1Igst;
  final double gstr3bIgst;
  final double igstDifference;
  final bool isReconciled;

  const GstReconciliation({
    required this.businessId,
    required this.month,
    required this.year,
    required this.gstr1TaxableValue,
    required this.gstr3bTaxableValue,
    required this.taxableDifference,
    required this.gstr1Cgst,
    required this.gstr3bCgst,
    required this.cgstDifference,
    required this.gstr1Sgst,
    required this.gstr3bSgst,
    required this.sgstDifference,
    required this.gstr1Igst,
    required this.gstr3bIgst,
    required this.igstDifference,
    required this.isReconciled,
  });

  double get totalDifference =>
      taxableDifference.abs() +
      cgstDifference.abs() +
      sgstDifference.abs() +
      igstDifference.abs();
}
