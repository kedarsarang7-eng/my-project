import 'package:dukanx/features/invoice/universal/migration/invoice_layout_migration.dart';
import 'package:dukanx/features/invoice/universal/model/universal_invoice_data.dart';
import 'package:dukanx/features/invoice/universal/model/universal_invoice_item.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:flutter_test/flutter_test.dart';

/// The 12 in-scope invoice business types (9 universal + 3 dedicated).
const _inScope = [
  BusinessType.grocery,
  BusinessType.mobileShop,
  BusinessType.wholesale,
  BusinessType.computerShop,
  BusinessType.electronics,
  BusinessType.bookStore,
  BusinessType.clothing,
  BusinessType.autoParts,
  BusinessType.hardware,
  BusinessType.pharmacy,
  BusinessType.restaurant,
  BusinessType.jewellery,
];

/// Build a deterministic simulated PRODUCTION COPY of invoices.
List<MigrationRecord> _simulatedProductionCopy() {
  final records = <MigrationRecord>[];
  var n = 0;
  for (final type in _inScope) {
    // Two invoices per type => 24 records.
    for (var k = 0; k < 2; k++) {
      n++;
      final itemCount = 1 + ((n + k) % 3); // 1..3 items
      final items = List<UniversalInvoiceItem>.generate(
        itemCount,
        (i) => UniversalInvoiceItem(
          name: 'Item ${i + 1}',
          quantity: (i + 1).toDouble(),
          unitPrice: 100.0 + i * 10,
          taxPercent: 18,
          cgst: 9.0 * (i + 1),
          sgst: 9.0 * (i + 1),
        ),
      );
      final subtotal = items.fold<double>(0, (s, it) => s + it.subtotal);
      final tax = items.fold<double>(0, (s, it) => s + it.totalTax);
      final grand = subtotal + tax;
      records.add(
        MigrationRecord(
          invoiceId: 'INV-${n.toString().padLeft(4, '0')}',
          businessType: type,
          sourceItemCount: itemCount,
          sourceGrandTotal: grand,
          data: UniversalInvoiceData(
            shopName: '${type.name} shop',
            ownerName: 'Owner',
            address: 'Addr',
            mobile: '9999999999',
            customerName: 'Customer $n',
            invoiceNumber: 'INV-${n.toString().padLeft(4, '0')}',
            date: DateTime(2026, 1, 1).add(Duration(days: n)),
            items: items,
            subtotal: subtotal,
            totalCgst: items.fold<double>(0, (s, it) => s + it.cgst),
            totalSgst: items.fold<double>(0, (s, it) => s + it.sgst),
            grandTotal: grand,
            paidAmount: grand,
          ),
        ),
      );
    }
  }
  return records;
}

void main() {
  const migration = InvoiceLayoutMigration();

  test('DRY RUN on production copy: parity + lossless, NO configs written', () {
    final records = _simulatedProductionCopy();
    final store = InMemoryLayoutConfigStore();

    final report = migration.migrate(records, store, dryRun: true);

    expect(report.beforeCount, records.length);
    expect(report.afterCount, records.length);
    expect(report.recordCountParity, isTrue);
    expect(report.isLossless, isTrue);
    // Dry run must not write any config.
    expect(store.count, 0);
  });

  test(
    'COMMIT on production copy: zero data loss + configs for universal types',
    () {
      final records = _simulatedProductionCopy();
      final store = InMemoryLayoutConfigStore();

      final report = migration.migrate(records, store);

      // Record-count parity == zero data loss.
      expect(report.beforeCount, report.afterCount);
      expect(report.isLossless, isTrue);
      // 9 universal types get a layout config; 3 dedicated use their templates.
      expect(store.count, 9);

      // Print the migration report (incl. 10-sample old-vs-new table).
      // ignore: avoid_print
      print(report.toText(sampleLimit: 10));
    },
  );

  test('detects data loss (item dropped) and flags it', () {
    final good = _simulatedProductionCopy().first;
    // Corrupt: source says 3 items but mapped data has 0.
    final corrupted = MigrationRecord(
      invoiceId: 'INV-BAD',
      businessType: good.businessType,
      sourceItemCount: 3,
      sourceGrandTotal: 999.0,
      data: UniversalInvoiceData(
        shopName: 'x',
        ownerName: 'x',
        address: 'x',
        mobile: 'x',
        customerName: 'x',
        invoiceNumber: 'INV-BAD',
        date: DateTime(2026, 1, 1),
        items: const [], // lost items
        grandTotal: 0,
      ),
    );
    final store = InMemoryLayoutConfigStore();
    final report = migration.migrate([corrupted], store);

    expect(report.isLossless, isFalse);
    expect(report.errors, isNotEmpty);
    expect(report.errors.first, contains('INV-BAD'));
  });

  test('ROLLBACK removes created configs; records untouched', () {
    final records = _simulatedProductionCopy();
    final store = InMemoryLayoutConfigStore();

    final report = migration.migrate(records, store);
    expect(store.count, 9);

    final removed = migration.rollback(store, report);
    expect(removed, 9);
    expect(store.count, 0);
    // Records were never touched, so re-running still sees the same count.
    expect(records.length, report.beforeCount);
  });
}
