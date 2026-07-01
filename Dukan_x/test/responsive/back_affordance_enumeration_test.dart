// ============================================================================
// Task 8.2 — BACK/DISMISS AFFORDANCE ENUMERATION TEST (non-PBT, structural)
// Feature: mobile-text-scale-responsive-hardening
// **Validates: Requirement 9.2** — "THE DukanX_App SHALL present back
//   navigation consistently so that every Feature_Screen reachable by forward
//   navigation, including modal dialogs and onboarding flows, provides a back
//   or dismiss affordance."
// ============================================================================
//
// WHAT THIS TEST DOES
//   It statically enumerates every forward-reachable *surface* under
//   `lib/features/**` — a screen (anything that builds a `Scaffold` or a
//   `DesktopContentContainer`) or a modal dialog (anything that builds an
//   `AlertDialog` / `SimpleDialog` / `Dialog` / `showDialog`) — and asserts
//   that each one exposes a back/close/dismiss affordance.
//
//   A surface is considered AFFORDANCE-BEARING when its source contains at
//   least one recognised mechanism:
//     * SCREENS:
//         - `DesktopContentContainer(...)` — the shared content shell, which
//           auto-injects a Back button whenever `Navigator.canPop()` is true
//           (see lib/widgets/desktop/desktop_content_container.dart).
//         - a Material `AppBar` / `SliverAppBar` / `CupertinoNavigationBar` —
//           Flutter auto-injects a Back button when the route can pop.
//         - an explicit close/back control: `Icons.close`, `Icons.arrow_back`
//           (and its rounded/ios variants), or `Icons.chevron_left`.
//         - a wired pop: `Navigator.(of(context).)pop`, `.maybePop(`,
//           `context.pop(` / `context.maybePop(`.
//     * DIALOGS additionally accept the natural dialog-dismiss mechanisms:
//         - an `actions:` list (Cancel/OK/Close buttons), a `TextButton`, a
//           `CloseButton`, or `barrierDismissible` (tap-outside to dismiss).
//
//   Surfaces that legitimately do NOT expose a back/dismiss affordance — app
//   entry points (splash, license, auth gate, onboarding, first-run language
//   pickers), module dashboards/home tabs (which are roots, not forward
//   destinations), tab content embedded inside a parent dashboard/shell that
//   owns the navigation chrome, and non-route integration/service helpers that
//   merely contain a `Scaffold` — are captured in a DOCUMENTED, CATEGORISED
//   allowlist below. Each entry carries the reason it is exempt.
//
// WHY THIS IS THE REGRESSION GATE FOR R9.2
//   The value of this test is forward-looking: the moment a NEW
//   forward-reachable screen or dialog is added without any back/dismiss
//   affordance — and without a justified allowlist entry — the suite fails and
//   names the offending file. That is exactly the "back navigation presented
//   consistently" guarantee R9.2 asks for, enforced structurally.
//
// HONESTY CONTRACT
//   - The allowlist is the CURRENT baseline of known exempt surfaces. It is not
//     a silent suppression: every entry is categorised with a reason, and the
//     test asserts every allowlisted path still resolves (so the list cannot
//     rot into stale entries that hide real regressions).
//   - Two embedded self-tests prove the classifier actually fires (flags a
//     surface with no affordance) and does not over-fire (passes a surface with
//     an AppBar / DesktopContentContainer), so a green run is meaningful.
//
// CONVENTIONS
//   Mirrors the source-scanning style of
//   `test/responsive/unbounded_font_audit_test.dart` and
//   `test/tool/responsive_audit_totality_property_test.dart`: pure `dart:io`,
//   comment/string-stripped scanning, CWD = package root (so `lib/...`
//   resolves under `flutter test`).
//
// Run: flutter test test/responsive/back_affordance_enumeration_test.dart -r expanded
// ============================================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Surface + affordance token vocabularies
// ---------------------------------------------------------------------------

/// A file builds a SCREEN surface when it contains one of these tokens.
const List<String> kScreenSurfaceTokens = <String>[
  'Scaffold(',
  'DesktopContentContainer(',
];

