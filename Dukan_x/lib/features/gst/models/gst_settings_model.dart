/// GST Settings Model for business GST configuration
class GstSettingsModel {
  final String id; // userId
  final String? gstin;
  final String? stateCode;
  final String? legalName;
  final String? tradeName;
  final String filingFrequency; // MONTHLY, QUARTERLY
  final bool isCompositionScheme;
  final double compositionRate;
  final bool isEInvoiceEnabled;
  final DateTime? registrationDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;

  GstSettingsModel({
    required this.id,
    this.gstin,
    this.stateCode,
    this.legalName,
    this.tradeName,
    this.filingFrequency = 'MONTHLY',
    this.isCompositionScheme = false,
    this.compositionRate = 1.0,
    this.isEInvoiceEnabled = false,
    this.registrationDate,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
  });

  /// Whether GST is enabled for this business
  bool get isGstEnabled => gstin != null && gstin!.isNotEmpty;

  /// State name from code (first 2 digits of GSTIN)
  String? get stateName =>
      stateCode != null ? IndianStates.getName(stateCode!) : null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'gstin': gstin,
      'stateCode': stateCode,
      'legalName': legalName,
      'tradeName': tradeName,
      'filingFrequency': filingFrequency,
      'isCompositionScheme': isCompositionScheme,
      'compositionRate': compositionRate,
      'isEInvoiceEnabled': isEInvoiceEnabled,
      'registrationDate': registrationDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isSynced': isSynced,
    };
  }

  factory GstSettingsModel.fromMap(Map<String, dynamic> map) {
    return GstSettingsModel(
      id: map['id'] ?? '',
      gstin: map['gstin'],
      stateCode: map['stateCode'],
      legalName: map['legalName'],
      tradeName: map['tradeName'],
      filingFrequency: map['filingFrequency'] ?? 'MONTHLY',
      isCompositionScheme: map['isCompositionScheme'] ?? false,
      compositionRate: (map['compositionRate'] ?? 1.0).toDouble(),
      isEInvoiceEnabled: map['isEInvoiceEnabled'] ?? false,
      registrationDate: map['registrationDate'] != null
          ? DateTime.tryParse(map['registrationDate'])
          : null,
      createdAt: DateTime.parse(
        map['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        map['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
      isSynced: map['isSynced'] ?? false,
    );
  }

  GstSettingsModel copyWith({
    String? id,
    String? gstin,
    String? stateCode,
    String? legalName,
    String? tradeName,
    String? filingFrequency,
    bool? isCompositionScheme,
    double? compositionRate,
    bool? isEInvoiceEnabled,
    DateTime? registrationDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return GstSettingsModel(
      id: id ?? this.id,
      gstin: gstin ?? this.gstin,
      stateCode: stateCode ?? this.stateCode,
      legalName: legalName ?? this.legalName,
      tradeName: tradeName ?? this.tradeName,
      filingFrequency: filingFrequency ?? this.filingFrequency,
      isCompositionScheme: isCompositionScheme ?? this.isCompositionScheme,
      compositionRate: compositionRate ?? this.compositionRate,
      isEInvoiceEnabled: isEInvoiceEnabled ?? this.isEInvoiceEnabled,
      registrationDate: registrationDate ?? this.registrationDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

/// Indian State codes as per GST
class IndianStates {
  static const Map<String, String> codes = {
    '01': 'Jammu & Kashmir',
    '02': 'Himachal Pradesh',
    '03': 'Punjab',
    '04': 'Chandigarh',
    '05': 'Uttarakhand',
    '06': 'Haryana',
    '07': 'Delhi',
    '08': 'Rajasthan',
    '09': 'Uttar Pradesh',
    '10': 'Bihar',
    '11': 'Sikkim',
    '12': 'Arunachal Pradesh',
    '13': 'Nagaland',
    '14': 'Manipur',
    '15': 'Mizoram',
    '16': 'Tripura',
    '17': 'Meghalaya',
    '18': 'Assam',
    '19': 'West Bengal',
    '20': 'Jharkhand',
    '21': 'Odisha',
    '22': 'Chhattisgarh',
    '23': 'Madhya Pradesh',
    '24': 'Gujarat',
    '25': 'Daman & Diu', // Now part of Dadra & Nagar Haveli
    '26': 'Dadra & Nagar Haveli',
    '27': 'Maharashtra',
    '28': 'Andhra Pradesh (Old)',
    '29': 'Karnataka',
    '30': 'Goa',
    '31': 'Lakshadweep',
    '32': 'Kerala',
    '33': 'Tamil Nadu',
    '34': 'Puducherry',
    '35': 'Andaman & Nicobar',
    '36': 'Telangana',
    '37': 'Andhra Pradesh',
    '38': 'Ladakh',
  };

  static String? getName(String code) => codes[code];

  static String? getCodeFromGstin(String gstin) {
    if (gstin.length >= 2) {
      return gstin.substring(0, 2);
    }
    return null;
  }

  static List<MapEntry<String, String>> get sortedList {
    return codes.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
  }
}
