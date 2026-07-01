import 'package:dukanx/core/compat/firestore_compat.dart';

/// Simple date range class for financial year calculations.
/// Using a custom class instead of Flutter's DateTimeRange to keep model pure.
class FinancialYearRange {
  final DateTime start;
  final DateTime end;
  const FinancialYearRange({required this.start, required this.end});

  Duration get duration => end.difference(start);
}

/// Business Entity - The root tenant container for multi-business support.
///
/// Every business entity (shop/firm) has a unique ID that serves as the
/// foreign key root for all related data: customers, suppliers, ledgers,
/// stock items, and transactions.
///
/// This replaces the legacy `ownerId`-based ownership pattern and ensures
/// proper multi-tenancy with strong referential integrity.
class Business {
  final String id;
  final String ownerId; // Firebase Auth UID of the owner
  final String name;
  final String? gstin;
  final String? pan;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String phone;
  final String? email;
  final String currency;
  final DateTime financialYearStart;
  final String businessType; // grocery, pharmacy, restaurant, etc.
  final bool isActive;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Settings embedded for quick access
  final BusinessSettings settings;

  const Business({
    required this.id,
    required this.ownerId,
    required this.name,
    this.gstin,
    this.pan,
    this.address = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
    this.phone = '',
    this.email,
    this.currency = 'INR',
    required this.financialYearStart,
    this.businessType = 'grocery',
    this.isActive = true,
    this.version = 1,
    required this.createdAt,
    required this.updatedAt,
    this.settings = const BusinessSettings(),
  });

  /// Empty business for initialization
  factory Business.empty(String ownerId) => Business(
    id: '',
    ownerId: ownerId,
    name: '',
    financialYearStart: DateTime(DateTime.now().year, 4, 1), // April 1
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  /// Create from Firestore document
  factory Business.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Business.fromMap(doc.id, data);
  }

  /// Create from Map
  factory Business.fromMap(String id, Map<String, dynamic> map) {
    return Business(
      id: id,
      ownerId: map['ownerId'] ?? '',
      name: map['name'] ?? '',
      gstin: map['gstin'],
      pan: map['pan'],
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      pincode: map['pincode'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'],
      currency: map['currency'] ?? 'INR',
      financialYearStart:
          _parseDate(map['financialYearStart']) ??
          DateTime(DateTime.now().year, 4, 1),
      businessType: map['businessType'] ?? 'grocery',
      isActive: map['isActive'] ?? true,
      version: map['version'] ?? 1,
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(map['updatedAt']) ?? DateTime.now(),
      settings: map['settings'] != null
          ? BusinessSettings.fromMap(map['settings'])
          : const BusinessSettings(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'name': name,
      'gstin': gstin,
      'pan': pan,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'phone': phone,
      'email': email,
      'currency': currency,
      'financialYearStart': Timestamp.fromDate(financialYearStart),
      'businessType': businessType,
      'isActive': isActive,
      'version': version,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'settings': settings.toMap(),
    };
  }

  /// Convert to Map (for local storage)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'name': name,
      'gstin': gstin,
      'pan': pan,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'phone': phone,
      'email': email,
      'currency': currency,
      'financialYearStart': financialYearStart.toIso8601String(),
      'businessType': businessType,
      'isActive': isActive,
      'version': version,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'settings': settings.toMap(),
    };
  }

