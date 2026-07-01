import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../core/session/session_manager.dart';

import '../../../../widgets/modern_ui_components.dart';
import '../../../../widgets/ui/futuristic_button.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class ImportInventoryScreen extends ConsumerStatefulWidget {
  const ImportInventoryScreen({super.key});

  @override
  ConsumerState<ImportInventoryScreen> createState() =>
      _ImportInventoryScreenState();
}

class _ImportInventoryScreenState extends ConsumerState<ImportInventoryScreen> {
  bool _isLoading = false;
  List<List<dynamic>> _csvData = [];
  List<String> _headers = [];
  Map<String, int> _columnMapping = {};

  // Stats
  int _successCount = 0;
  int _failCount = 0;
  bool _isImporting = false;
  String _statusMessage = "";

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: kIsWeb, // Web needs data bytes
      );

      if (result != null) {
        setState(() => _isLoading = true);

        String csvString = "";

        if (kIsWeb) {
          final bytes = result.files.first.bytes;
          if (bytes != null) {
            csvString = utf8.decode(bytes);
          }
        } else {
          final path = result.files.single.path;
          if (path != null) {
            final file = File(path);
            csvString = await file.readAsString();
          }
        }

        if (csvString.isNotEmpty) {
          List<List<dynamic>> rows = const CsvDecoder().convert(
            csvString,
          );
          if (rows.isNotEmpty) {
            _headers = rows.first.map((e) => e.toString()).toList();
            _csvData = rows.skip(1).toList();
            _autoMapColumns();
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error reading file: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _autoMapColumns() {
    _columnMapping = {};
    for (int i = 0; i < _headers.length; i++) {
      final header = _headers[i].toLowerCase();
      if (header.contains("name") || header.contains("product")) {
        _columnMapping['name'] = i;
      } else if (header.contains("price") ||
          header.contains("selling") ||
          header.contains("mrp")) {
        _columnMapping['price'] = i;
      } else if (header.contains("stock") ||
          header.contains("qty") ||
          header.contains("quantity")) {
        _columnMapping['stock'] = i;
      } else if (header.contains("unit")) {
        _columnMapping['unit'] = i;
      } else if (header.contains("cost") || header.contains("buy")) {
        _columnMapping['cost'] = i;
      }
    }
  }

  Future<void> _processImport() async {
    // Validation
    if (_columnMapping['name'] == null || _columnMapping['price'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please map at least Name and Price columns"),
        ),
      );
      return;
    }

    setState(() {
      _isImporting = true;
      _successCount = 0;
      _failCount = 0;
    });

    final repo = sl<ProductsRepository>();
    final userId = sl<SessionManager>().ownerId;

    if (userId == null) return;

    final total = _csvData.length;

    for (int i = 0; i < total; i++) {
      final row = _csvData[i];

      // Update UI every 10 items
      if (i % 10 == 0) {
        setState(() {
          _statusMessage = "Processing item ${i + 1} of $total...";
        });
      }

      try {
        final nameIdx = _columnMapping['name'];
        final priceIdx = _columnMapping['price'];
        final stockIdx = _columnMapping['stock'];
        final unitIdx = _columnMapping['unit'];
        final costIdx = _columnMapping['cost'];

        final name = row[nameIdx!].toString().trim();
        if (name.isEmpty) continue; // Skip empty names

        final price = double.tryParse(row[priceIdx!].toString()) ?? 0.0;

        double stock = 0.0;
        if (stockIdx != null && stockIdx < row.length) {
          stock = double.tryParse(row[stockIdx].toString()) ?? 0.0;
        }

        String unit = "pcs";
        if (unitIdx != null && unitIdx < row.length) {
          unit = row[unitIdx].toString().trim();
          if (unit.isEmpty) unit = "pcs";
        }

        double cost = 0.0;
        if (costIdx != null && costIdx < row.length) {
          cost = double.tryParse(row[costIdx].toString()) ?? 0.0;
        }

        await repo.createProduct(
          userId: userId,
          name: name,
          sellingPrice: price,
          stockQuantity: stock,
          unit: unit,
          costPrice: cost,
          taxRate: 0, // Default or add mapping
        );

        _successCount++;
      } catch (e) {
        _failCount++;
        debugPrint("Import Error Row $i: $e");
      }
    }

    setState(() {
      _isImporting = false;
      _statusMessage = "Import Complete!";
    });

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Import Summary"),
          content: Text(
            "Successfully imported: $_successCount\nFailed: $_failCount",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true); // Return true to refresh
              },
              child: const Text("Done"),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Theme logic could be pulled from riverpod, simplifying for speed
    // final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text("Bulk Import Inventory")),
      body: BoundedBox(
        maxWidth: 800,
        child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Step 1: Pick File
            if (_csvData.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.upload_file,
                        size: 60,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Select a CSV file to import products",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Supported columns: Name, Price, Stock, Unit, Cost",
                      ),
                      const SizedBox(height: 30),
                      if (_isLoading)
                        const CircularProgressIndicator()
                      else
                        FuturisticButton.primary(
                          label: "Pick CSV File",
                          icon: Icons.folder_open,
                          onPressed: _pickFile,
                        ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Preview: Found ${_csvData.length} items",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _csvData = [];
                              _headers = [];
                            });
                          },
                          child: const Text("Clear"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Mapping Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Column Mapping",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 20,
                              runSpacing: 10,
                              children: [
                                _buildMappingDropdown("Name *", "name"),
                                _buildMappingDropdown("Price *", "price"),
                                _buildMappingDropdown("Stock", "stock"),
                                _buildMappingDropdown("Unit", "unit"),
                                _buildMappingDropdown("Cost", "cost"),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Data Preview
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            columns: _headers
                                .map((h) => DataColumn(label: Text(h)))
                                .toList(),
                            rows: _csvData.take(10).map((row) {
                              return DataRow(
                                cells: row
                                    .map(
                                      (cell) => DataCell(Text(cell.toString())),
                                    )
                                    .toList(),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Progress
                    if (_isImporting) ...[
                      LinearProgressIndicator(
                        value: _csvData.isEmpty
                            ? 0
                            : (_successCount + _failCount) / _csvData.length,
                      ),
                      Text(_statusMessage),
                      const SizedBox(height: 20),
                    ],

                    // Action
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FuturisticButton.success(
                        label: _isImporting ? "Importing..." : "Confirm Import",
                        icon: Icons.cloud_upload,
                        isLoading: _isImporting,
                        onPressed: _isImporting ? null : _processImport,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildMappingDropdown(String label, String key) {
    return SizedBox(
      width: 150,
      child: DropdownButtonFormField<int>(
        value: _columnMapping[key],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: List.generate(_headers.length, (index) {
          return DropdownMenuItem(
            value: index,
            child: Text(
              _headers[index],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
        onChanged: (val) {
          setState(() {
            if (val != null) _columnMapping[key] = val;
          });
        },
      ),
    );
  }
}
