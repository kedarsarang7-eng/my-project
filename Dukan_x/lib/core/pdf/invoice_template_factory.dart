// ============================================================================
// INVOICE TEMPLATE FACTORY - BUSINESS-TYPE AWARE INVOICES
// ============================================================================
// Implements plug-based invoice generation that varies by business type
//
// REQUIREMENTS:
// - Each business type has unique invoice fields
// - No one-size-fits-all invoice
// - No hardcoded conditions inside UI
//
// SUPPORTED BUSINESS TYPES:
// - Petrol Pump: Fuel type, Nozzle, Shift, Litres, Rate
// - Pharmacy: Batch, Expiry, HSN
// - Grocery: Item-wise GST
// - Service: Labour/Service charges
// - Restaurant: Table, Service charge
// - Electronics: Serial, Warranty
// - General: Standard columns
//
// Author: DukanX Engineering
// ============================================================================

import 'package:intl/intl.dart';
import '../../models/business_type.dart';
import '../../models/bill.dart';

/// Column definition for invoice tables
class InvoiceColumn {
  final String id;
  final String label;
  final double widthRatio; // Relative width (0.0 - 1.0)
  final bool isNumeric;
  final bool isCurrency;

  const InvoiceColumn({
    required this.id,
    required this.label,
    this.widthRatio = 0.1,
    this.isNumeric = false,
    this.isCurrency = false,
  });
}

/// Base invoice template interface
abstract class InvoiceTemplate {
  /// Column definitions for this business type
  List<InvoiceColumn> get columns;

  /// Header text for invoice (can be customized per type)
  String get headerText;

  /// Footer text/notes specific to this business type
  String get footerText;

  /// Format a bill item to a map of column values
  Map<String, dynamic> formatItem(BillItem item, int index);

  /// Get additional fields to show in invoice header
  Map<String, String> getHeaderFields(Bill bill);

  /// Business-specific summary rows (before totals)
  List<Map<String, String>> getSummaryRows(Bill bill);
}

/// Factory to get appropriate template for business type
class InvoiceTemplateFactory {
  /// Get template for a specific business type
  ///
  /// CRITICAL: This is the single point of business-type logic
  /// UI should NEVER contain business-type conditionals
  static InvoiceTemplate getTemplate(BusinessType type) {
    switch (type) {
      case BusinessType.petrolPump:
        return PetrolPumpInvoiceTemplate();
      case BusinessType.pharmacy:
        return PharmacyInvoiceTemplate();
      case BusinessType.grocery:
        return GroceryInvoiceTemplate();
      case BusinessType.service:
        return ServiceInvoiceTemplate();
      case BusinessType.restaurant:
        return RestaurantInvoiceTemplate();
      case BusinessType.electronics:
        return ElectronicsInvoiceTemplate();
      case BusinessType.clothing:
        return ClothingInvoiceTemplate();
      case BusinessType.hardware:
        return HardwareInvoiceTemplate();
      case BusinessType.other:
      default:
        return GeneralInvoiceTemplate();
    }
  }
}

// ============================================================================
// PETROL PUMP INVOICE TEMPLATE
// ============================================================================
class PetrolPumpInvoiceTemplate implements InvoiceTemplate {
  @override
  List<InvoiceColumn> get columns => const [
    InvoiceColumn(id: 'sno', label: 'S.No', widthRatio: 0.05),
    InvoiceColumn(id: 'fuel_type', label: 'Fuel Type', widthRatio: 0.15),
    InvoiceColumn(id: 'nozzle', label: 'Nozzle', widthRatio: 0.10),
    InvoiceColumn(id: 'vehicle', label: 'Vehicle', widthRatio: 0.15),
    InvoiceColumn(
      id: 'litres',
      label: 'Litres',
      widthRatio: 0.15,
      isNumeric: true,
    ),
    InvoiceColumn(
      id: 'rate',
      label: 'Rate/L',
      widthRatio: 0.15,
      isCurrency: true,
    ),
    InvoiceColumn(
      id: 'amount',
      label: 'Amount',
      widthRatio: 0.20,
      isCurrency: true,
    ),
  ];

  @override
  String get headerText => 'FUEL INVOICE';

  @override
  String get footerText =>
      'Prices inclusive of all taxes as per government norms.';

