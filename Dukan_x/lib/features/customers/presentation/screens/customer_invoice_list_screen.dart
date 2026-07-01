// ============================================================================
// CUSTOMER INVOICE LIST SCREEN
// ============================================================================
// Shows all invoices for a customer, with filters for status
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import 'dart:convert';
import '../../../../core/pdf/enhanced_invoice_pdf_service.dart';
import '../../../../core/pdf/invoice_models.dart';
import '../../../../services/invoice_pdf_service.dart'; // InvoiceLanguage
import '../../../../features/customers/data/customer_dashboard_repository.dart';
import '../../../../models/business_type.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class CustomerInvoiceListScreen extends ConsumerStatefulWidget {
  final String customerId;
  final String? vendorId; // Optional: filter by vendor

  const CustomerInvoiceListScreen({
    super.key,
    required this.customerId,
    this.vendorId,
  });

  @override
  ConsumerState<CustomerInvoiceListScreen> createState() =>
      _CustomerInvoiceListScreenState();
}

class _CustomerInvoiceListScreenState
    extends ConsumerState<CustomerInvoiceListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<BillEntity> _allInvoices = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInvoices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(customerDashboardRepositoryProvider);

      if (widget.vendorId != null) {
        final result = await repo.getInvoicesFromVendor(
          customerId: widget.customerId,
          vendorId: widget.vendorId!,
        );

        if (result.isSuccess) {
          setState(() {
            _allInvoices = result.data ?? [];
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = result.errorMessage;
            _isLoading = false;
          });
        }
      } else {
        // Load from all vendors
        final vendorsAsync = ref.read(
          connectedVendorsProvider(widget.customerId),
        );

        vendorsAsync.whenData((vendors) async {
          List<BillEntity> all = [];
          for (final vendor in vendors) {
            final result = await repo.getInvoicesFromVendor(
              customerId: widget.customerId,
              vendorId: vendor.vendorId,
            );
            if (result.isSuccess && result.data != null) {
              all.addAll(result.data!);
            }
          }
          // Sort by date
          all.sort((a, b) => b.billDate.compareTo(a.billDate));
          setState(() {
            _allInvoices = all;
            _isLoading = false;
          });
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<BillEntity> get _unpaidInvoices => _allInvoices
      .where((b) => b.status == 'PENDING' || b.status == 'PARTIAL')
      .toList();

  List<BillEntity> get _paidInvoices =>
      _allInvoices.where((b) => b.status == 'PAID').toList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.vendorId != null ? 'Invoices' : 'All Invoices',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: 'All (${_allInvoices.length})'),
            Tab(text: 'Unpaid (${_unpaidInvoices.length})'),
            Tab(text: 'Paid (${_paidInvoices.length})'),
          ],
        ),
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildInvoiceList(_allInvoices),
                _buildInvoiceList(_unpaidInvoices),
                _buildInvoiceList(_paidInvoices),
              ],
            ),
      ),
    );
  }

  Widget _buildInvoiceList(List<BillEntity> invoices) {
    if (invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No invoices found',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInvoices,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: invoices.length,
        itemBuilder: (context, index) => _buildInvoiceCard(invoices[index]),
      ),
    );
  }

  Widget _buildInvoiceCard(BillEntity invoice) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOverdue =
        invoice.dueDate != null &&
        DateTime.now().isAfter(invoice.dueDate!) &&
        invoice.paidAmount < invoice.grandTotal;
    final isPaid = invoice.status == 'PAID';
    final balance = invoice.grandTotal - invoice.paidAmount;

    Color statusColor;
    String statusText;
    if (isPaid) {
      statusColor = Colors.green;
      statusText = 'PAID';
    } else if (isOverdue) {
      statusColor = Colors.red;
      statusText = 'OVERDUE';
    } else if (invoice.status == 'PARTIAL') {
      statusColor = Colors.orange;
      statusText = 'PARTIAL';
    } else {
      statusColor = Colors.blue;
      statusText = 'PENDING';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdue
              ? Colors.red.withOpacity(0.3)
              : (isDark ? Colors.white10 : Colors.grey.shade200),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _openInvoiceDetail(invoice),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '#${invoice.invoiceNumber}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusText,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('dd MMM yyyy').format(invoice.billDate),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (invoice.dueDate != null) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.event, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      'Due: ${DateFormat('dd MMM').format(invoice.dueDate!)}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isOverdue ? Colors.red : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '₹${invoice.grandTotal.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Balance',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '₹${balance.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: isPaid ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            'Failed to load invoices',
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _loadInvoices, child: const Text('Retry')),
        ],
      ),
    );
  }

  Future<void> _openInvoiceDetail(BillEntity invoice) async {
    setState(() => _isLoading = true);
    try {
      // 1. Parse Items directly to EnhancedInvoiceItem (skipping ModelBill intermediary)
      final List<dynamic> itemsList = jsonDecode(invoice.itemsJson);
      final List<EnhancedInvoiceItem> items = itemsList.map((i) {
        final double qty = (i['quantity'] ?? 1).toDouble();
        final double rate = (i['rate'] ?? 0).toDouble();
        return EnhancedInvoiceItem(
          name: i['name'] ?? 'Item',
          quantity: qty,
          unitPrice: rate,
          unit: i['unit'] ?? 'pc',
          // Map other fields if available in JSON
        );
      }).toList();

      // 2. Get Vendor Helper Details for PDF Config
      String shopName = "Shop";
      String ownerName = "Vendor";
      String address = "";
      String mobile = "";

      // Try to find vendor in connected list
      final vendorsState = ref.read(
        connectedVendorsProvider(widget.customerId),
      );
      if (vendorsState.hasValue) {
        final vendor = vendorsState.value!.firstWhere(
          (v) => v.vendorId == invoice.userId,
          orElse: () => VendorConnection(
            id: '',
            customerId: '',
            vendorId: '',
            vendorName: 'Unknown Shop',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        shopName = vendor.vendorName;
        ownerName = vendor.vendorBusinessName ?? vendor.vendorName;
        address = vendor.vendorAddress ?? "";
        mobile = vendor.vendorPhone ?? "";
      }

      // 3. Config
      final config = EnhancedInvoiceConfig(
        businessType: BusinessType.grocery, // Default
        language: InvoiceLanguage.english,
        shopName: shopName,
        ownerName: ownerName,
        address: address,
        mobile: mobile,
      );

      // 4. Customer object
      // We don't have full customer details easily available here without fetching
      // But we can use the basic info or fetch. For now using 'Self' or empty.
      final customer = EnhancedInvoiceCustomer(
        name:
            "Customer", // Ideally fetch from profile if needed, or leave generic "Customer"
        mobile: "", // Can fetch from profile
      );

      // 5. Generate PDF
      final pdfService = EnhancedInvoicePdfService();
      final bytes = await pdfService.generateInvoicePdf(
        items: items,
        config: config,
        customer: customer,
        invoiceNumber: invoice.invoiceNumber,
        invoiceDate: invoice.billDate,
        dueDate: invoice.dueDate, // Now passing due date!
        // We can pass discount/tax info if available in BillEntity fields
        // For now using simple totals
      );

      // 6. Save/Share
      final path = await pdfService.saveInvoice(bytes, invoice.invoiceNumber);

      if (mounted) {
        setState(() => _isLoading = false);
        if (path != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invoice saved to $path'),
              action: SnackBarAction(
                label: 'Open',
                onPressed: () {
                  // Implement open logic if permitted
                },
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save invoice')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
      }
    }
  }
}
