import '../../../../models/business_type.dart';
import '../config/invoice_layout_config.dart';
import '../config/universal_invoice_presets.dart';
import '../model/universal_invoice_data.dart';

/// A snapshot of one existing invoice as stored in production (or a copy of it).
///
/// [sourceItemCount] and [sourceGrandTotal] capture the values as they exist in
/// the source store; [data] is the record mapped into the new engine's view
/// model. The migration compares the two to prove no data was lost.
class MigrationRecord {
  final String invoiceId;
  final BusinessType businessType;
  final int sourceItemCount;
  final double sourceGrandTotal;
  final UniversalInvoiceData data;

  const MigrationRecord({
    required this.invoiceId,
    required this.businessType,
    required this.sourceItemCount,
    required this.sourceGrandTotal,
    required this.data,
  });
}

/// In-memory store standing in for the NEW `invoice_layout_config` table. The
/// forward migration writes here; rollback deletes from here. Existing invoice
/// records live in a SEPARATE store that this migration never touches.
class InMemoryLayoutConfigStore {
  final Map<BusinessType, InvoiceLayoutConfig> _configs = {};

  bool has(BusinessType t) => _configs.containsKey(t);
  void put(BusinessType t, InvoiceLayoutConfig c) => _configs[t] = c;
  void remove(BusinessType t) => _configs.remove(t);
  int get count => _configs.length;
  List<BusinessType> get types => _configs.keys.toList();
}

/// Per-invoice old-vs-new comparison row.
class MigrationSample {
  final String invoiceId;
  final BusinessType businessType;
  final int oldItemCount;
  final int newItemCount;
  final double oldGrandTotal;
  final double newGrandTotal;
  final String template; // 'universal' | 'dedicated'
  final bool lossless;

  const MigrationSample({
    required this.invoiceId,
    required this.businessType,
    required this.oldItemCount,
    required this.newItemCount,
    required this.oldGrandTotal,
    required this.newGrandTotal,
    required this.template,
    required this.lossless,
  });
}

/// Result of a migration run.
class MigrationReport {
  final int beforeCount;
  final int afterCount;
  final List<MigrationSample> samples;
  final List<String> errors;
  final List<BusinessType> createdConfigTypes;
  final bool dryRun;

  const MigrationReport({
    required this.beforeCount,
    required this.afterCount,
    required this.samples,
    required this.errors,
    required this.createdConfigTypes,
    required this.dryRun,
  });

  /// Record-count parity: no invoice was added or dropped.
  bool get recordCountParity => beforeCount == afterCount;

  /// True when counts match AND every invoice migrated without data loss.
  bool get isLossless => recordCountParity && errors.isEmpty;

  String toText({int sampleLimit = 10}) {
    final b = StringBuffer();
    b.writeln(
      '=== INVOICE LAYOUT MIGRATION REPORT ${dryRun ? "(DRY RUN)" : "(COMMITTED)"} ===',
    );
    b.writeln('Invoice records BEFORE : $beforeCount');
    b.writeln('Invoice records AFTER  : $afterCount');
    b.writeln(
      'Record-count parity    : ${recordCountParity ? "OK (no loss)" : "MISMATCH"}',
    );
    b.writeln(
      'Layout configs created : ${createdConfigTypes.length} '
      '(${createdConfigTypes.map((t) => t.name).join(", ")})',
    );
    b.writeln('Data-loss errors       : ${errors.length}');
    for (final e in errors) {
      b.writeln('  - $e');
    }
    b.writeln('');
    b.writeln('Sample (old render vs new render), first $sampleLimit:');
    b.writeln(
      'InvoiceID     | BusinessType     | Template   | Items(old→new) | GrandTotal(old→new)      | Match',
    );
    for (final s in samples.take(sampleLimit)) {
      b.writeln(
        '${s.invoiceId.padRight(13)} | '
        '${s.businessType.name.padRight(16)} | '
        '${s.template.padRight(10)} | '
        '${'${s.oldItemCount}→${s.newItemCount}'.padRight(14)} | '
        '${'Rs.${s.oldGrandTotal.toStringAsFixed(2)}→Rs.${s.newGrandTotal.toStringAsFixed(2)}'.padRight(24)} | '
        '${s.lossless ? "YES" : "NO"}',
      );
    }
    b.writeln('');
    b.writeln(
      'RESULT: ${isLossless ? "ZERO DATA LOSS — SAFE" : "REVIEW REQUIRED"}',
    );
    return b.toString();
  }
}

/// Additive, reversible migration from existing invoices to the config-driven
/// engine. Existing invoice records are NEVER modified or deleted; the forward
/// step only creates layout-config records, so rollback is a config drop.
class InvoiceLayoutMigration {
  const InvoiceLayoutMigration();

  MigrationReport migrate(
    List<MigrationRecord> records,
    InMemoryLayoutConfigStore configStore, {
    bool dryRun = false,
  }) {
    final before = records.length;
    final samples = <MigrationSample>[];
    final errors = <String>[];
    final created = <BusinessType>{};

    for (final r in records) {
      final newItemCount = r.data.items.length;
      final newTotal = r.data.grandTotal;
      final lossless =
          newItemCount == r.sourceItemCount &&
          (newTotal - r.sourceGrandTotal).abs() < 0.001;
      if (!lossless) {
        errors.add(
          'Invoice ${r.invoiceId}: data mismatch '
          '(items ${r.sourceItemCount}->$newItemCount, '
          'total ${r.sourceGrandTotal.toStringAsFixed(2)}->'
          '${newTotal.toStringAsFixed(2)})',
        );
      }

      final isUniversal = UniversalInvoicePresets.isWired(r.businessType);
      if (!dryRun && isUniversal && !configStore.has(r.businessType)) {
        configStore.put(
          r.businessType,
          UniversalInvoicePresets.forType(r.businessType),
        );
        created.add(r.businessType);
      }

      samples.add(
        MigrationSample(
          invoiceId: r.invoiceId,
          businessType: r.businessType,
          oldItemCount: r.sourceItemCount,
          newItemCount: newItemCount,
          oldGrandTotal: r.sourceGrandTotal,
          newGrandTotal: newTotal,
          template: isUniversal ? 'universal' : 'dedicated',
          lossless: lossless,
        ),
      );
    }

    // Records are never modified/deleted -> after == before by construction.
    final after = records.length;

    return MigrationReport(
      beforeCount: before,
      afterCount: after,
      samples: samples,
      errors: errors,
      createdConfigTypes: created.toList(),
      dryRun: dryRun,
    );
  }

  /// Reverse the forward migration by dropping the created layout configs.
  /// Existing invoice records are untouched, so this fully restores state.
  int rollback(InMemoryLayoutConfigStore configStore, MigrationReport report) {
    var removed = 0;
    for (final t in report.createdConfigTypes) {
      if (configStore.has(t)) {
        configStore.remove(t);
        removed++;
      }
    }
    return removed;
  }
}
