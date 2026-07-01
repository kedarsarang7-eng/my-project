import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:docx_template/docx_template.dart';
import '../../models/export_data.dart';
import 'export_adapter.dart';

class WordExportAdapter implements ExportAdapter {
  @override
  String get fileExtension => 'docx';

  @override
  String get contentType =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

  @override
  Future<List<int>> generate(ExportData data) async {
    // Load Template
    // We assume the template exists. In a production app, we would verify or download it.
    final templatePath = 'assets/templates/invoice_template.docx';
    ByteData? templateBytes;
    try {
      templateBytes = await rootBundle.load(templatePath);
    } catch (e) {
      // Fallback or explicit error
      throw Exception(
        'Word Template not found at $templatePath. Please ensure the asset exists.',
      );
    }

    final docx = await DocxTemplate.fromBytes(
      templateBytes.buffer.asUint8List(),
    );

    final content = Content();

    // --- COMPANY ---
    content.add(TextContent('company_name', data.company.name));
    content.add(TextContent('company_address', data.company.address));
    content.add(TextContent('company_phone', data.company.phone ?? ''));
    content.add(TextContent('company_email', data.company.email ?? ''));
    content.add(TextContent('company_gstin', data.company.gstin ?? ''));

    // --- DOCUMENT ---
    content.add(TextContent('invoice_no', data.document.number));
    content.add(
      TextContent('date', data.document.date.toString().substring(0, 10)),
    );
    content.add(
      TextContent(
        'due_date',
        data.document.dueDate?.toString().substring(0, 10) ?? '',
      ),
    );

    // --- PARTY ---
    content.add(TextContent('customer_name', data.party.name));
    content.add(TextContent('customer_phone', data.party.phone ?? ''));
    content.add(TextContent('customer_address', data.party.address ?? ''));
    content.add(TextContent('customer_gstin', data.party.gstin ?? ''));

    // --- TERMS & NOTES ---
    content.add(TextContent('notes', data.notes ?? ''));
    content.add(TextContent('terms', data.termsAndConditions ?? ''));

    // --- ITEMS (Loop) ---
    final itemsList = <Content>[];
    for (final item in data.items) {
      final itemContent = Content();
      itemContent.add(TextContent('index', item.index));
      itemContent.add(TextContent('item_name', item.name));
      itemContent.add(TextContent('qty', item.quantity));
      itemContent.add(TextContent('unit', item.unit));
      itemContent.add(TextContent('price', item.unitPrice));
      itemContent.add(TextContent('tax', item.taxAmount));
      itemContent.add(TextContent('total', item.totalAmount));
      itemsList.add(itemContent);
    }
    content.add(ListContent('items', itemsList));

    // --- TOTALS ---
    content.add(TextContent('subtotal', data.totals.subtotal));
    content.add(TextContent('total_tax', data.totals.totalTax));
    content.add(TextContent('discount', data.totals.totalDiscount));
    content.add(TextContent('grand_total', data.totals.grandTotal));

    final generated = await docx.generate(content);
    if (generated != null) {
      return generated;
    } else {
      throw Exception('Failed to generate Word document content.');
    }
  }
}
