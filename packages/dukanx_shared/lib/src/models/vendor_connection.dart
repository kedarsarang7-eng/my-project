import 'package:equatable/equatable.dart';

enum ConnectionStatus { active, pending, rejected, suspended }

class VendorConnection extends Equatable {
  final String id;
  final String customerId;
  final String vendorId;
  final String vendorName;
  final String? vendorBusinessName;
  final String? vendorPhone;
  final String? businessType;
  final String? logoUrl;
  final ConnectionStatus status;
  final double outstandingBalance;
  final DateTime connectedAt;
  final DateTime? lastTransactionAt;

  const VendorConnection({
    required this.id,
    required this.customerId,
    required this.vendorId,
    required this.vendorName,
    this.vendorBusinessName,
    this.vendorPhone,
    this.businessType,
    this.logoUrl,
    required this.status,
    required this.outstandingBalance,
    required this.connectedAt,
    this.lastTransactionAt,
  });

  factory VendorConnection.fromJson(Map<String, dynamic> json) {
    return VendorConnection(
      id: json['id'] as String,
      customerId: json['customerId'] as String,
      vendorId: json['vendorId'] as String,
      vendorName: json['vendorName'] as String,
      vendorBusinessName: json['vendorBusinessName'] as String?,
      vendorPhone: json['vendorPhone'] as String?,
      businessType: json['businessType'] as String?,
      logoUrl: json['logoUrl'] as String?,
      status: _statusFromString(json['status'] as String? ?? 'active'),
      outstandingBalance: (json['outstandingBalance'] as num? ?? 0).toDouble(),
      connectedAt: DateTime.parse(json['connectedAt'] as String),
      lastTransactionAt: json['lastTransactionAt'] != null
          ? DateTime.parse(json['lastTransactionAt'] as String)
          : null,
    );
  }

  static ConnectionStatus _statusFromString(String s) {
    switch (s.toLowerCase()) {
      case 'pending':
        return ConnectionStatus.pending;
      case 'rejected':
        return ConnectionStatus.rejected;
      case 'suspended':
        return ConnectionStatus.suspended;
      default:
        return ConnectionStatus.active;
    }
  }

  @override
  List<Object?> get props => [id, customerId, vendorId, status, outstandingBalance];
}
