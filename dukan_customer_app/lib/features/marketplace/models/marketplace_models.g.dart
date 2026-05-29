// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'marketplace_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$StoreProfileImpl _$$StoreProfileImplFromJson(Map<String, dynamic> json) =>
    _$StoreProfileImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      logo: json['logo'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      description: json['description'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      deliveryTime: json['deliveryTime'] as String?,
      minOrderValue: (json['minOrderValue'] as num?)?.toDouble(),
      deliveryCharge: (json['deliveryCharge'] as num?)?.toDouble(),
      isOpen: json['isOpen'] as bool?,
    );

Map<String, dynamic> _$$StoreProfileImplToJson(_$StoreProfileImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'category': instance.category,
      'logo': instance.logo,
      'address': instance.address,
      'phone': instance.phone,
      'description': instance.description,
      'rating': instance.rating,
      'deliveryTime': instance.deliveryTime,
      'minOrderValue': instance.minOrderValue,
      'deliveryCharge': instance.deliveryCharge,
      'isOpen': instance.isOpen,
    };

_$ProductImpl _$$ProductImplFromJson(Map<String, dynamic> json) =>
    _$ProductImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      subcategory: json['subcategory'] as String?,
      brand: json['brand'] as String?,
      mrp: (json['mrp'] as num).toDouble(),
      sellingPrice: (json['sellingPrice'] as num).toDouble(),
      discountPercent: (json['discountPercent'] as num).toDouble(),
      stockQuantity: (json['stockQuantity'] as num).toInt(),
      unit: json['unit'] as String,
      images:
          (json['images'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isAvailable: json['isAvailable'] as bool?,
      gstPercent: (json['gstPercent'] as num).toDouble(),
      expiryDate: json['expiryDate'] as String?,
      drugSchedule: json['drugSchedule'] as String?,
      comboProducts:
          (json['comboProducts'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      specAttributes: (json['specAttributes'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      warrantyMonths: (json['warrantyMonths'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$ProductImplToJson(_$ProductImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'category': instance.category,
      'subcategory': instance.subcategory,
      'brand': instance.brand,
      'mrp': instance.mrp,
      'sellingPrice': instance.sellingPrice,
      'discountPercent': instance.discountPercent,
      'stockQuantity': instance.stockQuantity,
      'unit': instance.unit,
      'images': instance.images,
      'isAvailable': instance.isAvailable,
      'gstPercent': instance.gstPercent,
      'expiryDate': instance.expiryDate,
      'drugSchedule': instance.drugSchedule,
      'comboProducts': instance.comboProducts,
      'specAttributes': instance.specAttributes,
      'warrantyMonths': instance.warrantyMonths,
    };

_$ProductDetailImpl _$$ProductDetailImplFromJson(Map<String, dynamic> json) =>
    _$ProductDetailImpl(
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
      relatedProducts:
          (json['relatedProducts'] as List<dynamic>?)
              ?.map((e) => Product.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$ProductDetailImplToJson(_$ProductDetailImpl instance) =>
    <String, dynamic>{
      'product': instance.product,
      'relatedProducts': instance.relatedProducts,
    };

_$CartItemImpl _$$CartItemImplFromJson(Map<String, dynamic> json) =>
    _$CartItemImpl(
      productId: json['productId'] as String,
      name: json['name'] as String,
      image: json['image'] as String?,
      quantity: (json['quantity'] as num).toInt(),
      unit: json['unit'] as String,
      mrp: (json['mrp'] as num).toDouble(),
      sellingPrice: (json['sellingPrice'] as num).toDouble(),
      discountPercent: (json['discountPercent'] as num).toDouble(),
      gstPercent: (json['gstPercent'] as num).toDouble(),
      itemTotal: (json['itemTotal'] as num).toDouble(),
      prescriptionUrl: json['prescriptionUrl'] as String?,
      cookingInstructions: json['cookingInstructions'] as String?,
      warrantyRequired: json['warrantyRequired'] as bool?,
      stockQuantity: (json['stockQuantity'] as num?)?.toInt(),
      isAvailable: json['isAvailable'] as bool?,
    );

Map<String, dynamic> _$$CartItemImplToJson(_$CartItemImpl instance) =>
    <String, dynamic>{
      'productId': instance.productId,
      'name': instance.name,
      'image': instance.image,
      'quantity': instance.quantity,
      'unit': instance.unit,
      'mrp': instance.mrp,
      'sellingPrice': instance.sellingPrice,
      'discountPercent': instance.discountPercent,
      'gstPercent': instance.gstPercent,
      'itemTotal': instance.itemTotal,
      'prescriptionUrl': instance.prescriptionUrl,
      'cookingInstructions': instance.cookingInstructions,
      'warrantyRequired': instance.warrantyRequired,
      'stockQuantity': instance.stockQuantity,
      'isAvailable': instance.isAvailable,
    };

_$CartImpl _$$CartImplFromJson(Map<String, dynamic> json) => _$CartImpl(
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => CartItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  couponCode: json['couponCode'] as String?,
  discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
  subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
  taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0,
  deliveryCharge: (json['deliveryCharge'] as num?)?.toDouble() ?? 0,
  total: (json['total'] as num?)?.toDouble() ?? 0,
  itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
  lastUpdatedAt: json['lastUpdatedAt'] as String?,
  stockWarnings: (json['stockWarnings'] as List<dynamic>?)
      ?.map((e) => StockWarning.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$$CartImplToJson(_$CartImpl instance) =>
    <String, dynamic>{
      'items': instance.items,
      'couponCode': instance.couponCode,
      'discountAmount': instance.discountAmount,
      'subtotal': instance.subtotal,
      'taxAmount': instance.taxAmount,
      'deliveryCharge': instance.deliveryCharge,
      'total': instance.total,
      'itemCount': instance.itemCount,
      'lastUpdatedAt': instance.lastUpdatedAt,
      'stockWarnings': instance.stockWarnings,
    };

_$StockWarningImpl _$$StockWarningImplFromJson(Map<String, dynamic> json) =>
    _$StockWarningImpl(
      productId: json['productId'] as String,
      name: json['name'] as String,
      requested: (json['requested'] as num).toInt(),
      available: (json['available'] as num).toInt(),
    );

Map<String, dynamic> _$$StockWarningImplToJson(_$StockWarningImpl instance) =>
    <String, dynamic>{
      'productId': instance.productId,
      'name': instance.name,
      'requested': instance.requested,
      'available': instance.available,
    };

_$OrderItemImpl _$$OrderItemImplFromJson(Map<String, dynamic> json) =>
    _$OrderItemImpl(
      productId: json['productId'] as String,
      name: json['name'] as String,
      image: json['image'] as String?,
      quantity: (json['quantity'] as num).toInt(),
      unit: json['unit'] as String,
      mrp: (json['mrp'] as num).toDouble(),
      sellingPrice: (json['sellingPrice'] as num).toDouble(),
      discountPercent: (json['discountPercent'] as num).toDouble(),
      gstPercent: (json['gstPercent'] as num).toDouble(),
      itemTotal: (json['itemTotal'] as num).toDouble(),
      deliveredQuantity: (json['deliveredQuantity'] as num?)?.toInt(),
      returnReason: json['returnReason'] as String?,
    );

Map<String, dynamic> _$$OrderItemImplToJson(_$OrderItemImpl instance) =>
    <String, dynamic>{
      'productId': instance.productId,
      'name': instance.name,
      'image': instance.image,
      'quantity': instance.quantity,
      'unit': instance.unit,
      'mrp': instance.mrp,
      'sellingPrice': instance.sellingPrice,
      'discountPercent': instance.discountPercent,
      'gstPercent': instance.gstPercent,
      'itemTotal': instance.itemTotal,
      'deliveredQuantity': instance.deliveredQuantity,
      'returnReason': instance.returnReason,
    };

_$DeliveryAddressImpl _$$DeliveryAddressImplFromJson(
  Map<String, dynamic> json,
) => _$DeliveryAddressImpl(
  id: json['id'] as String,
  label: json['label'] as String,
  addressLine1: json['addressLine1'] as String,
  addressLine2: json['addressLine2'] as String?,
  landmark: json['landmark'] as String?,
  city: json['city'] as String,
  state: json['state'] as String,
  pincode: json['pincode'] as String,
  contactName: json['contactName'] as String,
  contactPhone: json['contactPhone'] as String,
  location: (json['location'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, (e as num).toDouble()),
  ),
);

Map<String, dynamic> _$$DeliveryAddressImplToJson(
  _$DeliveryAddressImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'label': instance.label,
  'addressLine1': instance.addressLine1,
  'addressLine2': instance.addressLine2,
  'landmark': instance.landmark,
  'city': instance.city,
  'state': instance.state,
  'pincode': instance.pincode,
  'contactName': instance.contactName,
  'contactPhone': instance.contactPhone,
  'location': instance.location,
};

_$OrderTimelineEventImpl _$$OrderTimelineEventImplFromJson(
  Map<String, dynamic> json,
) => _$OrderTimelineEventImpl(
  status: $enumDecode(_$OrderStatusEnumMap, json['status']),
  timestamp: json['timestamp'] as String,
  note: json['note'] as String?,
  updatedBy: json['updatedBy'] as String,
);

Map<String, dynamic> _$$OrderTimelineEventImplToJson(
  _$OrderTimelineEventImpl instance,
) => <String, dynamic>{
  'status': _$OrderStatusEnumMap[instance.status]!,
  'timestamp': instance.timestamp,
  'note': instance.note,
  'updatedBy': instance.updatedBy,
};

const _$OrderStatusEnumMap = {
  OrderStatus.placed: 'placed',
  OrderStatus.accepted: 'accepted',
  OrderStatus.rejected: 'rejected',
  OrderStatus.preparing: 'preparing',
  OrderStatus.readyForDispatch: 'readyForDispatch',
  OrderStatus.outForDelivery: 'outForDelivery',
  OrderStatus.delivered: 'delivered',
  OrderStatus.cancelled: 'cancelled',
};

_$OrderImpl _$$OrderImplFromJson(Map<String, dynamic> json) => _$OrderImpl(
  orderId: json['orderId'] as String,
  status: $enumDecode(_$OrderStatusEnumMap, json['status']),
  customerName: json['customerName'] as String,
  customerPhone: json['customerPhone'] as String,
  itemCount: (json['itemCount'] as num).toInt(),
  total: (json['total'] as num).toDouble(),
  paymentMethod: $enumDecode(_$PaymentMethodEnumMap, json['paymentMethod']),
  paymentStatus: $enumDecode(_$PaymentStatusEnumMap, json['paymentStatus']),
  isExpress: json['isExpress'] as bool?,
  scheduledFor: json['scheduledFor'] as String?,
  estimatedDeliveryTime: json['estimatedDeliveryTime'] as String?,
  createdAt: json['createdAt'] as String,
);

Map<String, dynamic> _$$OrderImplToJson(_$OrderImpl instance) =>
    <String, dynamic>{
      'orderId': instance.orderId,
      'status': _$OrderStatusEnumMap[instance.status]!,
      'customerName': instance.customerName,
      'customerPhone': instance.customerPhone,
      'itemCount': instance.itemCount,
      'total': instance.total,
      'paymentMethod': _$PaymentMethodEnumMap[instance.paymentMethod]!,
      'paymentStatus': _$PaymentStatusEnumMap[instance.paymentStatus]!,
      'isExpress': instance.isExpress,
      'scheduledFor': instance.scheduledFor,
      'estimatedDeliveryTime': instance.estimatedDeliveryTime,
      'createdAt': instance.createdAt,
    };

const _$PaymentMethodEnumMap = {
  PaymentMethod.cod: 'cod',
  PaymentMethod.online: 'online',
  PaymentMethod.wallet: 'wallet',
};

const _$PaymentStatusEnumMap = {
  PaymentStatus.pending: 'pending',
  PaymentStatus.completed: 'completed',
  PaymentStatus.failed: 'failed',
  PaymentStatus.refunded: 'refunded',
};

_$OrderDetailImpl _$$OrderDetailImplFromJson(Map<String, dynamic> json) =>
    _$OrderDetailImpl(
      orderId: json['orderId'] as String,
      status: $enumDecode(_$OrderStatusEnumMap, json['status']),
      customerName: json['customerName'] as String,
      customerPhone: json['customerPhone'] as String,
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      deliveryAddress: DeliveryAddress.fromJson(
        json['deliveryAddress'] as Map<String, dynamic>,
      ),
      subtotal: (json['subtotal'] as num).toDouble(),
      taxAmount: (json['taxAmount'] as num).toDouble(),
      deliveryCharge: (json['deliveryCharge'] as num).toDouble(),
      discountAmount: (json['discountAmount'] as num).toDouble(),
      couponCode: json['couponCode'] as String?,
      total: (json['total'] as num).toDouble(),
      paymentMethod: $enumDecode(_$PaymentMethodEnumMap, json['paymentMethod']),
      paymentStatus: $enumDecode(_$PaymentStatusEnumMap, json['paymentStatus']),
      isExpress: json['isExpress'] as bool?,
      scheduledFor: json['scheduledFor'] as String?,
      estimatedDeliveryTime: json['estimatedDeliveryTime'] as String?,
      timeline:
          (json['timeline'] as List<dynamic>?)
              ?.map(
                (e) => OrderTimelineEvent.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      notes: json['notes'] as String?,
      prescriptionUrl: json['prescriptionUrl'] as String?,
      createdAt: json['createdAt'] as String?,
      deliveryPartner: json['deliveryPartner'] == null
          ? null
          : DeliveryPartnerInfo.fromJson(
              json['deliveryPartner'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$$OrderDetailImplToJson(_$OrderDetailImpl instance) =>
    <String, dynamic>{
      'orderId': instance.orderId,
      'status': _$OrderStatusEnumMap[instance.status]!,
      'customerName': instance.customerName,
      'customerPhone': instance.customerPhone,
      'items': instance.items,
      'deliveryAddress': instance.deliveryAddress,
      'subtotal': instance.subtotal,
      'taxAmount': instance.taxAmount,
      'deliveryCharge': instance.deliveryCharge,
      'discountAmount': instance.discountAmount,
      'couponCode': instance.couponCode,
      'total': instance.total,
      'paymentMethod': _$PaymentMethodEnumMap[instance.paymentMethod]!,
      'paymentStatus': _$PaymentStatusEnumMap[instance.paymentStatus]!,
      'isExpress': instance.isExpress,
      'scheduledFor': instance.scheduledFor,
      'estimatedDeliveryTime': instance.estimatedDeliveryTime,
      'timeline': instance.timeline,
      'notes': instance.notes,
      'prescriptionUrl': instance.prescriptionUrl,
      'createdAt': instance.createdAt,
      'deliveryPartner': instance.deliveryPartner,
    };

_$DeliveryPartnerInfoImpl _$$DeliveryPartnerInfoImplFromJson(
  Map<String, dynamic> json,
) => _$DeliveryPartnerInfoImpl(
  name: json['name'] as String,
  phone: json['phone'] as String,
  currentLocation: (json['currentLocation'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, (e as num).toDouble()),
  ),
  vehicleType: json['vehicleType'] as String?,
  vehicleNumber: json['vehicleNumber'] as String?,
);

Map<String, dynamic> _$$DeliveryPartnerInfoImplToJson(
  _$DeliveryPartnerInfoImpl instance,
) => <String, dynamic>{
  'name': instance.name,
  'phone': instance.phone,
  'currentLocation': instance.currentLocation,
  'vehicleType': instance.vehicleType,
  'vehicleNumber': instance.vehicleNumber,
};

_$StoreConnectionImpl _$$StoreConnectionImplFromJson(
  Map<String, dynamic> json,
) => _$StoreConnectionImpl(
  connected: json['connected'] as bool,
  status: json['status'] as String?,
  connectedAt: json['connectedAt'] as String?,
  totalOrders: (json['totalOrders'] as num?)?.toInt(),
  totalSpent: (json['totalSpent'] as num?)?.toDouble(),
);

Map<String, dynamic> _$$StoreConnectionImplToJson(
  _$StoreConnectionImpl instance,
) => <String, dynamic>{
  'connected': instance.connected,
  'status': instance.status,
  'connectedAt': instance.connectedAt,
  'totalOrders': instance.totalOrders,
  'totalSpent': instance.totalSpent,
};

_$CouponImpl _$$CouponImplFromJson(Map<String, dynamic> json) => _$CouponImpl(
  code: json['code'] as String,
  type: json['type'] as String,
  value: (json['value'] as num).toDouble(),
  maxDiscount: (json['maxDiscount'] as num?)?.toDouble(),
  minOrderValue: (json['minOrderValue'] as num?)?.toDouble(),
);

Map<String, dynamic> _$$CouponImplToJson(_$CouponImpl instance) =>
    <String, dynamic>{
      'code': instance.code,
      'type': instance.type,
      'value': instance.value,
      'maxDiscount': instance.maxDiscount,
      'minOrderValue': instance.minOrderValue,
    };

_$ProductSearchFiltersImpl _$$ProductSearchFiltersImplFromJson(
  Map<String, dynamic> json,
) => _$ProductSearchFiltersImpl(
  category: json['category'] as String?,
  brand: json['brand'] as String?,
  inStock: json['inStock'] as bool?,
  sortBy: json['sortBy'] as String?,
  minPrice: (json['minPrice'] as num?)?.toDouble(),
  maxPrice: (json['maxPrice'] as num?)?.toDouble(),
);

Map<String, dynamic> _$$ProductSearchFiltersImplToJson(
  _$ProductSearchFiltersImpl instance,
) => <String, dynamic>{
  'category': instance.category,
  'brand': instance.brand,
  'inStock': instance.inStock,
  'sortBy': instance.sortBy,
  'minPrice': instance.minPrice,
  'maxPrice': instance.maxPrice,
};

_$ProductSearchResultImpl _$$ProductSearchResultImplFromJson(
  Map<String, dynamic> json,
) => _$ProductSearchResultImpl(
  products:
      (json['products'] as List<dynamic>?)
          ?.map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  filters: json['filters'] == null
      ? null
      : ProductSearchFilters.fromJson(json['filters'] as Map<String, dynamic>),
  total: (json['total'] as num?)?.toInt(),
  page: (json['page'] as num?)?.toInt(),
  limit: (json['limit'] as num?)?.toInt(),
  hasMore: json['hasMore'] as bool?,
);

Map<String, dynamic> _$$ProductSearchResultImplToJson(
  _$ProductSearchResultImpl instance,
) => <String, dynamic>{
  'products': instance.products,
  'filters': instance.filters,
  'total': instance.total,
  'page': instance.page,
  'limit': instance.limit,
  'hasMore': instance.hasMore,
};

_$WebSocketMessageImpl _$$WebSocketMessageImplFromJson(
  Map<String, dynamic> json,
) => _$WebSocketMessageImpl(
  type: json['type'] as String,
  timestamp: json['timestamp'] as String,
  businessId: json['businessId'] as String,
  targetRoom: json['targetRoom'] as String?,
  payload: json['payload'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$$WebSocketMessageImplToJson(
  _$WebSocketMessageImpl instance,
) => <String, dynamic>{
  'type': instance.type,
  'timestamp': instance.timestamp,
  'businessId': instance.businessId,
  'targetRoom': instance.targetRoom,
  'payload': instance.payload,
};

_$OrderUpdatePayloadImpl _$$OrderUpdatePayloadImplFromJson(
  Map<String, dynamic> json,
) => _$OrderUpdatePayloadImpl(
  orderId: json['orderId'] as String,
  status: json['status'] as String,
  previousStatus: json['previousStatus'] as String?,
  message: json['message'] as String,
  estimatedTime: json['estimatedTime'] as String?,
  timestamp: json['timestamp'] as String,
);

Map<String, dynamic> _$$OrderUpdatePayloadImplToJson(
  _$OrderUpdatePayloadImpl instance,
) => <String, dynamic>{
  'orderId': instance.orderId,
  'status': instance.status,
  'previousStatus': instance.previousStatus,
  'message': instance.message,
  'estimatedTime': instance.estimatedTime,
  'timestamp': instance.timestamp,
};
