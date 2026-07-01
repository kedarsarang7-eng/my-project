import '../../../core/api/api_client.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/di/service_locator.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectionService {
  /// Check if the device is currently online
  Future<bool> isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return !result.contains(ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }
  ApiClient get _api => sl<ApiClient>();

  // --- VENDOR METHODS ---

  /// Generate QR Data String
  /// Format: "v1:`vendorId`:`customerId`:`checksum`"
  String generateQrData(String customerId) {
    final userId = sl<SessionManager>().userId;
    if (userId == null) throw Exception('Not authenticated');
    final vendorId = userId;

    final raw = '$vendorId:$customerId';
    final bytes = utf8.encode(raw);
    final digest = sha256.convert(bytes).toString().substring(0, 8);

    return 'v1:$vendorId:$customerId:$digest';
  }

  /// Generate Generic Shop QR Data
  String generateShopQr(String vendorId) {
    return 'v1:$vendorId';
  }

  /// Manually link to a shop by ID (Request Mode)
  Future<void> linkShop(String vendorId) async {
    final userId = sl<SessionManager>().userId;
    if (userId == null) throw Exception('Auth required');

    await _api.post('/api/v1/connections', body: {
      'vendorId': vendorId,
      'customerId': userId,
      'customerUserId': userId,
      'customerName': 'Unknown',
      'customerPhone': '',
      'status': 'pending',
      'source': 'manual_entry',
    });
  }

  /// Get incoming connection requests for vendor
  Stream<List<ConnectionRequest>> streamRequests() {
    final userId = sl<SessionManager>().userId;
    if (userId == null) return const Stream.empty();

    return Stream.fromFuture(_fetchRequests());
  }

  Future<List<ConnectionRequest>> _fetchRequests() async {
    final res = await _api.get('/api/v1/connections',
        queryParams: {'status': 'pending'});
    if (res.isSuccess && res.data != null) {
      final items = res.data!['items'];
      if (items is List) {
        return items
            .map((e) => ConnectionRequest.fromMap(
                (e as Map)['id']?.toString() ?? '', Map<String, dynamic>.from(e)))
            .toList();
      }
    }
    return [];
  }

  /// Accept a customer's connection request
  Future<void> acceptRequest(ConnectionRequest req) async {
    await _api.put('/api/v1/connections/${req.id}', body: {
      'status': 'accepted',
      'linkedUserId': req.customerUserId,
    });
  }

  /// Reject a request
  Future<void> rejectRequest(String requestId) async {
    await _api.put('/api/v1/connections/$requestId', body: {
      'status': 'rejected',
    });
  }

  // --- CUSTOMER METHODS ---

  /// Decode QR and Send Connection Request
  Future<void> sendRequestFromQr(String qrData) async {
    final userId = sl<SessionManager>().userId;
    if (userId == null) throw Exception('Auth required');

    final parts = qrData.split(':');
    if (parts.length < 2 || parts[0] != 'v1') {
      throw Exception('Mboshi: Invalid QR Code format');
    }

    final vendorId = parts[1];

    if (parts.length == 4) {
      final customeridQr = parts[2];
      final checksum = parts[3];
      final raw = '$vendorId:$customeridQr';
      final bytes = utf8.encode(raw);
      final digest = sha256.convert(bytes).toString().substring(0, 8);
      if (digest != checksum) throw Exception('Invalid QR Checksum');
    } else if (parts.length != 2) {
      throw Exception('Invalid QR format length');
    }

    await _api.post('/api/v1/connections', body: {
      'vendorId': vendorId,
      'customerId': userId,
      'customerUserId': userId,
      'customerName': 'Unknown',
      'customerPhone': '',
      'status': 'pending',
      'source': 'qr_scan',
    });
  }

  /// Check pending connections and finalize accepted ones
  Future<void> checkMyConnections() async {
    final userId = sl<SessionManager>().userId;
    if (userId == null) return;

    try {
      final res = await _api.get('/api/v1/connections',
          queryParams: {'status': 'pending', 'role': 'customer'});
      if (!res.isSuccess || res.data == null) return;

      final items = res.data!['items'];
      if (items is! List) return;

      for (final item in items) {
        final status = item['status'];
        if (status == 'accepted' || status == 'rejected') {
          // Server handles finalization
        }
      }
    } catch (_) {}
  }

  /// Stream my active connections
  Stream<List<ConnectedShop>> streamMyConnections() {
    final userId = sl<SessionManager>().userId;
    if (userId == null) return const Stream.empty();

    return Stream.fromFuture(_fetchMyConnections());
  }

  Future<List<ConnectedShop>> _fetchMyConnections() async {
    final res = await _api.get('/api/v1/connections',
        queryParams: {'status': 'accepted'});
    if (res.isSuccess && res.data != null) {
      final items = res.data!['items'];
      if (items is List) {
        return items
            .map((e) => ConnectedShop.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    }
    return [];
  }

  /// Get vendor/shop details
  Future<Map<String, dynamic>?> getShopDetails(String vendorId) async {
    try {
      final res = await _api.get('/api/v1/vendor-profiles/$vendorId');
      if (res.isSuccess && res.data != null) {
        return res.data!['vendorProfile'] ?? res.data!;
      }
    } catch (_) {}
    return null;
  }

  /// Stream live shop details
  Stream<Map<String, dynamic>> streamShopDetails(String vendorId) {
    return Stream.fromFuture(
      getShopDetails(vendorId).then((v) => v ?? {}),
    );
  }

  /// Get list of accepted connections
  Future<List<Map<String, dynamic>>> getAcceptedConnections() async {
    final connections = await _fetchMyConnections();
    return connections.map((c) => {
      'id': c.vendorId,
      'vendorId': c.vendorId,
      'customerId': c.customerId,
      'shopName': c.shopName,
    }).toList();
  }

  /// Search for shops by ID or Name
  Future<List<Map<String, dynamic>>> searchShops(String query) async {
    if (query.isEmpty) return [];

    try {
      final res = await _api.get('/api/v1/vendor-profiles',
          queryParams: {'search': query});
      if (res.isSuccess && res.data != null) {
        final items = res.data!['items'];
        if (items is List) {
          return items
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Unlink a shop
  Future<void> unlinkShop(String vendorId) async {
    final userId = sl<SessionManager>().userId;
    if (userId == null) throw Exception('Auth required');

    await _api.delete('/api/v1/connections/$vendorId');
  }

  /// Verify a 6-digit link request code (Legacy/Remote Flow)
  Future<bool> verifyLinkRequest(String phone, String code) async {
    try {
      final res = await _api.post('/api/v1/connections/verify', body: {
        'phone': phone,
        'code': code,
      });
      return res.isSuccess;
    } catch (e) {
      return false;
    }
  }
}

class ConnectionRequest {
  final String id;
  final String customerId;
  final String customerUserId;
  final String customerName;
  final String customerPhone;
  final String status;
  final DateTime? createdAt;

  ConnectionRequest({
    required this.id,
    required this.customerId,
    required this.customerUserId,
    required this.customerName,
    required this.customerPhone,
    required this.status,
    this.createdAt,
  });

  factory ConnectionRequest.fromMap(String id, Map<String, dynamic> map) {
    DateTime? created;
    if (map['createdAt'] is String) {
      created = DateTime.tryParse(map['createdAt']);
    } else if (map['created_at'] is String) {
      created = DateTime.tryParse(map['created_at']);
    }

    return ConnectionRequest(
      id: id,
      customerId: map['customerId'] ?? map['customer_id'] ?? '',
      customerUserId: map['customerUserId'] ?? map['customer_user_id'] ?? '',
      customerName: map['customerName'] ?? map['customer_name'] ?? '',
      customerPhone: map['customerPhone'] ?? map['customer_phone'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: created,
    );
  }
}

class ConnectedShop {
  final String vendorId;
  final String customerId;
  final String shopName;

  ConnectedShop({
    required this.vendorId,
    required this.customerId,
    required this.shopName,
  });

  factory ConnectedShop.fromMap(Map<String, dynamic> map) {
    return ConnectedShop(
      vendorId: map['vendorId'] ?? map['vendor_id'] ?? '',
      customerId: map['customerId'] ?? map['customer_id'] ?? '',
      shopName: map['shopName'] ?? map['shop_name'] ?? 'Unknown Shop',
    );
  }
}
