import 'package:dukanx/core/compat/firestore_compat.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../models/fuel_type.dart';

class FuelService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _ownerId => sl<SessionManager>().ownerId ?? '';

  CollectionReference get _fuelCollection =>
      _firestore.collection('owners').doc(_ownerId).collection('fuelTypes');

  /// Add default fuel types for a new petrol pump setup
  Future<void> initializeDefaultFuels() async {
    final defaults = FuelType.defaultFuelTypes(_ownerId);
    final batch = _firestore.batch();

    for (var fuel in defaults) {
      final docRef = _fuelCollection.doc(fuel.fuelId);
      final doc = await docRef.get();
      if (!doc.exists) {
        batch.set(docRef, fuel.toMap());
      }
    }

    await batch.commit();
  }

  /// Get all fuel types
  Stream<List<FuelType>> getFuelTypes() {
    return _fuelCollection.snapshots().map((snapshot) {
      return snapshot.docs
          .map(
            (doc) =>
                FuelType.fromMap(doc.id, doc.data() as Map<String, dynamic>),
          )
          .toList();
    });
  }

  /// Update fuel rate
  Future<void> updateFuelRate(
    String fuelId,
    double newRate, {
    String? updatedBy,
  }) async {
    final docRef = _fuelCollection.doc(fuelId);
    final doc = await docRef.get();

    if (doc.exists) {
      final fuel = FuelType.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      final updatedFuel = fuel.updateRate(newRate, updatedBy: updatedBy);
      await docRef.update(updatedFuel.toMap());
    }
  }

  /// Add new custom fuel type
  Future<void> addFuelType(FuelType fuel) async {
    await _fuelCollection.doc(fuel.fuelId).set(fuel.toMap());
  }

  /// Toggle fuel active status
  Future<void> toggleFuelStatus(String fuelId, bool isActive) async {
    await _fuelCollection.doc(fuelId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
