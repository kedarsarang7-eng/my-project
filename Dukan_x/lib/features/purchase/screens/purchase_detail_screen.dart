import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/repository/purchase_repository.dart';
import '../../../core/theme/futuristic_colors.dart';
import '../../../widgets/modern_ui_components.dart';
import 'package:dukanx/core/responsive/responsive_layout.dart';

class PurchaseDetailScreen extends StatelessWidget {
  final PurchaseOrder order;

  const PurchaseDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    // Detect if we need special columns
    final hasBatchInfo = order.items.any(
      (i) => i.batchNumber != null && i.batchNumber!.isNotEmpty,
    );
    final hasExpiryInfo = order.items.any((i) => i.expiryDate != null);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Purchase Details',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: FuturisticColors.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: context.isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 20),
                  _buildItemsSectionTitle(context),
                  const SizedBox(height: 10),
                  _buildItemsList(hasBatchInfo, hasExpiryInfo),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _buildHeaderCard(),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 7,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildItemsSectionTitle(context),
                        const SizedBox(height: 10),
                        _buildItemsList(hasBatchInfo, hasExpiryInfo),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return ModernCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Inv: ${order.invoiceNumber ?? "N/A"}',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: FuturisticColors.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: order.status == 'COMPLETED'
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  order.status,
                  style: TextStyle(
                    color: order.status == 'COMPLETED'
                        ? Colors.green
                        : Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow('Vendor', order.vendorName ?? 'Unknown'),
          _infoRow(
            'Date',
            DateFormat('dd MMM yyyy').format(order.purchaseDate),
          ),
          const Divider(),
          _infoRow(
            'Total Amount',
            '₹${order.totalAmount.toStringAsFixed(2)}',
            isBold: true,
            color: FuturisticColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSectionTitle(BuildContext context) {
    return Text(
      'Items Purchased',
      style: GoogleFonts.outfit(
        fontSize: responsiveValue<double>(context,
          mobile: 14.0,
          tablet: 16.0,
          desktop: 18.0,
        ),
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildItemsList(bool hasBatchInfo, bool hasExpiryInfo) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: order.items.length,
      itemBuilder: (context, index) {
        final item = order.items[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.productName,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Text(
                      '₹${item.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '${item.quantity} ${item.unit} x ₹${item.costPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                // Dynamic Pharmacy Fields
                if (hasBatchInfo && item.batchNumber != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      'Batch: ${item.batchNumber}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                ],
                if (hasExpiryInfo && item.expiryDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Expiry: ${DateFormat('MM/yyyy').format(item.expiryDate!)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: item.expiryDate!.isBefore(DateTime.now())
                          ? Colors.red
                          : Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
