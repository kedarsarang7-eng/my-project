import 'package:dukanx/core/compat/firestore_compat.dart';

/// Rate history entry for tracking fuel price changes
class RateHistoryEntry {
  final DateTime date;
  final double rate;
  final String? updatedBy;

  RateHistoryEntry({required this.date, required this.rate, this.updatedBy});

  Map<String, dynamic> toMap() => {
    'date': date.toIso8601String(),
    'rate': rate,
    if (updatedBy != null) 'updatedBy': updatedBy,
  };

  factory RateHistoryEntry.fromMap(Map<String, dynamic> map) =>
      RateHistoryEntry(
        date: DateTime.parse(map['date'] as String),
        rate: (map['rate'] as num).toDouble(),
        updatedBy: map['updatedBy'] as String?,
      );
}

/// Fuel type configuration for Petrol Pump business
/// Represents different fuel types like Petrol, Diesel, CNG, Power
class FuelType {
  final String fuelId;
  final String fuelName;
  final double currentRatePerLitre;
  final List<RateHistoryEntry> rateHistory;
  final double linkedGSTRate;
  final String ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  FuelType({
    required this.fuelId,
    required this.fuelName,
    required this.currentRatePerLitre,
    this.rateHistory = const [],
    this.linkedGSTRate =
        0.0, // Petrol/diesel are outside GST; fuel GST defaults to 0
    required this.ownerId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isActive = true,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Create a copy with updated fields
  FuelType copyWith({
    String? fuelId,
    String? fuelName,
    double? currentRatePerLitre,
    List<RateHistoryEntry>? rateHistory,
    double? linkedGSTRate,
    String? ownerId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return FuelType(
      fuelId: fuelId ?? this.fuelId,
      fuelName: fuelName ?? this.fuelName,
      currentRatePerLitre: currentRatePerLitre ?? this.currentRatePerLitre,
      rateHistory: rateHistory ?? this.rateHistory,
      linkedGSTRate: linkedGSTRate ?? this.linkedGSTRate,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isActive: isActive ?? this.isActive,
    );
  }

  /// Update rate and add to history
  FuelType updateRate(double newRate, {String? updatedBy}) {
    final historyEntry = RateHistoryEntry(
      date: DateTime.now(),
      rate: currentRatePerLitre, // Save old rate to history
      updatedBy: updatedBy,
    );
    return copyWith(
      currentRatePerLitre: newRate,
      rateHistory: [...rateHistory, historyEntry],
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'fuelId': fuelId,
    'fuelName': fuelName,
    'currentRatePerLitre': currentRatePerLitre,
    'rateHistory': rateHistory.map((e) => e.toMap()).toList(),
    'linkedGSTRate': linkedGSTRate,
    'ownerId': ownerId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isActive': isActive,
  };

  factory FuelType.fromMap(String id, Map<String, dynamic> map) {
    final historyRaw = map['rateHistory'] as List<dynamic>? ?? [];
    final history = historyRaw
        .map((e) => RateHistoryEntry.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    return FuelType(
      fuelId: id,
      fuelName: map['fuelName'] as String? ?? '',
      currentRatePerLitre:
          (map['currentRatePerLitre'] as num?)?.toDouble() ?? 0.0,
      rateHistory: history,
      linkedGSTRate: (map['linkedGSTRate'] as num?)?.toDouble() ?? 0.0,
      ownerId: map['ownerId'] as String? ?? '',
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  /// Default fuel types for initial setup
  static List<FuelType> defaultFuelTypes(String ownerId) => [
    FuelType(
      fuelId: 'petrol',
      fuelName: 'Petrol',
      currentRatePerLitre: 0.0,
      ownerId: ownerId,
    ),
    FuelType(
      fuelId: 'diesel',
      fuelName: 'Diesel',
      currentRatePerLitre: 0.0,
      ownerId: ownerId,
    ),
    FuelType(
      fuelId: 'cng',
      fuelName: 'CNG',
      currentRatePerLitre: 0.0,
      linkedGSTRate: 0.0, // Fuel is outside GST regime
      ownerId: ownerId,
    ),
    FuelType(
      fuelId: 'power',
      fuelName: 'Power (EV)',
      currentRatePerLitre: 0.0, // Per kWh for EV
      linkedGSTRate: 0.0, // Fuel is outside GST regime
      ownerId: ownerId,
    ),
  ];
}
