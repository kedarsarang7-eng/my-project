// ============================================================================
// ACADEMIC COACHING — STUDENT ID CARD GENERATOR
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/ac_models.dart';

class AcIdCardGenerator extends StatefulWidget {
  final AcStudent? student;
  final String? batchName;
  final String? courseName;
  final String instituteName;
  final String? instituteLogo;
  final String? instituteAddress;
  final String? institutePhone;

  const AcIdCardGenerator({
    super.key,
    this.student,
    this.batchName,
    this.courseName,
    required this.instituteName,
    this.instituteLogo,
    this.instituteAddress,
    this.institutePhone,
  });

  @override
  State<AcIdCardGenerator> createState() => _AcIdCardGeneratorState();
}

class _AcIdCardGeneratorState extends State<AcIdCardGenerator> {
  bool _isGenerating = false;
  Uint8List? _pdfBytes;

  Future<void> _generateIdCard() async {
    if (widget.student == null) return;

    setState(() => _isGenerating = true);

    try {
      final pdf = pw.Document();
      final student = widget.student!;

      pdf.addPage(
        pw.Page(
          pageFormat: idCardFormat,
          build: (context) => _buildIdCard(student),
        ),
      );

      final bytes = await pdf.save();
      setState(() {
        _pdfBytes = bytes;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating ID card: $e')),
      );
    }
  }

  pw.Widget _buildIdCard(AcStudent student) {
    return pw.Container(
      width: 85 * PdfPageFormat.mm,
      height: 55 * PdfPageFormat.mm,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromHex('#4F46E5'), width: 2),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#4F46E5'),
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                topRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Center(
              child: pw.Text(
                widget.instituteName,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
          // Body
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(12),
              child: pw.Row(
                children: [
                  // Photo placeholder
                  pw.Container(
                    width: 50,
                    height: 60,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'Photo',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey,
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  // Info
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                          student.fullName,
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'ID: ${student.studentId}',
                          style: pw.TextStyle(fontSize: 10),
                        ),
                        pw.SizedBox(height: 4),
                        if (widget.courseName != null)
                          pw.Text(
                            'Course: ${widget.courseName}',
                            style: pw.TextStyle(fontSize: 9),
                          ),
                        if (widget.batchName != null)
                          pw.Text(
                            'Batch: ${widget.batchName}',
                            style: pw.TextStyle(fontSize: 9),
                          ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Valid Until: ${_getValidUntil()}',
                          style: pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Footer
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey200)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                if (widget.institutePhone != null)
                  pw.Text(
                    'Ph: ${widget.institutePhone}',
                    style: pw.TextStyle(fontSize: 8),
                  ),
                pw.Text(
                  'Student ID Card',
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getValidUntil() {
    final nextYear = DateTime.now().year + 1;
    return '31-03-$nextYear';
  }

  Future<void> _printIdCard() async {
    if (_pdfBytes == null) return;

    await Printing.layoutPdf(
      onLayout: (format) => _pdfBytes!,
      name: 'ID_Card_${widget.student?.studentId ?? 'unknown'}.pdf',
    );
  }

  Future<void> _shareIdCard() async {
    if (_pdfBytes == null) return;

    await Printing.sharePdf(
      bytes: _pdfBytes!,
      filename: 'ID_Card_${widget.student?.studentId ?? 'unknown'}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.student == null) {
      return const Center(
        child: Text('No student selected for ID card generation'),
      );
    }

    return Column(
      children: [
        // Preview
        Container(
          width: 340,
          height: 220,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _pdfBytes != null
              ? PdfPreview(
                  build: (format) => _pdfBytes!,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  canDebug: false,
                )
              : _buildPreviewPlaceholder(),
        ),
        const SizedBox(height: 24),
        // Actions
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _isGenerating ? null : _generateIdCard,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.badge),
              label: Text(_isGenerating ? 'Generating...' : 'Generate ID Card'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
            const SizedBox(width: 12),
            if (_pdfBytes != null) ...[
              ElevatedButton.icon(
                onPressed: _printIdCard,
                icon: const Icon(Icons.print),
                label: const Text('Print'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _shareIdCard,
                icon: const Icon(Icons.share),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewPlaceholder() {
    final student = widget.student!;
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF4F46E5),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Center(
              child: Text(
                widget.instituteName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          // Body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Photo placeholder
                  Container(
                    width: 80,
                    height: 100,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Center(
                      child: Icon(Icons.person, size: 40, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          student.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${student.studentId}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (widget.courseName != null)
                          Text(
                            'Course: ${widget.courseName}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        if (widget.batchName != null)
                          Text(
                            'Batch: ${widget.batchName}',
                            style: const TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const idCardFormat = PdfPageFormat(85 * PdfPageFormat.mm, 55 * PdfPageFormat.mm);
