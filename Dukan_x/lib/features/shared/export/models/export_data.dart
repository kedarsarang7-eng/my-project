import 'package:equatable/equatable.dart';

/// The Universal Data Structure for all exports.
/// This object contains PRE-CALCULATED, NORMALIZED data.
/// Adapters should NOT perform business logic, only formatting.
class ExportData extends Equatable {
  final ExportCompany company;
  final ExportDocument document;
  final ExportParty party;
  final List<ExportItem> items;
  final List<ExportTax> taxSummary;
  final ExportTotals totals;
  final ExportPayment? payment;
  final Map<String, dynamic> metadata;
  final String? termsAndConditions;
  final String? notes;

  const ExportData({
    required this.company,
    required this.document,
    required this.party,
    required this.items,
    required this.taxSummary,
    required this.totals,
    this.payment,
    this.metadata = const {},
    this.termsAndConditions,
    this.notes,
  });

  @override
  List<Object?> get props => [
    company,
    document,
    party,
    items,
    taxSummary,
    totals,
    payment,
    metadata,
    termsAndConditions,
    notes,
  ];
}

class ExportCompany extends Equatable {
  final String name;
  final String address;
  final String? phone;
  final String? email;
  final String? gstin;
  final String? logoPath;
  final String? signaturePath;

  const ExportCompany({
    required this.name,
    required this.address,
    this.phone,
    this.email,
    this.gstin,
    this.logoPath,
    this.signaturePath,
  });

  @override
  List<Object?> get props => [
    name,
    address,
    phone,
    email,
    gstin,
    logoPath,
    signaturePath,
  ];
}

class ExportDocument extends Equatable {
  final String id;
  final String number; // Invoice Number
  final DateTime date;
  final DateTime? dueDate;
  final String type; // TAX_INVOICE, QUOTATION, RECEIPT, etc.
  final String status; // PAID, PENDING

  const ExportDocument({
    required this.id,
    required this.number,
    required this.date,
    this.dueDate,
    required this.type,
    required this.status,
  });

  @override
  List<Object?> get props => [id, number, date, dueDate, type, status];
}

class ExportParty extends Equatable {
  final String name;
  final String? address;
  final String? phone;
  final String? email;
  final String? gstin;
  final String? pan;

  const ExportParty({
    required this.name,
    this.address,
    this.phone,
    this.email,
    this.gstin,
    this.pan,
  });

  @override
  List<Object?> get props => [name, address, phone, email, gstin, pan];
}

class ExportItem extends Equatable {
  final int index;
  final String name;
  final String? description;
  final String? hsn;
  final double quantity;
  final String unit;
  final double unitPrice; // Price BEFORE tax if flexible, or whatever base
  final double taxRate; // GST %
  final double taxAmount;
  final double discountAmount;
  final double totalAmount; // Final line total

  const ExportItem({
    required this.index,
    required this.name,
    this.description,
    this.hsn,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.taxRate,
    required this.taxAmount,
    required this.discountAmount,
    required this.totalAmount,
  });

  @override
  List<Object?> get props => [
    index,
    name,
    description,
    hsn,
    quantity,
    unit,
    unitPrice,
    taxRate,
    taxAmount,
    discountAmount,
    totalAmount,
  ];
}

class ExportTax extends Equatable {
  final String taxName; // "CGST 9%", "IGST 18%"
  final double rate;
  final double taxableValue;
  final double taxAmount;

  const ExportTax({
    required this.taxName,
    required this.rate,
    required this.taxableValue,
    required this.taxAmount,
  });

  @override
  List<Object?> get props => [taxName, rate, taxableValue, taxAmount];
}

class ExportTotals extends Equatable {
  final double subtotal; // Taxable Value
  final double totalTax; // Total GST
  final double totalDiscount;
  final double grandTotal; // Final Payable
  final double roundOff; // +0.5 or -0.3

  const ExportTotals({
    required this.subtotal,
    required this.totalTax,
    required this.totalDiscount,
    required this.grandTotal,
    this.roundOff = 0.0,
  });

  @override
  List<Object?> get props => [
    subtotal,
    totalTax,
    totalDiscount,
    grandTotal,
    roundOff,
  ];
}

class ExportPayment extends Equatable {
  final double paidAmount;
  final double dueAmount;
  final String mode; // Cash, Online
  final String? transactionId;
  final String? bankName;

  const ExportPayment({
    required this.paidAmount,
    required this.dueAmount,
    required this.mode,
    this.transactionId,
    this.bankName,
  });

  @override
  List<Object?> get props => [
    paidAmount,
    dueAmount,
    mode,
    transactionId,
    bankName,
  ];
}
