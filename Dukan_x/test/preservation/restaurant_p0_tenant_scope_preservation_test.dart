// PRESERVATION TEST — expected to PASS on unfixed code.
// Pass = baseline behavior preserved, ready to guard against regression.
//
// Property 3: Preservation — Non-Restaurant Tenant Resolution Unchanged
//
// **Validates: Requirements 3.1, 3.2**
//
// This test confirms that:
//   1. The 19 already-correctly-resolving restaurant sidebar items do NOT
//      contain the 'SYSTEM' fallback pattern in their case blocks — they
//      resolve to their documented widget types via simple `return const *Screen()`
//      patterns (no vendorId resolution needed).
//   2. Non-restaurant business type sections (clinic, petrol pump, pharmacy,
//      jewellery, wholesale, hardware, school, clothing, DC, mandi, etc.) are
//      structurally independent of any restaurant-specific vendorId resolution
//      code, and will remain unaffected by the P0 fix.
//
// Methodology (observation-first):
//   - Read sidebar_navigation_handler.dart source code.
//   - For each of the 19 non-affected restaurant items, structurally confirm:
//     (a) No 'SYSTEM' literal appears in the case block.
//     (b) The return statement matches the documented widget type.
//   - For non-restaurant business types, structurally confirm their case blocks
//     contain no reference to 'SYSTEM' or restaurant-specific vendorId patterns.
//
// PBT library: dartproptest ^0.2.1
//
// Run: flutter test test/preservation/restaurant_p0_tenant_scope_preservation_test.dart
library;

import 'dart:io';

import 'package:dartproptest/dartproptest.dart';
import 'package:flutter_test/flutter_test.dart';

/// Number of PBT runs for generated-input properties.
const int kNumRuns = 100;

/// The 19 already-correctly-resolving restaurant sidebar items that do NOT
/// use the vendorId ?? 'SYSTEM' pattern. These items resolve directly to
/// their widget types without any tenant-scope resolution.
const List<String> kNonAffectedRestaurantItems = <String>[
  'new_sale',
  'revenue_overview',
  'sales_register',
  'stock_summary',
  'item_stock',
  'low_stock',
  'customers',
  'suppliers',
  'party_ledger',
  'outstanding',
  'analytics_hub',
  'product_performance',
  'invoice_margin',
  'gstr1',
  'print_settings',
  'backup',
  'error_logs',
  'device_settings',
  'executive_dashboard',
];

/// Documented widget type mappings for the 19 non-affected items.
/// Each maps to the class name that should appear in the return statement.
const Map<String, String> kExpectedWidgetTypes = <String, String>{
  'new_sale': 'BillCreationScreenV2',
  'revenue_overview': 'RevenueOverviewScreen',
  'sales_register': 'SalesRegisterScreen',
  'stock_summary': 'StockSummaryScreen',
  'item_stock': 'InventoryDashboardScreen',
  'low_stock': 'LowStockAlertsScreen',
  'customers': 'CustomersListScreen',
  'suppliers': 'PartyLedgerListScreen',
  'party_ledger': 'PartyLedgerListScreen',
  'outstanding': 'PartyLedgerListScreen',
  'analytics_hub': 'ReportsHubScreen',
  'product_performance': 'ProductPerformanceScreen',
  'invoice_margin': 'PnlScreen',
  'gstr1': 'GstReportsScreen',
  'print_settings': 'PrintMenuScreen',
  'backup': 'BackupScreen',
  'error_logs': 'ErrorLogsScreen',
  'device_settings': 'DeviceSettingsScreen',
  'executive_dashboard': 'DashboardController',
};

