// Feature: comprehensive-test-certification, Property 19
// ============================================================================
// Property 19: Service-only certification omits product and inventory test cases.
//
// For any Service_Only_Type (service, clinic, schoolErp, decorationCatering),
// the produced test set contains no product or inventory test case and each
// omitted case is recorded with the rationale that the type has no product or
// inventory scope; and for any attempt to inject a product or inventory case
// into a service-only set, the case is rejected.
//
// Non-service-only types include all tests without omission.
//
// **Validates: Requirements 16.5**
//
// PBT library: dartproptest ^0.2.1.
//   forAll((args...) => <bool>, [gen1, gen2, ...], numRuns: 200);
//
// Run: flutter test test/certification/pbt/property_19_service_only_omission_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import '../core/domain.dart';
import '../core/test_classifier.dart';
import 'generators.dart';

// ============================================================================
// GENERATORS
// ============================================================================

/// All modules as a list for indexed access.
const List<Module> _allModules = Module.values;

/// The modules that are product/inventory related (should be omitted for
/// service-only types).
const Set<Module> _productInventoryModules = kProductInventoryModules;

/// Modules that are NOT product/inventory (safe for service-only types).
final List<Module> _nonProductModules = _allModules
    .where((m) => !_productInventoryModules.contains(m))
    .toList();

/// Generates a random Module from ALL modules (including product/inventory).
final Generator<Module> _anyModuleGen = Gen.elementOf<Module>(_allModules);

/// Generates a Module that IS in kProductInventoryModules.
final Generator<Module> _productModuleGen = Gen.elementOf<Module>(
  _productInventoryModules.toList(),
);

/// Generates a Module that is NOT in kProductInventoryModules.
final Generator<Module> _nonProductModuleGen = Gen.elementOf<Module>(
  _nonProductModules,
);

/// Generates a test file path index (used to build unique paths).
final Generator<int> _pathIndexGen = Gen.interval(1, 99999);

/// Generates a count of test files (1–10).
final Generator<int> _testCountGen = Gen.interval(1, 10);

/// Generates a non-service-only business type.
final List<BusinessType> _nonServiceTypes = BusinessType.values
    .where((bt) => !kServiceOnlyTypes.contains(bt))
    .toList();

final Generator<BusinessType> _nonServiceTypeGen = Gen.elementOf<BusinessType>(
  _nonServiceTypes,
);

// ============================================================================
// HELPERS
// ============================================================================

/// Builds a [TestFileClassification] for a given type and module with a
/// unique path.
TestFileClassification _makeTest(
  BusinessType type,
  Module module,
  int pathSeed,
) {
  return TestFileClassification(
    path: 'test/unit/${type.name}/${module.name}/test_$pathSeed.dart',
    businessType: type,
    module: module,
  );
}

/// Builds a mixed list of test classifications for a given type — some with
/// product/inventory modules, some without.
List<TestFileClassification> _buildMixedTestSet(
  BusinessType type,
  int count,
  int baseSeed,
) {
  final tests = <TestFileClassification>[];
  for (var i = 0; i < count; i++) {
    // Alternate between product and non-product modules
    final module = i.isEven && _nonProductModules.isNotEmpty
        ? _nonProductModules[i % _nonProductModules.length]
        : _productInventoryModules.toList()[i %
              _productInventoryModules.length];
    tests.add(_makeTest(type, module, baseSeed + i));
  }
  return tests;
}

/// Builds a list of tests that are ALL product/inventory for a given type.
List<TestFileClassification> _buildProductOnlyTestSet(
  BusinessType type,
  int count,
  int baseSeed,
) {
  final modules = _productInventoryModules.toList();
  final tests = <TestFileClassification>[];
  for (var i = 0; i < count; i++) {
    tests.add(_makeTest(type, modules[i % modules.length], baseSeed + i));
  }
  return tests;
}

/// Builds a list of tests that are ALL non-product/inventory for a given type.
List<TestFileClassification> _buildNonProductTestSet(
  BusinessType type,
  int count,
  int baseSeed,
) {
  final tests = <TestFileClassification>[];
  for (var i = 0; i < count; i++) {
    tests.add(
      _makeTest(
        type,
        _nonProductModules[i % _nonProductModules.length],
        baseSeed + i,
      ),
    );
  }
  return tests;
}

// ============================================================================
// TESTS
// ============================================================================

