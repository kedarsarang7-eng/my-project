/// BillItemModel: SQLite-compatible bill item (vegetable line item) structure
class BillItemModel {
  final String? id; // Firestore doc ID, null for new records
  final String billId; // Reference to bill
  final String vegId; // Reference to vegetable/product
  final String vegName;
  final double qtyKg;
  final double pricePerKg;
  final double total;
  final DateTime createdAt;
  final bool syncStatus; // true = synced to Firestore, false = pending sync
  final String? firestoreDocId; // Reference to Firestore doc for syncing

  BillItemModel({
    this.id,
    required this.billId,
    required this.vegId,
    required this.vegName,
    required this.qtyKg,
    required this.pricePerKg,
    required this.total,
    required this.createdAt,
    this.syncStatus = false,
    this.firestoreDocId,
  });

  /// Convert model to SQLite-compatible Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'billId': billId,
      'vegId': vegId,
      'vegName': vegName,
      'qtyKg': qtyKg,
      'pricePerKg': pricePerKg,
      'total': total,
      'createdAt': createdAt.toIso8601String(),
      'syncStatus': syncStatus ? 1 : 0,
      'firestoreDocId': firestoreDocId,
    };
  }

  /// Create model from SQLite Map
  factory BillItemModel.fromMap(Map<String, dynamic> map) {
    return BillItemModel(
      id: map['id'] as String?,
      billId: map['billId'] as String? ?? '',
      vegId: map['vegId'] as String? ?? '',
      vegName: map['vegName'] as String? ?? '',
      qtyKg: (map['qtyKg'] as num?)?.toDouble() ?? 0.0,
      pricePerKg: (map['pricePerKg'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(
        map['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
      syncStatus: (map['syncStatus'] as int?) == 1,
      firestoreDocId: map['firestoreDocId'] as String?,
    );
  }

  /// Create a copy with updated fields
  BillItemModel copyWith({
    String? id,
    String? billId,
    String? vegId,
    String? vegName,
    double? qtyKg,
    double? pricePerKg,
    double? total,
    DateTime? createdAt,
    bool? syncStatus,
    String? firestoreDocId,
  }) {
    return BillItemModel(
      id: id ?? this.id,
      billId: billId ?? this.billId,
      vegId: vegId ?? this.vegId,
      vegName: vegName ?? this.vegName,
      qtyKg: qtyKg ?? this.qtyKg,
      pricePerKg: pricePerKg ?? this.pricePerKg,
      total: total ?? this.total,
      createdAt: createdAt ?? this.createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
      firestoreDocId: firestoreDocId ?? this.firestoreDocId,
    );
  }

  @override
  String toString() {
    return 'BillItemModel(id: $id, billId: $billId, vegName: $vegName, qtyKg: $qtyKg, total: $total, syncStatus: $syncStatus)';
  }
}
