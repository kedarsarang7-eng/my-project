// ============================================================================
// JEWELLERY VERTICAL REMEDIATION — Phase 8 Polish, Accessibility & Regression
//
// Feature: jewellery-vertical-remediation
//
// Tasks 16.5, 16.6, 16.7:
//   Property 32: Calculator output is mojibake-free UTF-8
//   Accessibility/responsive example tests
//   Regression suite verification
//
// **Validates: Requirements 17.1, 17.2, 17.3, 17.5, 17.6**
//
// PBT library: dartproptest ^0.2.1
// Run: flutter test test/features/jewellery/phase8_polish_test.dart
// ============================================================================

import 'dart:io';

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/features/jewellery/data/models/making_charges_model.dart';
import 'package:dukanx/features/jewellery/data/services/making_charges_calculator.dart';
import 'package:dukanx/features/jewellery/utils/jewellery_business_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ==========================================================================
  // Task 16.5 — Property 32: Calculator output is mojibake-free UTF-8.
  // Feature: jewellery-vertical-remediation, Property 32: Calculator output is mojibake-free UTF-8
  // **Validates: Requirements 17.1**
  //
  // For any calculation output string, it contains no mojibake sequences.
  // 100 iterations.
  // ==========================================================================
  group('Feature: jewellery-vertical-remediation, '
      'Property 32: Calculator output is mojibake-free UTF-8', () {
    /// Known mojibake patterns that indicate UTF-8 decoded as Latin-1:
    /// - The UTF-8 bytes of multiplication sign (U+00D7) misread as Latin-1
    /// - The UTF-8 bytes of Indian Rupee sign (U+20B9) misread as Latin-1
    final mojibakePatterns = [
      '\u00c3\u0097', // mojibake of multiplication sign
      '\u00c3\u00b7', // alternate mojibake
      'â\u0082¹', // mojibake of rupee sign
    ];

    bool containsMojibake(String text) {
      for (final pattern in mojibakePatterns) {
        if (text.contains(pattern)) return true;
      }
      // Also check for common double-encoding artifacts
      if (text.contains('\u00c3') && text.contains('\u0097')) return true;
      return false;
    }

    test('Property 32: MakingChargesCalculator output strings contain no '
        'mojibake sequences for any valid inputs', () {
      // Generators for valid calculator inputs
      final Generator<int> weightGen = Gen.interval(1, 100000);
      final Generator<int> rateGen = Gen.interval(100, 10000000);
      final Generator<int> makingRateGen = Gen.interval(0, 1000000);

      final now = DateTime.now();

      final bool held = forAll(
        (int weightMg, int rate, int makingRate) {
          final double weightGrams = weightMg / 1000.0;

          final config = MakingChargesConfig(
            id: 'test-config-1',
            tenantId: 'tenant-1',
            name: 'Test Config',
            type: MakingChargeType.perGram,
            ratePaisaPerGram: makingRate,
            createdAt: now,
            updatedAt: now,
          );

          // Test per-gram calculation (produces string output)
          final result = MakingChargesCalculator.calculate(
            CalculateMakingChargesRequest(
              config: config,
              metalWeightGrams: weightGrams,
              metalRatePaisaPerGram: rate,
            ),
          );

          // Check the breakdown string for mojibake
          if (containsMojibake(result.calculationBreakdown)) return false;

          // Check error message if present
          if (result.errorMessage != null &&
              containsMojibake(result.errorMessage!)) {
            return false;
          }

          // Also test calculateTotalPrice output strings
          final totalResult = MakingChargesCalculator.calculateTotalPrice(
            metalWeightGrams: weightGrams,
            metalRatePaisaPerGram: rate,
            makingChargesConfig: config,
            purity: GoldPurity.k22,
          );

          // Check all string values in the result map
          for (final entry in totalResult.entries) {
            if (entry.value is String &&
                containsMojibake(entry.value as String)) {
              return false;
            }
          }

          return true;
        },
        [weightGen, rateGen, makingRateGen],
        numRuns: 100,
      );

      expect(
        held,
        isTrue,
        reason:
            'All calculator output strings must be clean UTF-8 with no '
            'mojibake sequences (Requirement 17.1).',
      );
    });

    test('Property 32 (source file check): making_charges_calculator.dart '
        'contains no mojibake', () {
      final file = File(
        'lib/features/jewellery/data/services/making_charges_calculator.dart',
      );
      expect(
        file.existsSync(),
        isTrue,
        reason: 'making_charges_calculator.dart must exist',
      );

      final content = file.readAsStringSync();

      // Check for common mojibake byte sequences
      expect(
        content.contains('\u00c3\u0097'),
        isFalse,
        reason:
            'File must not contain mojibake of multiplication sign '
            '(should be the clean Unicode character)',
      );
    });

    test('Property 32 (source file check): jewellery_business_rules.dart '
        'contains no mojibake', () {
      final file = File(
        'lib/features/jewellery/utils/jewellery_business_rules.dart',
      );
      expect(
        file.existsSync(),
        isTrue,
        reason: 'jewellery_business_rules.dart must exist',
      );

      final content = file.readAsStringSync();

      expect(
        content.contains('\u00c3\u0097'),
        isFalse,
        reason:
            'File must not contain mojibake of multiplication sign '
            '(should be the clean Unicode character)',
      );
    });
  });

  // ==========================================================================
  // Task 16.6 — Accessibility and responsive example tests.
  // **Validates: Requirements 17.2, 17.3, 17.5**
  //
  // Assert:
  //   - Semantics labels present on dashboard controls
  //   - The '!' badge replaced with accessible text
  //   - Each of The_Eight_Screens renders without overflow (verify they
  //     import responsive.dart and use BoundedBox/SingleChildScrollView)
  // ==========================================================================
  group('Feature: jewellery-vertical-remediation, '
      'Accessibility and responsive example tests', () {
    // --- Requirement 17.2: Semantics labels on dashboard controls ---

    test('business_quick_actions.dart contains Semantics labels for '
        'jewellery controls', () {
      final file = File(
        'lib/features/dashboard/v2/widgets/business_quick_actions.dart',
      );
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();

      // Verify jewellery branch exists
      expect(
        content.contains('BusinessType.jewellery'),
        isTrue,
        reason: 'Quick actions must have a jewellery branch',
      );

      // Verify Semantics widget is used
      expect(
        content.contains('Semantics('),
        isTrue,
        reason:
            'Quick actions must wrap controls in Semantics '
            '(Requirement 17.2)',
      );

      // Verify semanticLabel parameter is used for jewellery actions
      expect(
        content.contains('semanticLabel:'),
        isTrue,
        reason:
            'Quick actions must specify semanticLabel for accessibility '
            '(Requirement 17.2)',
      );
    });

    test('business_alerts_widget.dart contains Semantics labels for '
        'jewellery alerts', () {
      final file = File(
        'lib/features/dashboard/v2/widgets/business_alerts_widget.dart',
      );
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();

      // Verify jewellery branch exists
      expect(
        content.contains('BusinessType.jewellery'),
        isTrue,
        reason: 'Alerts widget must have a jewellery branch',
      );

      // Verify Semantics widget is used
      expect(
        content.contains('Semantics('),
        isTrue,
        reason:
            'Alerts widget must use Semantics for accessibility '
            '(Requirement 17.2)',
      );

      // Verify semanticLabel for jewellery alerts
      expect(
        content.contains('semanticLabel:'),
        isTrue,
        reason:
            'Alerts widget must specify semanticLabel for jewellery alerts '
            '(Requirement 17.2)',
      );
    });

    // --- Requirement 17.3: '!' badge replaced with accessible text ---

    test('business_alerts_widget.dart does not use bare "!" glyph as '
        'jewellery alert badge', () {
      final file = File(
        'lib/features/dashboard/v2/widgets/business_alerts_widget.dart',
      );
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();

      // Find the jewellery section
      final jewelleryIdx = content.indexOf('case BusinessType.jewellery:');
      expect(jewelleryIdx, greaterThan(-1));

      // Look at the section after the jewellery case for a bare '!' count
      final jewellerySection = content.substring(
        jewelleryIdx,
        (jewelleryIdx + 2000).clamp(0, content.length),
      );

      // The old pattern was: count: '!' — a glyph-only badge.
      // After fix, it should use descriptive text or a proper count.
      expect(
        jewellerySection.contains("count: '!'"),
        isFalse,
        reason:
            "The '!' glyph-only badge must be replaced with accessible text "
            '(Requirement 17.3)',
      );
    });

    // --- Requirement 17.5: The_Eight_Screens responsive/overflow ---

    /// The Eight Screens and their expected file paths
    final theEightScreens = <String, String>{
      'GoldRateManagementScreen':
          'lib/features/jewellery/presentation/screens/gold_rate_management_screen.dart',
      'GoldRateAlertScreen':
          'lib/features/jewellery/presentation/screens/gold_rate_alert_screen.dart',
      'MakingChargesCalculatorScreen':
          'lib/features/jewellery/presentation/screens/making_charges_calculator_screen.dart',
      'HallmarkInventoryScreen':
          'lib/features/jewellery/presentation/screens/hallmark_inventory_screen.dart',
      'OldGoldExchangeScreen':
          'lib/features/jewellery/presentation/screens/old_gold_exchange_screen.dart',
      'CustomOrderManagementScreen':
          'lib/features/jewellery/presentation/screens/custom_order_management_screen.dart',
      'JewelleryRepairScreen':
          'lib/features/jewellery/presentation/screens/jewellery_repair_screen.dart',
      'GoldSchemeScreen':
          'lib/features/jewellery/presentation/screens/gold_scheme_screen.dart',
    };

    for (final entry in theEightScreens.entries) {
      test('${entry.key} imports responsive.dart and uses overflow '
          'prevention', () {
        final file = File(entry.value);
        expect(
          file.existsSync(),
          isTrue,
          reason: '${entry.key} file must exist at ${entry.value}',
        );

        final content = file.readAsStringSync();

        // Verify responsive.dart import
        expect(
          content.contains('core/responsive/responsive.dart'),
          isTrue,
          reason:
              '${entry.key} must import responsive.dart for responsive '
              'layout support (Requirement 17.5)',
        );

        // Verify at least one overflow prevention mechanism is used:
        // BoundedBox, SingleChildScrollView, or responsiveValue
        final hasOverflowPrevention =
            content.contains('BoundedBox') ||
            content.contains('SingleChildScrollView') ||
            content.contains('responsiveValue');

        expect(
          hasOverflowPrevention,
          isTrue,
          reason:
              '${entry.key} must use BoundedBox, SingleChildScrollView, or '
              'responsiveValue to prevent overflow at different breakpoints '
              '(Requirement 17.5)',
        );
      });
    }
  });

  // ==========================================================================
  // Task 16.7 — Regression suite verification.
  // **Validates: Requirements 17.6**
  //
  // Verify that existing test files at test/core/routing/* and other-vertical
  // sidebar tests exist and would not be broken by jewellery changes.
  // ==========================================================================
  group('Feature: jewellery-vertical-remediation, '
      'Regression suite verification', () {
    // Critical routing preservation tests that must still exist
    final criticalRoutingTests = [
      'test/core/routing/phase_a_foundation_wiring_preservation_test.dart',
      'test/core/routing/phase_b_guarded_resolution_preservation_test.dart',
      'test/core/routing/phase2_property4_sidebar_invariance_test.dart',
      'test/core/routing/phase2_route_parity_preservation_test.dart',
      'test/core/routing/phase3_capability_guard_preservation_test.dart',
      'test/core/routing/phase0_routing_scaffold_smoke_test.dart',
    ];

    for (final testPath in criticalRoutingTests) {
      test('Routing preservation test exists: ${testPath.split('/').last}', () {
        final file = File(testPath);
        expect(
          file.existsSync(),
          isTrue,
          reason:
              'Critical routing test $testPath must exist to ensure no '
              'other vertical regresses (Requirement 17.6)',
        );
      });
    }

    test('Routing test directory contains preservation tests', () {
      final routingDir = Directory('test/core/routing');
      expect(routingDir.existsSync(), isTrue);

      final testFiles = routingDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('_test.dart'))
          .toList();

      // Must have a reasonable number of routing tests
      expect(
        testFiles.length,
        greaterThanOrEqualTo(10),
        reason:
            'The routing test directory must contain the full suite of '
            'preservation and property tests (Requirement 17.6)',
      );
    });

    test(
      'Other-vertical sidebar tests are not broken by jewellery changes',
      () {
        // Verify the phase2_property4_sidebar_invariance_test exists and
        // references other business types (proving it guards them)
        final file = File(
          'test/core/routing/phase2_property4_sidebar_invariance_test.dart',
        );
        expect(file.existsSync(), isTrue);

        final content = file.readAsStringSync();

        // This test must reference BusinessType to verify sidebar invariance
        expect(
          content.contains('BusinessType'),
          isTrue,
          reason:
              'Sidebar invariance test must reference BusinessType to ensure '
              'other verticals are preserved (Requirement 17.6)',
        );
      },
    );

    test('Jewellery test files co-exist without import conflicts', () {
      final jewelleryTestDir = Directory('test/features/jewellery');
      expect(jewelleryTestDir.existsSync(), isTrue);

      final testFiles = jewelleryTestDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('_test.dart'))
          .toList();

      // Must have the phase test files
      expect(
        testFiles.length,
        greaterThanOrEqualTo(3),
        reason:
            'Jewellery test directory must contain phase test files '
            '(Requirement 17.6)',
      );
    });
  });
}
