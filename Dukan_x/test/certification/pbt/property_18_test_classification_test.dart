// Feature: comprehensive-test-certification, Property 18
// ============================================================================
// Property 18: Every test file maps to exactly one business type and one module.
//
// For any well-formed test path under the four layer roots:
//   - test/unit/{type}/{module}/*
//   - test/widget/{type}/{module}/*
//   - integration_test/{module}/*
//   - e2e/{type}/*
// the TestFileClassifier.classify returns a TestFileClassification with exactly
// one BusinessType and exactly one Module.
//
// For any malformed path (not under a recognized root, or containing unknown
// type/module segments), classify returns a ClassificationError.
//
// **Validates: Requirements 16.3, 16.4**
//
// PBT library: dartproptest ^0.2.1.
//   forAll((args...) => <bool>, [gen1, gen2, ...], numRuns: 200);
//
// Run: flutter test test/certification/pbt/property_18_test_classification_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import '../core/test_classifier.dart';
import '../core/domain.dart';
import 'generators.dart';

// ============================================================================
// GENERATORS
// ============================================================================

/// Generates a random Module from all enum values.
final Generator<Module> _moduleGen = Gen.elementOf<Module>(Module.values);

/// Generates a random file name suffix for test files.
final Generator<String> _fileNameGen = Gen.interval(
  1,
  9999,
).map((n) => 'test_${n}_test.dart');

/// Layer root selector: 0=unit, 1=widget, 2=integration, 3=e2e
final Generator<int> _layerRootGen = Gen.interval(0, 3);

/// Generates a random subdirectory depth (0–2 extra subdirs between module and file).
final Generator<int> _extraDepthGen = Gen.interval(0, 2);

/// Generates random extra subdirectory names.
final Generator<String> _subDirGen = Gen.interval(0, 99).map((n) => 'sub_$n');

// ============================================================================
// PATH CONSTRUCTION HELPERS
// ============================================================================

/// Builds a well-formed test path for layer roots that have {type}/{module}
/// structure (unit, widget).
String _buildTypeModulePath(
  String layerPrefix,
  BusinessType type,
  Module module,
  String fileName,
  int extraDepth,
) {
  final typeName = type.name;
  final moduleName = module.name;
  final extra = extraDepth > 0
      ? List.generate(extraDepth, (i) => 'nested_$i').join('/')
      : '';
  if (extra.isEmpty) {
    return '$layerPrefix$typeName/$moduleName/$fileName';
  }
  return '$layerPrefix$typeName/$moduleName/$extra/$fileName';
}

/// Builds a well-formed integration_test path ({module}/{type_filename}).
/// Business type is encoded in filename for inference.
String _buildIntegrationPath(
  BusinessType type,
  Module module,
  String fileName,
) {
  final moduleName = module.name;
  // Encode business type in filename so classifier can infer it
  final typedFileName = '${type.name}_$fileName';
  return 'integration_test/$moduleName/$typedFileName';
}

/// Builds a well-formed e2e path ({type}/{module_filename}).
/// Module is encoded in filename for inference.
String _buildE2ePath(BusinessType type, Module module, String fileName) {
  final typeName = type.name;
  // Encode module in filename so classifier can infer it
  final moduledFileName = '${module.name}_$fileName';
  return 'e2e/$typeName/$moduledFileName';
}

// ============================================================================
// TESTS
// ============================================================================

