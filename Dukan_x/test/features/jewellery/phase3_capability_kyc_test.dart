// ============================================================================
// JEWELLERY VERTICAL REMEDIATION — Phase 3 Capability, KYC & Tenant Property Tests
//
// Feature: jewellery-vertical-remediation
//
// Tasks 6.5–6.11:
//   Property 16: Jewellery capabilities are granted to jewellery only
//   Property 17: Gated jewellery items carry their capability
//   Property 18: Retail-origin items are gated or removed
//   Property 19: KYC fields round-trip under encryption and are not stored in plaintext
//   Property 20: Displayed KYC id numbers are redacted
//   Property 3:  Tenant isolation
//   Example test: Assert the ten capabilities are present in the jewellery grant
//
// **Validates: Requirements 1.4, 1.5, 9.1, 9.2, 9.3, 9.4, 9.5, 10.1, 10.4, 11.1, 11.2, 11.3**
//
// PBT library: dartproptest ^0.2.1
// Run: flutter test test/features/jewellery/phase3_capability_kyc_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/isolation/feature_resolver.dart';
import 'package:dukanx/core/utils/rid_generator.dart';
import 'package:dukanx/features/jewellery/data/services/kyc_field_crypto.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/widgets/desktop/sidebar_configuration.dart';

// ---------------------------------------------------------------------------
// Constants — the ten jewellery capabilities (Requirement 9.1, 9.2).
// ---------------------------------------------------------------------------

/// The 8 NEW jewellery-domain capabilities granted ONLY to jewellery.
const List<BusinessCapability> _jewelleryOnlyCapabilities = [
  BusinessCapability.useGoldRate,
  BusinessCapability.useGoldRateAlert,
  BusinessCapability.useMakingCharges,
  BusinessCapability.useHallmark,
  BusinessCapability.useOldGoldExchange,
  BusinessCapability.useCustomOrders,
  BusinessCapability.useGoldSchemes,
  BusinessCapability.useJewelleryRepair,
];

/// The 2 shared capabilities also granted to jewellery.
const List<BusinessCapability> _sharedCapabilities = [
  BusinessCapability.useProductUnit,
  BusinessCapability.useProductTax,
];

/// All 10 capabilities forming the jewellery grant.
const List<BusinessCapability> _allTenCapabilities = [
  ..._jewelleryOnlyCapabilities,
  ..._sharedCapabilities,
];

/// The five retail-origin items that must not leak into jewellery view.
const List<String> _retailOriginItemIds = [
  'return_inwards',
  'proforma_bids',
  'dispatch_notes',
  'booking_orders',
  'low_stock',
];

/// All business types that are NOT jewellery.
final List<BusinessType> _nonJewelleryTypes = BusinessType.values
    .where((t) => t != BusinessType.jewellery)
    .toList(growable: false);