/// A file builds a DIALOG surface when it contains one of these tokens
/// (and is not already classified as a screen).
const List<String> kDialogSurfaceTokens = <String>[
  'AlertDialog(',
  'SimpleDialog(',
  'Dialog(', // also matches showDialog( / showmodal..Dialog(
];

/// Mechanisms that satisfy the back/close affordance for a SCREEN surface.
const List<String> kScreenAffordanceTokens = <String>[
  // Shared shell — auto-injects Back when Navigator.canPop().
  'DesktopContentContainer(',
  // Material/Cupertino bars auto-inject Back when the route can pop.
  'AppBar(',
  'SliverAppBar(',
  'CupertinoNavigationBar(',
  // Explicit close / back controls.
  'Icons.close',
  'Icons.arrow_back',
  'Icons.arrow_back_ios',
  'Icons.arrow_back_ios_new',
  'Icons.arrow_back_rounded',
  'Icons.chevron_left',
  'CloseButton(',
  'BackButton(',
  // Wired pop / dismiss.
  'Navigator.of(context).pop',
  'Navigator.pop(',
  'Navigator.of(context).maybePop',
  '.maybePop(',
  'context.pop(',
  'context.maybePop(',
];

/// Mechanisms that satisfy the dismiss affordance for a DIALOG surface
/// (in addition to all screen affordances above).
const List<String> kDialogAffordanceTokens = <String>[
  'actions:', // Cancel/OK/Close action buttons
  'TextButton', // action buttons
  'CloseButton',
  'barrierDismissible', // tap-outside to dismiss
];

// ---------------------------------------------------------------------------
// Documented allowlist of surfaces that are exempt from R9.2 by design.
// Paths are package-root relative with forward slashes.
// ---------------------------------------------------------------------------

/// (A) App ENTRY POINTS / GATES — the first surface(s) on launch or
/// blocking gates reached by replace-style navigation, not by forward push.
/// A back affordance here would either exit the app or bypass the gate.
const List<String> kEntryAndGateSurfaces = <String>[
  'lib/features/splash/splash_screen.dart',
  'lib/features/auth/presentation/screens/auth_wrapper.dart',
  'lib/features/auth/presentation/screens/license_screen.dart',
  'lib/features/auth/presentation/widgets/security_upgrade_prompt.dart',
  'lib/features/subscription/presentation/widgets/trial_expired_gate_widget.dart',
  'lib/features/onboarding/login_onboarding_screen.dart',
  'lib/features/onboarding/vendor_onboarding_screen.dart',
  'lib/features/localization/presentation/screens/language_selection_screen.dart',
  'lib/features/localization/presentation/screens/language_setup_screen.dart',
];

/// (B) MODULE DASHBOARDS / HOME ROOTS — top-level home surfaces selected from
/// the business-type chooser or shown as a module's landing tab host. They are
/// navigation ROOTS (not forward destinations), so there is nothing to pop to.
const List<String> kDashboardRootSurfaces = <String>[
  'lib/features/dashboard/presentation/screens/dashboard_controller.dart',
  'lib/features/dashboard/presentation/screens/dashboard_selection_screen.dart',
  'lib/features/dashboard/v2/screens/pharmacy_dashboard_screen.dart',
  'lib/features/academic_coaching/presentation/screens/ac_dashboard_screen.dart',
  'lib/features/decoration_catering/presentation/screens/dc_dashboard_screen.dart',
  'lib/features/jewellery/presentation/screens/jewellery_dashboard_screen.dart',
  'lib/features/petrol_pump/presentation/screens/revenue_dashboard_screen.dart',
  'lib/features/restaurant/presentation/screens/restaurant_owner_command_screen.dart',
];

