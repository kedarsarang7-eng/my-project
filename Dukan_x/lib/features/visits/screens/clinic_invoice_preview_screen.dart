import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../models/bill.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/database/app_database.dart';
import 'package:dukanx/core/responsive/responsive.dart'; // For fetching bill if needed, or repo

class ClinicInvoicePreviewScreen extends StatefulWidget {
  final String billId;

  const ClinicInvoicePreviewScreen({super.key, required this.billId});

  @override
  State<ClinicInvoicePreviewScreen> createState() =>
      _ClinicInvoicePreviewScreenState();
}

class _ClinicInvoicePreviewScreenState
    extends State<ClinicInvoicePreviewScreen> {
  Bill? _bill;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBill();
  }

  Future<void> _loadBill() async {
    final db = sl<AppDatabase>();
    final billEntity = await (db.select(
      db.bills,
    )..where((t) => t.id.equals(widget.billId))).getSingleOrNull();

    if (billEntity != null) {
      // We also need items
      final itemsEntity = await (db.select(
        db.billItems,
      )..where((t) => t.billId.equals(widget.billId))).get();

      // Convert to Model (Simplified for preview)
      final items = itemsEntity
          .map(
            (e) => BillItem(
              productId: e.productId ?? '',
              productName: e.productName,
              qty: e.quantity,
              price: e.unitPrice,
              // ... simple mapping
              gstRate: e.cgstRate + e.sgstRate + e.igstRate,
            ),
          )
          .toList();

      if (mounted) {
        setState(() {
          _bill = Bill(
            id: billEntity.id,
            invoiceNumber: billEntity.invoiceNumber,
            customerId: billEntity.customerId ?? '',
            customerName: billEntity.customerName ?? 'Walk-in',
            date: billEntity.billDate,
            items: items,
            grandTotal: billEntity.grandTotal,
            subtotal: billEntity.subtotal,
            totalTax: billEntity.taxAmount,
            // ...
          );
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: FuturisticColors.backgroundDark,
        body: BoundedBox(
          maxWidth: 800,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_bill == null) {
      return const Scaffold(body: Center(child: Text('Invoice Not Found')));
    }

    return Scaffold(
      backgroundColor: Colors.grey[100], // Professional Paper bg
      appBar: AppBar(
        title: Text(
          'Invoice Preview',
          style: GoogleFonts.outfit(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(icon: const Icon(Icons.print), onPressed: () {}),
          IconButton(icon: const Icon(Icons.share), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _buildHeader(),
              const Divider(height: 48),

              // Patient Info
              _buildPatientInfo(),
              const SizedBox(height: 32),

              // Items
              _buildItemsTable(),
              const SizedBox(height: 32),

              // Totals
              _buildTotals(),
              const SizedBox(height: 48),

              // Footer
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HEALTH PLUS CLINIC',
                  style: GoogleFonts.outfit(
                    fontSize: responsiveValue<double>(context, mobile: 18, tablet: 20, desktop: 24),
                    fontWeight: FontWeight.bold,
                    color: FuturisticColors.neonBlue,
                  ),
                ),
                Text(
                  'Dr. Strange, MD',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'Reg No. 12345/MMC',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'INVOICE',
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey[200],
                  ),
                ),
                Text(
                  _bill!.invoiceNumber,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  DateFormat('dd MMM yyyy').format(_bill!.date),
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPatientInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BILL TO',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Colors.blue[900],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _bill!.customerName.isNotEmpty
                ? _bill!.customerName
                : 'Walk-in Patient',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          // Text('Age: 32 | Gender: M', style: GoogleFonts.outfit(fontSize: 14, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildItemsTable() {
    return Column(
      children: [
        // Header
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                'DESCRIPTION',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                'QTY',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                'PRICE',
                textAlign: TextAlign.right,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                'TOTAL',
                textAlign: TextAlign.right,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
        const Divider(),
        // Items
        ..._bill!.items.map(
          (item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    item.productName,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    item.qty.toString(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    item.price.toStringAsFixed(2),
                    textAlign: TextAlign.right,
                    style: GoogleFonts.outfit(),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    (item.qty * item.price).toStringAsFixed(2),
                    textAlign: TextAlign.right,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTotals() {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 200,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal:',
                  style: GoogleFonts.outfit(color: Colors.black54),
                ),
                Text(
                  _bill!.subtotal.toStringAsFixed(2),
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total:',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '₹${_bill!.grandTotal.toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: FuturisticColors.neonBlue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Text(
        'Thank you for choosing Health Plus!',
        style: GoogleFonts.outfit(color: Colors.black38, fontSize: 12),
      ),
    );
  }
}
