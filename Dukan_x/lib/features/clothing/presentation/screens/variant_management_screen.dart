// WCAG 2.1 AA: Theme-derived color pairs target ≥4.5:1 contrast (normal text)
// and ≥3:1 (large text). Full conformance requires manual AT testing + expert review.

import 'package:flutter/material.dart';
import '../../widgets/variant_grid/variant_grid_widget.dart';
import '../../widgets/variant_grid/variant_cell_key.dart';
import '../../../barcode/widgets/clothing_variant_scanner_widget.dart';
import 'package:dukanx/core/responsive/responsive.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../data/variant_repository.dart';
import '../../data/repositories/clothing_repository_offline.dart';
import '../../services/clothing_tag_printer.dart';
import '../../widgets/clothing_sync_indicator.dart';

class VariantManagementScreen extends StatefulWidget {
  final String productId;

  const VariantManagementScreen({super.key, required this.productId});

  @override
  State<VariantManagementScreen> createState() =>
      _VariantManagementScreenState();
}

class _VariantManagementScreenState extends State<VariantManagementScreen> {
  /// Tracks the latest edited quantities from the grid.
  Map<String, int> _editedQuantities = {};

  /// Whether a save operation is currently in progress.
  bool _isSaving = false;

  void _openVariantScanner(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: ClothingVariantScannerWidget(
          onComplete: (result) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Scanned: ${result.product.name} — Qty: ${result.quantity}',
                ),
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            );
          },
          onCancel: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  /// Handler that replaces the empty onQuantitiesChanged callback (Req 8.2).
  /// Stores edited quantities so they are available for the Save action.
  void _onQuantitiesChanged(Map<String, int> quantities) {
    _editedQuantities = Map.from(quantities);
  }

  /// Persists edited quantities via ClothingRepositoryOffline.bulkUpdateVariants,
  /// scoped by the active Tenant_Id (Req 8.1, 8.8, 8.9, 12.1).
  Future<bool> _onSave(Map<String, int> quantities) async {
    final session = sl<SessionManager>();
    final tenantId = session.currentBusinessId;

    // Reject if tenant cannot be resolved (Req 1.12)
    if (tenantId == null || tenantId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Save failed: no active business session.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return false;
    }

    setState(() => _isSaving = true);

    // Convert the grid's key→quantity map to VariantItem list for the repository
    final variants = quantities.entries.map((entry) {
      final parsed = parseVariantCellKey(entry.key);
      return VariantItem(
        id: '', // Existing variants retain their IDs server-side
        productId: widget.productId,
        color: parsed.color,
        size: parsed.size,
        stock: entry.value,
      );
    }).toList();

    // Route through ClothingRepositoryOffline (offline-first, Req 12.1)
    try {
      final repository = ClothingRepositoryOffline(sl(), sl<SessionManager>());
      await repository.initialize();
      await repository.bulkUpdateVariants(widget.productId, variants);

      setState(() => _isSaving = false);

      // On success: show visible success indicator within 2 seconds (Req 8.8)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Quantities saved successfully.'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return true;
    } catch (e) {
      setState(() => _isSaving = false);

      // On failure: show error indication, retain edited quantities (Req 8.9)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Save failed: ${e.toString()}. Your edits are preserved.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return false;
    }
  }

  /// Prints price-tag/barcode labels for all variants currently in the grid.
  /// Uses [ClothingTagPrinter] to render one tag per variant via
  /// Print_Infrastructure. On failure, names the affected variant(s)
  /// (Requirement 12.6, 12.7).
  Future<void> _printVariantTags() async {
    // Build a list of VariantItem from the edited quantities map
    final variants = _editedQuantities.entries
        .where((entry) => entry.value > 0)
        .map((entry) {
          final parsed = parseVariantCellKey(entry.key);
          return VariantItem(
            id: entry.key,
            productId: widget.productId,
            color: parsed.color,
            size: parsed.size,
            stock: entry.value,
          );
        })
        .toList();

    if (variants.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No variants with stock to print tags for.'),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
        );
      }
      return;
    }

    const printer = ClothingTagPrinter();
    final result = await printer.printVariantTags(variants);

    if (!mounted) return;

    if (result.allSucceeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Printed ${result.successCount} variant tag(s) successfully.',
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } else {
      // Name the failed variants in the error message (Req 12.7)
      final failedNames = result.failureDetails.keys.join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Print failed for: $failedNames. '
            '${result.successCount} tag(s) printed successfully.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Variants'),
        actions: [
          ClothingSyncIndicator(
            repository: ClothingRepositoryOffline(sl(), sl<SessionManager>()),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _printVariantTags,
            icon: const Icon(Icons.label_outlined),
            tooltip: 'Print variant tags',
          ),
          IconButton(
            onPressed: () => _openVariantScanner(context),
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan variant barcode',
          ),
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: VariantGridWidget(
            sizes: const ['S', 'M', 'L', 'XL', 'XXL', '3XL'],
            colors: const ['Red', 'Blue', 'Green', 'Black', 'White', 'Yellow'],
            onQuantitiesChanged: _onQuantitiesChanged,
            onSave: _onSave,
            isSaving: _isSaving,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openVariantScanner(context),
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan Variant'),
      ),
    );
  }
}
