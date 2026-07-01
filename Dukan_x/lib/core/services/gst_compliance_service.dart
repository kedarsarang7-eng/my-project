import 'package:dukanx/core/compat/firestore_compat.dart';
import 'package:dukanx/core/api/api_client.dart';
import 'package:dukanx/core/di/service_locator.dart';
import 'package:dukanx/core/accounting/money_math.dart';

/// GST Compliance Service - GSTR-1, GSTR-3B mapping and reconciliation.
///
/// Provides automated GST return data generation and reconciliation
/// for Indian businesses as per GST Council guidelines.
/// Structured compliance warning for GST audit trail.
class ComplianceWarning {
  final String type;
  final String billId;
  final String invoiceNo;
  final String message;
  final String severity;
  final DateTime timestamp;

  ComplianceWarning({
    required this.type,
    required this.billId,
    required this.invoiceNo,
    required this.message,
    this.severity = 'warning',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class GstComplianceService {
  ApiClient get _api => sl<ApiClient>();
  GstComplianceService();

  /// Compliance warnings collected during report generation.
  final List<ComplianceWarning> _complianceWarnings = [];
  List<ComplianceWarning> get complianceWarnings =>
      List.unmodifiable(_complianceWarnings);
  void clearWarnings() => _complianceWarnings.clear();

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

    // Get all sales for the period via API
    final res = await _api.get(
      '/api/v1/bills',
      queryParameters: {
        'businessId': businessId,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      },
    );

    final billDocs = <Map<String, dynamic>>[];
    if (res.isSuccess && res.data != null) {
      // Assuming pagination or items array
      final dynamic data = res.data;
      billDocs.addAll(
        List<Map<String, dynamic>>.from(
          (data is Map && data.containsKey('items')) ? data['items'] : data,
        ),
      );
    }

    final b2bInvoices = <B2BInvoice>[];
    final b2cLarge = <B2CInvoice>[];
    final b2cSmall = <B2CInvoice>[];
    final creditNotes = <CreditNote>[];
    final exportInvoices = <ExportInvoice>[];
    double nilRatedAmount = 0; // Petroleum (outside GST) for Table 8

    for (final data in billDocs) {
      final type = data['type'] ?? 'sale';
      final gstin = data['customerGst'] as String?;
      final amount = (data['grandTotal'] ?? 0).toDouble();
      final taxable = (data['subtotal'] ?? 0).toDouble();
      final isInterState = data['isInterState'] ?? false;

      // PETROLEUM COMPLIANCE: Skip non-GST items (petrol/diesel)
      // These are outside GST and should not appear in GSTR-1.
      // They go to nil-rated/exempt supply table instead.
      final taxRegime = data['taxRegime'] as String?;
      final businessType = data['businessType'] as String? ?? '';
      if (taxRegime == 'vatExcise') {
        // GSTR-1 Table 8: Nil-rated/exempt supply
        nilRatedAmount += amount;
        continue;
      }
      // Also filter by known fuel names for legacy data without taxRegime field
      if (businessType == 'petrolPump') {
        final itemName = (data['itemName'] ?? '').toString().toLowerCase();
        if ((itemName.contains('petrol') || itemName.contains('diesel')) &&
            taxRegime != 'gst') {
          continue; // Skip non-GST petroleum
        }
      }

      if (type == 'saleReturn') {
        // Credit Note — GST requires original invoice reference
        final originalInvNo =
            (data['originalInvoiceNo'] as String?) ??
            (data['linkedBillId'] as String?) ??
            (data['originalBillId'] as String?) ??
            '';
        final originalInvDate =
            data['originalInvoiceDate'] ??
            data['linkedBillDate'] ??
            data['originalBillDate'];

        if (originalInvNo.isEmpty) {
          // G-05 FIX: Credit note without original invoice ref is non-compliant
          // per GST Rule 53. Add to discrepancies instead of silently proceeding.
          _complianceWarnings.add(
            ComplianceWarning(
              type: 'CREDIT_NOTE_MISSING_REF',
              billId: data['id']?.toString() ?? '',
              invoiceNo: data['invoiceNumber'] ?? data['refNo'] ?? '',
              message:
                  'Credit note missing original invoice reference. '
                  'Required under GST Rule 53 for GSTR-1 filing.',
              severity: 'critical',
            ),
          );
        }

        // CRITICAL: Use stored line-item CGST/SGST, never reconstruct from total
        // This ensures credit notes exactly mirror original invoice calculations
        double creditCgst = 0.0;
        double creditSgst = 0.0;
        double creditIgst = 0.0;

        final lineItems = data['items'] as List<dynamic>? ?? [];
        for (final item in lineItems) {
          creditCgst += (item['cgst'] as num? ?? 0).toDouble().abs();
          creditSgst += (item['sgst'] as num? ?? 0).toDouble().abs();
          creditIgst += (item['igst'] as num? ?? 0).toDouble().abs();
        }

        creditNotes.add(
          CreditNote(
            noteNo: data['refNo'] ?? '',
            noteDate: DateTime.parse(
              data['date'] ?? DateTime.now().toIso8601String(),
            ),
            originalInvoiceNo: originalInvNo,
            originalInvoiceDate: _parseDate(originalInvDate),
            gstin: gstin,
            taxableValue: taxable.abs(),
            cgst: creditCgst, // Use summed line-item values
            sgst: creditSgst, // Use summed line-item values
            igst: creditIgst, // Use summed line-item values
            total: amount.abs(),
          ),
        );
      } else if (gstin != null && gstin.isNotEmpty && gstin.length == 15) {
        // B2B - has valid GSTIN
        // CRITICAL: Use stored line-item CGST/SGST, never reconstruct from total
        double invoiceCgst = 0.0;
        double invoiceSgst = 0.0;
        double invoiceIgst = 0.0;

        final lineItems = data['items'] as List<dynamic>? ?? [];
        for (final item in lineItems) {
          invoiceCgst += (item['cgst'] as num? ?? 0).toDouble();
          invoiceSgst += (item['sgst'] as num? ?? 0).toDouble();
          invoiceIgst += (item['igst'] as num? ?? 0).toDouble();
        }

        b2bInvoices.add(
          B2BInvoice(
            gstin: gstin,
            invoiceNo: data['invoiceNumber'] ?? '',
            invoiceDate: DateTime.parse(
              data['date'] ?? DateTime.now().toIso8601String(),
            ),
            taxableValue: taxable,
            cgst: invoiceCgst, // Use summed line-item values
            sgst: invoiceSgst, // Use summed line-item values
            igst: invoiceIgst, // Use summed line-item values
            total: amount,
            placeOfSupply: data['placeOfSupply'] ?? '',
            isReverseCharge: data['isReverseCharge'] ?? false,
          ),
        );
      } else if (amount > 250000 && isInterState) {
        // B2C Large - Inter-state > Rs.2.5L
        // CRITICAL: Use stored line-item IGST, never reconstruct
        double invoiceIgst = 0.0;
        final lineItems = data['items'] as List<dynamic>? ?? [];
        for (final item in lineItems) {
          invoiceIgst += (item['igst'] as num? ?? 0).toDouble();
        }

        b2cLarge.add(
          B2CInvoice(
            invoiceNo: data['invoiceNumber'] ?? '',
            invoiceDate: DateTime.parse(
              data['date'] ?? DateTime.now().toIso8601String(),
            ),
            taxableValue: taxable,
            igst: invoiceIgst, // Use summed line-item values
            total: amount,
            placeOfSupply: data['placeOfSupply'] ?? '',
          ),
        );
      } else if (type == 'export') {
        // Export Invoice
        // CRITICAL: Use stored line-item IGST, never reconstruct
        double invoiceIgst = 0.0;
        final lineItems = data['items'] as List<dynamic>? ?? [];
        for (final item in lineItems) {
          invoiceIgst += (item['igst'] as num? ?? 0).toDouble();
        }

        exportInvoices.add(
          ExportInvoice(
            invoiceNo: data['invoiceNumber'] ?? '',
            invoiceDate: DateTime.parse(
              data['date'] ?? DateTime.now().toIso8601String(),
            ),
            taxableValue: taxable,
            igst: invoiceIgst, // Use summed line-item values
            portCode: data['portCode'] ?? '',
            shippingBillNo: data['shippingBillNo'] ?? '',
          ),
        );
      } else {
        // B2C Small
        // CRITICAL: Use stored line-item CGST/SGST/IGST, never reconstruct
        double invoiceCgst = 0.0;
        double invoiceSgst = 0.0;
        double invoiceIgst = 0.0;

        final lineItems = data['items'] as List<dynamic>? ?? [];
        for (final item in lineItems) {
          invoiceCgst += (item['cgst'] as num? ?? 0).toDouble();
          invoiceSgst += (item['sgst'] as num? ?? 0).toDouble();
          invoiceIgst += (item['igst'] as num? ?? 0).toDouble();
        }

        b2cSmall.add(
          B2CInvoice(
            invoiceNo: data['invoiceNumber'] ?? '',
            invoiceDate: DateTime.parse(
              data['date'] ?? DateTime.now().toIso8601String(),
            ),
            taxableValue: taxable,
            cgst: invoiceCgst, // Use summed line-item values
            sgst: invoiceSgst, // Use summed line-item values
            igst: invoiceIgst, // Use summed line-item values
            total: amount,
            placeOfSupply: data['placeOfSupply'] ?? '',
          ),
        );
      }
    }

    // Calculate totals using MoneyMath so the accumulator stays in
    // fixed-precision Decimal until the final rounded toDouble() (clause 2.6).
    final allInvoices = <dynamic>[
      ...b2bInvoices,
      ...b2cLarge,
      ...b2cSmall,
      ...exportInvoices,
    ];
    final double totalTaxable = MoneyMath.sum(
      allInvoices.map<double>((inv) => inv.taxableValue),
    );
    final double totalCgst = MoneyMath.sum(<double>[
      ...b2bInvoices.map((inv) => inv.cgst),
      ...b2cSmall.map((inv) => inv.cgst ?? 0.0),
    ]);
    final double totalSgst = MoneyMath.sum(<double>[
      ...b2bInvoices.map((inv) => inv.sgst),
      ...b2cSmall.map((inv) => inv.sgst ?? 0.0),
    ]);
    final double totalIgst = MoneyMath.sum(<double>[
      ...b2bInvoices.map((inv) => inv.igst),
      ...b2cLarge.map((inv) => inv.igst ?? 0.0),
      ...b2cSmall.map((inv) => inv.igst ?? 0.0),
      ...exportInvoices.map((inv) => inv.igst),
    ]);
    final double totalTax = MoneyMath.sum(<double>[
      totalCgst,
      totalSgst,
      totalIgst,
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
      totalTax: totalTax,
      nilRatedAmount: nilRatedAmount,
    );
  }

  // ============================================================
  // GSTR-3B (Summary Return)
  // ============================================================

  /// Generate GSTR-3B summary data for a tax period.
  ///
  /// G-02 FIX: Uses same API data source as GSTR-1 to ensure reconciliation.
  /// Previously queried 'businesses/{id}/sales' with different field names,
  /// making GSTR-1 and GSTR-3B irreconcilable.
  Future<Gstr3bData> generateGstr3b(
    String businessId,
    int month,
    int year,
  ) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

    // 1. Outward supplies — query same API endpoint as GSTR-1
    final billsResult = await _api.get(
      '/api/v1/bills',
      queryParams: {
        'businessId': businessId,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      },
    );

    double outwardTaxable = 0;
    double outwardCgst = 0;
    double outwardSgst = 0;
    double outwardIgst = 0;

    if (billsResult.isSuccess && billsResult.data != null) {
      final data = billsResult.data!;
      final bills =
          (data['bills'] as List<dynamic>?) ??
          (data['items'] as List<dynamic>?) ??
          const <dynamic>[];

      for (final data in bills) {
        final type = data['type'] ?? 'sale';
        if (type == 'saleReturn') continue; // Credit notes handled separately

        final taxable = (data['subtotal'] ?? 0).toDouble();
        final totalTax = (data['totalTax'] ?? 0).toDouble();
        final isInterState = data['isInterState'] ?? false;

        outwardTaxable += taxable;

        if (isInterState == true) {
          outwardIgst += totalTax;
        } else {
          // Split evenly — matches TaxCalculator logic
          outwardCgst += totalTax / 2;
          outwardSgst += totalTax / 2;
        }
      }
    }

    // 2. Inward supplies (from purchases) — for ITC
    // OFF-02 FIX: Migrated from legacy Firestore .collection() to REST API
    final purchaseResponse = await _api.get(
      '/api/v1/purchase-bills',
      queryParams: {
        'businessId': businessId,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      },
    );

    double itcCgst = 0;
    double itcSgst = 0;
    double itcIgst = 0;

    if (purchaseResponse.isSuccess && purchaseResponse.data != null) {
      final dynamic purchaseData = purchaseResponse.data;
      List<dynamic> purchaseBills = [];
      if (purchaseData is List) {
        purchaseBills = purchaseData;
      } else if (purchaseData is Map && purchaseData.containsKey('items')) {
        purchaseBills = purchaseData['items'] as List;
      }

      for (final data in purchaseBills) {
        // Only eligible ITC (with supplier GSTIN)
        final supplierGstin = data['supplierGstin'] as String?;
        if (supplierGstin != null && supplierGstin.length == 15) {
          final purchaseTax = (data['totalTax'] ?? 0).toDouble();
          final isInterState = data['isInterState'] ?? false;

          if (isInterState == true) {
            itcIgst += purchaseTax;
          } else {
            itcCgst += purchaseTax / 2;
            itcSgst += purchaseTax / 2;
          }
        }
      }
    }

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
  final double nilRatedAmount; // GSTR-1 Table 8: Petrol/diesel outside GST

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
    this.nilRatedAmount = 0,
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
