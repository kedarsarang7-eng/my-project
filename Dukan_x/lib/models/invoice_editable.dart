import 'package:intl/intl.dart';

/// Editable Invoice Item Model
class EditableInvoiceItem {
  String id;
  String itemName;
  double? manQuantity; // optional man quantity
  double kiloWeight;
  double ratePerKilo;
  double? manRate; // optional rate per man
  double totalAmount;

  EditableInvoiceItem({
    required this.id,
    required this.itemName,
    this.manQuantity,
    required this.kiloWeight,
    required this.ratePerKilo,
    this.manRate,
    required this.totalAmount,
  });

  double calculateTotal() {
    double total = 0;

    // Calculate based on kilo weight
    total += kiloWeight * ratePerKilo;

    // Add man quantity if applicable
    if (manQuantity != null && manQuantity! > 0 && manRate != null) {
      total += manQuantity! * manRate!;
    }

    return total;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'itemName': itemName,
    'manQuantity': manQuantity,
    'kiloWeight': kiloWeight,
    'ratePerKilo': ratePerKilo,
    'manRate': manRate,
    'totalAmount': totalAmount,
  };

  factory EditableInvoiceItem.fromMap(Map<String, dynamic> map) =>
      EditableInvoiceItem(
        id: map['id'] ?? '',
        itemName: map['itemName'] ?? '',
        manQuantity: map['manQuantity'],
        kiloWeight: (map['kiloWeight'] ?? 0).toDouble(),
        ratePerKilo: (map['ratePerKilo'] ?? 0).toDouble(),
        manRate: map['manRate'],
        totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      );
}

/// Editable Charges Model
class InvoiceCharges {
  double okshanKharcha; // à¤‘à¤•à¥à¤¶à¤¨ / à¤…à¤¡à¥à¤¡à¤¾ à¤–à¤°à¥à¤š
  double nagarpalika; // à¤¨à¤—à¤°à¤ªà¤¾à¤²à¤¿à¤•à¤¾
  double commission; // à¤•à¤®à¤¿à¤¶à¤¨
  double hamali; // à¤¹à¤®à¤¾à¤²à¥€
  double vetChithi; // à¤µ. à¤šà¤¿à¤ à¥à¤ à¥€
  double gadiKhada; // à¤—à¤¾à¤¡à¥€ à¤­à¤¾à¤¡à¤¾

  InvoiceCharges({
    this.okshanKharcha = 0,
    this.nagarpalika = 0,
    this.commission = 0,
    this.hamali = 0,
    this.vetChithi = 0,
    this.gadiKhada = 0,
  });

  double getTotalCharges() {
    return okshanKharcha +
        nagarpalika +
        commission +
        hamali +
        vetChithi +
        gadiKhada;
  }

  Map<String, dynamic> toMap() => {
    'okshanKharcha': okshanKharcha,
    'nagarpalika': nagarpalika,
    'commission': commission,
    'hamali': hamali,
    'vetChithi': vetChithi,
    'gadiKhada': gadiKhada,
  };

  factory InvoiceCharges.fromMap(Map<String, dynamic> map) => InvoiceCharges(
    okshanKharcha: (map['okshanKharcha'] ?? 0).toDouble(),
    nagarpalika: (map['nagarpalika'] ?? 0).toDouble(),
    commission: (map['commission'] ?? 0).toDouble(),
    hamali: (map['hamali'] ?? 0).toDouble(),
    vetChithi: (map['vetChithi'] ?? 0).toDouble(),
    gadiKhada: (map['gadiKhada'] ?? 0).toDouble(),
  );
}

/// Enhanced Editable Invoice Model
class EditableInvoice {
  String id;

  // Owner Details
  String ownerName;
  String shopName;
  String ownerPhone;
  String ownerAddress;
  String? gstNumber;
  String? logoUrl;

  // Customer Details
  String customerName;
  String customerVillage;
  DateTime invoiceDate;

