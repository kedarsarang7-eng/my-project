/// Test-file classifier and service-only test-set rules for the Certification_System.
///
/// Associates each test path under the four layer roots with exactly one
/// Business_Type and one Module. Records a defect for any unassignable file.
/// Builds service-only test sets that omit and record product/inventory cases
/// with rationale, rejecting injected product/inventory cases.
///
/// Layer roots:
///   - `test/unit/{type}/{module}/`
///   - `test/widget/{type}/{module}/`
///   - `integration_test/{module}/`
///   - `e2e/{type}/`
///
/// Requirements: 16.3, 16.4, 16.5
library;

import 'domain.dart';
import 'defect.dart';

// ---------------------------------------------------------------------------
// Result types (simple Either pattern)
// ---------------------------------------------------------------------------

/// A simple Either-like sealed class for classification results.
sealed class ClassificationResult {}

/// Successful classification — a test file maps to exactly one type and module.
class TestFileClassification extends ClassificationResult {
  /// The original test file path.
  final String path;

  /// The single Business_Type this test belongs to.
  final BusinessType businessType;

  /// The single Module this test belongs to.
  final Module module;

  TestFileClassification({
    required this.path,
    required this.businessType,
    required this.module,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestFileClassification &&
          other.path == path &&
          other.businessType == businessType &&
          other.module == module;

  @override
  int get hashCode => Object.hash(path, businessType, module);

  @override
  String toString() =>
      'TestFileClassification(path: $path, type: ${businessType.name}, module: ${module.name})';
}

/// Classification error — the test file could not be assigned.
class ClassificationError extends ClassificationResult {
  /// The file path that could not be classified.
  final String path;

  /// Human-readable reason for the classification failure.
  final String reason;

  ClassificationError({required this.path, required this.reason});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassificationError &&
          other.path == path &&
          other.reason == reason;

  @override
  int get hashCode => Object.hash(path, reason);

  @override
  String toString() => 'ClassificationError(path: $path, reason: $reason)';
}

// ---------------------------------------------------------------------------
// Service-only omission record
// ---------------------------------------------------------------------------

/// Records a test case that was omitted from a service-only test set.
class ServiceOnlyOmission {
  /// The path of the omitted test file.
  final String testPath;

  /// Why this was omitted (product/inventory not applicable to the type).
  final String rationale;

  const ServiceOnlyOmission({required this.testPath, required this.rationale});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceOnlyOmission &&
          other.testPath == testPath &&
          other.rationale == rationale;

  @override
  int get hashCode => Object.hash(testPath, rationale);

  @override
  String toString() =>
      'ServiceOnlyOmission(testPath: $testPath, rationale: $rationale)';
}

// ---------------------------------------------------------------------------
// Injection rejection error
// ---------------------------------------------------------------------------

/// Error returned when product/inventory cases are injected into a
/// service-only test set.
class ServiceOnlyInjectionError {
  /// The test that was rejected.
  final TestFileClassification test;

  /// Why the injection was rejected.
  final String reason;

  const ServiceOnlyInjectionError({required this.test, required this.reason});
}

// ---------------------------------------------------------------------------
// Service-only build result
// ---------------------------------------------------------------------------

/// Result of building a service-only test set.
sealed class ServiceOnlyBuildResult {}

/// Successful build — contains the filtered test set and omission records.
class ServiceOnlyBuildSuccess extends ServiceOnlyBuildResult {
  /// Tests that passed (not product/inventory).
  final List<TestFileClassification> includedTests;

  /// Tests that were omitted with rationale.
  final List<ServiceOnlyOmission> omissions;

  ServiceOnlyBuildSuccess({
    required this.includedTests,
    required this.omissions,
  });
}

/// Rejected build — product/inventory cases were injected.
class ServiceOnlyBuildRejection extends ServiceOnlyBuildResult {
  /// The injected tests that caused the rejection.
  final List<ServiceOnlyInjectionError> rejections;

  ServiceOnlyBuildRejection({required this.rejections});
}

// ---------------------------------------------------------------------------
// Lookup maps (string name → enum value)
// ---------------------------------------------------------------------------

/// Maps camelCase business type names to their enum values.
/// Handles both camelCase and lowercase matching.
final Map<String, BusinessType> _businessTypeByName = {
  for (final bt in BusinessType.values) bt.name.toLowerCase(): bt,
};

/// Maps camelCase module names to their enum values.
/// Also supports snake_case and kebab-case directory names.
final Map<String, Module> _moduleByName = {
  for (final m in Module.values) m.name.toLowerCase(): m,
  // Additional common directory-style mappings
  'customer_management': Module.customerManagement,
  'supplier_management': Module.supplierManagement,
  'inventory_tracking': Module.inventoryTracking,
  'invoice_generation': Module.invoiceGeneration,
  'data_sync': Module.dataSync,
  'offline_mode': Module.offlineMode,
  'subscription_controls': Module.subscriptionControls,
  'license_activation': Module.licenseActivation,
  'customer-management': Module.customerManagement,
  'supplier-management': Module.supplierManagement,
  'inventory-tracking': Module.inventoryTracking,
  'invoice-generation': Module.invoiceGeneration,
  'data-sync': Module.dataSync,
  'offline-mode': Module.offlineMode,
  'subscription-controls': Module.subscriptionControls,
  'license-activation': Module.licenseActivation,
};

/// Modules related to product/inventory — used to detect product/inventory
/// test cases that should be omitted for service-only types.
const Set<Module> kProductInventoryModules = {
  Module.inventoryTracking,
  Module.supplierManagement,
};

// ---------------------------------------------------------------------------
// TestFileClassifier
// ---------------------------------------------------------------------------

/// Classifies test files by their path structure under the four layer roots
/// and enforces service-only test-set rules.
///
/// The four recognized layer root patterns:
///   - `test/unit/{type}/{module}/...`
///   - `test/widget/{type}/{module}/...`
///   - `integration_test/{module}/...`
///   - `e2e/{type}/...`
///
/// For integration_test (which has no type segment), a default Business_Type
/// must be provided or the file's test name must encode the type.
class TestFileClassifier {
  const TestFileClassifier();

  /// Classify a test file path into exactly one BusinessType and one Module.
  ///
  /// Returns [TestFileClassification] on success, [ClassificationError] if
  /// the path doesn't match the expected structure or contains unknown
  /// type/module values.
  ClassificationResult classify(String path) {
    // Normalize path separators to forward slashes
    final normalized = path.replaceAll('\\', '/');

    // Try each layer root pattern in order
    final unitResult = _tryClassifyLayerWithTypeAndModule(
      normalized,
      'test/unit/',
    );
    if (unitResult != null) return unitResult;

    final widgetResult = _tryClassifyLayerWithTypeAndModule(
      normalized,
      'test/widget/',
    );
    if (widgetResult != null) return widgetResult;

    final integrationResult = _tryClassifyIntegrationTest(normalized);
    if (integrationResult != null) return integrationResult;

    final e2eResult = _tryClassifyE2e(normalized);
    if (e2eResult != null) return e2eResult;

    return ClassificationError(
      path: path,
      reason:
          'Path does not match any recognized layer root '
          '(test/unit/, test/widget/, integration_test/, e2e/)',
    );
  }

  /// Build service-only test sets: omit product/inventory test cases for
  /// service-only business types, recording the omission with rationale.
  /// Reject (return error) if product/inventory cases are injected for
  /// service-only types.
  ///
  /// A "product/inventory case" is any test whose module is in
  /// [kProductInventoryModules] (inventoryTracking, supplierManagement).
  ServiceOnlyBuildResult buildServiceOnlyTestSet(
    BusinessType type,
    List<TestFileClassification> tests,
  ) {
    // Only applies to service-only types
    if (!kServiceOnlyTypes.contains(type)) {
      // Non-service-only types include all tests without omission
      return ServiceOnlyBuildSuccess(
        includedTests: List.of(tests),
        omissions: [],
      );
    }

    // For service-only types, detect and reject injected product/inventory cases
    final injections = <ServiceOnlyInjectionError>[];
    final omissions = <ServiceOnlyOmission>[];
    final included = <TestFileClassification>[];

    for (final test in tests) {
      if (isProductOrInventoryCase(test)) {
        // Check if this test is for the same service-only business type
        if (test.businessType == type) {
          // This is an omission — legitimate test that doesn't apply
          omissions.add(
            ServiceOnlyOmission(
              testPath: test.path,
              rationale:
                  '${type.name} is a Service_Only_Type with no product or '
                  'inventory scope; ${test.module.name} tests do not apply.',
            ),
          );
        } else {
          // This is an injection — product/inventory test being forced into
          // a service-only set
          injections.add(
            ServiceOnlyInjectionError(
              test: test,
              reason:
                  'Cannot inject product/inventory test case '
                  '(${test.module.name}) into service-only type ${type.name}.',
            ),
          );
        }
      } else {
        included.add(test);
      }
    }

    // If any injections were detected, reject the entire build
    if (injections.isNotEmpty) {
      return ServiceOnlyBuildRejection(rejections: injections);
    }

    return ServiceOnlyBuildSuccess(
      includedTests: included,
      omissions: omissions,
    );
  }

  /// Build service-only omissions list (simpler API matching design spec).
  ///
  /// Returns a list of omitted tests with rationale. Throws [ArgumentError]
  /// if product/inventory cases are injected for a service-only type.
  List<ServiceOnlyOmission> buildServiceOnlyOmissions(
    BusinessType type,
    List<TestFileClassification> tests,
  ) {
    final result = buildServiceOnlyTestSet(type, tests);
    switch (result) {
      case ServiceOnlyBuildSuccess():
        return result.omissions;
      case ServiceOnlyBuildRejection():
        throw ArgumentError(
          'Rejected: product/inventory cases injected into service-only type '
          '${type.name}. Rejections: '
          '${result.rejections.map((r) => r.reason).join('; ')}',
        );
    }
  }

  /// Check if a test case is a product/inventory case.
  ///
  /// A test is considered product/inventory if its module is in
  /// [kProductInventoryModules].
  bool isProductOrInventoryCase(TestFileClassification test) {
    return kProductInventoryModules.contains(test.module);
  }

  /// Create a [Defect] record for an unassignable test file.
  Defect createUnassignableDefect(ClassificationError error) {
    return Defect(
      id: 'DEF-CLASSIFY-${error.path.hashCode.abs()}',
      severity: Severity.medium,
      reproSteps: [
        'Attempt to classify test file: ${error.path}',
        'Classification failed: ${error.reason}',
      ],
      status: ResolutionStatus.open,
      category: GapCategory.missingRequirement,
    );
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  /// Try to classify a path under a layer root that has `{type}/{module}/`
  /// structure (test/unit/ and test/widget/).
  ClassificationResult? _tryClassifyLayerWithTypeAndModule(
    String normalized,
    String layerRoot,
  ) {
    final rootIndex = normalized.indexOf(layerRoot);
    if (rootIndex == -1) return null;

    final afterRoot = normalized.substring(rootIndex + layerRoot.length);
    final segments = afterRoot.split('/').where((s) => s.isNotEmpty).toList();

    // Need at least {type}/{module}/{file}
    if (segments.length < 2) {
      return ClassificationError(
        path: normalized,
        reason:
            'Path under $layerRoot has insufficient segments to determine '
            'type and module (expected {type}/{module}/...)',
      );
    }

    final typeSegment = segments[0].toLowerCase();
    final moduleSegment = segments[1].toLowerCase();

    final businessType = _businessTypeByName[typeSegment];
    if (businessType == null) {
      return ClassificationError(
        path: normalized,
        reason: 'Unknown Business_Type "$typeSegment" in path segment',
      );
    }

    final module = _moduleByName[moduleSegment];
    if (module == null) {
      return ClassificationError(
        path: normalized,
        reason: 'Unknown Module "$moduleSegment" in path segment',
      );
    }

    return TestFileClassification(
      path: normalized,
      businessType: businessType,
      module: module,
    );
  }

  /// Try to classify a path under `integration_test/{module}/`.
  ///
  /// Integration tests are organized by module only. Business_Type is inferred
  /// from the file name if it contains a type prefix (e.g.,
  /// `integration_test/billing/grocery_billing_test.dart`), or defaults to the
  /// first applicable type for the module.
  ClassificationResult? _tryClassifyIntegrationTest(String normalized) {
    const layerRoot = 'integration_test/';
    final rootIndex = normalized.indexOf(layerRoot);
    if (rootIndex == -1) return null;

    final afterRoot = normalized.substring(rootIndex + layerRoot.length);
    final segments = afterRoot.split('/').where((s) => s.isNotEmpty).toList();

    // Need at least {module}/{file} or {module}
    if (segments.isEmpty) {
      return ClassificationError(
        path: normalized,
        reason: 'Path under integration_test/ has no module segment',
      );
    }

    final moduleSegment = segments[0].toLowerCase();
    final module = _moduleByName[moduleSegment];
    if (module == null) {
      return ClassificationError(
        path: normalized,
        reason: 'Unknown Module "$moduleSegment" in integration_test path',
      );
    }

    // Try to infer business type from file name
    final fileName = segments.length > 1
        ? segments.last.toLowerCase()
        : segments[0].toLowerCase();

    BusinessType? businessType;
    for (final entry in _businessTypeByName.entries) {
      if (fileName.contains(entry.key)) {
        businessType = entry.value;
        break;
      }
    }

    // If no type found in filename, check if module segment itself or path
    // contains a type name
    if (businessType == null) {
      for (final seg in segments.skip(1)) {
        final lowerSeg = seg.toLowerCase();
        for (final entry in _businessTypeByName.entries) {
          if (lowerSeg.startsWith(entry.key)) {
            businessType = entry.value;
            break;
          }
        }
        if (businessType != null) break;
      }
    }

    // Default to 'other' if no type can be inferred — this is a valid
    // classification since integration tests are organized by module
    businessType ??= BusinessType.other;

    return TestFileClassification(
      path: normalized,
      businessType: businessType,
      module: module,
    );
  }

  /// Try to classify a path under `e2e/{type}/`.
  ///
  /// E2E tests are organized by type. Module is inferred from the file name
  /// or the first subdirectory after the type.
  ClassificationResult? _tryClassifyE2e(String normalized) {
    const layerRoot = 'e2e/';
    final rootIndex = normalized.indexOf(layerRoot);
    if (rootIndex == -1) return null;

    final afterRoot = normalized.substring(rootIndex + layerRoot.length);
    final segments = afterRoot.split('/').where((s) => s.isNotEmpty).toList();

    // Need at least {type}/{file} or {type}
    if (segments.isEmpty) {
      return ClassificationError(
        path: normalized,
        reason: 'Path under e2e/ has no type segment',
      );
    }

    final typeSegment = segments[0].toLowerCase();
    final businessType = _businessTypeByName[typeSegment];
    if (businessType == null) {
      return ClassificationError(
        path: normalized,
        reason: 'Unknown Business_Type "$typeSegment" in e2e path',
      );
    }

    // Try to infer module from subsequent path segments or file name
    Module? module;
    for (final seg in segments.skip(1)) {
      final lowerSeg = seg
          .toLowerCase()
          .replaceAll('_test.dart', '')
          .replaceAll('.dart', '');
      final foundModule = _moduleByName[lowerSeg];
      if (foundModule != null) {
        module = foundModule;
        break;
      }
      // Try partial match in filename
      for (final entry in _moduleByName.entries) {
        if (lowerSeg.contains(entry.key)) {
          module = entry.value;
          break;
        }
      }
      if (module != null) break;
    }

    // For E2E tests, default module to billing (primary business scenario)
    module ??= Module.billing;

    return TestFileClassification(
      path: normalized,
      businessType: businessType,
      module: module,
    );
  }
}