  Business copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? gstin,
    String? pan,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? phone,
    String? email,
    String? currency,
    DateTime? financialYearStart,
    String? businessType,
    bool? isActive,
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
    BusinessSettings? settings,
  }) {
    return Business(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      gstin: gstin ?? this.gstin,
      pan: pan ?? this.pan,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      currency: currency ?? this.currency,
      financialYearStart: financialYearStart ?? this.financialYearStart,
      businessType: businessType ?? this.businessType,
      isActive: isActive ?? this.isActive,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      settings: settings ?? this.settings,
    );
  }

  /// Validate GSTIN format
  bool get isGstinValid {
    if (gstin == null || gstin!.isEmpty) return true;
    final regex = RegExp(
      r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
      caseSensitive: false,
    );
    return regex.hasMatch(gstin!.toUpperCase());
  }

  /// Check if business is complete for invoicing
  bool get isComplete =>
      name.isNotEmpty && address.isNotEmpty && phone.isNotEmpty;

  /// Get current financial year range
  FinancialYearRange get currentFinancialYear {
    final now = DateTime.now();
    final fyMonth = financialYearStart.month;
    final fyDay = financialYearStart.day;

    DateTime start;
    DateTime end;

    if (now.month >= fyMonth || (now.month == fyMonth && now.day >= fyDay)) {
      // Current FY started this calendar year
      start = DateTime(now.year, fyMonth, fyDay);
      end = DateTime(
        now.year + 1,
        fyMonth,
        fyDay,
      ).subtract(const Duration(days: 1));
    } else {
      // Current FY started last calendar year
      start = DateTime(now.year - 1, fyMonth, fyDay);
      end = DateTime(
        now.year,
        fyMonth,
        fyDay,
      ).subtract(const Duration(days: 1));
    }

    return FinancialYearRange(start: start, end: end);
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  @override
  String toString() => 'Business(id: $id, name: $name, owner: $ownerId)';
}

/// Business-level settings
class BusinessSettings {
  final bool enableGst;
  final bool enableInventory;
  final bool enableCreditNotes;
  final bool allowNegativeStock;
  final String invoicePrefix;
  final int nextInvoiceNumber;
  final String defaultPaymentMode;
  final int dueDays; // Default credit period

  const BusinessSettings({
    this.enableGst = true,
    this.enableInventory = true,
    this.enableCreditNotes = true,
    this.allowNegativeStock = false,
    this.invoicePrefix = 'INV',
    this.nextInvoiceNumber = 1,
    this.defaultPaymentMode = 'Cash',
    this.dueDays = 30,
  });

  factory BusinessSettings.fromMap(Map<String, dynamic> map) {
    return BusinessSettings(
      enableGst: map['enableGst'] ?? true,
      enableInventory: map['enableInventory'] ?? true,
      enableCreditNotes: map['enableCreditNotes'] ?? true,
      allowNegativeStock: map['allowNegativeStock'] ?? false,
      invoicePrefix: map['invoicePrefix'] ?? 'INV',
      nextInvoiceNumber: map['nextInvoiceNumber'] ?? 1,
      defaultPaymentMode: map['defaultPaymentMode'] ?? 'Cash',
      dueDays: map['dueDays'] ?? 30,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enableGst': enableGst,
      'enableInventory': enableInventory,
      'enableCreditNotes': enableCreditNotes,
      'allowNegativeStock': allowNegativeStock,
      'invoicePrefix': invoicePrefix,
      'nextInvoiceNumber': nextInvoiceNumber,
      'defaultPaymentMode': defaultPaymentMode,
      'dueDays': dueDays,
    };
  }

  BusinessSettings copyWith({
    bool? enableGst,
    bool? enableInventory,
    bool? enableCreditNotes,
    bool? allowNegativeStock,
    String? invoicePrefix,
    int? nextInvoiceNumber,
    String? defaultPaymentMode,
    int? dueDays,
  }) {
    return BusinessSettings(
      enableGst: enableGst ?? this.enableGst,
      enableInventory: enableInventory ?? this.enableInventory,
      enableCreditNotes: enableCreditNotes ?? this.enableCreditNotes,
      allowNegativeStock: allowNegativeStock ?? this.allowNegativeStock,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      nextInvoiceNumber: nextInvoiceNumber ?? this.nextInvoiceNumber,
      defaultPaymentMode: defaultPaymentMode ?? this.defaultPaymentMode,
      dueDays: dueDays ?? this.dueDays,
    );
  }
}
