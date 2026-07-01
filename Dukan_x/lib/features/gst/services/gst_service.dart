import 'package:uuid/uuid.dart';
import '../models/gst_invoice_detail_model.dart';
import 'gstin_validator.dart';

/// GST Service - Core GST calculation and invoice classification logic
class GstService {
  static const double b2cLargeThreshold = 250000; // ₹2.5 Lakhs

  /// Determine invoice type based on customer and invoice details
  static GstInvoiceType determineInvoiceType({
    required String? customerGstin,
    required String sellerStateCode,
    required String? customerStateCode,
    required double invoiceAmount,
  }) {
    // If customer has GSTIN, it's B2B
    if (customerGstin != null && customerGstin.isNotEmpty) {
      final validation = GstinValidator.validateGstin(customerGstin);
      if (validation.isValid) {
        return GstInvoiceType.b2b;
      }
    }

    // B2C - Check if Large or Small
    final isInterstate = sellerStateCode != customerStateCode;

    if (isInterstate && invoiceAmount > b2cLargeThreshold) {
      return GstInvoiceType.b2cl;
    }

    return GstInvoiceType.b2cs;
  }

  /// Determine supply type (Interstate/Intrastate)
  static SupplyType determineSupplyType({
    required String sellerStateCode,
    required String? customerStateCode,
  }) {
    if (customerStateCode == null || customerStateCode.isEmpty) {
      // Default to intrastate if customer state unknown
      return SupplyType.intra;
    }
    return sellerStateCode == customerStateCode
        ? SupplyType.intra
        : SupplyType.inter;
  }

  /// Calculate tax breakup for a line item
  static TaxBreakup calculateTaxBreakup({
    required double taxableValue,
    required double gstRate,
    required SupplyType supplyType,
  }) {
    if (supplyType == SupplyType.intra) {
      // Intrastate: Split into CGST + SGST
      final halfRate = gstRate / 2;
      final halfAmount = (taxableValue * halfRate) / 100;
      return TaxBreakup(
        cgstRate: halfRate,
        cgstAmount: halfAmount,
        sgstRate: halfRate,
        sgstAmount: halfAmount,
        igstRate: 0,
        igstAmount: 0,
      );
    } else {
      // Interstate: Full IGST
      final igstAmount = (taxableValue * gstRate) / 100;
      return TaxBreakup(
        cgstRate: 0,
        cgstAmount: 0,
        sgstRate: 0,
        sgstAmount: 0,
        igstRate: gstRate,
        igstAmount: igstAmount,
      );
    }
  }

  /// Calculate GST for an entire invoice
  static InvoiceGstSummary calculateInvoiceGst({
    required List<LineItemForGst> items,
    required String sellerStateCode,
    required String? customerStateCode,
    required String? customerGstin,
  }) {
    final supplyType = determineSupplyType(
      sellerStateCode: sellerStateCode,
      customerStateCode: customerStateCode,
    );

    double totalTaxableValue = 0;
    double totalCgst = 0;
    double totalSgst = 0;
    double totalIgst = 0;
    final List<HsnSummaryItem> hsnSummary = [];
    final Map<String, HsnSummaryItem> hsnMap = {};

    for (final item in items) {
      final taxBreakup = calculateTaxBreakup(
        taxableValue: item.taxableValue,
        gstRate: item.gstRate,
        supplyType: supplyType,
      );

      totalTaxableValue += item.taxableValue;
      totalCgst += taxBreakup.cgstAmount;
      totalSgst += taxBreakup.sgstAmount;
      totalIgst += taxBreakup.igstAmount;

      // Aggregate by HSN code
      final hsn = item.hsnCode ?? 'UNKNOWN';
      if (hsnMap.containsKey(hsn)) {
        final existing = hsnMap[hsn]!;
        hsnMap[hsn] = HsnSummaryItem(
          hsnCode: hsn,
          description: existing.description,
          uqc: existing.uqc,
          quantity: existing.quantity + item.quantity,
          taxableValue: existing.taxableValue + item.taxableValue,
          cgstAmount: existing.cgstAmount + taxBreakup.cgstAmount,
          sgstAmount: existing.sgstAmount + taxBreakup.sgstAmount,
          igstAmount: existing.igstAmount + taxBreakup.igstAmount,
        );
      } else {
        hsnMap[hsn] = HsnSummaryItem(
          hsnCode: hsn,
          description: item.description,
          uqc: item.unit,
          quantity: item.quantity,
          taxableValue: item.taxableValue,
          cgstAmount: taxBreakup.cgstAmount,
          sgstAmount: taxBreakup.sgstAmount,
          igstAmount: taxBreakup.igstAmount,
        );
      }
    }

    hsnSummary.addAll(hsnMap.values);

    final invoiceType = determineInvoiceType(
      customerGstin: customerGstin,
      sellerStateCode: sellerStateCode,
      customerStateCode: customerStateCode,
      invoiceAmount: totalTaxableValue + totalCgst + totalSgst + totalIgst,
    );

    return InvoiceGstSummary(
      invoiceType: invoiceType,
      supplyType: supplyType,
      taxableValue: totalTaxableValue,
      cgstAmount: totalCgst,
      sgstAmount: totalSgst,
      igstAmount: totalIgst,
      totalGst: totalCgst + totalSgst + totalIgst,
      grandTotal: totalTaxableValue + totalCgst + totalSgst + totalIgst,
      hsnSummary: hsnSummary,
    );
  }

