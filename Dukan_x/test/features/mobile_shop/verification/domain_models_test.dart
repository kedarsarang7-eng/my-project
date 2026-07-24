// ============================================================================
// MOBILE SHOP — DOMAIN MODELS UNIT TESTS
// ============================================================================
// Comprehensive unit tests for domain models, validators, and policies.
// Covers IMEI validation, device lifecycle transitions, warranty calculation,
// and monetary validation.
//
// **Validates: Requirements 1.3–1.4, 3.1–3.12, 4.1–4.9, 5.2–5.7, 13.1–13.2**
//
// Run: flutter test test/features/mobile_shop/verification/domain_models_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/features/mobile_shop/domain/device_lifecycle.dart';
import 'package:dukanx/features/mobile_shop/domain/imei_validator.dart';
import 'package:dukanx/features/mobile_shop/domain/monetary_validator.dart';
import 'package:dukanx/features/mobile_shop/domain/warranty_validator.dart';

// ─── Test Data ───────────────────────────────────────────────────────────────

/// Known valid IMEI (passes Luhn checksum).
const _validImei = '356938035643809';

/// Simple unit stub implementing TransitionableUnit for lifecycle tests.
class _TestUnit implements TransitionableUnit {
  @override
  final DeviceLifecycleState lifecycleState;
  @override
  final int version;

  const _TestUnit({required this.lifecycleState, required this.version});
}

// ─── Main Test Suite ─────────────────────────────────────────────────────────

