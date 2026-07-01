import '../../../../core/api/api_client.dart';
import '../models/customer_model.dart';

/// Live rolled-up balance summary for a customer (Part 2 — GET /customers/{id}/profile).
///
/// Mirrors the backend `balance` object. All amounts are in whole rupees
/// (the API returns `*Cents`; we convert on parse). Used to hydrate the detail
/// screen with fresh totals that the offline-first local cache cannot guarantee.
class CustomerProfileBalance {
  final double totalBilled;
  final double totalPaid;
  final double outstanding;
  final int invoiceCount;
  final int paymentCount;
  final DateTime? lastInvoiceAt;
  final DateTime? lastPaymentAt;

  const CustomerProfileBalance({
    this.totalBilled = 0,
    this.totalPaid = 0,
    this.outstanding = 0,
    this.invoiceCount = 0,
    this.paymentCount = 0,
    this.lastInvoiceAt,
    this.lastPaymentAt,
  });

  factory CustomerProfileBalance.fromJson(Map<String, dynamic> json) {
    double centsToRupees(num? v) => (v ?? 0) / 100.0;
    return CustomerProfileBalance(
      totalBilled: centsToRupees(json['totalBilledCents'] as num?),
      totalPaid: centsToRupees(json['totalPaidCents'] as num?),
      outstanding: centsToRupees(json['outstandingCents'] as num?),
      invoiceCount: (json['invoiceCount'] as num?)?.toInt() ?? 0,
      paymentCount: (json['paymentCount'] as num?)?.toInt() ?? 0,
      lastInvoiceAt: json['lastInvoiceAt'] != null
          ? DateTime.tryParse(json['lastInvoiceAt'].toString())
          : null,
      lastPaymentAt: json['lastPaymentAt'] != null
          ? DateTime.tryParse(json['lastPaymentAt'].toString())
          : null,
    );
  }
}

/// Repository for Customer Management operations
class CustomerRepository {
  final ApiClient _apiClient;

  CustomerRepository(this._apiClient);

  Future<List<Customer>> getCustomers({
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null) params['search'] = search;

    final response = await _apiClient.get('/customers', queryParams: params);

    if (response.statusCode == 200) {
      final data = response.data ?? {};
      final items =
          data['items'] ?? data['customers'] ?? (data is List ? data : []);
      return (items as List)
          .map((e) => Customer.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load customers: ${response.error}');
  }

  Future<void> deleteCustomer(String id) async {
    final response = await _apiClient.delete('/customers/$id');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete customer: ${response.error}');
    }
  }

  Future<void> restoreCustomer(String id) async {
    final response = await _apiClient.post('/customers/$id/restore');
    if (response.statusCode != 200) {
      throw Exception('Failed to restore customer: ${response.error}');
    }
  }

  Future<void> setCustomerBlockStatus(
    String id, {
    required bool isBlocked,
    String? reason,
  }) async {
    final response = await _apiClient.patch(
      '/customers/$id/block',
      body: {'isBlocked': isBlocked, 'reason': ?reason},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update block status: ${response.error}');
    }
  }

  /// Fetch the consolidated profile + rolled-up balance (Part 2).
  ///
  /// Returns `null` on any failure so callers can silently fall back to the
  /// offline-first local cache — this is a display enhancement, not a hard
  /// dependency, so it must never break the detail screen when offline.
  Future<CustomerProfileBalance?> getCustomerProfileBalance(String id) async {
    try {
      final response = await _apiClient.get('/customers/$id/profile');
      if (response.statusCode != 200) return null;
      final data = response.data ?? {};
      final balanceJson = data['balance'];
      if (balanceJson is! Map<String, dynamic>) return null;
      return CustomerProfileBalance.fromJson(balanceJson);
    } catch (_) {
      return null;
    }
  }
}
