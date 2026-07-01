import 'package:dukanx/core/compat/firestore_compat.dart';

enum StockMovementType {
  sale,
  purchase,
  returnIn, // Sales Return (Stock comes back)
  returnOut, // Purchase Return (Stock goes out)
  adjustment, // Manual correction
}

class StockMovementModel {
  final String movementId;
  final String businessId;
  final String itemId;
  final double qtyChange;
  final double stockAfter;
  final StockMovementType type;
  final String reason;
  final String referenceId; // Bill ID / Purchase ID
  final DateTime date;

  StockMovementModel({
    required this.movementId,
    required this.businessId,
    required this.itemId,
    required this.qtyChange,
    required this.stockAfter,
    required this.type,
    required this.reason,
    required this.referenceId,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'movementId': movementId,
      'businessId': businessId,
      'itemId': itemId,
      'qtyChange': qtyChange,
      'stockAfter': stockAfter,
      'type': type.name,
      'reason': reason,
      'referenceId': referenceId,
      'date': Timestamp.fromDate(date),
    };
  }

  factory StockMovementModel.fromMap(Map<String, dynamic> map) {
    return StockMovementModel(
      movementId: map['movementId'] ?? '',
      businessId: map['businessId'] ?? '',
      itemId: map['itemId'] ?? '',
      qtyChange: (map['qtyChange'] ?? 0).toDouble(),
      stockAfter: (map['stockAfter'] ?? 0).toDouble(),
      type: StockMovementType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => StockMovementType.adjustment,
      ),
      reason: map['reason'] ?? '',
      referenceId: map['referenceId'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
    );
  }
}
