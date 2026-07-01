// ============================================================================
// BILL SIGNATURE SERVICE - Control 2
// ============================================================================
// Generates SHA-256 hashes for bill data and embeds in PDF metadata
// for audit trust and legal compliance.
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../models/bill.dart';

/// Bill Signature Service - Generates tamper-evident hashes for bills
class BillSignatureService {
  /// Generate SHA-256 hash of bill data
  ///
  /// Creates a deterministic hash based on:
  /// - Invoice number
  /// - Date
  /// - Items (productId, qty, price)
  /// - Grand total
  /// - Customer info
  ///
  /// This hash can be verified later to detect any modifications.
  String generateBillHash(Bill bill) {
    // Create canonical representation of bill data
    final canonicalData = _buildCanonicalBillData(bill);

    // Compute SHA-256 hash
    final bytes = utf8.encode(canonicalData);
    final digest = sha256.convert(bytes);

    return digest.toString();
  }

  /// Build canonical (deterministic) string representation of bill
  String _buildCanonicalBillData(Bill bill) {
    final buffer = StringBuffer();

    // Header fields
    buffer.writeln('INVOICE:${bill.invoiceNumber}');
    buffer.writeln('DATE:${bill.date.toIso8601String()}');
    buffer.writeln('OWNER:${bill.ownerId}');
    buffer.writeln(
      'CUSTOMER:${bill.customerId}|${bill.customerName}|${bill.customerGst}',
    );

    // Items (sorted by productId for consistency)
    final sortedItems = List<BillItem>.from(bill.items)
      ..sort((a, b) => a.productId.compareTo(b.productId));

    for (final item in sortedItems) {
      buffer.writeln(
        'ITEM:${item.productId}|${item.productName}|${item.qty}|${item.price}|${item.discount}|${item.cgst}|${item.sgst}|${item.igst}',
      );
    }

    // Totals
    buffer.writeln('SUBTOTAL:${bill.subtotal.toStringAsFixed(2)}');
    buffer.writeln('TAX:${bill.totalTax.toStringAsFixed(2)}');
    buffer.writeln('DISCOUNT:${bill.discountApplied.toStringAsFixed(2)}');
    buffer.writeln('GRAND_TOTAL:${bill.grandTotal.toStringAsFixed(2)}');
    buffer.writeln('PAID:${bill.paidAmount.toStringAsFixed(2)}');

    return buffer.toString();
  }

  /// Verify bill signature by comparing stored hash with computed hash
  BillSignatureVerificationResult verifyBillSignature(
    Bill bill,
    String storedHash,
  ) {
    final computedHash = generateBillHash(bill);
    final isValid = computedHash == storedHash;

    return BillSignatureVerificationResult(
      isValid: isValid,
      billId: bill.id,
      invoiceNumber: bill.invoiceNumber,
      storedHash: storedHash,
      computedHash: computedHash,
      verifiedAt: DateTime.now(),
    );
  }

  /// Generate signature metadata for PDF embedding
  ///
  /// Returns a map that can be embedded in PDF metadata:
  /// - hash: SHA-256 hash of bill data
  /// - algorithm: Hash algorithm used
  /// - signedAt: ISO timestamp
  /// - appId: Application identifier
  Map<String, String> generatePdfMetadata(Bill bill) {
    final hash = generateBillHash(bill);

    return {
      'dukanx_signature': hash,
      'dukanx_algorithm': 'SHA-256',
      'dukanx_signed_at': DateTime.now().toIso8601String(),
      'dukanx_app_id': 'com.dukanx.billing',
      'dukanx_version': '1.0',
      'dukanx_invoice': bill.invoiceNumber,
    };
  }

  /// Embed signature in existing PDF bytes
  ///
  /// Note: This is a simplified implementation that appends metadata
  /// as a comment. For production, integrate with a proper PDF library.
  Uint8List embedSignatureInPdf(
    Uint8List pdfBytes,
    Map<String, String> metadata,
  ) {
    try {
      // Create signature block as PDF comment
      final signatureBlock = StringBuffer();
      signatureBlock.writeln('%% DukanX Digital Signature');
      for (final entry in metadata.entries) {
        signatureBlock.writeln('%% ${entry.key}: ${entry.value}');
      }
      signatureBlock.writeln('%% End Signature');

      // Append to PDF
      final signatureBytes = utf8.encode(signatureBlock.toString());
      final combined = Uint8List(pdfBytes.length + signatureBytes.length);
      combined.setAll(0, pdfBytes);
      combined.setAll(pdfBytes.length, signatureBytes);

      return combined;
    } catch (e) {
      debugPrint('BillSignatureService: Failed to embed signature: $e');
      return pdfBytes; // Return original if embedding fails
    }
  }
}

// ============================================================
// RESULT CLASSES
// ============================================================

/// Result of bill signature verification
class BillSignatureVerificationResult {
  final bool isValid;
  final String billId;
  final String invoiceNumber;
  final String storedHash;
  final String computedHash;
  final DateTime verifiedAt;

  BillSignatureVerificationResult({
    required this.isValid,
    required this.billId,
    required this.invoiceNumber,
    required this.storedHash,
    required this.computedHash,
    required this.verifiedAt,
  });

  Map<String, dynamic> toJson() => {
    'isValid': isValid,
    'billId': billId,
    'invoiceNumber': invoiceNumber,
    'storedHash': storedHash,
    'computedHash': computedHash,
    'verifiedAt': verifiedAt.toIso8601String(),
  };
}
