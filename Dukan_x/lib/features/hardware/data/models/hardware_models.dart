// ============================================================================
// HARDWARE TYPED MODELS (bugfix.md 2.25 — architectural consistency)
// ============================================================================

import 'dart:convert';

/// A hardware project.
class HardwareProject {
  final String id;
  final String? projectName;
  final String? contractorName;
  final String? siteAddress;
  final String? notes;
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const HardwareProject({
    required this.id,
    this.projectName,
    this.contractorName,
    this.siteAddress,
    this.notes,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory HardwareProject.fromJson(Map<String, dynamic> json) =>
      HardwareProject(
        id: json['id']?.toString() ?? '',
        projectName: (json['projectName'] ?? json['project_name']) as String?,
        contractorName:
            (json['contractorName'] ?? json['contractor_name']) as String?,
        siteAddress: (json['siteAddress'] ?? json['site_address']) as String?,
        notes: json['notes'] as String?,
        status: json['status'] as String?,
        createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
        updatedAt: _parseDate(json['updatedAt'] ?? json['updated_at']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    if (projectName != null) 'projectName': projectName,
    if (contractorName != null) 'contractorName': contractorName,
    if (siteAddress != null) 'siteAddress': siteAddress,
    if (notes != null) 'notes': notes,
    if (status != null) 'status': status,
  };
}

/// A site indent.
class HardwareSiteIndent {
  final String id;
  final String? projectId;
  final String? requestedBy;
  final String? priority;
  final String? status;
  final String? notes;
  final List<Map<String, dynamic>> items;

  const HardwareSiteIndent({
    required this.id,
    this.projectId,
    this.requestedBy,
    this.priority,
    this.status,
    this.notes,
    this.items = const [],
  });

  factory HardwareSiteIndent.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] ?? json['items_json'];
    List<Map<String, dynamic>> parsedItems = const [];
    if (rawItems is List) {
      parsedItems = rawItems
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } else if (rawItems is String && rawItems.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawItems) as List;
        parsedItems = decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } catch (_) {}
    }
    return HardwareSiteIndent(
      id: json['id']?.toString() ?? '',
      projectId: (json['projectId'] ?? json['project_id']) as String?,
      requestedBy: (json['requestedBy'] ?? json['requested_by']) as String?,
      priority: json['priority'] as String?,
      status: json['status'] as String?,
      notes: json['notes'] as String?,
      items: parsedItems,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (projectId != null) 'projectId': projectId,
    if (requestedBy != null) 'requestedBy': requestedBy,
    if (priority != null) 'priority': priority,
    if (status != null) 'status': status,
    if (notes != null) 'notes': notes,
    'items': items,
  };
}

/// A material deposit.
class HardwareMaterialDeposit {
  final String id;
  final String? customerId;
  final String? customerName;
  final String? itemType;
  final double quantity;
  final int depositAmountCents;
  final String? referenceNo;
  final String? notes;
  final String? status;

  const HardwareMaterialDeposit({
    required this.id,
    this.customerId,
    this.customerName,
    this.itemType,
    this.quantity = 0,
    this.depositAmountCents = 0,
    this.referenceNo,
    this.notes,
    this.status,
  });

  factory HardwareMaterialDeposit.fromJson(Map<String, dynamic> json) =>
      HardwareMaterialDeposit(
        id: json['id']?.toString() ?? '',
        customerId: (json['customerId'] ?? json['customer_id']) as String?,
        customerName:
            (json['customerName'] ?? json['customer_name']) as String?,
        itemType: (json['itemType'] ?? json['item_type']) as String?,
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        depositAmountCents:
            (json['depositAmountCents'] ?? json['deposit_amount_cents'] as num?)
                ?.toInt() ??
            0,
        referenceNo: (json['referenceNo'] ?? json['reference_no']) as String?,
        notes: json['notes'] as String?,
        status: json['status'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    if (customerId != null) 'customerId': customerId,
    if (customerName != null) 'customerName': customerName,
    if (itemType != null) 'itemType': itemType,
    'quantity': quantity,
    'depositAmountCents': depositAmountCents,
    if (referenceNo != null) 'referenceNo': referenceNo,
    if (notes != null) 'notes': notes,
    if (status != null) 'status': status,
  };
}

/// A hardware purchase order.
class HardwarePurchaseOrder {
  final String id;
  final String? supplierId;
  final String? status;
  final String? expectedDeliveryDate;
  final String? notes;
  final List<Map<String, dynamic>> items;

