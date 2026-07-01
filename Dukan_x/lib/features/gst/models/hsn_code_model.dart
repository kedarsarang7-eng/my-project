/// HSN Code model with tax rates
class HsnCodeModel {
  final String hsnCode;
  final String description;
  final double cgstRate;
  final double sgstRate;
  final double igstRate;
  final String? unit; // KGS, NOS, MTR, etc.
  final bool isActive;

  HsnCodeModel({
    required this.hsnCode,
    required this.description,
    required this.cgstRate,
    required this.sgstRate,
    required this.igstRate,
    this.unit,
    this.isActive = true,
  });

  /// Total GST rate (for intrastate: CGST + SGST, for interstate: IGST)
  double get totalGstRate => igstRate; // IGST = CGST + SGST

  Map<String, dynamic> toMap() => {
    'hsnCode': hsnCode,
    'description': description,
    'cgstRate': cgstRate,
    'sgstRate': sgstRate,
    'igstRate': igstRate,
    'unit': unit,
    'isActive': isActive,
  };

  factory HsnCodeModel.fromMap(Map<String, dynamic> map) => HsnCodeModel(
    hsnCode: map['hsnCode'] ?? '',
    description: map['description'] ?? '',
    cgstRate: (map['cgstRate'] ?? 0).toDouble(),
    sgstRate: (map['sgstRate'] ?? 0).toDouble(),
    igstRate: (map['igstRate'] ?? 0).toDouble(),
    unit: map['unit'],
    isActive: map['isActive'] ?? true,
  );

  HsnCodeModel copyWith({
    String? hsnCode,
    String? description,
    double? cgstRate,
    double? sgstRate,
    double? igstRate,
    String? unit,
    bool? isActive,
  }) {
    return HsnCodeModel(
      hsnCode: hsnCode ?? this.hsnCode,
      description: description ?? this.description,
      cgstRate: cgstRate ?? this.cgstRate,
      sgstRate: sgstRate ?? this.sgstRate,
      igstRate: igstRate ?? this.igstRate,
      unit: unit ?? this.unit,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() => 'HSN $hsnCode: $description ($igstRate% GST)';
}

/// Common GST tax slabs in India
class GstTaxSlabs {
  static const List<double> rates = [0, 5, 12, 18, 28];

  static List<HsnCodeModel> get commonHsnCodes => [
    // Common goods
    HsnCodeModel(
      hsnCode: '1006',
      description: 'Rice',
      cgstRate: 0,
      sgstRate: 0,
      igstRate: 0,
      unit: 'KGS',
    ),
    HsnCodeModel(
      hsnCode: '1001',
      description: 'Wheat',
      cgstRate: 0,
      sgstRate: 0,
      igstRate: 0,
      unit: 'KGS',
    ),
    HsnCodeModel(
      hsnCode: '0401',
      description: 'Milk',
      cgstRate: 0,
      sgstRate: 0,
      igstRate: 0,
      unit: 'LTR',
    ),
    HsnCodeModel(
      hsnCode: '0702',
      description: 'Tomatoes',
      cgstRate: 0,
      sgstRate: 0,
      igstRate: 0,
      unit: 'KGS',
    ),
    HsnCodeModel(
      hsnCode: '2710',
      description: 'Petroleum oils (Petrol/Diesel)',
      cgstRate: 0,
      sgstRate: 0,
      igstRate: 0, // Excluded from GST
      unit: 'LTR',
    ),
    // 5% GST items
    HsnCodeModel(
      hsnCode: '1905',
      description: 'Bread, pastry, cakes, biscuits',
      cgstRate: 2.5,
      sgstRate: 2.5,
      igstRate: 5,
      unit: 'KGS',
    ),
    HsnCodeModel(
      hsnCode: '0402',
      description: 'Skimmed milk powder',
      cgstRate: 2.5,
      sgstRate: 2.5,
      igstRate: 5,
      unit: 'KGS',
    ),
    // 12% GST items
    HsnCodeModel(
      hsnCode: '8471',
      description: 'Computers',
      cgstRate: 6,
      sgstRate: 6,
      igstRate: 12,
      unit: 'NOS',
    ),
    HsnCodeModel(
      hsnCode: '3304',
      description: 'Beauty/make-up preparations',
      cgstRate: 6,
      sgstRate: 6,
      igstRate: 12,
      unit: 'NOS',
    ),
    // 18% GST items
    HsnCodeModel(
      hsnCode: '8517',
      description: 'Mobile phones',
      cgstRate: 9,
      sgstRate: 9,
      igstRate: 18,
      unit: 'NOS',
    ),
    HsnCodeModel(
      hsnCode: '9403',
      description: 'Furniture',
      cgstRate: 9,
      sgstRate: 9,
      igstRate: 18,
      unit: 'NOS',
    ),
    // 28% GST items
    HsnCodeModel(
      hsnCode: '8703',
      description: 'Motor cars',
      cgstRate: 14,
      sgstRate: 14,
      igstRate: 28,
      unit: 'NOS',
    ),
    HsnCodeModel(
      hsnCode: '3303',
      description: 'Perfumes and toilet waters',
      cgstRate: 14,
      sgstRate: 14,
      igstRate: 28,
      unit: 'NOS',
    ),
  ];
}
