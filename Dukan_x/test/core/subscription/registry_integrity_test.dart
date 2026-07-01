// ============================================================================
// Task 2.4 — Undefined-identifier rejection
// Spec: subscription-plan-tiers (Requirement 4.9)
// ============================================================================
// Asserts the RegistryIntegrityGuard rejects a proposed (string-keyed) registry
// entry that names an identifier not defined in the BusinessCapability enum,
// and reports exactly which identifier(s) are undefined — while still resolving
// the recognised identifiers.
//
// Run: flutter test test/core/subscription/registry_integrity_test.dart
// ============================================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/subscription/registry_integrity.dart';

void main() {
  late RegistryIntegrityGuard guard;

  setUp(() {
    guard = RegistryIntegrityGuard();
  });

  group('UT-REG-INTEGRITY: undefined identifier rejection (Req 4.9)', () {
    test('rejects an entry naming an unknown identifier and reports it', () {
      final result = guard.validateEntry([
        'useInvoiceCreate', // valid
        'useTeleportation', // undefined — does not exist in the enum
      ]);

      expect(result.isValid, isFalse);
      expect(result.undefinedIdentifiers, contains('useTeleportation'));
      // The valid identifier still resolves.
      expect(
        result.resolvedCapabilities,
        contains(BusinessCapability.useInvoiceCreate),
      );
    });

    test('reports every distinct undefined identifier exactly once', () {
      final result = guard.validateEntry([
        'useInvoiceList', // valid
        'useNotAReal', // undefined
        'useAlsoFake', // undefined
        'useNotAReal', // duplicate undefined — collapsed
      ]);

      expect(result.isValid, isFalse);
      expect(
        result.undefinedIdentifiers,
        equals(['useNotAReal', 'useAlsoFake']),
      );
      expect(
        result.resolvedCapabilities,
        equals([BusinessCapability.useInvoiceList]),
      );
    });

    test('accepts an entry whose identifiers are all defined', () {
      final result = guard.validateEntry([
        'useInvoiceCreate',
        'useInvoiceList',
        'useInvoiceSearch',
      ]);

      expect(result.isValid, isTrue);
      expect(result.undefinedIdentifiers, isEmpty);
      expect(
        result.toCapabilitySet(),
        equals({
          BusinessCapability.useInvoiceCreate,
          BusinessCapability.useInvoiceList,
          BusinessCapability.useInvoiceSearch,
        }),
      );
    });

    test('resolve() maps a known name and returns null for an unknown one', () {
      expect(
        guard.resolve('useInvoiceCreate'),
        equals(BusinessCapability.useInvoiceCreate),
      );
      expect(guard.resolve('useDefinitelyNotDefined'), isNull);
      expect(guard.isDefined('useInvoiceCreate'), isTrue);
      expect(guard.isDefined('useDefinitelyNotDefined'), isFalse);
    });
  });
}