  @override
  Map<String, dynamic> formatItem(BillItem item, int index) {
    // Use BillItem direct fields for petrol pump
    return {
      'sno': '${index + 1}',
      'fuel_type': item.productName,
      'nozzle': item.nozzleId ?? '-',
      'vehicle': item.vehicleNumber ?? '-',
      'litres': item.qty.toStringAsFixed(2),
      'rate': '₹${item.price.toStringAsFixed(2)}',
      'amount': '₹${item.total.toStringAsFixed(2)}',
    };
  }

  @override
  Map<String, String> getHeaderFields(Bill bill) {
    return {if (bill.shiftId != null) 'Shift ID': bill.shiftId!};
  }

  @override
  List<Map<String, String>> getSummaryRows(Bill bill) {
    final totalLitres = bill.items.fold<double>(
      0,
      (sum, item) => sum + item.qty,
    );
    return [
      {'label': 'Total Litres', 'value': '${totalLitres.toStringAsFixed(2)} L'},
    ];
  }
}

// ============================================================================
// PHARMACY INVOICE TEMPLATE
// ============================================================================
class PharmacyInvoiceTemplate implements InvoiceTemplate {
  @override
  List<InvoiceColumn> get columns => const [
    InvoiceColumn(id: 'sno', label: 'S.No', widthRatio: 0.05),
    InvoiceColumn(id: 'medicine', label: 'Medicine', widthRatio: 0.20),
    InvoiceColumn(id: 'batch', label: 'Batch', widthRatio: 0.10),
    InvoiceColumn(id: 'expiry', label: 'Expiry', widthRatio: 0.10),
    InvoiceColumn(id: 'hsn', label: 'HSN', widthRatio: 0.08),
    InvoiceColumn(id: 'qty', label: 'Qty', widthRatio: 0.07, isNumeric: true),
    InvoiceColumn(id: 'mrp', label: 'MRP', widthRatio: 0.10, isCurrency: true),
    InvoiceColumn(id: 'gst', label: 'GST%', widthRatio: 0.08, isNumeric: true),
    InvoiceColumn(
      id: 'amount',
      label: 'Amount',
      widthRatio: 0.12,
      isCurrency: true,
    ),
  ];

  @override
  String get headerText => 'MEDICAL INVOICE';

  @override
  String get footerText =>
      'Drugs shown are as per prescription. Return policy as per Drug License.';

  @override
  Map<String, dynamic> formatItem(BillItem item, int index) {
    // Use BillItem direct fields
    String expiryStr = '-';
    if (item.expiryDate != null) {
      expiryStr = DateFormat('MM/yy').format(item.expiryDate!);
    }

    return {
      'sno': '${index + 1}',
      'medicine': item.productName,
      'batch': item.batchNo ?? '-',
      'expiry': expiryStr,
      'hsn': item.hsn.isNotEmpty ? item.hsn : '-',
      'qty': item.qty.toStringAsFixed(0),
      'mrp': '₹${item.price.toStringAsFixed(2)}',
      'gst': '${item.gstRate.toStringAsFixed(1)}%',
      'amount': '₹${item.total.toStringAsFixed(2)}',
    };
  }

  @override
  Map<String, String> getHeaderFields(Bill bill) {
    return {
      'Doctor': bill.items.isNotEmpty
          ? (bill.items.first.doctorName ?? '-')
          : '-',
      'Patient': bill.customerName.isNotEmpty ? bill.customerName : '-',
    };
  }

  @override
  List<Map<String, String>> getSummaryRows(Bill bill) => [];
}

// ============================================================================
// GROCERY INVOICE TEMPLATE
// ============================================================================
class GroceryInvoiceTemplate implements InvoiceTemplate {
  @override
  List<InvoiceColumn> get columns => const [
    InvoiceColumn(id: 'sno', label: 'S.No', widthRatio: 0.05),
    InvoiceColumn(id: 'item', label: 'Item Name', widthRatio: 0.25),
    InvoiceColumn(id: 'hsn', label: 'HSN', widthRatio: 0.08),
    InvoiceColumn(id: 'qty', label: 'Qty', widthRatio: 0.08, isNumeric: true),
    InvoiceColumn(
      id: 'rate',
      label: 'Rate',
      widthRatio: 0.12,
      isCurrency: true,
    ),
    InvoiceColumn(id: 'gst', label: 'GST%', widthRatio: 0.08, isNumeric: true),
    InvoiceColumn(
      id: 'gst_amt',
      label: 'GST Amt',
      widthRatio: 0.12,
      isCurrency: true,
    ),
    InvoiceColumn(
      id: 'discount',
      label: 'Discount',
      widthRatio: 0.10,
      isCurrency: true,
    ),
    InvoiceColumn(
      id: 'total',
      label: 'Total',
      widthRatio: 0.12,
      isCurrency: true,
    ),
  ];

