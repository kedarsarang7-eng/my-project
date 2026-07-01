// Export Screen
//
// Save, share, and print scanned documents.
// Futuristic minimal UI with format options.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../theme/p2d_theme.dart';
import '../widgets/widgets.dart';
import '../../../ml/ml_models/ocr_result.dart';
import 'package:dukanx/core/responsive/responsive.dart';

enum ExportFormat { pdf, image }

class P2DExportScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final OcrResult? ocrResult;

  const P2DExportScreen({super.key, required this.imageBytes, this.ocrResult});

  @override
  State<P2DExportScreen> createState() => _P2DExportScreenState();
}

class _P2DExportScreenState extends State<P2DExportScreen> {
  final _fileNameController = TextEditingController();
  ExportFormat _selectedFormat = ExportFormat.pdf;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Generate default filename
    final now = DateTime.now();
    final defaultName = widget.ocrResult?.shopName.isNotEmpty == true
        ? '${widget.ocrResult!.shopName.replaceAll(' ', '_')}_${now.day}${now.month}'
        : 'Scan_${now.day}${now.month}${now.year}_${now.hour}${now.minute}';
    _fileNameController.text = defaultName;
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final fileName = _fileNameController.text.trim().isEmpty
          ? 'Scan_${DateTime.now().millisecondsSinceEpoch}'
          : _fileNameController.text.trim();

      final dir = await getApplicationDocumentsDirectory();
      final scansDir = Directory('${dir.path}/P2D_Scans');
      if (!await scansDir.exists()) {
        await scansDir.create(recursive: true);
      }

      if (_selectedFormat == ExportFormat.pdf) {
        final pdfPath = '${scansDir.path}/$fileName.pdf';
        await _savePdf(pdfPath);
        _showSuccess('PDF saved to P2D_Scans');
      } else {
        final imagePath = '${scansDir.path}/$fileName.jpg';
        await File(imagePath).writeAsBytes(widget.imageBytes);
        _showSuccess('Image saved to P2D_Scans');
      }
    } catch (e) {
      debugPrint('Save error: $e');
      _showError('Failed to save file');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _savePdf(String path) async {
    final pdf = pw.Document();
    final image = pw.MemoryImage(widget.imageBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) =>
            pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ),
    );

    final file = File(path);
    await file.writeAsBytes(await pdf.save());
  }

  Future<void> _share() async {
    HapticFeedback.lightImpact();

    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = _fileNameController.text.trim().isEmpty
          ? 'Scan'
          : _fileNameController.text.trim();

      String filePath;
      if (_selectedFormat == ExportFormat.pdf) {
        filePath = '${tempDir.path}/$fileName.pdf';
        await _savePdf(filePath);
      } else {
        filePath = '${tempDir.path}/$fileName.jpg';
        await File(filePath).writeAsBytes(widget.imageBytes);
      }

      await Share.shareXFiles([XFile(filePath)]);
    } catch (e) {
      debugPrint('Share error: $e');
      _showError('Failed to share');
    }
  }

  Future<void> _print() async {
    HapticFeedback.lightImpact();

    try {
      final pdf = pw.Document();
      final image = pw.MemoryImage(widget.imageBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (context) =>
              pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
        ),
      );

      await Printing.layoutPdf(onLayout: (format) => pdf.save());
    } catch (e) {
      debugPrint('Print error: $e');
      _showError('Failed to print');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: kP2DGlowSuccess),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _done() {
    // Pop all the way back to the dashboard
    Navigator.of(context).popUntil((route) => route.isFirst);
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
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    top: 80,
                    left: 24,
                    right: 24,
                    bottom: MediaQuery.of(context).padding.bottom + 100,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Preview thumbnail
                      Center(
                        child: Container(
                          width: 200,
                          height: 280,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kP2DGlassBorder),
                            boxShadow: [kP2DNeonGlow(kP2DAccentCyan, blur: 20)],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.memory(
                              widget.imageBytes,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // File name input
                      const Text(
                        'File Name',
                        style: TextStyle(
                          color: kP2DTextSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kP2DGlassBorder),
                          color: kP2DGlassSurface,
                        ),
                        child: TextField(
                          controller: _fileNameController,
                          style: const TextStyle(color: kP2DTextPrimary),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(16),
                            hintText: 'Enter file name',
                            hintStyle: TextStyle(color: kP2DTextMuted),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Format selection
                      const Text(
                        'Format',
                        style: TextStyle(
                          color: kP2DTextSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildFormatOption(ExportFormat.pdf, 'PDF'),
                          const SizedBox(width: 16),
                          _buildFormatOption(ExportFormat.image, 'Image'),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionButton(
                            icon: Icons.share_rounded,
                            label: 'Share',
                            onTap: _share,
                          ),
                          _buildActionButton(
                            icon: Icons.print_rounded,
                            label: 'Print',
                            onTap: _print,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
                      const Text(
                        'Save & Export',
                        style: TextStyle(
                          color: kP2DTextPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 40), // Spacer
                    ],
                  ),
                ),
              ),

              // Bottom save button
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                    left: 24,
                    right: 24,
                    top: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [kP2DBackground, kP2DBackground.withOpacity(0)],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _isSaving ? null : _save,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: kP2DAccentGradient,
                              boxShadow: [kP2DNeonGlow(kP2DAccentCyan, blur: 15)],
                            ),
                            child: Center(
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Save',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      NeonButton(
                        icon: Icons.check_rounded,
                        onTap: _done,
                        isActive: true,
                        color: kP2DGlowSuccess,
                        size: 52,
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

  Widget _buildFormatOption(ExportFormat format, String label) {
    final isSelected = _selectedFormat == format;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedFormat = format);
          HapticFeedback.selectionClick();
        },
        child: AnimatedContainer(
          duration: kP2DAnimationFast,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? kP2DAccentCyan.withOpacity(0.2)
                : kP2DGlassSurface,
            border: Border.all(
              color: isSelected ? kP2DAccentCyan : kP2DGlassBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  format == ExportFormat.pdf
                      ? Icons.picture_as_pdf_rounded
                      : Icons.image_rounded,
                  color: isSelected ? kP2DAccentCyan : kP2DTextSecondary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? kP2DAccentCyan : kP2DTextSecondary,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kP2DGlassSurface,
              border: Border.all(color: kP2DGlassBorder),
            ),
            child: Icon(icon, color: kP2DTextSecondary, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: kP2DTextMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
