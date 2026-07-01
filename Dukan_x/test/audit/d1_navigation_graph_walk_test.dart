// D1 — Navigation graph-walk integration test.
//
// Property: every `GoRoute` registered under `Dukan_x/lib/modules/<m>/routes/`
// resolves to a fully-implemented destination — not `ModulePlaceholderScreen`.
//
// This test is the regression guard for task 3.2.1 in the
// `billing-app-end-to-end-audit` spec. Before the fix, the same predicate
// is enforced inside the wider `bug_condition_audit_test.dart` D1 sub-test.
// Lifting it into a dedicated file lets future D1 work (drawer-gating,
// `PopScope`, etc.) extend this suite without churning the audit walker.
//
// The test is deliberately a *static walker* over the module route files
// rather than a widget-pump integration test: the running app currently
// uses the legacy `MaterialApp.routes` map (see
// `Dukan_x/lib/app/app.dart`), and the GoRouter migration is tracked
// separately. Until that migration lands, the canonical signal that a
// module route is "fully wired" is exactly the absence of
// `ModulePlaceholderScreen` from its builder body — every replacement is
// either a real `lib/features/<m>/presentation/screens/...` widget or a
// `LegacyRouteRedirect` to a working legacy named-route. Once the
// migration ships, a follow-up commit can extend this test with a real
// `GoRouter` widget pump per route.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'audit_walker.dart';

void main() {
  late final Directory ws;

  setUpAll(() {
    ws = resolveWorkspaceRoot();
  });

  test('D1: every Dukan_x module route resolves to a built screen '
      '(no ModulePlaceholderScreen)', () {
    final findings = <Finding>[];

    for (final m in dukanxModules) {
      final routesDir = Directory('${ws.path}/Dukan_x/lib/modules/$m/routes');
      if (!routesDir.existsSync()) continue;
      for (final f in listDartFiles(routesDir)) {
        final src = safeRead(f);
        final routeMatches = RegExp(
          r"GoRoute\(\s*path:\s*'([^']+)'",
        ).allMatches(src);
        for (final r in routeMatches) {
          final path = r.group(1)!;
          final maxEnd = (r.end + 200).clamp(0, src.length);
          final tail = src.substring(r.end, maxEnd);
          final closeIdx = tail.indexOf('),');
          final lineSrc = closeIdx >= 0
              ? src.substring(r.start, r.end + closeIdx + 1)
              : src.substring(r.start, maxEnd);
          if (lineSrc.contains('ModulePlaceholderScreen')) {
            findings.add(
              Finding(
                defectId: 'D1-DKX-$m-${path.hashCode.toUnsigned(16)}',
                app: 'Dukan_x',
                module: m,
                workflow: 'route $path',
                defectClass: 'D1',
                severity: 'blocker',
                repro:
                    "navigate to '$path' via drawer/deep-link in business-"
                    'type $m',
                observed:
                    'route in ${f.uri.pathSegments.last} resolves to '
                    "ModulePlaceholderScreen ('Coming soon')",
                expected:
                    'route resolves to a fully-implemented destination, or '
                    'redirects via LegacyRouteRedirect to a working legacy '
                    'named-route (clause 2.1)',
                fixScope:
                    'replace ModulePlaceholderScreen with the real screen '
                    'or a LegacyRouteRedirect to a sensible legacy entry',
              ),
            );
          }
        }
      }
    }

    expect(findings, isEmpty, reason: renderInventory('D1', findings));
  });

  test('D1: every Dukan_x module route imports either a real feature screen '
      'or LegacyRouteRedirect', () {
    // Hardening guard: a module route file that imports neither a
    // feature screen (`lib/features/<m>/...`) nor `legacy_route_redirect`
    // is by definition wiring routes to placeholders. This catches
    // regressions where someone reintroduces an inline placeholder class.
    final problems = <String>[];

    for (final m in dukanxModules) {
      final routesDir = Directory('${ws.path}/Dukan_x/lib/modules/$m/routes');
      if (!routesDir.existsSync()) continue;
      for (final f in listDartFiles(routesDir)) {
        final src = safeRead(f);
        if (!src.contains('GoRoute(')) continue;
        final usesRedirect = src.contains('legacy_route_redirect.dart');
        final usesFeatureScreen = src.contains("'../../../features/");
        // Files that define their own real Scaffold-backed widgets count
        // as "real screens" too (e.g. the grocery module routes file).
        final usesInlineRealScreen = RegExp(
          r'class\s+\w+Screen\s+extends\s+(Stateful|Stateless|Consumer)',
        ).hasMatch(src);
        if (!usesRedirect && !usesFeatureScreen && !usesInlineRealScreen) {
          problems.add(
            '${f.path.replaceAll(ws.path, '<ws>')}: imports neither a '
            'feature screen nor LegacyRouteRedirect — likely wired to a '
            'placeholder',
          );
        }
      }
    }

    expect(
      problems,
      isEmpty,
      reason:
          '\nD1 wiring regression — the following module-route files '
          'appear to be wired to placeholders:\n  ${problems.join('\n  ')}',
    );
  });
}
