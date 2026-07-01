import 'dart:typed_data';
import '../../../../../../services/invoice_pdf_service.dart';
import '../../models/export_data.dart';
import 'export_adapter.dart';

class PdfExportAdapter implements ExportAdapter {
  final InvoicePdfService _pdfService = InvoicePdfService();

  @override
  String get fileExtension => 'pdf';

  @override
  String get contentType => 'application/pdf';

  @override
  Future<List<int>> generate(ExportData data) async {
    // Map ExportData -> InvoiceConfig
    // Note: We use metadata for binary assets if available
    final logoBytes = data.metadata['logoBytes'] as Uint8List?;
    final signatureBytes = data.metadata['signatureBytes'] as Uint8List?;

    final config = InvoiceConfig(
      shopName: data.company.name,
      ownerName: '', // ExportData might mock this or we add it.
      // For now, assume company name covers it or leaving blank is fine.
      address: data.company.address,
      mobile: data.company.phone ?? '',
      email: data.company.email,
      gstin: data.company.gstin,
      logoImage: logoBytes,
      signatureImage: signatureBytes,
      showTax: data.taxSummary.isNotEmpty,
      isGstBill: data.taxSummary.isNotEmpty, // Infer from tax presence
    );

    final customer = InvoiceCustomer(
      name: data.party.name,
      mobile: data.party.phone ?? '',
      address: data.party.address,
      gstin: data.party.gstin,
    );

    final items = data.items
        .map(
          (item) => InvoiceItem(
            name: item.name,
            description: item.description,
            quantity: item.quantity,
            unit: item.unit,
            unitPrice: item.unitPrice,
            taxPercent: item.taxRate, // Assuming taxRate is %
          ),
        )
        .toList();

    final bytes = await _pdfService.generateInvoicePdf(
      config: config,
      customer: customer,
      items: items,
      invoiceNumber: data.document.number,
      invoiceDate: data.document.date,
      dueDate: data.document.dueDate,
      discount: data.totals.totalDiscount,
      notes: data.notes ?? data.metadata['notes'],
      termsAndConditions:
          data.termsAndConditions ?? data.metadata['termsAndConditions'],
    );
    return bytes.toList();
  }
}
