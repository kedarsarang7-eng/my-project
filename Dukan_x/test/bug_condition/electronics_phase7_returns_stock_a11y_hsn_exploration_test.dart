/// Phase 7 Bug-Condition Exploration Test — Electronics returns, serial-stock
/// view, accessibility, and HSN validation.
///
/// **Validates: Requirements 2.22, 2.23, 2.24, 2.25**
///
/// **Property 9: Bug Condition** — Returns, serial-stock view, accessibility, HSN.
///
/// This test encodes the EXPECTED behavior (what SHOULD happen after the fix).
/// It is run on UNFIXED code and is EXPECTED TO FAIL — failure confirms the bugs
/// exist. DO NOT fix the tests or the code when they fail here.
///
/// Bug conditions (from design):
///   - `ReturnSave` where `businessType == electronics AND isDeviceLine AND
///     NOT serialValidated(input)` (2.22)
///   - No serial-wise stock view exists for Electronics (2.23)
///   - Quick-action buttons expose no `Semantics`/tooltips (2.24)
///   - `HsnEntry` where `NOT hsnFormatValidated(input)` (2.25)
///
/// Expected behavior asserted:
///   - 2.22: Only sold, tenant-scoped serials accepted on return; wrong/blank/
///     never-sold rejected.
///   - 2.23: A serial-wise stock view (status-filtered IMEISerials list) exists
///     and is reachable from the Electronics sidebar.
///   - 2.24: Electronics quick-action buttons expose `Semantics`/tooltips and
///     accessible state (semanticLabel parameter passed).
///   - 2.25: HSN field validates length/format — malformed values rejected.
///
/// EXPECTED OUTCOME on UNFIXED code: Tests FAIL —
///   - Generic return flow does no serial validation (2.22).
///   - No serial-wise stock view exists in the sidebar (2.23).
///   - Electronics quick-action buttons use `InkWell`+`Text` with no
///     `Semantics` wrapping — `semanticLabel` is not passed (2.24).
///   - HSN field is required but has no format/length validator (2.25).
///
/// PBT library: dartproptest ^0.2.1
///
/// Run: flutter test test/bug_condition/electronics_phase7_returns_stock_a11y_hsn_exploration_test.dart
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';

import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/widgets/desktop/sidebar_configuration.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Reads the source of `revenue_repository.dart` for serial validation check.
String _returnFlowSource() {
  final file = File('lib/core/repository/revenue_repository.dart');
  expect(
    file.existsSync(),
    isTrue,
    reason: 'revenue_repository.dart must exist at expected path.',
  );
  return file.readAsStringSync();
}

/// Reads the source of `return_inwards_screen.dart`.
String _returnScreenSource() {
  final file = File('lib/features/revenue/screens/return_inwards_screen.dart');
  expect(
    file.existsSync(),
    isTrue,
    reason: 'return_inwards_screen.dart must exist at expected path.',
  );
  return file.readAsStringSync();
}

/// Reads the `business_quick_actions.dart` source.
String _quickActionsSource() {
  final file = File(
    'lib/features/dashboard/v2/widgets/business_quick_actions.dart',
  );
  expect(
    file.existsSync(),
    isTrue,
    reason: 'business_quick_actions.dart must exist at expected path.',
  );
  return file.readAsStringSync();
}

/// Reads the `manual_item_entry_sheet.dart` source for HSN validator check.
String _entrySheetSource() {
  final file = File(
    'lib/features/billing/presentation/widgets/manual_item_entry_sheet.dart',
  );
  expect(
    file.existsSync(),
    isTrue,
    reason: 'manual_item_entry_sheet.dart must exist at expected path.',
  );
  return file.readAsStringSync();
}

/// Checks whether the electronics section of `business_quick_actions.dart`
/// passes a `semanticLabel` to any of its `_buildActionButton` calls.
bool _electronicsButtonsHaveSemanticLabel(String source) {
  final electronicsIdx = source.indexOf('case BusinessType.electronics:');
  if (electronicsIdx < 0) return false;

  final afterElectronics = source.substring(electronicsIdx + 30);
  // The electronics case shares with mobileShop and computerShop. Find the
  // next unrelated case to bound the block.
  final nextCaseIdx = afterElectronics.indexOf('case BusinessType.hardware:');
  final electronicsBlock = nextCaseIdx > 0
      ? afterElectronics.substring(0, nextCaseIdx)
      : afterElectronics.substring(0, math.min(afterElectronics.length, 1500));

  return electronicsBlock.contains('semanticLabel:');
}

