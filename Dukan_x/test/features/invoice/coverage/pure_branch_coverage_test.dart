import 'package:dukanx/features/invoice/dedicated/models/pharmacy_invoice_item.dart';
import 'package:dukanx/features/invoice/universal/config/invoice_field_config.dart';
import 'package:dukanx/features/invoice/universal/config/invoice_section.dart';
import 'package:dukanx/features/invoice/universal/config/invoice_section_config.dart';
import 'package:dukanx/features/invoice/universal/config/universal_invoice_presets.dart';
import 'package:dukanx/features/invoice/universal/migration/invoice_layout_migration.dart';
import 'package:dukanx/features/invoice/universal/model/universal_invoice_data.dart';
import 'package:dukanx/features/invoice/universal/model/universal_invoice_item.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UniversalInvoiceItem.cell — every key and branch', () {
    final item = UniversalInvoiceItem(
      name: 'Widget',
      description: 'desc',
      quantity: 2,
      unit: 'box',
      unitPrice: 100,
      discount: 10,
      taxPercent: 18.5,
      cgst: 9,
      sgst: 9,
      hsn: '1234',
      serialNo: 'SN1',
      warrantyMonths: 12,
      size: 'L',
      color: 'Red',
      partNumber: 'P1',
      isbn: 'ISBN1',
      batchNo: 'B1',
      expiryDate: DateTime(2027, 6, 1),
    );

    test('all populated keys resolve', () {
      expect(item.cell('name'), 'Widget');
      expect(item.cell('description'), 'desc');
      expect(item.cell('qty'), '2');
      expect(item.cell('unit'), 'box');
      expect(item.cell('rate'), '\u20B9100.00');
      expect(item.cell('price'), '\u20B9100.00');
      expect(item.cell('mrp'), '\u20B9100.00');
      expect(item.cell('hsn'), '1234');
      expect(item.cell('serialNo'), 'SN1');
      expect(item.cell('imei'), 'SN1');
      expect(item.cell('warranty'), '1 Year');
      expect(item.cell('size'), 'L');
      expect(item.cell('color'), 'Red');
      expect(item.cell('partNumber'), 'P1');
      expect(item.cell('isbn'), 'ISBN1');
      expect(item.cell('batchNo'), 'B1');
      expect(item.cell('expiry'), '06/27');
      expect(item.cell('gst'), '18.5%');
      expect(item.cell('discount'), '\u20B910.00');
      expect(item.cell('taxable'), '\u20B9190.00');
      expect(item.cell('amount'), '\u20B9208.00');
      expect(item.cell('total'), '\u20B9208.00');
      expect(item.cell('unknown_key'), '-');
    });

    test('null optionals resolve to dash', () {
      const bare = UniversalInvoiceItem(name: 'x', quantity: 1, unitPrice: 1);
      expect(bare.cell('hsn'), '-');
      expect(bare.cell('serialNo'), '-');
      expect(bare.cell('warranty'), '-');
      expect(bare.cell('size'), '-');
      expect(bare.cell('color'), '-');
      expect(bare.cell('partNumber'), '-');
      expect(bare.cell('isbn'), '-');
      expect(bare.cell('batchNo'), '-');
      expect(bare.cell('expiry'), '-');
      expect(bare.cell('description'), '');
    });

    test('warranty formatting branches', () {
      expect(
        const UniversalInvoiceItem(
          name: 'x',
          quantity: 1,
          unitPrice: 1,
          warrantyMonths: 1,
        ).cell('warranty'),
        '1 Month',
      );
      expect(
        const UniversalInvoiceItem(
          name: 'x',
          quantity: 1,
          unitPrice: 1,
          warrantyMonths: 6,
        ).cell('warranty'),
        '6 Months',
      );
      expect(
        const UniversalInvoiceItem(
          name: 'x',
          quantity: 1,
          unitPrice: 1,
          warrantyMonths: 24,
        ).cell('warranty'),
        '2 Years',
      );
    });

    test('gst integer trims decimals', () {
      const it = UniversalInvoiceItem(
        name: 'x',
        quantity: 1,
        unitPrice: 1,
        taxPercent: 18,
      );
      expect(it.cell('gst'), '18%');
    });
  });

  group('InvoiceFieldConfig.copyWith — all params', () {
    test('overrides every field', () {
      const f = InvoiceFieldConfig(key: 'k', label: 'L');
      final c = f.copyWith(
        label: 'L2',
        enabled: false,
        required: false,
        visible: false,
        editable: false,
      );
      expect(c.label, 'L2');
      expect(c.enabled, isFalse);
      expect(c.visible, isFalse);
      expect(c.editable, isFalse);
    });

    test('omitting params keeps originals (covers ?? fallbacks)', () {
      const f = InvoiceFieldConfig(key: 'k', label: 'Orig', visible: false);
      final c = f.copyWith(
        editable: false,
      ); // label/visible/enabled default to this.*
      expect(c.label, 'Orig');
      expect(c.visible, isFalse);
      expect(c.enabled, isTrue);
      expect(c.editable, isFalse);
    });
  });

  group('InvoiceSectionConfig.copyWith — all params', () {
    test('overrides business/offline/tier/fields', () {
      const s = InvoiceSectionConfig(section: InvoiceSection.qr, order: 0);
      final c = s.copyWith(
        businessTypeSpecific: true,
        offlineCompatible: false,
        editable: false,
        required: false,
        fields: const [InvoiceFieldConfig(key: 'a', label: 'A')],
      );
      expect(c.businessTypeSpecific, isTrue);
      expect(c.offlineCompatible, isFalse);
      expect(c.editable, isFalse);
      expect(c.fields.single.key, 'a');
    });
  });

  group('PharmacyInvoiceValidator + expiry edges', () {
    test('valid item yields no errors', () {
      final ok = PharmacyInvoiceValidator.validate([
        PharmacyInvoiceItem(
          name: 'Med',
          batchNo: 'B',
          expiryDate: DateTime(2030, 1, 1),
          quantity: 1,
          mrp: 10,
        ),
      ], asOf: DateTime(2026, 1, 1));
      expect(ok, isEmpty);
    });

    test('expiresWithin returns false for already-expired item', () {
      final expired = PharmacyInvoiceItem(
        name: 'E',
        batchNo: 'B',
        expiryDate: DateTime(2020, 1, 1),
        quantity: 1,
        mrp: 1,
      );
      expect(
        expired.expiresWithin(DateTime(2026, 1, 1), const Duration(days: 90)),
        isFalse,
      );
    });

    test('validate without asOf uses DateTime.now()', () {
      // Future expiry => valid regardless of real "now".
      final errors = PharmacyInvoiceValidator.validate([
        PharmacyInvoiceItem(
          name: 'Med',
          batchNo: 'B',
          expiryDate: DateTime(2999, 1, 1),
          quantity: 1,
          mrp: 10,
        ),
      ]);
      expect(errors, isEmpty);
    });
  });

  group('Migration store + rollback edges', () {
    UniversalInvoiceData d() => UniversalInvoiceData(
      shopName: 's',
      ownerName: 'o',
      address: 'a',
      mobile: 'm',
      customerName: 'c',
      invoiceNumber: 'i',
      date: DateTime(2026, 1, 1),
      items: const [
        UniversalInvoiceItem(name: 'x', quantity: 1, unitPrice: 10),
      ],
      grandTotal: 10,
    );

    test('store.types reflects created configs; double rollback is a no-op', () {
      const migration = InvoiceLayoutMigration();
      final store = InMemoryLayoutConfigStore();
      final report = migration.migrate([
        MigrationRecord(
          invoiceId: 'INV-1',
          businessType: BusinessType.grocery,
          sourceItemCount: 1,
          sourceGrandTotal: 10,
          data: d(),
        ),
      ], store);

      expect(store.types, contains(BusinessType.grocery));

      final removed1 = migration.rollback(store, report);
      expect(removed1, 1);
      // Second rollback finds nothing to remove (covers the `if (has)` false path).
      final removed2 = migration.rollback(store, report);
      expect(removed2, 0);
    });

    test('report.toText renders for dry run', () {
      const migration = InvoiceLayoutMigration();
      final store = InMemoryLayoutConfigStore();
      final report = migration.migrate(
        [
          MigrationRecord(
            invoiceId: 'INV-1',
            businessType: BusinessType.grocery,
            sourceItemCount: 1,
            sourceGrandTotal: 10,
            data: d(),
          ),
        ],
        store,
        dryRun: true,
      );
      final text = report.toText();
      expect(text, contains('DRY RUN'));
      expect(store.count, 0);
    });

    test('report.toText lists errors when data loss detected', () {
      const migration = InvoiceLayoutMigration();
      final store = InMemoryLayoutConfigStore();
      final report = migration.migrate([
        MigrationRecord(
          invoiceId: 'INV-BAD',
          businessType: BusinessType.grocery,
          sourceItemCount: 5, // source claims 5; mapped has 1 => loss
          sourceGrandTotal: 999,
          data: d(),
        ),
      ], store);
      final text = report.toText();
      expect(report.isLossless, isFalse);
      expect(text, contains('INV-BAD'));
      expect(text, contains('REVIEW REQUIRED'));
    });
  });

  group('Presets: wholesale now built via shared _build', () {
    test('wholesale has shipping + bankDetails + notes + signature', () {
      final cfg = UniversalInvoicePresets.forType(BusinessType.wholesale);
      final sections = cfg.sections.map((s) => s.section).toSet();
      expect(sections.contains(InvoiceSection.shipping), isTrue);
      expect(sections.contains(InvoiceSection.bankDetails), isTrue);
      expect(sections.contains(InvoiceSection.notes), isTrue);
      expect(sections.contains(InvoiceSection.signature), isTrue);
      // No serial/warranty for wholesale.
      expect(sections.contains(InvoiceSection.warranty), isFalse);
    });

    test('non-in-scope type throws (default branch)', () {
      expect(
        () => UniversalInvoicePresets.forType(BusinessType.petrolPump),
        throwsUnimplementedError,
      );
    });
  });
}
