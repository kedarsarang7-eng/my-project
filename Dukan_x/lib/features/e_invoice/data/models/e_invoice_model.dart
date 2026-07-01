/// e-Invoice Status
enum EInvoiceStatus { pending, generated, cancelled, failed }

/// e-Invoice Model
/// Represents a GST e-invoice with IRN from the GST portal
class EInvoiceModel {
  final String id;
  final String userId;
  final String billId;
  final String? irn; // Invoice Reference Number
  final String? ackNumber; // Acknowledgement number
  final DateTime? ackDate;
  final EInvoiceStatus status;
  final String? qrCode;
  final String? signedInvoice;
  final String? signedQrCode;
  final String? cancelReason;
  final DateTime? cancelledAt;
  final String? lastError;
  final int retryCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;
  final String? syncOperationId;

  const EInvoiceModel({
    required this.id,
    required this.userId,
    required this.billId,
    this.irn,
    this.ackNumber,
    this.ackDate,
    this.status = EInvoiceStatus.pending,
    this.qrCode,
    this.signedInvoice,
    this.signedQrCode,
    this.cancelReason,
    this.cancelledAt,
    this.lastError,
    this.retryCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.syncOperationId,
  });

  EInvoiceModel copyWith({
    String? id,
    String? userId,
    String? billId,
    String? irn,
    String? ackNumber,
    DateTime? ackDate,
    EInvoiceStatus? status,
    String? qrCode,
    String? signedInvoice,
    String? signedQrCode,
    String? cancelReason,
    DateTime? cancelledAt,
    String? lastError,
    int? retryCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    String? syncOperationId,
  }) {
    return EInvoiceModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      billId: billId ?? this.billId,
      irn: irn ?? this.irn,
      ackNumber: ackNumber ?? this.ackNumber,
      ackDate: ackDate ?? this.ackDate,
      status: status ?? this.status,
      qrCode: qrCode ?? this.qrCode,
      signedInvoice: signedInvoice ?? this.signedInvoice,
      signedQrCode: signedQrCode ?? this.signedQrCode,
      cancelReason: cancelReason ?? this.cancelReason,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      lastError: lastError ?? this.lastError,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      syncOperationId: syncOperationId ?? this.syncOperationId,
    );
  }
}

/// Extension for entity mapping
extension EInvoiceModelX on EInvoiceModel {
  /// Create from database entity
  static EInvoiceModel fromEntity(dynamic entity) {
    return EInvoiceModel(
      id: entity.id as String,
      userId: entity.userId as String,
      billId: entity.billId as String,
      irn: entity.irn as String?,
      ackNumber: entity.ackNumber as String?,
      ackDate: entity.ackDate as DateTime?,
      status: _parseStatus(entity.status as String),
      qrCode: entity.qrCode as String?,
      signedInvoice: entity.signedInvoice as String?,
      signedQrCode: entity.signedQrCode as String?,
      cancelReason: entity.cancelReason as String?,
      cancelledAt: entity.cancelledAt as DateTime?,
      lastError: entity.lastError as String?,
      retryCount: entity.retryCount as int,
      createdAt: entity.createdAt as DateTime,
      updatedAt: entity.updatedAt as DateTime,
      isSynced: entity.isSynced as bool,
      syncOperationId: entity.syncOperationId as String?,
    );
  }

  static EInvoiceStatus _parseStatus(String status) {
    switch (status.toUpperCase()) {
      case 'GENERATED':
        return EInvoiceStatus.generated;
      case 'CANCELLED':
        return EInvoiceStatus.cancelled;
      case 'FAILED':
        return EInvoiceStatus.failed;
      default:
        return EInvoiceStatus.pending;
    }
  }
}