/// The jewellery sidebar item ids that carry domain capabilities.
/// Maps item id → expected BusinessCapability.
const Map<String, BusinessCapability> _gatedItemCapabilities = {
  'jewellery_gold_rate': BusinessCapability.useGoldRate,
  'jewellery_gold_rate_alert': BusinessCapability.useGoldRateAlert,
  'jewellery_hallmark': BusinessCapability.useHallmark,
  'jewellery_old_gold_exchange': BusinessCapability.useOldGoldExchange,
  'jewellery_custom_orders': BusinessCapability.useCustomOrders,
  'jewellery_repair': BusinessCapability.useJewelleryRepair,
  'jewellery_gold_scheme': BusinessCapability.useGoldSchemes,
  'jewellery_making_charges': BusinessCapability.useMakingCharges,
  'new_sale': BusinessCapability.useInvoiceCreate,
  'stock_summary': BusinessCapability.useInventoryList,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Install an in-memory secure-storage backend so KycFieldCrypto tests never
  // hit a missing platform channel (MissingPluginException).
  setUp(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      <String, String>{},
    );
    KycFieldCrypto.clearCache();
  });

  // ==========================================================================
  // Task 6.5 — Property 16: Jewellery capabilities are granted to jewellery only
  // Feature: jewellery-vertical-remediation, Property 16
  // **Validates: Requirements 9.4, 9.5**
  // ==========================================================================
  group('Feature: jewellery-vertical-remediation, '
      'Property 16: Jewellery capabilities are granted to jewellery only', () {
    test('PBT: For all 10 jewellery capabilities, canAccess("jewellery", cap) '
        'is true (100 iterations)', () {
      final bool held = forAll(
        (int idx) {
          final cap = _allTenCapabilities[idx % _allTenCapabilities.length];
          return FeatureResolver.canAccess('jewellery', cap);
        },
        [Gen.interval(0, _allTenCapabilities.length * 12)],
        numRuns: 100,
      );

      expect(
        held,
        isTrue,
        reason:
            'All 10 jewellery capabilities must be granted to jewellery '
            '(Requirement 9.4).',
      );
    });

    test(
      'PBT: For all non-jewellery types and the 8 jewellery-domain capabilities, '
      'canAccess(type, cap) is false (100 iterations)',
      () {
        final bool held = forAll(
          (int typeIdx, int capIdx) {
            final type =
                _nonJewelleryTypes[typeIdx % _nonJewelleryTypes.length];
            final cap =
                _jewelleryOnlyCapabilities[capIdx %
                    _jewelleryOnlyCapabilities.length];
            return !FeatureResolver.canAccess(type.name, cap);
          },
          [
            Gen.interval(0, _nonJewelleryTypes.length * 8),
            Gen.interval(0, _jewelleryOnlyCapabilities.length * 15),
          ],
          numRuns: 100,
        );

        expect(
          held,
          isTrue,
          reason:
              'The 8 jewellery-domain capabilities must not be granted to '
              'any non-jewellery business type (Requirement 9.5).',
        );
      },
    );
  });

  // ==========================================================================
  // Task 6.6 — Property 17: Gated jewellery items carry their capability
  // Feature: jewellery-vertical-remediation, Property 17
  // **Validates: Requirements 9.3**
  // ==========================================================================
  group('Feature: jewellery-vertical-remediation, '
      'Property 17: Gated jewellery items carry their capability', () {
    test(
      'PBT: For all jewellery sidebar items surfacing a gated domain feature, '
      'the item carries the correct BusinessCapability (100 iterations)',
      () {
        // Obtain the jewellery sections directly.
        final sections = getSectionsForBusinessType(BusinessType.jewellery);
        final allItems = sections.expand((s) => s.items).toList();

        final gatedEntries = _gatedItemCapabilities.entries.toList();

        final bool held = forAll(
          (int idx) {
            final entry = gatedEntries[idx % gatedEntries.length];
            final itemId = entry.key;
            final expectedCap = entry.value;

            // Find the item in the sections.
            final matchingItems = allItems
                .where((item) => item.id == itemId)
                .toList();

            // The item must exist.
            if (matchingItems.isEmpty) return false;

            // The item must carry the expected capability.
            final item = matchingItems.first;
            return item.capability == expectedCap;
          },
          [Gen.interval(0, gatedEntries.length * 12)],
          numRuns: 100,
        );

        expect(
          held,
          isTrue,
          reason:
              'Every gated jewellery sidebar item must carry its corresponding '
              'BusinessCapability (Requirement 9.3).',
        );
      },
    );
  });

  // ==========================================================================
  // Task 6.7 — Property 18: Retail-origin items are gated or removed
  // Feature: jewellery-vertical-remediation, Property 18
  // **Validates: Requirements 10.1, 10.4**
  // ==========================================================================
  group('Feature: jewellery-vertical-remediation, '
      'Property 18: Retail-origin items are gated or removed', () {
    test('PBT: For all 5 retail-origin items, none appear in the jewellery '
        'sidebar sections ungated (100 iterations)', () {
      final sections = getSectionsForBusinessType(BusinessType.jewellery);
      final allItemIds = sections
          .expand((s) => s.items)
          .map((i) => i.id)
          .toSet();

      // Build a map of items with their capabilities for gated check.
      final allItems = sections.expand((s) => s.items).toList();
      final itemCapMap = {for (final i in allItems) i.id: i.capability};

      final bool held = forAll(
        (int idx) {
          final retailId =
              _retailOriginItemIds[idx % _retailOriginItemIds.length];

          if (!allItemIds.contains(retailId)) {
            // Item is REMOVED — acceptable (Requirement 10.1).
            return true;
          }

          // Item is present — must be GATED by a granted capability.
          final cap = itemCapMap[retailId];
          if (cap == null) {
            // Present but not gated — reconciliation incomplete (10.4).
            return false;
          }

          // Verify the capability is actually granted to jewellery.
          return FeatureResolver.canAccess('jewellery', cap);
        },
        [Gen.interval(0, _retailOriginItemIds.length * 25)],
        numRuns: 100,
      );

      expect(
        held,
        isTrue,
        reason:
            'Each retail-origin item must be absent from jewellery sections '
            'or gated by a granted capability (Requirements 10.1, 10.4).',
      );
    });
  });

  // ==========================================================================
  // Task 6.8 — Property 19: KYC fields round-trip under encryption and are
  //            not stored in plaintext
  // Feature: jewellery-vertical-remediation, Property 19
  // **Validates: Requirements 11.1**
  // ==========================================================================
  group(
    'Feature: jewellery-vertical-remediation, '
    'Property 19: KYC fields round-trip under encryption and are not stored in plaintext',
    () {
      test(
        'PBT: For all generated KYC plaintext values, encrypt then decrypt '
        'yields the original, and ciphertext != plaintext (100 iterations)',
        () async {
          // Alphanumeric generator for KYC id numbers (Aadhaar/PAN-like).
          const chars =
              'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
          final tenantId =
              'test-tenant-${DateTime.now().millisecondsSinceEpoch}';

          // Run 100 iterations manually since the encrypt/decrypt is async.
          for (int i = 0; i < 100; i++) {
            // Generate a random plaintext of length 4–16.
            final length = 4 + (i % 13);
            final plaintext = String.fromCharCodes(
              List.generate(
                length,
                (j) => chars.codeUnitAt((i * 7 + j * 3) % chars.length),
              ),
            );

            // Encrypt.
            final ciphertext = await KycFieldCrypto.encrypt(
              plaintext,
              tenantId,
            );

            // Ciphertext must not be null and must differ from plaintext.
            expect(
              ciphertext,
              isNotNull,
              reason: 'Encryption of "$plaintext" returned null',
            );
            expect(
              ciphertext,
              isNot(equals(plaintext)),
              reason: 'Ciphertext must not equal plaintext (Requirement 11.1)',
            );

            // Decrypt.
            final result = await KycFieldCrypto.decrypt(ciphertext, tenantId);

            expect(
              result.hasError,
              isFalse,
              reason: 'Decryption failed for "$plaintext"',
            );
            expect(
              result.value,
              equals(plaintext),
              reason: 'Round-trip failed: decrypt(encrypt(x)) != x',
            );
          }
        },
      );

      test(
        'PBT: Null and empty values encrypt to null (boundary case)',
        () async {
          final tenantId = 'test-tenant-boundary';

          final nullResult = await KycFieldCrypto.encrypt(null, tenantId);
          expect(nullResult, isNull);

          final emptyResult = await KycFieldCrypto.encrypt('', tenantId);
          expect(emptyResult, isNull);
        },
      );
    },
  );

  // ==========================================================================
  // Task 6.9 — Property 20: Displayed KYC id numbers are redacted
  // Feature: jewellery-vertical-remediation, Property 20
  // **Validates: Requirements 11.3**
  // ==========================================================================
  group('Feature: jewellery-vertical-remediation, '
      'Property 20: Displayed KYC id numbers are redacted', () {
    test('PBT: For all generated id numbers longer than 4 chars, redact '
        'masks all but the last 4 and never contains the full plaintext '
        '(100 iterations)', () {
      final bool held = forAll(
        (int seed) {
          // Generate id numbers of length 5–20.
          final length = 5 + (seed % 16);
          final idNumber = String.fromCharCodes(
            List.generate(
              length,
              (j) => 48 + ((seed * 3 + j * 7) % 74), // ASCII 48–122
            ),
          );

          final redacted = KycFieldCrypto.redact(idNumber);

          // Must start with '****'.
          if (!redacted.startsWith('****')) return false;

          // Must show exactly the last 4 characters.
          final last4 = idNumber.substring(idNumber.length - 4);
          if (!redacted.endsWith(last4)) return false;

          // Must NOT contain the full plaintext.
          if (redacted.contains(idNumber)) return false;

          // Redacted length should be 4 (mask) + 4 (last4) = 8.
          if (redacted.length != 8) return false;

          return true;
        },
        [Gen.interval(1, 10000)],
        numRuns: 100,
      );

      expect(
        held,
        isTrue,
        reason:
            'Redacted KYC id must mask all but last 4 characters and never '
            'contain the full plaintext (Requirement 11.3).',
      );
    });

    test('PBT: For id numbers of length <= 4, redact returns fully masked '
        '(100 iterations)', () {
      final bool held = forAll(
        (int seed) {
          // Generate id numbers of length 1–4.
          final length = 1 + (seed % 4);
          final idNumber = String.fromCharCodes(
            List.generate(length, (j) => 65 + ((seed + j) % 26)),
          );

          final redacted = KycFieldCrypto.redact(idNumber);

          // Must be fully masked.
          return redacted == '****';
        },
        [Gen.interval(1, 5000)],
        numRuns: 100,
      );

      expect(
        held,
        isTrue,
        reason:
            'KYC ids of 4 or fewer chars must be fully masked (Requirement 11.3).',
      );
    });

    test('redact(null) and redact("") return "****"', () {
      expect(KycFieldCrypto.redact(null), equals('****'));
      expect(KycFieldCrypto.redact(''), equals('****'));
    });
  });

  // ==========================================================================
  // Task 6.10 — Property 3: Tenant isolation
  // Feature: jewellery-vertical-remediation, Property 3
  // **Validates: Requirements 1.4, 1.5, 11.2**
  // ==========================================================================
  group('Feature: jewellery-vertical-remediation, '
      'Property 3: Tenant isolation', () {
    test('PBT: RIDs are tenant-scoped — for all distinct tenant pairs, '
        'RID prefix differs (100 iterations)', () {
      final bool held = forAll(
        (int seed) {
          final tenantA = 'tenant-a-$seed';
          final tenantB = 'tenant-b-$seed';

          final ridA = RidGenerator.next(tenantA);
          final ridB = RidGenerator.next(tenantB);

          // RID must start with the respective tenantId.
          if (!ridA.startsWith('$tenantA-')) return false;
          if (!ridB.startsWith('$tenantB-')) return false;

          // RIDs from different tenants must never be equal.
          if (ridA == ridB) return false;

          // No operation uses literal 'SYSTEM' tenant.
          if (ridA.contains('SYSTEM') || ridB.contains('SYSTEM')) {
            return false;
          }

          return true;
        },
        [Gen.interval(1, 10000)],
        numRuns: 100,
      );

      expect(
        held,
        isTrue,
        reason:
            'RIDs must embed tenant id as prefix and differ across tenants '
            '(Requirements 1.4, 1.5).',
      );
    });

    test('PBT: KYC key derivation differs per tenant — encrypting the same '
        'plaintext under different tenants produces different ciphertext '
        '(100 iterations)', () async {
      const plaintext = 'AADHAAR1234567890';

      for (int i = 0; i < 100; i++) {
        final tenantA = 'tenant-kyc-a-$i';
        final tenantB = 'tenant-kyc-b-$i';

        final ciphertextA = await KycFieldCrypto.encrypt(plaintext, tenantA);
        final ciphertextB = await KycFieldCrypto.encrypt(plaintext, tenantB);

        // Both must succeed.
        expect(ciphertextA, isNotNull);
        expect(ciphertextB, isNotNull);

        // Ciphertexts must differ (tenant isolation at crypto layer).
        expect(
          ciphertextA,
          isNot(equals(ciphertextB)),
          reason:
              'Same plaintext encrypted under tenant "$tenantA" and '
              '"$tenantB" must produce different ciphertext (Requirement 11.2).',
        );
      }
    });

    test('PBT: Cross-tenant decryption fails — ciphertext from tenant A '
        'cannot be decrypted by tenant B (100 iterations)', () async {
      for (int i = 0; i < 100; i++) {
        final tenantA = 'tenant-cross-a-$i';
        final tenantB = 'tenant-cross-b-$i';
        final plaintext = 'ID-NUMBER-$i-${i * 37}';

        final ciphertext = await KycFieldCrypto.encrypt(plaintext, tenantA);
        expect(ciphertext, isNotNull);

        // Attempt decryption under a different tenant.
        final result = await KycFieldCrypto.decrypt(ciphertext, tenantB);

        // Must either fail or produce a different (garbage) value.
        if (!result.hasError) {
          // If decryption didn't throw, the value must NOT equal plaintext.
          expect(
            result.value,
            isNot(equals(plaintext)),
            reason:
                'Cross-tenant decryption must not yield the original '
                'plaintext (Requirement 11.2).',
          );
        }
        // If hasError is true, that's the expected isolation behavior.
      }
    });
  });

  // ==========================================================================
  // Task 6.11 — Example test: Assert the ten capabilities are present in the
  //             jewellery grant
  // **Validates: Requirements 9.1, 9.2**
  // ==========================================================================
  group('Feature: jewellery-vertical-remediation, '
      'Example: Ten capabilities present in jewellery grant', () {
    test(
      'The jewellery registry entry contains all 10 required capabilities',
      () {
        final jewelleryGrant = businessCapabilityRegistry['jewellery'];

        expect(
          jewelleryGrant,
          isNotNull,
          reason: 'Jewellery must have a capability registry entry (9.1)',
        );

        // The 8 new jewellery-domain capabilities.
        for (final cap in _jewelleryOnlyCapabilities) {
          expect(
            jewelleryGrant!.contains(cap),
            isTrue,
            reason:
                '${cap.name} must be granted to jewellery (Requirement 9.1)',
          );
        }

        // The 2 shared capabilities.
        for (final cap in _sharedCapabilities) {
          expect(
            jewelleryGrant!.contains(cap),
            isTrue,
            reason:
                '${cap.name} must be granted to jewellery (Requirement 9.2)',
          );
        }
      },
    );

    test('FeatureResolver.canAccess confirms all 10 for jewellery', () {
      for (final cap in _allTenCapabilities) {
        expect(
          FeatureResolver.canAccess('jewellery', cap),
          isTrue,
          reason:
              'FeatureResolver.canAccess("jewellery", ${cap.name}) must '
              'be true (Requirement 9.4)',
        );
      }
    });

    test(
      'The 8 jewellery-domain capabilities are NOT granted to any other type',
      () {
        for (final type in _nonJewelleryTypes) {
          for (final cap in _jewelleryOnlyCapabilities) {
            expect(
              FeatureResolver.canAccess(type.name, cap),
              isFalse,
              reason:
                  '${cap.name} must NOT be granted to ${type.name} '
                  '(Requirement 9.5)',
            );
          }
        }
      },
    );
  });
}
