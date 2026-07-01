// Enhanced Invoice Profile Integration
// Bridges VendorProfile with EnhancedInvoicePdfService for automatic data injection
//
// Created: 2024-12-26
// Author: DukanX Team

import 'dart:typed_data';
import 'package:flutter/services.dart' as services;
// firebase_storage removed — migrate to S3 pre-signed URLs
import '../../../../core/pdf/enhanced_invoice_pdf_service.dart';
import '../../../../core/pdf/invoice_models.dart';
import '../../../../core/pdf/invoice_pdf_theme.dart';
import '../../../../models/vendor_profile.dart';
import '../../../../models/bill.dart';
import '../../../../services/vendor_profile_service.dart';
import '../../../../core/services/logger_service.dart';

import '../../../../models/business_type.dart';
import '../../../../services/invoice_pdf_service.dart' show InvoiceLanguage;

/// Enhanced invoice profile helper - bridges VendorProfile with PDF generation
class EnhancedInvoiceProfileHelper {
  static final EnhancedInvoiceProfileHelper _instance =
      EnhancedInvoiceProfileHelper._internal();
  factory EnhancedInvoiceProfileHelper() => _instance;
  EnhancedInvoiceProfileHelper._internal();

  final _profileService = VendorProfileService();
  final _pdfService = EnhancedInvoicePdfService();

  /// Get EnhancedInvoiceConfig from vendor profile (real-time fetch)
  /// This is the SINGLE SOURCE OF TRUTH for invoice generation
  Future<EnhancedInvoiceConfig> getInvoiceConfig({
    InvoiceLanguage language = InvoiceLanguage.english,
    BusinessType? businessType,
    bool showTax = false,
    bool isGstBill = false,
    Uint8List? signatureImage,
    Uint8List? stampImage,
  }) async {
    // Always fetch fresh profile for invoice
    final profile = await _profileService.getProfileForInvoice();

    if (profile == null) {
      throw Exception(
        'Vendor profile not found. Please set up your profile first.',
      );
    }

    // Get logo bytes if available
    Uint8List? logoBytes;
    if (profile.shopLogoUrl != null) {
      try {
        logoBytes = await _profileService.getLogoBytes();
      } catch (e) {
        LoggerService.d('InvoiceProfile', 'Failed to fetch logo: $e');
      }
    }

    // Get avatar bytes if available
    Uint8List? avatarBytes;
    if (profile.avatar != null) {
      try {
        final byteData = await services.rootBundle.load(
          profile.avatar!.assetPath,
        );
        avatarBytes = byteData.buffer.asUint8List();
      } catch (e) {
        LoggerService.d('InvoiceProfile', 'Failed to load avatar asset: $e');
      }
    }

    // Get signature bytes if stored URL exists and no override provided
    Uint8List? sigBytes = signatureImage;
    if (sigBytes == null && profile.signatureImageUrl != null) {
      try {
        sigBytes = await _loadImageFromUrl(profile.signatureImageUrl!);
      } catch (e) {
        LoggerService.d('InvoiceProfile', 'Failed to load signature: $e');
      }
    }

    // Get stamp bytes if stored URL exists and no override provided
    Uint8List? stmpBytes = stampImage;
    if (stmpBytes == null && profile.stampImageUrl != null) {
      try {
        stmpBytes = await _loadImageFromUrl(profile.stampImageUrl!);
      } catch (e) {
        LoggerService.d('InvoiceProfile', 'Failed to load stamp: $e');
      }
    }

    // Determine business type
    BusinessType actualBusinessType = businessType ?? BusinessType.grocery;
    if (profile.businessType != null) {
      try {
        actualBusinessType = BusinessType.values.firstWhere(
          (e) => e.toString().contains(profile.businessType!),
          orElse: () => BusinessType.grocery,
        );
      } catch (_) {
        // Use default
      }
    }

    return EnhancedInvoiceConfig(
      shopName: profile.shopName,
      ownerName: profile.vendorName,
      address: profile.shopAddress,
      mobile: profile.shopMobile,
      email: profile.email,
      gstin: profile.gstin,
      fssaiNumber: profile.fssaiNumber,
      tagline: profile.businessTagline,
      upiId: profile.upiId,
      logoImage: logoBytes,
      avatarImage: avatarBytes,
      signatureImage: sigBytes,
      stampImage: stmpBytes,
      language: language,
      businessType: actualBusinessType,
      showTax: showTax,
      isGstBill:
          isGstBill || (profile.gstin != null && profile.gstin!.isNotEmpty),
      returnPolicy: profile.returnPolicy,
    );
  }

