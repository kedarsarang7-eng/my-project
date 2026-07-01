// Credit Notes Feature - Models
//
// Implements GST-compliant Credit Notes linked to original invoices
// with support for partial and full returns, GST reversal, and stock re-entry.
//
// Author: DukanX Team
// Created: 2026-01-17

import 'dart:convert';

/// Credit Note Type
enum CreditNoteType {
  fullReturn, // Complete invoice returned
  partialReturn, // Some items/quantities returned
  priceAdjustment, // Price correction without physical return
}

/// Credit Note Status
enum CreditNoteStatus {
  draft, // Being prepared
  confirmed, // Finalized
  cancelled, // Voided
  adjusted, // Adjusted against new invoice
}

/// GST Reversal Details
class GstReversal {
  final double originalCgst;
  final double originalSgst;
  final double originalIgst;
  final double reversedCgst;
  final double reversedSgst;
  final double reversedIgst;
  final String supplyType; // INTRA / INTER

  GstReversal({
    required this.originalCgst,
    required this.originalSgst,
    required this.originalIgst,
    required this.reversedCgst,
    required this.reversedSgst,
    required this.reversedIgst,
    required this.supplyType,
  });

  double get totalReversedGst => reversedCgst + reversedSgst + reversedIgst;

  factory GstReversal.fromMap(Map<String, dynamic> map) {
    return GstReversal(
      originalCgst: (map['originalCgst'] ?? 0).toDouble(),
      originalSgst: (map['originalSgst'] ?? 0).toDouble(),
      originalIgst: (map['originalIgst'] ?? 0).toDouble(),
      reversedCgst: (map['reversedCgst'] ?? 0).toDouble(),
      reversedSgst: (map['reversedSgst'] ?? 0).toDouble(),
      reversedIgst: (map['reversedIgst'] ?? 0).toDouble(),
      supplyType: map['supplyType'] ?? 'INTRA',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'originalCgst': originalCgst,
      'originalSgst': originalSgst,
      'originalIgst': originalIgst,
      'reversedCgst': reversedCgst,
      'reversedSgst': reversedSgst,
      'reversedIgst': reversedIgst,
      'supplyType': supplyType,
    };
  }
}

/// Credit Note Item
class CreditNoteItem {
  final String id;
  final String productId;
  final String productName;
  final String? hsnCode;
  final double originalQuantity;
  final double returnedQuantity;
  final double unitPrice;
  final double discountPercent;
  final double gstRate;
  final double taxableValue;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double totalAmount;
  final String unit;
  final bool stockReturned; // Whether stock was re-added to inventory

  CreditNoteItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.hsnCode,
    required this.originalQuantity,
    required this.returnedQuantity,
    required this.unitPrice,
    this.discountPercent = 0,
    required this.gstRate,
    required this.taxableValue,
    this.cgstAmount = 0,
    this.sgstAmount = 0,
    this.igstAmount = 0,
    required this.totalAmount,
    this.unit = 'pcs',
    this.stockReturned = false,
  });

  factory CreditNoteItem.fromMap(Map<String, dynamic> map) {
    return CreditNoteItem(
      id: map['id'] ?? '',
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      hsnCode: map['hsnCode'],
      originalQuantity: (map['originalQuantity'] ?? 0).toDouble(),
      returnedQuantity: (map['returnedQuantity'] ?? 0).toDouble(),
      unitPrice: (map['unitPrice'] ?? 0).toDouble(),
      discountPercent: (map['discountPercent'] ?? 0).toDouble(),
      gstRate: (map['gstRate'] ?? 0).toDouble(),
      taxableValue: (map['taxableValue'] ?? 0).toDouble(),
      cgstAmount: (map['cgstAmount'] ?? 0).toDouble(),
      sgstAmount: (map['sgstAmount'] ?? 0).toDouble(),
      igstAmount: (map['igstAmount'] ?? 0).toDouble(),
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      unit: map['unit'] ?? 'pcs',
      stockReturned: map['stockReturned'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'hsnCode': hsnCode,
      'originalQuantity': originalQuantity,
      'returnedQuantity': returnedQuantity,
      'unitPrice': unitPrice,
      'discountPercent': discountPercent,
      'gstRate': gstRate,
      'taxableValue': taxableValue,
      'cgstAmount': cgstAmount,
      'sgstAmount': sgstAmount,
      'igstAmount': igstAmount,
      'totalAmount': totalAmount,
      'unit': unit,
      'stockReturned': stockReturned,
    };
  }

  CreditNoteItem copyWith({bool? stockReturned}) {
    return CreditNoteItem(
      id: id,
      productId: productId,
      productName: productName,
      hsnCode: hsnCode,
      originalQuantity: originalQuantity,
      returnedQuantity: returnedQuantity,
      unitPrice: unitPrice,
      discountPercent: discountPercent,
      gstRate: gstRate,
      taxableValue: taxableValue,
      cgstAmount: cgstAmount,
      sgstAmount: sgstAmount,
      igstAmount: igstAmount,
      totalAmount: totalAmount,
      unit: unit,
      stockReturned: stockReturned ?? this.stockReturned,
    );
  }
}

