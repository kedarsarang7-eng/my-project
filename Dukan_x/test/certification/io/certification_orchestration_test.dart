/// Example tests for certification orchestration (Task 15.5).
///
/// Validates CertificationPass.runAll():
/// 1. All 19 reports produced with default runners (all pass).
/// 2. Custom runners that fail specific checks → FAIL reports with defect IDs.
/// 3. Service-only types have omissions in their reports.
/// 4. Exactly 19 distinct report files created.
/// 5. Report markdown contains correct structure (header, table, omissions section).
///
/// Requirements: 6.1, 6.6, 6.8
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'certification_pass.dart';
import '../core/domain.dart';
import 'defect_store.dart';

/// A check runner that always returns defects (simulates failures).
class _FailingCheckRunner implements CertificationCheckRunner {
  final List<String> defectIds;
  const _FailingCheckRunner(this.defectIds);

  @override
  Future<List<String>> run(BusinessType businessType) async => defectIds;
}

/// A check runner that fails only for specific business types.
class _SelectiveFailCheckRunner implements CertificationCheckRunner {
  final Set<BusinessType> failingTypes;
  final List<String> defectIds;

  const _SelectiveFailCheckRunner({
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

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('cert_orchestration_test_');
    basePath = tempDir.path;
    defectStore = DefectStore(basePath: basePath);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group(
    'CertificationPass.runAll — all six checks run, 19 reports (Req 6.1, 6.6, 6.8)',
    () {
      test('default runners → all 19 reports produced, all pass', () async {
        final certPass = CertificationPass(
          basePath: basePath,
          defectStore: defectStore,
        );

        final reports = await certPass.runAll();

        // Exactly 19 reports returned (Req 6.8).
        expect(reports.length, equals(19));

        // Every report has all six checks (Req 6.1).
        for (final report in reports) {
          expect(report.checks.length, equals(CheckName.values.length));
          final checkNames = report.checks.map((c) => c.name).toSet();
          for (final cn in CheckName.values) {
            expect(
              checkNames,
              contains(cn),
              reason: 'Missing check $cn for ${report.businessType}',
            );
          }
        }

        // All pass with default runners.
        for (final report in reports) {
          expect(
            report.overallPass,
            isTrue,
            reason: '${report.businessType} should pass with default runners',
          );
        }
      });

      test(
        'custom runners that fail specific checks → FAIL reports with defect IDs',
        () async {
          final certPass = CertificationPass(
            basePath: basePath,
            defectStore: defectStore,
            checkRunners: {
              CheckName.authAndOnboarding: const _FailingCheckRunner([
                'DEF-101',
              ]),
              CheckName.modulesInWorkflowOrder: const DefaultCheckRunner(),
              CheckName.routeReachability: const _FailingCheckRunner([
                'DEF-201',
                'DEF-202',
              ]),
              CheckName.rolePermissionEnforcement: const DefaultCheckRunner(),
              CheckName.reportAndAnalyticsAccuracy: const DefaultCheckRunner(),
              CheckName.billingInventoryPersistence: const _FailingCheckRunner([
                'DEF-301',
              ]),
            },
          );

          final reports = await certPass.runAll();

          // All 19 reports should still be generated (Req 6.8).
          expect(reports.length, equals(19));

          // Verify non-service-only types show FAIL with defect IDs.
          final groceryReport = reports.firstWhere(
            (r) => r.businessType == 'grocery',
          );
          expect(groceryReport.overallPass, isFalse);

          // Auth & Onboarding failed with DEF-101.
          final authCheck = groceryReport.checks.firstWhere(
            (c) => c.name == CheckName.authAndOnboarding,
          );
          expect(authCheck.passed, isFalse);
          expect(authCheck.defectIds, equals(['DEF-101']));

          // Route Reachability failed with DEF-201, DEF-202.
          final routeCheck = groceryReport.checks.firstWhere(
            (c) => c.name == CheckName.routeReachability,
          );
          expect(routeCheck.passed, isFalse);
          expect(routeCheck.defectIds, equals(['DEF-201', 'DEF-202']));

          // Billing & Inventory failed with DEF-301 (non-service-only type).
          final billingCheck = groceryReport.checks.firstWhere(
            (c) => c.name == CheckName.billingInventoryPersistence,
          );
          expect(billingCheck.passed, isFalse);
          expect(billingCheck.defectIds, equals(['DEF-301']));

          // Modules in Workflow Order passed (default runner).
          final modulesCheck = groceryReport.checks.firstWhere(
            (c) => c.name == CheckName.modulesInWorkflowOrder,
          );
          expect(modulesCheck.passed, isTrue);
          expect(modulesCheck.defectIds, isEmpty);

          // Verify the markdown report file reflects FAIL.
          final reportFile = File('$basePath/reports/business-type-grocery.md');
          expect(reportFile.existsSync(), isTrue);
          final content = reportFile.readAsStringSync();
          expect(content, contains('## Overall Result: FAIL'));
          expect(content, contains('| Auth & Onboarding | FAIL | DEF-101 |'));
          expect(
            content,
            contains('| Route Reachability | FAIL | DEF-201, DEF-202 |'),
          );
        },
      );

      test('service-only types have omissions in their reports', () async {
        final certPass = CertificationPass(
          basePath: basePath,
          defectStore: defectStore,
        );

        final reports = await certPass.runAll();

        // The four service-only types.
        const serviceOnlyNames = {
          'service',
          'clinic',
          'schoolErp',
          'decorationCatering',
        };

        for (final report in reports) {
          if (serviceOnlyNames.contains(report.businessType)) {
            // Service-only types have omissions.
            expect(
              report.omittedTests,
              isNotEmpty,
              reason: '${report.businessType} should have omissions',
            );

            // Omissions mention inventory and supplier management.
            expect(
              report.omittedTests.any((o) => o.contains('Inventory Tracking')),
              isTrue,
              reason: '${report.businessType} should omit inventory tests',
            );
            expect(
              report.omittedTests.any((o) => o.contains('Supplier Management')),
              isTrue,
              reason: '${report.businessType} should omit supplier tests',
            );

            // Report markdown has service-only omissions section.
            final file = File(
              '$basePath/reports/business-type-${report.businessType}.md',
            );
            final content = file.readAsStringSync();
            expect(content, contains('## Service-Only Omissions'));
            expect(content, contains('Service_Only_Type'));
          } else {
            // Non-service-only types have no omissions.
            expect(
              report.omittedTests,
              isEmpty,
              reason: '${report.businessType} should not have omissions',
            );
          }
        }
      });

      test('exactly 19 distinct report files created', () async {
        final certPass = CertificationPass(
          basePath: basePath,
          defectStore: defectStore,
        );

        await certPass.runAll();

        final reportsDir = Directory('$basePath/reports');
        expect(reportsDir.existsSync(), isTrue);

        final reportFiles = reportsDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.md'))
            .toList();

        // Exactly 19 files (Req 6.8).
        expect(reportFiles.length, equals(19));

        // Each file is distinct — one per business type.
        final fileNames = reportFiles.map((f) {
          final name = f.uri.pathSegments.last;
          return name;
        }).toSet();
        expect(fileNames.length, equals(19));

        // Verify all 19 business type names are represented.
        for (final bt in BusinessType.values) {
          expect(
            fileNames.contains('business-type-${bt.name}.md'),
            isTrue,
            reason: 'Missing report file for ${bt.name}',
          );
        }
      });

      test(
        'report markdown contains correct structure (header, table, omissions)',
        () async {
          final certPass = CertificationPass(
            basePath: basePath,
            defectStore: defectStore,
            checkRunners: {
              CheckName.authAndOnboarding: const DefaultCheckRunner(),
              CheckName.modulesInWorkflowOrder: const DefaultCheckRunner(),
              CheckName.routeReachability: const _FailingCheckRunner([
                'DEF-X01',
              ]),
              CheckName.rolePermissionEnforcement: const DefaultCheckRunner(),
              CheckName.reportAndAnalyticsAccuracy: const DefaultCheckRunner(),
              CheckName.billingInventoryPersistence: const DefaultCheckRunner(),
            },
          );

          // Run for a service-only type to verify all sections.
          await certPass.runAll();

          // --- Verify non-service-only type report structure ---
          final groceryFile = File(
            '$basePath/reports/business-type-grocery.md',
          );
          final groceryContent = groceryFile.readAsStringSync();

          // Header
          expect(groceryContent, contains('# Certification Report: grocery'));
          // Overall Result
          expect(groceryContent, contains('## Overall Result: FAIL'));
          // Checks table
          expect(groceryContent, contains('## Checks'));
          expect(groceryContent, contains('| Check | Result | Defect IDs |'));
          expect(groceryContent, contains('|-------|--------|------------|'));
          // All six checks present
          expect(groceryContent, contains('| Auth & Onboarding |'));
          expect(groceryContent, contains('| Modules in Workflow Order |'));
          expect(groceryContent, contains('| Route Reachability |'));
          expect(groceryContent, contains('| Role Permission Enforcement |'));
          expect(groceryContent, contains('| Report & Analytics Accuracy |'));
          expect(
            groceryContent,
            contains('| Billing & Inventory Persistence |'),
          );
          // FAIL check with defect ID
          expect(
            groceryContent,
            contains('| Route Reachability | FAIL | DEF-X01 |'),
          );
          // PASS checks show — for defect column
          expect(groceryContent, contains('| PASS | — |'));
          // Non-service-only has no omissions section
          expect(groceryContent, isNot(contains('## Service-Only Omissions')));

          // --- Verify service-only type report structure ---
          final clinicFile = File('$basePath/reports/business-type-clinic.md');
          final clinicContent = clinicFile.readAsStringSync();

          // Header
          expect(clinicContent, contains('# Certification Report: clinic'));
          // Overall result (route reachability fails for all types)
          expect(clinicContent, contains('## Overall Result: FAIL'));
          // Service-Only Omissions section present
          expect(clinicContent, contains('## Service-Only Omissions'));
          // Omissions list items
          expect(clinicContent, contains('- Inventory Tracking tests'));
          expect(clinicContent, contains('- Supplier Management tests'));
        },
      );
    },
  );

  group('CertificationPass — defects recorded on failure', () {
    test('selective runner records defects only for targeted types', () async {
      final targetTypes = {BusinessType.jewellery, BusinessType.pharmacy};

      final certPass = CertificationPass(
        basePath: basePath,
        defectStore: defectStore,
        checkRunners: {
          CheckName.authAndOnboarding: const DefaultCheckRunner(),
          CheckName.modulesInWorkflowOrder: _SelectiveFailCheckRunner(
            failingTypes: targetTypes,
            defectIds: ['DEF-SEL-001'],
          ),
          CheckName.routeReachability: const DefaultCheckRunner(),
          CheckName.rolePermissionEnforcement: const DefaultCheckRunner(),
          CheckName.reportAndAnalyticsAccuracy: const DefaultCheckRunner(),
          CheckName.billingInventoryPersistence: const DefaultCheckRunner(),
        },
      );

      final reports = await certPass.runAll();

      // Targeted types FAIL.
      final jewelleryReport = reports.firstWhere(
        (r) => r.businessType == 'jewellery',
      );
      expect(jewelleryReport.overallPass, isFalse);
      final modCheck = jewelleryReport.checks.firstWhere(
        (c) => c.name == CheckName.modulesInWorkflowOrder,
      );
      expect(modCheck.defectIds, equals(['DEF-SEL-001']));

      // Non-targeted types PASS.
      final groceryReport = reports.firstWhere(
        (r) => r.businessType == 'grocery',
      );
      expect(groceryReport.overallPass, isTrue);
    });

    test('multiple failing checks accumulate defects per type', () async {
      final certPass = CertificationPass(
        basePath: basePath,
        defectStore: defectStore,
        checkRunners: {
          CheckName.authAndOnboarding: const _FailingCheckRunner(['DEF-A1']),
          CheckName.modulesInWorkflowOrder: const _FailingCheckRunner([
            'DEF-M1',
          ]),
          CheckName.routeReachability: const _FailingCheckRunner([
            'DEF-R1',
            'DEF-R2',
          ]),
          CheckName.rolePermissionEnforcement: const _FailingCheckRunner([
            'DEF-P1',
          ]),
          CheckName.reportAndAnalyticsAccuracy: const _FailingCheckRunner([
            'DEF-RA1',
          ]),
          CheckName.billingInventoryPersistence: const _FailingCheckRunner([
            'DEF-B1',
          ]),
        },
      );

      final reports = await certPass.runAll();

      // Non-service-only type: all 6 checks fail.
      final hwReport = reports.firstWhere((r) => r.businessType == 'hardware');
      expect(hwReport.overallPass, isFalse);
      expect(hwReport.checks.where((c) => !c.passed).length, equals(6));

      // Service-only type: billing/inventory check is skipped (passes by default).
      final svcReport = reports.firstWhere((r) => r.businessType == 'service');
      expect(svcReport.overallPass, isFalse);
      final billingCheck = svcReport.checks.firstWhere(
        (c) => c.name == CheckName.billingInventoryPersistence,
      );
      // Service-only: billing check is skipped → passes even with failing runner.
      expect(billingCheck.passed, isTrue);
      expect(billingCheck.defectIds, isEmpty);
    });
  });
}