  /// Create GstInvoiceDetailModel from calculation
  static GstInvoiceDetailModel createGstInvoiceDetail({
    required String billId,
    required InvoiceGstSummary summary,
    required String placeOfSupply,
  }) {
    return GstInvoiceDetailModel(
      id: const Uuid().v4(),
      billId: billId,
      invoiceType: summary.invoiceType,
      supplyType: summary.supplyType,
      placeOfSupply: placeOfSupply,
      taxableValue: summary.taxableValue,
      cgstRate: summary.hsnSummary.isNotEmpty
          ? summary.hsnSummary.first.cgstAmount /
                (summary.hsnSummary.first.taxableValue > 0
                    ? summary.hsnSummary.first.taxableValue
                    : 1) *
                100
          : 0,
      cgstAmount: summary.cgstAmount,
      sgstRate: summary.hsnSummary.isNotEmpty
          ? summary.hsnSummary.first.sgstAmount /
                (summary.hsnSummary.first.taxableValue > 0
                    ? summary.hsnSummary.first.taxableValue
                    : 1) *
                100
          : 0,
      sgstAmount: summary.sgstAmount,
      igstRate: summary.hsnSummary.isNotEmpty
          ? summary.hsnSummary.first.igstAmount /
                (summary.hsnSummary.first.taxableValue > 0
                    ? summary.hsnSummary.first.taxableValue
                    : 1) *
                100
          : 0,
      igstAmount: summary.igstAmount,
      hsnSummary: summary.hsnSummary,
      createdAt: DateTime.now(),
    );
  }
}

/// Tax breakup result
class TaxBreakup {
  final double cgstRate;
  final double cgstAmount;
  final double sgstRate;
  final double sgstAmount;
  final double igstRate;
  final double igstAmount;

  TaxBreakup({
    required this.cgstRate,
    required this.cgstAmount,
    required this.sgstRate,
    required this.sgstAmount,
    required this.igstRate,
    required this.igstAmount,
  });

  double get totalTax => cgstAmount + sgstAmount + igstAmount;
}

/// Line item input for GST calculation
class LineItemForGst {
  final String? hsnCode;
  final String description;
  final double quantity;
  final String? unit;
  final double taxableValue; // unitPrice * quantity - discount
  final double gstRate;

  LineItemForGst({
    this.hsnCode,
    required this.description,
    required this.quantity,
    this.unit,
    required this.taxableValue,
    required this.gstRate,
  });
}

/// Invoice GST summary result
class InvoiceGstSummary {
  final GstInvoiceType invoiceType;
  final SupplyType supplyType;
  final double taxableValue;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double totalGst;
  final double grandTotal;
  final List<HsnSummaryItem> hsnSummary;