/// Credit Note Model - GST Compliant
class CreditNote {
  final String id;
  final String userId;
  final String creditNoteNumber;

  // Original Invoice Reference
  final String originalBillId;
  final String originalBillNumber;
  final DateTime originalBillDate;

  // Customer Details
  final String customerId;
  final String customerName;
  final String? customerGstin;
  final String? customerPhone;
  final String? customerAddress;

  // Credit Note Details
  final CreditNoteType type;
  final CreditNoteStatus status;
  final List<CreditNoteItem> items;
  final String reason;

  // Amounts
  final double subtotal;
  final double totalTaxableValue;
  final double totalCgst;
  final double totalSgst;
  final double totalIgst;
  final double totalGst;
  final double grandTotal;

  // GST Compliance
  final GstReversal? gstReversal;
  final String? placeOfSupply;
  final bool isReverseCharge;

  // Stock & Ledger
  final bool stockReEntered;
  final bool ledgerAdjusted;
  final String? adjustedAgainstBillId;
  final double adjustedAmount;
  final double balanceAmount; // Remaining credit to customer

  // GSTR-1 Filing
  final bool includedInGstr1;
  final String? gstr1Period; // e.g., "012026" for Jan 2026

  // Audit
  final DateTime date;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final bool isSynced;
  final String? notes;

  CreditNote({
    required this.id,
    required this.userId,
    required this.creditNoteNumber,
    required this.originalBillId,
    required this.originalBillNumber,
    required this.originalBillDate,
    required this.customerId,
    required this.customerName,
    this.customerGstin,
    this.customerPhone,
    this.customerAddress,
    required this.type,
    required this.status,
    required this.items,
    required this.reason,
    required this.subtotal,
    required this.totalTaxableValue,
    required this.totalCgst,
    required this.totalSgst,
    required this.totalIgst,
    required this.totalGst,
    required this.grandTotal,
    this.gstReversal,
    this.placeOfSupply,
    this.isReverseCharge = false,
    this.stockReEntered = false,
    this.ledgerAdjusted = false,
    this.adjustedAgainstBillId,
    this.adjustedAmount = 0,
    this.balanceAmount = 0,
    this.includedInGstr1 = false,
    this.gstr1Period,
    required this.date,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.isSynced = false,
    this.notes,
  });