  @override
  String get headerText => 'TAX INVOICE';

  @override
  String get footerText => 'Thank you for shopping with us!';

  @override
  Map<String, dynamic> formatItem(BillItem item, int index) {
    final gstAmount = item.cgst + item.sgst + item.igst;
    return {
      'sno': '${index + 1}',
      'item': item.productName,
      'hsn': item.hsn.isNotEmpty ? item.hsn : '-',
      'qty': item.qty.toStringAsFixed(2),
      'rate': '₹${item.price.toStringAsFixed(2)}',
      'gst': '${item.gstRate.toStringAsFixed(1)}%',
      'gst_amt': '₹${gstAmount.toStringAsFixed(2)}',
      'discount': '₹${item.discount.toStringAsFixed(2)}',
      'total': '₹${item.total.toStringAsFixed(2)}',
    };
  }

  @override
  Map<String, String> getHeaderFields(Bill bill) => {};

  @override
  List<Map<String, String>> getSummaryRows(Bill bill) {
    // Group GST by rate
    final gstBreakdown = <double, double>{};
    for (final item in bill.items) {
      final gstAmount = item.cgst + item.sgst + item.igst;
      gstBreakdown[item.gstRate] =
          (gstBreakdown[item.gstRate] ?? 0) + gstAmount;
    }

    return gstBreakdown.entries
        .map(
          (e) => {
            'label': 'GST ${e.key.toStringAsFixed(0)}%',
            'value': '₹${e.value.toStringAsFixed(2)}',
          },
        )
        .toList();
  }
}

// ============================================================================
// SERVICE INVOICE TEMPLATE
// ============================================================================
class ServiceInvoiceTemplate implements InvoiceTemplate {
  @override
  List<InvoiceColumn> get columns => const [
    InvoiceColumn(id: 'sno', label: 'S.No', widthRatio: 0.05),
    InvoiceColumn(id: 'service', label: 'Service', widthRatio: 0.30),
    InvoiceColumn(id: 'hsn', label: 'SAC Code', widthRatio: 0.12),
    InvoiceColumn(
      id: 'rate',
      label: 'Rate',
      widthRatio: 0.15,
      isCurrency: true,
    ),
    InvoiceColumn(id: 'gst', label: 'GST%', widthRatio: 0.10),
    InvoiceColumn(
      id: 'amount',
      label: 'Amount',
      widthRatio: 0.18,
      isCurrency: true,
    ),
  ];

  @override
  String get headerText => 'SERVICE INVOICE';

  @override
  String get footerText => 'Service charges are non-refundable.';

  @override
  Map<String, dynamic> formatItem(BillItem item, int index) {
    return {
      'sno': '${index + 1}',
      'service': item.productName,
      'hsn': item.hsn.isNotEmpty ? item.hsn : '-',
      'rate': '₹${item.price.toStringAsFixed(2)}',
      'gst': '${item.gstRate.toStringAsFixed(1)}%',
      'amount': '₹${item.total.toStringAsFixed(2)}',
    };
  }

  @override
  Map<String, String> getHeaderFields(Bill bill) {
    return {'Service Date': DateFormat('dd/MM/yyyy').format(bill.date)};
  }

  @override
  List<Map<String, String>> getSummaryRows(Bill bill) {
    // Sum labour charges from items
    double totalLabour = 0;
    for (final item in bill.items) {
      if (item.laborCharge != null) {
        totalLabour += item.laborCharge!;
      }
    }
    if (totalLabour > 0) {
      return [
        {
          'label': 'Labour Charges',
          'value': '₹${totalLabour.toStringAsFixed(2)}',
        },
      ];
    }
    return [];
  }
}

// ============================================================================
// RESTAURANT / HOTEL INVOICE TEMPLATE
// ============================================================================
class RestaurantInvoiceTemplate implements InvoiceTemplate {
  @override
  List<InvoiceColumn> get columns => const [
    InvoiceColumn(id: 'sno', label: 'S.No', widthRatio: 0.05),
    InvoiceColumn(id: 'item', label: 'Item', widthRatio: 0.35),
    InvoiceColumn(id: 'qty', label: 'Qty', widthRatio: 0.10, isNumeric: true),
    InvoiceColumn(
      id: 'price',
      label: 'Price',
      widthRatio: 0.15,
      isCurrency: true,
    ),
    InvoiceColumn(id: 'gst', label: 'GST%', widthRatio: 0.10),
    InvoiceColumn(
      id: 'total',
      label: 'Total',
      widthRatio: 0.15,
      isCurrency: true,
    ),
  ];

