// ============================================================================
// PHASE 4 — Task 5.6: PROPERTY TEST
// Feature: gorouter-navigation-migration, Property 7: Grocery expiry support
// equals capability
// **Validates: Requirements 7.3**
// ============================================================================
//
// Property 7 (design.md):
//   "For any business type — and specifically for grocery — after the fix,
//    reported expiry support is true IF AND ONLY IF the batch-expiry capability
//    is granted to that type, so grocery matches other expiry-capable types."
//
// Task 5.5 changed `lib/core/config/business_capabilities.dart` so that
//   supportsExpiry: FeatureResolver.canAccess(t, BusinessCapability.useBatchExpiry)
// removing the prior `type != BusinessType.grocery` special-case. This suite
// proves the resulting biconditional holds across the WHOLE BusinessType space.
//
// SEAMS (per task):
//   - reported support : BusinessCapabilities.get(type).supportsExpiry
//   - capability grant : FeatureResolver.canAccess(type.name,
//                                                   BusinessCapability.useBatchExpiry)
//   Both are pure, deterministic functions of the business type — no widget
//   pumping, no provider container needed.
//
// This suite proves three facets:
//
//   7a. CORE BICONDITIONAL (>=100 generated iterations over the full
//       BusinessType space, incl. `other`):
//         BusinessCapabilities.get(type).supportsExpiry
//                   IFF
//         FeatureResolver.canAccess(type.name, useBatchExpiry)
//
//   7b. GROCERY-SPECIFIC (Req 7.3): grocery.supportsExpiry == true AND equals
//       canAccess(grocery, useBatchExpiry) — grocery now matches other
//       expiry-capable types (closes the forced-false self-contradiction).
//
//   7c. NON-VACUITY: a known expiry-capable type (pharmacy) reports true and a
//       known non-expiry type (petrolPump) reports false, proving the
//       biconditional is not trivially satisfied by a constant.
//
// PBT library: dartproptest (dev dependency; glados is unresolvable here — see
//   the dev_dependency note in pubspec.yaml). The variadic
//   `forAll((a) => boolExpr, [genA], numRuns: N)` runs `numRuns` generated
//   cases and returns whether the predicate held for all of them.
//
// TEST-ONLY: no production code is changed by this task.
//
// Run: flutter test test/core/config/phase4_property7_grocery_expiry_test.dart
// ============================================================================

import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/config/business_capabilities.dart';
import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/isolation/feature_resolver.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // At least 100 iterations are required by the spec; 200 matches the default
  // and the convention used across the other property suites in this repo.
  const int kNumRuns = 200;

  // --- Input space ----------------------------------------------------------
  // The ENTIRE BusinessType space, including `other`. The biconditional must
  // hold for every type — `other` resolves to a strict-deny in the registry,
  // so both sides are expected to be false there (still a valid biconditional).
  final List<BusinessType> allTypes = BusinessType.values;

  setUpAll(() {
    // The 18 in-scope types (design Data Model 4) plus `other` must all be
    // covered; guard against an empty/degenerate input space.
    expect(allTypes, isNotEmpty);
    expect(
      allTypes.where((t) => t != BusinessType.other).length,
      greaterThanOrEqualTo(18),
      reason: 'Property 7 input space includes the 18 in-scope types.',
    );
  });

  // --- Generators -----------------------------------------------------------
  final Generator<BusinessType> typeGen = Gen.elementOf<BusinessType>(allTypes);

  group('Feature: gorouter-navigation-migration, Property 7: Grocery expiry '
      'support equals capability — Req 7.3', () {
    // --------------------------------------------------------------------
    // Property 7a — CORE BICONDITIONAL (support iff capability).
    // --------------------------------------------------------------------
    test('Property 7: for any business type, supportsExpiry == '
        'canAccess(type, useBatchExpiry)', () {
      final held = forAll(
        (BusinessType type) {
          final bool reported = BusinessCapabilities.get(type).supportsExpiry;
          final bool granted = FeatureResolver.canAccess(
            type.name,
            BusinessCapability.useBatchExpiry,
          );
          // Biconditional: reported support IFF capability granted.
          return reported == granted;
        },
        [typeGen],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // --------------------------------------------------------------------
    // Property 7b — GROCERY-SPECIFIC (Req 7.3 / the fix).
    // --------------------------------------------------------------------
    test('Property 7: grocery supportsExpiry is true AND equals '
        'canAccess(grocery, useBatchExpiry)', () {
      final bool groceryReported = BusinessCapabilities.get(
        BusinessType.grocery,
      ).supportsExpiry;
      final bool groceryGranted = FeatureResolver.canAccess(
        BusinessType.grocery.name,
        BusinessCapability.useBatchExpiry,
      );

      expect(
        groceryGranted,
        isTrue,
        reason:
            'grocery must be granted useBatchExpiry after Task 5.5 '
            '(registry change).',
      );
      expect(
        groceryReported,
        isTrue,
        reason:
            'grocery.supportsExpiry must be true — the forced-false '
            'special-case was removed in Task 5.5.',
      );
      expect(
        groceryReported,
        equals(groceryGranted),
        reason: 'grocery now matches other expiry-capable types.',
      );
    });

    // --------------------------------------------------------------------
    // Property 7c — NON-VACUITY (true and false both occur).
    // pharmacy: known expiry-capable -> true.
    // petrolPump: known non-expiry type -> false.
    // --------------------------------------------------------------------
    test('Property 7: non-vacuity — pharmacy reports true, petrolPump reports '
        'false (biconditional is not a constant)', () {
      expect(
        BusinessCapabilities.get(BusinessType.pharmacy).supportsExpiry,
        isTrue,
        reason: 'pharmacy is a known expiry-capable type.',
      );
      expect(
        FeatureResolver.canAccess(
          BusinessType.pharmacy.name,
          BusinessCapability.useBatchExpiry,
        ),
        isTrue,
      );

      expect(
        BusinessCapabilities.get(BusinessType.petrolPump).supportsExpiry,
        isFalse,
        reason: 'petrolPump is a known non-expiry type.',
      );
      expect(
        FeatureResolver.canAccess(
          BusinessType.petrolPump.name,
          BusinessCapability.useBatchExpiry,
        ),
        isFalse,
      );
    });
  });
}
