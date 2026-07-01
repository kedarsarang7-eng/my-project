/// Phase 5 Bug-Condition Exploration Test — Electronics Dashboard Data Integrity
///
/// **Validates: Requirements 2.17, 2.18, 2.19**
///
/// **Property 7: Bug Condition** — Dashboard data truthfulness.
///
/// This test encodes the EXPECTED behavior (what SHOULD happen after the fix).
/// It is run on UNFIXED code and is EXPECTED TO FAIL — failure confirms the bug
/// exists. DO NOT fix the test or the code when it fails.
///
/// Bug condition (from design):
///   `DashboardRender` where `businessType == electronics AND
///    countIsHardcodedLiteral(input)`
///
/// Expected behavior asserted (Property 7 / 2.17–2.19):
///   - Alert counts are computed from real tenant-scoped queries
///     (warranty-expiring from `IMEISerials.warrantyEndDate`; pending repairs
///     from the service-job source). With an EMPTY data source the rendered
///     counts MUST reflect zero (or an unavailable `...` indicator) — never the
///     hardcoded literals `'5'` / `'8'`.
///   - The "IMEI Lookup" quick action navigates to a functional destination
///     (no dead `onTap: () {}`).
///   - Electronics only runs the alert queries whose results are displayed: a
///     dedicated `electronicsAlertCountsProvider` drives the panel rather than
///     the generic `alertCountsProvider` lowStock/expiringSoon work.
///
/// EXPECTED OUTCOME on UNFIXED code: Test FAILS because
/// `business_alerts_widget.dart` renders literal `count: '5'` (Warranty
/// Expiring) and `count: '8'` (Pending Repairs) for the electronics+computerShop
/// branch, ignoring the real data source, and there is no
/// `electronicsAlertCountsProvider`.
///
/// PBT library: dartproptest ^0.2.1
///
/// Run: flutter test test/bug_condition/electronics_phase5_dashboard_integrity_exploration_test.dart
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartproptest/dartproptest.dart';
import 'package:get_it/get_it.dart';

import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/providers/app_state_providers.dart';
import 'package:dukanx/features/dashboard/v2/widgets/business_alerts_widget.dart';

// ---------------------------------------------------------------------------
// Test doubles for Riverpod overrides
// ---------------------------------------------------------------------------
class _FixedBusinessTypeNotifier extends BusinessTypeNotifier {
  _FixedBusinessTypeNotifier(this._type);
  final BusinessType _type;
  @override
  BusinessTypeState build() => BusinessTypeState(type: _type);
}

/// Minimal SessionManager fake so capability resolution / providers that read
/// `sl<SessionManager>()` do not blow up during the widget pump.
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
// The hardcoded literals the electronics branch renders today (bugfix.md
// 1.17): "Warranty Expiring" => '5', "Pending Repairs" => '8'.
// ---------------------------------------------------------------------------
const String _kWarrantyExpiringLiteral = '5';
const String _kPendingRepairsLiteral = '8';

/// Pumps the [BusinessAlertsWidget] for [type] with an EMPTY alert-counts data
/// source (simulating an empty DB), and returns the widget tester ready to
/// query. The `alertCountsProvider` is overridden to an empty map so any branch
/// driven by REAL data would render zero.
Future<void> _pumpElectronicsAlerts(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        businessTypeProvider.overrideWith(
          () => _FixedBusinessTypeNotifier(BusinessType.electronics),
        ),
        // Empty DB → every real-data-driven count should resolve to zero.
        alertCountsProvider.overrideWith(
          (ref) => Stream.value(<String, int>{}),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: BusinessAlertsWidget())),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Returns the rendered "count" badge text for the alert card whose title is
/// [title], or `null` when no such card is present. The alert card is a `Row`
/// containing, in order, the title `Text`, the subtitle `Text`, and the count
/// `Text` (the last `Text` descendant of the `Row`).
String? _countForTitle(WidgetTester tester, String title) {
  final titleFinder = find.text(title);
  if (titleFinder.evaluate().isEmpty) return null;

  final rowFinder = find
      .ancestor(of: titleFinder, matching: find.byType(Row))
      .first;
  final texts = tester
      .widgetList<Text>(
        find.descendant(of: rowFinder, matching: find.byType(Text)),
      )
      .map((t) => t.data)
      .whereType<String>()
      .toList();
  if (texts.isEmpty) return null;
  // [title, subtitle, count] — the count badge is the last Text in the Row.
  return texts.last;
}

