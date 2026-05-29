import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx_shared/dukanx_shared.dart';
import '../../../core/di/providers.dart';

final invoiceListProvider =
    FutureProvider.family<List<CustomerInvoice>, InvoiceStatus?>(
        (ref, status) async {
  final client = ref.read(customerApiClientProvider);
  final queryParams = <String, String>{};
  if (status != null) queryParams['status'] = status.name;

  final response = await client.get(
    '/customer/v1/invoices',
    queryParams: queryParams.isEmpty ? null : queryParams,
  );

  if (!response.isSuccess) {
    throw ApiException(
      statusCode: response.statusCode,
      message: response.error ?? 'Failed to load invoices',
    );
  }

  final items = response.data!['invoices'] as List<dynamic>? ?? [];
  return items
      .map((e) => CustomerInvoice.fromJson(e as Map<String, dynamic>))
      .toList();
});

final invoiceDetailProvider =
    FutureProvider.family<CustomerInvoice, String>((ref, id) async {
  final client = ref.read(customerApiClientProvider);
  final response = await client.get('/customer/v1/invoices/$id');

  if (!response.isSuccess) {
    throw ApiException(
      statusCode: response.statusCode,
      message: response.error ?? 'Invoice not found',
    );
  }

  return CustomerInvoice.fromJson(response.data!);
});