  const HardwarePurchaseOrder({
    required this.id,
    this.supplierId,
    this.status,
    this.expectedDeliveryDate,
    this.notes,
    this.items = const [],
  });

  factory HardwarePurchaseOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] ?? json['items_json'];
    List<Map<String, dynamic>> parsedItems = const [];
    if (rawItems is List) {
      parsedItems = rawItems
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } else if (rawItems is String && rawItems.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawItems) as List;
        parsedItems = decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } catch (_) {}
    }
    return HardwarePurchaseOrder(
      id: json['id']?.toString() ?? '',
      supplierId: (json['supplierId'] ?? json['supplier_id']) as String?,
      status: json['status'] as String?,
      expectedDeliveryDate:
          (json['expectedDeliveryDate'] ?? json['expected_delivery_date'])
              as String?,
      notes: json['notes'] as String?,
      items: parsedItems,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (supplierId != null) 'supplierId': supplierId,
    if (status != null) 'status': status,
    if (expectedDeliveryDate != null)
      'expectedDeliveryDate': expectedDeliveryDate,
    if (notes != null) 'notes': notes,
    'items': items,
  };
}

/// A hardware party.
class HardwareParty {
  final String id;
  final String? name;
  final String? type;
  final String? phone;
  final String? gstin;
  final String? address;
  final int creditLimit;
  final int creditDays;
  final String priceCategory;

  const HardwareParty({
    required this.id,
    this.name,
    this.type,
    this.phone,
    this.gstin,
    this.address,
    this.creditLimit = 0,
    this.creditDays = 30,
    this.priceCategory = 'retail',
  });

  factory HardwareParty.fromJson(Map<String, dynamic> json) => HardwareParty(
    id: json['id']?.toString() ?? '',
    name: json['name'] as String?,
    type: json['type'] as String?,
    phone: json['phone'] as String?,
    gstin: json['gstin'] as String?,
    address: json['address'] as String?,
    creditLimit:
        (json['creditLimit'] ?? json['credit_limit'] as num?)?.toInt() ?? 0,
    creditDays:
        (json['creditDays'] ?? json['credit_days'] as num?)?.toInt() ?? 30,
    priceCategory:
        (json['priceCategory'] ?? json['price_category']) as String? ??
        'retail',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    if (name != null) 'name': name,
    if (type != null) 'type': type,
    if (phone != null) 'phone': phone,
    if (gstin != null) 'gstin': gstin,
    if (address != null) 'address': address,
    'creditLimit': creditLimit,
    'creditDays': creditDays,
    'priceCategory': priceCategory,
  };
}

/// A hardware sales order.
class HardwareSalesOrder {
  final String id;
  final String? customerId;
  final String? customerName;
  final String? status;
  final String? notes;
  final List<Map<String, dynamic>> items;

  const HardwareSalesOrder({
    required this.id,
    this.customerId,
    this.customerName,
    this.status,
    this.notes,
    this.items = const [],
  });

  factory HardwareSalesOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] ?? json['items_json'];
    List<Map<String, dynamic>> parsedItems = const [];
    if (rawItems is List) {
      parsedItems = rawItems
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } else if (rawItems is String && rawItems.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawItems) as List;
        parsedItems = decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } catch (_) {}
    }
    return HardwareSalesOrder(
      id: json['id']?.toString() ?? '',
      customerId: (json['customerId'] ?? json['customer_id']) as String?,
      customerName: (json['customerName'] ?? json['customer_name']) as String?,
      status: json['status'] as String?,
      notes: json['notes'] as String?,
      items: parsedItems,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (customerId != null) 'customerId': customerId,
    if (customerName != null) 'customerName': customerName,
    if (status != null) 'status': status,
    if (notes != null) 'notes': notes,
    'items': items,
  };
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return DateTime.tryParse(v.toString());
}
