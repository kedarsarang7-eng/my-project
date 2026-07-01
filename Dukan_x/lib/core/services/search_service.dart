import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/di/service_locator.dart';
import '../../../core/session/session_manager.dart';
import '../../../config/api_config.dart';

/// Entity types supported by the search service
enum SearchEntityType {
  bills,
  customers,
  products,
  productBatches,
  suppliers,
  purchaseBills,
  patients,
  visits,
  prescriptions,
  kots,
  menuItems,
  ledgerEntries,
  expenses,
  bankTransactions,
  deliveryChallans,
  bookReturns,
  preOrders,
  serviceJobs,
  eInvoices,
  fuelTransactions,
}

/// Search result model
class SearchResult<T> {
  final List<T> results;
  final int total;
  final int page;
  final int pageSize;
  final Map<String, dynamic>? aggregations;

  SearchResult({
    required this.results,
    required this.total,
    required this.page,
    required this.pageSize,
    this.aggregations,
  });

  factory SearchResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final results = (json['results'] as List<dynamic>?)
        ?.map((e) => fromJson(e as Map<String, dynamic>))
        .toList() ??
        [];

    return SearchResult(
      results: results,
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 20,
      aggregations: json['aggregations'] as Map<String, dynamic>?,
    );
  }

  bool get hasMore => (page * pageSize) < total;
}

/// Suggestion model for autocomplete
class SearchSuggestion {
  final String text;
  final String type;
  final String id;
  final String? highlight;

  SearchSuggestion({
    required this.text,
    required this.type,
    required this.id,
    this.highlight,
  });

  factory SearchSuggestion.fromJson(Map<String, dynamic> json) {
    return SearchSuggestion(
      text: json['text'] as String,
      type: json['type'] as String,
      id: json['id'] as String,
      highlight: json['highlight'] as String?,
    );
  }
}

/// Search parameters
class SearchParams {
  final String query;
  final int page;
  final int pageSize;
  final String? sortBy;
  final String? sortOrder;
  final String? businessType;
  final String? status;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final double? minAmount;
  final double? maxAmount;

  SearchParams({
    this.query = '',
    this.page = 1,
    this.pageSize = 20,
    this.sortBy,
    this.sortOrder = 'desc',
    this.businessType,
    this.status,
    this.dateFrom,
    this.dateTo,
    this.minAmount,
    this.maxAmount,
  });

  Map<String, String> toQueryParams() {
    final params = <String, String>{
      'q': query,
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };

    if (sortBy != null) params['sortBy'] = sortBy!;
    if (sortOrder != null) params['sortOrder'] = sortOrder!;
    if (businessType != null) params['businessType'] = businessType!;
    if (status != null) params['status'] = status!;
    if (dateFrom != null) params['dateFrom'] = dateFrom!.toIso8601String();
    if (dateTo != null) params['dateTo'] = dateTo!.toIso8601String();
    if (minAmount != null) params['minAmount'] = minAmount!.toString();
    if (maxAmount != null) params['maxAmount'] = maxAmount!.toString();

    return params;
  }
}

/// Advanced filter configuration
class AdvancedFilter {
  final dynamic eq;
  final List<dynamic>? in_;
  final Map<String, dynamic>? range;
  final String? match;
  final bool? exists;

  AdvancedFilter({
    this.eq,
    this.in_,
    this.range,
    this.match,
    this.exists,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (eq != null) json['eq'] = eq;
    if (in_ != null) json['in'] = in_;
    if (range != null) json['range'] = range;
    if (match != null) json['match'] = match;
    if (exists != null) json['exists'] = exists;
    return json;
  }
}

/// Advanced search request
class AdvancedSearchRequest {
  final String? query;
  final Map<String, AdvancedFilter>? filters;
  final int? page;
  final int? pageSize;
  final String? sortBy;
  final String? sortOrder;
  final Map<String, dynamic>? aggregations;
  final List<String>? fields;