  // Items & Charges
  List<EditableInvoiceItem> items;
  InvoiceCharges charges;

  // Signatures & Stamp
  String? ownerSignatureUrl;
  String? stampUrl;

  // Additional
  String notes;
  bool paid;
  DateTime? paidAt;
  DateTime createdAt;
  DateTime updatedAt;

  EditableInvoice({
    required this.id,
    required this.ownerName,
    required this.shopName,
    required this.ownerPhone,
    required this.ownerAddress,
    this.gstNumber,
    this.logoUrl,
    required this.customerName,
    required this.customerVillage,
    required this.invoiceDate,
    required this.items,
    required this.charges,
    this.ownerSignatureUrl,
    this.stampUrl,
    this.notes = '',
    this.paid = false,
    this.paidAt,
    required this.createdAt,
    required this.updatedAt,
  });

  double getItemsTotal() {
    return items.fold(0, (sum, item) => sum + item.totalAmount);
  }

  double getChargesTotal() {
    return charges.getTotalCharges();
  }

  double getFinalTotal() {
    return getItemsTotal() + getChargesTotal();
  }

  String get invoiceNumber {
    return 'INV-${invoiceDate.year}-${invoiceDate.month.toString().padLeft(2, '0')}-${id.substring(0, 6).toUpperCase()}';
  }

  String get formattedDate => DateFormat('dd/MM/yyyy').format(invoiceDate);
  String get formattedTime => DateFormat('hh:mm a').format(createdAt);

  Map<String, dynamic> toMap() => {
    'id': id,
    'ownerName': ownerName,
    'shopName': shopName,
    'ownerPhone': ownerPhone,
    'ownerAddress': ownerAddress,
    'gstNumber': gstNumber,
    'logoUrl': logoUrl,
    'customerName': customerName,
    'customerVillage': customerVillage,
    'invoiceDate': invoiceDate,
    'items': items.map((i) => i.toMap()).toList(),
    'charges': charges.toMap(),
    'ownerSignatureUrl': ownerSignatureUrl,
    'stampUrl': stampUrl,
    'notes': notes,
    'paid': paid,
    'paidAt': paidAt,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  factory EditableInvoice.fromMap(Map<String, dynamic> map) => EditableInvoice(
    id: map['id'] ?? '',
    ownerName: map['ownerName'] ?? '',
    shopName: map['shopName'] ?? '',
    ownerPhone: map['ownerPhone'] ?? '',
    ownerAddress: map['ownerAddress'] ?? '',
    gstNumber: map['gstNumber'],
    logoUrl: map['logoUrl'],
    customerName: map['customerName'] ?? '',
    customerVillage: map['customerVillage'] ?? '',
    invoiceDate: (map['invoiceDate'] as dynamic).toDate() ?? DateTime.now(),
    items:
        (map['items'] as List?)
            ?.map((i) => EditableInvoiceItem.fromMap(i as Map<String, dynamic>))
            .toList() ??
        [],
    charges: InvoiceCharges.fromMap(
      (map['charges'] as Map<String, dynamic>?) ?? {},
    ),
    ownerSignatureUrl: map['ownerSignatureUrl'],
    stampUrl: map['stampUrl'],
    notes: map['notes'] ?? '',
    paid: map['paid'] ?? false,
    paidAt: map['paidAt'],
    createdAt: (map['createdAt'] as dynamic).toDate() ?? DateTime.now(),
    updatedAt: (map['updatedAt'] as dynamic).toDate() ?? DateTime.now(),
  );

  /// Create empty invoice with default values
  factory EditableInvoice.empty({
    required String ownerName,
    required String shopName,
    required String ownerPhone,
    required String ownerAddress,
  }) {
    return EditableInvoice(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ownerName: ownerName,
      shopName: shopName,
      ownerPhone: ownerPhone,
      ownerAddress: ownerAddress,
      customerName: '',
      customerVillage: '',
      invoiceDate: DateTime.now(),
      items: [],
      charges: InvoiceCharges(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
