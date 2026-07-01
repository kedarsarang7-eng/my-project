import 'package:dukanx/core/compat/firestore_compat.dart';

/// Dispenser entity representing a fuel dispensing unit
/// A dispenser can have multiple nozzles (typically 2-4)
class Dispenser {
  final String dispenserId;
  final String name;
  final List<String> nozzleIds;
  final String? linkedTankId;
  final String ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  Dispenser({
    required this.dispenserId,
    required this.name,
    this.nozzleIds = const [],
    this.linkedTankId,
    required this.ownerId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isActive = true,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Dispenser copyWith({
    String? dispenserId,
    String? name,
    List<String>? nozzleIds,
    String? linkedTankId,
    String? ownerId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return Dispenser(
      dispenserId: dispenserId ?? this.dispenserId,
      name: name ?? this.name,
      nozzleIds: nozzleIds ?? this.nozzleIds,
      linkedTankId: linkedTankId ?? this.linkedTankId,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() => {
    'dispenserId': dispenserId,
    'name': name,
    'nozzleIds': nozzleIds,
    'linkedTankId': linkedTankId,
    'ownerId': ownerId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isActive': isActive,
  };

  factory Dispenser.fromMap(String id, Map<String, dynamic> map) {
    return Dispenser(
      dispenserId: id,
      name: map['name'] as String? ?? '',
      nozzleIds:
          (map['nozzleIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      linkedTankId: map['linkedTankId'] as String?,
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
}
