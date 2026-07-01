// ============================================================================
// COMPUTER SHOP — API Repository
// ============================================================================
// Integrates with Lambda backend via ApiClient
// All amounts in paise on wire, converted to rupees in models
// CRITICAL FIX: This file was created to address audit findings
// ============================================================================

import '../../../../core/api/api_client.dart';

/// Generic paginated response wrapper
class PaginatedResponse<T> {
  final List<T> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  PaginatedResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;
  int get from => (page - 1) * limit + 1;
  int get to => (page - 1) * limit + items.length;
}

/// Job Card model for Computer Shop
class ComputerJobCard {
  final String id;
  final String? customerId;
  final String deviceBrand;
  final String deviceModel;
  final String? serialNumber;
  final String reportedIssue;
  final String status;
  final String? technicianId;
  final String? technicianName;
  final String? diagnosis;
  final double? estimatedLaborCost;
  final double? actualLaborCost;
  final double? actualPartsCost;
  final String? invoiceId;
  final String? invoiceNumber;
  final DateTime createdAt;
  final DateTime updatedAt;

  ComputerJobCard({
    required this.id,
    this.customerId,
    required this.deviceBrand,
    required this.deviceModel,
    this.serialNumber,
    required this.reportedIssue,
    required this.status,
    this.technicianId,
    this.technicianName,
    this.diagnosis,
    this.estimatedLaborCost,
    this.actualLaborCost,
    this.actualPartsCost,
    this.invoiceId,
    this.invoiceNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ComputerJobCard.fromJson(Map<String, dynamic> json) {
    return ComputerJobCard(
      id: json['id'] ?? '',
      customerId: json['customerId'],
      deviceBrand: json['deviceBrand'] ?? '',
      deviceModel: json['deviceModel'] ?? '',
      serialNumber: json['serialNumber'],
      reportedIssue: json['reportedIssue'] ?? '',
      status: json['status'] ?? 'INTAKE',
      technicianId: json['technicianId'],
      technicianName: json['technicianName'],
      diagnosis: json['diagnosis'],
      estimatedLaborCost: json['estimatedLaborCost']?.toDouble(),
      actualLaborCost: json['actualLaborCost']?.toDouble(),
      actualPartsCost: json['actualPartsCost']?.toDouble(),
      invoiceId: json['invoiceId'],
      invoiceNumber: json['invoiceNumber'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }
}

/// Job Part model
class ComputerJobPart {
  final String id;
  final String jobCardId;
  final String productId;
  final String? productName;
  final double quantity;
  final double unitPrice;
  final double totalCost;
  final String? notes;
  final DateTime createdAt;

  ComputerJobPart({
    required this.id,
    required this.jobCardId,
    required this.productId,
    this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalCost,
    this.notes,
    required this.createdAt,
  });

  factory ComputerJobPart.fromJson(Map<String, dynamic> json) {
    return ComputerJobPart(
      id: json['id'] ?? '',
      jobCardId: json['jobCardId'] ?? '',
      productId: json['productId'] ?? '',
      productName: json['productName'],
      quantity: (json['quantity'] ?? 0).toDouble(),
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
      totalCost: (json['totalCost'] ?? 0).toDouble(),
      notes: json['notes'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}

/// Warranty model
class ComputerWarranty {
  final String id;
  final String serialNumber;
  final String productId;
  final String? invoiceId;
  final String? customerId;
  final int warrantyPeriodMonths;
  final String purchaseDate;
  final String warrantyExpiryDate;
  final String status;
  final int claimCount;
  final int? daysRemaining;
  final bool? isExpired;

  ComputerWarranty({
    required this.id,
    required this.serialNumber,
    required this.productId,
    this.invoiceId,
    this.customerId,
    required this.warrantyPeriodMonths,
    required this.purchaseDate,
    required this.warrantyExpiryDate,
    required this.status,
    required this.claimCount,
    this.daysRemaining,
    this.isExpired,
  });

  factory ComputerWarranty.fromJson(Map<String, dynamic> json) {
    return ComputerWarranty(
      id: json['id'] ?? json['SK']?.toString().split('#').last ?? '',
      serialNumber: json['serialNumber'] ?? '',
      productId: json['productId'] ?? '',
      invoiceId: json['invoiceId'],
      customerId: json['customerId'],
      warrantyPeriodMonths: json['warrantyPeriodMonths'] ?? 0,
      purchaseDate: json['purchaseDate'] ?? '',
      warrantyExpiryDate: json['warrantyExpiryDate'] ?? '',
      status: json['status'] ?? 'ACTIVE',
      claimCount: json['claimCount'] ?? 0,
      daysRemaining: json['daysRemaining'],
      isExpired: json['isExpired'],
    );
  }
}

/// Serial History response
class ComputerSerialHistory {
  final Map<String, dynamic> serial;
  final List<ComputerJobCard> jobCards;
  final List<Map<String, dynamic>> rmas;
  final ComputerWarranty? warranty;

  ComputerSerialHistory({
    required this.serial,
    required this.jobCards,
    required this.rmas,
    this.warranty,
  });

  factory ComputerSerialHistory.fromJson(Map<String, dynamic> json) {
    final history = json['serviceHistory'] ?? {};
    return ComputerSerialHistory(
      serial: json['serial'] ?? {},
      jobCards: (history['jobCards'] as List? ?? [])
          .map((j) => ComputerJobCard.fromJson(j))
          .toList(),
      rmas: (history['rmas'] as List? ?? [])
          .map((r) => r as Map<String, dynamic>)
          .toList(),
      warranty: json['warranty'] != null
          ? ComputerWarranty.fromJson(json['warranty'])
          : null,
    );
  }
}

/// Multi-unit conversion configuration
class MultiUnitConfig {
  final String productId;
  final String primaryUnit;
  final String alternateUnit;
  final double conversionRate;

  MultiUnitConfig({
    required this.productId,
    required this.primaryUnit,
    required this.alternateUnit,
    required this.conversionRate,
  });
}

/// Converted stock unit result
class UnitConversionResult {
  final String productId;
  final String productName;
  final Map<String, dynamic> from;
  final Map<String, dynamic> to;
  final double conversionRate;

  UnitConversionResult({
    required this.productId,
    required this.productName,
    required this.from,
    required this.to,
    required this.conversionRate,
  });

  factory UnitConversionResult.fromJson(Map<String, dynamic> json) {
    return UnitConversionResult(
      productId: json['productId'] ?? '',
      productName: json['productName'] ?? '',
      from: json['from'] ?? {},
      to: json['to'] ?? {},
      conversionRate: (json['conversionRate'] ?? 1).toDouble(),
    );
  }
}

/// Computer Shop Repository
class ComputerRepository {
  final ApiClient _apiClient;

  ComputerRepository(this._apiClient);

  // ==========================================================================
  // JOB CARDS
  // ==========================================================================

  /// List all job cards with optional status filter
  Future<PaginatedResponse<ComputerJobCard>> listJobCards({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null) queryParams['status'] = status;

    final response = await _apiClient.get(
      '/computer/job-cards',
      queryParameters: queryParams,
    );

    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      final data = raw['data'] ?? raw;
      final List<dynamic> items = data is List ? data : (data['items'] ?? []);
      return PaginatedResponse(
        items: items.map((json) => ComputerJobCard.fromJson(json)).toList(),
        total: data['total'] ?? items.length,
        page: data['page'] ?? page,
        limit: data['limit'] ?? limit,
        totalPages: data['totalPages'] ?? 1,
      );
    }
    throw Exception('Failed to load job cards: ${response.error}');
  }

  /// Create a new job card
  Future<ComputerJobCard> createJobCard(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/computer/job-cards', body: data);
    if (response.statusCode == 201 || response.statusCode == 200) {
      final raw = response.data ?? {};
      // Fetch the created job card
      final id = raw['id'] ?? raw['data']?['id'];
      if (id != null) {
        return getJobCard(id);
      }
      return ComputerJobCard.fromJson(raw['data'] ?? raw);
    }
    throw Exception('Failed to create job card: ${response.error}');
  }

  /// Get a single job card by ID
  Future<ComputerJobCard> getJobCard(String id) async {
    final response = await _apiClient.get('/computer/job-cards/$id');
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return ComputerJobCard.fromJson(raw['data'] ?? raw);
    }
    throw Exception('Failed to load job card: ${response.error}');
  }

  /// Update job card status
  Future<void> updateJobCardStatus(
    String id,
    String status, {
    String? techNotes,
  }) async {
    final response = await _apiClient.patch(
      '/computer/job-cards/$id/status',
      body: {'status': status, 'techNotes': ?techNotes},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update status: ${response.error}');
    }
  }

  // ==========================================================================
  // JOB PARTS (CRITICAL FIX)
  // ==========================================================================

  /// Add a part to a job card (deducts inventory)
  Future<String> addJobPart(
    String jobCardId, {
    required String productId,
    required double quantity,
    required double unitPrice,
    String? notes,
  }) async {
    final response = await _apiClient.post(
      '/computer/job-cards/$jobCardId/parts',
      body: {
        'productId': productId,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'notes': ?notes,
      },
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      final raw = response.data ?? {};
      return raw['partId'] ?? raw['data']?['partId'] ?? '';
    }
    throw Exception('Failed to add part: ${response.error}');
  }

  /// Get all parts for a job card
  Future<List<ComputerJobPart>> getJobParts(String jobCardId) async {
    final response = await _apiClient.get(
      '/computer/job-cards/$jobCardId/parts',
    );
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      final List<dynamic> items = raw is List ? raw : (raw['data'] ?? []);
      return items.map((json) => ComputerJobPart.fromJson(json)).toList();
    }
    throw Exception('Failed to load job parts: ${response.error}');
  }

  // ==========================================================================
  // TECHNICIAN ASSIGNMENT (HIGH FIX)
  // ==========================================================================

  /// Assign technician to job card
  Future<void> assignTechnician(
    String jobCardId, {
    required String technicianId,
    required String technicianName,
  }) async {
    final response = await _apiClient.patch(
      '/computer/job-cards/$jobCardId/assign',
      body: {'technicianId': technicianId, 'technicianName': technicianName},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to assign technician: ${response.error}');
    }
  }

  // ==========================================================================
  // LABOR COSTS
  // ==========================================================================

  /// Update labor costs and diagnosis
  Future<void> updateLaborCost(
    String jobCardId, {
    double? estimatedLaborCost,
    double? actualLaborCost,
    String? diagnosis,
  }) async {
    final body = <String, dynamic>{};
    if (estimatedLaborCost != null)
      body['estimatedLaborCost'] = estimatedLaborCost;
    if (actualLaborCost != null) body['actualLaborCost'] = actualLaborCost;
    if (diagnosis != null) body['diagnosis'] = diagnosis;

    final response = await _apiClient.patch(
      '/computer/job-cards/$jobCardId/labor',
      body: body,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update labor costs: ${response.error}');
    }
  }

  // ==========================================================================
  // JOB TO INVOICE CONVERSION (CRITICAL FIX)
  // ==========================================================================

  /// Convert completed job to invoice
  Future<Map<String, dynamic>> convertJobToInvoice(
    String jobCardId, {
    required String customerName,
    String? customerPhone,
    String paymentMode = 'cash',
    String? notes,
    double discountCents = 0,
  }) async {
    final response = await _apiClient.post(
      '/computer/job-cards/$jobCardId/convert-to-invoice',
      body: {
        'customerName': customerName,
        'customerPhone': ?customerPhone,
        'paymentMode': paymentMode,
        'notes': ?notes,
        'discountCents': discountCents,
      },
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      final raw = response.data ?? {};
      return raw['data'] ?? raw;
    }
    throw Exception('Failed to convert job to invoice: ${response.error}');
  }

  // ==========================================================================
  // WARRANTY MANAGEMENT (HIGH FIX)
  // ==========================================================================

  /// Register warranty for a serial number
  Future<ComputerWarranty> registerWarranty({
    required String serialNumber,
    required String productId,
    required int warrantyPeriodMonths,
    required String purchaseDate,
    required String invoiceId,
    String? customerId,
  }) async {
    final response = await _apiClient.post(
      '/computer/warranty',
      body: {
        'serialNumber': serialNumber,
        'productId': productId,
        'warrantyPeriodMonths': warrantyPeriodMonths,
        'purchaseDate': purchaseDate,
        'invoiceId': invoiceId,
        'customerId': ?customerId,
      },
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      final raw = response.data ?? {};
      final data = raw['data'] ?? raw;
      // Fetch the created warranty
      final id = data['warrantyId'] ?? data['id'];
      if (id != null) {
        return getWarranty(warrantyId: id);
      }
      return ComputerWarranty.fromJson(data);
    }
    throw Exception('Failed to register warranty: ${response.error}');
  }

  /// Get warranty by serial number or warranty ID
  Future<ComputerWarranty> getWarranty({
    String? serialNumber,
    String? warrantyId,
  }) async {
    final queryParams = <String, String>{};
    if (serialNumber != null) queryParams['serial'] = serialNumber;
    if (warrantyId != null) queryParams['warrantyId'] = warrantyId;

    final response = await _apiClient.get(
      '/computer/warranty',
      queryParameters: queryParams,
    );
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return ComputerWarranty.fromJson(raw['data'] ?? raw);
    }
    throw Exception('Failed to load warranty: ${response.error}');
  }

  // ==========================================================================
  // SERIAL HISTORY (MEDIUM FIX)
  // ==========================================================================

  /// Get complete service history for a serial number
  Future<ComputerSerialHistory> getSerialHistory(String serialNumber) async {
    final response = await _apiClient.get(
      '/computer/serials/$serialNumber/history',
    );
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return ComputerSerialHistory.fromJson(raw['data'] ?? raw);
    }
    throw Exception('Failed to load serial history: ${response.error}');
  }

  // ==========================================================================
  // MULTI-UNIT SUPPORT (CRITICAL FIX)
  // ==========================================================================

  /// Configure multi-unit conversion for a product
  Future<void> setMultiUnitConversion(MultiUnitConfig config) async {
    final response = await _apiClient.post(
      '/computer/products/multi-unit',
      body: {
        'productId': config.productId,
        'primaryUnit': config.primaryUnit,
        'alternateUnit': config.alternateUnit,
        'conversionRate': config.conversionRate,
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to set multi-unit conversion: ${response.error}');
    }
  }

  /// Convert stock between units (e.g., box to pcs)
  Future<UnitConversionResult> convertStockUnit({
    required String productId,
    required String fromUnit,
    required String toUnit,
    required double quantity,
  }) async {
    final response = await _apiClient.post(
      '/computer/stock/convert-unit',
      body: {
        'productId': productId,
        'fromUnit': fromUnit,
        'toUnit': toUnit,
        'quantity': quantity,
      },
    );
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return UnitConversionResult.fromJson(raw['data'] ?? raw);
    }
    throw Exception('Failed to convert stock unit: ${response.error}');
  }

  // ==========================================================================
  // RMA (Return Merchandise Authorization)
  // ==========================================================================

  /// Create RMA
  Future<String> createRma({
    required String componentSerialId,
    required String brand,
    required String reason,
    String? oemRmaNumber,
  }) async {
    final response = await _apiClient.post(
      '/computer/rma',
      body: {
        'componentSerialId': componentSerialId,
        'brand': brand,
        'reason': reason,
        'oemRmaNumber': ?oemRmaNumber,
      },
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      final raw = response.data ?? {};
      return raw['id'] ?? raw['data']?['id'] ?? '';
    }
    throw Exception('Failed to create RMA: ${response.error}');
  }

  /// Update RMA status
  Future<void> updateRmaStatus(String rmaId, String status) async {
    final response = await _apiClient.patch(
      '/computer/rma/$rmaId/status',
      body: {'status': status},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update RMA status: ${response.error}');
    }
  }

  // ==========================================================================
  // SERIALS / COMPONENT TRACKING
  // ==========================================================================

  /// List component serials with optional invoice filter
  Future<List<Map<String, dynamic>>> getSerials({String? invoiceId}) async {
    final queryParams = <String, String>{};
    if (invoiceId != null) queryParams['invoiceId'] = invoiceId;

    final response = await _apiClient.get(
      '/computer/serials',
      queryParameters: queryParams,
    );
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      final List<dynamic> items = raw is List ? raw : (raw['data'] ?? []);
      return items.map((i) => i as Map<String, dynamic>).toList();
    }
    throw Exception('Failed to load serials: ${response.error}');
  }

  /// Checkout PC build with serial tracking
  Future<void> checkoutBuild({
    required List<Map<String, dynamic>> components,
    String? customerId,
    required String invoiceId,
  }) async {
    final response = await _apiClient.post(
      '/computer/checkout',
      body: {
        'components': components,
        'customerId': ?customerId,
        'invoiceId': invoiceId,
      },
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to checkout build: ${response.error}');
    }
  }
}
