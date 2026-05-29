import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx_shared/dukanx_shared.dart';
import '../../../core/di/providers.dart';

class HomeSummary {
  final double totalDue;
  final double totalPaid;
  final int linkedShopsCount;
  final int pendingInvoiceCount;

  const HomeSummary({
    required this.totalDue,
    required this.totalPaid,
    required this.linkedShopsCount,
    required this.pendingInvoiceCount,
  });

  factory HomeSummary.fromJson(Map<String, dynamic> json) {
    return HomeSummary(
      totalDue: (json['totalDue'] as num? ?? 0).toDouble(),
      totalPaid: (json['totalPaid'] as num? ?? 0).toDouble(),
      linkedShopsCount: (json['linkedShopsCount'] as int? ?? 0),
      pendingInvoiceCount: (json['pendingInvoiceCount'] as int? ?? 0),
    );
  }
}

final homeSummaryProvider = FutureProvider<HomeSummary>((ref) async {
  final client = ref.read(customerApiClientProvider);
  final response = await client.get('/customer/v1/summary');
  if (!response.isSuccess) {
    throw ApiException(
      statusCode: response.statusCode,
      message: response.error ?? 'Failed to load summary',
    );
  }
  return HomeSummary.fromJson(response.data!);
});

final recentShopsProvider = FutureProvider<List<VendorConnection>>((ref) async {
  final client = ref.read(customerApiClientProvider);
  final response = await client.get('/customer/v1/connections');
  if (!response.isSuccess) {
    throw ApiException(
      statusCode: response.statusCode,
      message: response.error ?? 'Failed to load shops',
    );
  }
  final items = response.data!['connections'] as List<dynamic>? ?? [];
  return items
      .map((e) => VendorConnection.fromJson(e as Map<String, dynamic>))
      .toList();
});
