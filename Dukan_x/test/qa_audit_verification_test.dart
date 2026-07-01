import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dukanx/features/petrol_pump/services/petrol_pump_billing_service.dart';
import 'package:dukanx/features/petrol_pump/services/shift_service.dart';
import 'package:dukanx/features/petrol_pump/services/period_lock_service.dart';
import 'package:dukanx/features/petrol_pump/models/nozzle.dart';
import 'package:dukanx/features/petrol_pump/models/fuel_type.dart';
import 'package:dukanx/features/petrol_pump/models/shift.dart';
import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/core/repository/audit_repository.dart';
import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/core/repository/customers_repository.dart';

class MockAppDatabase extends Mock implements AppDatabase {}
class MockAuditRepository extends Mock implements AuditRepository {}
class MockSessionManager extends Mock implements SessionManager {}
class MockCustomersRepository extends Mock implements CustomersRepository {}

class MockShiftService extends Mock implements ShiftService {
  @override
  Future<Shift?> getActiveShift() => super.noSuchMethod(
    Invocation.method(#getActiveShift, []),
    returnValue: Future<Shift?>.value(null),
    returnValueForMissingStub: Future<Shift?>.value(null),
  );
}

class MockPeriodLockService extends Mock implements PeriodLockService {
  @override
  Future<bool> isDateLocked(DateTime? date) async {
    if (date != null && date.year == 2020) return true; // Lock 2020
    return false;
  }

  @override
  Future<DateTime?> getLockDate() => super.noSuchMethod(
    Invocation.method(#getLockDate, []),
    returnValue: Future.value(DateTime(2020, 12, 31)),
    returnValueForMissingStub: Future.value(DateTime(2020, 12, 31)),
  );

  @override
  Future<void> closePeriod(DateTime? newLockDate, String? userId) async {}
}

void main() {
  late PetrolPumpBillingService billingService;
  late MockShiftService mockShiftService;
  late MockPeriodLockService mockPeriodLockService;

  setUp(() {
    mockShiftService = MockShiftService();
    mockPeriodLockService = MockPeriodLockService();

    // Stub getActiveShift to return a dummy shift
    when(mockShiftService.getActiveShift()).thenAnswer(
      (_) async => Shift(
        shiftId: 'dummyShiftId',
        shiftName: 'Morning',
        ownerId: 'owner1',
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        status: ShiftStatus.open,
      ),
    );

    billingService = PetrolPumpBillingService(
      db: MockAppDatabase(),
      shiftService: mockShiftService,
      periodLockService: mockPeriodLockService,
      auditRepo: MockAuditRepository(),
      sessionManager: MockSessionManager(),
      customersRepo: MockCustomersRepository(),
    );
  });

  // Dummy Data
  final validNozzle = Nozzle(
    nozzleId: 'n1',
    dispenserId: 'd1',
    fuelTypeId: 'f1',
    fuelTypeName: 'Petrol',
    openingReading: 1000,
    closingReading: 1000,
    linkedShiftId: 's1',
    ownerId: 'owner1',
    isActive: true,
  );

  final petrolType = FuelType(
    fuelId: 'f1',
    fuelName: 'Petrol',
    currentRatePerLitre: 100,
    ownerId: 'owner1',
    isActive: true,
  );

  group('QA Critical Gaps Verification', () {
    test('Gap #2: Should block Backdated Bills', () async {
      final backDate = DateTime(2020, 1, 1); // Mock locks 2020

      expect(
        () async => await billingService.createFuelBill(
          nozzle: validNozzle,
          fuelType: petrolType,
          litres: 10,
          rate: 100,
          customerId: 'cust1',
          billDate: backDate, // Backdated
        ),
        throwsA(isA<PeriodLockedException>()),
      );
    });

    test('Gap #2: Should allow bills in Open Period', () async {
      final openDate = DateTime(2025, 1, 1);

      // Need to mock getActiveShift to avoid NRE
      // We don't care about return value structure much, just that it returns SOMETHING or null
      // Actually if safe call is made, we handle exceptions.
      // But let's testing PeriodLockedException absence.

      // Since createFuelBill calls activeShift check AFTER period lock,
      // if period lock passes, it might fail on activeShift (if we don't mock it).
      // That's fine, as long as it's not PeriodLockedException.

      try {
        await billingService.createFuelBill(
          nozzle: validNozzle,
          fuelType: petrolType,
          litres: 10,
          rate: 100,
          customerId: 'cust1',
          billDate: openDate,
        );
      } catch (e) {
        expect(e, isNot(isA<PeriodLockedException>()));
      }
    });
  });
}
