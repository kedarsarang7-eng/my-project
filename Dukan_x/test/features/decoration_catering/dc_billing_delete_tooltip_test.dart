// Requirement 4.3 — Delete-row icon tooltip regression lock.
//
// **Validates: Requirements 4.3**
//
// Per requirements.md Requirement 4.3 (Acceptance Criteria 1-2):
//   AC1. THE delete-row IconButton on DcBillingScreen SHALL have a
//        non-null tooltip property with the value 'Remove line item'.
//   AC2. THE regression-lock test for this requirement SHALL fail if the
//        tooltip is removed or its text changes without an accompanying,
//        deliberate update to the test.
//
// This is a regression-lock test (design.md status: DONE) — no production
// code change is expected unless it surfaces an actual regression (per
// tasks.md Task 24).
//
// Pumping pattern follows the repo-wide convention of a minimal
// `noSuchMethod`-backed mock `DcRepository` overridden via
// `dcRepositoryProvider` (see `test/dc_enhancements_test.dart`'s
// `MockDcRepository`), overriding only the methods `DcBillingScreen`
// actually calls during build/initState: `getBookings()` (consumed by
// `dcBookingsProvider`, which the screen's `build()` awaits before
// rendering the billing form) and `getInvoices()` (consumed by
// `_loadInvoiceHistory()` in `initState`).
//
// Run: flutter test test/features/decoration_catering/dc_billing_delete_tooltip_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:dukanx/core/services/currency_service.dart';
import 'package:dukanx/features/decoration_catering/data/models/dc_models.dart';
import 'package:dukanx/features/decoration_catering/data/repositories/dc_repository.dart';
import 'package:dukanx/features/decoration_catering/presentation/screens/dc_billing_screen.dart';

/// Minimal mock backing `dcRepositoryProvider` for this test. Only the
/// methods `DcBillingScreen` calls during build/initState are overridden;
/// everything else falls through `noSuchMethod`, following the same
/// pattern as `test/dc_enhancements_test.dart`'s `MockDcRepository`.
class _MockDcRepository implements DcRepository {
  @override
  Future<List<EventBooking>> getBookings({
    EventStatus? statusFilter,
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> getInvoices({
    String? eventId,
    String? status,
    String? search,
    String? invoiceNumber,
    int page = 1,
    int limit = 50,
  }) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final sl = GetIt.instance;

  setUp(() {
    if (!sl.isRegistered<CurrencyService>()) {
      sl.registerSingleton<CurrencyService>(CurrencyService());
    }
  });

  tearDown(() async {
    await sl.reset();
  });

  group('Requirement 4.3 AC1-2 — delete-row IconButton tooltip', () {
    testWidgets("DcBillingScreen's delete-row IconButton has "
        "tooltip: 'Remove line item'", (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dcRepositoryProvider.overrideWithValue(_MockDcRepository()),
          ],
          child: const MaterialApp(home: DcBillingScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Add a line item so the delete-row IconButton renders — the
      // billing form starts with no items until a booking is selected
      // or "Add Item" is tapped.
      await tester.tap(find.text('Add Item'));
      await tester.pumpAndSettle();

      final deleteIconFinder = find.widgetWithIcon(
        IconButton,
        Icons.delete_outline,
      );
      expect(
        deleteIconFinder,
        findsOneWidget,
        reason:
            'The delete-row IconButton (Icons.delete_outline) must be '
            'present after adding a line item.',
      );

      final deleteButton = tester.widget<IconButton>(deleteIconFinder);
      expect(
        deleteButton.tooltip,
        'Remove line item',
        reason:
            'Requirement 4.3 AC1: the delete-row IconButton on '
            'DcBillingScreen must have tooltip == "Remove line item".',
      );
    });
  });
}
