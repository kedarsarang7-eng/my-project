/// Integration test for full pipeline wiring (Task 17.3).
///
/// Drives [CertificationPipeline.run()] over a fixture workspace and asserts:
/// 1. `production-readiness-checklist.md` is produced
/// 2. The checklist contains a go/no-go decision
/// 3. `inventory/system-map.md` is produced
/// 4. `traceability-matrix.md` is produced
/// 5. [PipelineResult] contains systemMap, certificationReports (19),
///    gateStatuses, and readinessDecision
/// 6. Without real performance/security/regression data the pipeline produces
///    a no-go decision with non-empty reasons explaining unevaluatable items
///
/// Uses `dart:io` temp directories as fixtures.
///
/// **Validates: Requirements 14.1, 14.5, 16.1**
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'certification_pipeline.dart';
import 'core/domain.dart';
import 'core/gate_reducer.dart';

void main() {
  late Directory fixtureWorkspace;
  late Directory outputDir;

  setUp(() {
    // Create a temp fixture workspace with lib/features/ structure.
    fixtureWorkspace = Directory.systemTemp.createTempSync(
      'pipeline_fixture_ws_',
    );
    outputDir = Directory.systemTemp.createTempSync('pipeline_output_');

    // The scanner expects a pubspec.yaml to confirm the workspace path.
    File(
      '${fixtureWorkspace.path}/Dukan_x/pubspec.yaml',
    ).createSync(recursive: true);
    File(
      '${fixtureWorkspace.path}/Dukan_x/pubspec.yaml',
    ).writeAsStringSync('name: dukan_x\n');

    // Create a minimal lib/features/ structure with a few feature directories.
    _createFixtureFeatures(fixtureWorkspace.path);
  });

  tearDown(() {
    if (fixtureWorkspace.existsSync()) {
      fixtureWorkspace.deleteSync(recursive: true);
    }
    if (outputDir.existsSync()) {
      outputDir.deleteSync(recursive: true);
    }
  });

  group('CertificationPipeline.run() integration', () {
    test(
      'produces production-readiness-checklist.md with go/no-go decision',
      () async {
        final pipeline = CertificationPipeline();

        final config = PipelineConfig(
          workspacePath: fixtureWorkspace.path,
          outputPath: outputDir.path,
        );

        final result = await pipeline.run(config);

        // Assert: production-readiness-checklist.md is produced
        final checklistFile = File(
          '${outputDir.path}/production-readiness-checklist.md',
        );
        expect(
          checklistFile.existsSync(),
          isTrue,
          reason: 'production-readiness-checklist.md should be produced',
        );

        // Assert: the checklist contains a go/no-go decision
        final checklistContent = checklistFile.readAsStringSync();
        expect(
          checklistContent,
          contains('Final Decision:'),
          reason: 'Checklist should contain a go/no-go decision',
        );
        // Should be a NO-GO since no real data was provided
        expect(
          checklistContent,
          contains('NO-GO'),
          reason:
              'Decision should be NO-GO without real performance/security data',
        );
      },
    );

    test('produces system-map.md under inventory/', () async {
      final pipeline = CertificationPipeline();

      final config = PipelineConfig(
        workspacePath: fixtureWorkspace.path,
        outputPath: outputDir.path,
      );

      await pipeline.run(config);

      // Assert: system-map.md is produced under inventory/
      final systemMapFile = File('${outputDir.path}/inventory/system-map.md');
      expect(
        systemMapFile.existsSync(),
        isTrue,
        reason: 'inventory/system-map.md should be produced by the scan stage',
      );

      final systemMapContent = systemMapFile.readAsStringSync();
      expect(
        systemMapContent,
        contains('# System Map'),
        reason: 'system-map.md should have a proper header',
      );
      expect(
        systemMapContent.isNotEmpty,
        isTrue,
        reason: 'system-map.md should not be empty',
      );
    });

    test('produces traceability-matrix.md', () async {
      final pipeline = CertificationPipeline();

      final config = PipelineConfig(
        workspacePath: fixtureWorkspace.path,
        outputPath: outputDir.path,
      );

      await pipeline.run(config);

      // Assert: traceability-matrix.md is produced
      final matrixFile = File('${outputDir.path}/traceability-matrix.md');
      expect(
        matrixFile.existsSync(),
        isTrue,
        reason: 'traceability-matrix.md should be produced by the trace stage',
      );
    });

    test('PipelineResult contains systemMap, certificationReports (19), '
        'gateStatuses, and readinessDecision', () async {
      final pipeline = CertificationPipeline();

      final config = PipelineConfig(
        workspacePath: fixtureWorkspace.path,
        outputPath: outputDir.path,
      );

      final result = await pipeline.run(config);

      // Assert: systemMap is populated
      expect(result.systemMap, isNotNull);
      expect(
        result.systemMap.businessTypes,
        isNotEmpty,
        reason: 'SystemMap should enumerate business types',
      );

      // Assert: exactly 19 certification reports
      expect(
        result.certificationReports.length,
        equals(19),
        reason: 'Pipeline should produce exactly 19 certification reports',
      );

      // Assert: all 19 business types are represented
      final reportedTypes = result.certificationReports
          .map((r) => r.businessType)
          .toSet();
      for (final type in BusinessType.values) {
        expect(
          reportedTypes.contains(type.name),
          isTrue,
          reason: 'Certification report for ${type.name} should be present',
        );
      }

      // Assert: gateStatuses is populated with expected keys
      expect(result.gateStatuses, isNotEmpty);
      expect(result.gateStatuses.containsKey('performance'), isTrue);
      expect(result.gateStatuses.containsKey('security'), isTrue);
      expect(result.gateStatuses.containsKey('regression'), isTrue);
      expect(result.gateStatuses.containsKey('dataIntegrity'), isTrue);

      // Assert: readinessDecision is populated
      expect(result.readinessDecision, isNotNull);
    });

    test('produces no-go decision with non-empty reasons for '
        'unevaluatable items when no real data is provided', () async {
      final pipeline = CertificationPipeline();

      final config = PipelineConfig(
        workspacePath: fixtureWorkspace.path,
        outputPath: outputDir.path,
        // Intentionally not providing:
        // - performanceMeasurements
        // - securityCaseResults
        // - regressionResults
        // - recordSet
        // - releaseBuildPath
      );

      final result = await pipeline.run(config);

      // Assert: no-go decision
      expect(
        result.readinessDecision.go,
        isFalse,
        reason:
            'Without real data, the pipeline should produce a no-go decision',
      );

      // Assert: reasons list is non-empty explaining what couldn't be evaluated
      expect(
        result.readinessDecision.reasons,
        isNotEmpty,
        reason:
            'No-go decision should have reasons explaining unevaluatable items',
      );

      // Assert: all gates are notGreen since no data was provided
      for (final entry in result.gateStatuses.entries) {
        expect(
          entry.value,
          equals(GateStatus.notGreen),
          reason:
              'Gate "${entry.key}" should be notGreen without provided data',
        );
      }
    });

    test('checklist path in PipelineResult matches the output file', () async {
      final pipeline = CertificationPipeline();

      final config = PipelineConfig(
        workspacePath: fixtureWorkspace.path,
        outputPath: outputDir.path,
      );

      final result = await pipeline.run(config);

      // Assert: checklistPath points to the actual produced file
      expect(
        File(result.checklistPath).existsSync(),
        isTrue,
        reason:
            'The checklistPath in PipelineResult should point to an '
            'existing file',
      );
      expect(
        result.checklistPath,
        endsWith('production-readiness-checklist.md'),
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Fixture helpers
// ---------------------------------------------------------------------------

/// Creates a minimal fixture workspace under [basePath] with:
/// - `Dukan_x/lib/features/grocery/` containing a screen file
/// - `Dukan_x/lib/features/pharmacy/` containing a repository file
/// - `Dukan_x/lib/features/restaurant/` containing a screen file
///
/// This provides just enough structure for the InventoryScanner to find
/// some files without requiring the full 460+ screen codebase.
void _createFixtureFeatures(String basePath) {
  final dukanPath = '$basePath/Dukan_x';

  // Grocery feature — a screen
  final groceryScreenDir = Directory(
    '$dukanPath/lib/features/grocery/presentation/screens',
  );
  groceryScreenDir.createSync(recursive: true);
  File(
    '${groceryScreenDir.path}/grocery_billing_screen.dart',
  ).writeAsStringSync('''
import 'package:flutter/material.dart';

class GroceryBillingScreen extends StatelessWidget {
  static const String routeName = '/grocery-billing';

  const GroceryBillingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Grocery Billing')),
    );
  }
}
''');

  // Pharmacy feature — a repository with API call
  final pharmacyDir = Directory(
    '$dukanPath/lib/features/pharmacy/data/repositories',
  );
  pharmacyDir.createSync(recursive: true);
  File('${pharmacyDir.path}/pharmacy_repository.dart').writeAsStringSync('''
class PharmacyRepository {
  final apiClient = ApiClient();

  Future<void> fetchMedicines() async {
    final response = apiClient.get('/medicines');
    return response;
  }
}
''');

  // Restaurant feature — a screen with DynamoDB access
  final restaurantDir = Directory(
    '$dukanPath/lib/features/restaurant/presentation/screens',
  );
  restaurantDir.createSync(recursive: true);
  File('${restaurantDir.path}/restaurant_order_screen.dart').writeAsStringSync(
    '''
import 'package:flutter/material.dart';

class RestaurantOrderScreen extends StatefulWidget {
  static const String routeName = '/restaurant-order';

  const RestaurantOrderScreen({super.key});

  @override
  State<RestaurantOrderScreen> createState() => _RestaurantOrderScreenState();
}

class _RestaurantOrderScreenState extends State<RestaurantOrderScreen> {
  // Uses DynamoDB for order persistence
  final String TableName = 'orders';

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Restaurant Orders')),
    );
  }
}
''',
  );

  // Clinic feature — a service-only type screen
  final clinicDir = Directory(
    '$dukanPath/lib/features/clinic/presentation/screens',
  );
  clinicDir.createSync(recursive: true);
  File('${clinicDir.path}/patient_management_screen.dart').writeAsStringSync('''
import 'package:flutter/material.dart';

class PatientManagementScreen extends StatelessWidget {
  static const String routeName = '/patient-management';

  const PatientManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Patient Management')),
    );
  }
}
''');
}
