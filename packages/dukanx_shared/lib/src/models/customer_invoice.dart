import 'package:equatable/equatable.dart';

enum InvoiceStatus { paid, unpaid, partial, overdue, cancelled }

class CustomerInvoiceItem extends Equatable {
  final String id;
  final String name;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double discountAmount;
  final double taxPercent;
  final double taxAmount;
  final double total;

  const CustomerInvoiceItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.discountAmount,
    required this.taxPercent,
    required this.taxAmount,
    required this.total,
  });

  factory CustomerInvoiceItem.fromJson(Map<String, dynamic> json) {
    return CustomerInvoiceItem(
      id: json['id'] as String,
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String? ?? 'pcs',
      unitPrice: (json['unitPrice'] as num).toDouble(),
      discountAmount: (json['discountAmount'] as num? ?? 0).toDouble(),
      taxPercent: (json['taxPercent'] as num? ?? 0).toDouble(),
      taxAmount: (json['taxAmount'] as num? ?? 0).toDouble(),
      total: (json['total'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'unitPrice': unitPrice,
        'discountAmount': discountAmount,
        'taxPercent': taxPercent,
        'taxAmount': taxAmount,
        'total': total,
      };

  @override
  List<Object?> get props =>
      [id, name, quantity, unit, unitPrice, discountAmount, taxPercent, taxAmount, total];
}

class CustomerInvoice extends Equatable {
  final String id;
  final String invoiceNumber;
  final String tenantId;
  final String customerId;
  final String vendorId;
  final String vendorName;
  final String? vendorPhone;
  final String? vendorBusinessName;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final InvoiceStatus status;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double totalAmount;
  final double paidAmount;
  final double balanceDue;
  final String? notes;
  final String? pdfUrl;
  final List<CustomerInvoiceItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomerInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.tenantId,
    required this.customerId,
    required this.vendorId,
    required this.vendorName,
    this.vendorPhone,
    this.vendorBusinessName,
    required this.invoiceDate,
    this.dueDate,
    required this.status,
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.totalAmount,
    required this.paidAmount,
    required this.balanceDue,
    this.notes,
    this.pdfUrl,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomerInvoice.fromJson(Map<String, dynamic> json) {
    return CustomerInvoice(
      id: json['id'] as String,
      invoiceNumber: json['invoiceNumber'] as String,
      tenantId: json['tenantId'] as String,
      customerId: json['customerId'] as String,
      vendorId: json['vendorId'] as String,
      vendorName: json['vendorName'] as String,
      vendorPhone: json['vendorPhone'] as String?,
      vendorBusinessName: json['vendorBusinessName'] as String?,
      invoiceDate: DateTime.parse(json['invoiceDate'] as String),
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate'] as String) : null,
      status: _statusFromString(json['status'] as String),
      subtotal: (json['subtotal'] as num).toDouble(),
      discountAmount: (json['discountAmount'] as num? ?? 0).toDouble(),
      taxAmount: (json['taxAmount'] as num? ?? 0).toDouble(),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      paidAmount: (json['paidAmount'] as num? ?? 0).toDouble(),
      balanceDue: (json['balanceDue'] as num? ?? 0).toDouble(),
      notes: json['notes'] as String?,
      pdfUrl: json['pdfUrl'] as String?,
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => CustomerInvoiceItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  static InvoiceStatus _statusFromString(String s) {
    switch (s.toLowerCase()) {
      case 'paid':
        return InvoiceStatus.paid;
      case 'partial':
        return InvoiceStatus.partial;
      case 'overdue':
        return InvoiceStatus.overdue;
      case 'cancelled':
        return InvoiceStatus.cancelled;
      default:
        return InvoiceStatus.unpaid;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'invoiceNumber': invoiceNumber,
        'tenantId': tenantId,
        'customerId': customerId,
        'vendorId': vendorId,
        'vendorName': vendorName,
        'vendorPhone': vendorPhone,
        'vendorBusinessName': vendorBusinessName,
        'invoiceDate': invoiceDate.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'status': status.name,
        'subtotal': subtotal,
        'discountAmount': discountAmount,
        'taxAmount': taxAmount,
        'totalAmount': totalAmount,
        'paidAmount': paidAmount,
        'balanceDue': balanceDue,
        'notes': notes,
        'pdfUrl': pdfUrl,
        'items': items.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, invoiceNumber, tenantId, customerId, vendorId, status, totalAmount];
}
