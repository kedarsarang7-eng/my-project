import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/feature_flag_service.dart';

final variantRepositoryProvider = Provider<VariantRepository>((ref) {
  return VariantRepository(apiClient: sl<ApiClient>());
});

class VariantItem {
  final String id;
  final String productId;
  final String color;
  final String size;
  final String sku; // <= 64 chars
  final String barcode; // <= 64 chars
  final int priceCents; // integer Paise, >= 0
  final int stock; // integer count, >= 0

  VariantItem({
    required this.id,
    required this.productId,
    required this.color,
    required this.size,
    this.sku = '',
    this.barcode = '',
    this.priceCents = 0,
    this.stock = 0,
  }) : assert(sku.length <= 64, 'sku must be <= 64 chars'),
       assert(barcode.length <= 64, 'barcode must be <= 64 chars'),
       assert(priceCents >= 0, 'priceCents must be >= 0'),
       assert(priceCents <= 9999999999, 'priceCents must be <= 9,999,999,999'),
       assert(stock >= 0, 'stock must be >= 0'),
       assert(stock <= 999999, 'stock must be <= 999,999');

  /// Idempotent factory: accepts both the new shape (`stock`, `priceCents`)
  /// and the legacy shape (`quantity`, `priceAdjustment` double). If the new
  /// fields are already present they are used as-is; legacy fields are mapped
  /// only when the new fields are absent.
  factory VariantItem.fromJson(Map<String, dynamic> json) {
    // Required fields — must be non-null Strings.
    final rawId = json['id'];
    if (rawId == null || rawId is! String) {
      throw FormatException(
        'VariantItem.fromJson: required field "id" is null or not a String',
      );
    }
    final rawProductId = json['productId'];
    if (rawProductId == null || rawProductId is! String) {
      throw FormatException(
        'VariantItem.fromJson: required field "productId" is null or not a String',
      );
    }

    // Optional String fields — default to '' if null or wrong type.
    final rawColor = json['color'];
    final color = (rawColor is String) ? rawColor : '';
    final rawSize = json['size'];
    final size = (rawSize is String) ? rawSize : '';

    // sku (String, <= 64) — default ''.
    final rawSku = json['sku'];
    final sku = (rawSku is String)
        ? rawSku.substring(0, rawSku.length > 64 ? 64 : rawSku.length)
        : '';

    // barcode (String, <= 64) — default ''.
    final rawBarcode = json['barcode'];
    final barcode = (rawBarcode is String)
        ? rawBarcode.substring(
            0,
            rawBarcode.length > 64 ? 64 : rawBarcode.length,
          )
        : '';

    // stock (int, >= 0) — idempotent migration: prefer `stock`, fall back to
    // legacy `quantity`. null → 0; String → int.tryParse; num → .toInt(); other → 0.
    final rawStock = json.containsKey('stock')
        ? json['stock']
        : json['quantity'];
    int stock;
    if (rawStock == null) {
      stock = 0;
    } else if (rawStock is int) {
      stock = rawStock;
    } else if (rawStock is num) {
      stock = rawStock.toInt();
    } else if (rawStock is String) {
      stock = int.tryParse(rawStock) ?? 0;
    } else {
      stock = 0;
    }
    if (stock < 0) stock = 0;
    if (stock > 999999) stock = 999999;

    // priceCents (int Paise, >= 0) — idempotent migration: prefer `priceCents`,
    // fall back to legacy `priceAdjustment` (double, treated as rupees → ×100).
    int priceCents;
    if (json.containsKey('priceCents')) {
      final rawPrice = json['priceCents'];
      if (rawPrice == null) {
        priceCents = 0;
      } else if (rawPrice is int) {
        priceCents = rawPrice;
      } else if (rawPrice is num) {
        priceCents = rawPrice.toInt();
      } else if (rawPrice is String) {
        priceCents = int.tryParse(rawPrice) ?? 0;
      } else {
        priceCents = 0;
      }
    } else {
      // Legacy fallback: priceAdjustment was a double in rupees → convert to Paise.
      final rawPriceAdj = json['priceAdjustment'];
      if (rawPriceAdj == null) {
        priceCents = 0;
      } else if (rawPriceAdj is num) {
        priceCents = (rawPriceAdj.toDouble() * 100).round();
      } else if (rawPriceAdj is String) {
        final parsed = double.tryParse(rawPriceAdj);
        priceCents = parsed != null ? (parsed * 100).round() : 0;
      } else {
        priceCents = 0;
      }
    }
    if (priceCents < 0) priceCents = 0;
    if (priceCents > 9999999999) priceCents = 9999999999;

    return VariantItem(
      id: rawId,
      productId: rawProductId,
      color: color,
      size: size,
      sku: sku,
      barcode: barcode,
      priceCents: priceCents,
      stock: stock,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'productId': productId,
    'color': color,
    'size': size,
    'sku': sku,
    'barcode': barcode,
    'priceCents': priceCents,
    'stock': stock,
  };
}

/// Result of a CSV variant import operation.
/// Contains the count of successfully imported rows and details of any failures.
class CsvImportResult {
  final int importedCount;
  final List<CsvImportFailedRow> failedRows;

