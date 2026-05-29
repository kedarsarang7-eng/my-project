import 'package:equatable/equatable.dart';

class CustomerDue extends Equatable {
  final String vendorId;
  final String vendorName;
  final String? vendorBusinessName;
  final double totalDue;
  final double totalPaid;
  final double netBalance;
  final int overdueInvoiceCount;
  final DateTime? oldestDueDate;

  const CustomerDue({
    required this.vendorId,
    required this.vendorName,
    this.vendorBusinessName,
    required this.totalDue,
    required this.totalPaid,
    required this.netBalance,
    required this.overdueInvoiceCount,
    this.oldestDueDate,
  });

  bool get hasOverdue => overdueInvoiceCount > 0;

  factory CustomerDue.fromJson(Map<String, dynamic> json) {
    return CustomerDue(
      vendorId: json['vendorId'] as String,
      vendorName: json['vendorName'] as String,
      vendorBusinessName: json['vendorBusinessName'] as String?,
      totalDue: (json['totalDue'] as num? ?? 0).toDouble(),
      totalPaid: (json['totalPaid'] as num? ?? 0).toDouble(),
      netBalance: (json['netBalance'] as num? ?? 0).toDouble(),
      overdueInvoiceCount: (json['overdueInvoiceCount'] as int? ?? 0),
      oldestDueDate: json['oldestDueDate'] != null
          ? DateTime.parse(json['oldestDueDate'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [vendorId, netBalance, overdueInvoiceCount];
}
