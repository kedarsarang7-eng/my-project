/// Customer model for Customer Management module
class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? gstin;
  final String? businessName;
  final double? totalDues;
  final bool isBlocked;
  final DateTime? createdAt;

  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.gstin,
    this.businessName,
    this.totalDues,
    this.isBlocked = false,
    this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'],
      email: json['email'],
      gstin: json['gstin'],
      businessName: json['businessName'],
      totalDues: (json['totalDues'] as num?)?.toDouble(),
      isBlocked: json['isBlocked'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? gstin,
    String? businessName,
    double? totalDues,
    bool? isBlocked,
    DateTime? createdAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      gstin: gstin ?? this.gstin,
      businessName: businessName ?? this.businessName,
      totalDues: totalDues ?? this.totalDues,
      isBlocked: isBlocked ?? this.isBlocked,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'gstin': gstin,
    'businessName': businessName,
    'totalDues': totalDues,
    'isBlocked': isBlocked,
    'createdAt': createdAt?.toIso8601String(),
  };
}
