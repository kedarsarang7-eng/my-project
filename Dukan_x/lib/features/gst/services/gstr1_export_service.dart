import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../repositories/gst_repository.dart';
import '../../../core/database/app_database.dart';
import '../../../core/di/service_locator.dart';
import '../../credit_notes/data/models/credit_note_model.dart';
import '../../credit_notes/data/repositories/credit_note_repository.dart';
import '../../../core/accounting/money_math.dart';

/// GSTR-1 Export Service - Generates government-compliant JSON for GST portal upload
///
/// GSTR-1 is a monthly/quarterly return of outward supplies (sales)
/// Format follows GST Portal specifications
class Gstr1ExportService {
  final GstRepository _gstRepo;
  final AppDatabase _db;
  late final CreditNoteRepository _creditNoteRepo;

  Gstr1ExportService({GstRepository? gstRepo, AppDatabase? db})
    : _gstRepo = gstRepo ?? GstRepository(),
      _db = db ?? sl<AppDatabase>() {
    _creditNoteRepo = CreditNoteRepository(_db);
  }

  /// Generate GSTR-1 JSON for a filing period
  Future<Gstr1ExportResult> generateGstr1Json({
    required String userId,
    required String gstin,
    required String financialYear, // e.g., "2025-26"
    required String taxPeriod, // e.g., "042025" for April 2025
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Get GST settings
    final gstSettings = await _gstRepo.getGstSettings(userId);
    if (gstSettings == null || !gstSettings.isGstEnabled) {
      return Gstr1ExportResult.error('GST is not enabled for this business');
    }

    // Get all GST invoices for the period
    final invoices = await _gstRepo.getGstInvoicesForPeriod(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
    );

    // Get bill details for each invoice
    final bills = await _getBillsForInvoices(invoices);

    // Get customer details for each bill
    final customers = await _getCustomersForBills(bills.values.toList());

    // Get credit notes for the period
    final creditNotes = await _creditNoteRepo.getCreditNotesForGstr1(
      userId: userId,
      fromDate: startDate,
      toDate: endDate,
    );

    // Categorize invoices
    final b2bInvoices = invoices
        .where((i) => i.invoiceType == GstInvoiceType.b2b)
        .toList();
    final b2clInvoices = invoices
        .where((i) => i.invoiceType == GstInvoiceType.b2cl)
        .toList();
    final b2csInvoices = invoices
        .where((i) => i.invoiceType == GstInvoiceType.b2cs)
        .toList();

    // Categorize credit notes (B2B -> CDNR, B2C -> CDNUR)
    final cdnrNotes = creditNotes.where((cn) => cn.isB2B).toList();
    final cdnurNotes = creditNotes.where((cn) => !cn.isB2B).toList();

    // Build GSTR-1 JSON structure
    final gstr1Data = {
      "gstin": gstin,
      "fp": taxPeriod,
      "gt": _calculateGrossTurnover(invoices),
      "cur_gt": _calculateGrossTurnover(invoices),
      "b2b": _buildB2BSection(b2bInvoices, bills, customers),
      "b2cl": _buildB2CLSection(b2clInvoices, bills),
      "b2cs": _buildB2CSSection(b2csInvoices),
      "cdnr": _buildCDNRSection(cdnrNotes), // Credit/Debit Notes for B2B
      "cdnur": _buildCDNURSection(cdnurNotes), // Credit/Debit Notes for B2C
      "hsn": _buildHsnSummary(invoices),
      "nil": _buildNilRatedSection(invoices),
      "doc_issue": _buildDocumentIssuedSection(invoices, bills),
    };

    // Remove empty sections
    gstr1Data.removeWhere((key, value) {
      if (value is List) return value.isEmpty;
      if (value is Map) return value.isEmpty;
      return false;
    });

    final jsonString = const JsonEncoder.withIndent('  ').convert(gstr1Data);

    return Gstr1ExportResult.success(
      json: jsonString,
      summary: Gstr1Summary(
        totalInvoices: invoices.length,
        b2bCount: b2bInvoices.length,
        b2clCount: b2clInvoices.length,
        b2csCount: b2csInvoices.length,
        cdnrCount: cdnrNotes.length,
        cdnurCount: cdnurNotes.length,
        totalTaxableValue: invoices.fold(0.0, (sum, i) => sum + i.taxableValue),
        totalCgst: invoices.fold(0.0, (sum, i) => sum + i.cgstAmount),
        totalSgst: invoices.fold(0.0, (sum, i) => sum + i.sgstAmount),
        totalIgst: invoices.fold(0.0, (sum, i) => sum + i.igstAmount),
        totalCess: invoices.fold(0.0, (sum, i) => sum + i.cessAmount),
        creditNoteTaxReversed: creditNotes.fold(
          0.0,
          (sum, cn) => sum + cn.totalGst,
        ),
      ),
    );
  }

  Future<Map<String, BillEntity>> _getBillsForInvoices(
    List<GstInvoiceDetailModel> invoices,
  ) async {
    final billIds = invoices.map((i) => i.billId).toSet().toList();
    final billsMap = <String, BillEntity>{};

    for (final billId in billIds) {
      final bill = await _db.getBillById(billId);
      if (bill != null) {
        billsMap[billId] = bill;
      }
    }
    return billsMap;
  }

  Future<Map<String, CustomerEntity>> _getCustomersForBills(
    List<BillEntity> bills,
  ) async {
    final customerIds = bills
        .map((b) => b.customerId)
        .whereType<String>()
        .toSet()
        .toList();
    final customersMap = <String, CustomerEntity>{};

    for (final custId in customerIds) {
      final customer = await _db.getCustomerById(custId);
      if (customer != null) {
        customersMap[custId] = customer;
      }
    }
    return customersMap;
  }

  double _calculateGrossTurnover(List<GstInvoiceDetailModel> invoices) {
    return invoices.fold(0.0, (sum, i) => sum + i.taxableValue + i.totalGst);
  }

  /// Build B2B section (Business to Business)
  List<Map<String, dynamic>> _buildB2BSection(
    List<GstInvoiceDetailModel> invoices,
    Map<String, BillEntity> bills,
    Map<String, CustomerEntity> customers,
  ) {
    // Group by customer GSTIN
    final groupedByGstin = <String, List<GstInvoiceDetailModel>>{};

    for (final inv in invoices) {
      final bill = bills[inv.billId];
      if (bill == null) continue;

      String? customerGstin;
      if (bill.customerId != null) {
        customerGstin = customers[bill.customerId!]?.gstin;
      }

      // If no valid GSTIN found, skip or handle error (B2B must have GSTIN)
      if (customerGstin == null || customerGstin.isEmpty) {
        debugPrint(
          'GstrExport: Warning - B2B invoice ${bill.invoiceNumber} has no customer GSTIN',
        );
        continue; // Skip this invoice for B2B section, maybe it should be B2C?
      }

      if (!groupedByGstin.containsKey(customerGstin)) {
        groupedByGstin[customerGstin] = [];
      }
      groupedByGstin[customerGstin]!.add(inv);
    }

    return groupedByGstin.entries.map((entry) {
      return {
        "ctin": entry.key,
        "inv": entry.value.map((inv) {
          final bill = bills[inv.billId]!;
          return {
            "inum": bill.invoiceNumber,
            "idt": _formatDate(bill.billDate),
            "val": inv.taxableValue + inv.totalGst,
            "pos": inv.placeOfSupply,
            "rchrg": inv.isReverseCharge ? "Y" : "N",
            "inv_typ": "R", // Regular
            "itms": [
              {
                "num": 1,
                "itm_det": {
                  "txval": inv.taxableValue,
                  "rt": inv.igstRate > 0
                      ? inv.igstRate
                      : (inv.cgstRate + inv.sgstRate),
                  "camt": inv.cgstAmount,
                  "samt": inv.sgstAmount,
                  "iamt": inv.igstAmount,
                  "csamt": inv.cessAmount,
                },
              },
            ],
          };
        }).toList(),
      };
    }).toList();
  }

  /// Build B2CL section (B2C Large - Interstate > ₹2.5L)
  List<Map<String, dynamic>> _buildB2CLSection(
    List<GstInvoiceDetailModel> invoices,
    Map<String, BillEntity> bills,
  ) {
    // Group by Place of Supply
    final groupedByPos = <String, List<GstInvoiceDetailModel>>{};

    for (final inv in invoices) {
      if (!groupedByPos.containsKey(inv.placeOfSupply)) {
        groupedByPos[inv.placeOfSupply] = [];
      }
      groupedByPos[inv.placeOfSupply]!.add(inv);
    }

    return groupedByPos.entries.map((entry) {
      return {
        "pos": entry.key,
        "inv": entry.value.map((inv) {
          final bill = bills[inv.billId]!;
          return {
            "inum": bill.invoiceNumber,
            "idt": _formatDate(bill.billDate),
            "val": inv.taxableValue + inv.totalGst,
            "itms": [
              {
                "num": 1,
                "itm_det": {
                  "txval": inv.taxableValue,
                  "rt": inv.igstRate,
                  "iamt": inv.igstAmount,
                  "csamt": inv.cessAmount,
                },
              },
            ],
          };
        }).toList(),
      };
    }).toList();
  }

  /// Build B2CS section (B2C Small - aggregated by rate)
  List<Map<String, dynamic>> _buildB2CSSection(
    List<GstInvoiceDetailModel> invoices,
  ) {
    // Aggregate by supply type, place of supply, and rate
    final aggregated = <String, _B2CSAggregate>{};

    for (final inv in invoices) {
      final rate = inv.igstRate > 0
          ? inv.igstRate
          : (inv.cgstRate + inv.sgstRate);
      final key = '${inv.supplyType.name}_${inv.placeOfSupply}_$rate';

      if (!aggregated.containsKey(key)) {
        aggregated[key] = _B2CSAggregate(
          supplyType: inv.supplyType,
          placeOfSupply: inv.placeOfSupply,
          rate: rate,
        );
      }
      aggregated[key]!.add(inv);
    }

    return aggregated.values.map((agg) {
      return {
        "sply_ty": agg.supplyType == SupplyType.inter ? "INTER" : "INTRA",
        "pos": agg.placeOfSupply,
        "rt": agg.rate,
        "typ": "OE", // Outward taxable supplies (E-Commerce)
        "txval": agg.taxableValue,
        "camt": agg.cgstAmount,
        "samt": agg.sgstAmount,
        "iamt": agg.igstAmount,
        "csamt": agg.cessAmount,
      };
    }).toList();
  }

  /// Build HSN Summary section
  Map<String, dynamic> _buildHsnSummary(List<GstInvoiceDetailModel> invoices) {
    final hsnMap = <String, HsnSummaryItem>{};

    for (final inv in invoices) {
      for (final hsn in inv.hsnSummary) {
        if (hsnMap.containsKey(hsn.hsnCode)) {
          final existing = hsnMap[hsn.hsnCode]!;
          hsnMap[hsn.hsnCode] = HsnSummaryItem(
            hsnCode: hsn.hsnCode,
            description: existing.description,
            uqc: existing.uqc,
            quantity: existing.quantity + hsn.quantity,
            taxableValue: existing.taxableValue + hsn.taxableValue,
            cgstAmount: existing.cgstAmount + hsn.cgstAmount,
            sgstAmount: existing.sgstAmount + hsn.sgstAmount,
            igstAmount: existing.igstAmount + hsn.igstAmount,
            cessAmount: existing.cessAmount + hsn.cessAmount,
          );
        } else {
          hsnMap[hsn.hsnCode] = hsn;
        }
      }
    }

    return {
      "data": hsnMap.values.map((hsn) {
        return {
          "num": 1,
          "hsn_sc": hsn.hsnCode,
          "desc": hsn.description,
          "uqc": hsn.uqc ?? "OTH-OTHERS",
          "qty": hsn.quantity,
          "val": hsn.taxableValue + hsn.totalTax,
          "txval": hsn.taxableValue,
          "camt": hsn.cgstAmount,
          "samt": hsn.sgstAmount,
          "iamt": hsn.igstAmount,
          "csamt": hsn.cessAmount,
        };
      }).toList(),
    };
  }

  /// Build nil rated / exempt section
  Map<String, dynamic> _buildNilRatedSection(
    List<GstInvoiceDetailModel> invoices,
  ) {
    final nilInvoices = invoices
        .where((i) => i.invoiceType == GstInvoiceType.nil)
        .toList();
    if (nilInvoices.isEmpty) return {};

    final interValue = nilInvoices
        .where((i) => i.supplyType == SupplyType.inter)
        .fold(0.0, (sum, i) => sum + i.taxableValue);
    final intraValue = nilInvoices
        .where((i) => i.supplyType == SupplyType.intra)
        .fold(0.0, (sum, i) => sum + i.taxableValue);

    return {
      "inv": [
        {
          "sply_ty": "INTRB2B",
          "nil_amt": 0,
          "expt_amt": intraValue,
          "ngsup_amt": 0,
        },
        {
          "sply_ty": "INTRAB2C",
          "nil_amt": 0,
          "expt_amt": interValue,
          "ngsup_amt": 0,
        },
      ],
    };
  }

  /// Build document issued summary
  Map<String, dynamic> _buildDocumentIssuedSection(
    List<GstInvoiceDetailModel> invoices,
    Map<String, BillEntity> bills,
  ) {
    if (invoices.isEmpty) return {};

    final invoiceNumbers = invoices
        .map((i) => bills[i.billId]?.invoiceNumber)
        .whereType<String>()
        .toList();

    if (invoiceNumbers.isEmpty) return {};

    invoiceNumbers.sort();

    return {
      "doc_det": [
        {
          "doc_num": 1,
          "docs": [
            {
              "num": 1,
              "from": invoiceNumbers.first,
              "to": invoiceNumbers.last,
              "totnum": invoices.length,
              "cancel": 0,
              "net_issue": invoices.length,
            },
          ],
        },
      ],
    };
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  /// Build CDNR section (Credit/Debit Notes for B2B)
  /// Per GST Portal: Grouped by customer GSTIN
  List<Map<String, dynamic>> _buildCDNRSection(List<CreditNote> creditNotes) {
    if (creditNotes.isEmpty) return [];

    // Group by customer GSTIN
    final groupedByGstin = <String, List<CreditNote>>{};
    for (final cn in creditNotes) {
      final gstin = cn.customerGstin ?? '';
      if (gstin.isEmpty) continue; // Skip if no GSTIN (should be CDNUR)
      if (!groupedByGstin.containsKey(gstin)) {
        groupedByGstin[gstin] = [];
      }
      groupedByGstin[gstin]!.add(cn);
    }

    return groupedByGstin.entries.map((entry) {
      return {
        "ctin": entry.key,
        "nt": entry.value.map((cn) {
          final rate = cn.totalIgst > 0
              ? (cn.totalIgst / cn.totalTaxableValue * 100)
              : ((cn.totalCgst + cn.totalSgst) / cn.totalTaxableValue * 100);
          return {
            "ntty": "C", // C = Credit Note, D = Debit Note
            "nt_num": cn.creditNoteNumber,
            "nt_dt": _formatDate(cn.date),
            "inum": cn.originalBillNumber,
            "idt": _formatDate(cn.originalBillDate),
            "val": cn.grandTotal,
            "pos": cn.placeOfSupply ?? "00",
            "rchrg": cn.isReverseCharge ? "Y" : "N",
            "inv_typ": "R", // Regular
            "itms": [
              {
                "num": 1,
                "itm_det": {
                  "txval": cn.totalTaxableValue,
                  "rt": rate.isNaN ? 0 : rate,
                  "camt": cn.totalCgst,
                  "samt": cn.totalSgst,
                  "iamt": cn.totalIgst,
                  "csamt": 0, // Cess - not tracked separately yet
                },
              },
            ],
          };
        }).toList(),
      };
    }).toList();
  }

  /// Build CDNUR section (Credit/Debit Notes for B2C Unregistered)
  /// Per GST Portal: For B2C credit notes > 2.5L interstate
  List<Map<String, dynamic>> _buildCDNURSection(List<CreditNote> creditNotes) {
    if (creditNotes.isEmpty) return [];

    return creditNotes.map((cn) {
      final rate = cn.totalIgst > 0
          ? (cn.totalIgst / cn.totalTaxableValue * 100)
          : ((cn.totalCgst + cn.totalSgst) / cn.totalTaxableValue * 100);

      return {
        "typ": "B2CL", // B2CL for large B2C
        "ntty": "C", // C = Credit Note
        "nt_num": cn.creditNoteNumber,
        "nt_dt": _formatDate(cn.date),
        "inum": cn.originalBillNumber,
        "idt": _formatDate(cn.originalBillDate),
        "val": cn.grandTotal,
        "pos": cn.placeOfSupply ?? "00",
        "itms": [
          {
            "num": 1,
            "itm_det": {
              "txval": cn.totalTaxableValue,
              "rt": rate.isNaN ? 0 : rate,
              "camt": cn.totalCgst,
              "samt": cn.totalSgst,
              "iamt": cn.totalIgst,
              "csamt": 0,
            },
          },
        ],
      };
    }).toList();
  }
}

/// Helper class for B2CS aggregation
class _B2CSAggregate {
  final SupplyType supplyType;
  final String placeOfSupply;
  final double rate;
  double taxableValue = 0;
  double cgstAmount = 0;
  double sgstAmount = 0;
  double igstAmount = 0;
  double cessAmount = 0;

  _B2CSAggregate({
    required this.supplyType,
    required this.placeOfSupply,
    required this.rate,
  });

  void add(GstInvoiceDetailModel inv) {
    taxableValue = MoneyMath.sum([taxableValue, inv.taxableValue]);
    cgstAmount = MoneyMath.sum([cgstAmount, inv.cgstAmount]);
    sgstAmount = MoneyMath.sum([sgstAmount, inv.sgstAmount]);
    igstAmount = MoneyMath.sum([igstAmount, inv.igstAmount]);
    cessAmount = MoneyMath.sum([cessAmount, inv.cessAmount]);
  }
}

/// GSTR-1 Export Result
class Gstr1ExportResult {
  final bool success;
  final String? json;
  final Gstr1Summary? summary;
  final String? errorMessage;

  Gstr1ExportResult.success({required this.json, required this.summary})
    : success = true,
      errorMessage = null;

  Gstr1ExportResult.error(this.errorMessage)
    : success = false,
      json = null,
      summary = null;
}

/// GSTR-1 Summary for display
class Gstr1Summary {
  final int totalInvoices;
  final int b2bCount;
  final int b2clCount;
  final int b2csCount;
  final int cdnrCount;
  final int cdnurCount;
  final double totalTaxableValue;
  final double totalCgst;
  final double totalSgst;
  final double totalIgst;
  final double totalCess;
  final double creditNoteTaxReversed;

  Gstr1Summary({
    required this.totalInvoices,
    required this.b2bCount,
    required this.b2clCount,
    required this.b2csCount,
    this.cdnrCount = 0,
    this.cdnurCount = 0,
    required this.totalTaxableValue,
    required this.totalCgst,
    required this.totalSgst,
    required this.totalIgst,
    required this.totalCess,
    this.creditNoteTaxReversed = 0,
  });

  double get totalGst => totalCgst + totalSgst + totalIgst + totalCess;
  int get totalCreditNotes => cdnrCount + cdnurCount;
}
