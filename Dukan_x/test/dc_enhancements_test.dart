// ============================================================================
// DC (Decoration & Catering) Module - Flutter Widget Tests
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/decoration_catering/data/models/dc_models.dart';
import 'package:dukanx/features/decoration_catering/data/repositories/dc_repository.dart';
import 'package:dukanx/features/decoration_catering/presentation/screens/dc_event_detail_screen.dart';
import 'package:dukanx/features/decoration_catering/presentation/screens/dc_quote_conversion_screen.dart';
import 'package:dukanx/features/decoration_catering/presentation/screens/dc_staff_attendance_screen.dart';
import 'package:dukanx/features/decoration_catering/presentation/widgets/dc_vendor_rating_dialog.dart';

// Mock repository for testing
class MockDcRepository implements DcRepository {
  @override
  Future<EventBooking?> getBookingById(String id) async {
    return EventBooking(
      id: id,
      customerId: 'cust-123',
      customerName: 'Test Customer',
      customerPhone: '9999999999',
      eventType: EventType.wedding,
      eventTitle: 'Test Wedding',
      eventDate: DateTime.now().add(const Duration(days: 7)),
      venue: 'Test Venue',
      guestCount: 100,
      quotedAmount: 100000,
      createdAt: DateTime.now(),
      assignedStaffIds: [],
      notesList: [
        DcEventNote(
          id: 'note-1',
          text: 'Initial meeting completed',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          createdBy: 'Manager',
        ),
        DcEventNote(
          id: 'note-2',
          text: 'Deposit received',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          createdBy: 'Admin',
        ),
      ],
    );
  }

  @override
  Future<List<DcEventNote>> getEventNotes(String eventId) async {
    return [
      DcEventNote(
        id: 'note-1',
        text: 'Initial meeting completed',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        createdBy: 'Manager',
      ),
      DcEventNote(
        id: 'note-2',
        text: 'Deposit received',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        createdBy: 'Admin',
      ),
    ];
  }

  @override
  Future<List<DcStaff>> getStaff({String? search, StaffRole? roleFilter}) async {
    return [
      DcStaff(
        id: 'staff-1',
        name: 'Rajesh',
        phone: '9999999999',
        role: StaffRole.decorator,
        dailyWage: 800,
      ),
      DcStaff(
        id: 'staff-2',
        name: 'Suresh',
        phone: '8888888888',
        role: StaffRole.cook,
        dailyWage: 1000,
      ),
    ];
  }