/// (C) EMBEDDED TAB CONTENT — surfaces rendered INSIDE a parent dashboard/
/// wrapper (e.g. AcScreenWrapper / the module dashboard's tab body) that owns
/// the back/navigation chrome. They are never pushed as standalone routes, so
/// the affordance lives on the parent, not the tab.
const List<String> kEmbeddedTabSurfaces = <String>[
  'lib/features/academic_coaching/presentation/widgets/ac_screen_wrapper.dart',
  'lib/features/academic_coaching/presentation/screens/ac_attendance_screen.dart',
  'lib/features/academic_coaching/presentation/screens/ac_bulk_operations_screen.dart',
  'lib/features/academic_coaching/presentation/screens/ac_certificate_generator_screen.dart',
  'lib/features/academic_coaching/presentation/screens/ac_courses_screen.dart',
  'lib/features/academic_coaching/presentation/screens/ac_faculty_screen.dart',
  'lib/features/academic_coaching/presentation/screens/ac_financial_reports_screen.dart',
  'lib/features/academic_coaching/presentation/screens/ac_notifications_screen.dart',
  'lib/features/academic_coaching/presentation/screens/ac_risk_detection_screen.dart',
  'lib/features/decoration_catering/presentation/screens/dc_profitability_screen.dart',
  'lib/features/decoration_catering/presentation/screens/dc_reports_screen.dart',
  'lib/features/decoration_catering/presentation/screens/dc_shopping_list_screen.dart',
  'lib/features/decoration_catering/presentation/screens/dc_staff_attendance_screen.dart',
];

/// (D) NON-ROUTE INTEGRATION / SERVICE HELPERS — files that contain a
/// `Scaffold`/dialog token but are not standalone navigable screens (they wrap
/// or decorate another screen, or are boot-time services). The wrapped screen
/// / host route carries the affordance.
const List<String> kNonRouteHelperSurfaces = <String>[
  'lib/features/barcode/integration/delivery_challan_barcode_integration.dart',
  'lib/features/barcode/integration/stock_entry_barcode_integration.dart',
  'lib/features/clinic/services/clinic_license_service.dart',
];

/// (E) DESKTOP SHELL-CONTENT SCREENS — full-bleed screens that render inside
/// the desktop root shell's content area (the shell's sidebar/top-bar provides
/// navigation) and use a raw `Scaffold` body without their own chrome. None of
/// these is registered as a standalone forward route — they are only ever shown
/// as content inside a parent shell that owns the navigation chrome:
///   * alerts_notifications_screen — rendered by `sidebar_navigation_handler`
///     (case 'alerts') as shell content.
///   * book_pos_screen / desktop_invoices_screen — exported as shell-content
///     surfaces; no GoRoute/MaterialPageRoute pushes them full-screen.
///
/// REVIEW NOTE: if any of these is ever pushed full-screen on mobile as a
/// standalone route, it MUST gain its own back/close affordance (or adopt
/// DesktopContentContainer). They are listed explicitly so the exemption is
/// visible and revisitable.
///
/// NOTE: the two jewellery screens (gold_rate_management, making_charges_
/// calculator) were PREVIOUSLY listed here but are registered as standalone
/// GoRoutes (/jewellery/gold-rate, /jewellery/rates, /jewellery/making-charges)
/// and pushed full-screen, so they were a genuine R9.2 gap. They now carry
/// their own AppBar back affordance and have been removed from this allowlist —
/// the enumeration test below now actively enforces that fix.
const List<String> kShellContentSurfaces = <String>[
  'lib/features/book_store/presentation/screens/book_pos_screen.dart',
  'lib/features/billing/presentation/screens/desktop_invoices_screen.dart',
  'lib/features/alerts/presentation/screens/alerts_notifications_screen.dart',
];

/// The full exempt set, normalised to forward-slash package-root paths.
Set<String> get kAllowlistedSurfaces => <String>{
  ...kEntryAndGateSurfaces,
  ...kDashboardRootSurfaces,
  ...kEmbeddedTabSurfaces,
  ...kNonRouteHelperSurfaces,
  ...kShellContentSurfaces,
};

// ---------------------------------------------------------------------------
// Classification result types
// ---------------------------------------------------------------------------

enum SurfaceKind { screen, dialog }

class Surface {
  Surface(this.path, this.kind, this.hasAffordance);
  final String path; // package-root relative, forward slashes
  final SurfaceKind kind;
  final bool hasAffordance;
}

