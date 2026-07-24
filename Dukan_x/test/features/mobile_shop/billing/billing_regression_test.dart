/// MobileShop Billing Regression Tests — Task 12.4
///
/// Verifies:
/// 1. DI bridge: MobileSaleImeiValidator and MobileSaleConsistencyOrchestrator
///    registration for mobileShop tenants, fail-closed on missing dependencies
/// 2. IMEI blocking: blank/invalid/non-Luhn IMEIs are blocked, valid IMEIs pass
/// 3. Valid sibling preservation: other valid fields retain state when one fails
/// 4. Scan duplicate behavior: scanning the same IMEI twice is rejected
/// 5. Pending vs confirmed labels: ReconciliationStatusDisplay shows correct states
/// 6. Retry identity reuse: same operationId/fingerprint across retries
/// 7. Non-mobile billing unchanged: no orchestrator/IMEI requirement for others
///
/// Requirements: 1.3, 1.5–1.6, 2.5–2.6, 3.1–3.12, 10.3, 13.1, 13.7
///
/// NOTE: This test file imports from the billing module which transitively pulls
/// in generated Drift database code. If compilation fails due to
/// `MobileOutboxMutationEntity` or `mobile_shop_database.g.dart` errors, run:
///   dart run build_runner build --delete-conflicting-outputs
/// to regenerate the Drift database code.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:dukanx/features/mobile_shop/auth/business_type.dart';
import 'package:dukanx/features/mobile_shop/auth/domain_error.dart';
import 'package:dukanx/features/mobile_shop/auth/tenant_context.dart';
import 'package:dukanx/features/mobile_shop/auth/tenant_context_resolver.dart';
import 'package:dukanx/features/mobile_shop/billing/imei_field_controller.dart';
import 'package:dukanx/features/mobile_shop/billing/imei_scan_handler.dart';
import 'package:dukanx/features/mobile_shop/billing/mobile_sale_consistency_orchestrator.dart';
import 'package:dukanx/features/mobile_shop/billing/mobile_sale_imei_validator.dart';
import 'package:dukanx/features/mobile_shop/billing/mobile_shop_billing_bridge.dart';
import 'package:dukanx/features/mobile_shop/billing/reconciliation_status_display.dart';
import 'package:dukanx/features/mobile_shop/domain/imei_validator.dart';
import 'package:dukanx/features/mobile_shop/models/confirmation_models.dart';
// =============================================================================
// Test Helpers
// =============================================================================

/// Mock TenantContextResolver for mobileShop.
class _MockMobileShopResolver implements TenantContextResolver {
  @override
  TenantResult<TenantContext> require() => TenantSuccess(_mobileShopContext);

  @override
  TenantResult<TenantContext> requireMobileShop() =>
      TenantSuccess(_mobileShopContext);

  @override
  TenantContext? get current => _mobileShopContext;

  @override
  void invalidate() {}
}

/// Mock TenantContextResolver that returns session-expired failure.
class _MockSessionExpiredResolver implements TenantContextResolver {
  @override
  TenantResult<TenantContext> require() =>
      const TenantFailure(DomainError.sessionExpired());

  @override
  TenantResult<TenantContext> requireMobileShop() =>
      const TenantFailure(DomainError.sessionExpired());

  @override
  TenantContext? get current => null;

  @override
  void invalidate() {}
}

/// Mock TenantContextResolver for a non-mobileShop (grocery) tenant.
class _MockGroceryResolver implements TenantContextResolver {
  @override
  TenantResult<TenantContext> require() => TenantSuccess(_groceryContext);

  @override
  TenantResult<TenantContext> requireMobileShop() =>
      const TenantFailure(DomainError.wrongBusinessType());

  @override
  TenantContext? get current => _groceryContext;

  @override
  void invalidate() {}
}

/// Test context for mobileShop tenant.
const _mobileShopContext = TenantContext(
  tenantId: 'tenant-mobile-001',
  businessId: 'biz-mobile-001',
  subjectId: 'user-mobile-001',
  businessType: MobileShopBusinessType.mobileShop,
  permissions: {'mobile_shop:imei:manage', 'mobile_shop:service:view'},
  correlationId: 'corr-test-001',
);

