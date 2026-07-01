class PushRequest {
  final String businessId;
  final List<CustomerSync> customers;
  final List<ProductSync> products;
  final List<BillSync> bills;

  PushRequest({
    required this.businessId,
    this.customers = const [],
    this.products = const [],
    this.bills = const [],
  });

  Map<String, dynamic> toJson() => {
    'business_id': businessId,
    'customers': customers.map((e) => e.toJson()).toList(),
    'products': products.map((e) => e.toJson()).toList(),
    'bills': bills.map((e) => e.toJson()).toList(),
  };
}

class PullRequest {
  final String businessId;
  final DateTime lastSyncTimestamp;

  PullRequest({required this.businessId, required this.lastSyncTimestamp});

  Map<String, dynamic> toJson() => {
    'business_id': businessId,
    'last_sync_timestamp': lastSyncTimestamp.toIso8601String(),
  };
}

class PullResponse {
  final DateTime serverTimestamp;
  final List<CustomerSync> customers;
  final List<ProductSync> products;
  final List<BillSync> bills;

  PullResponse({
    required this.serverTimestamp,
    this.customers = const [],
    this.products = const [],
    this.bills = const [],
  });

  factory PullResponse.fromJson(Map<String, dynamic> json) {
    return PullResponse(
      serverTimestamp: DateTime.parse(json['server_timestamp']),
      customers:
          (json['customers'] as List?)
              ?.map((e) => CustomerSync.fromJson(e))
              .toList() ??
          [],
      products:
          (json['products'] as List?)
              ?.map((e) => ProductSync.fromJson(e))
              .toList() ??
          [],
      bills:
          (json['bills'] as List?)?.map((e) => BillSync.fromJson(e)).toList() ??
          [],
    );
  }
}

// --- ENTITY MODELS (Simplified for Sync) ---

class CustomerSync {
  final String id;
  final DateTime updatedAt;
  final bool isDeleted;
  final String name;
  final String? phone;
  final String? email;
  final double? balance;

  CustomerSync({
    required this.id,
    required this.updatedAt,
    this.isDeleted = false,
    required this.name,
    this.phone,
    this.email,
    this.balance,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'updated_at': updatedAt.toIso8601String(),
    'is_deleted': isDeleted,
    'name': name,
    'phone': phone,
    'email': email,
    'balance': balance,
  };

  factory CustomerSync.fromJson(Map<String, dynamic> json) {
    return CustomerSync(
      id: json['id'],
      updatedAt: DateTime.parse(json['updated_at']),
      isDeleted: json['is_deleted'] ?? false,
      name: json['name'],
      phone: json['phone'],
      email: json['email'],
      balance: (json['balance'] as num?)?.toDouble(),
    );
  }
}

class ProductSync {
  final String id;
  final DateTime updatedAt;
  final bool isDeleted;
  final String name;
  final double price;
  final String? sku;
  final double? stockQty;

  ProductSync({
    required this.id,
    required this.updatedAt,
    this.isDeleted = false,
    required this.name,
    required this.price,
    this.sku,
    this.stockQty,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'updated_at': updatedAt.toIso8601String(),
    'is_deleted': isDeleted,
    'name': name,
    'price': price,
    'sku': sku,
    'stock_qty': stockQty,
  };

  factory ProductSync.fromJson(Map<String, dynamic> json) {
    return ProductSync(
      id: json['id'],
      updatedAt: DateTime.parse(json['updated_at']),
      isDeleted: json['is_deleted'] ?? false,
      name: json['name'],
      price: (json['price'] as num).toDouble(),
      sku: json['sku'],
      stockQty: (json['stock_qty'] as num?)?.toDouble(),
    );
  }
}

class BillSync {
  final String id;
  final DateTime updatedAt;
  final bool isDeleted;
  final String invoiceNumber;
  final DateTime billDate;
  final double totalAmount;
  final String status;
  final List<BillItemSync> items;

  BillSync({
    required this.id,
    required this.updatedAt,
    this.isDeleted = false,
    required this.invoiceNumber,
    required this.billDate,
    required this.totalAmount,
    required this.status,
    this.items = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'updated_at': updatedAt.toIso8601String(),
    'is_deleted': isDeleted,
    'invoice_number': invoiceNumber,
    'bill_date': billDate.toIso8601String(),
    'total_amount': totalAmount,
    'status': status,
    'items': items.map((e) => e.toJson()).toList(),
  };

  factory BillSync.fromJson(Map<String, dynamic> json) {
    return BillSync(
      id: json['id'],
      updatedAt: DateTime.parse(json['updated_at']),
      isDeleted: json['is_deleted'] ?? false,
      invoiceNumber: json['invoice_number'],
      billDate: DateTime.parse(json['bill_date']),
      totalAmount: (json['total_amount'] as num).toDouble(),
      status: json['status'],
      items:
          (json['items'] as List?)
              ?.map((e) => BillItemSync.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class BillItemSync {
  final String id;
  final DateTime updatedAt;
  final bool isDeleted;
  final String billId;
  final String? productId;
  final double qty;
  final double price;
  final double total;

  BillItemSync({
    required this.id,
    required this.updatedAt,
    this.isDeleted = false,
    required this.billId,
    this.productId,
    required this.qty,
    required this.price,
    required this.total,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'updated_at': updatedAt.toIso8601String(),
    'is_deleted': isDeleted,
    'bill_id': billId,
    'product_id': productId,
    'qty': qty,
    'price': price,
    'total': total,
  };

  factory BillItemSync.fromJson(Map<String, dynamic> json) {
    return BillItemSync(
      id: json['id'],
      updatedAt: DateTime.parse(json['updated_at']),
      isDeleted: json['is_deleted'] ?? false,
      billId: json['bill_id'],
      productId: json['product_id'],
      qty: (json['qty'] as num).toDouble(),
      price: (json['price'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
    );
  }
}

class SyncChangeRecord {
  final String table;
  final String action;
  final String id;
  final Map<String, dynamic> data;
  final String localTimestamp;
  final String? idempotencyKey;

  const SyncChangeRecord({
    required this.table,
    required this.action,
    required this.id,
    required this.data,
    required this.localTimestamp,
    this.idempotencyKey,
  });

  Map<String, dynamic> toJson() {
    return {
      'table': table,
      'action': action,
      'id': id,
      'data': data,
      'localTimestamp': localTimestamp,
      if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
    };
  }

  factory SyncChangeRecord.fromJson(Map<String, dynamic> json) {
    return SyncChangeRecord(
      table: json['table'] as String,
      action: json['action'] as String,
      id: json['id'] as String,
      data: Map<String, dynamic>.from(json['data'] as Map),
      localTimestamp: json['localTimestamp'] as String,
      idempotencyKey: json['idempotencyKey'] as String?,
    );
  }
}