void main() {
  const classifier = TestFileClassifier();

  group('Feature: comprehensive-test-certification, Property 19: '
      'Service-only certification omits product and inventory test cases', () {
    // FORWARD: Service-only types omit ALL product/inventory tests and record
    // each with rationale.
    test('Property 19 FORWARD: service-only types omit product/inventory '
        'tests and record omissions with rationale', () {
      final held = forAll(
        (int serviceTypeIdx, int testCount, int baseSeed) {
          final serviceTypes = kServiceOnlyTypes.toList();
          final type = serviceTypes[serviceTypeIdx % serviceTypes.length];
          final count = (testCount % 10) + 1; // 1–10 tests

          // Build a mixed test set with both product and non-product tests
          final tests = _buildMixedTestSet(type, count, baseSeed);
          final result = classifier.buildServiceOnlyTestSet(type, tests);

          // Must succeed (no injections since tests are for the same type)
          if (result is! ServiceOnlyBuildSuccess) return false;

          final success = result;

          // Verify: included tests contain NO product/inventory modules
          for (final t in success.includedTests) {
            if (_productInventoryModules.contains(t.module)) return false;
          }

          // Verify: every product/inventory test is recorded in omissions
          final productTests = tests
              .where((t) => _productInventoryModules.contains(t.module))
              .toList();
          if (success.omissions.length != productTests.length) return false;

          // Verify: each omission has a rationale mentioning no scope
          for (final omission in success.omissions) {
            if (!omission.rationale.contains('Service_Only_Type')) return false;
            if (!omission.rationale.contains('no product or inventory scope')) {
              return false;
            }
          }

          return true;
        },
        [
          Gen.interval(0, 3), // serviceTypeIdx (4 service-only types)
          _testCountGen,
          _pathIndexGen,
        ],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // FORWARD: Non-service-only types include ALL tests (no omissions).
    test('Property 19 FORWARD: non-service-only types include all tests '
        'without omission', () {
      final held = forAll(
        (int nonServiceTypeIdx, int testCount, int baseSeed) {
          final type =
              _nonServiceTypes[nonServiceTypeIdx % _nonServiceTypes.length];
          final count = (testCount % 10) + 1; // 1–10 tests

          // Build a mixed test set with product and non-product tests
          final tests = _buildMixedTestSet(type, count, baseSeed);
          final result = classifier.buildServiceOnlyTestSet(type, tests);

          // Must succeed
          if (result is! ServiceOnlyBuildSuccess) return false;

          final success = result;

          // Non-service-only types should have ALL tests included
          if (success.includedTests.length != tests.length) return false;

          // No omissions for non-service-only types
          if (success.omissions.isNotEmpty) return false;

          return true;
        },
        [
          Gen.interval(0, _nonServiceTypes.length - 1),
          _testCountGen,
          _pathIndexGen,
        ],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // REJECTION: Injecting product/inventory cases from a different type into
    // a service-only set is rejected.
    test('Property 19 REJECTION: injecting product/inventory case into '
        'service-only set is rejected', () {
      final held = forAll(
        (int serviceTypeIdx, int baseSeed, int injectedTypeIdx) {
          final serviceTypes = kServiceOnlyTypes.toList();
          final type = serviceTypes[serviceTypeIdx % serviceTypes.length];

          // Pick a DIFFERENT type (non-service) for the injected test
          final injectedType =
              _nonServiceTypes[injectedTypeIdx % _nonServiceTypes.length];

          // Create a product/inventory test attributed to a different type
          final injectedTest = TestFileClassification(
            path:
                'test/unit/${injectedType.name}/inventory_tracking/test_$baseSeed.dart',
            businessType: injectedType,
            module: Module.inventoryTracking,
          );

          // Build a test set with the injected foreign product/inventory case
          final tests = [injectedTest];
          final result = classifier.buildServiceOnlyTestSet(type, tests);

          // Must be rejected
          if (result is! ServiceOnlyBuildRejection) return false;

          final rejection = result;

          // Must identify the injected test in rejections
          if (rejection.rejections.isEmpty) return false;
          if (rejection.rejections.first.test != injectedTest) return false;

          return true;
        },
        [
          Gen.interval(0, 3), // serviceTypeIdx
          _pathIndexGen,
          Gen.interval(0, _nonServiceTypes.length - 1),
        ],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // FORWARD: service-only type with ONLY non-product tests → all included,
    // zero omissions.
    test('Property 19 FORWARD: service-only type with only non-product tests '
        '→ all included, zero omissions', () {
      final held = forAll(
        (int serviceTypeIdx, int testCount, int baseSeed) {
          final serviceTypes = kServiceOnlyTypes.toList();
          final type = serviceTypes[serviceTypeIdx % serviceTypes.length];
          final count = (testCount % 10) + 1;

          // Build tests with only non-product modules
          final tests = _buildNonProductTestSet(type, count, baseSeed);
          final result = classifier.buildServiceOnlyTestSet(type, tests);

          if (result is! ServiceOnlyBuildSuccess) return false;

          final success = result;

          // All tests should be included
          if (success.includedTests.length != tests.length) return false;
          // No omissions since no product/inventory tests exist
          if (success.omissions.isNotEmpty) return false;

          return true;
        },
        [Gen.interval(0, 3), _testCountGen, _pathIndexGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });
  });
}