void main() {
  group('Feature: mobile-text-scale-responsive-hardening, Requirement 9.2: '
      'forward-reachable surfaces expose a back/dismiss affordance', () {
    // ---- Self-tests: prove the classifier is non-trivial --------------

    test('self-test: a Scaffold screen with NO affordance is flagged', () {
      const src = '''
class FooScreen extends StatelessWidget {
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('hi')));
  }
}
''';
      final s = classifySurface('synthetic_screen.dart', src);
      expect(s, isNotNull);
      expect(s!.kind, SurfaceKind.screen);
      expect(
        s.hasAffordance,
        isFalse,
        reason: 'A bare Scaffold with no back/close control is uncovered.',
      );
    });

    test('self-test: a screen using DesktopContentContainer is covered', () {
      const src = '''
class FooScreen extends StatelessWidget {
  Widget build(BuildContext context) {
    return DesktopContentContainer(title: 'Foo', child: SizedBox());
  }
}
''';
      final s = classifySurface('synthetic_dcc.dart', src);
      expect(s, isNotNull);
      expect(s!.hasAffordance, isTrue);
    });

    test('self-test: a screen with an AppBar is covered', () {
      const src = '''
Widget build(BuildContext context) {
  return Scaffold(appBar: AppBar(title: Text('x')), body: SizedBox());
}
''';
      final s = classifySurface('synthetic_appbar.dart', src);
      expect(s!.hasAffordance, isTrue);
    });

    test('self-test: an explicit Navigator.pop close control is covered', () {
      const src = '''
Widget build(BuildContext context) {
  return Scaffold(
    body: IconButton(
      icon: const Icon(Icons.close),
      onPressed: () => Navigator.of(context).pop(),
    ),
  );
}
''';
      final s = classifySurface('synthetic_close.dart', src);
      expect(s!.hasAffordance, isTrue);
    });

    test('self-test: a dialog with action buttons is covered', () {
      const src = '''
Future<void> confirm(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Sure?'),
      actions: [TextButton(onPressed: () {}, child: const Text('Cancel'))],
    ),
  );
}
''';
      final s = classifySurface('synthetic_dialog.dart', src);
      expect(s, isNotNull);
      expect(s!.kind, SurfaceKind.dialog);
      expect(s.hasAffordance, isTrue);
    });

    test('self-test: a comment mentioning Navigator.pop does NOT count', () {
      const src = '''
// This screen used to call Navigator.of(context).pop() but no longer does.
class FooScreen extends StatelessWidget {
  Widget build(BuildContext context) => Scaffold(body: SizedBox());
}
''';
      final s = classifySurface('synthetic_comment.dart', src);
      expect(
        s!.hasAffordance,
        isFalse,
        reason: 'Tokens inside comments must be stripped before matching.',
      );
    });

    // ---- Allowlist hygiene -------------------------------------------

    test('every allowlisted surface path still resolves (no stale '
        'entries)', () {
      final missing = <String>[];
      for (final rel in kAllowlistedSurfaces) {
        if (!File(rel).existsSync()) missing.add(rel);
      }
      expect(
        missing,
        isEmpty,
        reason:
            'Allowlisted surfaces that no longer exist (remove them from the '
            'allowlist to keep it honest):\n${missing.map((m) => '  - $m').join('\n')}',
      );
    });

    // ---- The real enumeration ----------------------------------------

    test('every forward-reachable surface under lib/features exposes a '
        'back/dismiss affordance, or is a documented exempt surface '
        '(R9.2)', () {
      final featuresDir = Directory('lib/features');
      expect(
        featuresDir.existsSync(),
        isTrue,
        reason:
            'lib/features must resolve from the package root '
            '(CWD under flutter test).',
      );

      final allowlist = kAllowlistedSurfaces;
      final uncovered = <String>[];
      var screenCount = 0;
      var dialogCount = 0;

      for (final entity in featuresDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final rel = _relPath(entity.path);
        final surface = classifySurface(rel, entity.readAsStringSync());
        if (surface == null) continue; // not a navigable surface

        if (surface.kind == SurfaceKind.screen) {
          screenCount++;
        } else {
          dialogCount++;
        }

        if (surface.hasAffordance) continue;
        if (allowlist.contains(rel)) continue;
        uncovered.add('${surface.kind.name}: $rel');
      }

      // Sanity: the scan must actually find a substantial surface universe,
      // otherwise a path/CWD regression could vacuously pass this test.
      expect(
        screenCount + dialogCount,
        greaterThan(200),
        reason:
            'Expected to enumerate the full feature surface set; found only '
            '${screenCount + dialogCount}. Check the scan root / CWD.',
      );

      expect(
        uncovered,
        isEmpty,
        reason:
            'Forward-reachable surface(s) with NO back/dismiss affordance and '
            'NO documented allowlist entry (violates Requirement 9.2). Either '
            'add a back/close affordance (or DesktopContentContainer/AppBar), '
            'or, if genuinely exempt, add the path to the categorised '
            'allowlist with a reason:\n'
            '${uncovered.map((u) => '  - $u').join('\n')}',
      );
    });
  });
}

