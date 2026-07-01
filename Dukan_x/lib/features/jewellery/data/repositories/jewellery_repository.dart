import '../../../../core/api/api_client.dart';
import '../models/jewellery_models.dart';

/// Repository for Jewellery module API operations
class JewelleryRepository {
  final ApiClient _apiClient;

  JewelleryRepository(this._apiClient);

  Future<List<CustomOrder>> getCustomOrders({String? status}) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;

    final response = await _apiClient.get(
      '/jewellery/custom-orders',
      queryParams: params,
    );

    if (response.statusCode == 200) {
      final data = response.data ?? {};
      final items =
          data['items'] ?? data['orders'] ?? (data is List ? data : []);
      return (items as List)
          .map((e) => CustomOrder.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load custom orders: ${response.error}');
  }

  Future<void> deleteCustomOrder(String orderId) async {
    final response = await _apiClient.delete(
      '/jewellery/custom-orders/$orderId',
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete order: ${response.error}');
    }
  }

  Future<void> restoreCustomOrder(String orderId) async {
    final response = await _apiClient.post(
      '/jewellery/custom-orders/$orderId/restore',
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to restore order: ${response.error}');
    }
  }

  Future<void> updateCustomOrderStatus(
    String orderId, {
    required String status,
  }) async {
    final response = await _apiClient.patch(
      '/jewellery/custom-orders/$orderId/status',
      body: {'status': status},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update order status: ${response.error}');
    }
  }
}
