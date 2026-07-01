import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'certification_pass.dart';
import '../core/domain.dart';
import 'defect_store.dart';

/// A check runner that always returns defects (simulates failures).
class FailingCheckRunner implements CertificationCheckRunner {
  final List<String> defectIds;
  const FailingCheckRunner(this.defectIds);

  @override
  Future<List<String>> run(BusinessType businessType) async => defectIds;
}

/// A check runner that fails only for specific business types.
class SelectiveFailCheckRunner implements CertificationCheckRunner {
  final Set<BusinessType> failingTypes;
  final List<String> defectIds;

  const SelectiveFailCheckRunner({
    required this.failingTypes,
    required this.defectIds,
  });

  @override
  Future<List<String>> run(BusinessType businessType) async {
    if (failingTypes.contains(businessType)) return defectIds;
    return [];
  }
}

void main() {
  late Directory tempDir;
  late String basePath;
  late DefectStore defectStore;
  late CertificationPass certPass;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('cert_pass_test_');
    basePath = tempDir.path;
    defectStore = DefectStore(basePath: basePath);
    certPass = CertificationPass(basePath: basePath, defectStore: defectStore);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('CertificationPass.runAll', () {
    test('produces exactly 19 reports', () async {
      final reports = await certPass.runAll();
      expect(reports.length, equals(19));
    });

    test('each report covers a distinct business type', () async {
      final reports = await certPass.runAll();
      final reportedTypes = reports.map((r) => r.businessType).toSet();
      expect(reportedTypes.length, equals(19));

      // Verify all 19 business types are present
      for (final bt in BusinessType.values) {
        expect(reportedTypes, contains(bt.name));
      }
    });

    test('writes 19 report files to reports/ directory', () async {
      await certPass.runAll();

      final reportsDir = Directory('$basePath/reports');
      expect(reportsDir.existsSync(), isTrue);

      final reportFiles = reportsDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .toList();
      expect(reportFiles.length, equals(19));
    });

    test('report filenames follow business-type-<name>.md pattern', () async {
      await certPass.runAll();

      final reportsDir = Directory('$basePath/reports');
      for (final bt in BusinessType.values) {
        final expectedFile = File(
          '$basePath/reports/business-type-${bt.name}.md',
        );
        expect(
          expectedFile.existsSync(),
          isTrue,
          reason: 'Missing report for ${bt.name}',
        );
      }
    });
  });

  group('CertificationPass.run — report content', () {
    test('report contains correct header and overall result (PASS)', () async {
      final report = await certPass.run(BusinessType.grocery);

      final file = File('$basePath/reports/business-type-grocery.md');
      final content = file.readAsStringSync();

      expect(content, contains('# Certification Report: grocery'));
      expect(content, contains('## Overall Result: PASS'));
    });

    test('report contains checks table with all six checks', () async {
      await certPass.run(BusinessType.grocery);

      final file = File('$basePath/reports/business-type-grocery.md');
      final content = file.readAsStringSync();

      expect(content, contains('## Checks'));
      expect(content, contains('| Check | Result | Defect IDs |'));
      expect(content, contains('| Auth & Onboarding |'));
      expect(content, contains('| Modules in Workflow Order |'));
      expect(content, contains('| Route Reachability |'));
      expect(content, contains('| Role Permission Enforcement |'));
      expect(content, contains('| Report & Analytics Accuracy |'));
      expect(content, contains('| Billing & Inventory Persistence |'));
    });

    test('report shows FAIL with defect IDs when check fails', () async {
      final failPass = CertificationPass(
        basePath: basePath,
        defectStore: defectStore,
        checkRunners: {
          CheckName.authAndOnboarding: const DefaultCheckRunner(),
          CheckName.modulesInWorkflowOrder: const DefaultCheckRunner(),
          CheckName.routeReachability: const FailingCheckRunner([
            'DEF-001',
            'DEF-002',
          ]),
          CheckName.rolePermissionEnforcement: const DefaultCheckRunner(),
          CheckName.reportAndAnalyticsAccuracy: const DefaultCheckRunner(),
          CheckName.billingInventoryPersistence: const DefaultCheckRunner(),
        },
      );

      final report = await failPass.run(BusinessType.pharmacy);
      expect(report.overallPass, isFalse);
      expect(report.checks[2].passed, isFalse);
      expect(report.checks[2].defectIds, equals(['DEF-001', 'DEF-002']));

      final file = File('$basePath/reports/business-type-pharmacy.md');
      final content = file.readAsStringSync();

      expect(content, contains('## Overall Result: FAIL'));
      expect(
        content,
        contains('| Route Reachability | FAIL | DEF-001, DEF-002 |'),
      );
    });

    test('overall result is FAIL if any check has defects (Req 6.7)', () async {
      final failPass = CertificationPass(
        basePath: basePath,
        defectStore: defectStore,
        checkRunners: {
          CheckName.authAndOnboarding: const DefaultCheckRunner(),
          CheckName.modulesInWorkflowOrder: const DefaultCheckRunner(),
          CheckName.routeReachability: const DefaultCheckRunner(),
          CheckName.rolePermissionEnforcement: const DefaultCheckRunner(),
          CheckName.reportAndAnalyticsAccuracy: const FailingCheckRunner([
            'DEF-003',
          ]),
          CheckName.billingInventoryPersistence: const DefaultCheckRunner(),
        },
      );

      final report = await failPass.run(BusinessType.electronics);
      expect(report.overallPass, isFalse);
    });
  });

  group('Service-only omissions (Req 16.5)', () {
    test('service-only types include omissions in report', () async {
      final report = await certPass.run(BusinessType.service);

      expect(report.omittedTests, isNotEmpty);
      expect(
        report.omittedTests.any((o) => o.contains('Inventory Tracking')),
        isTrue,
      );
      expect(
        report.omittedTests.any((o) => o.contains('Supplier Management')),
        isTrue,
      );

      final file = File('$basePath/reports/business-type-service.md');
      final content = file.readAsStringSync();

      expect(content, contains('## Service-Only Omissions'));
      expect(content, contains('Service_Only_Type'));
    });

    test('clinic type includes service-only omissions', () async {
      final report = await certPass.run(BusinessType.clinic);
      expect(report.omittedTests, isNotEmpty);
    });

    test('schoolErp type includes service-only omissions', () async {
      final report = await certPass.run(BusinessType.schoolErp);
      expect(report.omittedTests, isNotEmpty);
    });

    test('decorationCatering type includes service-only omissions', () async {
      final report = await certPass.run(BusinessType.decorationCatering);
      expect(report.omittedTests, isNotEmpty);
    });

    test('non-service-only types have no omissions', () async {
      final report = await certPass.run(BusinessType.grocery);
      expect(report.omittedTests, isEmpty);

      final file = File('$basePath/reports/business-type-grocery.md');
      final content = file.readAsStringSync();

      expect(content, isNot(contains('## Service-Only Omissions')));
    });
  });

  group('Report markdown format', () {
    test('all six CheckName values produce check results', () async {
      final report = await certPass.run(BusinessType.restaurant);
      expect(report.checks.length, equals(CheckName.values.length));

      final checkNames = report.checks.map((c) => c.name).toSet();
      for (final cn in CheckName.values) {
        expect(checkNames, contains(cn));
      }
    });

    test('PASS checks show dash for defect IDs column', () async {
      await certPass.run(BusinessType.wholesale);

      final file = File('$basePath/reports/business-type-wholesale.md');
      final content = file.readAsStringSync();

      // All checks pass → each should have — in defect column
      expect(content, contains('| PASS | — |'));
    });
  });
}
