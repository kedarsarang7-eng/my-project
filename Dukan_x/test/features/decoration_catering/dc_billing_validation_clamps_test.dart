// Requirement 3.9 — Billing validation clamps regression lock.
//
// **Validates: Requirements 3.9**
//
// Per requirements.md Requirement 3.9 (Acceptance Criteria 1-4):
//   AC1. FOR ALL discount percentage inputs on DcBillingScreen, THE effective
//        discount value used in totals SHALL be clamped to [0, 100].
//   AC2. FOR ALL GST percentage inputs on DcBillingScreen, THE effective GST
//        value used in totals SHALL be clamped to [0, 28].
//   AC3. IF a line-item quantity or rate is entered as zero or negative, THEN
//        THE DcBillingScreen SHALL show an inline error and SHALL NOT include
//        that item's invalid value in the computed total as if it were valid.
//   AC4. WHILE no event is selected, THE DcBillingScreen SHALL keep "Generate
//        Invoice" disabled.
//
// This is a regression-lock test (design.md status: DONE) — no production
// code change is expected unless it surfaces an actual regression (per
// tasks.md Task 20).
//
// Run: flutter test test/features/decoration_catering/dc_billing_validation_clamps_test.dart

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
/// everything else falls through `noSuchMethod`.
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

/// Finds a TextField whose InputDecoration has a suffix widget containing the
/// given text. Used to uniquely identify the discount ('%' suffix) and GST
/// ('%' suffix) fields by combining with controller text.
Finder _findTextFieldWithSuffix(String suffixText, String controllerText) {
  return find.byWidgetPredicate((w) {
    if (w is! TextField) return false;
    if (w.controller?.text != controllerText) return false;
    final decoration = w.decoration;
    if (decoration == null) return false;
    final suffix = decoration.suffix;
    if (suffix is Text && suffix.data == suffixText) return true;
    return false;
  });
}

/// Helper to pump the DcBillingScreen with provider overrides.
Widget _buildTestWidget() {
  return ProviderScope(
    overrides: [dcRepositoryProvider.overrideWithValue(_MockDcRepository())],
    child: const MaterialApp(home: DcBillingScreen()),
  );
}

