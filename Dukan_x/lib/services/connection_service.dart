import 'package:dukanx/core/compat/firestore_compat.dart';
import 'package:dukanx/core/compat/firebase_auth_compat.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class ConnectionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- VENDOR METHODS ---

  /// Generate QR Data String
  /// Format: "v1:`vendorId`:`customerId`:`checksum`"
  String generateQrData(String customerId) {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    final vendorId = user.uid;

    // Simple checksum to prevent typos/garbage
    final raw = '$vendorId:$customerId';
    final bytes = utf8.encode(raw);
    final digest = sha256.convert(bytes).toString().substring(0, 8);

    return 'v1:$vendorId:$customerId:$digest';
  }

  /// Generate Generic Shop QR Data
  /// Format: "v1:`vendorId`"
  String generateShopQr(String vendorId) {
    return 'v1:$vendorId';
  }

  /// Manually link to a shop by ID (Request Mode)
  Future<void> linkShop(String vendorId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Auth required');

    // For manual entry, we assume customerId is the user's ID
    final customerId = user.uid;
    final requestId = '${vendorId}_${customerId}_${user.uid}';

    final reqRef = _db
        .collection('users')
        .doc(vendorId)
        .collection('requests')
        .doc(requestId);

    await reqRef.set({
      'vendorId': vendorId,
      'customerId': customerId,
      'customerUserId': user.uid,
      'customerName': user.displayName ?? 'Unknown',
      'customerPhone': user.phoneNumber ?? '',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'source': 'manual_entry',
    });

    await _addToMyWatchlist(vendorId, customerId, requestId);
  }

  /// Stream incoming connection requests for a vendor
  Stream<List<ConnectionRequest>> streamRequests() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ConnectionRequest.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  /// Accept a customer's connection request
  Future<void> acceptRequest(ConnectionRequest req) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    final vendorId = user.uid;

    final batch = _db.batch();

    // 1. Update Customer Profile -> Link User ID
    final customerRef = _db
        .collection('users')
        .doc(vendorId)
        .collection('customers')
        .doc(req.customerId);

    batch.update(customerRef, {
      'linkedUserId': req.customerUserId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Update Request Status -> Accepted
    final reqRef = _db
        .collection('users')
        .doc(vendorId)
        .collection('requests')
        .doc(req.id);

    batch.update(reqRef, {
      'status': 'accepted',
      'respondedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Reject a request
  Future<void> rejectRequest(String requestId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('requests')
        .doc(requestId)
        .update({
          'status': 'rejected',
          'respondedAt': FieldValue.serverTimestamp(),
        });
  }

  // --- CUSTOMER METHODS ---

  /// Decode QR and Send Connection Request
  Future<void> sendRequestFromQr(String qrData) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Auth required');

    // Parse QR
    // Parse QR
    final parts = qrData.split(':');
    if (parts.length < 2 || parts[0] != 'v1') {
      throw Exception('Mboshi: Invalid QR Code format');
    }

    final vendorId = parts[1];

    // Handle specific vs generic
    if (parts.length == 4) {
      // Specific invite
      final customeridQr = parts[2];
      final checksum = parts[3];

      // Verify checksum
      final raw = '$vendorId:$customeridQr';
      final bytes = utf8.encode(raw);
      final digest = sha256.convert(bytes).toString().substring(0, 8);
      if (digest != checksum) throw Exception('Invalid QR Checksum');

      // If customerId_qr matches current user, or generic?
      // Ideally we just use vendorId to link to current user.
    } else if (parts.length == 2) {
      // Generic shop QR v1:vendorId
      // No checksum verification (public ID)
    } else {
      throw Exception('Invalid QR format length');
    }

    final customerId = user.uid;

    // Create Request (Common logic)
    // We use a deterministic ID (vendorId_customerId_userId) to prevent spam duplicates
    final requestId =
        '${vendorId}_${user.uid}_${user.uid}'; // customerId=user.uid for manual scan

    final reqRef = _db
        .collection('users')
        .doc(vendorId)
        .collection('requests')
        .doc(requestId);

    await reqRef.set({
      'vendorId': vendorId,
      'customerId': customerId,
      'customerUserId': user.uid,
      'customerName': user.displayName ?? 'Unknown',
      'customerPhone': user.phoneNumber ?? '',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Add to my watchlist (to track acceptance)
    await _addToMyWatchlist(vendorId, customerId, requestId);
  }

  /// Add a temporary watch record to my own profile to track this request
  Future<void> _addToMyWatchlist(
    String vendorId,
    String customerId,
    String requestId,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('pending_connections')
        .doc(requestId)
        .set({
          'vendorId': vendorId,
          'customerId': customerId,
          'requestId': requestId,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  /// Check Status of my pending connections and move to 'connected' if accepted
  Future<void> checkMyConnections() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final pendingSnap = await _db
        .collection('users')
        .doc(user.uid)
        .collection('pending_connections')
        .get();

    for (var doc in pendingSnap.docs) {
      final data = doc.data();
      final vendorId = data['vendorId'];
      final requestId = data['requestId'];
      final customerId = data['customerId'];

      // Check Real Status on Vendor Side
      final reqDoc = await _db
          .collection('users')
          .doc(vendorId)
          .collection('requests')
          .doc(requestId)
          .get();

      if (!reqDoc.exists) {
        // Request deleted? Remove watch
        await doc.reference.delete();
        continue;
      }

      final status = reqDoc.data()?['status'];
      if (status == 'accepted') {
        // SUCCESS! Save to permanent connections
        await _db
            .collection('users')
            .doc(user.uid)
            .collection('connections')
            .doc(vendorId)
            .set({
              'vendorId': vendorId,
              'customerId': customerId,
              'linkedAt': FieldValue.serverTimestamp(),
              'shopName': 'Shop #$vendorId', // Ideally fetch shop name
            });

        // Remove pending watch
        await doc.reference.delete();
      } else if (status == 'rejected') {
        await doc.reference.delete();
      }
    }
  }

  /// Stream my active connections
  Stream<List<ConnectedShop>> streamMyConnections() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('connections')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => ConnectedShop.fromMap(d.data())).toList(),
        );
  }

  /// Stream live shop details (Name, Logo) from the official Owners collection
  Stream<Map<String, dynamic>> streamShopDetails(String vendorId) {
    return _db
        .collection('owners')
        .doc(vendorId)
        .snapshots()
        .map((doc) => doc.data() ?? {});
  }

  /// Get list of accepted connections as Map for dropdown/list usage
  Future<List<Map<String, dynamic>>> getAcceptedConnections() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snap = await _db
        .collection('users')
        .doc(user.uid)
        .collection('connections')
        .get();

    return snap.docs.map((d) {
      final data = d.data();
      return {
        'id': d.id, // Vendor ID
        ...data,
      };
    }).toList();
  }

  /// Search for shops by ID or Name
  Future<List<Map<String, dynamic>>> searchShops(String query) async {
    if (query.isEmpty) return [];

    final results = <Map<String, dynamic>>[];

    // 1. Exact match ownerID
    final byId = await _db
        .collection('owners')
        .where('ownerId', isEqualTo: query)
        .get();
    for (var doc in byId.docs) {
      results.add({'id': doc.id, ...doc.data()});
    }

    // 2. Exact match shopName (if not already found)
    if (results.isEmpty) {
      final byName = await _db
          .collection('owners')
          .where('shopName', isEqualTo: query)
          .get();
      for (var doc in byName.docs) {
        if (!results.any((r) => r['id'] == doc.id)) {
          results.add({'id': doc.id, ...doc.data()});
        }
      }
    }

    return results;
  }

  /// Unlink a shop
  Future<void> unlinkShop(String vendorId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Auth required');

    // Remove from my connections
    await _db
        .collection('users')
        .doc(user.uid)
        .collection('connections')
        .doc(vendorId)
        .delete();

    // Optionally notify vendor or remove from their list?
    // For now we just remove from our local list.

    // Also remove from legacy customers list if needed (backwards compat)
    await _db
        .collection('customers')
        .doc(user.uid)
        .update({
          'linkedShopIds': FieldValue.arrayRemove([vendorId]),
        })
        .onError((e, s) => null); // Ignore error if doc doesn't exist
  }

  /// Verify a 6-digit link request code (Legacy/Remote Flow)
  Future<bool> verifyLinkRequest(String phone, String code) async {
    try {
      final snap = await _db
          .collection('link_requests')
          .where('phone', isEqualTo: phone)
          .where('code', isEqualTo: code)
          .where('used', isEqualTo: false)
          .get();

      if (snap.docs.isEmpty) return false;

      final doc = snap.docs.first;
      final data = doc.data();

      final expires = DateTime.parse(data['expiresAt']);
      if (DateTime.now().isAfter(expires)) return false;

      final ownerId = data['ownerId'];

      // Find customer by phone
      final custSnap = await _db
          .collection('customers')
          .where('phone', isEqualTo: phone)
          .get();

      if (custSnap.docs.isEmpty) {
        // Create new customer doc
        await _db.collection('customers').add({
          'name': '',
          'phone': phone,
          'address': '',
          'totalDues': 0.0,
          'vegetableHistory': [],
          'billHistory': [],
          'ownerId': ownerId,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Update existing
        final custDoc = custSnap.docs.first;
        await _db.collection('customers').doc(custDoc.id).update({
          'ownerId': ownerId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Mark request as used
      await _db.collection('link_requests').doc(doc.id).update({'used': true});

      return true;
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
    return ConnectionRequest(
      id: id,
      customerId: map['customerId'] ?? '',
      customerUserId: map['customerUserId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
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
      vendorId: map['vendorId'] ?? '',
      customerId: map['customerId'] ?? '',
      shopName: map['shopName'] ?? 'Unknown Shop',
    );
  }
}
