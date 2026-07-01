/// CustomerModel: SQLite-compatible customer data structure
class CustomerModel {
  final String? id; // Firestore doc ID, null for new records
  final String name;
  final String phone;
  final String address;
  final double totalDues;
  final double cashDues;
  final double onlineDues;
  final double discount;
  final double marketTicket;
  final bool isBlacklisted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool syncStatus; // true = synced to Firestore, false = pending sync
  final String? firestoreDocId; // Reference to Firestore doc for syncing

  CustomerModel({
    this.id,
    required this.name,
    required this.phone,
    required this.address,
    this.totalDues = 0.0,
    this.cashDues = 0.0,
    this.onlineDues = 0.0,
    this.discount = 0.0,
    this.marketTicket = 0.0,
    this.isBlacklisted = false,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = false,
    this.firestoreDocId,
  });

  /// Convert model to SQLite-compatible Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'totalDues': totalDues,
      'cashDues': cashDues,
      'onlineDues': onlineDues,
      'discount': discount,
      'marketTicket': marketTicket,
      'isBlacklisted': isBlacklisted ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'syncStatus': syncStatus ? 1 : 0,
      'firestoreDocId': firestoreDocId,
    };
  }

  /// Create model from SQLite Map
  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      id: map['id'] as String?,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      address: map['address'] as String? ?? '',
      totalDues: (map['totalDues'] as num?)?.toDouble() ?? 0.0,
      cashDues: (map['cashDues'] as num?)?.toDouble() ?? 0.0,
      onlineDues: (map['onlineDues'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      marketTicket: (map['marketTicket'] as num?)?.toDouble() ?? 0.0,
      isBlacklisted: (map['isBlacklisted'] as int?) == 1,
      createdAt: DateTime.parse(
        map['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        map['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
      syncStatus: (map['syncStatus'] as int?) == 1,
      firestoreDocId: map['firestoreDocId'] as String?,
    );
  }

  /// Create a copy with updated fields
  CustomerModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    double? totalDues,
    double? cashDues,
    double? onlineDues,
    double? discount,
    double? marketTicket,
    bool? isBlacklisted,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? syncStatus,
    String? firestoreDocId,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      totalDues: totalDues ?? this.totalDues,
      cashDues: cashDues ?? this.cashDues,
      onlineDues: onlineDues ?? this.onlineDues,
      discount: discount ?? this.discount,
      marketTicket: marketTicket ?? this.marketTicket,
      isBlacklisted: isBlacklisted ?? this.isBlacklisted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      firestoreDocId: firestoreDocId ?? this.firestoreDocId,
    );
  }

  @override
  String toString() {
    return 'CustomerModel(id: $id, name: $name, phone: $phone, totalDues: $totalDues, syncStatus: $syncStatus)';
  }
}
