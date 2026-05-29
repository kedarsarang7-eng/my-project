// PosTable model + PosTableStatus enum for POS app

enum PosTableStatus { free, occupied, reserved, dirty, bill_requested }

extension PosTableStatusX on PosTableStatus {
  String get label {
    switch (this) {
      case PosTableStatus.free:
        return 'FREE';
      case PosTableStatus.occupied:
        return 'OCCUPIED';
      case PosTableStatus.reserved:
        return 'RESERVED';
      case PosTableStatus.dirty:
        return 'DIRTY';
      case PosTableStatus.bill_requested:
        return 'BILL_REQUESTED';
    }
  }

  static PosTableStatus fromString(String s) {
    switch (s.toUpperCase()) {
      case 'OCCUPIED':
        return PosTableStatus.occupied;
      case 'RESERVED':
        return PosTableStatus.reserved;
      case 'DIRTY':
        return PosTableStatus.dirty;
      case 'BILL_REQUESTED':
        return PosTableStatus.bill_requested;
      case 'FREE':
      default:
        return PosTableStatus.free;
    }
  }
}

class PosTable {
  final String id;
  final String number;
  final PosTableStatus status;
  final String? floor;
  final int? capacity;
  final String? currentOrderId;

  const PosTable({
    required this.id,
    required this.number,
    required this.status,
    this.floor,
    this.capacity,
    this.currentOrderId,
  });

  factory PosTable.fromJson(Map<String, dynamic> json) {
    return PosTable(
      id: json['id'] ?? json['tableNumber'] ?? '',
      number: json['tableNumber'] ?? json['id'] ?? '',
      status: PosTableStatusX.fromString(json['status'] ?? ''),
      floor: json['section'] ?? json['floor'],
      capacity: json['capacity'],
      currentOrderId: json['currentOrderId'],
    );
  }
}
