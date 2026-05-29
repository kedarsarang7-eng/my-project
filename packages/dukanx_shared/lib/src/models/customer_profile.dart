import 'package:equatable/equatable.dart';

class CustomerProfile extends Equatable {
  final String id;
  final String customerId;
  final String phone;
  final String? email;
  final String displayName;
  final String? photoUrl;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final double totalDue;
  final double totalPaid;
  final int linkedShopsCount;
  final DateTime? lastActiveAt;
  final DateTime createdAt;

  const CustomerProfile({
    required this.id,
    required this.customerId,
    required this.phone,
    this.email,
    required this.displayName,
    this.photoUrl,
    this.address,
    this.city,
    this.state,
    this.pincode,
    required this.totalDue,
    required this.totalPaid,
    required this.linkedShopsCount,
    this.lastActiveAt,
    required this.createdAt,
  });

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    return CustomerProfile(
      id: json['id'] as String,
      customerId: json['customerId'] as String? ?? json['id'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      displayName: json['displayName'] as String? ?? json['name'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      pincode: json['pincode'] as String?,
      totalDue: (json['totalDue'] as num? ?? 0).toDouble(),
      totalPaid: (json['totalPaid'] as num? ?? 0).toDouble(),
      linkedShopsCount: (json['linkedShopsCount'] as int? ?? 0),
      lastActiveAt: json['lastActiveAt'] != null
          ? DateTime.parse(json['lastActiveAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'customerId': customerId,
        'phone': phone,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'address': address,
        'city': city,
        'state': state,
        'pincode': pincode,
        'totalDue': totalDue,
        'totalPaid': totalPaid,
        'linkedShopsCount': linkedShopsCount,
        'lastActiveAt': lastActiveAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  CustomerProfile copyWith({
    String? displayName,
    String? email,
    String? photoUrl,
    String? address,
    String? city,
    String? state,
    String? pincode,
    double? totalDue,
    double? totalPaid,
    int? linkedShopsCount,
  }) {
    return CustomerProfile(
      id: id,
      customerId: customerId,
      phone: phone,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      totalDue: totalDue ?? this.totalDue,
      totalPaid: totalPaid ?? this.totalPaid,
      linkedShopsCount: linkedShopsCount ?? this.linkedShopsCount,
      lastActiveAt: lastActiveAt,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, customerId, phone, displayName, totalDue, totalPaid];
}
