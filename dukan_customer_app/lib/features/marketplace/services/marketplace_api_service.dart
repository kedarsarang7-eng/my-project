// ============================================================
// Dukan Customer App - Marketplace API Service
// Typed API client for marketplace endpoints
// ============================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/customer_session_manager.dart';
import '../../../config/app_config.dart';
import '../models/marketplace_models.dart';

final marketplaceApiServiceProvider = Provider<MarketplaceApiService>((ref) {
  final session = ref.watch(customerSessionProvider);
  final token = session.valueOrNull?.accessToken;
  return MarketplaceApiService(token);
});

class MarketplaceApiService {
  final String? _accessToken;
  final String _baseUrl;

  MarketplaceApiService(this._accessToken)
      : _baseUrl = AppConfig.apiBaseUrlStatic;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  String _url(String path) => '$_baseUrl/v1$path';

  // ---------- STORE ----------

  Future<StoreProfile> getStoreProfile(String businessId) async {
    final response = await http.get(
      Uri.parse(_url('/businesses/$businessId/profile')),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['data'];
      return StoreProfile.fromJson(data['business']);
    }
    throw _handleError(response);
  }

  Future<StoreConnection> connectToStore(
    String businessId, {
    required String customerName,
    required String customerPhone,
  }) async {
    final response = await http.post(
      Uri.parse(_url('/businesses/$businessId/connect')),
      headers: _headers,
      body: jsonEncode({
        'customerName': customerName,
        'customerPhone': customerPhone,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      jsonDecode(response.body); // validate response body
      return StoreConnection(connected: true, status: 'active');
    }
    throw _handleError(response);
  }

  Future<StoreConnection> getConnectionStatus(String businessId) async {
    final response = await http.get(
      Uri.parse(_url('/businesses/$businessId/connection-status')),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['data'];
      return StoreConnection.fromJson(data);
    }
    throw _handleError(response);
  }

  // ---------- PRODUCTS ----------

  Future<ProductSearchResult> getProducts(
    String businessId, {
    ProductSearchFilters? filters,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (filters?.category != null) {
      queryParams['category'] = filters!.category!;
    }
    if (filters?.brand != null) {
      queryParams['brand'] = filters!.brand!;
    }
    if (filters?.inStock == true) {
      queryParams['inStock'] = 'true';
    }
    if (filters?.sortBy != null) {
      queryParams['sortBy'] = filters!.sortBy!;
    }

    final uri = Uri.parse(_url('/businesses/$businessId/products'))
        .replace(queryParameters: queryParams);

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return ProductSearchResult.fromJson({
        'products': data['data']['products'],
        'filters': data['data']['filters'],
        ...data['meta'] ?? {},
      });
    }
    throw _handleError(response);
  }

  Future<ProductDetail> getProduct(String businessId, String productId) async {
    final response = await http.get(
      Uri.parse(_url('/businesses/$businessId/products/$productId')),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['data'];
      return ProductDetail.fromJson(data);
    }
    throw _handleError(response);
  }

  Future<ProductSearchResult> searchProducts(
    String businessId, {
    String? query,
    String? barcode,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (query != null) queryParams['q'] = query;
    if (barcode != null) queryParams['barcode'] = barcode;

    final uri = Uri.parse(_url('/businesses/$businessId/products/search'))
        .replace(queryParameters: queryParams);

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return ProductSearchResult.fromJson({
        'products': data['data']['products'],
        'query': data['data']['query'],
        ...data['meta'] ?? {},
      });
    }
    throw _handleError(response);
  }

  // ---------- CART ----------

  Future<Cart> getCart(String businessId) async {
    final response = await http.get(
      Uri.parse(_url('/businesses/$businessId/cart')),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['data'];
      return Cart.fromJson(data);
    }
    throw _handleError(response);
  }

  Future<Cart> addToCart(
    String businessId, {
    required String productId,
    required int quantity,
    String? prescriptionUrl,
    String? cookingInstructions,
  }) async {
    final body = <String, dynamic>{
      'productId': productId,
      'quantity': quantity,
    };
    if (prescriptionUrl != null) body['prescriptionUrl'] = prescriptionUrl;
    if (cookingInstructions != null) body['cookingInstructions'] = cookingInstructions;

    final response = await http.post(
      Uri.parse(_url('/businesses/$businessId/cart/items')),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body)['data'];
      return Cart.fromJson(data);
    }
    throw _handleError(response);
  }

  Future<Cart> updateCartItem(
    String businessId,
    String productId, {
    required int quantity,
  }) async {
    final response = await http.patch(
      Uri.parse(_url('/businesses/$businessId/cart/items/$productId')),
      headers: _headers,
      body: jsonEncode({'quantity': quantity}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['data'];
      return Cart.fromJson(data);
    }
    throw _handleError(response);
  }

  Future<Cart> removeFromCart(String businessId, String productId) async {
    final response = await http.delete(
      Uri.parse(_url('/businesses/$businessId/cart/items/$productId')),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['data'];
      return Cart.fromJson(data);
    }
    throw _handleError(response);
  }

  Future<void> clearCart(String businessId) async {
    final response = await http.delete(
      Uri.parse(_url('/businesses/$businessId/cart')),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw _handleError(response);
    }
  }

  Future<Cart> applyCoupon(String businessId, String couponCode) async {
    final response = await http.post(
      Uri.parse(_url('/businesses/$businessId/cart/coupon')),
      headers: _headers,
      body: jsonEncode({'couponCode': couponCode}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['data'];
      return Cart.fromJson(data);
    }
    throw _handleError(response);
  }

  Future<Cart> removeCoupon(String businessId) async {
    final response = await http.delete(
      Uri.parse(_url('/businesses/$businessId/cart/coupon')),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['data'];
      return Cart.fromJson(data);
    }
    throw _handleError(response);
  }

  // ---------- ORDERS ----------

  Future<OrderDetail> placeOrder(
    String businessId, {
    required String addressId,
    required PaymentMethod paymentMethod,
    String? scheduledFor,
    bool isExpress = false,
    String? notes,
  }) async {
    final response = await http.post(
      Uri.parse(_url('/businesses/$businessId/orders')),
      headers: _headers,
      body: jsonEncode({
        'addressId': addressId,
        'paymentMethod': paymentMethod.name.toUpperCase(),
        'scheduledFor': ?scheduledFor,
        'isExpress': isExpress,
        'notes': ?notes,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body)['data'];
      return OrderDetail.fromJson(data);
    }
    throw _handleError(response);
  }

  Future<List<Order>> getOrderHistory({
    OrderStatus? status,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null) queryParams['status'] = status.name.toUpperCase();

    final uri = Uri.parse(_url('/customers/me/orders'))
        .replace(queryParameters: queryParams);

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['data'];
      return (data['orders'] as List)
          .map((o) => Order.fromJson(o))
          .toList();
    }
    throw _handleError(response);
  }

  Future<OrderDetail> getOrderDetails(String businessId, String orderId) async {
    final response = await http.get(
      Uri.parse(_url('/businesses/$businessId/orders/$orderId')),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['data'];
      return OrderDetail.fromJson(data['order']);
    }
    throw _handleError(response);
  }

  Future<void> cancelOrder(String businessId, String orderId) async {
    final response = await http.post(
      Uri.parse(_url('/businesses/$businessId/orders/$orderId/cancel')),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw _handleError(response);
    }
  }

  // ---------- TRACKING ----------

  Future<OrderDetail> trackOrder(String businessId, String orderId) async {
    final response = await http.get(
      Uri.parse(_url('/businesses/$businessId/orders/$orderId/tracking')),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['data'];
      return OrderDetail.fromJson(data);
    }
    throw _handleError(response);
  }

  // ---------- ERROR HANDLING ----------

  Exception _handleError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      final error = body['error'];
      return ApiException(
        code: error?['code'] ?? 'UNKNOWN',
        message: error?['message'] ?? 'Unknown error',
        statusCode: response.statusCode,
      );
    } catch (_) {
      return ApiException(
        code: 'HTTP_${response.statusCode}',
        message: response.body,
        statusCode: response.statusCode,
      );
    }
  }
}

class ApiException implements Exception {
  final String code;
  final String message;
  final int statusCode;

  ApiException({
    required this.code,
    required this.message,
    required this.statusCode,
  });

  @override
  String toString() => 'ApiException: $code - $message';
}
