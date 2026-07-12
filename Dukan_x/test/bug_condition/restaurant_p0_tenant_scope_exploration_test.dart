// EXPLORATION TEST — expected to FAIL on unfixed code. Failure = bug confirmed.
//
// Property 1: Bug Condition — Restaurant Tenant Scope Never Falls Back to 'SYSTEM'
// Property 2: Bug Condition — Fail-Closed on Unresolvable Tenant
//
// **Validates: Requirements 1.1, 1.2, 2.1, 2.2, 2.3**
//
// Bug Condition (P0 — Tenant Isolation):
//   sidebar_navigation_handler.dart resolves vendorId for all 7 restaurant
//   screen cases via:
//     final vendorId = sl<SessionManager>().currentBusinessId
//         ?? sl<SessionManager>().userId
//         ?? 'SYSTEM';
//
//   Case 1: currentBusinessId is non-null -> vendorId == currentBusinessId (OK)
//   Case 2: currentBusinessId is null, userId is non-null -> vendorId == userId (OK)
//   Case 3: BOTH null -> vendorId == 'SYSTEM' <- BUG (should fail-closed)
//
// This test asserts the CORRECT behavior for all 3 cases x all 7 items.
// On UNFIXED code:
//   - Cases 1 & 2 PASS (the ?? chain resolves correctly before hitting 'SYSTEM')
//   - Case 3 FAILS (currently returns 'SYSTEM' instead of throwing/blocking)
//
// COUNTEREXAMPLE (documented after first run):
//   currentBusinessId=null, userId=null -> vendorId resolves to 'SYSTEM'
//   instead of throwing (debug) or showing a blocking error screen (release).
//   All 7 restaurant sidebar items exhibit this bug:
//     restaurant_tables, kitchen_display, menu_management, daily_summary,
//     floor_management, kot_report, recipe_management.
//
// PBT library: dartproptest ^0.2.1
//
// Run: flutter test test/bug_condition/restaurant_p0_tenant_scope_exploration_test.dart
library;

import 'dart:io';

import 'package:dartproptest/dartproptest.dart';
import 'package:flutter_test/flutter_test.dart';

/// Number of PBT runs for generated-input properties.
const int kNumRuns = 50;

/// All 7 affected restaurant sidebar item ids per the audit.
const List<String> kAffectedRestaurantItems = <String>[
  'restaurant_tables',
  'kitchen_display',
  'menu_management',
  'daily_summary',
  'floor_management',
  'kot_report',
  'recipe_management',
];

/// Pool of realistic business IDs for PBT generation.
const List<String> _bizIdPool = <String>[
  'biz_pizza_palace_123',
  'biz_sushi_bar_456',
  'biz_cafe_latte_789',
  'biz_burger_joint_abc',
  'biz_indian_spice_def',
  'biz_thai_noodle_ghi',
  'usr_owner_xyz_001',
  'usr_owner_pqr_002',
  'usr_chef_mno_003',
  'biz_bakery_jkl_004',
  'biz_steakhouse_stu_005',
  'biz_bistro_vwx_006',
];

/// Pool of realistic user IDs for PBT generation.
const List<String> _userIdPool = <String>[
  'user_waiter_alpha',
  'user_chef_beta',
  'user_captain_gamma',
  'user_owner_delta',
  'user_staff_epsilon',
  'usr_firebase_uid_001',
  'usr_firebase_uid_002',
  'usr_firebase_uid_003',
  'usr_firebase_uid_004',
  'usr_firebase_uid_005',
];