// ============================================================================
// Pure classification logic (exported for the self-tests above)
// ============================================================================

/// Classifies [content] (source of [path]) as a navigable [Surface], or
/// returns null when the file does not build a screen or dialog surface.
///
/// Comments and string literals are stripped first so that tokens appearing in
/// documentation or text content never trigger a (mis)classification.
Surface? classifySurface(String path, String content) {
  final code = _stripCommentsAndStrings(content);
  final rel = path.replaceAll('\\', '/');

  final isScreen = _containsAny(code, kScreenSurfaceTokens);
  final isDialog = !isScreen && _containsAny(code, kDialogSurfaceTokens);

  if (!isScreen && !isDialog) return null;

  if (isScreen) {
    final covered = _containsAny(code, kScreenAffordanceTokens);
    return Surface(rel, SurfaceKind.screen, covered);
  }

  // Dialog surface: screen affordances OR dialog-dismiss mechanisms count.
  final covered =
      _containsAny(code, kScreenAffordanceTokens) ||
      _containsAny(code, kDialogAffordanceTokens);
  return Surface(rel, SurfaceKind.dialog, covered);
}

bool _containsAny(String haystack, List<String> needles) {
  for (final n in needles) {
    if (haystack.contains(n)) return true;
  }
  return false;
}

/// Package-root relative, forward-slash path for an absolute scan path.
String _relPath(String absolute) {
  final norm = absolute.replaceAll('\\', '/');
  final idx = norm.indexOf('lib/features/');
  return idx >= 0 ? norm.substring(idx) : norm;
}

/// Replaces the body of string literals and comments with spaces (preserving
/// newlines) so structural scanning is not confused by tokens that appear in
/// literals or comments. Mirrors the helper in unbounded_font_audit_test.dart.
String _stripCommentsAndStrings(String src) {
  final out = StringBuffer();
  var i = 0;
  final n = src.length;
  while (i < n) {
    final c = src[i];
    final next = i + 1 < n ? src[i + 1] : '';

    // Line comment.
    if (c == '/' && next == '/') {
      while (i < n && src[i] != '\n') {
        out.write(' ');
        i++;
      }
      continue;
    }
    // Block comment.
    if (c == '/' && next == '*') {
      out.write('  ');
      i += 2;
      while (i < n && !(src[i] == '*' && i + 1 < n && src[i + 1] == '/')) {
        out.write(src[i] == '\n' ? '\n' : ' ');
        i++;
      }
      if (i < n) {
        out.write('  ');
        i += 2;
      }
      continue;
    }
    // String literals (single or double quote, with escapes).
    if (c == '\'' || c == '"') {
      final quote = c;
      out.write(' ');
      i++;
      while (i < n) {
        if (src[i] == '\\') {
          out.write('  ');
          i += 2;
          continue;
        }
        if (src[i] == quote) {
          out.write(' ');
          i++;
          break;
        }
        out.write(src[i] == '\n' ? '\n' : ' ');
        i++;
      }
      continue;
    }

    out.write(c);
    i++;
  }
  return out.toString();
}