  @override
  Future<List<DcPayment>> getPayments({String? eventId}) async {
    return [
      DcPayment(
        id: 'pay-1',
        eventId: eventId ?? '',
        customerName: 'Test Customer',
        amount: 25000,
        method: PaymentMethod.cash,
        date: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ];
  }

  @override
  Future<List<DcExpense>> getExpenses({String? eventId, String? from, String? to}) async {
    return [
      DcExpense(
        id: 'exp-1',
        eventId: eventId ?? '',
        title: 'Flowers',
        category: 'decorations',
        amount: 15000,
        paymentMethod: PaymentMethod.cash,
        date: DateTime.now().subtract(const Duration(days: 3)),
        vendorId: 'vendor-1',
      ),
    ];
  }

  @override
  Future<List<DcVendor>> getVendors({String? search}) async {
    return [
      DcVendor(
        id: 'vendor-1',
        name: 'Flower Palace',
        phone: '7777777777',
        category: 'Flowers',
        totalPaid: 50000,
        totalDue: 25000,
        totalExpense: 75000,
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<List<DcEventNote>> appendEventNote(String eventId, String text) async => [];
  @override
  Future<EventBooking> assignStaffToEvent(String eventId, List<String> staffIds) async {
    return EventBooking(
      id: eventId,
      customerId: 'cust-123',
      customerName: 'Test Customer',
      customerPhone: '9999999999',
      eventType: EventType.wedding,
      eventTitle: 'Test Wedding',
      eventDate: DateTime.now().add(const Duration(days: 7)),
      venue: 'Test Venue',
      guestCount: 100,
      quotedAmount: 100000,
      createdAt: DateTime.now(),
      assignedStaffIds: staffIds,
      notesList: [],
    );
  }
  @override
  Future<EventBooking> createBooking(EventBooking booking) async => booking;
  @override
  Future<void> recordPayment(DcPayment payment) async {}
  @override
  Future<DcQuote> updateQuoteStatus(String quoteId, QuoteStatus status) async {
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
  Future<List<DcQuote>> getQuotes({String? status}) async => [];
  @override
  Future<List<DecorationTheme>> getThemes() async => [];
  @override
  Future<List<CateringPackage>> getPackages() async => [];
  @override
  Future<List<DcVendorPayment>> getVendorPayments(String vendorId) async => [];
  @override
  Future<DcVendorPayment> recordVendorPayment({
    required String vendorId,
    required double amount,
    required String paymentMode,
    String? reference,
    String? eventId,
    String? notes,
  }) async {
    return DcVendorPayment(
      id: 'vpay-1',
      vendorId: vendorId,
      vendorName: 'Test Vendor',
      amount: amount,
      paymentMode: paymentMode,
      date: DateTime.now(),
    );
  }

  // Unimplemented mock methods
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final mockRepo = MockDcRepository();

  group('DC Event Detail Screen', () {
    testWidgets('displays event overview tab correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dcRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            home: DcEventDetailScreen(eventId: 'event-123'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify customer info is displayed
      expect(find.text('Test Customer'), findsOneWidget);
      expect(find.text('Customer Details'), findsOneWidget);
      expect(find.text('Event Details'), findsOneWidget);
    });

    testWidgets('switches to timeline tab and shows notes', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dcRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            home: DcEventDetailScreen(eventId: 'event-123'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Timeline tab
      await tester.tap(find.text('Timeline'));
      await tester.pumpAndSettle();

      // Verify notes are displayed
      expect(find.text('Initial meeting completed'), findsOneWidget);
      expect(find.text('Deposit received'), findsOneWidget);
    });

    testWidgets('switches to staff tab and shows assignment UI', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dcRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            home: DcEventDetailScreen(eventId: 'event-123'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Staff tab
      await tester.tap(find.text('Staff'));
      await tester.pumpAndSettle();

      // Verify staff members are shown
      expect(find.text('Rajesh'), findsOneWidget);
      expect(find.text('Suresh'), findsOneWidget);
    });
  });

  group('DC Vendor Rating Dialog', () {
    testWidgets('displays rating stars correctly', (WidgetTester tester) async {
      double submittedRating = 0;
      String submittedComment = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => DcVendorRatingDialog(
                    vendor: DcVendor(
                      id: 'vendor-1',
                      name: 'Test Vendor',
                      phone: '9999999999',
                      category: 'Flowers',
                      createdAt: DateTime.now(),
                    ),
                    onSubmit: (rating, comment) {
                      submittedRating = rating;
                      submittedComment = comment;
                    },
                  ),
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog title
      expect(find.text('Rate Test Vendor'), findsOneWidget);

      // Tap on 4th star
      await tester.tap(find.byIcon(Icons.star_border).at(3));
      await tester.pumpAndSettle();

      // Enter comment
      await tester.enterText(find.byType(TextField), 'Great service!');

      // Tap submit
      await tester.tap(find.text('Submit Rating'));
      await tester.pumpAndSettle();

      // Verify submission
      expect(submittedRating, 4.0);
      expect(submittedComment, 'Great service!');
    });

    testWidgets('DcVendorRatingStars displays correct star count', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                DcVendorRatingStars(rating: 4.5, ratingCount: 10),
                DcVendorRatingStars(rating: 3.0, ratingCount: 5),
                DcVendorRatingStars(rating: 0, ratingCount: 0),
              ],
            ),
          ),
        ),
      );

      // Verify star icons are rendered
      expect(find.byIcon(Icons.star), findsWidgets);
      expect(find.byIcon(Icons.star_half), findsWidgets);
      expect(find.byIcon(Icons.star_border), findsWidgets);
    });
  });

  group('DC Quote Conversion Screen', () {
    testWidgets('displays quote summary and conversion form', (WidgetTester tester) async {
      final quote = DcQuote(
        id: 'quote-123',
        quoteNumber: 'QT-2026-001',
        customerName: 'Test Customer',
        customerPhone: '9999999999',
        eventType: 'Wedding',
        guestCount: 100,
        subtotal: 50000,
        gstAmount: 9000,
        total: 59000,
        status: QuoteStatus.draft,
        createdAt: DateTime.now(),
        eventDate: '2026-06-15',
        venue: 'Grand Hall',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dcRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            home: DcQuoteConversionScreen(quote: quote),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify quote details
      expect(find.text('Quote #QT-2026-001'), findsOneWidget);
      expect(find.text('Test Customer'), findsOneWidget);
      expect(find.text('Wedding'), findsOneWidget);
      expect(find.text('Grand Hall'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);

      // Verify conversion button
      expect(find.text('Convert to Booking'), findsOneWidget);
    });
  });

  group('DC Staff Attendance Screen', () {
    testWidgets('displays date selector and staff list', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dcRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: DcStaffAttendanceScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header and date
      expect(find.text('Staff Attendance'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);

      // Verify staff names
      expect(find.text('Rajesh'), findsOneWidget);
      expect(find.text('Suresh'), findsOneWidget);

      // Verify attendance toggles
      expect(find.text('Present'), findsWidgets);
      expect(find.text('Half'), findsWidgets);
      expect(find.text('Absent'), findsWidgets);

      // Verify save button
      expect(find.text('Save Attendance'), findsOneWidget);
    });
  });

  group('DC Models - Vendor totalDue Calculation', () {
    test('DcVendor correctly calculates totalBusiness', () {
      final vendor = DcVendor(
        id: 'vendor-1',
        name: 'Test Vendor',
        phone: '9999999999',
        category: 'Flowers',
        totalPaid: 50000,
        totalDue: 25000,
        totalExpense: 75000,
        createdAt: DateTime.now(),
      );

      expect(vendor.totalPaid, 50000);
      expect(vendor.totalDue, 25000);
      expect(vendor.totalExpense, 75000);
      expect(vendor.totalBusiness, 75000); // totalPaid + totalDue
    });
  });

  group('DC Models - Event Scheduling Fields', () {
    test('EventBooking includes scheduling times', () {
      final event = EventBooking(
        id: 'event-123',
        customerId: 'cust-123',
        customerName: 'Test Customer',
        customerPhone: '9999999999',
        eventType: EventType.wedding,
        eventTitle: 'Test Wedding',
        eventDate: DateTime.now(),
        venue: 'Test Venue',
        guestCount: 100,
        quotedAmount: 100000,
        createdAt: DateTime.now(),
        setupTime: '14:00',
        serviceStartTime: '16:00',
        serviceEndTime: '22:00',
        cleanupTime: '23:00',
      );

      expect(event.setupTime, '14:00');
      expect(event.serviceStartTime, '16:00');
      expect(event.serviceEndTime, '22:00');
      expect(event.cleanupTime, '23:00');
    });

    test('EventBooking copyWith preserves scheduling fields', () {
      final event = EventBooking(
        id: 'event-123',
        customerId: 'cust-123',
        customerName: 'Test Customer',
        customerPhone: '9999999999',
        eventType: EventType.wedding,
        eventTitle: 'Test Wedding',
        eventDate: DateTime.now(),
        venue: 'Test Venue',
        guestCount: 100,
        quotedAmount: 100000,
        createdAt: DateTime.now(),
        setupTime: '14:00',
        serviceStartTime: '16:00',
      );

      final updated = event.copyWith(
        setupTime: '13:00',
        serviceStartTime: '15:00',
      );

      expect(updated.setupTime, '13:00');
      expect(updated.serviceStartTime, '15:00');
      expect(updated.serviceEndTime, null); // unchanged
    });
  });

  group('DC Models - PaymentStatus calculation', () {
    test('PaymentStatus.pending when no advance paid', () {
      final event = EventBooking(
        id: 'event-123',
        customerId: 'cust-123',
        customerName: 'Test Customer',
        customerPhone: '9999999999',
        eventType: EventType.wedding,
        eventTitle: 'Test Wedding',
        eventDate: DateTime.now().add(const Duration(days: 7)),
        venue: 'Test Venue',
        guestCount: 100,
        quotedAmount: 100000,
        advancePaid: 0,
        createdAt: DateTime.now(),
      );

      expect(event.paymentStatus, PaymentStatus.pending);
    });

    test('PaymentStatus.paid when fully paid', () {
      final event = EventBooking(
        id: 'event-123',
        customerId: 'cust-123',
        customerName: 'Test Customer',
        customerPhone: '9999999999',
        eventType: EventType.wedding,
        eventTitle: 'Test Wedding',
        eventDate: DateTime.now().add(const Duration(days: 7)),
        venue: 'Test Venue',
        guestCount: 100,
        quotedAmount: 100000,
        advancePaid: 100000,
        createdAt: DateTime.now(),
      );

      expect(event.paymentStatus, PaymentStatus.paid);
    });

    test('PaymentStatus.overdue when past date with balance due', () {
      final event = EventBooking(
        id: 'event-123',
        customerId: 'cust-123',
        customerName: 'Test Customer',
        customerPhone: '9999999999',
        eventType: EventType.wedding,
        eventTitle: 'Test Wedding',
        eventDate: DateTime.now().subtract(const Duration(days: 1)), // Past date
        venue: 'Test Venue',
        guestCount: 100,
        quotedAmount: 100000,
        advancePaid: 50000,
        createdAt: DateTime.now(),
      );

      expect(event.paymentStatus, PaymentStatus.overdue);
    });
  });
}