  const CsvImportResult({
    required this.importedCount,
    required this.failedRows,
  });
}

/// A single row that failed CSV import validation.
class CsvImportFailedRow {
  final int row;
  final String reason;

  const CsvImportFailedRow({required this.row, required this.reason});
}

class VariantRepository {
  final ApiClient apiClient;

  VariantRepository({required this.apiClient});

  Future<Either<Failure, List<VariantItem>>> getVariants(
    String productId,
  ) async {
    try {
      final response = await apiClient.get('/clothing/variants/$productId');
      final items = (response.data!['data'] as List)
          .map((item) => VariantItem.fromJson(item as Map<String, dynamic>))
          .toList();
      return Right(items);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, bool>> bulkUpdateVariants(
    String productId,
    List<VariantItem> variants,
  ) async {
    try {
      final payload = {'variants': variants.map((v) => v.toJson()).toList()};
      await apiClient.put('/clothing/variants/bulk', body: payload);
      return const Right(true);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// Feature flag key for the size-swap exchange.
  /// The exchange depends on `PUT /clothing/variants/{variantId}/stock` which is
  /// not yet deployed. Until the backend ships this endpoint, the feature is
  /// gated behind this flag to avoid silent 404 failures (Requirement 12.9).
  static const String _exchangeFeatureFlag = 'clothing_size_swap_exchange';

  /// Performs an atomic size-swap exchange:
  /// - Decrements [issuedVariantId]'s stock by [quantity]
  /// - Increments [returnedVariantId]'s stock by [quantity]
  ///
  /// Returns Right(true) on success.
  /// Returns Left(failure) if:
  /// - The `clothing_size_swap_exchange` feature flag is disabled (endpoint absent)
  /// - [tenantId] is empty (tenant context unavailable)
  /// - Issued variant has insufficient stock (both unchanged)
  /// - Any post-adjustment failure (both rolled back)
  Future<Either<Failure, bool>> sizeSwapExchange({
    required String issuedVariantId,
    required String returnedVariantId,
    required int quantity,
    required String tenantId,
  }) async {
    // Feature flag gate (Requirement 12.9): the exchange depends on
    // PUT /clothing/variants/{variantId}/stock which is not deployed.
    // Fail explicitly rather than silently returning a 404.
    try {
      final featureFlagService = FeatureFlagService();
      final isExchangeEnabled = await featureFlagService.isEnabled(
        _exchangeFeatureFlag,
      );
      if (!isExchangeEnabled) {
        return const Left(
          InputFailure(
            'Size-swap exchange is not available: the required backend endpoint '
            'is not yet deployed. This feature will be enabled once the backend '
            'supports per-variant stock adjustments.',
          ),
        );
      }
    } catch (_) {
      // If we cannot resolve the feature flag, fail-closed (deny access).
      return const Left(
        InputFailure(
          'Size-swap exchange is not available: unable to verify feature availability.',
        ),
      );
    }

    // Validate tenant context
    if (tenantId.isEmpty) {
      return const Left(
        InputFailure('Size-swap exchange failed: tenant context unavailable'),
      );
    }

    // Validate quantity is positive
    if (quantity <= 0) {
      return const Left(
        InputFailure(
          'Size-swap exchange failed: quantity must be greater than 0',
        ),
      );
    }

    // 1. Fetch the issued variant to validate sufficient stock
    final Either<Failure, List<VariantItem>> issuedResult;
    try {
      issuedResult = await getVariants(issuedVariantId);
    } catch (e) {
      return Left(
        ServerFailure(
          'Size-swap exchange failed: unable to fetch issued variant — ${e.toString()}',
        ),
      );
    }

    return issuedResult.fold(
      (failure) => Left(
        ServerFailure(
          'Size-swap exchange failed: unable to fetch issued variant — ${failure.message}',
        ),
      ),
      (issuedVariants) async {
        // Find the issued variant's current stock
        final issuedVariant = issuedVariants.isNotEmpty
            ? issuedVariants.first
            : null;
        if (issuedVariant == null) {
          return const Left(
            InputFailure('Size-swap exchange failed: issued variant not found'),
          );
        }

        // Reject if insufficient stock (Requirement 11.6)
        if (issuedVariant.stock < quantity) {
          return Left(
            InputFailure(
              'Size-swap exchange rejected: issued variant stock (${issuedVariant.stock}) '
              'is less than requested quantity ($quantity) — both variants unchanged',
            ),
          );
        }

        // 2. Atomically: decrement issued, increment returned
        // Step A: Decrement issued variant's stock
        bool issuedDecremented = false;
        try {
          final decrementPayload = {
            'variantId': issuedVariantId,
            'adjustment': -quantity,
            'tenantId': tenantId,
          };
          await apiClient.put(
            '/clothing/variants/$issuedVariantId/stock',
            body: decrementPayload,
          );
          issuedDecremented = true;
        } catch (e) {
          // Decrement failed — nothing to roll back, both unchanged
          return Left(
            ServerFailure(
              'Size-swap exchange failed: could not decrement issued variant stock — ${e.toString()}',
            ),
          );
        }

        // Step B: Increment returned variant's stock
        try {
          final incrementPayload = {
            'variantId': returnedVariantId,
            'adjustment': quantity,
            'tenantId': tenantId,
          };
          await apiClient.put(
            '/clothing/variants/$returnedVariantId/stock',
            body: incrementPayload,
          );
        } catch (e) {
          // 3. Increment failed after decrement succeeded — roll back the decrement
          // (Requirement 11.7: no partial state persists)
          if (issuedDecremented) {
            try {
              final rollbackPayload = {
                'variantId': issuedVariantId,
                'adjustment': quantity,
                'tenantId': tenantId,
              };
              await apiClient.put(
                '/clothing/variants/$issuedVariantId/stock',
                body: rollbackPayload,
              );
            } catch (rollbackError) {
              return Left(
                ServerFailure(
                  'Size-swap exchange failed: increment of returned variant failed and '
                  'rollback of issued variant also failed — manual intervention required. '
                  'Original error: ${e.toString()}, Rollback error: ${rollbackError.toString()}',
                ),
              );
            }
          }
          return Left(
            ServerFailure(
              'Size-swap exchange failed: could not increment returned variant stock — '
              'issued variant stock has been rolled back. Error: ${e.toString()}',
            ),
          );
        }

        return const Right(true);
      },
    );
  }

  Future<Either<Failure, String>> exportToCsv(String productId) async {
    try {
      final variantsEither = await getVariants(productId);
      return variantsEither.fold(Left.new, (variants) {
        final buffer = StringBuffer(
          'id,productId,color,size,sku,barcode,priceCents,stock\n',
        );
        for (final variant in variants) {
          buffer.writeln(
            '${variant.id},${variant.productId},${variant.color},${variant.size},${variant.sku},${variant.barcode},${variant.priceCents},${variant.stock}',
          );
        }
        final encoded = Uri.encodeComponent(buffer.toString());
        return Right('data:text/csv;charset=utf-8,$encoded');
      });
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// Expected CSV header matching the export format.
  static const _csvHeader =
      'id,productId,color,size,sku,barcode,priceCents,stock';

  /// Imports variants from CSV content.
  ///
  /// The CSV format must match the export format:
  /// `id,productId,color,size,sku,barcode,priceCents,stock`
  ///
  /// Returns a [CsvImportResult] containing:
  /// - [importedCount]: number of successfully imported rows
  /// - [failedRows]: list of (row, reason) for rejected rows
  ///
  /// Existing variant data is preserved — import only adds new or updates
  /// existing variants (Requirement 14.7).
  Future<Either<Failure, CsvImportResult>> importFromCsv(
    String productId,
    String csvContent,
  ) async {
    if (csvContent.trim().isEmpty) {
      return const Left(InputFailure('CSV content is empty'));
    }

    final lines = csvContent
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return const Left(InputFailure('CSV content is empty'));
    }

    // Validate header row
    final headerLine = lines.first.trim();
    if (headerLine != _csvHeader) {
      return const Left(
        InputFailure(
          'CSV header does not match expected format: '
          'id,productId,color,size,sku,barcode,priceCents,stock',
        ),
      );
    }

    final List<CsvImportFailedRow> failedRows = [];
    final List<VariantItem> validVariants = [];

    // Parse data rows (skip header at index 0)
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final rowNumber = i + 1; // 1-based row number (header is row 1)
      final fields = line.split(',');

      // Validation: must have exactly 8 fields
      if (fields.length != 8) {
        failedRows.add(
          CsvImportFailedRow(
            row: rowNumber,
            reason: 'Expected 8 fields, got ${fields.length}',
          ),
        );
        continue;
      }

      final id = fields[0].trim();
      final rowProductId = fields[1].trim();
      final color = fields[2].trim();
      final size = fields[3].trim();
      final sku = fields[4].trim();
      final barcode = fields[5].trim();
      final priceCentsStr = fields[6].trim();
      final stockStr = fields[7].trim();

      // Validation: color must be non-empty
      if (color.isEmpty) {
        failedRows.add(
          CsvImportFailedRow(
            row: rowNumber,
            reason: 'Required field "color" is empty',
          ),
        );
        continue;
      }

      // Validation: size must be non-empty
      if (size.isEmpty) {
        failedRows.add(
          CsvImportFailedRow(
            row: rowNumber,
            reason: 'Required field "size" is empty',
          ),
        );
        continue;
      }

      // Validation: sku must be <= 64 chars
      if (sku.length > 64) {
        failedRows.add(
          CsvImportFailedRow(
            row: rowNumber,
            reason: 'Field "sku" exceeds 64 characters (${sku.length})',
          ),
        );
        continue;
      }

      // Validation: barcode must be <= 64 chars
      if (barcode.length > 64) {
        failedRows.add(
          CsvImportFailedRow(
            row: rowNumber,
            reason: 'Field "barcode" exceeds 64 characters (${barcode.length})',
          ),
        );
        continue;
      }

      // Validation: priceCents must be a non-negative integer
      final priceCents = int.tryParse(priceCentsStr);
      if (priceCents == null) {
        failedRows.add(
          CsvImportFailedRow(
            row: rowNumber,
            reason:
                'Field "priceCents" is not a valid integer: "$priceCentsStr"',
          ),
        );
        continue;
      }
      if (priceCents < 0) {
        failedRows.add(
          CsvImportFailedRow(
            row: rowNumber,
            reason: 'Field "priceCents" must be non-negative, got $priceCents',
          ),
        );
        continue;
      }

      // Validation: stock must be a non-negative integer <= 999,999
      final stock = int.tryParse(stockStr);
      if (stock == null) {
        failedRows.add(
          CsvImportFailedRow(
            row: rowNumber,
            reason: 'Field "stock" is not a valid integer: "$stockStr"',
          ),
        );
        continue;
      }
      if (stock < 0) {
        failedRows.add(
          CsvImportFailedRow(
            row: rowNumber,
            reason: 'Field "stock" must be non-negative, got $stock',
          ),
        );
        continue;
      }
      if (stock > 999999) {
        failedRows.add(
          CsvImportFailedRow(
            row: rowNumber,
            reason: 'Field "stock" exceeds maximum (999,999), got $stock',
          ),
        );
        continue;
      }

      // All validations passed — build VariantItem
      validVariants.add(
        VariantItem(
          id: id.isNotEmpty ? id : '${productId}_${color}_$size',
          productId: rowProductId.isNotEmpty ? rowProductId : productId,
          color: color,
          size: size,
          sku: sku,
          barcode: barcode,
          priceCents: priceCents,
          stock: stock,
        ),
      );
    }

    // Import valid variants via bulkUpdateVariants (adds/updates, never clears)
    if (validVariants.isNotEmpty) {
      try {
        final result = await bulkUpdateVariants(productId, validVariants);
        return result.fold(
          (failure) => Left(failure),
          (_) => Right(
            CsvImportResult(
              importedCount: validVariants.length,
              failedRows: failedRows,
            ),
          ),
        );
      } catch (e) {
        return Left(
          ServerFailure(
            'CSV import failed during bulk update: ${e.toString()}',
          ),
        );
      }
    }

    // No valid rows to import — return result with zero imported
    return Right(CsvImportResult(importedCount: 0, failedRows: failedRows));
  }
}