  @override
  String get headerText => 'RESTAURANT BILL';

  @override
  String get footerText => 'Thank you for dining with us!';

  @override
  Map<String, dynamic> formatItem(BillItem item, int index) {
    return {
      'sno': '${index + 1}',
      'item': item.productName,
      'qty': item.qty.toStringAsFixed(0),
      'price': '₹${item.price.toStringAsFixed(2)}',
      'gst': '${item.gstRate.toStringAsFixed(1)}%',
      'total': '₹${item.total.toStringAsFixed(2)}',
    };
  }

  @override
  Map<String, String> getHeaderFields(Bill bill) {
    // Get table from first item
    final tableNo = bill.items.isNotEmpty ? bill.items.first.tableNo : null;
    return {'Table': ?tableNo};
  }

  @override
  List<Map<String, String>> getSummaryRows(Bill bill) {
    if (bill.serviceCharge > 0) {
      return [
        {
          'label': 'Service Charge',
          'value': '₹${bill.serviceCharge.toStringAsFixed(2)}',
        },
      ];
    }
    return [];
  }
}

// ============================================================================
// ELECTRONICS INVOICE TEMPLATE
// ============================================================================
class ElectronicsInvoiceTemplate implements InvoiceTemplate {
  @override
  List<InvoiceColumn> get columns => const [
    InvoiceColumn(id: 'sno', label: 'S.No', widthRatio: 0.05),
    InvoiceColumn(id: 'product', label: 'Product', widthRatio: 0.20),
    InvoiceColumn(id: 'serial', label: 'Serial No', widthRatio: 0.15),
    InvoiceColumn(id: 'warranty', label: 'Warranty', widthRatio: 0.10),
    InvoiceColumn(id: 'qty', label: 'Qty', widthRatio: 0.08, isNumeric: true),
    InvoiceColumn(
      id: 'price',
      label: 'Price',
      widthRatio: 0.12,
      isCurrency: true,
    ),
    InvoiceColumn(id: 'gst', label: 'GST%', widthRatio: 0.08),
    InvoiceColumn(
      id: 'total',
      label: 'Total',
      widthRatio: 0.12,
      isCurrency: true,
    ),
  ];

  @override
  String get headerText => 'ELECTRONICS INVOICE';

  @override
  String get footerText =>
      'Warranty valid only with original invoice. Terms & conditions apply.';

  @override
  Map<String, dynamic> formatItem(BillItem item, int index) {
    // Format warranty
    String warrantyStr = '1 Year';
    if (item.warrantyMonths != null) {
      if (item.warrantyMonths! >= 12) {
        warrantyStr =
            '${item.warrantyMonths! ~/ 12} Year${item.warrantyMonths! >= 24 ? 's' : ''}';
      } else {
        warrantyStr =
            '${item.warrantyMonths} Month${item.warrantyMonths! > 1 ? 's' : ''}';
      }
    }

    return {
      'sno': '${index + 1}',
      'product': item.productName,
      'serial': item.serialNo ?? '-',
      'warranty': warrantyStr,
      'qty': item.qty.toStringAsFixed(0),
      'price': '₹${item.price.toStringAsFixed(2)}',
      'gst': '${item.gstRate.toStringAsFixed(1)}%',
      'total': '₹${item.total.toStringAsFixed(2)}',
    };
  }

  @override
  Map<String, String> getHeaderFields(Bill bill) => {};

  @override
  List<Map<String, String>> getSummaryRows(Bill bill) => [];
}

// ============================================================================
// CLOTHING INVOICE TEMPLATE
// ============================================================================
class ClothingInvoiceTemplate implements InvoiceTemplate {
  @override
  List<InvoiceColumn> get columns => const [
    InvoiceColumn(id: 'sno', label: 'S.No', widthRatio: 0.05),
    InvoiceColumn(id: 'item', label: 'Item', widthRatio: 0.22),
    InvoiceColumn(id: 'size', label: 'Size', widthRatio: 0.08),
    InvoiceColumn(id: 'color', label: 'Color', widthRatio: 0.10),
    InvoiceColumn(id: 'qty', label: 'Qty', widthRatio: 0.08, isNumeric: true),
    InvoiceColumn(
      id: 'price',
      label: 'Price',
      widthRatio: 0.12,
      isCurrency: true,
    ),
    InvoiceColumn(
      id: 'discount',
      label: 'Discount',
      widthRatio: 0.10,
      isCurrency: true,
    ),
    InvoiceColumn(
      id: 'total',
      label: 'Total',
      widthRatio: 0.15,
      isCurrency: true,
    ),
  ];

