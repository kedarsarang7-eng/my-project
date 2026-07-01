import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/petrol_pump/models/fuel_type.dart';
import 'package:dukanx/features/petrol_pump/models/shift.dart';
import 'package:dukanx/features/petrol_pump/models/tank.dart';
import 'package:dukanx/features/petrol_pump/models/dispenser.dart';
import 'dart:convert';

void main() {
  group('Petrol Pump Models Serialization', () {
    test('FuelType serialization', () {
      final fuel = FuelType(
        fuelId: 'fuel_1',
        fuelName: 'Petrol',
        currentRatePerLitre: 100.0,
        ownerId: 'owner_1',
        rateHistory: [RateHistoryEntry(date: DateTime(2023, 1, 1), rate: 90.0)],
      );

      final map = fuel.toMap();
      expect(map['fuelId'], 'fuel_1');
      expect(map['rateHistory'], isA<List>());

      // Simulate SQLite JSON storage for List
      final jsonString = jsonEncode(map['rateHistory']);
      final decodedList = jsonDecode(jsonString);
      map['rateHistory'] = decodedList;

      final fromMap = FuelType.fromMap('fuel_1', map);
      expect(fromMap.fuelName, 'Petrol');
      expect(fromMap.rateHistory.length, 1);
      expect(fromMap.rateHistory.first.rate, 90.0);
    });

    test('Shift serialization with PaymentBreakup', () {
      final shift = Shift(
        shiftId: 'shift_1',
        shiftName: 'Morning',
        startTime: DateTime(2023, 1, 1, 8, 0),
        ownerId: 'owner_1',
        paymentBreakup: const PaymentBreakup(cash: 500, upi: 200),
        assignedEmployeeIds: ['emp_1', 'emp_2'],
      );

      final map = shift.toMap();
      expect(map['paymentBreakup'], isA<Map>());
      expect(map['paymentBreakup']['cash'], 500.0);
      expect(map['assignedEmployeeIds'], ['emp_1', 'emp_2']);

      final fromMap = Shift.fromMap('shift_1', map);
      expect(fromMap.paymentBreakup.cash, 500.0);
      expect(fromMap.paymentBreakup.upi, 200.0);
      expect(fromMap.assignedEmployeeIds, contains('emp_1'));
    });

    test('Tank serialization', () {
      final tank = Tank(
        tankId: 'tank_1',
        tankName: 'Main Tank',
        fuelTypeId: 'fuel_1',
        capacity: 10000,
        currentStock: 5000,
        ownerId: 'owner_1',
      );

      final map = tank.toMap();
      final fromMap = Tank.fromMap('tank_1', map);

      expect(fromMap.tankName, 'Main Tank');
      expect(fromMap.currentStock, 5000.0);
    });

    test('Dispenser serialization with Nozzle IDs', () {
      final dispenser = Dispenser(
        dispenserId: 'disp_1',
        name: 'D1',
        nozzleIds: ['noz_1', 'noz_2'],
        ownerId: 'owner_1',
      );

      final map = dispenser.toMap();
      expect(map['nozzleIds'], ['noz_1', 'noz_2']);

      // Simulate SQLite JSON storage
      // In DatabaseHelper, we store lists as JSON strings if passing to insert
      // But fromMap expects List<dynamic> usually from Firestore/JSON

      final fromMap = Dispenser.fromMap('disp_1', map);
      expect(fromMap.nozzleIds, contains('noz_1'));
      expect(fromMap.nozzleIds.length, 2);
    });
  });
}
