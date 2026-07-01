// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_order_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OnlineCustomer _$OnlineCustomerFromJson(Map<String, dynamic> json) =>
    _OnlineCustomer(
      customerId: json['customerId'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      totalOrders: (json['totalOrders'] as num).toInt(),
      totalSpent: (json['totalSpent'] as num).toDouble(),
      connectedAt: json['connectedAt'] as String,
    );

Map<String, dynamic> _$OnlineCustomerToJson(_OnlineCustomer instance) =>
    <String, dynamic>{
      'customerId': instance.customerId,
      'name': instance.name,
      'phone': instance.phone,
      'email': instance.email,
      'totalOrders': instance.totalOrders,
      'totalSpent': instance.totalSpent,
      'connectedAt': instance.connectedAt,
    };

_BusinessOrderItem _$BusinessOrderItemFromJson(Map<String, dynamic> json) =>
    _BusinessOrderItem(
      productId: json['productId'] as String,
      name: json['name'] as String,
      image: json['image'] as String?,
      quantity: (json['quantity'] as num).toInt(),
      stockQuantity: (json['stockQuantity'] as num?)?.toInt(),
      unit: json['unit'] as String,
      mrp: (json['mrp'] as num).toDouble(),
      sellingPrice: (json['sellingPrice'] as num).toDouble(),
      itemTotal: (json['itemTotal'] as num).toDouble(),
      prescriptionUrl: json['prescriptionUrl'] as String?,
      cookingInstructions: json['cookingInstructions'] as String?,
      warrantyRequired: json['warrantyRequired'] as bool?,
      isPrepared: json['isPrepared'] as bool?,
      preparedAt: json['preparedAt'] as String?,
      preparedBy: json['preparedBy'] as String?,
    );

Map<String, dynamic> _$BusinessOrderItemToJson(_BusinessOrderItem instance) =>
    <String, dynamic>{
      'productId': instance.productId,
      'name': instance.name,
      'image': instance.image,
      'quantity': instance.quantity,
      'stockQuantity': instance.stockQuantity,
      'unit': instance.unit,
      'mrp': instance.mrp,
      'sellingPrice': instance.sellingPrice,
      'itemTotal': instance.itemTotal,
      'prescriptionUrl': instance.prescriptionUrl,
      'cookingInstructions': instance.cookingInstructions,
      'warrantyRequired': instance.warrantyRequired,
      'isPrepared': instance.isPrepared,
      'preparedAt': instance.preparedAt,
      'preparedBy': instance.preparedBy,
    };

_BusinessDeliveryAddress _$BusinessDeliveryAddressFromJson(
  Map<String, dynamic> json,
) => _BusinessDeliveryAddress(
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

Map<String, dynamic> _$BusinessDeliveryAddressToJson(
  _BusinessDeliveryAddress instance,
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

_BusinessOrderTimelineEvent _$BusinessOrderTimelineEventFromJson(
  Map<String, dynamic> json,
) => _BusinessOrderTimelineEvent(
  status: $enumDecode(_$BusinessOrderStatusEnumMap, json['status']),
  timestamp: json['timestamp'] as String,
  note: json['note'] as String?,
  updatedBy: json['updatedBy'] as String,
);

Map<String, dynamic> _$BusinessOrderTimelineEventToJson(
  _BusinessOrderTimelineEvent instance,
) => <String, dynamic>{
  'status': _$BusinessOrderStatusEnumMap[instance.status]!,
  'timestamp': instance.timestamp,
  'note': instance.note,
  'updatedBy': instance.updatedBy,
};

const _$BusinessOrderStatusEnumMap = {
  BusinessOrderStatus.placed: 'placed',
  BusinessOrderStatus.accepted: 'accepted',
  BusinessOrderStatus.rejected: 'rejected',
  BusinessOrderStatus.preparing: 'preparing',
  BusinessOrderStatus.readyForDispatch: 'readyForDispatch',
  BusinessOrderStatus.outForDelivery: 'outForDelivery',
  BusinessOrderStatus.delivered: 'delivered',
  BusinessOrderStatus.cancelled: 'cancelled',
};

_BusinessOrder _$BusinessOrderFromJson(Map<String, dynamic> json) =>
    _BusinessOrder(
      orderId: json['orderId'] as String,
      status: $enumDecode(_$BusinessOrderStatusEnumMap, json['status']),
      customer: OnlineCustomer.fromJson(
        json['customer'] as Map<String, dynamic>,
      ),
      itemCount: (json['itemCount'] as num).toInt(),
      total: (json['total'] as num).toDouble(),
      paymentMethod: $enumDecode(
        _$BusinessPaymentMethodEnumMap,
        json['paymentMethod'],
      ),
      paymentStatus: $enumDecode(
        _$BusinessPaymentStatusEnumMap,
        json['paymentStatus'],
      ),
      isExpress: json['isExpress'] as bool?,
      scheduledFor: json['scheduledFor'] as String?,
      estimatedDeliveryTime: json['estimatedDeliveryTime'] as String?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String?,
    );

Map<String, dynamic> _$BusinessOrderToJson(_BusinessOrder instance) =>
    <String, dynamic>{
      'orderId': instance.orderId,
      'status': _$BusinessOrderStatusEnumMap[instance.status]!,
      'customer': instance.customer,
      'itemCount': instance.itemCount,
      'total': instance.total,
      'paymentMethod': _$BusinessPaymentMethodEnumMap[instance.paymentMethod]!,
      'paymentStatus': _$BusinessPaymentStatusEnumMap[instance.paymentStatus]!,
      'isExpress': instance.isExpress,
      'scheduledFor': instance.scheduledFor,
      'estimatedDeliveryTime': instance.estimatedDeliveryTime,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
    };

const _$BusinessPaymentMethodEnumMap = {
  BusinessPaymentMethod.cod: 'cod',
  BusinessPaymentMethod.online: 'online',
  BusinessPaymentMethod.wallet: 'wallet',
};

const _$BusinessPaymentStatusEnumMap = {
  BusinessPaymentStatus.pending: 'pending',
  BusinessPaymentStatus.completed: 'completed',
  BusinessPaymentStatus.failed: 'failed',
  BusinessPaymentStatus.refunded: 'refunded',
};

_BusinessOrderDetail _$BusinessOrderDetailFromJson(
  Map<String, dynamic> json,
) => _BusinessOrderDetail(
  orderId: json['orderId'] as String,
  status: $enumDecode(_$BusinessOrderStatusEnumMap, json['status']),
  customer: OnlineCustomer.fromJson(json['customer'] as Map<String, dynamic>),
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => BusinessOrderItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  deliveryAddress: BusinessDeliveryAddress.fromJson(
    json['deliveryAddress'] as Map<String, dynamic>,
  ),
  subtotal: (json['subtotal'] as num).toDouble(),
  taxAmount: (json['taxAmount'] as num).toDouble(),
  deliveryCharge: (json['deliveryCharge'] as num).toDouble(),
  discountAmount: (json['discountAmount'] as num).toDouble(),
  couponCode: json['couponCode'] as String?,
  total: (json['total'] as num).toDouble(),
  paymentMethod: $enumDecode(
    _$BusinessPaymentMethodEnumMap,
    json['paymentMethod'],
  ),
  paymentStatus: $enumDecode(
    _$BusinessPaymentStatusEnumMap,
    json['paymentStatus'],
  ),
  isExpress: json['isExpress'] as bool?,
  scheduledFor: json['scheduledFor'] as String?,
  estimatedDeliveryTime: json['estimatedDeliveryTime'] as String?,
  timeline:
      (json['timeline'] as List<dynamic>?)
          ?.map(
            (e) =>
                BusinessOrderTimelineEvent.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  notes: json['notes'] as String?,
  prescriptionUrl: json['prescriptionUrl'] as String?,
  createdAt: json['createdAt'] as String?,
  updatedAt: json['updatedAt'] as String?,
  assignedPartner: json['assignedPartner'] == null
      ? null
      : DeliveryPartnerInfo.fromJson(
          json['assignedPartner'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$BusinessOrderDetailToJson(
  _BusinessOrderDetail instance,
) => <String, dynamic>{
  'orderId': instance.orderId,
  'status': _$BusinessOrderStatusEnumMap[instance.status]!,
  'customer': instance.customer,
  'items': instance.items,
  'deliveryAddress': instance.deliveryAddress,
  'subtotal': instance.subtotal,
  'taxAmount': instance.taxAmount,
  'deliveryCharge': instance.deliveryCharge,
  'discountAmount': instance.discountAmount,
  'couponCode': instance.couponCode,
  'total': instance.total,
  'paymentMethod': _$BusinessPaymentMethodEnumMap[instance.paymentMethod]!,
  'paymentStatus': _$BusinessPaymentStatusEnumMap[instance.paymentStatus]!,
  'isExpress': instance.isExpress,
  'scheduledFor': instance.scheduledFor,
  'estimatedDeliveryTime': instance.estimatedDeliveryTime,
  'timeline': instance.timeline,
  'notes': instance.notes,
  'prescriptionUrl': instance.prescriptionUrl,
  'createdAt': instance.createdAt,
  'updatedAt': instance.updatedAt,
  'assignedPartner': instance.assignedPartner,
};

_DeliveryPartnerInfo _$DeliveryPartnerInfoFromJson(Map<String, dynamic> json) =>
    _DeliveryPartnerInfo(
      partnerId: json['partnerId'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      currentLocation: (json['currentLocation'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ),
      vehicleType: json['vehicleType'] as String?,
      vehicleNumber: json['vehicleNumber'] as String?,
      isActive: json['isActive'] as bool?,
    );

Map<String, dynamic> _$DeliveryPartnerInfoToJson(
  _DeliveryPartnerInfo instance,
) => <String, dynamic>{
  'partnerId': instance.partnerId,
  'name': instance.name,
  'phone': instance.phone,
  'currentLocation': instance.currentLocation,
  'vehicleType': instance.vehicleType,
  'vehicleNumber': instance.vehicleNumber,
  'isActive': instance.isActive,
};

_OrderStats _$OrderStatsFromJson(Map<String, dynamic> json) => _OrderStats(
  totalOrders: (json['totalOrders'] as num).toInt(),
  totalRevenue: (json['totalRevenue'] as num).toDouble(),
  pendingOrders: (json['pendingOrders'] as num).toInt(),
  preparingOrders: (json['preparingOrders'] as num).toInt(),
  outForDeliveryOrders: (json['outForDeliveryOrders'] as num).toInt(),
  deliveredToday: (json['deliveredToday'] as num).toInt(),
  avgOrderValue: (json['avgOrderValue'] as num).toDouble(),
  newCustomers: (json['newCustomers'] as num).toInt(),
  repeatCustomers: (json['repeatCustomers'] as num).toInt(),
);

Map<String, dynamic> _$OrderStatsToJson(_OrderStats instance) =>
    <String, dynamic>{
      'totalOrders': instance.totalOrders,
      'totalRevenue': instance.totalRevenue,
      'pendingOrders': instance.pendingOrders,
      'preparingOrders': instance.preparingOrders,
      'outForDeliveryOrders': instance.outForDeliveryOrders,
      'deliveredToday': instance.deliveredToday,
      'avgOrderValue': instance.avgOrderValue,
      'newCustomers': instance.newCustomers,
      'repeatCustomers': instance.repeatCustomers,
    };

_OrderFilters _$OrderFiltersFromJson(Map<String, dynamic> json) =>
    _OrderFilters(
      status: $enumDecodeNullable(_$BusinessOrderStatusEnumMap, json['status']),
      dateFrom: json['dateFrom'] == null
          ? null
          : DateTime.parse(json['dateFrom'] as String),
      dateTo: json['dateTo'] == null
          ? null
          : DateTime.parse(json['dateTo'] as String),
      searchQuery: json['searchQuery'] as String?,
      sortBy: json['sortBy'] as String?,
      isExpress: json['isExpress'] as bool?,
    );

Map<String, dynamic> _$OrderFiltersToJson(_OrderFilters instance) =>
    <String, dynamic>{
      'status': _$BusinessOrderStatusEnumMap[instance.status],
      'dateFrom': instance.dateFrom?.toIso8601String(),
      'dateTo': instance.dateTo?.toIso8601String(),
      'searchQuery': instance.searchQuery,
      'sortBy': instance.sortBy,
      'isExpress': instance.isExpress,
    };

_PaginatedOrders _$PaginatedOrdersFromJson(Map<String, dynamic> json) =>
    _PaginatedOrders(
      orders:
          (json['orders'] as List<dynamic>?)
              ?.map((e) => BusinessOrder.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      total: (json['total'] as num).toInt(),
      page: (json['page'] as num).toInt(),
      limit: (json['limit'] as num).toInt(),
      hasMore: json['hasMore'] as bool,
    );

Map<String, dynamic> _$PaginatedOrdersToJson(_PaginatedOrders instance) =>
    <String, dynamic>{
      'orders': instance.orders,
      'total': instance.total,
      'page': instance.page,
      'limit': instance.limit,
      'hasMore': instance.hasMore,
    };

_InventorySyncItem _$InventorySyncItemFromJson(Map<String, dynamic> json) =>
    _InventorySyncItem(
      productId: json['productId'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      mrp: (json['mrp'] as num?)?.toDouble(),
      sellingPrice: (json['sellingPrice'] as num?)?.toDouble(),
      stockQuantity: (json['stockQuantity'] as num?)?.toInt(),
      isActive: json['isActive'] as bool?,
      isAvailableForOnline: json['isAvailableForOnline'] as bool?,
      barcode: json['barcode'] as String?,
      hsnCode: json['hsnCode'] as String?,
      gstPercent: (json['gstPercent'] as num?)?.toDouble(),
      expiryDate: json['expiryDate'] as String?,
      drugSchedule: json['drugSchedule'] as String?,
    );

Map<String, dynamic> _$InventorySyncItemToJson(_InventorySyncItem instance) =>
    <String, dynamic>{
      'productId': instance.productId,
      'name': instance.name,
      'category': instance.category,
      'mrp': instance.mrp,
      'sellingPrice': instance.sellingPrice,
      'stockQuantity': instance.stockQuantity,
      'isActive': instance.isActive,
      'isAvailableForOnline': instance.isAvailableForOnline,
      'barcode': instance.barcode,
      'hsnCode': instance.hsnCode,
      'gstPercent': instance.gstPercent,
      'expiryDate': instance.expiryDate,
      'drugSchedule': instance.drugSchedule,
    };