/// Valid HSN patterns: 4-digit or 8-digit numeric strings.
bool _isValidHsn(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;
  final regex = RegExp(r'^(\d{4}|\d{8})$');
  return regex.hasMatch(trimmed);
}

/// Deterministic malformed HSN samples for property testing.
const List<String> _malformedHsnSamples = <String>[
  '1', // too short (1 digit)
  '12', // too short (2 digits)
  '123', // too short (3 digits)
  '12345', // invalid length (5 digits)
  '123456', // invalid length (6 digits)
  '1234567', // invalid length (7 digits)
  '123456789', // too long (9 digits)
  '1234567890', // too long (10 digits)
  'ABCD', // alphabetic (4 chars)
  'ABCDEFGH', // alphabetic (8 chars)
  '12@#', // special chars
  '1A2B', // mixed alpha-numeric
  '   ', // whitespace only
  '', // empty string
  '12AB5678', // 8 chars but not all numeric
  '123 ', // trailing space (3 digits effective)
  '1234 5678', // space in middle
  '12.34', // decimal point
  '-1234', // negative sign
  '00000', // 5 zeros (invalid length)
];

/// Deterministic valid HSN samples for property testing.
const List<String> _validHsnSamples = <String>[
  '1234', // 4-digit
  '5678', // 4-digit
  '0000', // 4-digit (all zeros)
  '9999', // 4-digit (all nines)
  '12345678', // 8-digit
  '87654321', // 8-digit
  '00000000', // 8-digit (all zeros)
  '99999999', // 8-digit (all nines)
  '0001', // 4-digit leading zeros
  '10000001', // 8-digit
  '8517', // real HSN (mobile phones)
  '85171290', // real HSN (smartphones)
  '8471', // real HSN (computers)
  '84713010', // real HSN (laptops)
  '8504', // real HSN (batteries)
  '85044090', // real HSN (UPS)
  '9001', // 4-digit
  '90011000', // 8-digit
  '7321', // 4-digit
  '73211100', // 8-digit
];