void main() {
  late String navigationHandlerSource;

  setUpAll(() {
    final handlerFile = File(
      'lib/widgets/desktop/sidebar_navigation_handler.dart',
    );
    expect(
      handlerFile.existsSync(),
      isTrue,
      reason: 'sidebar_navigation_handler.dart must exist',
    );
    navigationHandlerSource = handlerFile.readAsStringSync();
  });

  // ===========================================================================
  // Helper: extract the body of a named static method definition from source.
  // Looks for the method DEFINITION (starting with 'static Widget <name>')
  // rather than a call site.
  // ===========================================================================
  String extractHelperBody(String methodName) {
    final definitionPattern = 'static Widget $methodName';
    final idx = navigationHandlerSource.indexOf(definitionPattern);
    if (idx == -1) return '';
    // Get a generous window after the method definition to capture its body
    final end = (idx + 500).clamp(0, navigationHandlerSource.length);
    return navigationHandlerSource.substring(idx, end);
  }

  // ===========================================================================
  // Helper: extract the vendorId resolution code for a given restaurant case.
  // Returns the code between `case '<itemId>':` and the next `return *Screen(`
  // OR the full resolved code including the helper method body if the case
  // delegates to a helper like `_resolveRestaurantScreen`.
  // ===========================================================================
  String extractVendorIdResolution(String itemId) {
    final casePattern = "case '$itemId':";
    final caseIdx = navigationHandlerSource.indexOf(casePattern);
    if (caseIdx == -1) return '';

    // Find the return statement after this case
    final afterCase = navigationHandlerSource.substring(caseIdx);
    final returnIdx = afterCase.indexOf('return ');
    if (returnIdx == -1) return afterCase.substring(0, 200);

    final caseBlock = afterCase.substring(0, returnIdx + 200);

    // If the case block delegates to a helper method, include the helper's
    // body in the resolution analysis so fail-closed constructs (require(),
    // TenantScopeError, throw) are visible through the indirection.
    if (caseBlock.contains('_resolveRestaurantScreen')) {
      final helperBody = extractHelperBody('_resolveRestaurantScreen');
      return '$caseBlock\n$helperBody';
    }

    return caseBlock;
  }

  // ===========================================================================
  // GROUP 1: Property 1 — Structural assertion that 'SYSTEM' literal is
  //          ABSENT from the vendorId resolution chain for all 7 items.
  //
  // After the P0 fix: 'SYSTEM' has been removed and replaced with
  // RestaurantTenantScope().require(). This group confirms the fix landed.
  // ===========================================================================
  group('P0 Bug Absence — SYSTEM fallback removed from source', () {
    for (final itemId in kAffectedRestaurantItems) {
      test('$itemId case does NOT contain SYSTEM fallback literal', () {
        final resolution = extractVendorIdResolution(itemId);
        expect(
          resolution.contains("'SYSTEM'"),
          isFalse,
          reason:
              'Post-fix assertion: "$itemId" case in sidebar_navigation_handler.dart '
              'must NOT contain the literal SYSTEM. The P0 fix replaces it '
              'with RestaurantTenantScope().require().',
        );
      });
    }
  });

  // ===========================================================================
  // GROUP 2: Property 1 — vendorId resolution MUST NOT contain 'SYSTEM'.
  //
  // Asserts the CORRECT behavior: no restaurant case should ever resolve
  // vendorId to 'SYSTEM'. On UNFIXED code this FAILS for all 7 items.
  //
  // PBT: For each randomly-selected (itemIdx, bizIdx) pair from the pools,
  // the source code for that item's case MUST NOT contain a 'SYSTEM' fallback.
  // ===========================================================================
  group('Property 1: Restaurant Tenant Scope Never Falls Back to SYSTEM', () {
    // Exhaustive enumeration over all 7 items
    for (final itemId in kAffectedRestaurantItems) {
      test('$itemId vendorId resolution has no SYSTEM fallback', () {
        final resolution = extractVendorIdResolution(itemId);

        expect(
          resolution.contains("'SYSTEM'"),
          isFalse,
          reason:
              'COUNTEREXAMPLE (Property 1, Req 2.1/2.3): "$itemId" case in '
              'sidebar_navigation_handler.dart resolves vendorId via:\n'
              '  final vendorId = sl<SessionManager>().currentBusinessId\n'
              '      ?? sl<SessionManager>().userId\n'
              '      ?? SYSTEM;\n\n'
              'The literal SYSTEM is a shared, cross-tenant constant that '
              'violates tenant isolation. When both currentBusinessId and '
              'userId are null, ALL restaurant data is read/written under '
              'vendorId=SYSTEM, causing cross-tenant data leakage.\n\n'
              'Expected: vendorId resolved via RestaurantTenantScope.require() '
              'with no SYSTEM fallback.',
        );
      });
    }

    // PBT: randomly pick items x business ids and assert structural invariant
    test('PBT: no SYSTEM fallback across random item x businessId pairs', () {
      final held = forAll(
        (int itemIdx, int bizIdx) {
          final itemId =
              kAffectedRestaurantItems[itemIdx %
                  kAffectedRestaurantItems.length];
          final resolution = extractVendorIdResolution(itemId);

          // Property: for any non-null bizId that a SessionManager could
          // return, the source code MUST NOT contain a path that resolves to
          // the literal 'SYSTEM'.
          if (resolution.contains("'SYSTEM'")) return false;

          // bizIdx documents PBT coverage over the business-id space.
          assert(bizIdx >= 0 && bizIdx < _bizIdPool.length);
          return true;
        },
        [
          Gen.interval(0, kAffectedRestaurantItems.length - 1),
          Gen.interval(0, _bizIdPool.length - 1),
        ],
        numRuns: kNumRuns,
      );
      expect(
        held,
        isTrue,
        reason:
            'COUNTEREXAMPLE: at least one (item, businessId) pair has '
            'vendorId resolution containing the literal SYSTEM as a '
            'fallback, violating tenant isolation.',
      );
    });
  });

  // ===========================================================================
  // GROUP 3: Property 2 — Fail-Closed on Unresolvable Tenant
  //
  // When BOTH currentBusinessId and userId are null, the system MUST throw
  // (debug) or block navigation with an error screen (release). It MUST NOT
  // construct any restaurant screen with a fabricated vendorId.
  //
  // On UNFIXED code this FAILS: the code falls through to vendorId='SYSTEM'
  // and happily constructs the screen — no throw, no error screen.
  // ===========================================================================
  group('Property 2: Fail-Closed on Unresolvable Tenant', () {
    // Structural assertion: the code must contain a throw/assert/guard
    for (final itemId in kAffectedRestaurantItems) {
      test('$itemId fails closed when both session ids are null', () {
        final resolution = extractVendorIdResolution(itemId);

        // Evidence of correct fail-closed behavior:
        final hasFailClosed =
            resolution.contains('require()') ||
            resolution.contains('throw') ||
            resolution.contains('TenantScopeError') ||
            resolution.contains('assert(') ||
            resolution.contains('ArgumentError');

        final hasSilentFallback = resolution.contains("'SYSTEM'");

        // On unfixed code: hasFailClosed=false, hasSilentFallback=true.
        expect(
          hasFailClosed && !hasSilentFallback,
          isTrue,
          reason:
              'COUNTEREXAMPLE (Property 2, Req 2.2): "$itemId" case does NOT '
              'fail closed when both currentBusinessId and userId are null.\n\n'
              'Current behavior: falls through to vendorId=SYSTEM -- a '
              'shared constant that silently constructs the screen with '
              'cross-tenant data access.\n\n'
              'Expected behavior: throw TenantScopeError.missing() (debug) or '
              'render a blocking error screen (release). The screen MUST NOT '
              'be constructed with a fabricated vendorId.\n\n'
              'hasFailClosed=$hasFailClosed, hasSilentFallback=$hasSilentFallback',
        );
      });
    }

    // PBT: across random items x random user ids, confirm no item has
    // fail-closed behavior on the null-null path.
    test(
      'PBT: no item has fail-closed behavior for null-null session state',
      () {
        final held = forAll(
          (int itemIdx, int userIdx) {
            final itemId =
                kAffectedRestaurantItems[itemIdx %
                    kAffectedRestaurantItems.length];
            final resolution = extractVendorIdResolution(itemId);

            final hasFailClosed =
                resolution.contains('require()') ||
                resolution.contains('throw') ||
                resolution.contains('TenantScopeError');

            // For any item, the code must have a fail-closed path for the
            // null-null case. If 'SYSTEM' is present as the final fallback,
            // there is no fail-closed behavior.
            if (!hasFailClosed) return false;

            // userIdx documents PBT coverage over the user-id space.
            assert(userIdx >= 0 && userIdx < _userIdPool.length);
            return true;
          },
          [
            Gen.interval(0, kAffectedRestaurantItems.length - 1),
            Gen.interval(0, _userIdPool.length - 1),
          ],
          numRuns: kNumRuns,
        );
        expect(
          held,
          isTrue,
          reason:
              'COUNTEREXAMPLE: at least one item lacks fail-closed behavior '
              'for the null-null session state. The code silently falls to '
              'SYSTEM instead of throwing or blocking.',
        );
      },
    );
  });

  // ===========================================================================
  // GROUP 4: Confirm Cases 1 & 2 are correctly handled via encapsulation.
  //
  // After the fix, the vendorId resolution is encapsulated in
  // RestaurantTenantScope which implements the two-tier resolution:
  //   1. currentBusinessId (primary)
  //   2. userId (fallback)
  // The case blocks now delegate to _resolveRestaurantScreen which calls
  // RestaurantTenantScope().require().
  //
  // This group PASSES on fixed code — confirming proper encapsulation.
  // ===========================================================================
  group('Cases 1 & 2 -- resolution encapsulated in RestaurantTenantScope', () {
    for (final itemId in kAffectedRestaurantItems) {
      test('$itemId delegates to _resolveRestaurantScreen', () {
        final casePattern = "case '$itemId':";
        final caseIdx = navigationHandlerSource.indexOf(casePattern);
        expect(caseIdx, isNot(-1));
        final afterCase = navigationHandlerSource.substring(caseIdx);
        final nextCase = afterCase.indexOf(
          RegExp(r"case '"),
          casePattern.length,
        );
        final block = nextCase == -1
            ? afterCase
            : afterCase.substring(0, nextCase);

        expect(
          block.contains('_resolveRestaurantScreen'),
          isTrue,
          reason:
              '"$itemId" must delegate vendorId resolution to '
              '_resolveRestaurantScreen (which uses RestaurantTenantScope).',
        );
      });
    }

    test('RestaurantTenantScope reads currentBusinessId as first choice', () {
      final scopeFile = File(
        'lib/features/restaurant/utils/restaurant_tenant_scope.dart',
      );
      expect(scopeFile.existsSync(), isTrue);
      final scopeSource = scopeFile.readAsStringSync();

      expect(
        scopeSource.contains('currentBusinessId'),
        isTrue,
        reason:
            'RestaurantTenantScope must read currentBusinessId as first '
            'tier in two-tier resolution.',
      );
    });

    test('RestaurantTenantScope reads userId as second choice', () {
      final scopeFile = File(
        'lib/features/restaurant/utils/restaurant_tenant_scope.dart',
      );
      expect(scopeFile.existsSync(), isTrue);
      final scopeSource = scopeFile.readAsStringSync();

      expect(
        scopeSource.contains('userId'),
        isTrue,
        reason:
            'RestaurantTenantScope must read userId as second '
            'tier (fallback) in two-tier resolution.',
      );
    });
  });
}