void main() {
  // ==========================================================================
  // GROUP 1: IMEI Validator — Deterministic Precedence
  // ==========================================================================
  group('IMEI validator — deterministic precedence', () {
    test('null input returns imeiRequired', () {
      final result = validateImei(null);
      expect(result, isA<ImeiValidationFailure>());
      expect(
        (result as ImeiValidationFailure).error.code,
        ImeiValidationErrorCode.imeiRequired,
      );
    });

    test('empty string returns imeiRequired', () {
      final result = validateImei('');
      expect(result, isA<ImeiValidationFailure>());
      expect(
        (result as ImeiValidationFailure).error.code,
        ImeiValidationErrorCode.imeiRequired,
      );
    });

    test('whitespace-only returns imeiRequired', () {
      final result = validateImei('   ');
      expect(result, isA<ImeiValidationFailure>());
      expect(
        (result as ImeiValidationFailure).error.code,
        ImeiValidationErrorCode.imeiRequired,
      );
    });

    test('alpha characters return imeiInvalidCharacters', () {
      final result = validateImei('35693803564ABCD');
      expect(result, isA<ImeiValidationFailure>());
      expect(
        (result as ImeiValidationFailure).error.code,
        ImeiValidationErrorCode.imeiInvalidCharacters,
      );
    });

    test('special characters return imeiInvalidCharacters', () {
      final result = validateImei('35693@035643#09');
      expect(result, isA<ImeiValidationFailure>());
      expect(
        (result as ImeiValidationFailure).error.code,
        ImeiValidationErrorCode.imeiInvalidCharacters,
      );
    });

    test('too short (14 digits) returns imeiInvalidLength', () {
      final result = validateImei('35693803564380');
      expect(result, isA<ImeiValidationFailure>());
      expect(
        (result as ImeiValidationFailure).error.code,
        ImeiValidationErrorCode.imeiInvalidLength,
      );
    });

    test('too long (16 digits) returns imeiInvalidLength', () {
      final result = validateImei('3569380356438091');
      expect(result, isA<ImeiValidationFailure>());
      expect(
        (result as ImeiValidationFailure).error.code,
        ImeiValidationErrorCode.imeiInvalidLength,
      );
    });

    test('15 digits failing Luhn returns imeiInvalidChecksum', () {
      final result = validateImei('356938035643800');
      expect(result, isA<ImeiValidationFailure>());
      expect(
        (result as ImeiValidationFailure).error.code,
        ImeiValidationErrorCode.imeiInvalidChecksum,
      );
    });

    test('valid IMEI returns success with normalized value', () {
      final result = validateImei(_validImei);
      expect(result, isA<ImeiValidationSuccess>());
      expect((result as ImeiValidationSuccess).value.value, _validImei);
    });

    test('separators are removed before validation', () {
      final result = validateImei('356-938-035-643-809');
      expect(result, isA<ImeiValidationSuccess>());
      expect((result as ImeiValidationSuccess).value.value, _validImei);
    });

    test('spaces as separators are removed', () {
      final result = validateImei('356 938 035 643 809');
      expect(result, isA<ImeiValidationSuccess>());
      expect((result as ImeiValidationSuccess).value.value, _validImei);
    });

    test('error field is always "imei"', () {
      final result = validateImei('');
      expect((result as ImeiValidationFailure).error.field, 'imei');
    });

    test('error codeString matches enum convention', () {
      final result = validateImei('abc');
      expect(
        (result as ImeiValidationFailure).error.codeString,
        'IMEI_INVALID_CHARACTERS',
      );
    });
  });

  // ==========================================================================
  // GROUP 2: Luhn Algorithm
  // ==========================================================================
  group('Luhn algorithm', () {
    test('known valid IMEIs pass Luhn', () {
      expect(isValidLuhn('356938035643809'), isTrue);
      expect(isValidLuhn('490154203237518'), isTrue);
    });

    test('known invalid IMEIs fail Luhn', () {
      expect(isValidLuhn('356938035643800'), isFalse);
      expect(isValidLuhn('111111111111111'), isFalse);
    });

    test('non-15-digit strings always fail', () {
      expect(isValidLuhn('1234'), isFalse);
      expect(isValidLuhn('1234567890123456'), isFalse);
    });
  });

  // ==========================================================================
  // GROUP 3: Device Lifecycle — Allowed Transitions
  // ==========================================================================
  group('Device lifecycle — allowed transitions', () {
    test(
      'IN_STOCK can transition to RESERVED, SALE_PENDING, DEMO, DAMAGED, RETIRED',
      () {
        final targets = getAllowedTargets(DeviceLifecycleState.inStock);
        expect(
          targets,
          containsAll([
            DeviceLifecycleState.reserved,
            DeviceLifecycleState.salePending,
            DeviceLifecycleState.demo,
            DeviceLifecycleState.damaged,
            DeviceLifecycleState.retired,
          ]),
        );
      },
    );

    test('SOLD can transition to RETURNED, IN_SERVICE, EXCHANGED', () {
      final targets = getAllowedTargets(DeviceLifecycleState.sold);
      expect(
        targets,
        containsAll([
          DeviceLifecycleState.returned,
          DeviceLifecycleState.inService,
          DeviceLifecycleState.exchanged,
        ]),
      );
    });

    test('EXCHANGED is terminal (no outgoing transitions)', () {
      expect(isTerminalState(DeviceLifecycleState.exchanged), isTrue);
      expect(getAllowedTargets(DeviceLifecycleState.exchanged), isEmpty);
    });

    test('RETIRED is terminal (no outgoing transitions)', () {
      expect(isTerminalState(DeviceLifecycleState.retired), isTrue);
      expect(getAllowedTargets(DeviceLifecycleState.retired), isEmpty);
    });

    test('every non-terminal state has at least one outgoing transition', () {
      for (final state in DeviceLifecycleState.values) {
        if (!isTerminalState(state)) {
          expect(
            getAllowedTargets(state),
            isNotEmpty,
            reason: '${state.name} should have outgoing transitions',
          );
        }
      }
    });

    test('every state is represented in the transition map', () {
      for (final state in DeviceLifecycleState.values) {
        expect(
          allowedTransitions.containsKey(state),
          isTrue,
          reason: '${state.name} missing from allowedTransitions',
        );
      }
    });
  });

  // ==========================================================================
  // GROUP 4: Device Lifecycle — Transition Validation
  // ==========================================================================
  group('Device lifecycle — transition validation', () {
    test('valid transition produces TransitionSuccess with event', () {
      const unit = _TestUnit(
        lifecycleState: DeviceLifecycleState.inStock,
        version: 1,
      );
      final command = TransitionCommand(
        targetState: DeviceLifecycleState.reserved,
        expectedVersion: 1,
        actor: 'user-1',
        reason: 'Customer reservation',
      );

      final result = validateTransition(unit, command);
      expect(result, isA<TransitionSuccess>());
      final event = (result as TransitionSuccess).event;
      expect(event.previousState, DeviceLifecycleState.inStock);
      expect(event.newState, DeviceLifecycleState.reserved);
      expect(event.actor, 'user-1');
      expect(event.newVersion, 2);
    });

    test('version mismatch produces versionMismatch error', () {
      const unit = _TestUnit(
        lifecycleState: DeviceLifecycleState.inStock,
        version: 5,
      );
      final command = TransitionCommand(
        targetState: DeviceLifecycleState.reserved,
        expectedVersion: 3, // stale version
        actor: 'user-1',
        reason: 'Reserve',
      );

      final result = validateTransition(unit, command);
      expect(result, isA<TransitionFailure>());
      final error = (result as TransitionFailure).error;
      expect(error.code, LifecycleErrorCode.versionMismatch);
      expect(error.expectedVersion, 3);
      expect(error.actualVersion, 5);
    });

    test('invalid transition produces invalidTransition error', () {
      const unit = _TestUnit(
        lifecycleState: DeviceLifecycleState.inStock,
        version: 1,
      );
      final command = TransitionCommand(
        targetState: DeviceLifecycleState.sold, // cannot go directly to sold
        expectedVersion: 1,
        actor: 'user-1',
        reason: 'Direct sale attempt',
      );

      final result = validateTransition(unit, command);
      expect(result, isA<TransitionFailure>());
      final error = (result as TransitionFailure).error;
      expect(error.code, LifecycleErrorCode.invalidTransition);
    });

    test('terminal state produces terminalState error', () {
      const unit = _TestUnit(
        lifecycleState: DeviceLifecycleState.retired,
        version: 3,
      );
      final command = TransitionCommand(
        targetState: DeviceLifecycleState.inStock,
        expectedVersion: 3,
        actor: 'user-1',
        reason: 'Attempted resurrection',
      );

      final result = validateTransition(unit, command);
      expect(result, isA<TransitionFailure>());
      final error = (result as TransitionFailure).error;
      expect(error.code, LifecycleErrorCode.terminalState);
    });

    test('version check takes precedence over transition check', () {
      // Even though inStock -> sold is invalid, version mismatch fires first
      const unit = _TestUnit(
        lifecycleState: DeviceLifecycleState.inStock,
        version: 2,
      );
      final command = TransitionCommand(
        targetState: DeviceLifecycleState.sold,
        expectedVersion: 1, // wrong version
        actor: 'user-1',
        reason: 'Bad command',
      );

      final result = validateTransition(unit, command);
      expect(result, isA<TransitionFailure>());
      expect(
        (result as TransitionFailure).error.code,
        LifecycleErrorCode.versionMismatch,
      );
    });
  });

  // ==========================================================================
  // GROUP 5: Lifecycle Wire Format
  // ==========================================================================
  group('Device lifecycle — wire format', () {
    test('toWireValue and fromWire are symmetric for all states', () {
      for (final state in DeviceLifecycleState.values) {
        final wire = state.toWireValue();
        final parsed = DeviceLifecycleState.fromWire(wire);
        expect(parsed, state, reason: '${state.name} round-trip failed');
      }
    });

    test('fromWire throws for unknown string', () {
      expect(
        () => DeviceLifecycleState.fromWire('UNKNOWN_STATE'),
        throwsArgumentError,
      );
    });
  });

  // ==========================================================================
  // GROUP 6: Warranty Validator — Month-End Behavior
  // ==========================================================================
  group('Warranty validator — month-end dates', () {
    test('Jan 31 + 1 month = Feb 28 (non-leap year)', () {
      final saleDate = DateTime(2023, 1, 31);
      final result = calculateWarrantyEndDate(saleDate, 1);
      expect(result, '2023-02-28');
    });

    test('Jan 31 + 1 month = Feb 29 (leap year)', () {
      final saleDate = DateTime(2024, 1, 31);
      final result = calculateWarrantyEndDate(saleDate, 1);
      expect(result, '2024-02-29');
    });

    test('Jan 30 + 1 month = Feb 28 (non-leap year, clamped)', () {
      final saleDate = DateTime(2023, 1, 30);
      final result = calculateWarrantyEndDate(saleDate, 1);
      expect(result, '2023-02-28');
    });

    test('Jan 15 + 1 month = Feb 15 (mid-month preserved)', () {
      final saleDate = DateTime(2023, 1, 15);
      final result = calculateWarrantyEndDate(saleDate, 1);
      expect(result, '2023-02-15');
    });

    test('Dec 31 + 1 month = Jan 31 next year', () {
      final saleDate = DateTime(2023, 12, 31);
      final result = calculateWarrantyEndDate(saleDate, 1);
      expect(result, '2024-01-31');
    });

    test('March 31 + 12 months = March 31 next year', () {
      final saleDate = DateTime(2023, 3, 31);
      final result = calculateWarrantyEndDate(saleDate, 12);
      expect(result, '2024-03-31');
    });

    test('Nov 30 + 3 months = Feb 28 (non-leap year)', () {
      final saleDate = DateTime(2022, 11, 30);
      final result = calculateWarrantyEndDate(saleDate, 3);
      expect(result, '2023-02-28');
    });

    test('large month addition (24 months) crosses year boundary', () {
      final saleDate = DateTime(2023, 6, 15);
      final result = calculateWarrantyEndDate(saleDate, 24);
      expect(result, '2025-06-15');
    });
  });

  // ==========================================================================
  // GROUP 7: Warranty Validator — Months Validation
  // ==========================================================================
  group('Warranty validator — months validation', () {
    test('null months returns warrantyMonthsRequired', () {
      final result = validateWarrantyMonths(null);
      expect(result, isA<WarrantyMonthsFailure>());
      expect(
        (result as WarrantyMonthsFailure).error.code,
        WarrantyValidationErrorCode.warrantyMonthsRequired,
      );
    });

    test('zero months returns warrantyMonthsNotPositive', () {
      final result = validateWarrantyMonths(0);
      expect(result, isA<WarrantyMonthsFailure>());
      expect(
        (result as WarrantyMonthsFailure).error.code,
        WarrantyValidationErrorCode.warrantyMonthsNotPositive,
      );
    });

    test('negative months returns warrantyMonthsNotPositive', () {
      final result = validateWarrantyMonths(-5);
      expect(result, isA<WarrantyMonthsFailure>());
      expect(
        (result as WarrantyMonthsFailure).error.code,
        WarrantyValidationErrorCode.warrantyMonthsNotPositive,
      );
    });

    test('valid months returns success', () {
      final result = validateWarrantyMonths(12);
      expect(result, isA<WarrantyMonthsSuccess>());
      expect((result as WarrantyMonthsSuccess).value, 12);
    });
  });

  // ==========================================================================
  // GROUP 8: Warranty Registration Validation
  // ==========================================================================
  group('Warranty registration', () {
    test('null saleDate returns warrantySaleDateRequired', () {
      final result = validateWarrantyRegistration(
        saleDate: null,
        warrantyMonths: 12,
      );
      expect(result, isA<WarrantyRegistrationFailure>());
      expect(
        (result as WarrantyRegistrationFailure).error.code,
        WarrantyValidationErrorCode.warrantySaleDateRequired,
      );
    });

    test('valid inputs returns success with computed endDate', () {
      final result = validateWarrantyRegistration(
        saleDate: DateTime(2024, 1, 15),
        warrantyMonths: 12,
        provider: 'Samsung',
        notes: 'Standard warranty',
      );
      expect(result, isA<WarrantyRegistrationSuccess>());
      final success = result as WarrantyRegistrationSuccess;
      expect(success.warrantyMonths, 12);
      expect(success.warrantyEndDate, '2025-01-15');
      expect(success.provider, 'Samsung');
      expect(success.notes, 'Standard warranty');
    });
  });

  // ==========================================================================
  // GROUP 9: Monetary Validator
  // ==========================================================================
  group('Monetary validator', () {
    test('null amount returns moneyRequired', () {
      final result = validateMoney(null, 'salePrice');
      expect(result, isA<MoneyValidationFailure>());
      expect(
        (result as MoneyValidationFailure).error.code,
        MonetaryValidationErrorCode.moneyRequired,
      );
    });

    test('negative amount returns moneyNegative', () {
      final result = validateMoney(-100, 'salePrice');
      expect(result, isA<MoneyValidationFailure>());
      expect(
        (result as MoneyValidationFailure).error.code,
        MonetaryValidationErrorCode.moneyNegative,
      );
    });

    test('zero amount is valid (demo/damaged units can have 0 price)', () {
      final result = validateMoney(0, 'salePrice');
      expect(result, isA<MoneyValidationSuccess>());
      expect((result as MoneyValidationSuccess).value.amountMinorUnits, 0);
    });

    test('positive amount returns success with Money value', () {
      final result = validateMoney(5999900, 'salePrice');
      expect(result, isA<MoneyValidationSuccess>());
      final money = (result as MoneyValidationSuccess).value;
      expect(money.amountMinorUnits, 5999900);
    });

    test('field name is preserved in error', () {
      final result = validateMoney(null, 'acquisitionCost');
      expect((result as MoneyValidationFailure).error.field, 'acquisitionCost');
    });
  });

  // ==========================================================================
  // GROUP 10: Sale Price Validation — Sibling Preservation
  // ==========================================================================
  group('Sale price validation — sibling preservation', () {
    test('both valid returns ok with both prices', () {
      final result = validateSalePrice(
        salePrice: 2500000,
        acquisitionCost: 2000000,
      );
      expect(result.ok, isTrue);
      expect(result.salePrice, isNotNull);
      expect(result.acquisitionCost, isNotNull);
      expect(result.errors, isEmpty);
    });

    test('one invalid still preserves the valid sibling', () {
      final result = validateSalePrice(
        salePrice: -100, // invalid
        acquisitionCost: 2000000, // valid
      );
      expect(result.ok, isFalse);
      expect(result.salePrice, isNull); // invalid
      expect(result.acquisitionCost, isNotNull); // preserved
      expect(result.errors, hasLength(1));
    });

    test('both invalid collects both errors', () {
      final result = validateSalePrice(salePrice: null, acquisitionCost: null);
      expect(result.ok, isFalse);
      expect(result.salePrice, isNull);
      expect(result.acquisitionCost, isNull);
      expect(result.errors, hasLength(2));
    });
  });
}
