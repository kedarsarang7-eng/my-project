/// Unit tests for TestFileClassifier.
///
/// Validates:
/// - Requirement 16.3: Every test file maps to exactly one Business_Type and Module
/// - Requirement 16.4: Unassignable files are recorded as Defects
/// - Requirement 16.5: Service-only types omit product/inventory cases with rationale
library;

import 'package:flutter_test/flutter_test.dart';

import 'domain.dart';
import 'defect.dart';
import 'test_classifier.dart';

void main() {
  late TestFileClassifier classifier;

  setUp(() {
    classifier = const TestFileClassifier();
  });

  group('classify - test/unit/ layer', () {
    test('classifies valid unit test path', () {
      final result = classifier.classify(
        'test/unit/grocery/billing/tax_calc_test.dart',
      );

      expect(result, isA<TestFileClassification>());
      final classification = result as TestFileClassification;
      expect(classification.businessType, BusinessType.grocery);
      expect(classification.module, Module.billing);
    });

    test('classifies path with Windows separators', () {
      final result = classifier.classify(
        r'test\unit\pharmacy\payments\payment_test.dart',
      );

      expect(result, isA<TestFileClassification>());
      final classification = result as TestFileClassification;
      expect(classification.businessType, BusinessType.pharmacy);
      expect(classification.module, Module.payments);
    });

    test('classifies path with full prefix', () {
      final result = classifier.classify(
        'Dukan_x/test/unit/restaurant/reports/daily_report_test.dart',
      );

      expect(result, isA<TestFileClassification>());
      final classification = result as TestFileClassification;
      expect(classification.businessType, BusinessType.restaurant);
      expect(classification.module, Module.reports);
    });

    test('returns error for unknown business type', () {
      final result = classifier.classify(
        'test/unit/unknowntype/billing/test.dart',
      );

      expect(result, isA<ClassificationError>());
      final error = result as ClassificationError;
      expect(error.reason, contains('Unknown Business_Type'));
    });

    test('returns error for unknown module', () {
      final result = classifier.classify(
        'test/unit/grocery/unknownmodule/test.dart',
      );

      expect(result, isA<ClassificationError>());
      final error = result as ClassificationError;
      expect(error.reason, contains('Unknown Module'));
    });

    test('returns error for insufficient segments', () {
      final result = classifier.classify('test/unit/grocery/');

      expect(result, isA<ClassificationError>());
      final error = result as ClassificationError;
      expect(error.reason, contains('insufficient segments'));
    });
  });

  group('classify - test/widget/ layer', () {
    test('classifies valid widget test path', () {
      final result = classifier.classify(
        'test/widget/clothing/invoicegeneration/invoice_screen_test.dart',
      );

      expect(result, isA<TestFileClassification>());
      final classification = result as TestFileClassification;
      expect(classification.businessType, BusinessType.clothing);
      expect(classification.module, Module.invoiceGeneration);
    });

    test('classifies module with snake_case name', () {
      final result = classifier.classify(
        'test/widget/electronics/customer_management/list_test.dart',
      );

      expect(result, isA<TestFileClassification>());
      final classification = result as TestFileClassification;
      expect(classification.businessType, BusinessType.electronics);
      expect(classification.module, Module.customerManagement);
    });
  });

  group('classify - integration_test/ layer', () {
    test('classifies integration test with type in filename', () {
      final result = classifier.classify(
        'integration_test/billing/grocery_billing_test.dart',
      );

      expect(result, isA<TestFileClassification>());
      final classification = result as TestFileClassification;
      expect(classification.businessType, BusinessType.grocery);
      expect(classification.module, Module.billing);
    });

    test('defaults to other type when no type in filename', () {
      final result = classifier.classify(
        'integration_test/payments/generic_payment_test.dart',
      );

      expect(result, isA<TestFileClassification>());
      final classification = result as TestFileClassification;
      expect(classification.businessType, BusinessType.other);
      expect(classification.module, Module.payments);
    });

    test('returns error for unknown module', () {
      final result = classifier.classify(
        'integration_test/unknownmod/test.dart',
      );

      expect(result, isA<ClassificationError>());
      final error = result as ClassificationError;
      expect(error.reason, contains('Unknown Module'));
    });

    test('returns error for empty module segment', () {
      final result = classifier.classify('integration_test/');

      expect(result, isA<ClassificationError>());
      final error = result as ClassificationError;
      expect(error.reason, contains('no module segment'));
    });
  });

  group('classify - e2e/ layer', () {
    test('classifies valid e2e test path', () {
      final result = classifier.classify(
        'e2e/jewellery/billing_scenario_test.dart',
      );

      expect(result, isA<TestFileClassification>());
      final classification = result as TestFileClassification;
      expect(classification.businessType, BusinessType.jewellery);
      expect(classification.module, Module.billing);
    });

    test('infers module from file name', () {
      final result = classifier.classify(
        'e2e/wholesale/payments/payment_flow_test.dart',
      );

      expect(result, isA<TestFileClassification>());
      final classification = result as TestFileClassification;
      expect(classification.businessType, BusinessType.wholesale);
      expect(classification.module, Module.payments);
    });

    test('returns error for unknown type', () {
      final result = classifier.classify('e2e/nonexistent/test.dart');

      expect(result, isA<ClassificationError>());
      final error = result as ClassificationError;
      expect(error.reason, contains('Unknown Business_Type'));
    });

    test('returns error for empty type segment', () {
      final result = classifier.classify('e2e/');

      expect(result, isA<ClassificationError>());
      final error = result as ClassificationError;
      expect(error.reason, contains('no type segment'));
    });
  });

  group('classify - unrecognized paths', () {
    test('returns error for path outside all layer roots', () {
      final result = classifier.classify('lib/features/grocery/billing.dart');

      expect(result, isA<ClassificationError>());
      final error = result as ClassificationError;
      expect(
        error.reason,
        contains('does not match any recognized layer root'),
      );
    });

    test('returns error for random path', () {
      final result = classifier.classify('some/random/file.dart');

      expect(result, isA<ClassificationError>());
      final error = result as ClassificationError;
      expect(
        error.reason,
        contains('does not match any recognized layer root'),
      );
    });
  });

  group('createUnassignableDefect', () {
    test('creates a defect for classification errors (Req 16.4)', () {
      final error = ClassificationError(
        path: 'test/unit/unknown/test.dart',
        reason: 'Unknown Business_Type "unknown"',
      );

      final defect = classifier.createUnassignableDefect(error);

      expect(defect.id, isNotEmpty);
      expect(defect.severity, Severity.medium);
      expect(defect.reproSteps, hasLength(2));
      expect(defect.reproSteps[0], contains('test/unit/unknown/test.dart'));
      expect(defect.status, ResolutionStatus.open);
      expect(defect.category, GapCategory.missingRequirement);
    });
  });

  group('isProductOrInventoryCase', () {
    test('returns true for inventoryTracking module', () {
      final test = TestFileClassification(
        path: 'test/unit/grocery/inventorytracking/stock_test.dart',
        businessType: BusinessType.grocery,
        module: Module.inventoryTracking,
      );

      expect(classifier.isProductOrInventoryCase(test), isTrue);
    });

    test('returns true for supplierManagement module', () {
      final test = TestFileClassification(
        path: 'test/unit/grocery/suppliermanagement/supplier_test.dart',
        businessType: BusinessType.grocery,
        module: Module.supplierManagement,
      );

      expect(classifier.isProductOrInventoryCase(test), isTrue);
    });

    test('returns false for billing module', () {
      final test = TestFileClassification(
        path: 'test/unit/grocery/billing/tax_test.dart',
        businessType: BusinessType.grocery,
        module: Module.billing,
      );

      expect(classifier.isProductOrInventoryCase(test), isFalse);
    });

    test('returns false for payments module', () {
      final test = TestFileClassification(
        path: 'test/unit/grocery/payments/pay_test.dart',
        businessType: BusinessType.grocery,
        module: Module.payments,
      );

      expect(classifier.isProductOrInventoryCase(test), isFalse);
    });
  });

  group('buildServiceOnlyOmissions', () {
    test('returns empty list for non-service-only types', () {
      final tests = [
        TestFileClassification(
          path: 'test/unit/grocery/inventorytracking/stock_test.dart',
          businessType: BusinessType.grocery,
          module: Module.inventoryTracking,
        ),
      ];

      final omissions = classifier.buildServiceOnlyOmissions(
        BusinessType.grocery,
        tests,
      );

      expect(omissions, isEmpty);
    });

    test(
      'omits product/inventory tests for service-only types with rationale',
      () {
        final tests = [
          TestFileClassification(
            path: 'test/unit/service/inventorytracking/stock_test.dart',
            businessType: BusinessType.service,
            module: Module.inventoryTracking,
          ),
          TestFileClassification(
            path: 'test/unit/service/billing/bill_test.dart',
            businessType: BusinessType.service,
            module: Module.billing,
          ),
        ];

        final omissions = classifier.buildServiceOnlyOmissions(
          BusinessType.service,
          tests,
        );

        expect(omissions, hasLength(1));
        expect(omissions[0].testPath, contains('inventorytracking'));
        expect(omissions[0].rationale, contains('Service_Only_Type'));
        expect(
          omissions[0].rationale,
          contains('no product or inventory scope'),
        );
      },
    );

    test('omits supplierManagement tests for clinic type', () {
      final tests = [
        TestFileClassification(
          path: 'test/unit/clinic/suppliermanagement/supplier_test.dart',
          businessType: BusinessType.clinic,
          module: Module.supplierManagement,
        ),
      ];

      final omissions = classifier.buildServiceOnlyOmissions(
        BusinessType.clinic,
        tests,
      );

      expect(omissions, hasLength(1));
      expect(omissions[0].rationale, contains('clinic'));
    });

    test(
      'throws when product/inventory cases injected for service-only type',
      () {
        final tests = [
          TestFileClassification(
            path: 'test/unit/grocery/inventorytracking/stock_test.dart',
            businessType: BusinessType.grocery,
            module: Module.inventoryTracking,
          ),
        ];

        expect(
          () =>
              classifier.buildServiceOnlyOmissions(BusinessType.service, tests),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('works for all four service-only types', () {
      for (final type in kServiceOnlyTypes) {
        final tests = [
          TestFileClassification(
            path: 'test/unit/${type.name}/inventorytracking/test.dart',
            businessType: type,
            module: Module.inventoryTracking,
          ),
          TestFileClassification(
            path: 'test/unit/${type.name}/billing/test.dart',
            businessType: type,
            module: Module.billing,
          ),
        ];

        final omissions = classifier.buildServiceOnlyOmissions(type, tests);
        expect(
          omissions,
          hasLength(1),
          reason: 'Expected 1 omission for ${type.name}',
        );
        expect(omissions[0].rationale, contains('Service_Only_Type'));
      }
    });
  });

  group('buildServiceOnlyTestSet', () {
    test('includes all tests for non-service-only type', () {
      final tests = [
        TestFileClassification(
          path: 'test/unit/grocery/inventorytracking/test.dart',
          businessType: BusinessType.grocery,
          module: Module.inventoryTracking,
        ),
        TestFileClassification(
          path: 'test/unit/grocery/billing/test.dart',
          businessType: BusinessType.grocery,
          module: Module.billing,
        ),
      ];

      final result = classifier.buildServiceOnlyTestSet(
        BusinessType.grocery,
        tests,
      );

      expect(result, isA<ServiceOnlyBuildSuccess>());
      final success = result as ServiceOnlyBuildSuccess;
      expect(success.includedTests, hasLength(2));
      expect(success.omissions, isEmpty);
    });

    test('filters product/inventory for service-only type', () {
      final tests = [
        TestFileClassification(
          path: 'test/unit/service/inventorytracking/test.dart',
          businessType: BusinessType.service,
          module: Module.inventoryTracking,
        ),
        TestFileClassification(
          path: 'test/unit/service/billing/test.dart',
          businessType: BusinessType.service,
          module: Module.billing,
        ),
        TestFileClassification(
          path: 'test/unit/service/payments/test.dart',
          businessType: BusinessType.service,
          module: Module.payments,
        ),
      ];

      final result = classifier.buildServiceOnlyTestSet(
        BusinessType.service,
        tests,
      );

      expect(result, isA<ServiceOnlyBuildSuccess>());
      final success = result as ServiceOnlyBuildSuccess;
      expect(success.includedTests, hasLength(2));
      expect(success.omissions, hasLength(1));
      expect(
        success.includedTests.map((t) => t.module),
        containsAll([Module.billing, Module.payments]),
      );
    });

    test('rejects injection of product/inventory from different type', () {
      final tests = [
        TestFileClassification(
          path: 'test/unit/grocery/inventorytracking/test.dart',
          businessType: BusinessType.grocery,
          module: Module.inventoryTracking,
        ),
      ];

      final result = classifier.buildServiceOnlyTestSet(
        BusinessType.decorationCatering,
        tests,
      );

      expect(result, isA<ServiceOnlyBuildRejection>());
      final rejection = result as ServiceOnlyBuildRejection;
      expect(rejection.rejections, hasLength(1));
      expect(
        rejection.rejections[0].reason,
        contains('Cannot inject product/inventory'),
      );
    });
  });
}
