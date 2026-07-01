// Product Repository - Real API Integration
// Connects to my-backend handlers/products.ts

import '../../../../core/api/api_client.dart';
import '../models/product_model.dart';

class ProductRepository {
  final ApiClient _client;

  ProductRepository(this._client);

  /// GET /products - List products with filters and pagination
  Future<ProductListResponse> getProducts({
    String? businessType,
    int page = 1,
    int limit = 20,
    ProductFilters? filters,
    String? sortBy,
    bool sortDesc = false,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      'businessType': ?businessType,
      'category': ?filters?.category,
      'brand': ?filters?.brand,
      'minPrice': ?filters?.minPrice?.toString(),
      'maxPrice': ?filters?.maxPrice?.toString(),
      'inStock': ?filters?.inStock?.toString(),
      'searchTerm': ?filters?.searchTerm,
    };

    final response = await _client.get('/products', queryParams: queryParams);
    final data = response.data ?? {};
    
    // Handle both direct array response and wrapped response
    final List<dynamic> items = data['items'] ?? data['data'] ?? [];
    
    final total = data['total'] ?? items.length;
    final responsePage = data['page'] ?? page;
    final responseLimit = data['limit'] ?? limit;
    final nextToken = data['nextToken'];

    return ProductListResponse(
      items: items.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList(),
      total: total is int ? total : int.tryParse(total.toString()) ?? items.length,
      page: responsePage is int ? responsePage : int.tryParse(responsePage.toString()) ?? page,
      limit: responseLimit is int ? responseLimit : int.tryParse(responseLimit.toString()) ?? limit,
      nextToken: nextToken?.toString(),
    );
  }

  /// GET /products/{id} - Get single product by ID
  Future<Product?> getProductById(
    String productId, {
    String? businessType,
  }) async {
    try {
      final queryParams = <String, String>{
        'businessType': ?businessType,
      };

      final response = await _client.get(
        '/products/$productId',
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );

      final data = response.data ?? {};
      // Handle both direct product and wrapped response
      final productData = data['product'] ?? data;
      return Product.fromJson(productData as Map<String, dynamic>);
    } catch (e) {
      if (e.toString().contains('404')) return null;
      rethrow;
    }
  }

  /// POST /products - Create new product
  Future<Product> createProduct(
    CreateProductRequest request, {
    String? businessType,
  }) async {
    final response = await _client.post(
      '/products',
      body: request.toJson(),
    );

    final data = response.data ?? {};
    final productData = data['product'] ?? data;
    return Product.fromJson(productData as Map<String, dynamic>);
  }

  /// PUT /products/{id} - Update product
  Future<Product> updateProduct(
    String productId,
    UpdateProductRequest request, {
    String? businessType,
  }) async {
    final response = await _client.put(
      '/products/$productId',
      body: request.toJson(),
    );

    final data = response.data ?? {};
    final productData = data['product'] ?? data;
    return Product.fromJson(productData as Map<String, dynamic>);
  }

  /// DELETE /products/{id}?soft=true - Soft delete product
  Future<void> deleteProduct(String productId, {bool soft = true}) async {
    await _client.delete(
      '/products/$productId',
      queryParams: {'soft': soft.toString()},
    );
  }

  /// DELETE /products/{id}?permanent=true - Permanent delete
  Future<void> permanentDeleteProduct(String productId) async {
    await _client.delete(
      '/products/$productId',
      queryParams: {'permanent': 'true'},
    );
  }

  /// POST /products/{id}/restore - Restore soft-deleted product
  Future<Product> restoreProduct(String productId) async {
    final response = await _client.post('/products/$productId/restore');
    final data = response.data ?? {};
    final productData = data['product'] ?? data;
    return Product.fromJson(productData as Map<String, dynamic>);
  }

  /// GET /products/search/barcode - Search by barcode
  Future<Product?> searchByBarcode(
    String barcode, {
    String? businessType,
  }) async {
    try {
      final queryParams = <String, String>{
        'barcode': barcode,
        'businessType': ?businessType,
      };

      final response = await _client.get(
        '/products/search/barcode',
        queryParams: queryParams,
      );

      final data = response.data ?? {};
      final productData = data['product'] ?? data;
      return Product.fromJson(productData as Map<String, dynamic>);
    } catch (e) {
      if (e.toString().contains('404')) return null;
      rethrow;
    }
  }

  /// GET /products/low-stock - Get low stock alerts
  Future<List<Product>> getLowStockProducts({
    String? businessType,
    int limit = 50,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'businessType': ?businessType,
    };

    final response = await _client.get(
      '/products/low-stock',
      queryParams: queryParams,
    );

    final data = response.data ?? {};
    final List<dynamic> items = data['items'] ?? data['data'] ?? [];
    
    return items.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /products/top-selling - Get top selling products
  Future<List<Product>> getTopSellingProducts({
    String? businessType,
    int limit = 20,
    String? period, // 'day', 'week', 'month', 'year'
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'businessType': ?businessType,
      'period': ?period,
    };

    final response = await _client.get(
      '/products/top-selling',
      queryParams: queryParams,
    );

    final data = response.data ?? {};
    final List<dynamic> items = data['items'] ?? data['data'] ?? [];
    
    return items.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /products/batch-delete - Delete multiple products
  Future<Map<String, dynamic>> batchDelete(
    List<String> productIds, {
    bool soft = true,
  }) async {
    final response = await _client.post(
      '/products/batch-delete',
      body: {
        'ids': productIds,
        'soft': soft,
      },
    );
    return response.data ?? {};
  }

  /// GET /deleted-items - Get recycle bin items
  Future<List<Product>> getDeletedItems({
    String? entityType,
    int limit = 50,
    String? nextToken,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'deleted': 'true',
      'type': ?entityType,
      'nextToken': ?nextToken,
    };

    final response = await _client.get(
      '/deleted-items',
      queryParams: queryParams,
    );

    final data = response.data ?? {};
    final List<dynamic> items = data['items'] ?? data['data'] ?? [];
    
    return items.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /products/{id}/image-upload-url - Get presigned S3 URL for image upload
  Future<Map<String, String>> getImageUploadUrl(
    String productId, {
    required String fileName,
    required String contentType,
  }) async {
    final response = await _client.post(
      '/products/$productId/image-upload-url',
      body: {
        'fileName': fileName,
        'contentType': contentType,
      },
    );

    final data = response.data ?? {};
    return {
      'uploadUrl': data['uploadUrl']?.toString() ?? '',
      's3Key': data['s3Key']?.toString() ?? '',
    };
  }
}