  AdvancedSearchRequest({
    this.query,
    this.filters,
    this.page,
    this.pageSize,
    this.sortBy,
    this.sortOrder,
    this.aggregations,
    this.fields,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (query != null) json['query'] = query;
    if (filters != null) {
      json['filters'] = filters!.map((k, v) => MapEntry(k, v.toJson()));
    }
    if (page != null) json['page'] = page;
    if (pageSize != null) json['pageSize'] = pageSize;
    if (sortBy != null) json['sortBy'] = sortBy;
    if (sortOrder != null) json['sortOrder'] = sortOrder;
    if (aggregations != null) json['aggregations'] = aggregations;
    if (fields != null) json['fields'] = fields;
    return json;
  }
}

/// Search Service for AWS OpenSearch integration
/// 
/// Provides fast, multi-tenant search across all business entities.
/// Automatically handles authentication and tenant isolation.
class SearchService {
  static final SearchService _instance = SearchService._internal();
  factory SearchService() => _instance;
  SearchService._internal();

  SessionManager get _session => sl<SessionManager>();
  String get _baseUrl => ApiConfig.baseUrl;

  /// Search for entities
  /// 
  /// [entityType] - The type of entity to search
  /// [params] - Search parameters including query, filters, pagination
  /// [fromJson] - Function to parse the result items
  /// 
  /// Returns a [SearchResult] containing the matching items and metadata.
  Future<SearchResult<T>> search<T>({
    required SearchEntityType entityType,
    required SearchParams params,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    try {
      final token = await _session.getAccessToken();
      final businessId = _session.ownerId;

      final uri = Uri.parse('$_baseUrl/search/${_entityTypeToString(entityType)}')
          .replace(queryParameters: params.toQueryParams());

      final response = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'X-Business-Id': ?businessId,
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return SearchResult.fromJson(json, fromJson);
      } else if (response.statusCode == 503) {
        // Search service not configured - fallback to offline
        throw SearchOfflineException('Search service unavailable, using offline mode');
      } else {
        throw SearchException(
          'Search failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      if (e is SearchOfflineException) rethrow;
      throw SearchException('Search error: $e');
    }
  }

  /// Advanced search with complex filters
  /// 
  /// [entityType] - The type of entity to search
  /// [request] - Advanced search request with filters
  /// [fromJson] - Function to parse the result items
  Future<SearchResult<T>> advancedSearch<T>({
    required SearchEntityType entityType,
    required AdvancedSearchRequest request,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    try {
      final token = await _session.getAccessToken();
      final businessId = _session.ownerId;

      final uri = Uri.parse(
        '$_baseUrl/search/${_entityTypeToString(entityType)}/advanced',
      );

      final response = await http.post(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'X-Business-Id': ?businessId,
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return SearchResult.fromJson(json, fromJson);
      } else {
        throw SearchException(
          'Advanced search failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw SearchException('Advanced search error: $e');
    }
  }

  /// Get autocomplete suggestions
  /// 
  /// [query] - The partial query to get suggestions for
  /// [entityType] - Optional entity type to restrict suggestions
  /// 
  /// Returns a list of [SearchSuggestion] objects.
  Future<List<SearchSuggestion>> getSuggestions({
    required String query,
    SearchEntityType? entityType,
  }) async {
    if (query.length < 2) return [];

    try {
      final token = await _session.getAccessToken();

      final params = <String, String>{'q': query};
      if (entityType != null) {
        params['entity'] = _entityTypeToString(entityType);
      }

      final uri = Uri.parse('$_baseUrl/search/suggest')
          .replace(queryParameters: params);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final suggestions = (json['suggestions'] as List<dynamic>?)
            ?.map((e) => SearchSuggestion.fromJson(e as Map<String, dynamic>))
            .toList() ??
            [];
        return suggestions;
      } else {
        return [];
      }
    } catch (e) {
      // Silently fail for suggestions - they're optional
      return [];
    }
  }

  /// Search customers by name or phone
  /// Convenience method for customer search
  Future<SearchResult<Map<String, dynamic>>> searchCustomers(String query, {
    int page = 1,
    int pageSize = 20,
  }) async {
    return search(
      entityType: SearchEntityType.customers,
      params: SearchParams(query: query, page: page, pageSize: pageSize),
      fromJson: (json) => json,
    );
  }

  /// Search products by name, SKU, or barcode
  /// Convenience method for product search
  Future<SearchResult<Map<String, dynamic>>> searchProducts(String query, {
    int page = 1,
    int pageSize = 20,
    String? category,
  }) async {
    final filters = <String, AdvancedFilter>{};
    if (category != null) {
      filters['category'] = AdvancedFilter(eq: category);
    }

    return advancedSearch(
      entityType: SearchEntityType.products,
      request: AdvancedSearchRequest(
        query: query,
        filters: filters.isNotEmpty ? filters : null,
        page: page,
        pageSize: pageSize,
      ),
      fromJson: (json) => json,
    );
  }

  /// Search bills by customer name or invoice number
  /// Convenience method for bill search
  Future<SearchResult<Map<String, dynamic>>> searchBills(String query, {
    int page = 1,
    int pageSize = 20,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    return search(
      entityType: SearchEntityType.bills,
      params: SearchParams(
        query: query,
        page: page,
        pageSize: pageSize,
        dateFrom: dateFrom,
        dateTo: dateTo,
        sortBy: 'billDate',
        sortOrder: 'desc',
      ),
      fromJson: (json) => json,
    );
  }

  /// Search patients (for clinic/pharmacy)
  /// Convenience method for patient search
  Future<SearchResult<Map<String, dynamic>>> searchPatients(String query, {
    int page = 1,
    int pageSize = 20,
  }) async {
    return search(
      entityType: SearchEntityType.patients,
      params: SearchParams(query: query, page: page, pageSize: pageSize),
      fromJson: (json) => json,
    );
  }

  String _entityTypeToString(SearchEntityType type) {
    switch (type) {
      case SearchEntityType.bills:
        return 'bills';
      case SearchEntityType.customers:
        return 'customers';
      case SearchEntityType.products:
        return 'products';
      case SearchEntityType.productBatches:
        return 'product-batches';
      case SearchEntityType.suppliers:
        return 'suppliers';
      case SearchEntityType.purchaseBills:
        return 'purchase-bills';
      case SearchEntityType.patients:
        return 'patients';
      case SearchEntityType.visits:
        return 'visits';
      case SearchEntityType.prescriptions:
        return 'prescriptions';
      case SearchEntityType.kots:
        return 'kots';
      case SearchEntityType.menuItems:
        return 'menu-items';
      case SearchEntityType.ledgerEntries:
        return 'ledger-entries';
      case SearchEntityType.expenses:
        return 'expenses';
      case SearchEntityType.bankTransactions:
        return 'bank-transactions';
      case SearchEntityType.deliveryChallans:
        return 'delivery-challans';
      case SearchEntityType.bookReturns:
        return 'book-returns';
      case SearchEntityType.preOrders:
        return 'pre-orders';
      case SearchEntityType.serviceJobs:
        return 'service-jobs';
      case SearchEntityType.eInvoices:
        return 'einvoices';
      case SearchEntityType.fuelTransactions:
        return 'fuel-transactions';
    }
  }
}

/// Search exception
class SearchException implements Exception {
  final String message;
  SearchException(this.message);

  @override
  String toString() => 'SearchException: $message';
}

/// Search offline exception
/// Thrown when online search is unavailable and offline mode should be used
class SearchOfflineException implements Exception {
  final String message;
  SearchOfflineException(this.message);

  @override
  String toString() => 'SearchOfflineException: $message';
}
