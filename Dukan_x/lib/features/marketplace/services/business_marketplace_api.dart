// ============================================================
// Dukan Billing Software - Business Marketplace API Service
// Desktop-optimized API client for business owners
// ============================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/session/session_manager.dart';
import '../../../config/api_config.dart';
import '../../../core/di/service_locator.dart';
import '../models/business_order_models.dart';

final businessMarketplaceApiProvider = Provider<BusinessMarketplaceApi>((ref) {
  return BusinessMarketplaceApi(sl<SessionManager>());
});

class BusinessMarketplaceApi {
  final SessionManager _session;
  final String _baseUrl;

  BusinessMarketplaceApi(this._session) 
      : _baseUrl = ApiConfig.baseUrl;

  String? _cachedToken;

  Future<Map<String, String>> _getHeaders() async {
    _cachedToken ??= await _session.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (_cachedToken != null) 'Authorization': 'Bearer $_cachedToken',
    };
  }

  String _url(String path) => '$_baseUrl/v1$path';

  // ---------- ORDERS ----------

  Future<PaginatedOrders> getOrders({
    OrderFilters? filters,
    int page = 1,
    int limit = 50,
  }) async {
    final businessId = _session.currentBusinessId;
    
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (filters?.status != null) {
      queryParams['status'] = filters!.status!.name.toUpperCase();
    }
    if (filters?.dateFrom != null) {
      queryParams['dateFrom'] = filters!.dateFrom!.toIso8601String();
    }
    if (filters?.dateTo != null) {
      queryParams['dateTo'] = filters!.dateTo!.toIso8601String();
    }

    final uri = Uri.parse(_url('/businesses/$businessId/orders'))
        .replace(queryParameters: queryParams);

    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return PaginatedOrders.fromJson({
        'orders': data['data']['orders'],
        ...data['meta'] ?? {},
      });
    }
    throw _handleError(response);
  }

  Future<BusinessOrderDetail> getOrderDetails(String orderId) async {
    final businessId = _session.currentBusinessId;
    
    final response = await http.get(
      Uri.parse(_url('/businesses/$businessId/orders/$orderId')),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['data'];
      return BusinessOrderDetail.fromJson(data['order']);
    }
    throw _handleError(response);
  }

  Future<void> updateOrderStatus(
    String orderId, {
    required BusinessOrderStatus status,
    String? note,
    String? assignedPartnerId,
  }) async {
    final businessId = _session.currentBusinessId;
    
    final body = <String, dynamic>{
      'status': status.name.toUpperCase(),
      'note': ?note,
      'assignedDeliveryPartnerId': ?assignedPartnerId,
    };

    final response = await http.patch(
      Uri.parse(_url('/businesses/$businessId/orders/$orderId/status')),
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw _handleError(response);
    }
  }

  Future<void> assignDeliveryPartner(String orderId, String partnerId) async {
    await updateOrderStatus(
      orderId,
      status: BusinessOrderStatus.outForDelivery,
      assignedPartnerId: partnerId,
    );
  }

  // ---------- STATS ----------

  Future<OrderStats> getOrderStats({DateTime? dateFrom, DateTime? dateTo}) async {
    final businessId = _session.currentBusinessId;
    
    final queryParams = <String, String>{};
    if (dateFrom != null) queryParams['dateFrom'] = dateFrom.toIso8601String();
    if (dateTo != null) queryParams['dateTo'] = dateTo.toIso8601String();

    final uri = Uri.parse(_url('/businesses/$businessId/analytics/orders'))
        .replace(queryParameters: queryParams);

    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['data'];
      return OrderStats.fromJson(data);
    }
    throw _handleError(response);
  }

  // ---------- INVENTORY SYNC ----------

  Future<void> syncInventory(List<InventorySyncItem> products) async {
    final businessId = _session.currentBusinessId;
    
    final response = await http.post(
      Uri.parse(_url('/businesses/$businessId/inventory/sync')),
      headers: await _getHeaders(),
      body: jsonEncode({
        'products': products.map((p) => p.toJson()).toList(),
      }),
    );

    if (response.statusCode != 200) {
      throw _handleError(response);
    }
  }

  Future<void> updateProductStock(String productId, int newStock) async {
    final businessId = _session.currentBusinessId;
    
    final response = await http.patch(
      Uri.parse(_url('/businesses/$businessId/inventory/sync')),
      headers: await _getHeaders(),
      body: jsonEncode({
        'products': [{
          'productId': productId,
          'stockQuantity': newStock,
        }],
      }),
    );

    if (response.statusCode != 200) {
      throw _handleError(response);
    }
  }

  // ---------- DELIVERY PARTNERS ----------

  Future<List<DeliveryPartnerInfo>> getDeliveryPartners({bool? isActive}) async {
    final businessId = _session.currentBusinessId;
    
    final queryParams = <String, String>{};
    if (isActive != null) queryParams['isActive'] = isActive.toString();

    final uri = Uri.parse(_url('/businesses/$businessId/delivery-partners'))
        .replace(queryParameters: queryParams);

    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['data'];
      return (data['partners'] as List)
          .map((p) => DeliveryPartnerInfo.fromJson(p))
          .toList();
    }
    throw _handleError(response);
  }

  Future<void> createDeliveryPartner({
    required String name,
    required String phone,
    String? email,
    required String vehicleType,
    String? vehicleNumber,
  }) async {
    final businessId = _session.currentBusinessId;
    
    final response = await http.post(
      Uri.parse(_url('/businesses/$businessId/delivery-partners')),
      headers: await _getHeaders(),
      body: jsonEncode({
        'name': name,
        'phone': phone,
        'email': ?email,
        'vehicleType': vehicleType,
        'vehicleNumber': ?vehicleNumber,
      }),
    );

    if (response.statusCode != 201) {
      throw _handleError(response);
    }
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
