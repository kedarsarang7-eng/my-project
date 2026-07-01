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
import 'package:dukanx/core/responsive/responsive.dart';

class WarrantyScreen extends ConsumerStatefulWidget {
  const WarrantyScreen({super.key});

  @override
  ConsumerState<WarrantyScreen> createState() => _WarrantyScreenState();
}

class _WarrantyScreenState extends ConsumerState<WarrantyScreen> {
  int _selectedTab = 0;
  final _serialSearchController = TextEditingController();

  @override
  void dispose() {
    _serialSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
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
                color: Color(0xFF1E293B),
              ),
            ),
            Text(
              'Track & Register Product Warranties',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Column(
          children: [
            // Tab Bar
            Container(
              color: Colors.white,
              child: TabBar(
                onTap: (index) => setState(() => _selectedTab = index),
                indicatorColor: const Color(0xFF3B82F6),
                labelColor: const Color(0xFF3B82F6),
                unselectedLabelColor: Colors.grey.shade600,
                tabs: const [
                  Tab(text: 'Lookup', icon: Icon(Icons.search)),
                  Tab(text: 'Register', icon: Icon(Icons.add_card)),
                ],
              ),
            ),
            // Tab Content
            Expanded(
              child: IndexedStack(
                index: _selectedTab,
                children: [
                  _WarrantyLookupTab(
                    searchController: _serialSearchController,
                    onSearch: () => ref
                        .read(warrantyProvider.notifier)
                        .lookupWarranty(_serialSearchController.text.trim()),
                  ),
                  const _WarrantyRegisterTab(),
                ],
              ),
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
              color: valueColor ?? const Color(0xFF1E293B),
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
                // Switch to register tab
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
  final _productIdController = TextEditingController();
  final _invoiceIdController = TextEditingController();
  final _customerIdController = TextEditingController();
  int _warrantyMonths = 12;
  DateTime _purchaseDate = DateTime.now();

  @override
  void dispose() {
    _serialController.dispose();
    _productIdController.dispose();
    _invoiceIdController.dispose();
    _customerIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await ref
          .read(warrantyProvider.notifier)
          .registerWarranty(
            serialNumber: _serialController.text.trim(),
            productId: _productIdController.text.trim(),
            warrantyPeriodMonths: _warrantyMonths,
            purchaseDate: _purchaseDate.toIso8601String().split('T')[0],
            invoiceId: _invoiceIdController.text.trim(),
            customerId: _customerIdController.text.isEmpty
                ? null
                : _customerIdController.text.trim(),
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
        _productIdController.clear();
        _invoiceIdController.clear();
        _customerIdController.clear();
        setState(() {
          _warrantyMonths = 12;
          _purchaseDate = DateTime.now();
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
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Product ID
                    TextFormField(
                      controller: _productIdController,
                      decoration: InputDecoration(
                        labelText: 'Product ID *',
                        prefixIcon: const Icon(Icons.inventory_2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
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
                        if (picked != null) {
                          setState(() => _purchaseDate = picked);
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

                    // Invoice ID
                    TextFormField(
                      controller: _invoiceIdController,
                      decoration: InputDecoration(
                        labelText: 'Invoice ID *',
                        prefixIcon: const Icon(Icons.receipt),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Customer ID (Optional)
                    TextFormField(
                      controller: _customerIdController,
                      decoration: InputDecoration(
                        labelText: 'Customer ID (Optional)',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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