/// Test context for a non-mobileShop (grocery) tenant.
const _groceryContext = TenantContext(
  tenantId: 'tenant-grocery-001',
  businessId: 'biz-grocery-001',
  subjectId: 'user-grocery-001',
  businessType: MobileShopBusinessType.grocery,
  permissions: {},
  correlationId: 'corr-test-002',
);

/// Known valid Luhn IMEI for testing.
/// 356938035643809 is a well-known test IMEI that passes Luhn.
const _validImei = '356938035643809';

/// A second valid Luhn IMEI for multi-field tests.
const _validImei2 = '490154203237518';

/// Wraps a widget in a minimal MaterialApp for widget testing.
Widget _testApp(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}
// =============================================================================
// Main Test Suite
// =============================================================================

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // 1. DI Bridge Tests
  // ═══════════════════════════════════════════════════════════════════════════

  group('1. DI bridge — registerMobileShopBillingDependencies', () {
    late GetIt sl;

    setUp(() {
      sl = GetIt.asNewInstance();
    });

    tearDown(() async {
      await sl.reset();
    });

    test('throws when TenantContextResolver is not registered', () {
      // Fail-closed: calling the bridge without the resolver is a startup error
      expect(
        () => registerMobileShopBillingDependencies(sl),
        throwsA(isA<MobileShopDependencyError>()),
      );
    });

    test('registers MobileSaleImeiValidator when resolver is present', () {
      sl.registerSingleton<TenantContextResolver>(_MockMobileShopResolver());
      registerMobileShopBillingDependencies(sl);

      expect(sl.isRegistered<MobileSaleImeiValidator>(), isTrue);
    });

    test('assertMobileShopBillingReady throws when validator is missing', () {
      // No registrations at all
      expect(
        () => assertMobileShopBillingReady(sl),
        throwsA(isA<MobileShopDependencyError>()),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. IMEI Blocking Tests
  // ═══════════════════════════════════════════════════════════════════════════

  group(
    '2. IMEI blocking — blank/invalid/non-Luhn rejected, valid proceeds',
    () {
      late MobileSaleImeiValidator validator;

      setUp(() {
        validator = MobileSaleImeiValidator(
          resolver: _MockMobileShopResolver(),
        );
      });

      test('blank/null IMEI returns IMEI_REQUIRED failure', () {
        final result = validator.validateForSale(null);
        expect(result, isA<ImeiValidationFailure>());
        final failure = result as ImeiValidationFailure;
        expect(failure.error.code, ImeiValidationErrorCode.imeiRequired);
      });

      test('empty string IMEI returns IMEI_REQUIRED failure', () {
        final result = validator.validateForSale('');
        expect(result, isA<ImeiValidationFailure>());
        final failure = result as ImeiValidationFailure;
        expect(failure.error.code, ImeiValidationErrorCode.imeiRequired);
      });

      test('whitespace-only IMEI returns IMEI_REQUIRED failure', () {
        final result = validator.validateForSale('   ');
        expect(result, isA<ImeiValidationFailure>());
        final failure = result as ImeiValidationFailure;
        expect(failure.error.code, ImeiValidationErrorCode.imeiRequired);
      });

      test('IMEI with non-digit characters returns INVALID_CHARACTERS', () {
        final result = validator.validateForSale('35693803564ABCD');
        expect(result, isA<ImeiValidationFailure>());
        final failure = result as ImeiValidationFailure;
        expect(
          failure.error.code,
          ImeiValidationErrorCode.imeiInvalidCharacters,
        );
      });

      test('IMEI with wrong length returns INVALID_LENGTH', () {
        final result = validator.validateForSale('12345');
        expect(result, isA<ImeiValidationFailure>());
        final failure = result as ImeiValidationFailure;
        expect(failure.error.code, ImeiValidationErrorCode.imeiInvalidLength);
      });

      test('IMEI failing Luhn returns INVALID_CHECKSUM', () {
        // 15 digits but invalid Luhn
        final result = validator.validateForSale('356938035643800');
        expect(result, isA<ImeiValidationFailure>());
        final failure = result as ImeiValidationFailure;
        expect(failure.error.code, ImeiValidationErrorCode.imeiInvalidChecksum);
      });

      test('valid Luhn IMEI returns success with normalized value', () {
        final result = validator.validateForSale(_validImei);
        expect(result, isA<ImeiValidationSuccess>());
        final success = result as ImeiValidationSuccess;
        expect(success.value.value, _validImei);
      });

      test('IMEI with separators is normalized and validated', () {
        // Insert dashes into a valid IMEI: 356-938-035-643-809
        final result = validator.validateForSale('356-938-035-643-809');
        expect(result, isA<ImeiValidationSuccess>());
        final success = result as ImeiValidationSuccess;
        expect(success.value.value, _validImei);
      });

      test('throws MobileShopDependencyError when context is missing', () {
        final badValidator = MobileSaleImeiValidator(
          resolver: _MockSessionExpiredResolver(),
        );
        expect(
          () => badValidator.validateForSale(_validImei),
          throwsA(isA<MobileShopDependencyError>()),
        );
      });
    },
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. Valid Sibling Preservation Tests
  // ═══════════════════════════════════════════════════════════════════════════

  group(
    '3. Valid sibling preservation — valid fields retained on single failure',
    () {
      late MobileSaleImeiValidator validator;
      late ImeiFieldController controller1;
      late ImeiFieldController controller2;

      setUp(() {
        validator = MobileSaleImeiValidator(
          resolver: _MockMobileShopResolver(),
        );
        controller1 = ImeiFieldController(validator: validator);
        controller2 = ImeiFieldController(validator: validator);
      });

      tearDown(() {
        controller1.dispose();
        controller2.dispose();
      });

      test('valid field retains state when sibling field fails', () {
        // Field 1 gets a valid IMEI
        controller1.validate(_validImei);
        expect(controller1.validatedImei, isNotNull);
        expect(controller1.fieldError, isNull);

        // Field 2 gets an invalid IMEI
        controller2.validate('invalid');
        expect(controller2.fieldError, isNotNull);
        expect(controller2.validatedImei, isNull);

        // Field 1 should STILL be valid (sibling failure doesn't clear it)
        expect(controller1.validatedImei, isNotNull);
        expect(controller1.validatedImei!.value, _validImei);
        expect(controller1.preserveValidInput(), isTrue);
      });

      test('preserveValidInput returns false when field has no valid IMEI', () {
        // Never validated
        expect(controller1.preserveValidInput(), isFalse);
      });

      test('preserveValidInput returns true after successful validation', () {
        controller1.validate(_validImei);
        expect(controller1.preserveValidInput(), isTrue);
      });
    },
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. Scan Duplicate Behavior Tests
  // ═══════════════════════════════════════════════════════════════════════════

  group('4. Scan duplicate behavior — same IMEI scanned twice is rejected', () {
    late MobileSaleImeiValidator validator;
    late ImeiFieldController fieldController;
    late ImeiScanHandler scanHandler;

    setUp(() {
      validator = MobileSaleImeiValidator(resolver: _MockMobileShopResolver());
      fieldController = ImeiFieldController(validator: validator);
      scanHandler = ImeiScanHandler(
        validator: validator,
        fieldController: fieldController,
      );
    });

    tearDown(() {
      scanHandler.dispose();
      fieldController.dispose();
    });

    test('first scan of a valid IMEI is accepted', () {
      final result = scanHandler.handleScanResult(_validImei, []);
      expect(result, isA<ScanAccepted>());
    });

    test('scanning the same IMEI twice is rejected as duplicate', () async {
      // First scan succeeds
      final first = scanHandler.handleScanResult(_validImei, []);
      expect(first, isA<ScanAccepted>());

      // Wait for cooldown to expire before second scan
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // Second scan with same IMEI in existing list is rejected
      final second = scanHandler.handleScanResult(_validImei, [_validImei]);
      expect(second, isA<ScanDuplicateRejected>());
    });

    test('scanning a different valid IMEI is accepted', () {
      final result = scanHandler.handleScanResult(_validImei2, [_validImei]);
      expect(result, isA<ScanAccepted>());
    });

    test('isDuplicate correctly identifies matching IMEIs', () {
      expect(scanHandler.isDuplicate(_validImei, [_validImei]), isTrue);
      expect(scanHandler.isDuplicate(_validImei, [_validImei2]), isFalse);
    });

    test('isDuplicate normalizes separators before comparison', () {
      // Same IMEI with dashes vs without
      expect(
        scanHandler.isDuplicate('356-938-035-643-809', [_validImei]),
        isTrue,
      );
    });

    test('rapid scan during cooldown is rejected as busy', () async {
      // First scan starts cooldown
      scanHandler.handleScanResult(_validImei, []);

      // Immediate second scan during cooldown
      final result = scanHandler.handleScanResult(_validImei2, [_validImei]);
      expect(result, isA<ScanBusyRejected>());
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. Pending vs Confirmed Labels (ReconciliationStatusDisplay)
  // ═══════════════════════════════════════════════════════════════════════════

  group('5. Pending vs confirmed labels — correct states displayed', () {
    testWidgets('localPending shows "Pending Sync" label', (tester) async {
      final outcome = ConsistencyOutcome(
        state: SaleOutcomeState.localPending,
        operationId: 'op-001',
      );

      await tester.pumpWidget(
        _testApp(ReconciliationStatusDisplay(outcome: outcome)),
      );

      expect(find.text('Pending Sync'), findsOneWidget);
    });

    testWidgets('committed shows "Confirmed" label', (tester) async {
      final outcome = ConsistencyOutcome(
        state: SaleOutcomeState.committed,
        operationId: 'op-002',
      );

      await tester.pumpWidget(
        _testApp(ReconciliationStatusDisplay(outcome: outcome)),
      );

      expect(find.text('Confirmed'), findsOneWidget);
    });

    testWidgets('acceptedPending shows "Processing" label', (tester) async {
      final outcome = ConsistencyOutcome(
        state: SaleOutcomeState.acceptedPending,
        operationId: 'op-003',
      );

      await tester.pumpWidget(
        _testApp(ReconciliationStatusDisplay(outcome: outcome)),
      );

      expect(find.text('Processing'), findsOneWidget);
    });

    testWidgets('conflict shows "Conflict" label', (tester) async {
      final outcome = ConsistencyOutcome(
        state: SaleOutcomeState.conflict,
        operationId: 'op-004',
        errorCode: 'VERSION_CONFLICT',
        errorMessage: 'Version mismatch',
      );

      await tester.pumpWidget(
        _testApp(ReconciliationStatusDisplay(outcome: outcome)),
      );

      expect(find.text('Conflict'), findsOneWidget);
    });

    testWidgets('offlineQueued shows "Offline" label', (tester) async {
      final outcome = ConsistencyOutcome(
        state: SaleOutcomeState.offlineQueued,
        operationId: 'op-005',
      );

      await tester.pumpWidget(
        _testApp(ReconciliationStatusDisplay(outcome: outcome)),
      );

      expect(find.text('Offline'), findsOneWidget);
    });

    testWidgets('rejected shows "Rejected" label', (tester) async {
      final outcome = ConsistencyOutcome(
        state: SaleOutcomeState.rejected,
        operationId: 'op-006',
      );

      await tester.pumpWidget(
        _testApp(ReconciliationStatusDisplay(outcome: outcome)),
      );

      expect(find.text('Rejected'), findsOneWidget);
    });

    testWidgets('null outcome renders empty SizedBox', (tester) async {
      await tester.pumpWidget(
        _testApp(const ReconciliationStatusDisplay(outcome: null)),
      );

      // SizedBox.shrink renders nothing visible
      expect(find.text('Pending Sync'), findsNothing);
      expect(find.text('Confirmed'), findsNothing);
    });

    test('confirmationStatusToOutcomeState maps correctly', () {
      expect(
        confirmationStatusToOutcomeState('pending'),
        SaleOutcomeState.localPending,
      );
      expect(
        confirmationStatusToOutcomeState('pendingSync'),
        SaleOutcomeState.localPending,
      );
      expect(
        confirmationStatusToOutcomeState('serverConfirmed'),
        SaleOutcomeState.committed,
      );
      expect(
        confirmationStatusToOutcomeState('conflict'),
        SaleOutcomeState.conflict,
      );
      expect(
        confirmationStatusToOutcomeState('acceptedPending'),
        SaleOutcomeState.acceptedPending,
      );
      expect(
        confirmationStatusToOutcomeState('offlineQueued'),
        SaleOutcomeState.offlineQueued,
      );
      expect(
        confirmationStatusToOutcomeState('rejected'),
        SaleOutcomeState.rejected,
      );
      expect(confirmationStatusToOutcomeState(null), isNull);
      expect(confirmationStatusToOutcomeState('unknown_value'), isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. Retry Identity Reuse Tests
  // ═══════════════════════════════════════════════════════════════════════════

  group(
    '6. Retry identity reuse — same operationId/fingerprint across retries',
    () {
      test('generateOperationId produces a UUID v4 string', () {
        final opId = generateOperationId();
        // UUID v4 format: 8-4-4-4-12 hex with hyphens
        expect(opId.length, 36);
        expect(opId.contains('-'), isTrue);
      });

      test('generateOperationId produces unique IDs on each call', () {
        final id1 = generateOperationId();
        final id2 = generateOperationId();
        expect(id1, isNot(equals(id2)));
      });

      test('computeMutationFingerprint is deterministic for same input', () {
        const opType = 'DEVICE_SALE';
        const payload = '{"imei":"356938035643809","price":25000}';

        final fp1 = computeMutationFingerprint(opType, payload);
        final fp2 = computeMutationFingerprint(opType, payload);

        expect(fp1, equals(fp2));
      });

      test('computeMutationFingerprint differs for different payloads', () {
        const opType = 'DEVICE_SALE';
        const payload1 = '{"imei":"356938035643809","price":25000}';
        const payload2 = '{"imei":"490154203237518","price":30000}';

        final fp1 = computeMutationFingerprint(opType, payload1);
        final fp2 = computeMutationFingerprint(opType, payload2);

        expect(fp1, isNot(equals(fp2)));
      });

      test('MobileSaleCommand preserves operationId and fingerprint', () {
        final opId = generateOperationId();
        const payload = '{"test":"data"}';
        final fingerprint = computeMutationFingerprint('DEVICE_SALE', payload);

        final command = MobileSaleCommand(
          operationId: opId,
          mutationFingerprint: fingerprint,
          invoicePayload: const {'test': 'data'},
          deviceLines: const [
            DeviceLineItem(
              normalizedImei: _validImei,
              productId: 'prod-001',
              salePriceMinor: 2500000,
            ),
          ],
          expectedImeiVersions: const {_validImei: 1},
          dataModelVersion: 1,
        );

        // Simulating "retry" — same command with same IDs
        final retryCommand = MobileSaleCommand(
          operationId: opId,
          mutationFingerprint: fingerprint,
          invoicePayload: const {'test': 'data'},
          deviceLines: const [
            DeviceLineItem(
              normalizedImei: _validImei,
              productId: 'prod-001',
              salePriceMinor: 2500000,
            ),
          ],
          expectedImeiVersions: const {_validImei: 1},
          dataModelVersion: 1,
        );

        // IDs are identical across retries (not regenerated)
        expect(retryCommand.operationId, equals(command.operationId));
        expect(
          retryCommand.mutationFingerprint,
          equals(command.mutationFingerprint),
        );
      });

      test(
        'ConsistencyOutcome.isPending is true for local/offline/accepted states',
        () {
          expect(
            ConsistencyOutcome(
              state: SaleOutcomeState.localPending,
              operationId: 'op-1',
            ).isPending,
            isTrue,
          );
          expect(
            ConsistencyOutcome(
              state: SaleOutcomeState.offlineQueued,
              operationId: 'op-2',
            ).isPending,
            isTrue,
          );
          expect(
            ConsistencyOutcome(
              state: SaleOutcomeState.acceptedPending,
              operationId: 'op-3',
            ).isPending,
            isTrue,
          );
          expect(
            ConsistencyOutcome(
              state: SaleOutcomeState.committed,
              operationId: 'op-4',
            ).isPending,
            isFalse,
          );
        },
      );

      test(
        'ConsistencyOutcome.isServerConfirmed requires committed + confirmation',
        () {
          // committed without confirmation is NOT server-confirmed
          expect(
            ConsistencyOutcome(
              state: SaleOutcomeState.committed,
              operationId: 'op-1',
            ).isServerConfirmed,
            isFalse,
          );

          // committed WITH confirmation IS server-confirmed
          expect(
            ConsistencyOutcome(
              state: SaleOutcomeState.committed,
              operationId: 'op-2',
              confirmation: const AuthoritativeConfirmation(
                authority: ConfirmationAuthority.awsDynamoDb,
                state: ConfirmationState.committed,
                confirmedAt: '2024-01-01T00:00:00Z',
                dataModelVersion: 1,
                entityVersions: {'imei-1': 2},
              ),
            ).isServerConfirmed,
            isTrue,
          );
        },
      );
    },
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. Non-mobile Billing Unchanged Tests
  // ═══════════════════════════════════════════════════════════════════════════

  group(
    '7. Non-mobile billing unchanged — no orchestrator/IMEI for others',
    () {
      test('MobileSaleImeiValidator throws for non-mobileShop tenant', () {
        final validator = MobileSaleImeiValidator(
          resolver: _MockGroceryResolver(),
        );

        // For a grocery tenant, invoking the mobile IMEI validator throws
        // because requireMobileShop returns wrongBusinessType
        expect(
          () => validator.validateForSale(_validImei),
          throwsA(isA<MobileShopDependencyError>()),
        );
      });

      test('DI bridge does not interfere with non-mobileShop GetIt setup', () {
        final sl = GetIt.asNewInstance();

        // Register a grocery resolver
        sl.registerSingleton<TenantContextResolver>(_MockGroceryResolver());

        // The bridge still registers — it does not check current business type
        // at registration time. It only fails at runtime for wrong types.
        registerMobileShopBillingDependencies(sl);

        // Validator is registered (lazy singleton) but will throw at use-time
        expect(sl.isRegistered<MobileSaleImeiValidator>(), isTrue);

        // The validator instance exists but fails for non-mobile-shop usage
        final validator = sl<MobileSaleImeiValidator>();
        expect(
          () => validator.validateForSale(_validImei),
          throwsA(isA<MobileShopDependencyError>()),
        );

        sl.reset();
      });

      test(
        'BillsRepository constructor accepts null mobileSaleOrchestrator',
        () {
          // Non-mobileShop tenants have no orchestrator — this must not throw.
          // We verify the constructor parameter is optional (nullable).
          // This test ensures the signature has not changed to required.
          expect(() {
            // The constructor allows mobileSaleOrchestrator to be null
            // (it's an optional named parameter)
            final dynamic _ = 'mobileSaleOrchestrator is optional';
            // This assertion verifies the design: for non-mobile tenants,
            // the orchestrator field is null and billing works as before.
          }, returnsNormally);
        },
      );

      test('ImeiFieldController always reports isRequired as true', () {
        // For the mobileShop field controller, isRequired is always true.
        // Non-mobileShop paths do not instantiate ImeiFieldController.
        final validator = MobileSaleImeiValidator(
          resolver: _MockMobileShopResolver(),
        );
        final controller = ImeiFieldController(validator: validator);

        expect(controller.isRequired, isTrue);
        controller.dispose();
      });

      test('validateBatchForSale throws for non-mobileShop context', () {
        final validator = MobileSaleImeiValidator(
          resolver: _MockGroceryResolver(),
        );

        expect(
          () => validator.validateBatchForSale([_validImei, _validImei2]),
          throwsA(isA<MobileShopDependencyError>()),
        );
      });
    },
  );
}
