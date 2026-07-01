// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProductImage _$ProductImageFromJson(Map<String, dynamic> json) =>
    _ProductImage(
      s3Key: json['s3Key'] as String,
      s3ThumbnailKey: json['s3ThumbnailKey'] as String,
      uploadedAt: (json['uploadedAt'] as num).toInt(),
      fileSize: (json['fileSize'] as num).toInt(),
    );

Map<String, dynamic> _$ProductImageToJson(_ProductImage instance) =>
    <String, dynamic>{
      's3Key': instance.s3Key,
      's3ThumbnailKey': instance.s3ThumbnailKey,
      'uploadedAt': instance.uploadedAt,
      'fileSize': instance.fileSize,
    };

_ProductVariant _$ProductVariantFromJson(Map<String, dynamic> json) =>
    _ProductVariant(
      id: json['id'] as String,
      name: json['name'] as String,
      sku: json['sku'] as String?,
      price: (json['price'] as num?)?.toDouble(),
      stock: (json['stock'] as num?)?.toInt(),
      strength: json['strength'] as String?,
    );

Map<String, dynamic> _$ProductVariantToJson(_ProductVariant instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'sku': instance.sku,
      'price': instance.price,
      'stock': instance.stock,
      'strength': instance.strength,
    };

_Product _$ProductFromJson(Map<String, dynamic> json) => _Product(
  id: json['id'] as String,
  tenantId: json['tenantId'] as String,
  businessType: json['businessType'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  category: json['category'] as String?,
  brand: json['brand'] as String?,
  mainImage: json['mainImage'] == null
      ? null
      : ProductImage.fromJson(json['mainImage'] as Map<String, dynamic>),
  images: (json['images'] as List<dynamic>?)
      ?.map((e) => ProductImage.fromJson(e as Map<String, dynamic>))
      .toList(),
  price: (json['price'] as num).toDouble(),
  mrp: (json['mrp'] as num?)?.toDouble(),
  cost: (json['cost'] as num?)?.toDouble(),
  gstRate: (json['gstRate'] as num?)?.toDouble() ?? 0,
  hsn: json['hsn'] as String?,
  barcode: json['barcode'] as String?,
  sku: json['sku'] as String?,
  batchNo: json['batchNo'] as String?,
  expiryDate: (json['expiryDate'] as num?)?.toInt(),
  drugSchedule: json['drugSchedule'] as String?,
  strength: json['strength'] as String?,
  formulation: json['formulation'] as String?,
  manufacturer: json['manufacturer'] as String?,
  stock: (json['stock'] as num?)?.toInt() ?? 0,
  reorderLevel: (json['reorderLevel'] as num?)?.toInt(),
  maxStock: (json['maxStock'] as num?)?.toInt(),
  unit: json['unit'] as String?,
  variants: (json['variants'] as List<dynamic>?)
      ?.map((e) => ProductVariant.fromJson(e as Map<String, dynamic>))
      .toList(),
  isActive: json['isActive'] as bool? ?? true,
  createdAt: (json['createdAt'] as num).toInt(),
  updatedAt: (json['updatedAt'] as num).toInt(),
  createdBy: json['createdBy'] as String,
  updatedBy: json['updatedBy'] as String,
  synced: json['synced'] as bool?,
  lastSyncedAt: (json['lastSyncedAt'] as num?)?.toInt(),
  version: (json['version'] as num?)?.toInt(),
  isDeleted: json['isDeleted'] as bool?,
  deletedAt: (json['deletedAt'] as num?)?.toInt(),
);

Map<String, dynamic> _$ProductToJson(_Product instance) => <String, dynamic>{
  'id': instance.id,
  'tenantId': instance.tenantId,
  'businessType': instance.businessType,
  'name': instance.name,
  'description': instance.description,
  'category': instance.category,
  'brand': instance.brand,
  'mainImage': instance.mainImage,
  'images': instance.images,
  'price': instance.price,
  'mrp': instance.mrp,
  'cost': instance.cost,
  'gstRate': instance.gstRate,
  'hsn': instance.hsn,
  'barcode': instance.barcode,
  'sku': instance.sku,
  'batchNo': instance.batchNo,
  'expiryDate': instance.expiryDate,
  'drugSchedule': instance.drugSchedule,
  'strength': instance.strength,
  'formulation': instance.formulation,
  'manufacturer': instance.manufacturer,
  'stock': instance.stock,
  'reorderLevel': instance.reorderLevel,
  'maxStock': instance.maxStock,
  'unit': instance.unit,
  'variants': instance.variants,
  'isActive': instance.isActive,
  'createdAt': instance.createdAt,
  'updatedAt': instance.updatedAt,
  'createdBy': instance.createdBy,
  'updatedBy': instance.updatedBy,
  'synced': instance.synced,
  'lastSyncedAt': instance.lastSyncedAt,
  'version': instance.version,
  'isDeleted': instance.isDeleted,
  'deletedAt': instance.deletedAt,
};

_ProductListResponse _$ProductListResponseFromJson(Map<String, dynamic> json) =>
    _ProductListResponse(
      items: (json['items'] as List<dynamic>)
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
      page: (json['page'] as num).toInt(),
      limit: (json['limit'] as num).toInt(),
      nextToken: json['nextToken'] as String?,
    );

Map<String, dynamic> _$ProductListResponseToJson(
  _ProductListResponse instance,
) => <String, dynamic>{
  'items': instance.items,
  'total': instance.total,
  'page': instance.page,
  'limit': instance.limit,
  'nextToken': instance.nextToken,
};

_ProductFilters _$ProductFiltersFromJson(Map<String, dynamic> json) =>
    _ProductFilters(
      category: json['category'] as String?,
      brand: json['brand'] as String?,
      minPrice: (json['minPrice'] as num?)?.toDouble(),
      maxPrice: (json['maxPrice'] as num?)?.toDouble(),
      inStock: json['inStock'] as bool?,
      searchTerm: json['searchTerm'] as String?,
      barcode: json['barcode'] as String?,
      lowStock: json['lowStock'] as bool?,
      expiringSoon: json['expiringSoon'] as bool?,
    );

Map<String, dynamic> _$ProductFiltersToJson(_ProductFilters instance) =>
    <String, dynamic>{
      'category': instance.category,
      'brand': instance.brand,
      'minPrice': instance.minPrice,
      'maxPrice': instance.maxPrice,
      'inStock': instance.inStock,
      'searchTerm': instance.searchTerm,
      'barcode': instance.barcode,
      'lowStock': instance.lowStock,
      'expiringSoon': instance.expiringSoon,
    };

_CreateProductRequest _$CreateProductRequestFromJson(
  Map<String, dynamic> json,
) => _CreateProductRequest(
  name: json['name'] as String,
  description: json['description'] as String?,
  category: json['category'] as String?,
  brand: json['brand'] as String?,
  price: (json['price'] as num).toDouble(),
  mrp: (json['mrp'] as num?)?.toDouble(),
  cost: (json['cost'] as num?)?.toDouble(),
  gstRate: (json['gstRate'] as num?)?.toDouble(),
  hsn: json['hsn'] as String?,
  barcode: json['barcode'] as String?,
  sku: json['sku'] as String?,
  stock: (json['stock'] as num?)?.toInt(),
  reorderLevel: (json['reorderLevel'] as num?)?.toInt(),
  unit: json['unit'] as String?,
  variants: (json['variants'] as List<dynamic>?)
      ?.map((e) => ProductVariant.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$CreateProductRequestToJson(
  _CreateProductRequest instance,
) => <String, dynamic>{
  'name': instance.name,
  'description': instance.description,
  'category': instance.category,
  'brand': instance.brand,
  'price': instance.price,
  'mrp': instance.mrp,
  'cost': instance.cost,
  'gstRate': instance.gstRate,
  'hsn': instance.hsn,
  'barcode': instance.barcode,
  'sku': instance.sku,
  'stock': instance.stock,
  'reorderLevel': instance.reorderLevel,
  'unit': instance.unit,
  'variants': instance.variants,
};

_UpdateProductRequest _$UpdateProductRequestFromJson(
  Map<String, dynamic> json,
) => _UpdateProductRequest(
  name: json['name'] as String?,
  description: json['description'] as String?,
  category: json['category'] as String?,
  brand: json['brand'] as String?,
  price: (json['price'] as num?)?.toDouble(),
  mrp: (json['mrp'] as num?)?.toDouble(),
  cost: (json['cost'] as num?)?.toDouble(),
  gstRate: (json['gstRate'] as num?)?.toDouble(),
  hsn: json['hsn'] as String?,
  barcode: json['barcode'] as String?,
  sku: json['sku'] as String?,
  stock: (json['stock'] as num?)?.toInt(),
  reorderLevel: (json['reorderLevel'] as num?)?.toInt(),
  unit: json['unit'] as String?,
  isActive: json['isActive'] as bool?,
  variants: (json['variants'] as List<dynamic>?)
      ?.map((e) => ProductVariant.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$UpdateProductRequestToJson(
  _UpdateProductRequest instance,
) => <String, dynamic>{
  'name': instance.name,
  'description': instance.description,
  'category': instance.category,
  'brand': instance.brand,
  'price': instance.price,
  'mrp': instance.mrp,
  'cost': instance.cost,
  'gstRate': instance.gstRate,
  'hsn': instance.hsn,
  'barcode': instance.barcode,
  'sku': instance.sku,
  'stock': instance.stock,
  'reorderLevel': instance.reorderLevel,
  'unit': instance.unit,
  'isActive': instance.isActive,
  'variants': instance.variants,
};
