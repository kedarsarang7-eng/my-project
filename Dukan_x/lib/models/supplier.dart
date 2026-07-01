import 'package:dukanx/core/compat/firestore_compat.dart';

/// Supplier Entity - Represents a vendor/supplier with ledger linkage.
///
/// Every supplier has a linked ledger account (Sundry Creditor) for
/// automatic double-entry accounting when purchase bills are created.
///
/// This replaces the legacy vendor management which lacked proper
/// accounting integration.
class Supplier {
  final String id;
  final String businessId; // FK to Business
  final String ledgerId; // FK to Ledger (Sundry Creditor)
  final String name;
  final String phone;
  final String? email;
  final String address;
  final String? gstin;
  final String? pan;
  final String? bankName;
  final String? accountNumber;
  final String? ifscCode;
  final String? upiId;
  final int creditDays; // Payment terms
  final double creditLimit;
  final bool isActive;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Supplier({
    required this.id,
    required this.businessId,
    required this.ledgerId,
    required this.name,
    this.phone = '',
    this.email,
    this.address = '',
    this.gstin,
    this.pan,
    this.bankName,
    this.accountNumber,
    this.ifscCode,
    this.upiId,
    this.creditDays = 30,
    this.creditLimit = 0,
    this.isActive = true,
    this.version = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from Firestore document
  factory Supplier.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Supplier.fromMap(doc.id, data);
  }

  /// Create from Map
  factory Supplier.fromMap(String id, Map<String, dynamic> map) {
    return Supplier(
      id: id,
      businessId: map['businessId'] ?? '',
      ledgerId: map['ledgerId'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'],
      address: map['address'] ?? '',
      gstin: map['gstin'],
      pan: map['pan'],
      bankName: map['bankName'],
      accountNumber: map['accountNumber'],
      ifscCode: map['ifscCode'],
      upiId: map['upiId'],
      creditDays: map['creditDays'] ?? 30,
      creditLimit: (map['creditLimit'] ?? 0).toDouble(),
      isActive: map['isActive'] ?? true,
      version: map['version'] ?? 1,
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(map['updatedAt']) ?? DateTime.now(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'businessId': businessId,
      'ledgerId': ledgerId,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'gstin': gstin,
      'pan': pan,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'ifscCode': ifscCode,
      'upiId': upiId,
      'creditDays': creditDays,
      'creditLimit': creditLimit,
      'isActive': isActive,
      'version': version,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Convert to Map (for local storage)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'businessId': businessId,
      'ledgerId': ledgerId,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'gstin': gstin,
      'pan': pan,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'ifscCode': ifscCode,
      'upiId': upiId,
      'creditDays': creditDays,
      'creditLimit': creditLimit,
      'isActive': isActive,
      'version': version,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Supplier copyWith({
    String? id,
    String? businessId,
    String? ledgerId,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? gstin,
    String? pan,
    String? bankName,
    String? accountNumber,
    String? ifscCode,
    String? upiId,
    int? creditDays,
    double? creditLimit,
    bool? isActive,
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      ledgerId: ledgerId ?? this.ledgerId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      gstin: gstin ?? this.gstin,
      pan: pan ?? this.pan,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      upiId: upiId ?? this.upiId,
      creditDays: creditDays ?? this.creditDays,
      creditLimit: creditLimit ?? this.creditLimit,
      isActive: isActive ?? this.isActive,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
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

  /// Payment due date for a given invoice date
  DateTime dueDateFor(DateTime invoiceDate) {
    return invoiceDate.add(Duration(days: creditDays));
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  @override
  String toString() => 'Supplier(id: $id, name: $name, business: $businessId)';
}
