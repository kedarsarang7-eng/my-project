// Phase 4 — BulkImportService now actually persists CSV rows (previously a stub
// that instantiated Product without saving). The change is "parse rows and call
// createProduct for each". We verify with a fake ProductsRepository that
// records calls, isolating the parse/persist logic from the sync/auth stack.

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/error/error_handler.dart';
import 'package:dukanx/core/repository/products_repository.dart';
import 'package:dukanx/core/services/bulk_import_service.dart';

/// Records createProduct calls instead of touching the database. Exposes the
/// captured args so the test can assert what BulkImportService forwarded.
class _RecordingProductsRepository implements ProductsRepository {
  final List<Map<String, Object?>> created = [];

  @override
  Future<RepositoryResult<Product>> createProduct({
    required String userId,
    required String name,
    String? sku,
    String? barcode,
    String? category,
    String unit = 'pcs',
    required double sellingPrice,
    double costPrice = 0,
    double taxRate = 0,
    double stockQuantity = 0,
    double lowStockThreshold = 10,
    String? size,
    String? color,
    String? brand,
    String? hsnCode,
    List<String>? altBarcodes,
    String? drugSchedule,
    String? groupId,
    Map<String, String>? variantAttributes,
    List<Map<String, dynamic>>? initialBatches,
    List<String>? initialImeis,
  }) async {
    created.add({
      'userId': userId,
      'name': name,
      'sku': sku,
      'category': category,
      'sellingPrice': sellingPrice,
      'costPrice': costPrice,
      'stockQuantity': stockQuantity,
    });
    return RepositoryResult.success(null);
  }

  @override
  dynamic noSuchMethod(Invocation inv) =>
      throw UnimplementedError('Not used in this test: ${inv.memberName}');
}

void main() {
  late _RecordingProductsRepository repo;
  const userId = 'bulk_import_user';

  setUp(() => repo = _RecordingProductsRepository());

  test('importItemsFromCsv forwards every valid row to createProduct',
      () async {
    const csv =
        'Name,SKU,Category,SellingPrice,CostPrice,Stock\n'
        'Basmati Rice 5kg,RICE5,Groceries,499,420,30\n'
        'Toor Dal,TOOR1,Groceries,160,140,50\n'
        ',EMPTY,,0,0,0\n' // skipped: empty name
        'Bad Row\n'; // skipped: too few columns

    final service = BulkImportService(repo);
    final count = await service.importItemsFromCsv(csv, userId);

    expect(count, 2);
    expect(repo.created.length, 2);
    expect(repo.created.map((m) => m['name']).toList(),
        ['Basmati Rice 5kg', 'Toor Dal']);
    final first = repo.created.first;
    expect(first['sku'], 'RICE5');
    expect(first['category'], 'Groceries');
    expect(first['sellingPrice'], 499.0);
    expect(first['costPrice'], 420.0);
    expect(first['stockQuantity'], 30.0);
  });

  test('blank cells become null (not empty strings) for optional fields',
      () async {
    const csv =
        'Name,SKU,Category,SellingPrice,CostPrice,Stock\n'
        'Loose Item,,,100,0,0\n';

    final service = BulkImportService(repo);
    await service.importItemsFromCsv(csv, userId);

    expect(repo.created.length, 1);
    expect(repo.created.single['sku'], isNull);
    expect(repo.created.single['category'], isNull);
    expect(repo.created.single['sellingPrice'], 100.0);
  });

  test('empty CSV persists nothing', () async {
    final service = BulkImportService(repo);
    expect(await service.importItemsFromCsv('', userId), 0);
    expect(repo.created, isEmpty);
  });
}
