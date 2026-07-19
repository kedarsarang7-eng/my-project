// ============================================================================
// Task 14 — Advance-payment-ledger-with-rollback regression-lock test
// Feature: decoration-catering-remediation
// **Validates: Requirement 3.3 (Acceptance Criteria 1-3)**
// ============================================================================
//
// Regression-lock only — per design.md's Current State Assessment,
// `DcQuoteConversionScreen._convertToBooking()` already:
//   (a) calls `DcRepository.createBooking()` followed by
//       `DcRepository.recordPayment()` with the advance amount (AC1);
//   (b) when `recordPayment()` fails after booking creation, deletes the
//       created booking, reverts the quote status to its pre-conversion
//       value, and shows an error indicating the advance could not be
//       recorded (AC2);
//   (c) on full success (both `createBooking()` and `recordPayment()`
//       succeed), navigates back and shows a success indication (AC3).
//
// This test locks that behavior in with a mocked `DcRepository` — no
// production code change is expected unless this test surfaces an actual
// regression (per tasks.md Task 14).
//
// Run:
//   flutter test test/features/decoration_catering/dc_advance_payment_rollback_test.dart
// ============================================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/features/decoration_catering/data/models/dc_models.dart';
import 'package:dukanx/features/decoration_catering/data/repositories/dc_repository.dart';
import 'package:dukanx/features/decoration_catering/presentation/screens/dc_quote_conversion_screen.dart';

// ---------------------------------------------------------------------------
// Test double
// ---------------------------------------------------------------------------

/// A hand-rolled `DcRepository` test double that records every call it
/// receives (in order) so the test can assert both *that* the right methods
/// were called and *in what order*. Follows the repo-wide pattern already
/// used by `test/dc_enhancements_test.dart`'s `MockDcRepository`: implement
/// the concrete methods the screen under test actually calls, and rely on
/// the `noSuchMethod` override for everything else.
class _RecordingDcRepository implements DcRepository {
  _RecordingDcRepository({this.recordPaymentShouldFail = false});

  /// Whether `recordPayment` should throw (simulates the ledger-write
  /// failure path, Requirement 3.3 AC2).
  final bool recordPaymentShouldFail;

  /// Ordered log of every call this double received, e.g.
  /// `'updateQuoteStatus:accepted'`, `'createBooking'`,
  /// `'recordPayment:<eventId>:<amount>'`, `'deleteBooking:<id>'`.
  final List<String> calls = [];

  String? createdBookingId;
  String? deletedBookingId;
  DcPayment? recordedPayment;
  final List<QuoteStatus> quoteStatusCalls = [];

  static const String _fixedCreatedBookingId = 'booking-created-001';

