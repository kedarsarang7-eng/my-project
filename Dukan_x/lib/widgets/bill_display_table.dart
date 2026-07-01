import 'package:flutter/material.dart';
import '../core/theme/futuristic_colors.dart';
import '../models/bill.dart';

/// Excel-style bill display table widget with borders, alternating colors, and proper alignment
class BillDisplayTable extends StatelessWidget {
  final List<BillItem> items;
  final double subtotal;
  final double discountApplied;
  final double total;
  final String status;
  final double fontSize;

  const BillDisplayTable({
    required this.items,
    required this.subtotal,
    required this.discountApplied,
    required this.total,
    required this.status,
    this.fontSize = 12.0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Table Header
            Container(
              decoration: BoxDecoration(
                color: FuturisticColors.primary,
                border: Border.all(color: Colors.grey.shade400, width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildTableCell(
                      'Vegetable Name',
                      fontWeight: FontWeight.bold,
                      textColor: Colors.white,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _buildTableCell(
                      'Price/KG',
                      textAlign: TextAlign.center,
                      fontWeight: FontWeight.bold,
                      textColor: Colors.white,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _buildTableCell(
                      'Qty (KG)',
                      textAlign: TextAlign.center,
                      fontWeight: FontWeight.bold,
                      textColor: Colors.white,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _buildTableCell(
                      'Total (Rs.)',
                      textAlign: TextAlign.right,
                      fontWeight: FontWeight.bold,
                      textColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Table Rows with alternating colors
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isEven = index % 2 == 0;
              final rowColor = isEven ? Colors.grey[50] : Colors.white;

              return Container(
                decoration: BoxDecoration(
                  color: rowColor,
                  border: Border.all(color: Colors.grey.shade300, width: 0.5),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: _buildTableCell(item.vegName)),
                    Expanded(
                      flex: 2,
                      child: _buildTableCell(
                        '₹${item.pricePerKg.toStringAsFixed(0)}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildTableCell(
                        item.qtyKg.toStringAsFixed(2),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildTableCell(
                        '₹${item.total.toStringAsFixed(2)}',
                        textAlign: TextAlign.right,
                        fontWeight: FontWeight.bold,
                        textColor: FuturisticColors.success,
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 12),

            // Summary Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildSummaryRow('Subtotal:', subtotal),
                  if (discountApplied > 0) ...[
                    const SizedBox(height: 4),
                    _buildSummaryRow(
                      'Discount:',
                      -discountApplied,
                      color: FuturisticColors.error,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: FuturisticColors.paidBackground,
                      border: Border.all(color: FuturisticColors.paid),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _buildSummaryRow(
                      'TOTAL:',
                      total,
                      isBold: true,
                      fontSize: fontSize + 2,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: status == 'Paid'
                    ? FuturisticColors.paidBackground
                    : FuturisticColors.unpaidBackground,
                border: Border.all(
                  color: status == 'Paid'
                      ? FuturisticColors.paid
                      : FuturisticColors.unpaid,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    status == 'Paid' ? Icons.check_circle : Icons.cancel,
                    color: status == 'Paid'
                        ? FuturisticColors.paid
                        : FuturisticColors.unpaid,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Status: $status',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: status == 'Paid'
                          ? FuturisticColors.paid
                          : FuturisticColors.unpaid,
                      fontSize: fontSize,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCell(
    String text, {
    TextAlign textAlign = TextAlign.left,
    FontWeight fontWeight = FontWeight.normal,
    Color? textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        text,
        textAlign: textAlign,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: textColor ?? Colors.black,
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double amount, {
    Color color = Colors.black,
    bool isBold = false,
    double fontSize = 12,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
        const SizedBox(width: 16),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }
}