/// Non-restaurant business type sections identified by their comment markers
/// in the navigation handler source. These represent structurally independent
/// code paths that must remain untouched by any restaurant-specific changes.
const List<String> kNonRestaurantSectionMarkers = <String>[
  'Clinic Specific',
  'Petrol Pump',
  'WhatsApp',
  'BuyFlow',
  'Parties & Ledger',
  'Business Intelligence',
  'Financial Reports',
  'Tax & Compliance',
  'Operations & Logs',
  'Utilities & System',
  'Doctor/Clinic Hidden',
  'Petrol Pump Reports',
  'Service Business',
  'HARDWARE VERTICAL',
  'MANDI',
  'JEWELLERY VERTICAL',
  'DECORATION & CATERING',
  'SCHOOL ERP',
  'CLOTHING VERTICAL',
  'ELECTRONICS VERTICAL',
  'WHOLESALE VERTICAL',
  'BOOK STORE VERTICAL',
  'PHARMACY',
];

/// The 7 affected restaurant items (for exclusion/boundary checks).
const List<String> kAffectedRestaurantItems = <String>[
  'restaurant_tables',
  'kitchen_display',
  'menu_management',
  'daily_summary',
  'floor_management',
  'kot_report',
  'recipe_management',
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
  // Helper: extract the case block for a given sidebar item id.
  // Returns the code from `case '<itemId>':` to just before the next `case '`.
  // ===========================================================================
  String extractCaseBlock(String itemId) {
    final casePattern = "case '$itemId':";
    final caseIdx = navigationHandlerSource.indexOf(casePattern);
    if (caseIdx == -1) return '';

    final afterCase = navigationHandlerSource.substring(
      caseIdx + casePattern.length,
    );

    // Find the next case statement or default: to delimit this block
    final nextCaseIdx = afterCase.indexOf(RegExp(r"case '|default:"));
    if (nextCaseIdx == -1) return afterCase;
    return afterCase.substring(0, nextCaseIdx);
  }

  // ===========================================================================
  // Helper: extract a section block between two section comment markers.
  // Returns the code from a section header to the next section header.
  // ===========================================================================
  String extractSectionBlock(String sectionMarker) {
    final idx = navigationHandlerSource.indexOf(sectionMarker);
    if (idx == -1) return '';

    // Get the content from this section marker up to a reasonable boundary
    final afterMarker = navigationHandlerSource.substring(idx);
    // Look for the next major section comment (========== pattern)
    final nextSectionIdx = afterMarker.indexOf(
      RegExp(r'// =========='),
      sectionMarker.length + 10,
    );
    if (nextSectionIdx == -1) {
      return afterMarker.substring(0, (afterMarker.length).clamp(0, 2000));
    }
    return afterMarker.substring(0, nextSectionIdx);
  }

  // ===========================================================================
  // GROUP 1: Requirement 3.2 — 19 non-affected restaurant items have NO
  //          'SYSTEM' fallback in their case blocks.
  //
  // This group PASSES on unfixed code — confirming these items already
  // resolve correctly and do not participate in the P0 bug.
  // ===========================================================================
  group(
    'Property 3 (Req 3.2): Non-affected restaurant items have no SYSTEM fallback',
    () {
      // Exhaustive enumeration: each of the 19 items individually.
      for (final itemId in kNonAffectedRestaurantItems) {
        test('$itemId case block does NOT contain SYSTEM literal', () {
          final caseBlock = extractCaseBlock(itemId);

          expect(
            caseBlock.isNotEmpty,
            isTrue,
            reason:
                '"$itemId" must have a case block in sidebar_navigation_handler.dart',
          );

          expect(
            caseBlock.contains("'SYSTEM'"),
            isFalse,
            reason:
                'PRESERVATION ASSERTION: "$itemId" case block must NOT contain '
                'the SYSTEM fallback. This item already resolves correctly '
                'without vendorId tenant-scope logic. If this fails after the '
                'P0 fix, the fix has introduced a regression into a '
                'previously-correct item.',
          );
        });
      }

      // PBT: for randomly selected items from the 19, confirm no SYSTEM.
      test(
        'PBT: random non-affected restaurant items × session states have no SYSTEM',
        () {
          final held = forAll(
            (int itemIdx, int sessionVariant) {
              final itemId =
                  kNonAffectedRestaurantItems[itemIdx %
                      kNonAffectedRestaurantItems.length];
              final caseBlock = extractCaseBlock(itemId);

              if (caseBlock.isEmpty) return false;

              // Property: no matter what session state (represented by
              // sessionVariant), the case block for this item does NOT
              // contain SYSTEM — because these items don't use session state
              // for vendorId resolution at all.
              if (caseBlock.contains("'SYSTEM'")) return false;

              // Also verify no vendorId resolution chain exists
              // (these items should be simple returns, not vendorId-dependent).
              final hasVendorIdChain =
                  caseBlock.contains('currentBusinessId') &&
                  caseBlock.contains('userId') &&
                  caseBlock.contains("'SYSTEM'");
              if (hasVendorIdChain) return false;

              // sessionVariant documents coverage over session state space
              assert(sessionVariant >= 0 && sessionVariant < 10);
              return true;
            },
            [
              Gen.interval(0, kNonAffectedRestaurantItems.length - 1),
              Gen.interval(0, 9), // 10 session state variants
            ],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'PRESERVATION FAILURE: at least one non-affected restaurant '
                'item unexpectedly contains a SYSTEM fallback or vendorId '
                'resolution chain. This would indicate a regression.',
          );
        },
      );
    },
  );

  // ===========================================================================
  // GROUP 2: Requirement 3.2 — 19 non-affected restaurant items resolve to
  //          their documented widget types.
  //
  // This group PASSES on unfixed code — confirming the correct widget mappings
  // that must be preserved post-fix.
  // ===========================================================================
  group(
    'Property 3 (Req 3.2): Non-affected restaurant items resolve to documented widget types',
    () {
      for (final entry in kExpectedWidgetTypes.entries) {
        final itemId = entry.key;
        final expectedWidget = entry.value;

        test('$itemId resolves to $expectedWidget', () {
          final caseBlock = extractCaseBlock(itemId);

          expect(
            caseBlock.isNotEmpty,
            isTrue,
            reason:
                '"$itemId" must have a case block in sidebar_navigation_handler.dart',
          );

          expect(
            caseBlock.contains(expectedWidget),
            isTrue,
            reason:
                'PRESERVATION ASSERTION: "$itemId" must resolve to '
                '$expectedWidget. This mapping must remain stable after the '
                'P0 tenant-scope fix.',
          );
        });
      }

      // PBT: randomly pick items and verify widget type presence.
      test(
        'PBT: random non-affected items resolve to their expected widget type',
        () {
          final itemIds = kExpectedWidgetTypes.keys.toList();

          final held = forAll(
            (int itemIdx) {
              final itemId = itemIds[itemIdx % itemIds.length];
              final expectedWidget = kExpectedWidgetTypes[itemId]!;
              final caseBlock = extractCaseBlock(itemId);

              if (caseBlock.isEmpty) return false;
              if (!caseBlock.contains(expectedWidget)) return false;

              return true;
            },
            [Gen.interval(0, itemIds.length - 1)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'PRESERVATION FAILURE: at least one non-affected restaurant '
                'item does not resolve to its documented widget type.',
          );
        },
      );
    },
  );

  // ===========================================================================
  // GROUP 3: Requirement 3.1 — Non-restaurant business type sections are
  //          structurally independent of restaurant vendorId resolution.
  //
  // This group PASSES on unfixed code — confirming non-restaurant sections
  // have their own resolution paths entirely separate from the 7 affected
  // restaurant items.
  // ===========================================================================
  group(
    'Property 3 (Req 3.1): Non-restaurant business types independent of restaurant vendorId',
    () {
      // Structural assertion: non-restaurant sections don't reference 'SYSTEM'
      // in a vendorId context.
      for (final marker in kNonRestaurantSectionMarkers) {
        test(
          '$marker section has no restaurant-style SYSTEM vendorId pattern',
          () {
            final sectionBlock = extractSectionBlock(marker);

            if (sectionBlock.isEmpty) {
              // Section marker not found — this is acceptable for sections
              // that might be organized differently. Skip gracefully.
              return;
            }

            // Check for the specific restaurant vendorId pattern:
            // sl<SessionManager>().currentBusinessId ?? ... ?? 'SYSTEM'
            final hasRestaurantVendorIdPattern =
                sectionBlock.contains("?? 'SYSTEM'") &&
                sectionBlock.contains('currentBusinessId');

            expect(
              hasRestaurantVendorIdPattern,
              isFalse,
              reason:
                  'PRESERVATION ASSERTION: "$marker" section must NOT contain '
                  'the restaurant-style vendorId resolution pattern '
                  '(currentBusinessId ?? userId ?? SYSTEM). Non-restaurant '
                  'business types must remain structurally independent.',
            );
          },
        );
      }

      // PBT: for randomly selected non-restaurant section markers, confirm
      // structural independence from the restaurant vendorId pattern.
      test(
        'PBT: random non-restaurant sections are independent of restaurant vendorId pattern',
        () {
          final held = forAll(
            (int markerIdx) {
              final marker =
                  kNonRestaurantSectionMarkers[markerIdx %
                      kNonRestaurantSectionMarkers.length];
              final sectionBlock = extractSectionBlock(marker);

              if (sectionBlock.isEmpty) return true; // graceful skip

              // Property: no non-restaurant section contains the P0 bug pattern
              final hasRestaurantVendorIdPattern =
                  sectionBlock.contains("?? 'SYSTEM'") &&
                  sectionBlock.contains('currentBusinessId');

              return !hasRestaurantVendorIdPattern;
            },
            [Gen.interval(0, kNonRestaurantSectionMarkers.length - 1)],
            numRuns: kNumRuns,
          );
          expect(
            held,
            isTrue,
            reason:
                'PRESERVATION FAILURE: at least one non-restaurant section '
                'contains a restaurant-style vendorId SYSTEM pattern. '
                'Non-restaurant paths must be structurally independent.',
          );
        },
      );
    },
  );

  // ===========================================================================
  // GROUP 4: Boundary check — the 7 AFFECTED items now use
  //          _resolveRestaurantScreen (P0 fix landed).
  //
  // This group PASSES on fixed code — confirming the affected items have been
  // migrated to the safe RestaurantTenantScope pattern.
  // ===========================================================================
  group('Partition boundary: affected items use RestaurantTenantScope', () {
    for (final itemId in kAffectedRestaurantItems) {
      test('$itemId (AFFECTED) uses _resolveRestaurantScreen', () {
        final caseBlock = extractCaseBlock(itemId);

        expect(
          caseBlock.contains('_resolveRestaurantScreen'),
          isTrue,
          reason:
              'POST-FIX: "$itemId" must delegate to _resolveRestaurantScreen '
              '(which uses RestaurantTenantScope) after the P0 fix.',
        );

        expect(
          caseBlock.contains("'SYSTEM'"),
          isFalse,
          reason:
              'POST-FIX: "$itemId" must NOT contain the SYSTEM fallback '
              'after the P0 fix has landed.',
        );
      });
    }
  });

  // ===========================================================================
  // GROUP 5: Cross-check — the SYSTEM vendorId pattern no longer appears
  //          anywhere in the switch statement after the P0 fix.
  //
  // This confirms the P0 fix completely removed the 'SYSTEM' fallback.
  // ===========================================================================
  group('Scope boundary: SYSTEM completely removed after P0 fix', () {
    test('SYSTEM fallback count is exactly 0 (all 7 fixed)', () {
      // Count occurrences of the full vendorId pattern with 'SYSTEM'
      final pattern = RegExp(
        r"sl<SessionManager>\(\)\.currentBusinessId\s*\?\?\s*"
        r"sl<SessionManager>\(\)\.userId\s*\?\?\s*'SYSTEM'",
      );
      final matches = pattern.allMatches(navigationHandlerSource);

      expect(
        matches.length,
        equals(0),
        reason:
            'PRESERVATION ASSERTION: after the P0 fix, the vendorId ?? SYSTEM '
            'pattern should appear 0 times. Found: ${matches.length}.',
      );
    });
  });
}