  @override
  Future<DcQuote> updateQuoteStatus(String quoteId, QuoteStatus status) async {
    calls.add('updateQuoteStatus:${status.name}');
    quoteStatusCalls.add(status);
    return DcQuote(
      id: quoteId,
      quoteNumber: 'QT-1',
      customerName: 'Test Customer',
      customerPhone: '9999999999',
      eventType: 'Wedding',
      subtotal: 50000,
      gstAmount: 9000,
      total: 59000,
      status: status,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<EventBooking> createBooking(EventBooking booking) async {
    calls.add('createBooking');
    final created = EventBooking(
      id: _fixedCreatedBookingId,
      customerId: booking.customerId,
      customerName: booking.customerName,
      customerPhone: booking.customerPhone,
      customerEmail: booking.customerEmail,
      eventType: booking.eventType,
      eventTitle: booking.eventTitle,
      eventDate: booking.eventDate,
      venue: booking.venue,
      venueAddress: booking.venueAddress,
      guestCount: booking.guestCount,
      status: booking.status,
      quotedAmount: booking.quotedAmount,
      advancePaid: booking.advancePaid,
      createdAt: booking.createdAt,
      decorationThemeId: booking.decorationThemeId,
      cateringPackageId: booking.cateringPackageId,
    );
    createdBookingId = created.id;
    return created;
  }

  @override
  Future<void> recordPayment(DcPayment payment) async {
    calls.add('recordPayment:${payment.eventId}:${payment.amount}');
    recordedPayment = payment;
    if (recordPaymentShouldFail) {
      throw Exception('advance payment recording failed (test double)');
    }
  }

  @override
  Future<void> deleteBooking(String id) async {
    calls.add('deleteBooking:$id');
    deletedBookingId = id;
  }

  // DcQuoteConversionScreen.build() watches dcThemesProvider/
  // dcPackagesProvider, both of which read these two methods off
  // dcRepositoryProvider — must return quickly resolvable empty lists so
  // the screen builds without hitting the (unimplemented) noSuchMethod path.
  @override
  Future<List<DecorationTheme>> getThemes() async => [];

  @override
  Future<List<CateringPackage>> getPackages() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Mutable holder for the value `Navigator.pop(context, ...)` resolves the
/// pushed route's Future with — read after the pushed screen completes its
/// async conversion flow and pops itself.
class _PopResultHolder {
  bool? value;
}

/// A quote with subtotal ₹50,000, 0% discount, 18% GST → grand total
/// ₹59,000; default AdvanceConfig (50%) computes an advance of ₹29,500.
DcQuote _buildTestQuote({QuoteStatus status = QuoteStatus.draft}) => DcQuote(
  id: 'quote-123',
  quoteNumber: 'QT-2026-001',
  customerName: 'Test Customer',
  customerPhone: '9999999999',
  eventType: 'Wedding',
  eventDate: '2026-06-15',
  venue: 'Grand Hall',
  guestCount: 100,
  subtotal: 50000,
  gstPct: 18,
  gstAmount: 9000,
  discount: 0,
  total: 59000,
  status: status,
  createdAt: DateTime.now(),
);

/// Pumps a host screen with a button that pushes `DcQuoteConversionScreen`
/// onto the navigation stack (per the task's suggestion to wrap the screen
/// in a route so `Navigator.pop(context, true)` is observable), with
/// [repo] overriding `dcRepositoryProvider`. Returns the [_PopResultHolder]
/// that will be populated once the pushed route resolves.
Future<_PopResultHolder> _pumpConversionScreen(
  WidgetTester tester, {
  required DcQuote quote,
  required DcRepository repo,
}) async {
  final holder = _PopResultHolder();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [dcRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => DcQuoteConversionScreen(quote: quote),
                    ),
                  );
                  holder.value = result;
                },
                child: const Text('Open Conversion'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open Conversion'));
  await tester.pumpAndSettle();

  return holder;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Requirement 3.3 — advance payment ledger with rollback', () {
    // -----------------------------------------------------------------
    // AC1 + AC3 — success path: createBooking() followed by
    // recordPayment() with the advance amount, then navigate back with a
    // success indication.
    // -----------------------------------------------------------------
    testWidgets('on successful conversion, createBooking() is followed by '
        'recordPayment() with the advance amount, then the screen navigates '
        'back with a success indication (AC1, AC3)', (tester) async {
      final repo = _RecordingDcRepository();
      final quote = _buildTestQuote();

      final holder = await _pumpConversionScreen(
        tester,
        quote: quote,
        repo: repo,
      );

      expect(find.text('Convert to Booking'), findsOneWidget);
      await tester.tap(find.text('Convert to Booking'));
      await tester.pump(); // schedule the async conversion
      await tester.pumpAndSettle();

      // AC1: createBooking() called, then recordPayment() with the
      // advance amount (₹29,500 — 50% of ₹59,000 grand total).
      expect(
        repo.calls,
        containsAllInOrder(<String>['createBooking']),
        reason: 'createBooking() must be called during conversion.',
      );
      final createIdx = repo.calls.indexOf('createBooking');
      final recordPaymentIdx = repo.calls.indexWhere(
        (c) => c.startsWith('recordPayment:'),
      );
      expect(
        createIdx,
        greaterThanOrEqualTo(0),
        reason: 'createBooking() must have been called.',
      );
      expect(
        recordPaymentIdx,
        greaterThan(createIdx),
        reason:
            'Requirement 3.3 AC1: recordPayment() must be called AFTER '
            'createBooking(), got call order ${repo.calls}.',
      );
      expect(
        repo.recordedPayment?.eventId,
        repo.createdBookingId,
        reason:
            'recordPayment() must be called against the event id '
            'returned by createBooking().',
      );
      expect(
        repo.recordedPayment?.amount,
        closeTo(29500, 0.01),
        reason:
            'recordPayment() must be called with the computed advance '
            'amount (50% of the ₹59,000 quote total).',
      );

      // AC3: on full success, navigate back with a success indication.
      expect(
        find.textContaining('converted to booking successfully'),
        findsOneWidget,
        reason:
            'Requirement 3.3 AC3: a success indication must be shown on '
            'full success.',
      );
      expect(
        find.byType(DcQuoteConversionScreen),
        findsNothing,
        reason:
            'Requirement 3.3 AC3: the screen must navigate back (pop) on '
            'full success.',
      );
      expect(
        holder.value,
        isTrue,
        reason:
            'Requirement 3.3 AC3: Navigator.pop(context, true) must '
            'resolve the pushed route with a success indication (true).',
      );

      // No rollback must have occurred on the success path.
      expect(repo.deletedBookingId, isNull);
      expect(
        repo.quoteStatusCalls,
        equals(<QuoteStatus>[QuoteStatus.accepted]),
      );
    });

    // -----------------------------------------------------------------
    // AC2 — rollback path: recordPayment() fails after booking creation.
    // -----------------------------------------------------------------
    testWidgets('when recordPayment() fails after booking creation, the screen '
        'deletes the created booking, reverts the quote status, and shows '
        'an error (AC2)', (tester) async {
      final repo = _RecordingDcRepository(recordPaymentShouldFail: true);
      final quote = _buildTestQuote(status: QuoteStatus.draft);

      final holder = await _pumpConversionScreen(
        tester,
        quote: quote,
        repo: repo,
      );

      await tester.tap(find.text('Convert to Booking'));
      await tester.pump();
      await tester.pumpAndSettle();

      // createBooking() happened before the failing recordPayment().
      expect(repo.calls, contains('createBooking'));
      expect(
        repo.calls.any((c) => c.startsWith('recordPayment:')),
        isTrue,
        reason: 'recordPayment() must have been attempted.',
      );

      // AC2: the created booking is deleted (rollback).
      expect(
        repo.deletedBookingId,
        repo.createdBookingId,
        reason:
            'Requirement 3.3 AC2: the created booking must be deleted '
            'when recordPayment() fails.',
      );

      // AC2: the quote status is reverted to its pre-conversion value.
      // updateQuoteStatus is called twice: once to mark it accepted
      // (start of conversion), then again to revert to the original
      // status once recordPayment() fails.
      expect(
        repo.quoteStatusCalls,
        equals(<QuoteStatus>[QuoteStatus.accepted, quote.status]),
        reason:
            'Requirement 3.3 AC2: the quote status must be reverted to '
            'its pre-conversion value (${quote.status}) after rollback.',
      );

      // AC2: an error indicating the advance could not be recorded is
      // shown.
      expect(
        find.textContaining('Could not record advance payment'),
        findsOneWidget,
        reason:
            'Requirement 3.3 AC2: an error indicating the advance could '
            'not be recorded must be shown.',
      );

      // No success navigation occurred — the screen (and its "Convert to
      // Booking" button) is still present, and the pushed route's Future
      // has not resolved.
      expect(find.byType(DcQuoteConversionScreen), findsOneWidget);
      expect(find.text('Convert to Booking'), findsOneWidget);
      expect(
        holder.value,
        isNull,
        reason:
            'Requirement 3.3 AC2: on the rollback path the screen must '
            'not navigate back with a success indication.',
      );
    });
  });
}
