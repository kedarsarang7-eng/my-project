// ============================================================================
// Task 1 — Phase 1 reachability gate test (DcReachabilityGateTest)
// Feature: decoration-catering-remediation
// **Validates: Requirement 1.1**
// ============================================================================
//
// This is the hard prerequisite gate for the entire decoration-catering-
// remediation plan: per requirements.md, no Phase 2/3/4 task may be started
// until this test exists and passes.
//
// Logs in as a DcTenant (a fake SessionManager with
// activeBusinessType == decorationCatering) and asserts:
//   1. SidebarConfiguration returns exactly 14 DC-only sections/items
//      (Requirement 1.1 AC2).
//   2. No returned section has title "BuyFlow", "Inventory & Stock", or
//      "Tax & Compliance" (Requirement 1.1 AC3).
//   3. Every DC item id resolves via
//      SidebarNavigationHandler.tryGetScreenForItem to a non-null widget
//      that is not `_PlaceholderScreen` (Requirement 1.1 AC4).
//   4. Pumping each resolved screen widget does not throw during build
//      (Requirement 1.1 AC5).
//   5. Resolving `executive_dashboard` while the session business type is
//      decorationCatering resolves to `DcDashboardScreen` (Requirement 1.1
//      AC6 — the same handler `content_host.dart`'s `ContentHost` delegates
//      to for this branch).
//
// Per design.md's Current State Assessment, all of this underlying behavior
// is already implemented (DONE) — this test locks it in as a regression gate
// so a future change to any shared file cannot silently make the DC vertical
// unreachable again without breaking the build.
//
// Run: flutter test test/features/decoration_catering/dc_reachability_gate_test.dart
// ============================================================================
library;

import 'package:dukanx/core/api/api_client.dart';
import 'package:dukanx/core/services/currency_service.dart';
import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/features/decoration_catering/presentation/screens/dc_billing_screen.dart';
import 'package:dukanx/features/decoration_catering/presentation/screens/dc_bookings_screen.dart';
import 'package:dukanx/features/decoration_catering/presentation/screens/dc_calendar_screen.dart';
import 'package:dukanx/features/decoration_catering/presentation/screens/dc_catering_screen.dart';
import 'package:dukanx/features/decoration_catering/presentation/screens/dc_dashboard_screen.dart';
import 'package:dukanx/features/decoration_catering/presentation/screens/dc_decoration_screen.dart';
import 'package:dukanx/features/decoration_catering/presentation/screens/dc_inventory_screen.dart';
import 'package:dukanx/features/decoration_catering/presentation/screens/dc_profitability_screen.dart';
import 'package:dukanx/features/decoration_catering/presentation/screens/dc_quotes_screen.dart';
import 'package:dukanx/features/decoration_catering/presentation/screens/dc_reports_screen.dart';
import 'package:dukanx/features/decoration_catering/presentation/screens/dc_shopping_list_screen.dart';
import 'package:dukanx/features/decoration_catering/presentation/screens/dc_staff_attendance_screen.dart';
import 'package:dukanx/features/decoration_catering/presentation/screens/dc_staff_screen.dart';
import 'package:dukanx/features/decoration_catering/presentation/screens/dc_vendor_payments_screen.dart';
import 'package:dukanx/models/business_type.dart';
import 'package:dukanx/widgets/desktop/sidebar_configuration.dart';
import 'package:dukanx/widgets/desktop/sidebar_navigation_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/mockito.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// A fake [SessionManager] pinned to a `decorationCatering` DcTenant session.
/// `Mock` supplies `noSuchMethod` no-ops for every member we don't override;
/// production code under test only reads `activeBusinessType`,
/// `currentBusinessId`, and `userId`.
class FakeDcSessionManager extends Mock implements SessionManager {
  FakeDcSessionManager({this.businessId = 'biz_dc_tenant_001'});

  final String? businessId;

  @override
  BusinessType get activeBusinessType => BusinessType.decorationCatering;

  @override
  String? get currentBusinessId => businessId;

