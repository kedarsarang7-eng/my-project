import 'package:dukanx/core/compat/firestore_compat.dart';

class UserModel {
  final String uid;
  final String name;
  final String phone;
  final String email;
  final String role; // 'owner' or 'customer'
  final String? shopId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.phone,
    required this.email,
    required this.role,
    this.shopId,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      uid: id,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: map['role'] as String? ?? 'customer',
      shopId: map['shopId'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'role': role,
      'shopId': shopId,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}