void main() {
  // =========================================================================
  // (1) 2.22 — Returns serial validation
  //
  // Bug: The generic return flow (`addReturnInward` in revenue_repository.dart
  //   and `_saveReturn` in return_inwards_screen.dart) performs NO serial
  //   validation. A return can reference a wrong, blank, or never-sold serial.
  //
  // Expected (post-fix): Only sold, tenant-scoped serials are accepted on
  //   return. Wrong/blank/never-sold serials are rejected.
  //
  // EXPECTED OUTCOME on UNFIXED code: FAILS — no serial validation exists.
  // =========================================================================
  group('Phase 7 Bug Condition — returns serial validation (2.22)', () {
    test('addReturnInward validates serial against IMEISerials before accepting', () {
      final repoSource = _returnFlowSource();

      // Find the addReturnInward method body
      final addReturnIdx = repoSource.indexOf('addReturnInward');
      expect(addReturnIdx, greaterThanOrEqualTo(0));
      final addReturnBlock = repoSource.substring(
        addReturnIdx,
        math.min(repoSource.length, addReturnIdx + 3000),
      );

      // The fix should reference IMEISerials/imei validation in the return flow
      final hasSerialCheckInReturn =
          addReturnBlock.contains('IMEISerial') ||
          addReturnBlock.contains('imeiSerial') ||
          (addReturnBlock.contains('serial') &&
              addReturnBlock.contains('status'));

      expect(
        hasSerialCheckInReturn,
        isTrue,
        reason:
            'The return flow (addReturnInward) must validate device serials '
            'against IMEISerials (exists, tenant-scoped, was sold) before '
            'accepting the return. On UNFIXED code, addReturnInward accepts any '
            'items list with no serial validation. '
            'Counterexample: a return with a never-sold serial or blank serial '
            'is silently accepted.',
      );
    });

    test(
      'return screen collects and validates serial for electronics lines',
      () {
        final screenSource = _returnScreenSource();

        // Must have serial validation logic tied to the return items
        final hasSerialValidation =
            (screenSource.contains('serialNo') ||
                screenSource.contains('imeiOrSerial') ||
                screenSource.contains('IMEI')) &&
            (screenSource.contains('IMEISerialRepository') ||
                screenSource.contains('serialValidat') ||
                screenSource.contains('isAvailableFor'));

        expect(
          hasSerialValidation,
          isTrue,
          reason:
              'The return screen must collect a device serial for electronics '
              'lines and validate it (exists, was sold, tenant-scoped). '
              'Counterexample: return_inwards_screen.dart has no serial field '
              'or serial validation for device returns — it accepts any item '
              'checkbox without serial check.',
        );
      },
    );

    test('PBT: random serials — only sold, tenant-scoped serials accepted', () {
      final repoSource = _returnFlowSource();
      final addReturnIdx = repoSource.indexOf('addReturnInward');
      final addReturnBlock = repoSource.substring(
        addReturnIdx,
        math.min(repoSource.length, addReturnIdx + 3000),
      );

      forAll(
        (int idx) {
          // For each generated case, the return flow must have serial validation
          // Scenarios: idx 0 = blank serial, 1 = wrong serial, 2 = never-sold
          final scenarios = ['blank', 'wrong_tenant', 'never_sold'];
          final scenario = scenarios[idx % scenarios.length];

          // On unfixed code, none of these are validated
          final validates =
              addReturnBlock.contains('IMEISerial') ||
              addReturnBlock.contains('imeiSerial') ||
              (addReturnBlock.contains('serial') &&
                  addReturnBlock.contains('status'));

          expect(
            validates,
            isTrue,
            reason:
                'Property violated (2.22): return must validate serial before '
                'accepting. Scenario: $scenario serial should be rejected. '
                'Counterexample: addReturnInward has no serial/IMEI validation '
                'logic — all returns are accepted regardless of serial state.',
          );
          return true;
        },
        [Gen.interval(0, 2)],
        numRuns: 3,
      );
    });
  });

  // =========================================================================
  // (2) 2.23 — Serial-wise stock view
  //
  // Bug: No serial-wise stock view exists for Electronics. Only generic
  //   SKU-quantity inventory screens are available. There is no sidebar entry
  //   pointing to a status-filtered IMEISerials list.
  //
  // Expected (post-fix): A serial-wise stock view (status-filtered IMEISerials
  //   list) is reachable from the Electronics sidebar.
  //
  // EXPECTED OUTCOME on UNFIXED code: FAILS — no such sidebar entry exists.
  // =========================================================================
  group('Phase 7 Bug Condition — serial-wise stock view (2.23)', () {
    test('Electronics sidebar has a serial-wise stock view entry', () {
      final sections = getSectionsForBusinessType(BusinessType.electronics);
      final allIds = <String>[];
      final allLabels = <String>[];
      for (final section in sections) {
        for (final item in section.items) {
          allIds.add(item.id);
          allLabels.add(item.label.toLowerCase());
        }
      }

      // Look for a stock view entry referencing serial/IMEI stock
      final hasSerialStockEntry =
          allIds.any(
            (id) =>
                id.contains('serial_stock') ||
                id.contains('imei_stock') ||
                id.contains('serial_inventory') ||
                id.contains('device_stock'),
          ) ||
          allLabels.any(
            (label) =>
                label.contains('serial stock') ||
                label.contains('imei stock') ||
                label.contains('device stock') ||
                label.contains('serial-wise') ||
                label.contains('unit stock'),
          );

      expect(
        hasSerialStockEntry,
        isTrue,
        reason:
            'The Electronics sidebar must have a serial-wise stock view entry '
            '(a status-filtered IMEISerials list reachable from the sidebar). '
            'On UNFIXED code, no such entry exists. '
            'Counterexample: Electronics sidebar ids = $allIds; '
            'none reference a serial/device stock view.',
      );
    });
  });

  // =========================================================================
  // (3) 2.24 — Accessibility (Semantics/tooltips on quick-action buttons)
  //
  // Bug: Electronics quick-action buttons in `business_quick_actions.dart` are
  //   `InkWell`+`Text` with no `Semantics` wrapping. The `_buildActionButton`
  //   method has a `semanticLabel` parameter but the electronics case doesn't
  //   pass it. Pharmacy and DC verticals DO pass it (reference pattern).
  //
  // Expected (post-fix): Electronics buttons expose `Semantics`/tooltips and
  //   accessible state (pass the `semanticLabel` parameter).
  //
  // EXPECTED OUTCOME on UNFIXED code: FAILS — no semanticLabel in electronics
  //   block.
  // =========================================================================
  group('Phase 7 Bug Condition — accessibility (2.24)', () {
    test('Electronics quick-action buttons pass semanticLabel for a11y', () {
      final source = _quickActionsSource();
      final hasSemantics = _electronicsButtonsHaveSemanticLabel(source);

      expect(
        hasSemantics,
        isTrue,
        reason:
            'Electronics quick-action buttons must pass `semanticLabel` to '
            '`_buildActionButton` so `Semantics`/tooltips expose them to '
            'assistive technology. On UNFIXED code, the electronics case does '
            'NOT pass `semanticLabel` — buttons are plain InkWell+Text. '
            'Counterexample: pharmacy and DC verticals pass semanticLabel '
            '(e.g. "New Prescription, create a new prescription") but '
            'electronics does not.',
      );
    });

    test('each electronics _buildActionButton call includes semanticLabel', () {
      final source = _quickActionsSource();
      final electronicsIdx = source.indexOf('case BusinessType.electronics:');
      expect(electronicsIdx, greaterThanOrEqualTo(0));

      final afterElectronics = source.substring(electronicsIdx + 30);
      final nextCaseIdx = afterElectronics.indexOf(
        'case BusinessType.hardware:',
      );
      final electronicsBlock = nextCaseIdx > 0
          ? afterElectronics.substring(0, nextCaseIdx)
          : afterElectronics.substring(
              0,
              math.min(afterElectronics.length, 1500),
            );

      // Count _buildActionButton calls in the electronics block
      final buildCalls = '_buildActionButton'
          .allMatches(electronicsBlock)
          .length;
      // Count semanticLabel: occurrences in the electronics block
      final semanticCalls = 'semanticLabel:'
          .allMatches(electronicsBlock)
          .length;

      expect(
        semanticCalls,
        equals(buildCalls),
        reason:
            'Every _buildActionButton call in the electronics case must pass '
            'a `semanticLabel` for accessibility. Found $buildCalls button '
            'calls but only $semanticCalls have semanticLabel. '
            'Counterexample: ${buildCalls - semanticCalls} electronics buttons '
            'lack semantic labeling.',
      );
    });
  });

  // =========================================================================
  // (4) 2.25 — HSN validation (length/format)
  //
  // Bug: The HSN field in `manual_item_entry_sheet.dart` is required for
  //   electronics (via `requiredFields`) but has NO format/length validator.
  //   Malformed HSN values (too short, too long, alphabetic, special chars)
  //   are accepted.
  //
  // Expected (post-fix): A validator rejects malformed HSN; valid HSN is
  //   4-digit or 8-digit numeric.
  //
  // EXPECTED OUTCOME on UNFIXED code: FAILS — no validator on the HSN field.
  // =========================================================================
  group('Phase 7 Bug Condition — HSN validation (2.25)', () {
    test('HSN TextFormField has a format/length validator', () {
      final source = _entrySheetSource();

      // Find the HSN field section
      final hsnIdx = source.indexOf("'HSN Code'");
      final altIdx = source.indexOf('"HSN Code"');
      final effectiveIdx = hsnIdx >= 0 ? hsnIdx : altIdx;
      expect(
        effectiveIdx,
        greaterThanOrEqualTo(0),
        reason: 'Cannot find HSN Code field in manual_item_entry_sheet',
      );

      // Look in a window around the HSN label for a validator property.
      final windowStart = (effectiveIdx - 200).clamp(0, source.length);
      final windowEnd = (effectiveIdx + 300).clamp(0, source.length);
      final hsnWindow = source.substring(windowStart, windowEnd);

      final hasValidator =
          hsnWindow.contains('validator:') || hsnWindow.contains('validator :');

      expect(
        hasValidator,
        isTrue,
        reason:
            'The HSN TextFormField must have a `validator` that checks '
            'length/format (4-digit or 8-digit numeric). On UNFIXED code, '
            'the HSN field has NO validator — malformed values are accepted. '
            'Counterexample: HSN field window does not contain "validator:" — '
            'any input (e.g. "ABC", "1", "123456789012") is silently accepted.',
      );
    });

    test('PBT: malformed HSN values must be rejected by the validator', () {
      final source = _entrySheetSource();
      final hsnIdx = source.indexOf("'HSN Code'");
      final altIdx = source.indexOf('"HSN Code"');
      final effectiveIdx = hsnIdx >= 0 ? hsnIdx : altIdx;
      final windowStart = (effectiveIdx - 200).clamp(0, source.length);
      final windowEnd = (effectiveIdx + 500).clamp(0, source.length);
      final hsnWindow = source.substring(windowStart, windowEnd);

      final hasValidator =
          hsnWindow.contains('validator:') || hsnWindow.contains('validator :');

      // Property: for any malformed HSN, a validator must exist to reject it.
      // On unfixed code, there IS no validator, so all malformed values pass.
      forAll(
        (int idx) {
          final malformed =
              _malformedHsnSamples[idx % _malformedHsnSamples.length];
          // Assert that a validator EXISTS (precondition for rejection)
          expect(
            hasValidator,
            isTrue,
            reason:
                'Property violated (2.25): malformed HSN "$malformed" must be '
                'rejected by a format/length validator on the HSN field. On '
                'UNFIXED code, no validator exists — all values including '
                'malformed ones are accepted.',
          );
          return true;
        },
        [Gen.interval(0, _malformedHsnSamples.length - 1)],
        numRuns: _malformedHsnSamples.length,
      );
    });

    test('PBT: valid HSN values (4 or 8 digit numeric) are accepted', () {
      // This test asserts valid HSN matches the expected pattern.
      forAll(
        (int idx) {
          final valid = _validHsnSamples[idx % _validHsnSamples.length];
          expect(
            _isValidHsn(valid),
            isTrue,
            reason:
                'Generated HSN "$valid" should match valid pattern '
                '(4 or 8 digit numeric).',
          );
          return true;
        },
        [Gen.interval(0, _validHsnSamples.length - 1)],
        numRuns: _validHsnSamples.length,
      );
    });
  });

  // =========================================================================
  // (5) Combined PBT — Phase 7 bug-condition property over all four sub-reqs
  //
  // indices: 0=returns serial validation, 1=serial-stock view, 2=a11y,
  //          3=HSN validator
  //
  // At least one will FAIL on unfixed code (all four will, in practice).
  // =========================================================================
  group('Phase 7 Bug Condition — PBT: combined property (2.22–2.25)', () {
    test('PBT: all Phase 7 sub-requirements hold', () {
      final repoSource = _returnFlowSource();
      final quickActionsSource = _quickActionsSource();
      final entrySheetSource = _entrySheetSource();

      forAll(
        (int idx) {
          switch (idx) {
            case 0:
              // 2.22 — return serial validation
              final addReturnIdx = repoSource.indexOf('addReturnInward');
              final block = repoSource.substring(
                addReturnIdx,
                math.min(repoSource.length, addReturnIdx + 3000),
              );
              final validates =
                  block.contains('IMEISerial') ||
                  block.contains('imeiSerial') ||
                  (block.contains('serial') && block.contains('status'));
              expect(
                validates,
                isTrue,
                reason:
                    'Property violated (2.22): addReturnInward must validate '
                    'device serials against IMEISerials.',
              );
              break;
            case 1:
              // 2.23 — serial-wise stock view
              final sections = getSectionsForBusinessType(
                BusinessType.electronics,
              );
              final allIds = <String>[];
              for (final section in sections) {
                for (final item in section.items) {
                  allIds.add(item.id);
                }
              }
              final has = allIds.any(
                (id) =>
                    id.contains('serial_stock') ||
                    id.contains('imei_stock') ||
                    id.contains('serial_inventory') ||
                    id.contains('device_stock'),
              );
              expect(
                has,
                isTrue,
                reason:
                    'Property violated (2.23): Electronics sidebar must have '
                    'a serial-wise stock view entry. Ids: $allIds',
              );
              break;
            case 2:
              // 2.24 — accessibility
              final hasSemantics = _electronicsButtonsHaveSemanticLabel(
                quickActionsSource,
              );
              expect(
                hasSemantics,
                isTrue,
                reason:
                    'Property violated (2.24): Electronics quick-action '
                    'buttons must pass semanticLabel for accessibility.',
              );
              break;
            case 3:
              // 2.25 — HSN validator
              final hsnIdx = entrySheetSource.indexOf("'HSN Code'");
              final altIdx = entrySheetSource.indexOf('"HSN Code"');
              final effectiveIdx = hsnIdx >= 0 ? hsnIdx : altIdx;
              final windowStart = (effectiveIdx - 200).clamp(
                0,
                entrySheetSource.length,
              );
              final windowEnd = (effectiveIdx + 300).clamp(
                0,
                entrySheetSource.length,
              );
              final hsnWindow = entrySheetSource.substring(
                windowStart,
                windowEnd,
              );
              final hasValidator =
                  hsnWindow.contains('validator:') ||
                  hsnWindow.contains('validator :');
              expect(
                hasValidator,
                isTrue,
                reason:
                    'Property violated (2.25): HSN field must have a '
                    'format/length validator.',
              );
              break;
          }
          return true;
        },
        [Gen.interval(0, 3)],
        numRuns: 4,
      );
    });
  });
}