  @override
  String? get userId => businessId;
}

/// A fake [ApiClient] whose every network call fails immediately. DC screens
/// under test never await their data before their first build (they render
/// `AsyncValue.loading()`/`AsyncValue.error()` branches), so this fake never
/// needs to return real data — it exists purely so `sl<ApiClient>()`
/// resolves without hitting the network in a widget test.
class FakeDcApiClient extends Mock implements ApiClient {
  @override
  Future<ApiResponse<Map<String, dynamic>>> get(
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    bool requireAuth = true,
  }) async {
    throw Exception('network unavailable (test double)');
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool requireAuth = true,
    String? idempotencyKey,
  }) async {
    throw Exception('network unavailable (test double)');
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool requireAuth = true,
    String? idempotencyKey,
  }) async {
    throw Exception('network unavailable (test double)');
  }

  @override
  Future<ApiResponse<Map<String, dynamic>>> delete(
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? headers,
    bool requireAuth = true,
    String? idempotencyKey,
  }) async {
    throw Exception('network unavailable (test double)');
  }
}

/// The 14 DC-only sidebar item ids from `_getDecorationCateringSections()`,
/// mapped to the screen widget type each must resolve to via
/// `SidebarNavigationHandler.tryGetScreenForItem`.
const Map<String, Type> kDcItemIdToScreenType = <String, Type>{
  'dc_dashboard': DcDashboardScreen,
  'dc_bookings': DcBookingsScreen,
  'dc_calendar': DcCalendarScreen,
  'dc_quotes': DcQuotesScreen,
  'dc_catering_menu': DcCateringScreen,
  'dc_decoration_themes': DcDecorationScreen,
  'dc_staff': DcStaffScreen,
  'dc_attendance': DcStaffAttendanceScreen,
  'dc_vendor_payments': DcVendorPaymentsScreen,
  'dc_inventory_rentals': DcInventoryScreen,
  'dc_shopping_list': DcShoppingListScreen,
  'dc_billing': DcBillingScreen,
  'dc_profitability': DcProfitabilityScreen,
  'dc_reports': DcReportsScreen,
};

