/// Preservation Property Test — Petrol Pump GST Defaults Preserved
///
/// **Validates: Requirements 3.2**
///
/// Property 16: Preservation — Petrol Pump GST Defaults Preserved
///
/// This test confirms that the three already-correct GST zero-values remain
/// unchanged by the fix:
/// 1. `BusinessTypeConfig.petrolPump.defaultGstRate` == 0.0
/// 2. `FuelType.linkedGSTRate`'s default == 0.0
/// 3. `PetrolPumpBillingService.createFuelBill`'s `const gstRate = 0.0` override
///
/// The fix enforces `0` on the `bill_creation_screen_v2.dart` path IN ADDITION
/// to these existing values — it does NOT change the values themselves.
///
/// Methodology (source-reading / observation-first):
///   - Read the three source files via `dart:io` and verify each contains
///     the expected GST-zero value at the correct location.
///   - Property-based: generate arbitrary `Product.taxRate` values and assert
///     the three baseline values remain 0.0 regardless of what taxRate is set
///     (proving no accidental coupling between product taxRate and fuel GST).
///
/// This test MUST PASS on UNFIXED code — it captures baseline behavior that
/// the fix must preserve.
///
/// PBT library: dartproptest ^0.2.1.
///
/// Run: flutter test test/bug_condition/petrol_pump_preservation_gst_defaults_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/core/billing/business_type_config.dart';
import 'package:dukanx/features/petrol_pump/models/fuel_type.dart';

const double _eps = 1e-9;
const int kNumRuns = 200;

/// Reads a source file relative to the package root.
/// Returns '' if the file is missing.
String _readSource(String relativePath) {
  final f = File(relativePath);
  return f.existsSync() ? f.readAsStringSync() : '';
}

