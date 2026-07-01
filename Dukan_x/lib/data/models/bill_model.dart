/// BillModel: SQLite-compatible bill data structure
class BillModel {
  final String? id; // Firestore doc ID, null for new records
  final String customerId; // Reference to customer
  final String invoiceNumber;
  final double subtotal;
  final double paidAmount;
  final String paymentMethod; // 'cash', 'online', 'pending'
  final String status; // 'pending', 'paid', 'cancelled'
  final DateTime date;
  final DateTime dueDate;
  final DateTime updatedAt;
  final String? notes;
  final String? billImageUri; // Local file path to bill image
  final bool syncStatus; // true = synced to Firestore, false = pending sync
  final String? firestoreDocId; // Reference to Firestore doc for syncing

  BillModel({
    this.id,
    required this.customerId,
    required this.invoiceNumber,
    required this.subtotal,
    this.paidAmount = 0.0,
    this.paymentMethod = 'pending',
    this.status = 'pending',
    required this.date,
    required this.dueDate,
    required this.updatedAt,
    this.notes,
    this.billImageUri,
    this.syncStatus = false,
    this.firestoreDocId,
  });

  /// Convert model to SQLite-compatible Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'invoiceNumber': invoiceNumber,
      'subtotal': subtotal,
      'paidAmount': paidAmount,
      'paymentMethod': paymentMethod,
      'status': status,
      'date': date.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'notes': notes,
      'billImageUri': billImageUri,
      'syncStatus': syncStatus ? 1 : 0,
      'firestoreDocId': firestoreDocId,
    };
  }

  /// Create model from SQLite Map
  factory BillModel.fromMap(Map<String, dynamic> map) {
    return BillModel(
      id: map['id'] as String?,
      customerId: map['customerId'] as String? ?? '',
      invoiceNumber: map['invoiceNumber'] as String? ?? '',
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['paymentMethod'] as String? ?? 'pending',
      status: map['status'] as String? ?? 'pending',
      date: DateTime.parse(
        map['date'] as String? ?? DateTime.now().toIso8601String(),
      ),
      dueDate: DateTime.parse(
        map['dueDate'] as String? ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        map['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
      notes: map['notes'] as String?,
      billImageUri: map['billImageUri'] as String?,
      syncStatus: (map['syncStatus'] as int?) == 1,
      firestoreDocId: map['firestoreDocId'] as String?,
    );
  }

  /// Create a copy with updated fields
  BillModel copyWith({
    String? id,
    String? customerId,
    String? invoiceNumber,
    double? subtotal,
    double? paidAmount,
    String? paymentMethod,
    String? status,
    DateTime? date,
    DateTime? dueDate,
    DateTime? updatedAt,
    String? notes,
    String? billImageUri,
    bool? syncStatus,
    String? firestoreDocId,
  }) {
    return BillModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      subtotal: subtotal ?? this.subtotal,
      paidAmount: paidAmount ?? this.paidAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
      billImageUri: billImageUri ?? this.billImageUri,
      syncStatus: syncStatus ?? this.syncStatus,
      firestoreDocId: firestoreDocId ?? this.firestoreDocId,
    );
  }

  double get remainingAmount => subtotal - paidAmount;

  @override
  String toString() {
    return 'BillModel(id: $id, customerId: $customerId, invoiceNumber: $invoiceNumber, subtotal: $subtotal, status: $status, syncStatus: $syncStatus)';
  }
}
