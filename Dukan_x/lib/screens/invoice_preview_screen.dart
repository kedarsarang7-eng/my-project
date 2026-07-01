import 'package:flutter/material.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';
import '../core/theme/futuristic_colors.dart';
import '../models/invoice_editable.dart';

/// Professional Invoice Preview & Export Screen
/// - Beautiful, colorful invoice layout
/// - Matches handwritten screenshot style
/// - PDF export ready
/// - Print-friendly format
/// - Signature & stamp display

class InvoicePreviewScreen extends StatefulWidget {
  final EditableInvoice invoice;
  final VoidCallback? onEdit;
  final VoidCallback? onExportPDF;
  final VoidCallback? onPrint;

  const InvoicePreviewScreen({
    super.key,
    required this.invoice,
    this.onEdit,
    this.onExportPDF,
    this.onPrint,
  });

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  bool _showOptions = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Preview'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => setState(() => _showOptions = !_showOptions),
          ),
        ],
      ),
      body: ResponsiveContainer(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Action buttons
              if (_showOptions) _buildActionBar(),

              // Invoice content
              Padding(
                padding: EdgeInsets.all(isMobile ? 12 : 20),
                child: _buildInvoiceContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      color: Colors.blue[50],
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(Icons.edit, 'Edit', widget.onEdit),
          _buildActionButton(Icons.picture_as_pdf, 'PDF', widget.onExportPDF),
          _buildActionButton(Icons.print, 'Print', widget.onPrint),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildInvoiceContent() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with colorful border
          _buildHeader(),
          const SizedBox(height: 24),

          // Invoice number and date
          _buildInvoiceInfo(),
          const SizedBox(height: 20),

          // Customer details
          _buildCustomerDetails(),
          const SizedBox(height: 20),

          // Items table
          _buildItemsTable(),
          const SizedBox(height: 20),

          // Charges table
          _buildChargesTable(),
          const SizedBox(height: 20),

          // Totals
          _buildTotalsSection(),
          const SizedBox(height: 20),

          // Signature & Stamp
          _buildSignatureSection(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: FuturisticColors.primaryGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: FuturisticColors.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            widget.invoice.shopName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'à¤¸à¥à¤µà¤¾à¤®à¥€: ${widget.invoice.ownerName}',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'à¤¸à¤¬à¥à¤œà¥€ à¤µ à¤«à¥‚à¤¡ à¤šà¥‡ à¤•à¤®à¤¿à¤¶à¤¨ à¤à¤œà¤¨à¥à¤Ÿ',
            style: TextStyle(color: Colors.amber[100], fontSize: 12),
          ),
          const SizedBox(height: 8),
          Container(
            height: 1,
            color: Colors.white,
            margin: const EdgeInsets.symmetric(vertical: 8),
          ),
          Text(
            'ðŸ“ž ${widget.invoice.ownerPhone}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          Text(
            'ðŸ“ ${widget.invoice.ownerAddress}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          if (widget.invoice.gstNumber != null &&
              widget.invoice.gstNumber!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'GST: ${widget.invoice.gstNumber}',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInvoiceInfo() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[50],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Customer name appears before invoice number as requested
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'à¤—à¥à¤°à¤¾à¤¹à¤•à¤¾à¤šà¥‡ à¤¨à¤¾à¤µ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                widget.invoice.customerName,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              const Text(
                'à¤¬à¤¿à¤² à¤•à¥à¤°à¤®à¤¾à¤‚à¤•',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                widget.invoice.invoiceNumber,
                style: const TextStyle(fontSize: 16, color: Colors.blue),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'à¤¤à¤¾à¤°à¥€à¤–',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                widget.invoice.formattedDate,
                style: const TextStyle(fontSize: 16, color: Colors.blue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerDetails() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange[300]!, width: 2),
        borderRadius: BorderRadius.circular(8),
        color: Colors.orange[50],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'à¤–à¤°à¥‡à¤¦à¥€à¤¦à¤¾à¤°à¤šà¥‡ à¤¤à¤ªà¤¶à¥€à¤²',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'à¤¨à¤¾à¤µ: ${widget.invoice.customerName}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'à¤—à¤¾à¤µ: ${widget.invoice.customerVillage}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'à¤µà¥‡à¤³: ${widget.invoice.formattedTime}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTable() {
    if (widget.invoice.items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('No items in this invoice'),
      );
    }

    return Column(
      children: [
        // Table header
        Container(
          decoration: BoxDecoration(
            color: Colors.blue[600],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(flex: 3, child: _buildHeaderText('à¤®à¤¾à¤²à¤¾à¤šà¤¾ à¤µà¤¿à¤µà¤°à¤£')),
              Expanded(flex: 1, child: _buildHeaderText('à¤®à¤¨')),
              Expanded(flex: 2, child: _buildHeaderText('à¤•à¤¿à¤²à¥‹')),
              Expanded(flex: 2, child: _buildHeaderText('à¤­à¤¾à¤µ')),
              Expanded(flex: 2, child: _buildHeaderText('à¤à¤•à¥‚à¤£')),
            ],
          ),
        ),

        // Table rows
        ...List.generate(widget.invoice.items.length, (index) {
          final item = widget.invoice.items[index];
          final isAlternate = index % 2 == 0;

          return Container(
            color: isAlternate ? Colors.blue[50] : Colors.white,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    item.itemName,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    item.manQuantity?.toStringAsFixed(2) ?? '-',
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    item.kiloWeight.toStringAsFixed(2),
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'â‚¹${item.ratePerKilo.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'â‚¹${item.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        }),

        // Table footer
        Container(
          decoration: BoxDecoration(
            color: Colors.blue[700],
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'à¤®à¤¾à¤²à¤¾à¤šà¥€ à¤à¤•à¥‚à¤£: â‚¹${widget.invoice.getItemsTotal().toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderText(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildChargesTable() {
    if (widget.invoice.charges.getTotalCharges() == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.purple[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.purple[50],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'à¤–à¤°à¥à¤š',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.purple,
            ),
          ),
          const SizedBox(height: 12),
          if (widget.invoice.charges.okshanKharcha > 0)
            _buildChargeRow(
              'à¤‘à¤•à¥à¤¶à¤¨ / à¤…à¤¡à¥à¤¡à¤¾ à¤–à¤°à¥à¤š',
              widget.invoice.charges.okshanKharcha,
            ),
          if (widget.invoice.charges.nagarpalika > 0)
            _buildChargeRow('à¤¨à¤—à¤°à¤ªà¤¾à¤²à¤¿à¤•à¤¾', widget.invoice.charges.nagarpalika),
          if (widget.invoice.charges.commission > 0)
            _buildChargeRow('à¤•à¤®à¤¿à¤¶à¤¨', widget.invoice.charges.commission),
          if (widget.invoice.charges.hamali > 0)
            _buildChargeRow('à¤¹à¤®à¤¾à¤²à¥€', widget.invoice.charges.hamali),
          if (widget.invoice.charges.vetChithi > 0)
            _buildChargeRow('à¤µ. à¤šà¤¿à¤ à¥à¤ à¥€', widget.invoice.charges.vetChithi),
          if (widget.invoice.charges.gadiKhada > 0)
            _buildChargeRow('à¤—à¤¾à¤¡à¥€ à¤­à¤¾à¤¡à¤¾', widget.invoice.charges.gadiKhada),
        ],
      ),
    );
  }

  Widget _buildChargeRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(
            'â‚¹${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsSection() {
    final itemsTotal = widget.invoice.getItemsTotal();
    final chargesTotal = widget.invoice.charges.getTotalCharges();
    final finalTotal = widget.invoice.getFinalTotal();

    return Container(
      decoration: BoxDecoration(
        gradient: FuturisticColors.primaryGradient,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTotalRow('à¤®à¤¾à¤²à¤¾à¤šà¥€ à¤à¤•à¥‚à¤£', itemsTotal),
          const Divider(color: Colors.white30),
          _buildTotalRow('à¤–à¤°à¥à¤š à¤à¤•à¥‚à¤£', chargesTotal),
          Container(
            height: 2,
            color: Colors.white,
            margin: const EdgeInsets.symmetric(vertical: 8),
          ),
          _buildTotalRow('à¤…à¤‚à¤¤à¤¿à¤® à¤à¤•à¥‚à¤£', finalTotal, isBold: true, isLarge: true),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    double amount, {
    bool isBold = false,
    bool isLarge = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isLarge ? 16 : 13,
          ),
        ),
        Text(
          'â‚¹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: Colors.white,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isLarge ? 18 : 13,
          ),
        ),
      ],
    );
  }

  Widget _buildSignatureSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (widget.invoice.ownerSignatureUrl != null &&
            widget.invoice.ownerSignatureUrl!.isNotEmpty)
          Column(
            children: [
              Container(
                width: 100,
                height: 60,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    widget.invoice.ownerSignatureUrl!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text('à¤¸à¥à¤µà¤¾à¤•à¥à¤·à¤°', style: TextStyle(fontSize: 11)),
            ],
          ),
        if (widget.invoice.stampUrl != null &&
            widget.invoice.stampUrl!.isNotEmpty)
          Column(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    widget.invoice.stampUrl!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text('à¤¦à¥à¤•à¤¾à¤¨à¤¦à¤¾à¤°à¤šà¥‡ à¤›à¤¾à¤ª', style: TextStyle(fontSize: 11)),
            ],
          ),
      ],
    );
  }
}
