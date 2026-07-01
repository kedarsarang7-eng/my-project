/// Unit tests for DeliverableChecker.
///
/// Verifies that the checker:
/// - Correctly identifies missing and empty deliverables
/// - Records defects for any missing or empty deliverable
/// - Marks certification incomplete when deliverables are absent
/// - Passes when all deliverables are present and non-empty
///
/// Requirements: 16.1, 16.2
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'deliverable_checker.dart';
import '../core/defect.dart';
import '../core/domain.dart';

void main() {
  late Directory tempDir;
  late String basePath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('deliverable_check_');
    basePath = tempDir.path;
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Helper: creates all required deliverables with non-empty content.
  Future<void> createAllDeliverables(String base) async {
    // 1. System map
    final inventoryDir = Directory('$base/inventory');
    await inventoryDir.create(recursive: true);
    await File(
      '$base/inventory/system-map.md',
    ).writeAsString('# System Map\n\nContent here.');

    // 2. 19 business-type reports
    final reportsDir = Directory('$base/reports');
    await reportsDir.create(recursive: true);
    for (final type in BusinessType.values) {
      await File('$base/reports/business-type-${type.name}.md').writeAsString(
        '# Certification Report: ${type.name}\n\n## Overall Result: PASS',
      );
    }

    // 3. Defects directory
    final defectsDir = Directory('$base/defects');
    await defectsDir.create(recursive: true);

    // 4. Traceability matrix
    await File(
      '$base/traceability-matrix.md',
    ).writeAsString('# Traceability Matrix\n\nContent here.');

    // 5. Benchmark document
    final benchmarkDir = Directory('$base/benchmark');
    await benchmarkDir.create(recursive: true);
    await File(
      '$base/benchmark/industry-standards.md',
    ).writeAsString('# Industry Standards\n\nContent here.');

    // 6. Production readiness checklist
    await File(
      '$base/production-readiness-checklist.md',
    ).writeAsString('# Production Readiness Checklist\n\nGo decision: go');
  }

  group('DeliverableChecker', () {
    test(
      'certificationComplete is true when all deliverables exist and are non-empty',
      () async {
        await createAllDeliverables(basePath);

        final checker = DeliverableChecker();
        final result = await checker.check(basePath);

        expect(result.certificationComplete, isTrue);
        expect(result.defects, isEmpty);
        // 1 system-map + 19 reports + 1 defects dir + 1 traceability + 1 benchmark + 1 checklist = 24
        expect(result.checks.length, equals(24));
        expect(result.checks.every((c) => c.exists && c.nonEmpty), isTrue);
        expect(result.checks.every((c) => c.defectId == null), isTrue);
      },
    );

    test(
      'certificationComplete is false when basePath is empty (all missing)',
      () async {
        final checker = DeliverableChecker();
        final result = await checker.check(basePath);

        expect(result.certificationComplete, isFalse);
        expect(result.defects, isNotEmpty);
        // Every deliverable should be missing
        expect(result.checks.every((c) => !c.exists), isTrue);
        expect(result.checks.every((c) => c.defectId != null), isTrue);
        // 24 checks total, all missing → 24 defects
        expect(result.defects.length, equals(24));
      },
    );

    test('records a defect for a missing system-map.md', () async {
      await createAllDeliverables(basePath);
      // Remove the system map
      await File('$basePath/inventory/system-map.md').delete();

      final checker = DeliverableChecker();
      final result = await checker.check(basePath);

      expect(result.certificationComplete, isFalse);
      expect(result.defects.length, equals(1));

      final defect = result.defects.first;
      expect(defect.id, startsWith('DEF-DLVR-'));
      expect(defect.severity, equals(Severity.high));
      expect(defect.status, equals(ResolutionStatus.open));
      expect(defect.category, equals(GapCategory.missingRequirement));
      expect(defect.reproSteps.length, greaterThanOrEqualTo(1));

      // The check for system-map.md should show it as missing
      final systemMapCheck = result.checks.firstWhere(
        (c) => c.path == 'inventory/system-map.md',
      );
      expect(systemMapCheck.exists, isFalse);
      expect(systemMapCheck.nonEmpty, isFalse);
      expect(systemMapCheck.defectId, isNotNull);
    });

    test('records a defect for an empty deliverable file', () async {
      await createAllDeliverables(basePath);
      // Make the traceability matrix empty
      await File('$basePath/traceability-matrix.md').writeAsString('');

      final checker = DeliverableChecker();
      final result = await checker.check(basePath);

      expect(result.certificationComplete, isFalse);
      expect(result.defects.length, equals(1));

      final matrixCheck = result.checks.firstWhere(
        (c) => c.path == 'traceability-matrix.md',
      );
      expect(matrixCheck.exists, isTrue);
      expect(matrixCheck.nonEmpty, isFalse);
      expect(matrixCheck.defectId, isNotNull);
    });

    test('records a defect for each missing business-type report', () async {
      await createAllDeliverables(basePath);
      // Remove 3 reports
      await File('$basePath/reports/business-type-grocery.md').delete();
      await File('$basePath/reports/business-type-pharmacy.md').delete();
      await File('$basePath/reports/business-type-restaurant.md').delete();

      final checker = DeliverableChecker();
      final result = await checker.check(basePath);

      expect(result.certificationComplete, isFalse);
      expect(result.defects.length, equals(3));

      // Each removed report should have a missing check
      final groceryCheck = result.checks.firstWhere(
        (c) => c.path == 'reports/business-type-grocery.md',
      );
      expect(groceryCheck.exists, isFalse);
      expect(groceryCheck.defectId, isNotNull);
    });

    test(
      'verifies all 19 business-type reports by iterating BusinessType enum',
      () async {
        await createAllDeliverables(basePath);

        final checker = DeliverableChecker();
        final result = await checker.check(basePath);

        // Verify all 19 business type reports are checked
        for (final type in BusinessType.values) {
          final reportCheck = result.checks.firstWhere(
            (c) => c.path == 'reports/business-type-${type.name}.md',
            orElse: () => throw StateError(
              'No check found for business type "${type.name}"',
            ),
          );
          expect(
            reportCheck.exists,
            isTrue,
            reason: 'Report for ${type.name} should exist',
          );
          expect(
            reportCheck.nonEmpty,
            isTrue,
            reason: 'Report for ${type.name} should be non-empty',
          );
        }
      },
    );

    test('defects directory only needs to exist (may be empty)', () async {
      await createAllDeliverables(basePath);
      // The defects dir already exists but is empty — that's fine

      final checker = DeliverableChecker();
      final result = await checker.check(basePath);

      final defectsCheck = result.checks.firstWhere((c) => c.path == 'defects');
      expect(defectsCheck.exists, isTrue);
      expect(defectsCheck.nonEmpty, isTrue);
      expect(defectsCheck.defectId, isNull);
      expect(result.certificationComplete, isTrue);
    });

    test('records a defect when defects directory is missing', () async {
      await createAllDeliverables(basePath);
      // Remove the defects directory
      await Directory('$basePath/defects').delete(recursive: true);

      final checker = DeliverableChecker();
      final result = await checker.check(basePath);

      expect(result.certificationComplete, isFalse);
      final defectsCheck = result.checks.firstWhere((c) => c.path == 'defects');
      expect(defectsCheck.exists, isFalse);
      expect(defectsCheck.defectId, isNotNull);
    });

    test('defect IDs are unique across a check run', () async {
      // All deliverables missing → many defects, all with unique IDs
      final checker = DeliverableChecker();
      final result = await checker.check(basePath);

      final ids = result.defects.map((d) => d.id).toSet();
      expect(
        ids.length,
        equals(result.defects.length),
        reason: 'All defect IDs should be unique',
      );
    });

    test(
      'records defects for missing benchmark and production-readiness-checklist',
      () async {
        await createAllDeliverables(basePath);
        await File('$basePath/benchmark/industry-standards.md').delete();
        await File('$basePath/production-readiness-checklist.md').delete();

        final checker = DeliverableChecker();
        final result = await checker.check(basePath);

        expect(result.certificationComplete, isFalse);
        expect(result.defects.length, equals(2));

        final benchmarkCheck = result.checks.firstWhere(
          (c) => c.path == 'benchmark/industry-standards.md',
        );
        expect(benchmarkCheck.exists, isFalse);
        expect(benchmarkCheck.defectId, isNotNull);

        final checklistCheck = result.checks.firstWhere(
          (c) => c.path == 'production-readiness-checklist.md',
        );
        expect(checklistCheck.exists, isFalse);
        expect(checklistCheck.defectId, isNotNull);
      },
    );
  });
}
