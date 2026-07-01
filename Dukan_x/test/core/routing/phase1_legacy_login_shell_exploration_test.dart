// ============================================================================
// PHASE 1 — Legacy login -> shell EXPLORATION test (go_router navigation migration)
// ============================================================================
//
// Feature: gorouter-navigation-migration
// Task 2.2 — Write exploration test for legacy login->shell (3 business types).
// Validates: Requirements 2.1, 4.2
//
// PURPOSE (exploration / baseline):
//   This test documents the CURRENT (legacy, flag-absent/false) login->shell
//   reachability for three business types — grocery, pharmacy, and a
//   default/retail fallback — and MUST PASS against the UNCHANGED code. It is
//   the regression baseline that Phase 1's preservation test (task 2.4) will
//   later be compared against. No production code is touched by this task.
//
// SEAM CHOSEN (and why):
//   The full login UI flow (LoginPage -> AuthGate -> SessionManager ->
//   AdaptiveShell) is driven by the GetIt service locator, network/auth, and
//   SharedPreferences, which are heavy and non-deterministic in a widget test.
//   The MEANINGFUL, stable seam that proves "for business type X, shell Y
//   loads" is `sidebarSectionsProvider` (lib/widgets/desktop/
//   sidebar_configuration.dart). After login the shell (AdaptiveShell /
//   DesktopContentHost) renders its sidebar from exactly this provider, and the
//   design (Req 4.4) reuses this same provider UNCHANGED under the new
//   ShellRoute. So the *set of shell sections resolved for a business type* is
//   precisely the login->shell outcome that must be preserved.
//
//   `sidebarSectionsProvider` derives sections from `businessTypeProvider`
//   (which dedicated section set), then filters by capability
//   (`FeatureResolver`, a pure static authority) and by RBAC
//   (`currentUserRoleProvider`). To capture the business-type -> shell mapping
//   deterministically we:
//     * override `businessTypeProvider` with the type under test,
//     * override `authStateProvider` with an authenticated (post-login) state
//       so the provider graph does not reach into GetIt,
//     * override `currentUserRoleProvider` to `owner` so RBAC does not strip
//       the (ungated) dashboard sections we assert on.
//   `FeatureResolver` is left REAL — its per-type capability filtering is part
//   of the AS-IS behavior we are documenting.
//
// DOCUMENTED BASELINE (AS-IS, unchanged legacy code):
//   * grocery  -> NOT a dedicated section set; falls through `switch` default
//                 to `_getRetailSections()` => first section "Dashboard & Control".
//   * pharmacy -> dedicated `_getPharmacySections()` => first section
//                 "Pharmacy Control" (with a "Dispensing & Sales" section).
//   * other    -> the explicit default/retail fallback => "Dashboard & Control".
// ============================================================================

import 'package:dukanx/core/models/user_role.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/providers/app_state_providers.dart';
import 'package:dukanx/widgets/desktop/sidebar_configuration.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake [BusinessTypeNotifier] that pins the active business type WITHOUT
/// touching SharedPreferences / license providers (which the real `build()`
/// reads). Lets the test drive `sidebarSectionsProvider` deterministically.
class _FakeBusinessTypeNotifier extends BusinessTypeNotifier {
  _FakeBusinessTypeNotifier(this._type);

  final BusinessType _type;

  @override
  BusinessTypeState build() => BusinessTypeState(type: _type);
}

/// Fake [AuthStateNotifier] representing a completed (post-login)
/// authentication WITHOUT reaching into the GetIt service locator (which the
/// real `build()` does via `sl<SessionManager>()`).
class _FakeAuthStateNotifier extends AuthStateNotifier {
  @override
  AuthState build() => AuthState(status: AuthStatus.authenticated);
}

/// Builds a container whose provider graph resolves the legacy shell sidebar
/// for [type] as it would right after a successful login.
ProviderContainer _loggedInContainer(BusinessType type) {
  final container = ProviderContainer(
    overrides: [
      businessTypeProvider.overrideWith(() => _FakeBusinessTypeNotifier(type)),
      authStateProvider.overrideWith(() => _FakeAuthStateNotifier()),
      // Neutralize RBAC so the ungated dashboard sections we assert on survive
      // the filter; capability filtering (FeatureResolver) stays real.
      currentUserRoleProvider.overrideWithValue(UserRole.owner),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Convenience: the ordered list of resolved shell section titles for [type].
List<String> _sectionTitles(BusinessType type) {
  final sections = _loggedInContainer(type).read(sidebarSectionsProvider);
  return sections.map((s) => s.title).toList();
}

void main() {
  group('Feature: gorouter-navigation-migration — legacy login->shell baseline '
      '(Req 2.1, 4.2)', () {
    test('grocery login lands on the RETAIL shell (default switch branch)', () {
      final titles = _sectionTitles(BusinessType.grocery);

      // Grocery has no dedicated section set; the legacy switch falls
      // through `default -> _getRetailSections()`.
      expect(
        titles,
        isNotEmpty,
        reason: 'Grocery must resolve a non-empty shell after login.',
      );
      expect(
        titles.first,
        'Dashboard & Control',
        reason: 'Grocery resolves to the retail dashboard section set.',
      );
      expect(
        titles,
        isNot(contains('Pharmacy Control')),
        reason: 'Grocery must NOT get the dedicated pharmacy shell.',
      );
    });

    test('pharmacy login lands on the dedicated PHARMACY shell', () {
      final titles = _sectionTitles(BusinessType.pharmacy);

      expect(
        titles,
        isNotEmpty,
        reason: 'Pharmacy must resolve a non-empty shell after login.',
      );
      expect(
        titles.first,
        'Pharmacy Control',
        reason: 'Pharmacy resolves to its dedicated section set.',
      );
      expect(
        titles,
        contains('Dispensing & Sales'),
        reason: 'The dedicated pharmacy shell exposes the dispensing section.',
      );
    });

    test('default/retail (other) login lands on the RETAIL shell fallback', () {
      final titles = _sectionTitles(BusinessType.other);

      // `BusinessType.other` exercises the explicit `default` branch of the
      // legacy `_getSectionsForBusiness` switch.
      expect(
        titles,
        isNotEmpty,
        reason: 'Default/retail must resolve a non-empty shell after login.',
      );
      expect(
        titles.first,
        'Dashboard & Control',
        reason: 'The default fallback uses the retail dashboard section set.',
      );
      expect(
        titles,
        isNot(contains('Pharmacy Control')),
        reason: 'The default fallback must NOT get the pharmacy shell.',
      );
    });

    test('baseline distinguishes pharmacy from grocery/retail shells', () {
      // Captures the AS-IS invariant Phase 1 must preserve: pharmacy gets a
      // DIFFERENT shell than grocery and the default/retail fallback, while
      // grocery and the default fallback share the same retail shell.
      final grocery = _sectionTitles(BusinessType.grocery);
      final pharmacy = _sectionTitles(BusinessType.pharmacy);
      final retail = _sectionTitles(BusinessType.other);

      expect(grocery.first, retail.first);
      expect(pharmacy.first, isNot(grocery.first));
    });
  });
}
