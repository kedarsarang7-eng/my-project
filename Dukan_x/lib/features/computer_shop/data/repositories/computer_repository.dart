// ============================================================================
// COMPUTER SHOP — API Repository
// ============================================================================
// Integrates with Lambda backend via ApiClient
// All amounts in paise on wire, converted to rupees in models
// CRITICAL FIX: This file was created to address audit findings
// ============================================================================

import 'dart:async';

import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/core/di/service_locator.dart';
import 'package:dukanx/core/session/session_manager.dart';

import '../../../../core/api/api_client.dart';
import '../../utils/computer_shop_business_rules.dart';
import '../../utils/job_status_codec.dart';
import '../../utils/money.dart';
import 'computer_shop_cache.dart';

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

  /// Canonical job lifecycle status. Parsed from the backend wire string
  /// via [JobStatusCodec.fromWire] at the repository boundary.
  final ComputerJobStatus status;

  final String? technicianId;
  final String? technicianName;
  final String? diagnosis;

  /// Estimated labor cost in rupees (₹). Converted from paise at the
  /// repository boundary via the Money helper.
  final double? estimatedLaborCost;

  /// Actual labor cost in rupees (₹). Converted from paise at the
  /// repository boundary via the Money helper.
  final double? actualLaborCost;

  /// Actual parts cost in rupees (₹). Converted from paise at the
  /// repository boundary via the Money helper.
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
      status: _parseStatus(json['status']),
      technicianId: json['technicianId'],
      technicianName: json['technicianName'],
      diagnosis: json['diagnosis'],
      estimatedLaborCost: json['estimatedLaborCost'] != null
          ? Money.paiseToRupeesOr(json['estimatedLaborCost'], 0.0)
          : null,
      actualLaborCost: json['actualLaborCost'] != null
          ? Money.paiseToRupeesOr(json['actualLaborCost'], 0.0)
          : null,
      actualPartsCost: json['actualPartsCost'] != null
          ? Money.paiseToRupeesOr(json['actualPartsCost'], 0.0)
          : null,
      invoiceId: json['invoiceId'],
      invoiceNumber: json['invoiceNumber'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  /// Parses the status field from JSON. Accepts either a [ComputerJobStatus]
  /// value directly (when the repository has already converted it) or a raw
  /// wire string (converted via [JobStatusCodec.fromWire]).
  static ComputerJobStatus _parseStatus(dynamic raw) {
    if (raw is ComputerJobStatus) return raw;
    if (raw is String) {
      return JobStatusCodec.fromWire(raw) ?? ComputerJobStatus.intake;
    }
    return ComputerJobStatus.intake;
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
      unitPrice: Money.paiseToRupeesOr(json['unitPrice'], 0.0),
      totalCost: Money.paiseToRupeesOr(json['totalCost'], 0.0),
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

/// Result of a bulk serial intake submission (Req 12).
///
/// [accepted] holds the serials the backend persisted; [rejected] holds any
/// serials the backend itself declined (e.g. already existing for the
/// tenant) along with a human-readable reason for each.
class BulkSerialIntakeResult {
  final List<String> accepted;
  final List<BulkSerialRejection> rejected;

  BulkSerialIntakeResult({required this.accepted, required this.rejected});

  factory BulkSerialIntakeResult.fromJson(Map<String, dynamic> json) {
    return BulkSerialIntakeResult(
      accepted: (json['accepted'] as List? ?? [])
          .map((s) => s.toString())
          .toList(),
      rejected: (json['rejected'] as List? ?? [])
          .map((r) => BulkSerialRejection.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A single rejected serial and the reason it was rejected, as reported by
/// either client-side validation or the backend (Req 12.3).
class BulkSerialRejection {
  final String serial;
  final String reason;

  BulkSerialRejection({required this.serial, required this.reason});

  factory BulkSerialRejection.fromJson(Map<String, dynamic> json) {
    return BulkSerialRejection(
      serial: json['serial']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
    );
  }
}

/// Computer Shop Repository
class ComputerRepository {
  final ApiClient _apiClient;

  /// Offline read cache (Drift-backed). Defaults to a cache wrapping the
  /// shared [AppDatabase] instance so existing call sites (`ComputerRepository(apiClient)`)
  /// keep working unchanged; tests may inject a fake via the named parameter.
  final ComputerShopCache _cache;

  ComputerRepository(this._apiClient, {ComputerShopCache? cache})
    : _cache = cache ?? ComputerShopCache(sl<AppDatabase>());

  /// The current tenant id used to scope cache reads/writes. Cache rows are
  /// only ever written/read for this id, matching the app-wide
  /// `tenantId = SessionManager.userId` isolation rule. Falls back to an
  /// empty string when no session is active (cache is effectively skipped).
  String get _tenantId {
    try {
      return sl<SessionManager>().userId ?? '';
    } catch (_) {
      return '';
    }
  }

  /// True when [response] indicates the call failed for a connectivity
  /// reason (offline, network error, timeout, connection failed) rather
  /// than a genuine backend/business error. Used to decide whether to fall
  /// back to the offline cache instead of throwing (Req 26.2).
  bool _isOfflineFailure(ApiResponse response) => response.isNetworkError;

  // ==========================================================================
  // JOB CARDS
  // ==========================================================================

  /// Converts outgoing money fields in a job card data map from rupees to paise.
  ///
  /// Only processes known money field keys; all other fields pass through unchanged.
  static const _moneyFields = {
    'estimatedLaborCost',
    'actualLaborCost',
    'actualPartsCost',
  };

  Map<String, dynamic> _convertOutgoingMoney(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);
    for (final field in _moneyFields) {
      if (result.containsKey(field) && result[field] != null) {
        final value = result[field];
        if (value is num) {
          result[field] = Money.rupeesToPaise(value.toDouble());
        }
      }
    }
    // Convert status from enum to wire string if present
    if (result.containsKey('status') && result['status'] is ComputerJobStatus) {
      result['status'] = JobStatusCodec.toWire(
        result['status'] as ComputerJobStatus,
      );
    }
    return result;
  }

  /// List all job cards with optional status filter.
  ///
  /// The [status] parameter, if provided, should be a wire-format string
  /// (e.g., 'INTAKE'). Use [JobStatusCodec.toWire] to convert from the
  /// canonical enum.
  ///
  /// On success, every returned job card is cached (write-through) for
  /// offline reads (Req 26.1). When the call fails for a connectivity
  /// reason, the result is served from the offline cache instead of
  /// throwing (Req 26.2); a genuine backend/business error still throws.
  Future<PaginatedResponse<ComputerJobCard>> listJobCards({
    ComputerJobStatus? status,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null) queryParams['status'] = JobStatusCodec.toWire(status);

    final response = await _apiClient.get(
      '/computer/job-cards',
      queryParameters: queryParams,
    );

    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      final data = raw['data'] ?? raw;
      final List<dynamic> items = data is List ? data : (data['items'] ?? []);
      final jsonItems = items.cast<Map<String, dynamic>>();

      unawaited(
        _cache.upsertJobCards(tenantId: _tenantId, payloads: jsonItems),
      );

      return PaginatedResponse(
        items: jsonItems.map((json) => ComputerJobCard.fromJson(json)).toList(),
        total: data['total'] ?? items.length,
        page: data['page'] ?? page,
        limit: data['limit'] ?? limit,
        totalPages: data['totalPages'] ?? 1,
      );
    }

    if (_isOfflineFailure(response)) {
      final cached = await _cache.getCachedJobCards(tenantId: _tenantId);
      final filtered = status == null
          ? cached
          : cached
                .where(
                  (j) =>
                      j['status']?.toString() == JobStatusCodec.toWire(status),
                )
                .toList();
      return PaginatedResponse(
        items: filtered.map((json) => ComputerJobCard.fromJson(json)).toList(),
        total: filtered.length,
        page: 1,
        limit: filtered.length,
        totalPages: 1,
      );
    }

    throw Exception('Failed to load job cards: ${response.error}');
  }

  /// Create a new job card
  ///
  /// Money fields in [data] (estimatedLaborCost, actualLaborCost, actualPartsCost)
  /// are expected in rupees and are converted to paise before sending to the backend.
  Future<ComputerJobCard> createJobCard(Map<String, dynamic> data) async {
    final wireData = _convertOutgoingMoney(data);
    final response = await _apiClient.post(
      '/computer/job-cards',
      body: wireData,
    );
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

  /// Get a single job card by ID.
  ///
  /// Caches the result on success (Req 26.1) and falls back to the offline
  /// cache when the call fails for a connectivity reason (Req 26.2).
  Future<ComputerJobCard> getJobCard(String id) async {
    final response = await _apiClient.get('/computer/job-cards/$id');
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      final json = (raw['data'] ?? raw) as Map<String, dynamic>;
      unawaited(
        _cache.upsertJobCard(tenantId: _tenantId, id: id, payload: json),
      );
      return ComputerJobCard.fromJson(json);
    }

    if (_isOfflineFailure(response)) {
      final cached = await _cache.getCachedJobCard(tenantId: _tenantId, id: id);
      if (cached != null) return ComputerJobCard.fromJson(cached);
    }

    throw Exception('Failed to load job card: ${response.error}');
  }

  /// Searches job cards across the tenant's FULL dataset (not just the
  /// currently-loaded page) by brand/model/serial/reported-issue substring
  /// match (Req 27.1, 27.2).
  ///
  /// [query] must be non-empty; callers are responsible for not invoking
  /// this for an empty query (Req 27.5 — the paginated list should be shown
  /// instead). The call is bounded to a 10s timeout (Req 27.4); a timeout
  /// surfaces as a [TimeoutException] which callers should treat as an
  /// error state that retains the prior results (Req 27.4).
  Future<List<ComputerJobCard>> searchJobCards(String query) async {
    final response = await _apiClient
        .get('/computer/job-cards', queryParameters: {'search': query})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      final data = raw['data'] ?? raw;
      final List<dynamic> items = data is List ? data : (data['items'] ?? []);
      return items
          .cast<Map<String, dynamic>>()
          .map((json) => ComputerJobCard.fromJson(json))
          .toList();
    }

    throw Exception('Failed to search job cards: ${response.error}');
  }

  /// Update job card status.
  ///
  /// Accepts the canonical [ComputerJobStatus] and converts to the wire
  /// string via [JobStatusCodec.toWire] before sending to the backend.
  Future<void> updateJobCardStatus(
    String id,
    ComputerJobStatus status, {
    String? techNotes,
  }) async {
    final response = await _apiClient.patch(
      '/computer/job-cards/$id/status',
      body: {'status': JobStatusCodec.toWire(status), 'techNotes': ?techNotes},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update status: ${response.error}');
    }
  }

  // ==========================================================================
  // JOB PARTS (CRITICAL FIX)
  // ==========================================================================

  /// Add a part to a job card (deducts inventory).
  ///
  /// [unitPrice] is expected in rupees and is converted to paise before
  /// sending to the backend.
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
        'unitPrice': Money.rupeesToPaise(unitPrice),
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

  /// Update labor costs and diagnosis.
  ///
  /// [estimatedLaborCost] and [actualLaborCost] are expected in rupees and
  /// are converted to paise before sending to the backend.
  Future<void> updateLaborCost(
    String jobCardId, {
    double? estimatedLaborCost,
    double? actualLaborCost,
    String? diagnosis,
  }) async {
    final body = <String, dynamic>{};
    if (estimatedLaborCost != null)
      body['estimatedLaborCost'] = Money.rupeesToPaise(estimatedLaborCost);
    if (actualLaborCost != null)
      body['actualLaborCost'] = Money.rupeesToPaise(actualLaborCost);
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

  /// Convert completed job to invoice.
  ///
  /// [discount] is expected in rupees and is converted to paise (discountCents)
  /// before sending to the backend.
  Future<Map<String, dynamic>> convertJobToInvoice(
    String jobCardId, {
    required String customerName,
    String? customerPhone,
    String paymentMode = 'cash',
    String? notes,
    double discount = 0,
  }) async {
    final response = await _apiClient.post(
      '/computer/job-cards/$jobCardId/convert-to-invoice',
      body: {
        'customerName': customerName,
        'customerPhone': ?customerPhone,
        'paymentMode': paymentMode,
        'notes': ?notes,
        'discountCents': Money.rupeesToPaise(discount),
      },
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      final raw = response.data ?? {};
      return raw['data'] ?? raw;
    }
    throw Exception('Failed to convert job to invoice: ${response.error}');
  }

  /// Fetch a previously created invoice by its identifier.
  ///
  /// Used by Job_Card_Detail_Screen's "Open Invoice" control to open the
  /// invoice created by [convertJobToInvoice] (Req 16.2, 16.4). Amount
  /// fields on the response are in paise; callers converting to a display
  /// model should divide by 100.
  Future<Map<String, dynamic>> getInvoiceById(String invoiceId) async {
    final response = await _apiClient.get('/payments/$invoiceId');
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      return raw['data'] ?? raw;
    }
    throw Exception('Failed to load invoice: ${response.error}');
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

  /// Get warranty by serial number or warranty ID.
  ///
  /// Caches the result on success (Req 26.1) and falls back to the offline
  /// cache — looked up by serial number or warranty id, whichever was
  /// provided — when the call fails for a connectivity reason (Req 26.2).
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
      final json = (raw['data'] ?? raw) as Map<String, dynamic>;
      final warranty = ComputerWarranty.fromJson(json);
      unawaited(
        _cache.upsertWarranty(
          tenantId: _tenantId,
          id: warranty.id,
          serialNumber: warranty.serialNumber,
          payload: json,
          warrantyExpiryDate: DateTime.tryParse(warranty.warrantyExpiryDate),
        ),
      );
      return warranty;
    }

    if (_isOfflineFailure(response)) {
      final cached = serialNumber != null
          ? await _cache.getCachedWarrantyBySerial(
              tenantId: _tenantId,
              serialNumber: serialNumber,
            )
          : warrantyId != null
          ? await _cache.getCachedWarrantyById(
              tenantId: _tenantId,
              warrantyId: warrantyId,
            )
          : null;
      if (cached != null) return ComputerWarranty.fromJson(cached);
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
  // DASHBOARD ALERT COUNTS
  // ==========================================================================

  /// Returns the count of warranties whose end date falls within
  /// [today, today + 30 days] inclusive.
  ///
  /// Used by [computerShopAlertCountsProvider] for the "Warranty Expiring"
  /// dashboard metric.
  Future<int> getWarrantyExpiringCount() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final in30Days = today.add(const Duration(days: 30));

    final response = await _apiClient.get(
      '/computer/warranty',
      queryParameters: {
        'expiringFrom': today.toIso8601String().split('T').first,
        'expiringTo': in30Days.toIso8601String().split('T').first,
        'countOnly': 'true',
      },
    );
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      // The API may return { count: N } or { data: [...] } or { total: N }
      if (raw['count'] != null) return raw['count'] as int;
      if (raw['total'] != null) return raw['total'] as int;
      final data = raw['data'];
      if (data is List) return data.length;
      return 0;
    }
    throw Exception(
      'Failed to load warranty expiring count: ${response.error}',
    );
  }

  /// Returns the count of job cards whose status is NOT delivered or cancelled.
  ///
  /// Used by [computerShopAlertCountsProvider] for the "Pending Repairs"
  /// dashboard metric.
  Future<int> getPendingRepairsCount() async {
    final response = await _apiClient.get(
      '/computer/job-cards',
      queryParameters: {
        'excludeStatus': 'DELIVERED,CANCELLED',
        'countOnly': 'true',
      },
    );
    if (response.statusCode == 200) {
      final raw = response.data ?? {};
      // The API may return { count: N } or { data: { total: N } } or items
      if (raw['count'] != null) return raw['count'] as int;
      if (raw['total'] != null) return raw['total'] as int;
      final data = raw['data'];
      if (data is Map) return data['total'] ?? 0;
      if (data is List) return data.length;
      return 0;
    }
    throw Exception('Failed to load pending repairs count: ${response.error}');
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

  /// List component serials with optional invoice filter.
  ///
  /// Caches every returned serial on success (Req 26.1). When the call
  /// fails for a connectivity reason, serves cached serials instead of
  /// throwing (Req 26.2); the [invoiceId] filter is not applied to the
  /// offline cache since invoice linkage is not indexed locally.
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
      final jsonItems = items.map((i) => i as Map<String, dynamic>).toList();
      unawaited(_cache.upsertSerials(tenantId: _tenantId, payloads: jsonItems));
      return jsonItems;
    }

    if (_isOfflineFailure(response)) {
      return _cache.getCachedSerials(tenantId: _tenantId);
    }

    throw Exception('Failed to load serials: ${response.error}');
  }

  /// Bulk-intake component serials (1-500 per submission).
  ///
  /// Sends the already-validated, de-duplicated [serials] to the backend for
  /// persistence against [productId]. Returns the set of accepted serials
  /// and any serials the backend itself rejected (e.g. already existing)
  /// along with a reason for each. Callers are responsible for enforcing the
  /// 1-500 bound and intra-submission duplicate/format checks before calling
  /// this method (Req 12.1, 12.2).
  Future<BulkSerialIntakeResult> bulkIntakeSerials({
    required String productId,
    required List<String> serials,
  }) async {
    final response = await _apiClient.post(
      '/computer/serials/bulk',
      body: {'productId': productId, 'serials': serials},
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      final raw = response.data ?? {};
      final data = raw['data'] ?? raw;
      return BulkSerialIntakeResult.fromJson(data);
    }
    throw Exception('Failed to persist serials: ${response.error}');
  }

  /// Checkout PC build with serial tracking.
  ///
  /// Returns a unit reference for the completed build when the backend
  /// response includes one (e.g. an `id`/`unitReference` field); returns
  /// `null` when the backend response carries no such identifier, in which
  /// case callers should fall back to displaying the invoice reference.
  Future<String?> checkoutBuild({
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
    final raw = response.data ?? {};
    final data = raw['data'] ?? raw;
    if (data is Map) {
      final ref = data['unitReference'] ?? data['unitId'] ?? data['id'];
      return ref?.toString();
    }
    return null;
  }
}
