// Product Model - Matches Backend Product Interface
// Real API integration with my-backend/src/types/product.types.ts

import 'package:freezed_annotation/freezed_annotation.dart';

part 'product_model.freezed.dart';
part 'product_model.g.dart';

@freezed
abstract class ProductImage with _$ProductImage {
  const factory ProductImage({
    required String s3Key,
    required String s3ThumbnailKey,
    required int uploadedAt,
    required int fileSize,
  }) = _ProductImage;

  factory ProductImage.fromJson(Map<String, dynamic> json) =>
      _$ProductImageFromJson(json);
}

@freezed
abstract class ProductVariant with _$ProductVariant {
  const factory ProductVariant({
    required String id,
    required String name,
    String? sku,
    double? price,
    int? stock,
    String? strength,
  }) = _ProductVariant;

  factory ProductVariant.fromJson(Map<String, dynamic> json) =>
      _$ProductVariantFromJson(json);
}

@freezed
abstract class Product with _$Product {
  const factory Product({
    // Core identifiers
    required String id,
    required String tenantId,
    required String businessType,
    
    // Product metadata
    required String name,
    String? description,
    String? category,
    String? brand,
    
    // Image data
    ProductImage? mainImage,
    List<ProductImage>? images,
    
    // Product specifications
    required double price,
    double? mrp,
    double? cost,
    @Default(0) double gstRate,
    String? hsn,
    
    // Barcode / identifiers
    String? barcode,
    String? sku,
    
    // Pharmacy-specific fields
    String? batchNo,
    int? expiryDate,
    String? drugSchedule,
    String? strength,
    String? formulation,
    String? manufacturer,
    
    // Stock & variants
    @Default(0) int stock,
    int? reorderLevel,
    int? maxStock,
    String? unit,
    List<ProductVariant>? variants,
    
    // Metadata
    @Default(true) bool isActive,
    required int createdAt,
    required int updatedAt,
    required String createdBy,
    required String updatedBy,
    
    // Sync tracking
    bool? synced,
    int? lastSyncedAt,
    int? version,
    
    // Soft delete
    bool? isDeleted,
    int? deletedAt,
  }) = _Product;

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);
}

@freezed
abstract class ProductListResponse with _$ProductListResponse {
  const factory ProductListResponse({
    required List<Product> items,
    required int total,
    required int page,
    required int limit,
    String? nextToken,
  }) = _ProductListResponse;

  factory ProductListResponse.fromJson(Map<String, dynamic> json) =>
      _$ProductListResponseFromJson(json);
}

@freezed
abstract class ProductFilters with _$ProductFilters {
  const factory ProductFilters({
    String? category,
    String? brand,
    double? minPrice,
    double? maxPrice,
    bool? inStock,
    String? searchTerm,
    String? barcode,
    bool? lowStock,
    bool? expiringSoon,
  }) = _ProductFilters;

  factory ProductFilters.fromJson(Map<String, dynamic> json) =>
      _$ProductFiltersFromJson(json);
}

@freezed
abstract class CreateProductRequest with _$CreateProductRequest {
  const factory CreateProductRequest({
    required String name,
    String? description,
    String? category,
    String? brand,
    required double price,
    double? mrp,
    double? cost,
    double? gstRate,
    String? hsn,
    String? barcode,
    String? sku,
    int? stock,
    int? reorderLevel,
    String? unit,
    List<ProductVariant>? variants,
  }) = _CreateProductRequest;

  factory CreateProductRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateProductRequestFromJson(json);
}

@freezed
abstract class UpdateProductRequest with _$UpdateProductRequest {
  const factory UpdateProductRequest({
    String? name,
    String? description,
    String? category,
    String? brand,
    double? price,
    double? mrp,
    double? cost,
    double? gstRate,
    String? hsn,
    String? barcode,
    String? sku,
    int? stock,
    int? reorderLevel,
    String? unit,
    bool? isActive,
    List<ProductVariant>? variants,
  }) = _UpdateProductRequest;

  factory UpdateProductRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateProductRequestFromJson(json);
}