  /// Generate invoice PDF from a Bill using profile data
  Future<Uint8List> generateInvoiceFromBill({
    required Bill bill,
    InvoiceLanguage language = InvoiceLanguage.english,
    BusinessType? businessType,
    bool showTax = false,
    String? notes,
    Uint8List? signatureImage,
    Uint8List? stampImage,
  }) async {
    final config = await getInvoiceConfig(
      language: language,
      businessType: businessType,
      showTax: showTax,
      signatureImage: signatureImage,
      stampImage: stampImage,
    );

    return _pdfService.generateFromBill(
      bill: bill,
      config: config,
      notes: notes,
    );
  }

  /// Generate invoice PDF from items (for new invoices)
  Future<Uint8List> generateInvoice({
    required String invoiceNumber,
    required DateTime invoiceDate,
    required List<EnhancedInvoiceItem> items,
    required EnhancedInvoiceCustomer customer,
    InvoiceLanguage language = InvoiceLanguage.english,
    BusinessType? businessType,
    bool showTax = false,
    String? notes,
    double? additionalDiscount,
    DateTime? dueDate,
    InvoiceStatus? status,
    PaymentMode? paymentMode,
    Uint8List? signatureImage,
    Uint8List? stampImage,
  }) async {
    final config = await getInvoiceConfig(
      language: language,
      businessType: businessType,
      showTax: showTax,
      signatureImage: signatureImage,
      stampImage: stampImage,
    );

    return _pdfService.generateInvoicePdf(
      config: config,
      customer: customer,
      items: items,
      invoiceNumber: invoiceNumber,
      invoiceDate: invoiceDate,
      dueDate: dueDate,
      additionalDiscount: additionalDiscount,
      notes: notes,
      status: status,
      paymentMode: paymentMode,
    );
  }

  /// Share invoice via platform share sheet
  Future<void> shareInvoice(Uint8List pdfBytes, String invoiceNumber) async {
    await _pdfService.shareInvoice(pdfBytes, invoiceNumber);
  }

  /// Print invoice directly
  Future<void> printInvoice(Uint8List pdfBytes) async {
    await _pdfService.printInvoice(pdfBytes);
  }

  /// Save invoice to device
  Future<String?> saveInvoice(Uint8List pdfBytes, String invoiceNumber) async {
    return await _pdfService.saveInvoice(pdfBytes, invoiceNumber);
  }

  /// Check if profile is complete for invoice generation
  Future<bool> isProfileComplete() async {
    final profile = await _profileService.loadProfile();
    return profile?.isComplete ?? false;
  }

  /// Get cached profile (for quick checks, not for invoice)
  VendorProfile? get cachedProfile => _profileService.profile;

  /// Stream profile changes
  Stream<VendorProfile?> streamProfile() => _profileService.streamProfile();

  // Helper to load image from URL using Firebase Storage
  Future<Uint8List?> _loadImageFromUrl(String url) async {
    try {
      // Future: load using standard HTTP client for S3 pre-signed URLs
      LoggerService.d('InvoiceProfile', 'Cloud URL detected, skipping for now: $url');
      return null;
    } catch (e) {
      LoggerService.d('InvoiceProfile', 'Failed to load image from URL: $e');
      return null;
    }
  }
}

/// Global instance for easy access
final enhancedInvoiceProfileHelper = EnhancedInvoiceProfileHelper();

/// Extension for quick invoice generation from Bill
extension BillPdfExtension on Bill {
  /// Generate PDF for this bill
  Future<Uint8List> generatePdf({
    InvoiceLanguage language = InvoiceLanguage.english,
    BusinessType? businessType,
    bool showTax = false,
    String? notes,
  }) async {
    return enhancedInvoiceProfileHelper.generateInvoiceFromBill(
      bill: this,
      language: language,
      businessType: businessType,
      showTax: showTax,
      notes: notes,
    );
  }

  /// Share this bill as PDF
  Future<void> sharePdf({
    InvoiceLanguage language = InvoiceLanguage.english,
    bool showTax = false,
  }) async {
    final pdfBytes = await generatePdf(language: language, showTax: showTax);
    await enhancedInvoiceProfileHelper.shareInvoice(pdfBytes, invoiceNumber);
  }

  /// Print this bill
  Future<void> printBill({
    InvoiceLanguage language = InvoiceLanguage.english,
    bool showTax = false,
  }) async {
    final pdfBytes = await generatePdf(language: language, showTax: showTax);
    await enhancedInvoiceProfileHelper.printInvoice(pdfBytes);
  }
}
