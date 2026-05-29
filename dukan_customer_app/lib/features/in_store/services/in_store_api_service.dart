// ============================================================================
// In-Store Self Scan & Checkout — API Service
// ============================================================================

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../config/app_config.dart';
import '../../../core/di/providers.dart';
import '../models/in_store_models.dart';

final inStoreApiServiceProvider = Provider<InStoreApiService>((ref) {
  return InStoreApiService(ref);
});

class InStoreApiService {
  final Ref _ref;
  final String _baseUrl;

  InStoreApiService(this._ref)
      : _baseUrl = AppConfig.apiBaseUrlStatic;

  String get _token =>
      _ref.read(customerSessionProvider).valueOrNull?.accessToken ?? '';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      };

  String _url(String path) => '$_baseUrl/v1$path';

  // ── Session ───────────────────────────────────────────────────────────────

  Future<InStoreSession> startSession({
    required String storeId,
    required String tenantId,
  }) async {
    final res = await http.post(
      Uri.parse(_url('/in-store/session/start')),
      headers: _headers,
      body: jsonEncode({'storeId': storeId, 'tenantId': tenantId}),
    );
    _assertSuccess(res);
    final data = _data(res);
    return InStoreSession(
      sessionId: data['sessionId'] as String,
      storeId: data['storeId'] as String,
      storeName: data['storeName'] as String? ?? '',
      storeAddress: data['storeAddress'] as String? ?? '',
      status: data['status'] as String? ?? 'ACTIVE',
      startedAt: DateTime.now(),
    );
  }

  Future<InStoreSession> getSession(String sessionId) async {
    final res = await http.get(
      Uri.parse(_url('/in-store/session/$sessionId')),
      headers: _headers,
    );
    _assertSuccess(res);
    final data = _data(res);
    return InStoreSession.fromJson({
      ...data['session'] as Map<String, dynamic>,
      'summary': data['summary'],
      'storeName': '',
    });
  }

  Future<CartSummary> updateCart(
    String sessionId,
    List<CartItem> cartItems,
  ) async {
    final res = await http.patch(
      Uri.parse(_url('/in-store/session/$sessionId/cart')),
      headers: _headers,
      body: jsonEncode({
        'cartItems': cartItems.map((i) => i.toJson()).toList(),
      }),
    );
    _assertSuccess(res);
    final data = _data(res);
    return CartSummary.fromJson(data);
  }

  Future<void> abandonSession(String sessionId) async {
    final res = await http.post(
      Uri.parse(_url('/in-store/session/$sessionId/abandon')),
      headers: _headers,
    );
    _assertSuccess(res);
  }

  // ── Barcode Product Lookup ────────────────────────────────────────────────

  Future<ScannedProduct> getProductByBarcode(
    String barcode,
    String storeId,
  ) async {
    final uri = Uri.parse(_url('/in-store/products/barcode/$barcode'))
        .replace(queryParameters: {'storeId': storeId});
    final res = await http.get(uri, headers: _headers);
    _assertSuccess(res);
    return ScannedProduct.fromJson(_data(res));
  }

  // ── Checkout ──────────────────────────────────────────────────────────────

  Future<CheckoutResponse> checkout(String sessionId) async {
    final res = await http.post(
      Uri.parse(_url('/in-store/session/$sessionId/checkout')),
      headers: _headers,
    );
    _assertSuccess(res);
    return CheckoutResponse.fromJson(_data(res));
  }

  // ── Exit QR Refresh ───────────────────────────────────────────────────────

  Future<String> refreshExitQR(String sessionId) async {
    final res = await http.post(
      Uri.parse(_url('/in-store/session/$sessionId/exit-qr/refresh')),
      headers: _headers,
    );
    _assertSuccess(res);
    return _data(res)['exitQR'] as String;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Map<String, dynamic> _data(http.Response res) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>;
  }

  void _assertSuccess(http.Response res) {
    if (res.statusCode >= 400) {
      Map<String, dynamic>? body;
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}
      final err = body?['error'] as Map<String, dynamic>?;
      throw InStoreApiException(
        code: err?['code'] as String? ?? 'HTTP_${res.statusCode}',
        message: err?['message'] as String? ??
            'Request failed with status ${res.statusCode}',
        statusCode: res.statusCode,
        details: err?['details'],
      );
    }
  }
}

class InStoreApiException implements Exception {
  final String code;
  final String message;
  final int statusCode;
  final dynamic details;

  const InStoreApiException({
    required this.code,
    required this.message,
    required this.statusCode,
    this.details,
  });

  bool get isNotFound => statusCode == 404;
  bool get isOutOfStock => code == 'BAD_REQUEST' &&
      message.toLowerCase().contains('stock');

  @override
  String toString() => 'InStoreApiException[$code]: $message';
}
