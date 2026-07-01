// OCR Screen
//
// Display extracted text and structured data from document.
// Provides "Convert to Digital Bill" CTA for billing integration.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../theme/p2d_theme.dart';
import '../widgets/widgets.dart';
import '../../../../core/di/service_locator.dart';
import '../../../ml/ml_services/ocr_service.dart';
import '../../../ml/ml_models/ocr_result.dart';
import '../../../purchase/screens/add_purchase_screen.dart';
import '../../../../core/repository/purchase_repository.dart';
import 'p2d_export_screen.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class P2DOcrScreen extends StatefulWidget {
  final Uint8List imageBytes;

  const P2DOcrScreen({super.key, required this.imageBytes});

  @override
  State<P2DOcrScreen> createState() => _P2DOcrScreenState();
}

class _P2DOcrScreenState extends State<P2DOcrScreen> {
  OcrResult? _ocrResult;
  bool _isProcessing = true;

  @override
  void initState() {
    super.initState();
    _processOcr();
  }

  Future<void> _processOcr() async {
    try {
      // Save image temporarily for OCR
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/p2d_ocr_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await tempFile.writeAsBytes(widget.imageBytes);

      final ocrService = sl<MLKitOcrService>();
      final result = await ocrService.recognizeTextAutoDetect(tempFile.path);

      if (mounted) {
        setState(() {
          _ocrResult = result;
          _isProcessing = false;
        });
      }
    } catch (e) {
      debugPrint('OCR error: $e');
      if (mounted) {
        setState(() {
          _ocrResult = OcrResult.empty();
          _isProcessing = false;
        });
      }
    }
  }

  void _convertToBill() {
    if (_ocrResult == null) return;

    HapticFeedback.heavyImpact();

    // Map OCR result to PurchaseOrder
    final purchaseItems = _ocrResult!.items
        .map(
          (e) => PurchaseItem(
            id: const Uuid().v4(),
            productId: null,
            productName: e.name,
            quantity: e.quantity,
            unit: 'pc',
            costPrice: e.price,
            taxRate: 0,
            totalAmount: e.amount,
          ),
        )
        .toList();

    final purchaseOrder = PurchaseOrder(
      id: const Uuid().v4(),
      userId: '',
      vendorName: _ocrResult!.shopName,
      invoiceNumber: '',
      items: purchaseItems,
      totalAmount: _ocrResult!.totalAmount,
      purchaseDate: _ocrResult!.billDate ?? DateTime.now(),
      createdAt: DateTime.now(),
      paymentMode: 'Credit',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddPurchaseScreen(initialBill: purchaseOrder),
      ),
    );
  }

  void _proceedToExport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => P2DExportScreen(
          imageBytes: widget.imageBytes,
          ocrResult: _ocrResult,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kP2DBackground,
      body: Center(
        child: BoundedBox(
          maxWidth: 600,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Content
              SafeArea(
                child: _isProcessing ? _buildLoadingState() : _buildOcrResults(),
              ),

              // Top bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 8,
                    right: 8,
                    bottom: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [kP2DBackground, kP2DBackground.withOpacity(0)],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      NeonButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.psychology_rounded,
                            color: kP2DAccentCyan,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'AI Insights',
                            style: TextStyle(
                              color: kP2DTextPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      NeonButton(
                        icon: Icons.arrow_forward_rounded,
                        onTap: _proceedToExport,
                        isActive: !_isProcessing,
                        color: kP2DGlowSuccess,
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

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: kP2DAccentCyan),
          const SizedBox(height: 24),
          Text(
            'Extracting Intelligence...',
            style: TextStyle(color: kP2DTextSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildOcrResults() {
    final result = _ocrResult!;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: 80,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 120,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Extracted data cards
          if (result.shopName.isNotEmpty)
            _buildDataRow(
              icon: Icons.store_rounded,
              label: 'Vendor',
              value: result.shopName,
            ),

          if (result.billDate != null)
            _buildDataRow(
              icon: Icons.calendar_today_rounded,
              label: 'Date',
              value: _formatDate(result.billDate!),
            ),

          if (result.totalAmount > 0)
            _buildDataRow(
              icon: Icons.currency_rupee_rounded,
              label: 'Total',
              value: '₹${result.totalAmount.toStringAsFixed(2)}',
              highlight: true,
            ),

          if (result.gst > 0)
            _buildDataRow(
              icon: Icons.receipt_long_rounded,
              label: 'GST',
              value: '₹${result.gst.toStringAsFixed(2)}',
            ),

          const SizedBox(height: 24),

          // Items list
          if (result.items.isNotEmpty) ...[
            Text(
              'Detected Items (${result.items.length})',
              style: const TextStyle(
                color: kP2DTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...result.items.take(10).map((item) => _buildItemRow(item)),
          ],

          const SizedBox(height: 24),

          // Raw text preview
          if (result.rawText.isNotEmpty) ...[
            Text(
              'Raw Text',
              style: const TextStyle(
                color: kP2DTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            GlassPanel(
              padding: const EdgeInsets.all(12),
              child: Text(
                result.rawText.length > 500
                    ? '${result.rawText.substring(0, 500)}...'
                    : result.rawText,
                style: const TextStyle(
                  color: kP2DTextMuted,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Convert to Bill CTA
          if (result.items.isNotEmpty || result.totalAmount > 0)
            Center(
              child: GestureDetector(
                onTap: _convertToBill,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: kP2DAccentCyan, width: 1.5),
                    boxShadow: [kP2DNeonGlow(kP2DAccentCyan, blur: 15)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: kP2DAccentCyan,
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Convert to Digital Bill',
                        style: TextStyle(
                          color: kP2DAccentCyan,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDataRow({
    required IconData icon,
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassPanel(
        padding: const EdgeInsets.all(16),
        glowColor: highlight ? kP2DAccentCyan : null,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: kP2DAccentCyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: kP2DAccentCyan, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: kP2DTextMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: kP2DTextPrimary,
                      fontSize: highlight ? 18 : 15,
                      fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
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

  Widget _buildItemRow(dynamic item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: kP2DGlassSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kP2DGlassBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                style: const TextStyle(color: kP2DTextPrimary, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '₹${item.amount.toStringAsFixed(0)}',
              style: const TextStyle(
                color: kP2DAccentCyan,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
