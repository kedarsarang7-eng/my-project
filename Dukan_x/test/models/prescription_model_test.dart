import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/doctor/models/prescription_model.dart';

void main() {
  group('PrescriptionItemModel', () {
    test('should support serialization with null fields', () {
      final item = PrescriptionItemModel(
        id: '1',
        prescriptionId: 'p1',
        medicineName: 'Paracetamol',
        productId: null,
      );

      final map = item.toMap();
      expect(map['id'], '1');
      expect(map['productId'], null);

      final parsed = PrescriptionItemModel.fromMap(map);
      expect(parsed.id, '1');
      expect(parsed.productId, null);
    });

    test('should support serialization with productId', () {
      final item = PrescriptionItemModel(
        id: '2',
        prescriptionId: 'p2',
        medicineName: 'Aspirin',
        productId: 'prod-123',
      );

      final map = item.toMap();
      expect(map['productId'], 'prod-123');

      final parsed = PrescriptionItemModel.fromMap(map);
      expect(parsed.productId, 'prod-123');
    });
  });

  group('PrescriptionModel', () {
    test('should serialize items list to JSON string', () {
      final p = PrescriptionModel(
        id: 'p1',
        doctorId: 'd1',
        patientId: 'pat1',
        visitId: 'v1',
        date: DateTime.now(),
        updatedAt: DateTime.now(),
        createdAt: DateTime.now(),
        items: [
          PrescriptionItemModel(
            id: 'i1',
            prescriptionId: 'p1',
            medicineName: 'Med 1',
            dosage: '1-0-1',
          ),
        ],
      );

      final jsonStr = p.medicinesJson;
      expect(jsonStr, contains('Med 1'));
      expect(jsonStr, contains('1-0-1'));
    });
  });
}