void main() {
  const classifier = TestFileClassifier();

  group('Property 18: Every test file maps to exactly one business type '
      'and one module', () {
    // ========================================================================
    // Direction 1: FORWARD — well-formed paths under test/unit/{type}/{module}
    // classify successfully with exactly one type and one module.
    // ========================================================================
    test(
      'FORWARD: test/unit/{type}/{module}/* → exactly one type and module',
      () {
        final held = forAll(
          (BusinessType type, Module module, String fileName, int extraDepth) {
            final path = _buildTypeModulePath(
              'test/unit/',
              type,
              module,
              fileName,
              extraDepth,
            );

            final result = classifier.classify(path);

            if (result is! TestFileClassification) return false;
            return result.businessType == type && result.module == module;
          },
          [businessTypeGen, _moduleGen, _fileNameGen, _extraDepthGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    // ========================================================================
    // Direction 2: FORWARD — well-formed paths under test/widget/{type}/{module}
    // classify successfully with exactly one type and one module.
    // ========================================================================
    test(
      'FORWARD: test/widget/{type}/{module}/* → exactly one type and module',
      () {
        final held = forAll(
          (BusinessType type, Module module, String fileName, int extraDepth) {
            final path = _buildTypeModulePath(
              'test/widget/',
              type,
              module,
              fileName,
              extraDepth,
            );

            final result = classifier.classify(path);

            if (result is! TestFileClassification) return false;
            return result.businessType == type && result.module == module;
          },
          [businessTypeGen, _moduleGen, _fileNameGen, _extraDepthGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    // ========================================================================
    // Direction 3: FORWARD — well-formed paths under integration_test/{module}
    // classify successfully with exactly one type and one module.
    // ========================================================================
    test(
      'FORWARD: integration_test/{module}/{type_file} → exactly one type and module',
      () {
        final held = forAll(
          (BusinessType type, Module module, String fileName) {
            final path = _buildIntegrationPath(type, module, fileName);

            final result = classifier.classify(path);

            if (result is! TestFileClassification) return false;
            // Must have exactly one type and one module
            return result.businessType == type && result.module == module;
          },
          [businessTypeGen, _moduleGen, _fileNameGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    // ========================================================================
    // Direction 4: FORWARD — well-formed paths under e2e/{type}
    // classify successfully with exactly one type and one module.
    // ========================================================================
    test('FORWARD: e2e/{type}/{module_file} → exactly one type and module', () {
      final held = forAll(
        (BusinessType type, Module module, String fileName) {
          final path = _buildE2ePath(type, module, fileName);

          final result = classifier.classify(path);

          if (result is! TestFileClassification) return false;
          // Must have exactly one type and one module
          return result.businessType == type && result.module == module;
        },
        [businessTypeGen, _moduleGen, _fileNameGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ========================================================================
    // Direction 5: REJECTION — malformed paths return ClassificationError.
    // ========================================================================
    test('REJECTION: malformed paths → ClassificationError', () {
      final malformedPathGen = Gen.interval(0, 5).map((selector) {
        switch (selector) {
          case 0:
            return 'lib/features/grocery/billing_screen.dart'; // not a test root
          case 1:
            return 'test/unit/'; // insufficient segments
          case 2:
            return 'test/widget/unknownType/billing/test.dart'; // unknown type
          case 3:
            return 'test/unit/grocery/unknownModule/test.dart'; // unknown module
          case 4:
            return 'src/main.dart'; // completely unrelated
          default:
            return 'random/path/nowhere.dart'; // no recognized layer root
        }
      });

      final held = forAll(
        (String path) {
          final result = classifier.classify(path);
          return result is ClassificationError;
        },
        [malformedPathGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // ========================================================================
    // Direction 6: FORWARD — all layer roots produce exactly one BusinessType
    // value (not null, not multiple) and exactly one Module value.
    // ========================================================================
    test(
      'FORWARD: classification result always has single non-null type and module',
      () {
        final held = forAll(
          (BusinessType type, Module module, String fileName, int layerRoot) {
            final String path;
            switch (layerRoot) {
              case 0:
                path = _buildTypeModulePath(
                  'test/unit/',
                  type,
                  module,
                  fileName,
                  0,
                );
                break;
              case 1:
                path = _buildTypeModulePath(
                  'test/widget/',
                  type,
                  module,
                  fileName,
                  0,
                );
                break;
              case 2:
                path = _buildIntegrationPath(type, module, fileName);
                break;
              default:
                path = _buildE2ePath(type, module, fileName);
                break;
            }

            final result = classifier.classify(path);

            if (result is! TestFileClassification) return false;

            // Verify exactly one type — it must be a valid enum value
            final isValidType = BusinessType.values.contains(
              result.businessType,
            );
            // Verify exactly one module — it must be a valid enum value
            final isValidModule = Module.values.contains(result.module);

            return isValidType && isValidModule;
          },
          [businessTypeGen, _moduleGen, _fileNameGen, _layerRootGen],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );
  });
}
