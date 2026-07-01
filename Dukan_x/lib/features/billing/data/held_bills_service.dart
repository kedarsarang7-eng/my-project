// ============================================================================
// Held Bills Service — Sprint 1: Cashier Safety
// ============================================================================
// Thin HTTP client around the /invoices/hold + /invoices/held/* endpoints.
//
// A held (parked) bill is a transient cart snapshot the cashier saved so the
// counter is freed for the next customer. It does NOT impact stock, invoice
// numbering, credit, or accounting. On resume the client re-issues a normal
// POST /invoices using the snapshot payload.
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/di/service_locator.dart';

/// One line item inside a held cart. Mirrors the backend `holdBillSchema`.
@immutable
class HeldBillLineItem {
  final String productId;
  final String name;
  final double quantity;
  final String unit;
  final int unitPrice;
  final int discountCents;
  final int taxCents;
  final String? batchNumber;
  final String? expiryDate;
  final Map<String, dynamic> attributes;

  const HeldBillLineItem({
    required this.productId,
    required this.name,
    required this.quantity,
    this.unit = 'pcs',
    required this.unitPrice,
    this.discountCents = 0,
    this.taxCents = 0,
    this.batchNumber,
    this.expiryDate,
    this.attributes = const <String, dynamic>{},
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'productId': productId,
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'unitPrice': unitPrice,
    'discountCents': discountCents,
    'taxCents': taxCents,
    if (batchNumber != null) 'batchNumber': batchNumber,
    if (expiryDate != null) 'expiryDate': expiryDate,
    'attributes': attributes,
  };

  factory HeldBillLineItem.fromJson(Map<String, dynamic> json) {
    return HeldBillLineItem(
      productId: json['productId'] as String,
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: (json['unit'] as String?) ?? 'pcs',
      unitPrice: (json['unitPrice'] as num).toInt(),
      discountCents: (json['discountCents'] as num?)?.toInt() ?? 0,
      taxCents: (json['taxCents'] as num?)?.toInt() ?? 0,
      batchNumber: json['batchNumber'] as String?,
      expiryDate: json['expiryDate'] as String?,
      attributes: (json['attributes'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
  }
}

/// A held bill record returned by the backend.
@immutable
class HeldBill {
  final String id;
  final String label;
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  final List<HeldBillLineItem> items;
  final int discountCents;
  final int subtotal;
  final int totalCents;
  final int itemCount;
  final String? notes;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final String createdBy;

  const HeldBill({
    required this.id,
    required this.label,
    this.customerId,
    this.customerName,
    this.customerPhone,
    required this.items,
    required this.discountCents,
    required this.subtotal,
    required this.totalCents,
    required this.itemCount,
    this.notes,
    this.metadata = const <String, dynamic>{},
    required this.createdAt,
    required this.createdBy,
  });

  factory HeldBill.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const <dynamic>[];
    return HeldBill(
      id: json['id'] as String,
      label: (json['label'] as String?) ?? 'Held bill',
      customerId: json['customerId'] as String?,
      customerName: json['customerName'] as String?,
      customerPhone: json['customerPhone'] as String?,
      items: rawItems
          .whereType<Map>()
          .map((dynamic e) =>
              HeldBillLineItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList(growable: false),
      discountCents: (json['discountCents'] as num?)?.toInt() ?? 0,
      subtotal: (json['subtotal'] as num?)?.toInt() ?? 0,
      totalCents: (json['totalCents'] as num?)?.toInt() ?? 0,
      itemCount: (json['itemCount'] as num?)?.toInt() ?? rawItems.length,
      notes: json['notes'] as String?,
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.now(),
      createdBy: (json['createdBy'] as String?) ?? '',
    );
  }
}

/// Thrown when the backend rejects a hold/resume/discard call.
class HeldBillException implements Exception {
  final int statusCode;
  final String message;
  const HeldBillException(this.statusCode, this.message);

  @override
  String toString() => 'HeldBillException($statusCode): $message';
}

/// Service for parking and resuming carts.
class HeldBillsService {
  final ApiClient _api;

  HeldBillsService({ApiClient? apiClient})
    : _api = apiClient ?? sl<ApiClient>();

  /// POST /invoices/hold — save the current cart as a held bill.
  Future<HeldBill> hold({
    required String label,
    required List<HeldBillLineItem> items,
    String? customerId,
    String? customerName,
    String? customerPhone,
    int discountCents = 0,
    String? notes,
    Map<String, dynamic>? metadata,
  }) async {
    if (items.isEmpty) {
      throw const HeldBillException(400, 'Cannot hold an empty cart');
    }

    final response = await _api.post(
      '/invoices/hold',
      body: <String, dynamic>{
        'label': label,
        'customerId': ?customerId,
        'customerName': ?customerName,
        'customerPhone': ?customerPhone,
        'items': items.map((HeldBillLineItem e) => e.toJson()).toList(),
        'discountCents': discountCents,
        'notes': ?notes,
        'metadata': metadata ?? <String, dynamic>{},
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw HeldBillException(
        response.statusCode,
        response.error ?? 'Failed to hold bill',
      );
    }

    final payload = _extractData(response.data!);
    return HeldBill.fromJson(payload);
  }

  /// GET /invoices/held — list held bills (most recent first).
  Future<List<HeldBill>> list({int limit = 20}) async {
    final response = await _api.get(
      '/invoices/held',
      queryParams: <String, String>{'limit': '$limit'},
    );

    if (!response.isSuccess || response.data == null) {
      throw HeldBillException(
        response.statusCode,
        response.error ?? 'Failed to list held bills',
      );
    }

    final payload = _extractData(response.data!);
    final rawItems = payload['items'] as List? ?? const <dynamic>[];
    return rawItems
        .whereType<Map>()
        .map((dynamic e) => HeldBill.fromJson((e as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// POST /invoices/held/{id}/resume — atomically returns the cart and
  /// deletes the hold so it cannot be checked out twice.
  Future<HeldBill> resume(String heldBillId) async {
    final response =
        await _api.post('/invoices/held/$heldBillId/resume', body: <String, dynamic>{});

    if (!response.isSuccess || response.data == null) {
      throw HeldBillException(
        response.statusCode,
        response.error ?? 'Failed to resume held bill',
      );
    }

    return HeldBill.fromJson(_extractData(response.data!));
  }

  /// DELETE /invoices/held/{id} — discard the hold without resuming.
  Future<void> discard(String heldBillId) async {
    final response = await _api.delete('/invoices/held/$heldBillId');
    if (!response.isSuccess) {
      throw HeldBillException(
        response.statusCode,
        response.error ?? 'Failed to discard held bill',
      );
    }
  }

  // The backend wraps every payload in `{ status, code, data, ... }`. Extract
  // the `data` envelope but stay tolerant of legacy bare payloads.
  Map<String, dynamic> _extractData(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is Map) return data.cast<String, dynamic>();
    return body;
  }
}
