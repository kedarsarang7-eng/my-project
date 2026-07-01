/// Drug schedule categories per Indian Drugs & Cosmetics Act
enum DrugSchedule {
  none,     // OTC — no restriction
  scheduleH,  // Requires prescription (red Rx symbol)
  scheduleH1, // Requires prescription + record keeping
  scheduleX,  // Narcotic — requires prescription + register + ID proof
}

extension DrugScheduleX on DrugSchedule {
  String get label => switch (this) {
    DrugSchedule.none => 'OTC',
    DrugSchedule.scheduleH => 'Schedule H',
    DrugSchedule.scheduleH1 => 'Schedule H1',
    DrugSchedule.scheduleX => 'Schedule X',
  };

  bool get requiresPrescription =>
      this == DrugSchedule.scheduleH ||
      this == DrugSchedule.scheduleH1 ||
      this == DrugSchedule.scheduleX;

  bool get requiresNarcoticRegister => this == DrugSchedule.scheduleX;

  bool get requiresRecordKeeping =>
      this == DrugSchedule.scheduleH1 || this == DrugSchedule.scheduleX;

  static DrugSchedule fromString(String? value) {
    if (value == null || value.isEmpty) return DrugSchedule.none;
    switch (value.toUpperCase().replaceAll(' ', '')) {
      case 'H':
      case 'SCHEDULEH':
        return DrugSchedule.scheduleH;
      case 'H1':
      case 'SCHEDULEH1':
        return DrugSchedule.scheduleH1;
      case 'X':
      case 'SCHEDULEX':
        return DrugSchedule.scheduleX;
      default:
        return DrugSchedule.none;
    }
  }
}

/// Service that enforces drug schedule compliance before billing
class DrugScheduleService {
  /// Check if any item in cart requires prescription
  /// Returns list of items that need prescription before billing can proceed
  List<CartComplianceResult> validateCart(List<CartDrugItem> cartItems) {
    final results = <CartComplianceResult>[];
    for (final item in cartItems) {
      final schedule = DrugScheduleX.fromString(item.drugSchedule);
      if (schedule.requiresPrescription && !item.hasPrescriptionAttached) {
        results.add(CartComplianceResult(
          productId: item.productId,
          productName: item.productName,
          schedule: schedule,
          requiresPrescription: true,
          requiresNarcoticEntry: schedule.requiresNarcoticRegister,
        ));
      }
    }
    return results;
  }

  /// Check for duplicate molecules in cart (basic drug interaction)
  List<DrugInteractionWarning> checkDrugInteractions(
      List<CartDrugItem> cartItems) {
    final warnings = <DrugInteractionWarning>[];
    final moleculeMap = <String, List<String>>{};

    for (final item in cartItems) {
      if (item.molecule != null && item.molecule!.isNotEmpty) {
        final normalizedMolecule = item.molecule!.toLowerCase().trim();
        moleculeMap.putIfAbsent(normalizedMolecule, () => []);
        moleculeMap[normalizedMolecule]!.add(item.productName);
      }
    }

    for (final entry in moleculeMap.entries) {
      if (entry.value.length > 1) {
        warnings.add(DrugInteractionWarning(
          molecule: entry.key,
          products: entry.value,
          severity: 'HIGH',
          message:
              'Same molecule "${entry.key}" found in: ${entry.value.join(", ")}. '
              'Risk of overdose. Verify prescription.',
        ));
      }
    }

    return warnings;
  }
}

class CartDrugItem {
  final String productId;
  final String productName;
  final String? drugSchedule;
  final String? molecule; // Generic/salt name
  final bool hasPrescriptionAttached;

  CartDrugItem({
    required this.productId,
    required this.productName,
    this.drugSchedule,
    this.molecule,
    this.hasPrescriptionAttached = false,
  });
}

class CartComplianceResult {
  final String productId;
  final String productName;
  final DrugSchedule schedule;
  final bool requiresPrescription;
  final bool requiresNarcoticEntry;

  CartComplianceResult({
    required this.productId,
    required this.productName,
    required this.schedule,
    required this.requiresPrescription,
    required this.requiresNarcoticEntry,
  });
}

class DrugInteractionWarning {
  final String molecule;
  final List<String> products;
  final String severity;
  final String message;

  DrugInteractionWarning({
    required this.molecule,
    required this.products,
    required this.severity,
    required this.message,
  });
}
