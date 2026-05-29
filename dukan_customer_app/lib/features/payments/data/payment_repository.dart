import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx_shared/dukanx_shared.dart';
import '../../../core/di/providers.dart';

class PaymentRepository {
  final CustomerApiClient _client;
  const PaymentRepository(this._client);

  Future<void> recordPayment({
    required String vendorId,
    required double amount,
    required PaymentMethod method,
    String? notes,
    String? referenceNumber,
  }) async {
    final response = await _client.post(
      '/customer/v1/payments',
      body: {
        'vendorId': vendorId,
        'amount': amount,
        'paymentMethod': method.name,
        'notes': ?notes,
        'referenceNumber': ?referenceNumber,
        'paymentDate': DateTime.now().toIso8601String(),
      },
    );

    if (!response.isSuccess) {
      throw ApiException(
        statusCode: response.statusCode,
        message: response.error ?? 'Failed to record payment',
      );
    }
  }

  Future<List<CustomerPayment>> getPaymentHistory({String? vendorId}) async {
    final queryParams = vendorId != null ? {'vendorId': vendorId} : null;
    final response =
        await _client.get('/customer/v1/payments', queryParams: queryParams);

    if (!response.isSuccess) {
      throw ApiException(
        statusCode: response.statusCode,
        message: response.error ?? 'Failed to load payments',
      );
    }

    final items = response.data!['payments'] as List<dynamic>? ?? [];
    return items
        .map((e) => CustomerPayment.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.read(customerApiClientProvider));
});