  factory CreditNote.fromMap(Map<String, dynamic> map, String id) {
    return CreditNote(
      id: id,
      userId: map['userId'] ?? '',
      creditNoteNumber: map['creditNoteNumber'] ?? '',
      originalBillId: map['originalBillId'] ?? '',
      originalBillNumber: map['originalBillNumber'] ?? '',
      originalBillDate: _parseDate(map['originalBillDate']),
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerGstin: map['customerGstin'],
      customerPhone: map['customerPhone'],
      customerAddress: map['customerAddress'],
      type: CreditNoteType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => CreditNoteType.partialReturn,
      ),
      status: CreditNoteStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => CreditNoteStatus.draft,
      ),
      items: _parseItems(map['items']),
      reason: map['reason'] ?? '',
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      totalTaxableValue: (map['totalTaxableValue'] ?? 0).toDouble(),
      totalCgst: (map['totalCgst'] ?? 0).toDouble(),
      totalSgst: (map['totalSgst'] ?? 0).toDouble(),
      totalIgst: (map['totalIgst'] ?? 0).toDouble(),
      totalGst: (map['totalGst'] ?? 0).toDouble(),
      grandTotal: (map['grandTotal'] ?? 0).toDouble(),
      gstReversal: map['gstReversal'] != null
          ? GstReversal.fromMap(
              map['gstReversal'] is String
                  ? jsonDecode(map['gstReversal'])
                  : map['gstReversal'],
            )
          : null,
      placeOfSupply: map['placeOfSupply'],
      isReverseCharge: map['isReverseCharge'] ?? false,
      stockReEntered: map['stockReEntered'] ?? false,
      ledgerAdjusted: map['ledgerAdjusted'] ?? false,
      adjustedAgainstBillId: map['adjustedAgainstBillId'],
      adjustedAmount: (map['adjustedAmount'] ?? 0).toDouble(),
      balanceAmount: (map['balanceAmount'] ?? 0).toDouble(),
      includedInGstr1: map['includedInGstr1'] ?? false,
      gstr1Period: map['gstr1Period'],
      date: _parseDate(map['date']),
      createdAt: _parseDate(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? _parseDate(map['updatedAt']) : null,
      createdBy: map['createdBy'],
      isSynced: map['isSynced'] ?? false,
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'creditNoteNumber': creditNoteNumber,
      'originalBillId': originalBillId,
      'originalBillNumber': originalBillNumber,
      'originalBillDate': originalBillDate.toIso8601String(),
      'customerId': customerId,
      'customerName': customerName,
      'customerGstin': customerGstin,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'type': type.name,
      'status': status.name,
      'items': items.map((e) => e.toMap()).toList(),
      'reason': reason,
      'subtotal': subtotal,
      'totalTaxableValue': totalTaxableValue,
      'totalCgst': totalCgst,
      'totalSgst': totalSgst,
      'totalIgst': totalIgst,
      'totalGst': totalGst,
      'grandTotal': grandTotal,
      'gstReversal': gstReversal?.toMap(),
      'placeOfSupply': placeOfSupply,
      'isReverseCharge': isReverseCharge,
      'stockReEntered': stockReEntered,
      'ledgerAdjusted': ledgerAdjusted,
      'adjustedAgainstBillId': adjustedAgainstBillId,
      'adjustedAmount': adjustedAmount,
      'balanceAmount': balanceAmount,
      'includedInGstr1': includedInGstr1,
      'gstr1Period': gstr1Period,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'createdBy': createdBy,
      'isSynced': isSynced,
      'notes': notes,
    };
  }

  CreditNote copyWith({
    CreditNoteStatus? status,
    bool? stockReEntered,
    bool? ledgerAdjusted,
    bool? includedInGstr1,
    String? gstr1Period,
    String? adjustedAgainstBillId,
    double? adjustedAmount,
    double? balanceAmount,
    bool? isSynced,
    DateTime? updatedAt,
  }) {
    return CreditNote(
      id: id,
      userId: userId,
      creditNoteNumber: creditNoteNumber,
      originalBillId: originalBillId,
      originalBillNumber: originalBillNumber,
      originalBillDate: originalBillDate,
      customerId: customerId,
      customerName: customerName,
      customerGstin: customerGstin,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      type: type,
      status: status ?? this.status,
      items: items,
      reason: reason,
      subtotal: subtotal,
      totalTaxableValue: totalTaxableValue,
      totalCgst: totalCgst,
      totalSgst: totalSgst,
      totalIgst: totalIgst,
      totalGst: totalGst,
      grandTotal: grandTotal,
      gstReversal: gstReversal,
      placeOfSupply: placeOfSupply,
      isReverseCharge: isReverseCharge,
      stockReEntered: stockReEntered ?? this.stockReEntered,
      ledgerAdjusted: ledgerAdjusted ?? this.ledgerAdjusted,
      adjustedAgainstBillId:
          adjustedAgainstBillId ?? this.adjustedAgainstBillId,
      adjustedAmount: adjustedAmount ?? this.adjustedAmount,
      balanceAmount: balanceAmount ?? this.balanceAmount,
      includedInGstr1: includedInGstr1 ?? this.includedInGstr1,
      gstr1Period: gstr1Period ?? this.gstr1Period,
      date: date,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      createdBy: createdBy,
      isSynced: isSynced ?? this.isSynced,
      notes: notes,
    );
  }

  /// Check if this is a B2B credit note (for GSTR-1 CDNR)
  bool get isB2B => customerGstin != null && customerGstin!.isNotEmpty;

  /// Get GSTR-1 section (CDNR for B2B, CDNUR for B2C)
  String get gstr1Section => isB2B ? 'CDNR' : 'CDNUR';
}

// Helper functions
DateTime _parseDate(dynamic date) {
  if (date == null) return DateTime.now();
  if (date is DateTime) return date;
  if (date.runtimeType.toString() == 'Timestamp') {
    return (date as dynamic).toDate();
  }
  if (date is String) return DateTime.parse(date);
  if (date is int) return DateTime.fromMillisecondsSinceEpoch(date);
  return DateTime.now();
}

List<CreditNoteItem> _parseItems(dynamic items) {
  if (items == null) return [];
  if (items is String) {
    try {
      final decoded = jsonDecode(items) as List;
      return decoded.map((e) => CreditNoteItem.fromMap(e)).toList();
    } catch (_) {
      return [];
    }
  }
  if (items is List) {
    return items.map((e) => CreditNoteItem.fromMap(e)).toList();
  }
  return [];
}