void main() {
  setUpAll(() {
    final sl = GetIt.instance;
    if (!sl.isRegistered<SessionManager>()) {
      sl.registerSingleton<SessionManager>(_FakeSessionManager());
    }
  });

  tearDownAll(() {
    final sl = GetIt.instance;
    if (sl.isRegistered<SessionManager>()) {
      sl.unregister<SessionManager>();
    }
  });

  // =========================================================================
  // (1) Warranty-expiring count is NOT the hardcoded literal '5' (2.17)
  //
  // Bug: the electronics+computerShop branch renders `count: '5'` regardless of
  //   data. Expected (post-fix): with an empty DB the warranty-expiring count
  //   is computed from `IMEISerials.warrantyEndDate` and reflects zero.
  // =========================================================================
  group('Phase 5 Bug Condition — warranty-expiring count is real (2.17)', () {
    testWidgets(
      'empty DB: "Warranty Expiring" count is not the hardcoded literal "5"',
      (tester) async {
        await _pumpElectronicsAlerts(tester);

        final count = _countForTitle(tester, 'Warranty Expiring');
        expect(
          count,
          isNotNull,
          reason:
              'Electronics alerts panel should render a "Warranty Expiring" '
              'card (electronics holds useIMEI → supportsSerialNumber).',
        );
        expect(
          count,
          isNot(_kWarrantyExpiringLiteral),
          reason:
              'Counterexample: empty DB still shows "Warranty Expiring" = '
              '"$_kWarrantyExpiringLiteral". Bug (bugfix.md 1.17): '
              'business_alerts_widget.dart renders the hardcoded literal '
              "count: '5' for the electronics branch instead of a real "
              'tenant-scoped count from IMEISerials.warrantyEndDate. '
              'Rendered count: "$count"',
        );
      },
    );
  });

  // =========================================================================
  // (2) Pending-repairs count is NOT the hardcoded literal '8' (2.17)
  //
  // Bug: the electronics+computerShop branch renders `count: '8'` regardless of
  //   data. Expected (post-fix): with an empty DB the pending-repairs count is
  //   computed from the service-job source and reflects zero.
  // =========================================================================
  group('Phase 5 Bug Condition — pending-repairs count is real (2.17)', () {
    testWidgets(
      'empty DB: "Pending Repairs" count is not the hardcoded literal "8"',
      (tester) async {
        await _pumpElectronicsAlerts(tester);

        final count = _countForTitle(tester, 'Pending Repairs');
        expect(
          count,
          isNotNull,
          reason:
              'Electronics alerts panel should render a "Pending Repairs" card.',
        );
        expect(
          count,
          isNot(_kPendingRepairsLiteral),
          reason:
              'Counterexample: empty DB still shows "Pending Repairs" = '
              '"$_kPendingRepairsLiteral". Bug (bugfix.md 1.17): '
              'business_alerts_widget.dart renders the hardcoded literal '
              "count: '8' for the electronics branch instead of a real "
              'tenant-scoped count from the service-job source. '
              'Rendered count: "$count"',
        );
      },
    );
  });

  // =========================================================================
  // (3) A dedicated electronicsAlertCountsProvider drives the panel (2.17, 2.19)
  //
  // Bug: there is NO `electronicsAlertCountsProvider`; the electronics branch
  //   uses hardcoded literals and the generic `alertCountsProvider`
  //   lowStock/expiringSoon queries are run but never displayed (wasted work).
  // Expected (post-fix): a dedicated provider (mirroring
  //   mandiAlertCountsProvider / schoolAlertCountsProvider) supplies the
  //   electronics counts so only displayed queries run.
  // =========================================================================
  group('Phase 5 Bug Condition — dedicated electronics provider (2.17, 2.19)', () {
    test(
      'business_alerts_widget.dart defines electronicsAlertCountsProvider',
      () {
        final f = File(
          'lib/features/dashboard/v2/widgets/business_alerts_widget.dart',
        );
        expect(
          f.existsSync(),
          isTrue,
          reason: 'alerts widget source must exist',
        );
        final src = f.readAsStringSync();
        expect(
          src.contains('electronicsAlertCountsProvider'),
          isTrue,
          reason:
              'Counterexample: no electronicsAlertCountsProvider exists. Bug '
              '(bugfix.md 1.19 / 2.19): the electronics dashboard has no '
              'dedicated per-vertical alert provider, so it renders hardcoded '
              'literals and runs the generic alertCountsProvider '
              'lowStock/expiringSoon queries whose results are never displayed '
              '(wasted work).',
        );
      },
    );

    test('electronics branch no longer hardcodes the "5"/"8" alert literals', () {
      final f = File(
        'lib/features/dashboard/v2/widgets/business_alerts_widget.dart',
      );
      final src = f.readAsStringSync();

      // Narrow to the electronics/computerShop alerts branch so we don't match
      // unrelated literals elsewhere in the file.
      final branchStart = src.indexOf(
        'case BusinessType.electronics:\n      case BusinessType.computerShop:',
      );
      expect(
        branchStart,
        greaterThanOrEqualTo(0),
        reason: 'electronics+computerShop alerts branch should be present',
      );
      // The branch runs until the next `case BusinessType.` after it.
      final afterBranch = src.indexOf(
        'case BusinessType.',
        branchStart + 'case BusinessType.electronics:'.length,
      );
      final branchEnd = src.indexOf(
        'case BusinessType.',
        afterBranch + 'case BusinessType.computerShop:'.length,
      );
      final branch = src.substring(
        branchStart,
        branchEnd > 0 ? branchEnd : src.length,
      );

      final hasWarrantyLiteral = RegExp(
        r"title:\s*'Warranty Expiring'[\s\S]*?count:\s*'5'",
      ).hasMatch(branch);
      final hasRepairsLiteral = RegExp(
        r"title:\s*'Pending Repairs'[\s\S]*?count:\s*'8'",
      ).hasMatch(branch);

      expect(
        hasWarrantyLiteral || hasRepairsLiteral,
        isFalse,
        reason:
            'Counterexample: the electronics alerts branch still hardcodes '
            "count: '5' (Warranty Expiring) and/or count: '8' (Pending "
            'Repairs). Bug (bugfix.md 1.17). These must be driven by a real '
            'tenant-scoped provider.',
      );
    });
  });

  // =========================================================================
  // (4) "IMEI Lookup" quick action navigates — it is not a dead onTap (2.18)
  //
  // Expected (post-fix): the IMEI Lookup quick action navigates to a functional
  //   serial/IMEI lookup destination rather than `onTap: () {}`.
  //
  // NOTE: This is verified by source inspection of the electronics quick-action
  //   block in business_quick_actions.dart.
  // =========================================================================
  group('Phase 5 Bug Condition — IMEI Lookup quick action navigates (2.18)', () {
    test('IMEI Lookup quick action has a real (non-empty) onTap', () {
      final f = File(
        'lib/features/dashboard/v2/widgets/business_quick_actions.dart',
      );
      expect(f.existsSync(), isTrue, reason: 'quick actions source must exist');
      final src = f.readAsStringSync();

      final idx = src.indexOf("label: 'IMEI Lookup'");
      expect(
        idx,
        greaterThanOrEqualTo(0),
        reason: 'an "IMEI Lookup" quick action should exist',
      );

      // Inspect the onTap immediately following the IMEI Lookup label.
      final window = src.substring(idx, (idx + 240).clamp(0, src.length));
      final deadOnTap = RegExp(r'onTap:\s*\(\)\s*\{\s*\}').hasMatch(window);
      expect(
        deadOnTap,
        isFalse,
        reason:
            'Counterexample: the "IMEI Lookup" quick action is a dead '
            'onTap: () {} (bugfix.md 1.18) — tapping it gives no navigation '
            'or feedback. It must navigate to a functional serial/IMEI lookup '
            'destination.',
      );
    });
  });

  // =========================================================================
  // (5) Scoped property — for each displayed electronics alert card the count
  //     is NOT the hardcoded literal it currently uses.
  //
  // Combines the per-card assertions into a single property over the two
  // hardcoded electronics alert cards. It WILL FAIL on unfixed code because the
  // electronics branch renders the literals regardless of data.
  // =========================================================================
  group('Phase 5 Bug Condition — PBT: no hardcoded electronics alert counts', () {
    testWidgets('PBT: empty DB → electronics alert counts are not "5"/"8"', (
      tester,
    ) async {
      await _pumpElectronicsAlerts(tester);

      // index 0 → Warranty Expiring (literal '5')
      // index 1 → Pending Repairs   (literal '8')
      const cards = <String, String>{
        'Warranty Expiring': _kWarrantyExpiringLiteral,
        'Pending Repairs': _kPendingRepairsLiteral,
      };
      final titles = cards.keys.toList();

      forAll(
        (int idx) {
          final title = titles[idx % titles.length];
          final literal = cards[title]!;
          final count = _countForTitle(tester, title);
          // The card must be present and must NOT render the hardcoded literal.
          if (count != null) {
            expect(
              count,
              isNot(literal),
              reason:
                  'Property violated: with an empty DB the electronics "$title" '
                  'card still renders the hardcoded literal "$literal" instead '
                  'of a real tenant-scoped count. Bug (bugfix.md 1.17). '
                  'Rendered count: "$count"',
            );
          }
          return true;
        },
        [Gen.interval(0, titles.length - 1)],
        numRuns: titles.length,
      );
    });
  });
}