void main() {
  group('Requirement 3.9 — Billing validation clamps regression lock', () {
    setUp(() async {
      await GetIt.I.reset();
      GetIt.I.registerSingleton<CurrencyService>(CurrencyService());
    });

    tearDown(() async {
      await GetIt.I.reset();
    });

    // ─────────────────────────────────────────────────────────────────────
    // AC4: "Generate Invoice" remains disabled while no event is selected
    // ─────────────────────────────────────────────────────────────────────
    testWidgets('AC4: Generate Invoice is disabled when no event is selected', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      // Add a line item so _items is not empty (otherwise the button is also
      // disabled due to the _items.isEmpty guard).
      await tester.tap(find.text('Add Item'));
      await tester.pumpAndSettle();

      // The button text "Generate Invoice" should be present but disabled.
      final buttonFinder = find.widgetWithText(
        ElevatedButton,
        'Generate Invoice',
      );
      expect(
        buttonFinder,
        findsOneWidget,
        reason: 'The "Generate Invoice" button must be rendered.',
      );

      final button = tester.widget<ElevatedButton>(buttonFinder);
      expect(
        button.onPressed,
        isNull,
        reason:
            'Requirement 3.9 AC4: "Generate Invoice" must be disabled '
            'while no event is selected.',
      );
    });

    // ─────────────────────────────────────────────────────────────────────
    // AC1: Discount is clamped to [0, 100] in computed totals
    // ─────────────────────────────────────────────────────────────────────
    testWidgets('AC1: Discount above 100 is clamped to 100 in the UI', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      // Find the discount field by its '%' suffix and initial value '0'.
      final discountFinder = _findTextFieldWithSuffix('%', '0');
      expect(
        discountFinder,
        findsOneWidget,
        reason: 'Discount TextField (suffix "%" , value "0") must exist.',
      );

      // Enter a value above 100
      await tester.enterText(discountFinder, '150');
      await tester.pumpAndSettle();

      // After clamping, the controller text should show '100'.
      // Re-find the field using suffix only (value has changed).
      final allPercentFields = find.byWidgetPredicate((w) {
        if (w is! TextField) return false;
        final decoration = w.decoration;
        if (decoration == null) return false;
        final suffix = decoration.suffix;
        return suffix is Text &&
            suffix.data == '%' &&
            decoration.errorStyle != null; // discount has errorStyle
      });
      final discountField = tester.widget<TextField>(allPercentFields.first);
      expect(
        discountField.controller!.text,
        '100',
        reason:
            'Requirement 3.9 AC1: discount input of 150 must be '
            'clamped to 100.',
      );
    });

    testWidgets('AC1: Negative discount is clamped to 0 in the UI', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      final discountFinder = _findTextFieldWithSuffix('%', '0');
      expect(discountFinder, findsOneWidget);

      // Enter a negative value
      await tester.enterText(discountFinder, '-5');
      await tester.pumpAndSettle();

      // Re-find the discount field (has errorStyle in its decoration)
      final discountAfter = find.byWidgetPredicate((w) {
        if (w is! TextField) return false;
        final decoration = w.decoration;
        if (decoration == null) return false;
        final suffix = decoration.suffix;
        return suffix is Text &&
            suffix.data == '%' &&
            decoration.errorStyle != null;
      });
      final discountField = tester.widget<TextField>(discountAfter.first);
      expect(
        discountField.controller!.text,
        '0',
        reason:
            'Requirement 3.9 AC1: discount input of -5 must be '
            'clamped to 0.',
      );
    });

    // ─────────────────────────────────────────────────────────────────────
    // AC2: GST is clamped to [0, 28] in computed totals
    // ─────────────────────────────────────────────────────────────────────
    testWidgets('AC2: GST above 28 is clamped to 28 in the UI', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      // GST text field has '%' suffix and initial value '18'.
      final gstFinder = _findTextFieldWithSuffix('%', '18');
      expect(
        gstFinder,
        findsOneWidget,
        reason: 'GST TextField (suffix "%", value "18") must be present.',
      );

      // Enter a value above 28
      await tester.enterText(gstFinder, '30');
      await tester.pumpAndSettle();

      // Re-find the GST field: it has '%' suffix but NO errorStyle
      // (distinguishing it from the discount field which has errorStyle).
      final gstAfter = find.byWidgetPredicate((w) {
        if (w is! TextField) return false;
        final decoration = w.decoration;
        if (decoration == null) return false;
        final suffix = decoration.suffix;
        return suffix is Text &&
            suffix.data == '%' &&
            decoration.errorStyle == null;
      });
      final gstField = tester.widget<TextField>(gstAfter.first);
      expect(
        gstField.controller!.text,
        '28',
        reason:
            'Requirement 3.9 AC2: GST input of 30 must be '
            'clamped to 28.',
      );
    });

    testWidgets('AC2: Negative GST is clamped to 0 in the UI', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      final gstFinder = _findTextFieldWithSuffix('%', '18');
      expect(gstFinder, findsOneWidget);

      // Enter a negative value
      await tester.enterText(gstFinder, '-1');
      await tester.pumpAndSettle();

      // Re-find the GST field (no errorStyle)
      final gstAfter = find.byWidgetPredicate((w) {
        if (w is! TextField) return false;
        final decoration = w.decoration;
        if (decoration == null) return false;
        final suffix = decoration.suffix;
        return suffix is Text &&
            suffix.data == '%' &&
            decoration.errorStyle == null;
      });
      final gstField = tester.widget<TextField>(gstAfter.first);
      expect(
        gstField.controller!.text,
        '0',
        reason:
            'Requirement 3.9 AC2: GST input of -1 must be '
            'clamped to 0.',
      );
    });

    // ─────────────────────────────────────────────────────────────────────
    // AC3: Zero/negative qty shows inline error and is excluded from total
    // ─────────────────────────────────────────────────────────────────────
    testWidgets('AC3: Zero quantity shows inline error and retains previous '
        'valid value', (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      // Add a line item so qty/rate fields are rendered.
      await tester.tap(find.text('Add Item'));
      await tester.pumpAndSettle();

      // Find the qty field: center-aligned TextField with value '1'.
      final qtyField = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.controller?.text == '1' &&
            w.textAlign == TextAlign.center,
      );
      expect(
        qtyField,
        findsOneWidget,
        reason: 'Qty TextField (value "1", center-aligned) must exist.',
      );

      // Enter zero
      await tester.enterText(qtyField, '0');
      await tester.pumpAndSettle();

      // The qty field should revert to the previous valid value '1'
      final qtyWidget = tester.widget<TextField>(qtyField);
      expect(
        qtyWidget.controller!.text,
        '1',
        reason:
            'Requirement 3.9 AC3: zero qty must be rejected and '
            'previous valid value retained.',
      );

      // An inline error text 'Must be > 0' should be visible
      expect(
        find.text('Must be > 0'),
        findsOneWidget,
        reason: 'Requirement 3.9 AC3: zero qty must show an inline error.',
      );
    });

    testWidgets('AC3: Negative quantity shows inline error', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Item'));
      await tester.pumpAndSettle();

      final qtyField = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.controller?.text == '1' &&
            w.textAlign == TextAlign.center,
      );
      expect(qtyField, findsOneWidget);

      // Enter negative value
      await tester.enterText(qtyField, '-3');
      await tester.pumpAndSettle();

      // Previous valid value retained
      final qtyWidget = tester.widget<TextField>(qtyField);
      expect(
        qtyWidget.controller!.text,
        '1',
        reason: 'Requirement 3.9 AC3: negative qty must be rejected.',
      );

      // Inline error shown
      expect(
        find.text('Must be > 0'),
        findsOneWidget,
        reason: 'Requirement 3.9 AC3: negative qty must show an inline error.',
      );
    });

    testWidgets('AC3: Negative rate shows inline error and retains previous '
        'valid value', (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Item'));
      await tester.pumpAndSettle();

      // The rate field: it's inside the line items section with fontSize 13,
      // NOT center-aligned, and within a SizedBox of width 100.
      // Distinguish from discount field (fontSize 12, width 60, has '%' suffix).
      // The rate field has NO suffix and uses fontSize 13.
      final rateField = find.byWidgetPredicate((w) {
        if (w is! TextField) return false;
        if (w.controller?.text != '0') return false;
        if (w.textAlign == TextAlign.center) return false;
        final decoration = w.decoration;
        if (decoration == null) return false;
        // Rate field has no suffix; discount field has '%' suffix
        if (decoration.suffix != null) return false;
        // Rate field uses fontSize 13
        if (w.style?.fontSize != 13) return false;
        return true;
      });
      expect(
        rateField,
        findsOneWidget,
        reason:
            'Rate TextField (value "0", no suffix, fontSize 13) must '
            'exist after adding a line item.',
      );

      // Enter a negative rate
      await tester.enterText(rateField, '-100');
      await tester.pumpAndSettle();

      // Previous valid value retained (rate was 0)
      final rateWidget = tester.widget<TextField>(rateField);
      expect(
        rateWidget.controller!.text,
        '0',
        reason:
            'Requirement 3.9 AC3: negative rate must be rejected and '
            'previous valid value retained.',
      );

      // Inline error shown
      expect(
        find.text('Cannot be negative'),
        findsOneWidget,
        reason: 'Requirement 3.9 AC3: negative rate must show an inline error.',
      );
    });
  });
}
