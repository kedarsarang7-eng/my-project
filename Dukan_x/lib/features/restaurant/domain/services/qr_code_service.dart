// ============================================================================
// QR CODE SERVICE
// ============================================================================

import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

/// QR Code type
enum QrCodeType {
  restaurant('RESTAURANT'),
  table('TABLE');

  final String value;
  const QrCodeType(this.value);

  static QrCodeType fromString(String value) {
    return QrCodeType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => QrCodeType.restaurant,
    );
  }
}

/// QR Code data model
class QrCodeData {
  final String type;
  final String vendorId;
  final String? tableId;
  final String? tableNumber;
  final int version;

  const QrCodeData({
    required this.type,
    required this.vendorId,
    this.tableId,
    this.tableNumber,
    this.version = 1,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'vendorId': vendorId,
    'tableId': tableId,
    'tableNumber': tableNumber,
    'version': version,
  };

  String toEncodedString() => jsonEncode(toJson());

  factory QrCodeData.fromJson(Map<String, dynamic> json) {
    return QrCodeData(
      type: json['type'] ?? 'DUKANX_RESTAURANT',
      vendorId: json['vendorId'] ?? '',
      tableId: json['tableId'],
      tableNumber: json['tableNumber'],
      version: json['version'] ?? 1,
    );
  }

  factory QrCodeData.fromEncodedString(String encoded) {
    try {
      final json = jsonDecode(encoded);
      return QrCodeData.fromJson(json);
    } catch (_) {
      throw Exception('Invalid QR code format');
    }
  }

  bool get isValid => vendorId.isNotEmpty;
  bool get isTableQr => tableId != null || tableNumber != null;
}

/// Service for managing restaurant QR codes
class QrCodeService {
  final AppDatabase _db;
  static const _uuid = Uuid();
  static const qrType = 'DUKANX_RESTAURANT';

  QrCodeService({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  /// Generate QR code for restaurant (general)
  Future<String> generateRestaurantQrCode(String vendorId) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    final qrData = QrCodeData(type: qrType, vendorId: vendorId);

    await _db
        .into(_db.restaurantQrCodes)
        .insert(
          RestaurantQrCodesCompanion.insert(
            id: id,
            vendorId: vendorId,
            qrType: QrCodeType.restaurant.value,
            qrData: qrData.toEncodedString(),
            createdAt: now,
            updatedAt: now,
          ),
        );

    return qrData.toEncodedString();
  }

  /// Generate QR data string only (no DB save)
  String generateTableQrData(
    String vendorId,
    String tableId,
    String tableNumber,
  ) {
    return QrCodeData(
      type: qrType,
      vendorId: vendorId,
      tableId: tableId,
      tableNumber: tableNumber,
    ).toEncodedString();
  }

  /// Generate QR code for specific table
  Future<String> generateTableQrCode(
    String vendorId,
    String tableId,
    String tableNumber,
  ) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    final qrData = QrCodeData(
      type: qrType,
      vendorId: vendorId,
      tableId: tableId,
      tableNumber: tableNumber,
    );

    await _db
        .into(_db.restaurantQrCodes)
        .insert(
          RestaurantQrCodesCompanion.insert(
            id: id,
            vendorId: vendorId,
            tableId: Value(tableId),
            qrType: QrCodeType.table.value,
            qrData: qrData.toEncodedString(),
            createdAt: now,
            updatedAt: now,
          ),
        );

    return qrData.toEncodedString();
  }

  /// Parse scanned QR code
  QrCodeData? parseQrCode(String scannedData) {
    try {
      final qrData = QrCodeData.fromEncodedString(scannedData);

      // Validate it's a DukanX restaurant QR
      if (qrData.type != qrType) {
        return null;
      }

      if (!qrData.isValid) {
        return null;
      }

      return qrData;
    } catch (_) {
      return null;
    }
  }

  /// Get QR code by table ID
  Future<String?> getTableQrCode(String tableId) async {
    final entity =
        await (_db.select(_db.restaurantQrCodes)..where(
              (t) => t.tableId.equals(tableId) & t.isActive.equals(true),
            ))
            .getSingleOrNull();

    return entity?.qrData;
  }

  /// Get restaurant QR code
  Future<String?> getRestaurantQrCode(String vendorId) async {
    final entity =
        await (_db.select(_db.restaurantQrCodes)..where(
              (t) =>
                  t.vendorId.equals(vendorId) &
                  t.qrType.equals(QrCodeType.restaurant.value) &
                  t.isActive.equals(true),
            ))
            .getSingleOrNull();

    return entity?.qrData;
  }

  /// Deactivate QR code
  Future<void> deactivateQrCode(String qrCodeId) async {
    await (_db.update(
      _db.restaurantQrCodes,
    )..where((t) => t.id.equals(qrCodeId))).write(
      RestaurantQrCodesCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Get all QR codes for vendor
  Future<List<RestaurantQrCodeEntity>> getVendorQrCodes(String vendorId) async {
    return await (_db.select(_db.restaurantQrCodes)
          ..where((t) => t.vendorId.equals(vendorId) & t.isActive.equals(true)))
        .get();
  }
}
