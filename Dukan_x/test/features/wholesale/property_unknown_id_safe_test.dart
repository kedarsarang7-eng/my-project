// ============================================================================
// PROPERTY TEST: Unknown Id Navigation Is Safe
// ============================================================================
// Feature: wholesale-vertical-remediation, Property 8: Unknown id navigation is safe
//
// **Validates: Requirements 5.7**
//
// Generates random strings that are NOT valid wholesale sidebar ids, then
// verifies `getScreenForItem(randomId, context)` does NOT throw an unhandled
// exception. It may return null (current screen retained) or navigate to a
// default — but no crash.
//
// PBT library: dartproptest ^0.2.1.
//
// Run: flutter test test/features/wholesale/property_unknown_id_safe_test.dart
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';
import 'package:get_it/get_it.dart';

import 'package:dukanx/widgets/desktop/sidebar_configuration.dart';
import 'package:dukanx/widgets/desktop/sidebar_navigation_handler.dart';
import 'package:dukanx/core/session/session_manager.dart';

// ---------------------------------------------------------------------------
// Minimal SessionManager fake for navigation resolution tests.
// ---------------------------------------------------------------------------
class _FakeSessionManager extends ChangeNotifier implements SessionManager {
  @override
  String? get userId => 'test-vendor';
  @override
  String? get currentBusinessId => 'test-vendor';
  @override
  String? get ownerId => 'test-vendor';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Known invalid ids — deterministic adversarial inputs that are guaranteed NOT
// to be valid wholesale sidebar ids.
// ---------------------------------------------------------------------------
const List<String> kAdversarialIds = [
  '',
  ' ',
  '\t',
  '\n',
  'null',
  'undefined',
  'NaN',
  'Infinity',
  '__proto__',
  'constructor',
  'unknown_wholesale_id',
  'wholesale_nonexistent',
  'fake_screen_123',
  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  'test_id_with_special_!@#\$%^&*()',
  'café_résumé',
  'SELECT * FROM items',
  '../../../etc/passwd',
  'wholesale',
  'getWholesaleSections',
  '_getWholesaleSections',
  'sidebar_item_999',
  'nonexistent_section',
  'random_abc_def_ghi',
  'x',
  'XX',
  '123',
  '0',
  '-1',
  'true',
  'false',
  'Object',
  'Widget',
  'BuildContext',
  'main',
  'dispose',
  'setState',
  'wholesale_tiered_pricing',
  'wholesale_eway_bill',
  'wholesale_advanced_ar',
  'zombie_id',
  'phantom_screen',
  'legacy_redirect',
  'module_not_found',
];

/// Collects all valid wholesale sidebar item ids.
Set<String> validWholesaleIds() {
  final sections = getSectionsForBusinessType(BusinessType.wholesale);
  return sections.expand((s) => s.items).map((item) => item.id).toSet();
}

void main() {
  const int kNumRuns = 200;

  // Set up the minimal DI for SidebarNavigationHandler
  setUpAll(() {
    final sl = GetIt.instance;
    if (!sl.isRegistered<SessionManager>()) {
      sl.registerSingleton<SessionManager>(_FakeSessionManager());
    }
  });

  group(
    'Feature: wholesale-vertical-remediation, Property 8: Unknown id navigation is safe',
    () {
      late Set<String> validIds;

      setUp(() {
        validIds = validWholesaleIds();
      });

      // -----------------------------------------------------------------------
      // Property 8a: Known adversarial ids do not throw when passed to
      // getScreenForItem.
      // -----------------------------------------------------------------------
      testWidgets(
        'Property 8a: getScreenForItem does NOT throw for adversarial unknown ids',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) {
                  for (final id in kAdversarialIds) {
                    // Skip if this accidentally is a valid id
                    if (validIds.contains(id)) continue;

                    // This must NOT throw an unhandled exception.
                    Widget? result;
                    try {
                      result = SidebarNavigationHandler.getScreenForItem(
                        id,
                        context,
                      );
                    } catch (e) {
                      fail(
                        'Property 8 VIOLATED: getScreenForItem("$id") threw an '
                        'unhandled exception: $e. Unknown ids must be handled '
                        'safely (return placeholder or null, never crash).',
                      );
                    }

                    // getScreenForItem always returns a Widget (may be placeholder)
                    expect(
                      result,
                      isNotNull,
                      reason: 'getScreenForItem should always return a Widget',
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 8b: tryGetScreenForItem returns null gracefully for unknowns.
      // -----------------------------------------------------------------------
      testWidgets(
        'Property 8b: tryGetScreenForItem does NOT throw for adversarial unknown ids',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) {
                  for (final id in kAdversarialIds) {
                    if (validIds.contains(id)) continue;
                    try {
                      SidebarNavigationHandler.tryGetScreenForItem(id, context);
                    } catch (e) {
                      fail(
                        'Property 8 VIOLATED: tryGetScreenForItem("$id") threw: '
                        '$e. Must handle unknown ids without crashing.',
                      );
                    }
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 8c (forAll): dartproptest-generated random strings.
      // Uses Gen.printableAsciiString to produce arbitrary string ids.
      // -----------------------------------------------------------------------
      testWidgets(
        'Property 8c (forAll): dartproptest-generated random strings are safe '
        'to pass to getScreenForItem ($kNumRuns iterations)',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) {
                  final held = forAll(
                    (String randomId) {
                      // Skip if this accidentally generates a valid id
                      if (validIds.contains(randomId)) return true;

                      try {
                        SidebarNavigationHandler.getScreenForItem(
                          randomId,
                          context,
                        );
                        // No exception thrown — property holds
                        return true;
                      } catch (_) {
                        // Any unhandled exception means the property is violated
                        return false;
                      }
                    },
                    [Gen.printableAsciiString(minLength: 1, maxLength: 40)],
                    numRuns: kNumRuns,
                  );
                  expect(
                    held,
                    isTrue,
                    reason:
                        'Property 8: Unknown id navigation must be safe — '
                        'no unhandled exceptions for arbitrary string inputs',
                  );

                  return const SizedBox.shrink();
                },
              ),
            ),
          );
        },
      );

      // -----------------------------------------------------------------------
      // Property 8d (forAll): Index-based iteration over the adversarial list.
      // Provides at least 100 iterations as required.
      // -----------------------------------------------------------------------
      testWidgets(
        'Property 8d (forAll): indexed adversarial ids are all safe ($kNumRuns iterations)',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) {
                  final held = forAll(
                    (int index) {
                      final id =
                          kAdversarialIds[index % kAdversarialIds.length];
                      if (validIds.contains(id)) return true;

                      try {
                        SidebarNavigationHandler.getScreenForItem(id, context);
                        return true;
                      } catch (_) {
                        return false;
                      }
                    },
                    [Gen.interval(0, kAdversarialIds.length * 5)],
                    numRuns: kNumRuns,
                  );
                  expect(
                    held,
                    isTrue,
                    reason: 'Property 8: All adversarial ids must be safe',
                  );

                  return const SizedBox.shrink();
                },
              ),
            ),
          );
        },
      );
    },
  );
}