  InvoiceGstSummary({
    required this.invoiceType,
    required this.supplyType,
    required this.taxableValue,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    required this.totalGst,
    required this.grandTotal,
    required this.hsnSummary,
  });
}

// =============================================================================
// REVERSE CHARGE MECHANISM (RCM) SUPPORT
// =============================================================================

/// RCM Categories as per GST Law
enum RcmCategory {
  none,
  unregisteredSupplier, // From unregistered dealer
  specifiedServices, // Legal, Security, GTA etc.
  importOfGoods,
  importOfServices,
}

/// Reverse Charge Result
class ReverseChargeResult {
  final bool isApplicable;
  final RcmCategory category;
  final String? reason;
  final double rcmAmount;

  const ReverseChargeResult({
    required this.isApplicable,
    required this.category,
    this.reason,
    this.rcmAmount = 0,
  });
}

/// RCM Service - Check if Reverse Charge is applicable
class ReverseChargeService {
  // SAC codes for specified services under RCM
  static const Set<String> rcmServiceCodes = {
    '9961', // GTA (Goods Transport Agency)
    '9962', // GTA
    '9963', // GTA
    '9971', // Legal Services
    '9972', // Accounting
    '9983', // Manpower Supply
    '9985', // Security Services
    '9986', // Services by Director
    '9987', // Services by Insurance Agent
  };

  /// Check if RCM applies for a purchase
  static ReverseChargeResult checkRcmApplicability({
    required bool isSupplierRegistered,
    required String? supplierGstin,
    required String? sacCode,
    required double invoiceAmount,
    required bool isImport,
  }) {
    // 1. Import of Goods/Services
    if (isImport) {
      return const ReverseChargeResult(
        isApplicable: true,
        category: RcmCategory.importOfServices,
        reason: 'Import of goods/services attracts RCM',
      );
    }

    // 2. Purchase from Unregistered Supplier (now limited)
    // Note: As of now, RCM on unregistered dealers is mostly exempted
    // except for specific categories like Advocate/GTA
    if (!isSupplierRegistered ||
        (supplierGstin == null || supplierGstin.isEmpty)) {
      // Check if it's a notified category
      if (sacCode != null &&
          rcmServiceCodes.contains(sacCode.substring(0, 4))) {
        return ReverseChargeResult(
          isApplicable: true,
          category: RcmCategory.unregisteredSupplier,
          reason: 'Service from unregistered supplier under notified category',
        );
      }
    }

    // 3. Specified Services (even from registered suppliers)
    if (sacCode != null && sacCode.length >= 4) {
      final prefix = sacCode.substring(0, 4);
      if (rcmServiceCodes.contains(prefix)) {
        return ReverseChargeResult(
          isApplicable: true,
          category: RcmCategory.specifiedServices,
          reason: 'Service under specified RCM category (SAC: $sacCode)',
        );
      }
    }

    return const ReverseChargeResult(
      isApplicable: false,
      category: RcmCategory.none,
    );
  }
}

// =============================================================================
// TDS/TCS UNDER GST
// =============================================================================

/// TDS/TCS Result
class TdsTcsResult {
  final bool isTdsApplicable;
  final bool isTcsApplicable;
  final double tdsRate;
  final double tcsRate;
  final double tdsAmount;
  final double tcsAmount;
  final String? reason;

  const TdsTcsResult({
    this.isTdsApplicable = false,
    this.isTcsApplicable = false,
    this.tdsRate = 0,
    this.tcsRate = 0,
    this.tdsAmount = 0,
    this.tcsAmount = 0,
    this.reason,
  });
}

/// TDS/TCS Service
class GstTdsTcsService {
  // TDS threshold for government entities
  static const double tdsThreshold = 250000; // ₹2.5 Lakhs
  // TCS threshold for e-commerce operators
  static const double tcsThreshold = 0; // No threshold, applicable on all

  // TDS rate as per GST law
  static const double tdsRate = 2.0; // 2% (1% CGST + 1% SGST or 2% IGST)
  // TCS rate as per GST law
  static const double tcsRate = 1.0; // 1% (0.5% CGST + 0.5% SGST or 1% IGST)

