// ============================================================================
// Computer Shop — Warranty Management Screen
// ============================================================================
// Features:
// - Lookup warranty by serial number
// - Register new warranty
// - View warranty details with expiry status
// - Color-coded expiry indicators
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/computer_job_providers.dart';
import '../../data/repositories/computer_repository.dart';
import '../../utils/computer_shop_business_rules.dart';
import '../../utils/computer_shop_validators.dart';
import '../widgets/product_search_bottom_sheet.dart';
import '../widgets/invoice_search_bottom_sheet.dart';
import '../widgets/customer_search_bottom_sheet.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class WarrantyScreen extends ConsumerStatefulWidget {
  const WarrantyScreen({super.key});

  @override
  ConsumerState<WarrantyScreen> createState() => _WarrantyScreenState();
}

class _WarrantyScreenState extends ConsumerState<WarrantyScreen> {
  final _serialSearchController = TextEditingController();

  /// Number of tabs rendered by the TabBar.
  static const _tabCount = 2;

  @override
  void dispose() {
    _serialSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Warranty Management',
              style: TextStyle(
                fontSize: responsiveValue<double>(
                  context,
                  mobile: 16,
                  tablet: 18,
                  desktop: 20,
                ),
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              'Track & Register Product Warranties',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: DefaultTabController(
        length: _tabCount,
        child: BoundedBox(
          maxWidth: 800,
          child: Builder(
            builder: (context) {
              // Safety net: catch TabController resolution errors and show
              // inline error instead of crashing the app (Req 1.7).
              try {
                final controller = DefaultTabController.of(context);
                if (controller.length != _tabCount) {
                  return _TabControllerErrorWidget(
                    message:
                        'Tab controller mismatch: expected $_tabCount tabs, '
                        'got ${controller.length}.',
                  );
                }
              } catch (e) {
                return _TabControllerErrorWidget(
                  message: 'Unable to resolve TabController: $e',
                );
              }

              return Column(
                children: [
                  // Tab Bar
                  Container(
                    color: Theme.of(context).colorScheme.surface,
                    child: TabBar(
                      indicatorColor: Theme.of(context).colorScheme.primary,
                      labelColor: Theme.of(context).colorScheme.primary,
                      unselectedLabelColor: Colors.grey.shade600,
                      tabs: const [
                        Tab(text: 'Lookup', icon: Icon(Icons.search)),
                        Tab(text: 'Register', icon: Icon(Icons.add_card)),
                      ],
                    ),
                  ),
                  // Tab Content — only the selected tab's content is visible.
                  Expanded(
                    child: TabBarView(
                      children: [
                        _WarrantyLookupTab(
                          searchController: _serialSearchController,
                          onSearch: () => ref
                              .read(warrantyProvider.notifier)
                              .lookupWarranty(
                                _serialSearchController.text.trim(),
                              ),
                        ),
                        const _WarrantyRegisterTab(),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Inline error widget shown when the TabController cannot be resolved or
/// its tab count doesn't match (Req 1.7). Keeps the app running instead of
/// crashing.
class _TabControllerErrorWidget extends StatelessWidget {
  final String message;

  const _TabControllerErrorWidget({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Unable to display tabs',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.red.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Warranty Lookup Tab
// ============================================================================

class _WarrantyLookupTab extends ConsumerWidget {
  final TextEditingController searchController;
  final VoidCallback onSearch;

  const _WarrantyLookupTab({
    required this.searchController,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warrantyState = ref.watch(warrantyProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.qr_code_scanner,
                    size: 48,
                    color: Color(0xFF3B82F6),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Lookup Warranty',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the product serial number to check warranty status',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      labelText: 'Serial Number',
                      hintText: 'e.g., SN123456789',
                      prefixIcon: const Icon(Icons.confirmation_number),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: onSearch,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    onSubmitted: (_) => onSearch(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: warrantyState.isLoading ? null : onSearch,
                      icon: warrantyState.isLoading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                      label: Text(
                        warrantyState.isLoading ? 'Searching...' : 'Lookup',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Results
          if (warrantyState.error != null)
            _ErrorResult(error: warrantyState.error!)
          else if (warrantyState.warranty != null)
            _WarrantyResultCard(warranty: warrantyState.warranty!),
        ],
      ),
    );
  }
}

class _WarrantyResultCard extends StatelessWidget {
  final ComputerWarranty warranty;

  const _WarrantyResultCard({required this.warranty});

  @override
  Widget build(BuildContext context) {
    final isExpired = warranty.isExpired ?? false;
    final daysRemaining = warranty.daysRemaining ?? 0;
    final statusColor = isExpired
        ? Colors.red
        : (daysRemaining < 30 ? Colors.orange : Colors.green);

    final expiryDate =
        DateTime.tryParse(warranty.warrantyExpiryDate) ?? DateTime.now();
    final purchaseDate =
        DateTime.tryParse(warranty.purchaseDate) ?? DateTime.now();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withOpacity(0.3), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isExpired ? Icons.cancel : Icons.verified,
                        color: statusColor,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isExpired ? 'EXPIRED' : warranty.status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (!isExpired)
                  Text(
                    '$daysRemaining days left',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // AMC Status Indicator (Req 11.1–11.5)
            _AmcStatusIndicator(warranty: warranty),
            const Divider(height: 32),
            // Warranty Details
            _DetailRow(
              'Serial Number',
              warranty.serialNumber,
              Icons.confirmation_number,
            ),
            const SizedBox(height: 12),
            _DetailRow('Product ID', warranty.productId, Icons.inventory_2),
            const SizedBox(height: 12),
            _DetailRow(
              'Purchase Date',
              DateFormat('dd MMM yyyy').format(purchaseDate),
              Icons.calendar_today,
            ),
            const SizedBox(height: 12),
            _DetailRow(
              'Expiry Date',
              DateFormat('dd MMM yyyy').format(expiryDate),
              Icons.event,
              valueColor: isExpired ? Colors.red : null,
            ),
            const SizedBox(height: 12),
            _DetailRow(
              'Warranty Period',
              '${warranty.warrantyPeriodMonths} months',
              Icons.timelapse,
            ),
            const SizedBox(height: 12),
            _DetailRow(
              'Claims Made',
              '${warranty.claimCount}',
              Icons.receipt_long,
            ),
            const Divider(height: 32),
            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Navigate to serial history
                      context.push(
                        '/computer-shop/serial-history',
                        extra: {'serialNumber': warranty.serialNumber},
                      );
                    },
                    icon: const Icon(Icons.history),
                    label: const Text('View History'),
                  ),
                ),
                const SizedBox(width: 12),
                if (!isExpired)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Create service job from warranty
                        context.push(
                          '/computer-shop/create-job-card',
                          extra: {'serialNumber': warranty.serialNumber},
                        );
                      },
                      icon: const Icon(Icons.build),
                      label: const Text('Create Service'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// AMC Status Indicator (Req 11.1–11.5)
// ============================================================================
// Displays the AMC due/not-due/unavailable state for a warranty record.
// Input data (warrantyExpiryDate) is sourced from ComputerRepository via the
// warrantyProvider — never from hardcoded or literal values (Req 11.4).

class _AmcStatusIndicator extends StatelessWidget {
  final ComputerWarranty warranty;

  const _AmcStatusIndicator({required this.warranty});

  @override
  Widget build(BuildContext context) {
    final expiryDateStr = warranty.warrantyExpiryDate;

    // If the expiry date string is absent or unparseable, show unavailable (Req 11.5).
    if (expiryDateStr.isEmpty) {
      return _buildChip(
        context,
        label: 'AMC status unavailable',
        color: Colors.grey,
        icon: Icons.help_outline,
      );
    }

    final expiryDate = DateTime.tryParse(expiryDateStr);
    if (expiryDate == null) {
      return _buildChip(
        context,
        label: 'AMC status unavailable',
        color: Colors.grey,
        icon: Icons.help_outline,
      );
    }

    // Compute AMC due status via business rules (Req 11.1, 11.2).
    final now = DateTime.now();
    final isDue = ComputerShopBusinessRules.isAmcDue(expiryDate, now);

    if (isDue) {
      // Visually distinct "due" state (Req 11.3)
      return _buildChip(
        context,
        label: 'AMC Due',
        color: Colors.orange,
        icon: Icons.warning_amber_rounded,
      );
    } else {
      return _buildChip(
        context,
        label: 'AMC OK',
        color: Colors.green,
        icon: Icons.check_circle_outline,
      );
    }
  }

  Widget _buildChip(
    BuildContext context, {
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _DetailRow(this.label, this.value, this.icon, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: valueColor ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorResult extends StatelessWidget {
  final String error;

  const _ErrorResult({required this.error});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Warranty Not Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.red.shade600),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                // Navigate to the Register tab (index 1).
                try {
                  DefaultTabController.of(context).animateTo(1);
                } catch (e) {
                  // If tab navigation fails, show error indication (Req 24.2).
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.error, color: Colors.white),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text('Could not open warranty registration'),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Register Warranty'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Warranty Register Tab
// ============================================================================

class _WarrantyRegisterTab extends ConsumerStatefulWidget {
  const _WarrantyRegisterTab();

  @override
  ConsumerState<_WarrantyRegisterTab> createState() =>
      _WarrantyRegisterTabState();
}

class _WarrantyRegisterTabState extends ConsumerState<_WarrantyRegisterTab> {
  final _formKey = GlobalKey<FormState>();
  final _serialController = TextEditingController();
  int _warrantyMonths = 12;
  DateTime _purchaseDate = DateTime.now();

  // Picker state: store both the id (for backend) and label (for display).
  String? _selectedProductId;
  String? _selectedProductLabel;
  String? _selectedInvoiceId;
  String? _selectedInvoiceLabel;
  String? _selectedCustomerId;
  String? _selectedCustomerLabel;

  @override
  void dispose() {
    _serialController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate that required picker references are selected (Req 20.4, 20.5).
    if (_selectedProductId == null || _selectedProductId!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Please select a product using the picker'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (_selectedInvoiceId == null || _selectedInvoiceId!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Please select an invoice using the picker'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Validate purchase date is not in the future (defense-in-depth).
    final dateError = ComputerShopValidators.validatePurchaseDate(
      _purchaseDate,
    );
    if (dateError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(dateError)),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      await ref
          .read(warrantyProvider.notifier)
          .registerWarranty(
            serialNumber: _serialController.text.trim(),
            productId: _selectedProductId!,
            warrantyPeriodMonths: _warrantyMonths,
            purchaseDate: _purchaseDate.toIso8601String().split('T')[0],
            invoiceId: _selectedInvoiceId!,
            customerId: _selectedCustomerId,
          );

      final state = ref.read(warrantyProvider);
      if (state.warranty != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Warranty registered successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Clear form
        _serialController.clear();
        setState(() {
          _warrantyMonths = 12;
          _purchaseDate = DateTime.now();
          _selectedProductId = null;
          _selectedProductLabel = null;
          _selectedInvoiceId = null;
          _selectedInvoiceLabel = null;
          _selectedCustomerId = null;
          _selectedCustomerLabel = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openProductPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollController) => ProductSearchBottomSheet(
          jobId: '',
          onProductSelected: (productId, productName, _, __) {
            setState(() {
              _selectedProductId = productId;
              _selectedProductLabel = productName;
            });
            Navigator.of(ctx).pop();
          },
        ),
      ),
    );
  }

  void _openInvoicePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, __) => InvoiceSearchBottomSheet(
          onInvoiceSelected: (invoiceId, invoiceLabel) {
            setState(() {
              _selectedInvoiceId = invoiceId;
              _selectedInvoiceLabel = invoiceLabel;
            });
          },
        ),
      ),
    );
  }

  void _openCustomerPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, __) => CustomerSearchBottomSheet(
          onCustomerSelected: (customerId, customerLabel) {
            setState(() {
              _selectedCustomerId = customerId;
              _selectedCustomerLabel = customerLabel;
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final warrantyState = ref.watch(warrantyProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.add_card, color: Color(0xFF3B82F6)),
                        SizedBox(width: 8),
                        Text(
                          'Register New Warranty',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Serial Number
                    TextFormField(
                      controller: _serialController,
                      decoration: InputDecoration(
                        labelText: 'Serial Number *',
                        prefixIcon: const Icon(Icons.confirmation_number),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: ComputerShopValidators.validateSerial,
                    ),
                    const SizedBox(height: 16),

                    // Product ID — Picker (Req 20.4, 22.1, 22.3)
                    _PickerTile(
                      label: 'Product *',
                      icon: Icons.inventory_2,
                      selectedLabel: _selectedProductLabel,
                      placeholder: 'Select Product',
                      onTap: () => _openProductPicker(),
                    ),
                    const SizedBox(height: 16),

                    // Warranty Period
                    DropdownButtonFormField<int>(
                      value: _warrantyMonths,
                      decoration: InputDecoration(
                        labelText: 'Warranty Period *',
                        prefixIcon: const Icon(Icons.timelapse),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: [6, 12, 24, 36, 48, 60].map((months) {
                        return DropdownMenuItem(
                          value: months,
                          child: Text('$months months'),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _warrantyMonths = v!),
                    ),
                    const SizedBox(height: 16),

                    // Purchase Date
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _purchaseDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (!mounted) return;
                        if (picked != null) {
                          // Defense-in-depth: reject future dates, retain prior value.
                          final error =
                              ComputerShopValidators.validatePurchaseDate(
                                picked,
                              );
                          if (error == null) {
                            setState(() => _purchaseDate = picked);
                          }
                          // If validation fails, _purchaseDate retains its prior value.
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Purchase Date *',
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          DateFormat('dd MMM yyyy').format(_purchaseDate),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Invoice — Picker (Req 20.4, 22.1)
                    _PickerTile(
                      label: 'Invoice *',
                      icon: Icons.receipt,
                      selectedLabel: _selectedInvoiceLabel,
                      placeholder: 'Select Invoice',
                      onTap: () => _openInvoicePicker(),
                    ),
                    const SizedBox(height: 16),

                    // Customer — Picker (optional, Req 22.1)
                    _PickerTile(
                      label: 'Customer (Optional)',
                      icon: Icons.person,
                      selectedLabel: _selectedCustomerLabel,
                      placeholder: 'Select Customer',
                      onTap: () => _openCustomerPicker(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: warrantyState.isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: warrantyState.isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Registering...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save),
                          SizedBox(width: 8),
                          Text(
                            'Register Warranty',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Shared Picker Tile Widget
// ============================================================================

/// A tappable tile that displays a selected item label or a placeholder,
/// styled to match the form field appearance. Used to replace raw UUID text
/// fields with picker-based selection (Req 22.2).
class _PickerTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? selectedLabel;
  final String placeholder;
  final VoidCallback onTap;

  const _PickerTile({
    required this.label,
    required this.icon,
    required this.selectedLabel,
    required this.placeholder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedLabel != null && selectedLabel!.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.arrow_drop_down),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          hasSelection ? selectedLabel! : placeholder,
          style: TextStyle(
            fontSize: 16,
            color: hasSelection
                ? Theme.of(context).colorScheme.onSurface
                : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}
