import 'package:equatable/equatable.dart';

enum NotificationCategory { invoice, payment, due, system, promotion }

class CustomerNotification extends Equatable {
  final String id;
  final String customerId;
  final String? vendorId;
  final String? vendorName;
  final NotificationCategory category;
  final String title;
  final String body;
  final Map<String, dynamic>? payload;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;

  const CustomerNotification({
    required this.id,
    required this.customerId,
    this.vendorId,
    this.vendorName,
    required this.category,
    required this.title,
    required this.body,
    this.payload,
    required this.isRead,
    required this.createdAt,
    this.readAt,
  });

  factory CustomerNotification.fromJson(Map<String, dynamic> json) {
    return CustomerNotification(
      id: json['id'] as String,
      customerId: json['customerId'] as String,
      vendorId: json['vendorId'] as String?,
      vendorName: json['vendorName'] as String?,
      category: _categoryFromString(json['category'] as String? ?? 'system'),
      title: json['title'] as String,
      body: json['body'] as String,
      payload: json['payload'] as Map<String, dynamic>?,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      readAt: json['readAt'] != null ? DateTime.parse(json['readAt'] as String) : null,
    );
  }

  static NotificationCategory _categoryFromString(String s) {
    switch (s.toLowerCase()) {
      case 'invoice':
        return NotificationCategory.invoice;
      case 'payment':
        return NotificationCategory.payment;
      case 'due':
        return NotificationCategory.due;
      case 'promotion':
        return NotificationCategory.promotion;
      default:
        return NotificationCategory.system;
    }
  }

  CustomerNotification copyWith({bool? isRead, DateTime? readAt}) {
    return CustomerNotification(
      id: id,
      customerId: customerId,
      vendorId: vendorId,
      vendorName: vendorName,
      category: category,
      title: title,
      body: body,
      payload: payload,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  @override
  List<Object?> get props => [id, customerId, category, isRead, createdAt];
}
