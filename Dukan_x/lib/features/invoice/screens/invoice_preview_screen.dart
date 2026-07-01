// Invoice Preview Screen
//
// Created: 2024-12-25
// Author: DukanX Team

import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dukanx/features/shared/export/services/export_service.dart';
import 'package:dukanx/features/shared/export/services/adapters/export_adapter.dart';
import 'package:dukanx/features/billing/domain/repositories/billing_repository.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../providers/app_state_providers.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/repository/shop_repository.dart';
import '../../../core/pdf/enhanced_invoice_pdf_service.dart';
import '../../../core/pdf/invoice_models.dart';
import '../../../services/invoice_pdf_service.dart' show InvoiceLanguage;
import '../../../services/signature_manager.dart';
import '../../../models/bill.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class InvoicePreviewScreen extends ConsumerStatefulWidget {
  final Bill bill;

  const InvoicePreviewScreen({super.key, required this.bill});

  @override
  ConsumerState<InvoicePreviewScreen> createState() =>
      _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends ConsumerState<InvoicePreviewScreen> {
  final _invoiceService = EnhancedInvoicePdfService();
  final _signatureManager = SignatureManager();
  final _shopRepository = sl<ShopRepository>();
  final _session = sl<SessionManager>();

  Uint8List? _pdfBytes;
  bool _isLoading = true;
  String? _errorMessage;

  // Config loaded from settings
  EnhancedInvoiceConfig? _invoiceConfig;
  String? _terms;

  @override
  void initState() {
    super.initState();
    _loadAndGeneratePdf();
  }

  Future<void> _loadAndGeneratePdf() async {
    try {
      // Load shop settings
      final ownerId = _session.ownerId;
      if (ownerId == null) throw Exception('Not logged in');

      final result = await _shopRepository.getShopProfile(ownerId);
      final profile = result.data;
      final signature = await _signatureManager.getSignature();

      _terms = profile?.invoiceTerms;

      // Build invoice config
      _invoiceConfig = EnhancedInvoiceConfig(
        shopName: profile?.name ?? 'My Shop',
        ownerName: profile?.ownerName ?? '',
        address: profile?.address ?? '',
        mobile: profile?.phone ?? '',
        email: profile?.email,
        gstin: profile?.gstin,
        signatureImage: signature,
        showTax: profile?.showTaxOnInvoice ?? false,
        isGstBill: profile?.isGstRegistered ?? false,
        language: InvoiceLanguage.values[profile?.invoiceLanguage ?? 0],
        businessType: ref.read(businessTypeProvider).type,
        termsAndConditions: _terms,
      );

      // Generate PDF
      final pdfBytes = await _invoiceService.generateFromBill(
        bill: widget.bill,
        config: _invoiceConfig!,
      );

      setState(() {
        _pdfBytes = pdfBytes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error generating invoice: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _shareInvoice() async {
    if (_pdfBytes == null) return;

    try {
      // Generate Smart Payment Link
      // NOTE: UPI payment link is disabled because ShopEntity doesn't have upiId.
      // This feature requires VendorProfile integration which stores UPI ID.
      // When implementing: Check if vendorProfile?.upiId is available.
      String? paymentLink;
      // Future implementation:
      // if (_invoiceConfig != null && widget.bill.grandTotal > 0) {
      //   final vendorProfile = await _getVendorProfile();
      //   if (vendorProfile?.upiId?.isNotEmpty == true) {
      //     paymentLink = PaymentUtils.generateUpiLink(...);
      //   }
      // }

      await _invoiceService.shareInvoice(
        _pdfBytes!,
        widget.bill.invoiceNumber,
        paymentLink: paymentLink,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sharing: $e')));
      }
    }
  }

  Future<void> _printInvoice() async {
    if (_pdfBytes == null) return;

    try {
      await _invoiceService.printInvoice(_pdfBytes!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error printing: $e')));
      }
    }
  }

  Future<void> _downloadInvoice() async {
    if (_pdfBytes == null) return;

    try {
      final path = await _invoiceService.saveInvoice(
        _pdfBytes!,
        widget.bill.invoiceNumber,
      );
      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to: $path'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    }
  }

  Future<void> _handleExport(String format) async {
    setState(() => _isLoading = true);

    try {
      // Lazy load ExportService to avoid DI issues if not registered
      final billingRepo = sl<BillingRepository>(); // Assuming SL has it
      final exportService = ExportService(billingRepo);

      final exportFormat = format == 'excel'
          ? ExportFormat.excel
          : ExportFormat.word;
      final bytes = await exportService.generateBillExport(
        billId: widget.bill.id,
        format: exportFormat,
      );

      // Save file
      final ext = format == 'excel' ? 'xlsx' : 'docx';
      final fileName = 'Invoice_${widget.bill.invoiceNumber}.$ext';
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to: ${file.path}'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () {
                // Open file
                // Use open_file or url_launcher
                // For now just show path
              },
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export Failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final isDark = theme.isDark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          'Invoice Preview',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        actions: [
          if (_pdfBytes != null) ...[
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Download',
              onPressed: _downloadInvoice,
            ),
            IconButton(
              icon: const Icon(Icons.print_rounded),
              tooltip: 'Print',
              onPressed: _printInvoice,
            ),
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Share',
              onPressed: _shareInvoice,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: 'More Options',
              onSelected: _handleExport,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'excel',
                  child: Row(
                    children: [
                      Icon(
                        Icons.table_chart_rounded,
                        color: Colors.green,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Text('Export as Excel'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'word',
                  child: Row(
                    children: [
                      Icon(
                        Icons.description_rounded,
                        color: Colors.blue,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Text('Export as Word'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: _buildBody(isDark),
      ),

      bottomNavigationBar: _pdfBytes != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _printInvoice,
                        icon: const Icon(Icons.print_rounded),
                        label: const Text('Print'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          side: BorderSide(
                            color: isDark
                                ? Colors.white38
                                : const Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _shareInvoice,
                        icon: const Icon(Icons.share_rounded),
                        label: const Text('Share Invoice'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF1E3A8A)),
            const SizedBox(height: 16),
            Text(
              'Generating Invoice...',
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to Generate Invoice',
                style: GoogleFonts.outfit(
                  fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _loadAndGeneratePdf();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // PDF Preview
    return PdfPreview(
      build: (format) async => _pdfBytes!,
      allowPrinting: false,
      allowSharing: false,
      canChangePageFormat: false,
      canChangeOrientation: false,
      canDebug: false,
      pdfPreviewPageDecoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      loadingWidget: const Center(
        child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
      ),
      scrollViewDecoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      ),
    );
  }
}

/// Quick invoice generation from bill detail screen
class InvoiceGeneratorButton extends StatelessWidget {
  final Bill bill;
  final bool mini;

  const InvoiceGeneratorButton({
    super.key,
    required this.bill,
    this.mini = false,
  });

  @override
  Widget build(BuildContext context) {
    if (mini) {
      return IconButton(
        icon: const Icon(Icons.picture_as_pdf_rounded),
        tooltip: 'Generate Invoice PDF',
        onPressed: () => _openPreview(context),
      );
    }

    return ElevatedButton.icon(
      onPressed: () => _openPreview(context),
      icon: const Icon(Icons.picture_as_pdf_rounded),
      label: const Text('Generate Invoice'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  void _openPreview(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => InvoicePreviewScreen(bill: bill)),
    );
  }
}
