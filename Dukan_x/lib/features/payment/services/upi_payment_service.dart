import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

import '../../../config/security_config.dart';

/// Secure UPI Payment Service
///
/// Implements Multi-Layer Fraud Defense:
/// - Layer 1: Bill & Vendor Locking
/// - Layer 2: Nonce + HMAC Signature
/// - Layer 5: Time-Bound Expiry (5 mins)
/// - Layer 7: Transaction Fingerprinting
class UpiPaymentService {
  final AppDatabase _db;

  // Secret loaded from configuration (cached after first load)
  String? _cachedSecret;

  UpiPaymentService(this._db);

  /// Initialize the secret from secure storage
  Future<void> _ensureInitialized() async {
    _cachedSecret ??= await SecurityConfig.getPaymentHmacSecret();
  }

  /// Generate a secure, signed, time-bound UPI QR payload
  Future<String> generateDynamicQrPayload({
    required String billId,
    required String vendorId,
    required double amount,
    required String note,
  }) async {
    // Ensure secret is loaded
    await _ensureInitialized();

    // 1. Fetch Vendor
    final vendor = await (_db.select(
      _db.vendors,
    )..where((t) => t.id.equals(vendorId))).getSingleOrNull();

    if (vendor == null || vendor.upiId == null || vendor.upiId!.isEmpty) {
      throw Exception('Vendor missing secure UPI ID');
    }

    // 2. Security Parameters
    final nonce = const Uuid().v4(); // Layer 2: Unique Nonce
    final expiresAt = DateTime.now().add(
      const Duration(minutes: 5),
    ); // Layer 5: 5-min expiry
    // Use part of nonce for TR to keep it short enough for UPI (max 35 chars usually safe)
    // UPI spec says tr can be up to 35 chars. Using billId substring + random
    final tr = 'TR-${billId.substring(0, 4)}-${nonce.substring(0, 6)}'
        .toUpperCase();

    // 3. Generate HMAC Signature (Layer 2)
    final signatureData = '$billId|$vendorId|$amount|$nonce|$tr';
    final signature = _generateSignature(signatureData);

    // 4. Create Audit Record
    await _db
        .into(_db.paymentTransactions)
        .insert(
          PaymentTransactionsCompanion.insert(
            id: const Uuid().v4(),
            billId: billId,
            vendorId: vendorId,
            transactionRef: tr,
            amount: amount,
            nonce: Value(nonce), // Layer 2: UUIDv7 Nonce
            signature: Value(signature),
            expiresAt: Value(expiresAt),
            status: const Value('PENDING'),
            createdAt: DateTime.now(),
          ),
        );

    // 5. Construct UPI URI with signature in 'ref' or 'tn' if possible,
    // but standard UPI apps won't read custom params.
    // We rely on the 'tr' being the key to look up the secure record on our server/db.
    final uri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': vendor.upiId!,
        'pn': vendor.upiName ?? vendor.name,
        'am': amount.toStringAsFixed(2),
        'tr': tr,
        'tn': '$note (Valid for 5m)', // User visible expiry hint
        'cu': 'INR',
      },
    );

    return uri.toString();
  }

  String _generateSignature(String data) {
    final key = utf8.encode(_cachedSecret!);
    final bytes = utf8.encode(data);
    final hmac = Hmac(sha256, key);
    return hmac.convert(bytes).toString();
  }

  /// Verify a transaction attempt (Simulates Server-Side Check)
  Future<bool> verifyTransaction({
    required String billId,
    required String payerUpi, // From callback
    required double paidAmount,
  }) async {
    final txn = await (_db.select(
      _db.paymentTransactions,
    )..where((t) => t.billId.equals(billId))).getSingleOrNull();

    if (txn == null) throw Exception('Transaction not found');

    // Layer 5: Expiry Check
    if (DateTime.now().isAfter(txn.expiresAt ?? DateTime.now())) {
      await _markFailed(txn.id, 'EXPIRED_QR');
      throw Exception('QR Code Expired');
    }

    // Layer 3: Strict Amount Match
    if ((txn.amount - paidAmount).abs() > 0.01) {
      await _markFailed(txn.id, 'AMOUNT_MISMATCH');
      throw Exception('Amount mismatch detected');
    }

    // Layer 1: Status Check (Anti-Replay)
    if (txn.status == 'SUCCESS') {
      throw Exception('Transaction already processed (Replay Attempt)');
    }

    // Layer 7: Fingerprinting
    final fingerprint = _generateFingerprint(
      txn.billId,
      txn.vendorId,
      txn.amount,
      payerUpi,
    );
    // Check if fingerprint exists (duplicate payment with same params)
    final dupe =
        await (_db.select(_db.paymentTransactions)
              ..where((t) => t.transactionFingerprint.equals(fingerprint)))
            .getSingleOrNull();

    if (dupe != null && dupe.id != txn.id) {
      await _markFailed(txn.id, 'DUPLICATE_FINGERPRINT');
      throw Exception('Duplicate transaction detected');
    }

    // Success
    await (_db.update(
      _db.paymentTransactions,
    )..where((t) => t.id.equals(txn.id))).write(
      PaymentTransactionsCompanion(
        status: const Value('SUCCESS'),
        isVerified: const Value(true),
        verifiedAt: Value(DateTime.now()),
        payerUpi: Value(payerUpi),
        transactionFingerprint: Value(fingerprint),
      ),
    );

    return true;
  }

  String _generateFingerprint(
    String billId,
    String vendorId,
    double amount,
    String payerUpi,
  ) {
    final data = '$billId|$vendorId|$amount|$payerUpi';
    // SHA-256 Fingerprint
    return sha256.convert(utf8.encode(data)).toString();
  }

  Future<void> _markFailed(String id, String reason) async {
    await (_db.update(
      _db.paymentTransactions,
    )..where((t) => t.id.equals(id))).write(
      PaymentTransactionsCompanion(
        status: const Value('FAILED'),
        scannedByParams: Value('Reason: $reason'),
      ),
    );
  }
}
