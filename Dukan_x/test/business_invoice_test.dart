import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:dukanx/models/bill.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/core/pdf/enhanced_invoice_pdf_service.dart';
import 'package:dukanx/core/pdf/invoice_models.dart';
import 'package:dukanx/services/invoice_pdf_service.dart' show InvoiceLanguage;
import 'package:dukanx/core/services/currency_service.dart';

void main() {
  setUpAll(() {
    final sl = GetIt.instance;
    if (!sl.isRegistered<CurrencyService>()) {
      sl.registerLazySingleton<CurrencyService>(() => CurrencyService());
    }
  });

  tearDownAll(() {
    GetIt.instance.reset();
  });

  final service = EnhancedInvoicePdfService();
  final now = DateTime.now();

  Bill createMockBill(BusinessType type) {
    return Bill(
      id: 'test-bill-${type.name}',
      ownerId: 'owner-1',
      invoiceNumber: 'INV-${type.name.toUpperCase()}-001',
      customerId: 'cust-1',
      customerName: 'Test Customer',
      customerPhone: '9876543210',
      date: now,
      items: [
        BillItem(
          productId: 'p1',
          productName: 'Item 1',
          qty: 2,
          price: 100,
          unit: 'pcs',
          gstRate: 18,
          cgst: 18,
          sgst: 18,
          // Business specific
          batchNo: type == BusinessType.pharmacy ? 'BATCH123' : null,
          expiryDate: type == BusinessType.pharmacy
              ? now.add(const Duration(days: 365))
              : null,
          serialNo: type == BusinessType.electronics ? 'SN99999' : null,
          warrantyMonths: type == BusinessType.electronics ? 12 : null,
          size: type == BusinessType.clothing ? 'XL' : null,
          color: type == BusinessType.clothing ? 'Red' : null,
        ),
      ],
      subtotal: 200,
      discountApplied: 0,
      grandTotal: 236,
      paidAmount: 236,
      cashPaid: 236,
      onlinePaid: 0,
      status: 'Paid',
      paymentType: 'Cash',
      prescriptionId: null,
    );
  }

  test('Generate Pharmacy Invoice', () async {
    final bill = createMockBill(BusinessType.pharmacy);
    final config = EnhancedInvoiceConfig(
      shopName: 'My Pharmacy',
      ownerName: 'Dr. Owner',
      address: '123 Pharma St',
      mobile: '9999999999',
      businessType: BusinessType.pharmacy,
      language: InvoiceLanguage.english,
      showTax: true,
    );

    final bytes = await service.generateFromBill(bill: bill, config: config);
    expect(bytes.length, greaterThan(100));
    // Optional: write to file for inspection
    // File('test_pharmacy.pdf').writeAsBytesSync(bytes);
  });

  test('Generate Electronics Invoice', () async {
    final bill = createMockBill(BusinessType.electronics);
    final config = EnhancedInvoiceConfig(
      shopName: 'My Electronics',
      ownerName: 'Tech Guy',
      address: '456 Tech Park',
      mobile: '8888888888',
      businessType: BusinessType.electronics,
      language: InvoiceLanguage.marathi,
      showTax: true,
    );

    final bytes = await service.generateFromBill(bill: bill, config: config);
    expect(bytes.length, greaterThan(100));
  });

  test('Generate Clothing Invoice', () async {
    final bill = createMockBill(BusinessType.clothing);
    final config = EnhancedInvoiceConfig(
      shopName: 'Fashion Hub',
      ownerName: 'Designer',
      address: '789 Ramp Walk',
      mobile: '7777777777',
      businessType: BusinessType.clothing,
      language: InvoiceLanguage.hindi,
      showTax: false,
    );

    final bytes = await service.generateFromBill(bill: bill, config: config);
    expect(bytes.length, greaterThan(100));
  });
}
