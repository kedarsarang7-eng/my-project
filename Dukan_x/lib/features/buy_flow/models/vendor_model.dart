// Vendor Model (Mirror of Firestore/SQL)
// Removed cloud_firestore import

class Vendor {
  final String vendorId;
  final String ownerId;
  final String name;
  final String phone;
  final String email;
  final String gstNumber;
  final double openingBalance;
  final double currentBalance;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  Vendor({
    required this.vendorId,
    required this.ownerId,
    required this.name,
    this.phone = '',
    this.email = '',
    this.gstNumber = '',
    this.openingBalance = 0.0,
    this.currentBalance = 0.0,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'vendorId': vendorId,
      'ownerId': ownerId,
      'name': name,
      'phone': phone,
      'email': email,
      'gstNumber': gstNumber,
      'openingBalance': openingBalance,
      'currentBalance': currentBalance,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isDeleted': isDeleted,
    };
  }

  factory Vendor.fromMap(Map<String, dynamic> map) {
    return Vendor(
      vendorId: map['vendorId'] ?? '',
      ownerId: map['ownerId'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      gstNumber: map['gstNumber'] ?? '',
      openingBalance: (map['openingBalance'] ?? 0).toDouble(),
      currentBalance: (map['currentBalance'] ?? 0).toDouble(),
      createdAt: map['createdAt'] is String
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] is String
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
      isDeleted: map['isDeleted'] ?? false,
    );
  }
}
