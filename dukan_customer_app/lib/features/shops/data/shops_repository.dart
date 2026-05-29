import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx_shared/dukanx_shared.dart';
import '../../../core/di/providers.dart';

final linkedShopsProvider =
    FutureProvider<List<VendorConnection>>((ref) async {
  final client = ref.read(customerApiClientProvider);
  final response = await client.get('/customer/v1/connections');

  if (!response.isSuccess) {
    throw ApiException(
      statusCode: response.statusCode,
      message: response.error ?? 'Failed to load shops',
    );
  }

  final items =
      response.data!['connections'] as List<dynamic>? ?? [];
  return items
      .map((e) => VendorConnection.fromJson(e as Map<String, dynamic>))
      .toList();
});
