// ============================================================================
// Task 25 — Barrel-completeness regression-lock test
// Feature: decoration-catering-remediation
// **Validates: Requirement 4.4**
// ============================================================================
//
// Regression-lock only — this test does not change production code. It
// locks in the current, complete export surface of
// `lib/features/decoration_catering/decoration_catering.dart` by referencing
// every one of the 16 exported screen widget types plus
// `DcVendorRatingDialog` as compile-time `Type` literals.
//
// Mechanism: this is a COMPILE-TIME lock, not just a runtime assertion. If
// any of these 17 symbols is ever removed from (or renamed within) the
// barrel export list without a deliberate, accompanying update to this test
// file, this test file will FAIL TO COMPILE — which is a stronger guarantee
// than a runtime check, since `flutter test`/`flutter analyze` will surface
// the break immediately.
//
// The 16 screens (Requirement 4.4):
//   dc_billing_screen, dc_bookings_screen, dc_calendar_screen,
//   dc_catering_screen, dc_dashboard_screen, dc_decoration_screen,
//   dc_event_detail_screen, dc_inventory_screen, dc_profitability_screen,
//   dc_quote_conversion_screen, dc_quotes_screen, dc_reports_screen,
//   dc_shopping_list_screen, dc_staff_attendance_screen, dc_staff_screen,
//   dc_vendor_payments_screen
// Plus: dc_vendor_rating_dialog (DcVendorRatingDialog)
//
// Run: flutter test test/features/decoration_catering/dc_barrel_completeness_test.dart
// ============================================================================
library;

import 'package:dukanx/features/decoration_catering/decoration_catering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The 16 screen types required to remain exported from the DC barrel file,
/// per Requirement 4.4. Referencing each as a `Type` literal here means the
/// removal (or renaming) of any corresponding barrel export will cause this
/// test FILE to fail to compile, rather than merely failing an assertion.
const List<Type> kDcBarrelScreenTypes = <Type>[
  DcBillingScreen,
  DcBookingsScreen,
  DcCalendarScreen,
  DcCateringScreen,
  DcDashboardScreen,
  DcDecorationScreen,
  DcEventDetailScreen,
  DcInventoryScreen,
  DcProfitabilityScreen,
  DcQuoteConversionScreen,
  DcQuotesScreen,
  DcReportsScreen,
  DcShoppingListScreen,
  DcStaffAttendanceScreen,
  DcStaffScreen,
  DcVendorPaymentsScreen,
];

/// The vendor rating dialog widget, exported separately from the screens
/// list per Requirement 4.4 ("plus `dc_vendor_rating_dialog`").
const Type kDcBarrelVendorRatingDialogType = DcVendorRatingDialog;

void main() {
  group('DcBarrelCompletenessTest — Requirement 4.4', () {
    test('decoration_catering.dart exports all 16 required screen types '
        '(compile-time lock)', () {
      expect(
        kDcBarrelScreenTypes.length,
        16,
        reason:
            'Requirement 4.4: exactly 16 screen types must be locked in '
            'by this test — found ${kDcBarrelScreenTypes.length}. If a '
            'screen was intentionally added or removed from the barrel, '
            'update this list deliberately alongside that change.',
      );

      // Every referenced type must be non-null and distinct — this is a
      // sanity check on top of the primary compile-time lock above.
      for (final type in kDcBarrelScreenTypes) {
        expect(
          type,
          isNotNull,
          reason: 'Every barrel-exported screen type must be non-null.',
        );
      }
      expect(
        kDcBarrelScreenTypes.toSet().length,
        kDcBarrelScreenTypes.length,
        reason: 'All 16 barrel-exported screen types must be distinct.',
      );
    });

    test('decoration_catering.dart exports DcVendorRatingDialog '
        '(compile-time lock)', () {
      expect(kDcBarrelVendorRatingDialogType, DcVendorRatingDialog);
      expect(kDcBarrelVendorRatingDialogType, isNotNull);
    });

    test('the full 17-symbol barrel surface (16 screens + vendor rating '
        'dialog) is accounted for', () {
      final allTypes = <Type>[
        ...kDcBarrelScreenTypes,
        kDcBarrelVendorRatingDialogType,
      ];
      expect(
        allTypes.length,
        17,
        reason:
            'Requirement 4.4: 16 screens + 1 vendor rating dialog = 17 '
            'locked barrel symbols.',
      );
      expect(
        allTypes.toSet().length,
        17,
        reason: 'All 17 locked barrel symbols must be distinct types.',
      );
    });
  });
}
