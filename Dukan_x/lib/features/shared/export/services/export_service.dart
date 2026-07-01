import 'package:dukanx/features/billing/domain/entities/bill.dart';
import 'package:dukanx/features/billing/domain/repositories/billing_repository.dart';
import 'package:dukanx/services/invoice_pdf_service.dart';
import 'package:dukanx/services/invoice_profile_integration.dart';
import '../models/export_data.dart';
import 'adapters/export_adapter.dart';
import 'adapters/pdf_export_adapter.dart';
import 'adapters/excel_export_adapter.dart';
import 'adapters/word_export_adapter.dart';

class ExportService {
  final BillingRepository _billingRepo;
  final InvoiceProfileHelper _profileHelper = InvoiceProfileHelper();

  ExportService(this._billingRepo);

  /// Generates an export file (bytes) for a given Bill ID.
  Future<List<int>> generateBillExport({
    required String billId,
    required ExportFormat format,
  }) async {
    // 1. Fetch Bill Data
    final billEither = await _billingRepo.getBillById(billId);
    final bill = billEither.fold(
      (failure) => throw Exception('Failed to fetch bill: ${failure.message}'),
      (r) => r,
    );

    // 2. Fetch Company/Profile Data
    final config = await _profileHelper.getInvoiceConfig(
      showTax: true,
      isGstBill: true, // Defaulting to true for detailed exports
    );

    // 3. Normalize to Universal ExportData
    final exportData = _mapToExportData(bill, config);

    // 4. Generate
    return await generate(exportData, format);
  }

  /// Core Generation Method - Reusable for Reports, Ledgers, etc.
  /// Any module can construct ExportData and call this.
  Future<List<int>> generate(ExportData data, ExportFormat format) async {
    final adapter = _getAdapter(format);
    return await adapter.generate(data);
  }

  ExportAdapter _getAdapter(ExportFormat format) {
    switch (format) {
      case ExportFormat.pdf:
        return PdfExportAdapter();
      case ExportFormat.excel:
        return ExcelExportAdapter();
      case ExportFormat.word:
        return WordExportAdapter();
    }
  }

  ExportData _mapToExportData(Bill bill, InvoiceConfig config) {
    return ExportData(
      company: ExportCompany(
        name: config.shopName,
        address: config.address,
        phone: config.mobile,
        email: config.email,
        gstin: config.gstin,
        // logoPath not effectively used in binary generation unless Adapter handles it from elsewhere (config has bytes)
        // We might need to pass bytes directly or adapter handles config usage if we passed it.
        // But ExportData is strict. We'll handle images separately or add bytes field to ExportCompany.
        // For now, names and text.
      ),
      document: ExportDocument(
        id: bill.id,
        number: bill.id
            .substring(0, 8)
            .toUpperCase(), // Placeholder if no number
        date: bill.date,
        type: 'TAX INVOICE', // Should be dynamic based on bill type
        status: bill.paymentMethod.toLowerCase() == 'credit' ? 'DUE' : 'PAID',
      ),
      party: ExportParty(
        name: bill.customerName ?? 'Walk-in Customer',
        phone: bill.customerPhone,
      ),
      items: bill.items.asMap().entries.map((entry) {
        final idx = entry.key;
        final item = entry.value;
        return ExportItem(
          index: idx + 1,
          name: item.name,
          quantity: item.quantity.toDouble(),
          unit: 'pcs', // Default
          unitPrice: item.rate,
          taxRate: 0.0, // Need to extract from logic
          taxAmount: item.taxAmount,
          discountAmount: item.discount,
          totalAmount: item.amount,
        );
      }).toList(),
      taxSummary: [], // Calculate if data available
      totals: ExportTotals(
        subtotal: bill.subtotal,
        totalTax: bill.tax,
        totalDiscount: bill.discount,
        grandTotal: bill.totalAmount,
      ),
      payment: ExportPayment(
        paidAmount: bill.totalAmount,
        dueAmount: 0,
        mode: bill.paymentMethod,
      ),
      // Pass the raw config bytes for adapters to use if they can
      metadata: {
        'logoBytes': config.logoImage,
        'signatureBytes': config.signatureImage,
      },
    );
  }
}
