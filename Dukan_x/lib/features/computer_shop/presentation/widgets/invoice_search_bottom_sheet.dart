// ============================================================================
// Computer Shop — Invoice Search Bottom Sheet
// ============================================================================
// Search and select invoices for warranty registration or reference linking.
// Follows the same pattern as ProductSearchBottomSheet.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx/core/services/search_service.dart';

/// Bottom sheet for searching and selecting an invoice.
///
/// On selection, returns both the invoice id and a human-readable label
/// (invoice number). Dismiss without selection leaves the prior id unchanged
/// (Req 22.6).
class InvoiceSearchBottomSheet extends ConsumerStatefulWidget {
  /// Called when an invoice is selected from the results.
  final Function(String invoiceId, String invoiceLabel) onInvoiceSelected;

  const InvoiceSearchBottomSheet({super.key, required this.onInvoiceSelected});

  @override
  ConsumerState<InvoiceSearchBottomSheet> createState() =>
      _InvoiceSearchBottomSheetState();
}

class _InvoiceSearchBottomSheetState
    extends ConsumerState<InvoiceSearchBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<_InvoiceItem> _searchResults = [];
  bool _isSearching = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchInvoices(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final searchService = SearchService();
      final result = await searchService.searchBills(query, pageSize: 20);

      if (!mounted) return;

      final items = result.results.map((json) {
        return _InvoiceItem(
          id: json['id']?.toString() ?? json['SK']?.toString() ?? '',
          invoiceNumber:
              json['invoiceNumber']?.toString() ??
              json['billNumber']?.toString() ??
              'Unknown',
          customerName: json['customerName']?.toString() ?? '',
          date: json['date']?.toString() ?? json['createdAt']?.toString() ?? '',
          total: (json['total'] ?? json['grandTotal'] ?? 0).toDouble(),
        );
      }).toList();

      setState(() {
        _searchResults = items;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to search invoices: $e';
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'Select Invoice',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Search by invoice number or customer name',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),

              // Search Input
              TextField(
                controller: _searchController,
                onChanged: (value) {
                  if (value.length >= 2) {
                    _searchInvoices(value);
                  } else if (value.isEmpty) {
                    setState(() => _searchResults = []);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Search Invoices',
                  hintText: 'Type invoice number or customer name',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchResults = []);
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Results
              if (_isSearching)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_error != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: theme.colorScheme.error,
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text(_error!, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                )
              else if (_searchResults.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final invoice = _searchResults[index];
                      return ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.receipt_long,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          invoice.invoiceNumber,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          invoice.customerName.isNotEmpty
                              ? invoice.customerName
                              : invoice.date,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          widget.onInvoiceSelected(
                            invoice.id,
                            invoice.invoiceNumber,
                          );
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                )
              else if (_searchController.text.isNotEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off,
                          color: theme.disabledColor,
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No invoices found',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Internal model for invoice search results.
class _InvoiceItem {
  final String id;
  final String invoiceNumber;
  final String customerName;
  final String date;
  final double total;

  _InvoiceItem({
    required this.id,
    required this.invoiceNumber,
    required this.customerName,
    required this.date,
    required this.total,
  });
}
