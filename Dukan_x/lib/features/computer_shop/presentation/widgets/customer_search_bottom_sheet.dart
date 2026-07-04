// ============================================================================
// Computer Shop — Customer Search Bottom Sheet
// ============================================================================
// Search and select customers for warranty registration or reference linking.
// Follows the same pattern as ProductSearchBottomSheet.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx/core/services/search_service.dart';

/// Bottom sheet for searching and selecting a customer.
///
/// On selection, returns both the customer id and a human-readable label
/// (customer name). Dismiss without selection leaves the prior id unchanged
/// (Req 22.6).
class CustomerSearchBottomSheet extends ConsumerStatefulWidget {
  /// Called when a customer is selected from the results.
  final Function(String customerId, String customerLabel) onCustomerSelected;

  const CustomerSearchBottomSheet({
    super.key,
    required this.onCustomerSelected,
  });

  @override
  ConsumerState<CustomerSearchBottomSheet> createState() =>
      _CustomerSearchBottomSheetState();
}

class _CustomerSearchBottomSheetState
    extends ConsumerState<CustomerSearchBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<_CustomerItem> _searchResults = [];
  bool _isSearching = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchCustomers(String query) async {
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
      final result = await searchService.searchCustomers(query, pageSize: 20);

      if (!mounted) return;

      final items = result.results.map((json) {
        return _CustomerItem(
          id: json['id']?.toString() ?? json['SK']?.toString() ?? '',
          name:
              json['name']?.toString() ??
              json['customerName']?.toString() ??
              'Unknown',
          phone: json['phone']?.toString() ?? json['mobile']?.toString() ?? '',
          email: json['email']?.toString() ?? '',
        );
      }).toList();

      setState(() {
        _searchResults = items;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to search customers: $e';
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
                'Select Customer',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Search by customer name or phone number',
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
                    _searchCustomers(value);
                  } else if (value.isEmpty) {
                    setState(() => _searchResults = []);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Search Customers',
                  hintText: 'Type customer name or phone',
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
                      final customer = _searchResults[index];
                      return ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.person,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          customer.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          customer.phone.isNotEmpty
                              ? customer.phone
                              : customer.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          widget.onCustomerSelected(customer.id, customer.name);
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
                          'No customers found',
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

/// Internal model for customer search results.
class _CustomerItem {
  final String id;
  final String name;
  final String phone;
  final String email;

  _CustomerItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
  });
}