  /// Check TDS applicability (for Government/PSU/Notified entities)
  static TdsTcsResult checkTdsApplicability({
    required double invoiceAmount,
    required bool isDeductorGovernment, // Is buyer a govt/PSU entity
    required bool isDeductorNotified, // Is buyer a notified entity
  }) {
    if (!isDeductorGovernment && !isDeductorNotified) {
      return const TdsTcsResult(reason: 'Buyer not a TDS deductor');
    }

    if (invoiceAmount < tdsThreshold) {
      return TdsTcsResult(
        reason:
            'Invoice amount below TDS threshold of ₹${tdsThreshold.toStringAsFixed(0)}',
      );
    }

    final tdsAmount = invoiceAmount * tdsRate / 100;
    return TdsTcsResult(
      isTdsApplicable: true,
      tdsRate: tdsRate,
      tdsAmount: tdsAmount,
      reason: 'TDS applicable at $tdsRate%',
    );
  }

  /// Check TCS applicability (for E-commerce operators)
  static TdsTcsResult checkTcsApplicability({
    required double netTaxableValue,
    required bool isEcommerceOperator,
  }) {
    if (!isEcommerceOperator) {
      return const TdsTcsResult(reason: 'Not an e-commerce transaction');
    }

    final tcsAmount = netTaxableValue * tcsRate / 100;
    return TdsTcsResult(
      isTcsApplicable: true,
      tcsRate: tcsRate,
      tcsAmount: tcsAmount,
      reason: 'TCS applicable at $tcsRate% for e-commerce',
    );
  }
}

// =============================================================================
// COMPLIANCE WARNINGS
// =============================================================================

/// Compliance Warning
class ComplianceWarning {
  final String code;
  final String severity; // INFO, WARNING, ERROR
  final String message;
  final String? action;

  const ComplianceWarning({
    required this.code,
    required this.severity,
    required this.message,
    this.action,
  });
}

/// Compliance Checker - Generate warnings for GST compliance issues
class GstComplianceChecker {
  /// Check invoice for compliance issues
  static List<ComplianceWarning> checkInvoiceCompliance({
    required double invoiceAmount,
    required String? customerGstin,
    required String? hsnCode,
    required bool isB2b,
    required bool hasEwaybill,
    required double distance,
  }) {
    final warnings = <ComplianceWarning>[];

    // 1. E-Way Bill Check (>₹50,000 for movement of goods)
    if (invoiceAmount > 50000 && !hasEwaybill && distance > 0) {
      warnings.add(
        const ComplianceWarning(
          code: 'EWB001',
          severity: 'ERROR',
          message: 'E-Way Bill required for invoice amount >₹50,000',
          action: 'Generate E-Way Bill before dispatch',
        ),
      );
    }

    // 2. GSTIN validation for B2B
    if (isB2b && (customerGstin == null || customerGstin.isEmpty)) {
      warnings.add(
        const ComplianceWarning(
          code: 'GST001',
          severity: 'ERROR',
          message: 'Customer GSTIN required for B2B invoice',
          action: 'Add customer GSTIN before generating invoice',
        ),
      );
    }

    // 3. HSN code requirement
    if (hsnCode == null || hsnCode.isEmpty) {
      warnings.add(
        const ComplianceWarning(
          code: 'HSN001',
          severity: 'WARNING',
          message: 'HSN code missing - required for GST returns',
          action: 'Add HSN/SAC code to products',
        ),
      );
    }

    // 4. Large B2C invoice warning
    if (!isB2b && invoiceAmount > 250000) {
      warnings.add(
        const ComplianceWarning(
          code: 'B2C001',
          severity: 'INFO',
          message: 'Large B2C invoice - will be reported in B2CL section',
          action: 'Ensure customer state code is correct',
        ),
      );
    }

    // 5. E-Invoice threshold (>₹5 Cr turnover)
    // This would need business profile data
    // Placeholder for UI integration

    return warnings;
  }
}