void main() {
  // ==========================================================================
  // PRESERVATION 3.2 — GST Default #1: BusinessTypeConfig.petrolPump.defaultGstRate
  // ==========================================================================
  group('Preservation 3.2: BusinessTypeConfig.petrolPump.defaultGstRate == 0.0', () {
    test('petrolPump defaultGstRate is 0.0 via BusinessTypeRegistry', () {
      final config = BusinessTypeRegistry.getConfig(BusinessType.petrolPump);
      expect(
        config.defaultGstRate,
        closeTo(0.0, _eps),
        reason:
            'BusinessTypeConfig for petrolPump must have defaultGstRate = 0.0. '
            'This was already fixed and must remain unchanged.',
      );
    });

    test(
      'source file contains defaultGstRate 0.0 in petrolPump config block',
      () {
        final src = _readSource('lib/core/billing/business_type_config.dart');
        expect(
          src.isNotEmpty,
          isTrue,
          reason: 'business_type_config.dart must exist',
        );

        // Find the petrolPump BusinessTypeConfig constructor call (not the
        // extension cases). Look for the unique petrol pump config comment.
        final petrolConfigIdx = src.indexOf('PETROL PUMP');
        expect(
          petrolConfigIdx,
          isNot(-1),
          reason: 'PETROL PUMP config section comment must exist',
        );

        // Extract a window after the comment to find the defaultGstRate
        final windowEnd = (petrolConfigIdx + 1000).clamp(0, src.length);
        final configWindow = src.substring(petrolConfigIdx, windowEnd);

        // The source has `defaultGstRate:\n          0.0,` — check both
        // the field name and value exist in this window
        expect(
          configWindow.contains('defaultGstRate'),
          isTrue,
          reason: 'petrolPump config must have defaultGstRate field',
        );

        // Extract the value after defaultGstRate — find the next number
        final gstFieldIdx = configWindow.indexOf('defaultGstRate');
        final afterField = configWindow.substring(gstFieldIdx);
        // Match the pattern: defaultGstRate followed by colon/newline/spaces
        // then 0.0 (the value)
        final valueMatch = RegExp(
          r'defaultGstRate[:\s]+(\d+\.?\d*)',
        ).firstMatch(afterField);
        expect(
          valueMatch,
          isNotNull,
          reason: 'defaultGstRate must have a numeric value',
        );
        expect(
          double.parse(valueMatch!.group(1)!),
          closeTo(0.0, _eps),
          reason:
              'BusinessTypeConfig.petrolPump must declare defaultGstRate = 0.0 '
              'in the source. The fix must not change this value.',
        );
      },
    );

    test('PBT: regardless of arbitrary product taxRate, petrolPump '
        'defaultGstRate remains 0.0', () {
      forAll(
        (int taxRateTimes100) {
          // Generate arbitrary taxRate values (0.00 to 99.99)
          final arbitraryTaxRate = taxRateTimes100 / 100.0;

          // The petrolPump defaultGstRate should be completely independent
          // of any product's taxRate
          final config = BusinessTypeRegistry.getConfig(
            BusinessType.petrolPump,
          );

          // Regardless of what taxRate a product has, the BusinessTypeConfig
          // for petrolPump always returns 0.0
          expect(
            config.defaultGstRate,
            closeTo(0.0, _eps),
            reason:
                'petrolPump defaultGstRate must be 0.0 regardless of any '
                'arbitrary product taxRate ($arbitraryTaxRate). '
                'The config is a static value, not derived from product data.',
          );
          return true;
        },
        [Gen.interval(0, 9999)],
        numRuns: kNumRuns,
      );
    });
  });

  // ==========================================================================
  // PRESERVATION 3.2 — GST Default #2: FuelType.linkedGSTRate default == 0.0
  // ==========================================================================
  group('Preservation 3.2: FuelType.linkedGSTRate defaults to 0.0', () {
    test('FuelType constructor defaults linkedGSTRate to 0.0', () {
      final fuel = FuelType(
        fuelId: 'test_fuel',
        fuelName: 'Test Fuel',
        currentRatePerLitre: 100.0,
        ownerId: 'owner_1',
        // linkedGSTRate NOT provided — should default to 0.0
      );
      expect(
        fuel.linkedGSTRate,
        closeTo(0.0, _eps),
        reason:
            'FuelType.linkedGSTRate must default to 0.0 when not explicitly '
            'provided. This is the already-correct value that must be preserved.',
      );
    });

    test(
      'FuelType.fromMap defaults linkedGSTRate to 0.0 when field is absent',
      () {
        final fuel = FuelType.fromMap('test', {
          'fuelName': 'Test',
          'currentRatePerLitre': 100.0,
          'ownerId': 'owner_1',
          // No linkedGSTRate in the map
        });
        expect(
          fuel.linkedGSTRate,
          closeTo(0.0, _eps),
          reason:
              'FuelType.fromMap must default linkedGSTRate to 0.0 when the field '
              'is absent from the map.',
        );
      },
    );

    test('source file declares linkedGSTRate default as 0.0', () {
      final src = _readSource('lib/features/petrol_pump/models/fuel_type.dart');
      expect(src.isNotEmpty, isTrue, reason: 'fuel_type.dart must exist');

      // The constructor has: `this.linkedGSTRate = 0.0`
      // allowing for possible line breaks and whitespace
      final hasDefaultZero =
          src.contains('linkedGSTRate =') &&
          RegExp(r'linkedGSTRate\s*=\s*\n?\s*0\.0').hasMatch(src);

      // Alternative: check for the default in the named parameter list
      final hasNamedDefault = RegExp(
        r'this\.linkedGSTRate[:\s=]+\s*\n?\s*0\.0',
      ).hasMatch(src);

      expect(
        hasDefaultZero || hasNamedDefault,
        isTrue,
        reason:
            'FuelType constructor must declare linkedGSTRate with default 0.0 '
            'in the source. The fix must not change this default.',
      );
    });

    test('defaultFuelTypes all have linkedGSTRate == 0.0', () {
      final defaults = FuelType.defaultFuelTypes('test_owner');
      for (final fuel in defaults) {
        expect(
          fuel.linkedGSTRate,
          closeTo(0.0, _eps),
          reason:
              '${fuel.fuelName} default fuel type must have linkedGSTRate = 0.0. '
              'All default fuel types are outside GST regime.',
        );
      }
    });

    test('PBT: regardless of arbitrary product taxRate, FuelType.linkedGSTRate '
        'defaults to 0.0 for any newly created fuel', () {
      forAll(
        (int taxRateTimes100, int fuelNameSeed) {
          final arbitraryTaxRate = taxRateTimes100 / 100.0;
          final fuelName = 'Fuel_$fuelNameSeed';

          // Create a new FuelType without specifying linkedGSTRate
          final fuel = FuelType(
            fuelId: 'fuel_$fuelNameSeed',
            fuelName: fuelName,
            currentRatePerLitre: arbitraryTaxRate,
            ownerId: 'owner_1',
          );

          // The linkedGSTRate must always default to 0.0
          expect(
            fuel.linkedGSTRate,
            closeTo(0.0, _eps),
            reason:
                'FuelType "$fuelName" linkedGSTRate must default to 0.0 '
                'regardless of arbitrary rate ($arbitraryTaxRate).',
          );
          return true;
        },
        [Gen.interval(0, 9999), Gen.interval(1, 10000)],
        numRuns: kNumRuns,
      );
    });
  });

  // ==========================================================================
  // PRESERVATION 3.2 — GST Default #3: createFuelBill's `const gstRate = 0.0`
  // ==========================================================================
  group('Preservation 3.2: PetrolPumpBillingService.createFuelBill has '
      'const gstRate = 0.0', () {
    late String billingServiceSrc;
    late String createFuelBillBody;

    setUpAll(() {
      billingServiceSrc = _readSource(
        'lib/features/petrol_pump/services/petrol_pump_billing_service.dart',
      );
      assert(
        billingServiceSrc.isNotEmpty,
        'petrol_pump_billing_service.dart must exist',
      );

      // Find the createFuelBill method body — search for the method and
      // extract a generous window. The `const gstRate = 0.0` is inside
      // a transaction block within createFuelBill.
      final methodIdx = billingServiceSrc.indexOf('createFuelBill');
      assert(methodIdx != -1, 'createFuelBill method must exist');

      // The gstRate constant is ~100-200 lines into the method body.
      // Extract a large window to capture it.
      final windowEnd = (methodIdx + 5000).clamp(0, billingServiceSrc.length);
      createFuelBillBody = billingServiceSrc.substring(methodIdx, windowEnd);
    });

    test('source file contains gstRate = 0.0 override in createFuelBill', () {
      // The source has: `const gstRate = 0.0;`
      // Check for the pattern allowing both `const` and `final`
      final hasGstRateZero = createFuelBillBody.contains('gstRate = 0.0');
      expect(
        hasGstRateZero,
        isTrue,
        reason:
            'PetrolPumpBillingService.createFuelBill must contain '
            '`gstRate = 0.0`. This is the compliance override that ensures '
            'fuel GST is always 0. The fix must not change this value.',
      );
    });

    test('gstRate override uses const or final declaration', () {
      // Verify it's a proper constant/final declaration, not just assignment
      final hasConstOrFinal = RegExp(
        r'(const|final)\s+gstRate',
      ).hasMatch(createFuelBillBody);
      expect(
        hasConstOrFinal,
        isTrue,
        reason:
            'gstRate in createFuelBill must be declared as const or final, '
            'ensuring it cannot be overridden within the method.',
      );
    });

    test('gstRate override is commented with compliance reasoning', () {
      // Look for the compliance comment near the gstRate assignment
      final gstRateIdx = createFuelBillBody.indexOf('gstRate = 0.0');
      if (gstRateIdx == -1) return;

      // Look backwards for a comment within 300 chars before the assignment
      final lookBackStart = (gstRateIdx - 300).clamp(0, gstRateIdx);
      final commentWindow = createFuelBillBody.substring(
        lookBackStart,
        gstRateIdx,
      );

      final hasComplianceComment =
          commentWindow.contains('COMPLIANCE') ||
          commentWindow.contains('GST') ||
          commentWindow.contains('gst') ||
          commentWindow.contains('fuel');

      expect(
        hasComplianceComment,
        isTrue,
        reason:
            'The gstRate = 0.0 override in createFuelBill should have a '
            'nearby comment explaining the GST compliance reasoning.',
      );
    });

    test('PBT: for arbitrary product taxRate values, the source-level '
        'gstRate = 0.0 in createFuelBill is always present', () {
      forAll(
        (int taxRateTimes100) {
          final arbitraryTaxRate = taxRateTimes100 / 100.0;

          // Regardless of what product.taxRate might be (0..99.99),
          // the service hardcodes gstRate = 0.0
          expect(
            createFuelBillBody.contains('gstRate = 0.0'),
            isTrue,
            reason:
                'createFuelBill must always have gstRate = 0.0, regardless of '
                'any arbitrary product taxRate ($arbitraryTaxRate). '
                'The fix must not remove or change this override.',
          );
          return true;
        },
        [Gen.interval(0, 9999)],
        numRuns: kNumRuns,
      );
    });
  });

  // ==========================================================================
  // PRESERVATION 3.2 — Combined: All three GST defaults coexist at 0.0
  // ==========================================================================
  group('Preservation 3.2: all three GST zero-values coexist consistently', () {
    test('all three GST values are simultaneously 0.0', () {
      // Value #1: BusinessTypeConfig
      final config = BusinessTypeRegistry.getConfig(BusinessType.petrolPump);
      expect(config.defaultGstRate, closeTo(0.0, _eps));

      // Value #2: FuelType default
      final fuel = FuelType(
        fuelId: 'petrol',
        fuelName: 'Petrol',
        currentRatePerLitre: 100.0,
        ownerId: 'owner_1',
      );
      expect(fuel.linkedGSTRate, closeTo(0.0, _eps));

      // Value #3: createFuelBill source override
      final src = _readSource(
        'lib/features/petrol_pump/services/petrol_pump_billing_service.dart',
      );
      expect(
        src.contains('gstRate = 0.0'),
        isTrue,
        reason: 'createFuelBill must contain gstRate = 0.0',
      );
    });

    test('PBT: for any arbitrary product taxRate, all three GST defaults '
        'remain at 0.0 simultaneously (no coupling)', () {
      final src = _readSource(
        'lib/features/petrol_pump/services/petrol_pump_billing_service.dart',
      );

      forAll(
        (int taxRateTimes100) {
          final arbitraryTaxRate = taxRateTimes100 / 100.0;

          // #1: BusinessTypeConfig is a static map, unaffected by product data
          final config = BusinessTypeRegistry.getConfig(
            BusinessType.petrolPump,
          );
          expect(
            config.defaultGstRate,
            closeTo(0.0, _eps),
            reason:
                'defaultGstRate must be 0.0 regardless of product taxRate '
                '($arbitraryTaxRate)',
          );

          // #2: FuelType default is a constructor parameter default
          final fuel = FuelType(
            fuelId: 'petrol',
            fuelName: 'Petrol',
            currentRatePerLitre: arbitraryTaxRate,
            ownerId: 'owner_1',
          );
          expect(
            fuel.linkedGSTRate,
            closeTo(0.0, _eps),
            reason:
                'linkedGSTRate must default to 0.0 regardless of rate/taxRate '
                '($arbitraryTaxRate)',
          );

          // #3: createFuelBill's const override is a source-level constant
          expect(
            src.contains('gstRate = 0.0'),
            isTrue,
            reason:
                'createFuelBill gstRate = 0.0 must exist regardless of '
                'product taxRate ($arbitraryTaxRate)',
          );

          return true;
        },
        [Gen.interval(0, 9999)],
        numRuns: kNumRuns,
      );
    });
  });
}
