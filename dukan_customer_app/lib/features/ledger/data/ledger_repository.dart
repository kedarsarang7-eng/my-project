import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx_shared/dukanx_shared.dart';
import '../../../core/di/providers.dart';

class LedgerBalance {
  final double totalDebit;
  final double totalCredit;
  final double netBalance;

  const LedgerBalance({
    required this.totalDebit,
    required this.totalCredit,
    required this.netBalance,
  });

  factory LedgerBalance.fromJson(Map<String, dynamic> json) => LedgerBalance(
        totalDebit: (json['totalDebit'] as num? ?? 0).toDouble(),
        totalCredit: (json['totalCredit'] as num? ?? 0).toDouble(),
        netBalance: (json['netBalance'] as num? ?? 0).toDouble(),
      );
}

final ledgerEntriesProvider =
    FutureProvider.family<List<LedgerEntry>, String?>((ref, vendorId) async {
  final client = ref.read(customerApiClientProvider);
  final queryParams = vendorId != null ? {'vendorId': vendorId} : null;
  final response =
      await client.get('/customer/v1/ledger', queryParams: queryParams);

  if (!response.isSuccess) {
    throw ApiException(
      statusCode: response.statusCode,
      message: response.error ?? 'Failed to load ledger',
    );
  }

  final items = response.data!['entries'] as List<dynamic>? ?? [];
  return items
      .map((e) => LedgerEntry.fromJson(e as Map<String, dynamic>))
      .toList();
});

final ledgerBalanceProvider =
    FutureProvider.family<LedgerBalance, String?>((ref, vendorId) async {
  final client = ref.read(customerApiClientProvider);
  final queryParams = vendorId != null ? {'vendorId': vendorId} : null;
  final response =
      await client.get('/customer/v1/ledger/balance', queryParams: queryParams);

  if (!response.isSuccess) {
    throw ApiException(
      statusCode: response.statusCode,
      message: response.error ?? 'Failed to load balance',
    );
  }

  return LedgerBalance.fromJson(response.data!);
});
