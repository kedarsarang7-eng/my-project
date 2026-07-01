import 'package:equatable/equatable.dart';

enum AlertType { expiry, lowStock, abnormalBill }

class Alert extends Equatable {
  final String id;
  final AlertType type;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  const Alert({
    required this.id,
    required this.type,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });

  @override
  List<Object?> get props => [id, type, message, createdAt, isRead];
}
