/// PerformanceScore model for Universal Staff Management module.
///
/// Maps to the backend PerformanceScore entity (SK: PERFSCORE#{id}).
/// Score is a deterministic weighted sum with inspectable contributing factors.
class PerformanceScoreModel {
  final String id;
  final String businessId;
  final String employeeId;
  final String period;
  final double score;
  final List<PerformanceFactor> factors;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PerformanceScoreModel({
    required this.id,
    required this.businessId,
    required this.employeeId,
    required this.period,
    required this.score,
    this.factors = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory PerformanceScoreModel.fromJson(Map<String, dynamic> json) {
    return PerformanceScoreModel(
      id: json['id'] as String? ?? '',
      businessId: json['businessId'] as String? ?? '',
      employeeId: json['employeeId'] as String? ?? '',
      period: json['period'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      factors:
          (json['factors'] as List<dynamic>?)
              ?.map(
                (e) => PerformanceFactor.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'businessId': businessId,
    'employeeId': employeeId,
    'period': period,
    'score': score,
    'factors': factors.map((f) => f.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

/// A contributing factor in a performance score calculation.
class PerformanceFactor {
  final String name;
  final double value;
  final double weight;

  const PerformanceFactor({
    required this.name,
    required this.value,
    required this.weight,
  });

  factory PerformanceFactor.fromJson(Map<String, dynamic> json) {
    return PerformanceFactor(
      name: json['name'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'value': value,
    'weight': weight,
  };
}