  @override
  String get headerText => 'FASHION INVOICE';

  @override
  String get footerText =>
      'Exchange valid within 7 days with tags intact. No refunds.';

  @override
  Map<String, dynamic> formatItem(BillItem item, int index) {
    return {
      'sno': '${index + 1}',
      'item': item.productName,
      'size': item.size ?? '-',
      'color': item.color ?? '-',
      'qty': item.qty.toStringAsFixed(0),
      'price': '₹${item.price.toStringAsFixed(2)}',
      'discount': '₹${item.discount.toStringAsFixed(2)}',
      'total': '₹${item.total.toStringAsFixed(2)}',
    };
  }

  @override
  Map<String, String> getHeaderFields(Bill bill) => {};

  @override
  List<Map<String, String>> getSummaryRows(Bill bill) => [];
}

// ============================================================================
// HARDWARE STORE INVOICE TEMPLATE
// ============================================================================
class HardwareInvoiceTemplate implements InvoiceTemplate {
  @override
  List<InvoiceColumn> get columns => const [
    InvoiceColumn(id: 'sno', label: 'S.No', widthRatio: 0.05),
    InvoiceColumn(id: 'item', label: 'Item', widthRatio: 0.25),
    InvoiceColumn(id: 'qty', label: 'Qty', widthRatio: 0.10, isNumeric: true),
    InvoiceColumn(id: 'unit', label: 'Unit', widthRatio: 0.08),
    InvoiceColumn(
      id: 'rate',
      label: 'Rate',
      widthRatio: 0.12,
      isCurrency: true,
    ),
    InvoiceColumn(id: 'gst', label: 'GST%', widthRatio: 0.08),
    InvoiceColumn(
      id: 'total',
      label: 'Total',
      widthRatio: 0.15,
      isCurrency: true,
    ),
  ];

  @override
  String get headerText => 'HARDWARE INVOICE';

  @override
  String get footerText => 'Goods once sold will not be taken back.';

  @override
  Map<String, dynamic> formatItem(BillItem item, int index) {
    return {
      'sno': '${index + 1}',
      'item': item.productName,
      'qty': item.qty.toStringAsFixed(2),
      'unit': item.unit.isNotEmpty ? item.unit : 'Pc',
      'rate': '₹${item.price.toStringAsFixed(2)}',
      'gst': '${item.gstRate.toStringAsFixed(1)}%',
      'total': '₹${item.total.toStringAsFixed(2)}',
    };
  }

  @override
  Map<String, String> getHeaderFields(Bill bill) => {};

  @override
  List<Map<String, String>> getSummaryRows(Bill bill) => [];
}

// ============================================================================
// GENERAL INVOICE TEMPLATE (DEFAULT)
// ============================================================================
class GeneralInvoiceTemplate implements InvoiceTemplate {
  @override
  List<InvoiceColumn> get columns => const [
    InvoiceColumn(id: 'sno', label: 'S.No', widthRatio: 0.05),
    InvoiceColumn(id: 'item', label: 'Item', widthRatio: 0.30),
    InvoiceColumn(id: 'qty', label: 'Qty', widthRatio: 0.12, isNumeric: true),
    InvoiceColumn(
      id: 'rate',
      label: 'Rate',
      widthRatio: 0.18,
      isCurrency: true,
    ),
    InvoiceColumn(
      id: 'total',
      label: 'Total',
      widthRatio: 0.25,
      isCurrency: true,
    ),
  ];

  @override
  String get headerText => 'INVOICE';

  @override
  String get footerText => 'Thank you for your business!';

  @override
  Map<String, dynamic> formatItem(BillItem item, int index) {
    return {
      'sno': '${index + 1}',
      'item': item.productName,
      'qty': item.qty.toStringAsFixed(2),
      'rate': '₹${item.price.toStringAsFixed(2)}',
      'total': '₹${item.total.toStringAsFixed(2)}',
    };
  }

  @override
  Map<String, String> getHeaderFields(Bill bill) => {};

  @override
  List<Map<String, String>> getSummaryRows(Bill bill) => [];
}
