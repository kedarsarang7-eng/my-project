import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../../../core/repository/products_repository.dart';
import '../errors/io_guard.dart';

/// Bulk Import Service for Items and Parties
class BulkImportService {
  final ProductsRepository _productsRepo;

  BulkImportService(this._productsRepo);

  /// Import items from a CSV string, persisting each valid row via the products
  /// repository. Returns the number of products actually created.
  /// Expected header: Name, SKU, Category, SellingPrice, CostPrice, Stock
  Future<int> importItemsFromCsv(String csvData, String userId) async {
    int count = 0;
    final lines = const LineSplitter().convert(csvData);
    if (lines.isEmpty) return 0;

    for (int i = 1; i < lines.length; i++) {
      // Skip header row (i = 0).
      final parts = lines[i].split(',');
      if (parts.length < 6) continue;
      final name = parts[0].trim();
      if (name.isEmpty) continue;

      final result = await _productsRepo.createProduct(
        userId: userId,
        name: name,
        sku: parts[1].trim().isEmpty ? null : parts[1].trim(),
        category: parts[2].trim().isEmpty ? null : parts[2].trim(),
        sellingPrice: double.tryParse(parts[3].trim()) ?? 0.0,
        costPrice: double.tryParse(parts[4].trim()) ?? 0.0,
        stockQuantity: double.tryParse(parts[5].trim()) ?? 0.0,
      );
      if (result.isSuccess) count++;
    }
    return count;
  }

  /// Pick a CSV file, read it, and import its rows. Returns a user-facing
  /// summary string.
  Future<String> pickAndImportFile(String userId) async {
    return IoGuard.run<String>(
      label: 'bulk_import.pick_file',
      userMessage: 'Could not import the file. Please try again.',
      op: () async {
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['csv'],
          withData: kIsWeb,
        );

        if (result == null || result.files.isEmpty) {
          return 'No file selected';
        }

        final picked = result.files.single;
        String csvString;
        if (kIsWeb) {
          final bytes = picked.bytes;
          if (bytes == null) return 'Could not read the selected file';
          csvString = utf8.decode(bytes, allowMalformed: true);
        } else {
          final path = picked.path;
          if (path == null) return 'Could not read the selected file';
          csvString = await File(path).readAsString();
        }

        final count = await importItemsFromCsv(csvString, userId);
        return 'Imported $count item(s)';
      },
    );
  }
}
