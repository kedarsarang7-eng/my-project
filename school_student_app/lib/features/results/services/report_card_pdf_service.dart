import 'dart:developer' as developer;
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Generates and either prints or saves a PDF report card for a student.
class ReportCardPdfService {
  static Future<void> generate({
    required Map<String, dynamic> student,
    required Map<String, dynamic> results,
    required String examName,
    bool print = false,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    final subjects =
        (results['subjects'] as List? ?? []).cast<Map<String, dynamic>>();
    final totalMarks =
        subjects.fold<num>(0, (s, e) => s + ((e['marks'] ?? 0) as num));
    final maxMarks =
        subjects.fold<num>(0, (s, e) => s + ((e['maxMarks'] ?? 100) as num));
    final percentage = maxMarks > 0 ? (totalMarks / maxMarks * 100) : 0.0;
    final grade = _grade(percentage.toDouble());
    final fmt = DateFormat('d MMM yyyy');

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) =>
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        // Header
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
              color: PdfColors.indigo700,
              borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('REPORT CARD',
                          style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 20,
                              color: PdfColors.white)),
                      pw.SizedBox(height: 4),
                      pw.Text(examName,
                          style: pw.TextStyle(
                              font: font,
                              fontSize: 13,
                              color: PdfColor.fromInt(0xB3FFFFFF))),
                    ]),
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(fmt.format(DateTime.now()),
                          style: pw.TextStyle(
                              font: font,
                              fontSize: 11,
                              color: PdfColor.fromInt(0xB3FFFFFF))),
                    ]),
              ]),
        ),
        pw.SizedBox(height: 20),

        // Student info
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Row(children: [
            pw.Expanded(
                child: _infoRow(
                    'Name',
                    '${student['firstName'] ?? ''} ${student['lastName'] ?? ''}',
                    font,
                    fontBold)),
            pw.SizedBox(width: 20),
            pw.Expanded(
                child: _infoRow('Roll No.',
                    student['rollNumber']?.toString() ?? '-', font, fontBold)),
            pw.SizedBox(width: 20),
            pw.Expanded(
                child: _infoRow('Class / Batch',
                    student['batchName']?.toString() ?? '-', font, fontBold)),
          ]),
        ),
        pw.SizedBox(height: 20),

        // Marks table
        pw.Text('Subject-wise Performance',
            style: pw.TextStyle(
                font: fontBold, fontSize: 14, color: PdfColors.indigo900)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(1.5),
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.indigo50),
              children: ['Subject', 'Max Marks', 'Marks', '%', 'Grade']
                  .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        child: pw.Text(h,
                            style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 11,
                                color: PdfColors.indigo900)),
                      ))
                  .toList(),
            ),
            // Data rows
            ...subjects.map((s) {
              final m = (s['marks'] ?? 0) as num;
              final mx = (s['maxMarks'] ?? 100) as num;
              final pct = mx > 0 ? (m / mx * 100) : 0.0;
              final g = _grade(pct.toDouble());
              return pw.TableRow(
                  children: [
                s['subject']?.toString() ?? '-',
                mx.toString(),
                m.toString(),
                '${pct.toStringAsFixed(1)}%',
                g,
              ]
                      .map((v) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 8, vertical: 5),
                            child: pw.Text(v,
                                style: pw.TextStyle(font: font, fontSize: 11)),
                          ))
                      .toList());
            }),
          ],
        ),
        pw.SizedBox(height: 16),

        // Summary
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: _gradeBgColor(grade),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _summaryItem(
                    'Total Marks', '$totalMarks / $maxMarks', font, fontBold),
                _summaryItem('Percentage', '${percentage.toStringAsFixed(2)}%',
                    font, fontBold),
                _summaryItem('Overall Grade', grade, font, fontBold),
                _summaryItem('Result', percentage >= 33 ? 'PASS' : 'FAIL', font,
                    fontBold),
              ]),
        ),

        pw.Spacer(),
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 8),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Generated on ${fmt.format(DateTime.now())}',
              style: pw.TextStyle(
                  font: font, fontSize: 9, color: PdfColors.grey600)),
          pw.Text('EduConnect School ERP',
              style: pw.TextStyle(
                  font: fontBold, fontSize: 9, color: PdfColors.indigo400)),
        ]),
      ]),
    ));

    // Wrap the I/O entry points so PDF render / share / print failures
    // surface a localized error and do not freeze the UI (clause 2.12).
    try {
      if (print) {
        await Printing.layoutPdf(onLayout: (_) async => pdf.save());
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final name =
            'report_card_${student['rollNumber'] ?? 'student'}_${examName.replaceAll(' ', '_')}.pdf';
        final file = File('${dir.path}/$name');
        await file.writeAsBytes(await pdf.save());
        await Printing.sharePdf(bytes: await pdf.save(), filename: name);
      }
    } catch (e, st) {
      developer.log(
        'I/O failure in report_card_pdf.${print ? 'print' : 'share'}: $e',
        name: 'ReportCardPdfService',
        error: e,
        stackTrace: st,
      );
      // Rethrow as a typed exception with a user-safe message; UI layer
      // surfaces it via the existing snackbar/toast helper.
      throw Exception(
        'Could not produce the report card PDF. Please try again.',
      );
    }
  }

  static pw.Widget _infoRow(
          String label, String value, pw.Font font, pw.Font bold) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  font: font, fontSize: 9, color: PdfColors.grey600)),
          pw.SizedBox(height: 2),
          pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 12)),
        ],
      );

  static pw.Widget _summaryItem(
          String label, String value, pw.Font font, pw.Font bold) =>
      pw.Column(
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  font: font, fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 2),
          pw.Text(value,
              style: pw.TextStyle(
                  font: bold, fontSize: 16, color: PdfColors.indigo900)),
        ],
      );

  static String _grade(double pct) {
    if (pct >= 90) return 'A+';
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B+';
    if (pct >= 60) return 'B';
    if (pct >= 50) return 'C+';
    if (pct >= 40) return 'C';
    if (pct >= 33) return 'D';
    return 'F';
  }

  static PdfColor _gradeBgColor(String grade) => switch (grade) {
        'A+' || 'A' => PdfColors.green50,
        'B+' || 'B' => PdfColors.blue50,
        'C+' || 'C' => PdfColors.yellow50,
        _ => PdfColors.red50,
      };
}
