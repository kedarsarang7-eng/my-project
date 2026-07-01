// ============================================================================
// CUSTOMER DETAIL SCREEN — RENDERING REGRESSION TESTS
// ============================================================================
// Guards the Part 1 bug fix: after a customer is created/opened, the detail
// screen must render the name fully and never break layout (overflow) or crash
// on edge-case data (empty name, very large currency values) on a small phone.
//
// These tests drive the REAL CustomerDetailScreen widget through its normal
// load path (sl<CustomersRepository>().getById) using a mocked repository.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dukanx/core/error/error_handler.dart';
import 'package:dukanx/core/repository/customers_repository.dart';
import 'package:dukanx/features/customers/presentation/screens/customer_detail_screen.dart';

// Reuse the already-generated mock so no extra build_runner pass is needed.
import '../../integration/customer_flow_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockCustomersRepository mockRepo;

  Customer buildCustomer({
    required String name,
    double billed = 0,
    double paid = 0,
    double dues = 0,
    String? phone,
  }) {
    final now = DateTime.now();
    return Customer(
      id: 'c1',
      odId: 'owner1',
      name: name,
      phone: phone,
      totalBilled: billed,
      totalPaid: paid,
      totalDues: dues,
      createdAt: now,
      updatedAt: now,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GetIt.I.reset();
    mockRepo = MockCustomersRepository();
    GetIt.I.registerSingleton<CustomersRepository>(mockRepo);
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  /// Pumps the real detail screen on a narrow phone surface and returns the
  /// list of layout/exception errors captured during build & load.
  Future<List<FlutterErrorDetails>> pumpDetail(
    WidgetTester tester,
    Customer customer, {
    Size size = const Size(360, 720),
  }) async {
    when(
      mockRepo.getById(any),
    ).thenAnswer((_) async => RepositoryResult.success(customer));

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final errors = <FlutterErrorDetails>[];
    final oldHandler = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = oldHandler);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: CustomerDetailScreen(customerId: 'c1')),
        ),
      ),
    );
    // Resolve the async getById future and the resulting setState rebuild.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    return errors;
  }

  Iterable<FlutterErrorDetails> overflowOf(List<FlutterErrorDetails> e) =>
      e.where((d) => d.toString().contains('overflowed'));

  testWidgets('renders full customer name and no overflow on a small phone', (
    tester,
  ) async {
    const longName = 'Rajeshwari Venkataraman Subramaniam Enterprises Pvt Ltd';
    final errors = await pumpDetail(
      tester,
      buildCustomer(name: longName, phone: '9876543210'),
    );

    expect(find.text(longName), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
    expect(overflowOf(errors), isEmpty, reason: 'detail header overflowed');
  });

  testWidgets('large financial values do not overflow the summary row', (
    tester,
  ) async {
    // Dues = 0 keeps the test focused on the 3-stat row (no aging widget).
    final errors = await pumpDetail(
      tester,
      buildCustomer(name: 'Big Spender', billed: 98765432, paid: 12345678),
    );

    expect(find.text('₹98765432'), findsOneWidget);
    expect(find.text('₹12345678'), findsOneWidget);
    expect(
      overflowOf(errors),
      isEmpty,
      reason: 'financial summary row overflowed with large values',
    );
  });

  testWidgets('empty customer name does not crash and shows a safe fallback', (
    tester,
  ) async {
    final errors = await pumpDetail(tester, buildCustomer(name: '   '));

    // No RangeError from name[0] and a readable fallback is rendered.
    expect(
      errors.where((d) => d.exception is RangeError),
      isEmpty,
      reason: 'empty name must not throw RangeError on avatar initial',
    );
    expect(find.text('Unnamed Customer'), findsOneWidget);
    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('not-found state renders structure with a retry action', (
    tester,
  ) async {
    when(
      mockRepo.getById(any),
    ).thenAnswer((_) async => RepositoryResult.success(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: CustomerDetailScreen(customerId: 'missing')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Customer not found'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
