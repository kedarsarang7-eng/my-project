// ============================================================================
// CUSTOMER LEDGER SCREEN
// ============================================================================
// Shows debit/credit ledger entries for a customer-vendor relationship
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';

import '../../../customers/data/customer_ledger_repository.dart';
import '../../../customers/data/customer_dashboard_repository.dart';
import '../../services/customer_ledger_pdf_service.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class CustomerLedgerScreen extends ConsumerStatefulWidget {
  final String customerId;
  final String? vendorId;

  const CustomerLedgerScreen({
    super.key,
    required this.customerId,
    this.vendorId,
  });

  @override
  ConsumerState<CustomerLedgerScreen> createState() =>
      _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends ConsumerState<CustomerLedgerScreen> {
  String? _selectedVendorId;
  VendorConnection? _selectedVendor;

  @override
  void initState() {
    super.initState();
    _selectedVendorId = widget.vendorId;
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vendorsAsync = ref.watch(connectedVendorsProvider(widget.customerId));

    return DesktopContentContainer(
      title: 'Ledger',
      subtitle: 'Track debit and credit entries',
      actions: [
        DesktopIconButton(
          icon: Icons.picture_as_pdf,
          tooltip: 'Export PDF',
          onPressed: _exportPdf,
        ),
      ],
      child: Column(
        children: [
          // Vendor Selector
          vendorsAsync.when(
            data: (vendors) {
              if (vendors.isEmpty) {
                return const SizedBox.shrink();
              }
              if (_selectedVendorId == null && vendors.isNotEmpty) {
                _selectedVendorId = vendors.first.vendorId;
                _selectedVendor = vendors.first;
              }
              return _buildVendorSelector(vendors);
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const SizedBox.shrink(),
          ),

          // Ledger Entries
          Expanded(
            child: _selectedVendorId == null
                ? _buildNoVendorSelected()
                : _buildLedgerList(),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorSelector(List<VendorConnection> vendors) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Vendor',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedVendorId,
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            items: vendors.map((v) {
              return DropdownMenuItem(
                value: v.vendorId,
                child: Text(v.vendorName, style: GoogleFonts.poppins()),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedVendorId = value;
                _selectedVendor = vendors.firstWhere(
                  (v) => v.vendorId == value,
                );
              });
            },
          ),
          if (_selectedVendor != null) ...[
            const SizedBox(height: 16),
            _buildBalanceSummary(),
          ],
        ],
      ),
    );
  }

  Widget _buildBalanceSummary() {
    final balance = _selectedVendor?.outstandingBalance ?? 0;
    final isPositive = balance > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPositive
              ? [const Color(0xFFFF6B6B), const Color(0xFFEE5253)]
              : [const Color(0xFF00B894), const Color(0xFF00CEC9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Balance',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                '₹${balance.abs().toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isPositive ? 'You Owe' : 'All Clear',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerList() {
    final entriesAsync = ref.watch(
      customerLedgerEntriesProvider((
        customerId: widget.customerId,
        vendorId: _selectedVendorId!,
      )),
    );

    return entriesAsync.when(
      data: (entries) {
        if (entries.isEmpty) {
          return _buildEmptyLedger();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          itemBuilder: (context, index) => _buildLedgerEntry(entries[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildLedgerEntry(LedgerEntry entry) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDebit = entry.isDebit;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: isDebit ? Colors.red : Colors.green,
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                entry.referenceNumber ?? entry.entryTypeString,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              Text(
                '${isDebit ? '+' : '-'}₹${entry.amount.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: isDebit ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('dd MMM yyyy').format(entry.entryDate),
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
              ),
              Text(
                'Bal: ₹${entry.runningBalance.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          if (entry.description != null) ...[
            const SizedBox(height: 8),
            Text(
              entry.description!,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoVendorSelected() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Select a vendor to view ledger',
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyLedger() {
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
            'No transactions yet',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdf() async {
    if (_selectedVendorId == null || _selectedVendor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a vendor first')),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Generating PDF...')));

    try {
      // Get ledger entries
      final ledgerRepo = ref.read(customerLedgerRepositoryProvider);
      final result = await ledgerRepo.getLedgerEntries(
        customerId: widget.customerId,
        vendorId: _selectedVendorId!,
      );

      if (!result.isSuccess || result.data == null || result.data!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No entries to export')));
        }
        return;
      }

      // Generate PDF
      final pdfService = CustomerLedgerPdfService();
      final bytes = await pdfService.generateLedgerPdf(
        customerName: 'Customer', // In production, get from session
        vendor: _selectedVendor!,
        entries: result.data!,
      );

      // Share
      final fileName =
          'ledger_${_selectedVendor!.vendorName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await pdfService.sharePdf(bytes, fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