const List<String> kForbiddenSectionTitles = <String>[
  'BuyFlow',
  'Inventory & Stock',
  'Tax & Compliance',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await GetIt.I.reset();
    GetIt.I.registerSingleton<SessionManager>(FakeDcSessionManager());
    GetIt.I.registerSingleton<ApiClient>(FakeDcApiClient());
    GetIt.I.registerSingleton<CurrencyService>(CurrencyService());
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  group('DcReachabilityGateTest — Requirement 1.1', () {
    // -------------------------------------------------------------------
    // AC2: SidebarConfiguration returns exactly 14 DC-only sections/items
    // -------------------------------------------------------------------
    test('SidebarConfiguration returns exactly 14 DC-only sections/items for a '
        'DcTenant (AC2)', () {
      final sections = getSectionsForBusinessType(
        BusinessType.decorationCatering,
      );

      final items = sections.expand((s) => s.items).toList();

      expect(
        sections.length,
        14,
        reason:
            'Requirement 1.1 AC2: SidebarConfiguration must return exactly '
            '14 DC-only sections for a DcTenant, found ${sections.length}.',
      );
      expect(
        items.length,
        14,
        reason:
            'Requirement 1.1 AC2: SidebarConfiguration must return exactly '
            '14 DC-only items for a DcTenant, found ${items.length}.',
      );

      // Every item must have a non-empty label and resolve via the
      // canonical id map above (defensive — confirms our fixture list
      // matches production reality, not just a hardcoded assumption).
      final actualIds = items.map((i) => i.id).toSet();
      expect(
        actualIds,
        equals(kDcItemIdToScreenType.keys.toSet()),
        reason:
            'The set of DC sidebar item ids returned by '
            'SidebarConfiguration must exactly match the canonical 14 ids '
            'this gate test exercises.',
      );
      for (final item in items) {
        expect(
          item.label.isNotEmpty,
          isTrue,
          reason: 'DC sidebar item "${item.id}" must have a non-empty label.',
        );
      }
    });

    // -------------------------------------------------------------------
    // AC3: no BuyFlow / Inventory & Stock / Tax & Compliance section
    // -------------------------------------------------------------------
    test('no DC section has title "BuyFlow", "Inventory & Stock", or '
        '"Tax & Compliance" (AC3)', () {
      final sections = getSectionsForBusinessType(
        BusinessType.decorationCatering,
      );
      final titles = sections.map((s) => s.title).toSet();

      for (final forbidden in kForbiddenSectionTitles) {
        expect(
          titles.contains(forbidden),
          isFalse,
          reason:
              'Requirement 1.1 AC3: DcTenant sidebar must never include a '
              '"$forbidden" section — found it in $titles.',
        );
      }
    });

    // -------------------------------------------------------------------
    // AC4 + AC5: every DC item id resolves to a non-null, non-placeholder
    // widget, and pumping each resolved screen does not throw during build.
    // -------------------------------------------------------------------
    group('every DC item id resolves to a real screen and builds without '
        'throwing (AC4, AC5)', () {
      for (final entry in kDcItemIdToScreenType.entries) {
        testWidgets(
          '"${entry.key}" resolves to ${entry.value} and builds without '
          'throwing',
          (tester) async {
            // DC screens are desktop layouts; size the test surface like a
            // desktop viewport so layout does not overflow the default
            // (small) test window — that would be a viewport artifact, not
            // a real build failure.
            tester.view.physicalSize = const Size(1400, 900);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            late BuildContext ctx;
            await tester.pumpWidget(
              ProviderScope(
                child: MaterialApp(
                  home: Builder(
                    builder: (c) {
                      ctx = c;
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
            );

            final screen = SidebarNavigationHandler.tryGetScreenForItem(
              entry.key,
              ctx,
            );

            // AC4: non-null, not the internal placeholder.
            expect(
              screen,
              isNotNull,
              reason:
                  'Requirement 1.1 AC4: DC item "${entry.key}" must resolve '
                  'to a non-null widget via tryGetScreenForItem.',
            );
            expect(
              screen.runtimeType.toString().contains('Placeholder'),
              isFalse,
              reason:
                  'Requirement 1.1 AC4: DC item "${entry.key}" must not '
                  'resolve to _PlaceholderScreen.',
            );
            expect(
              screen.runtimeType,
              entry.value,
              reason:
                  'DC item "${entry.key}" must resolve to ${entry.value}, '
                  'got ${screen.runtimeType}.',
            );

            // AC5: pumping the resolved screen must not throw during build.
            await tester.pumpWidget(
              ProviderScope(child: MaterialApp(home: screen!)),
            );
            // One extra pump lets any post-frame callbacks run without
            // requiring the tree to go idle (some DC screens use
            // AnimatedContainer/repeating animations).
            await tester.pump();

            final exception = tester.takeException();
            expect(
              exception,
              isNull,
              reason:
                  'Requirement 1.1 AC5: pumping the DC screen resolved for '
                  '"${entry.key}" (${entry.value}) must not throw during '
                  'build.',
            );
          },
        );
      }
    });

    // -------------------------------------------------------------------
    // AC6: executive_dashboard resolves to DcDashboardScreen for a DcTenant
    // -------------------------------------------------------------------
    testWidgets(
      'executive_dashboard resolves to DcDashboardScreen while the active '
      'session business type is decorationCatering (AC6)',
      (tester) async {
        late BuildContext ctx;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Builder(
                builder: (c) {
                  ctx = c;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );

        final screen = SidebarNavigationHandler.tryGetScreenForItem(
          'executive_dashboard',
          ctx,
        );

        expect(
          screen,
          isA<DcDashboardScreen>(),
          reason:
              'Requirement 1.1 AC6: resolving executive_dashboard for a '
              'DcTenant session must resolve to DcDashboardScreen, got '
              '${screen?.runtimeType}.',
        );
      },
    );
  });
}
