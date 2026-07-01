// Invoice Profile Integration
// Bridges VendorProfile with InvoiceConfig for automatic data injection
//
// Created: 2024-12-25
// Author: DukanX Team

import 'dart:typed_data';
import 'package:flutter/services.dart' as services;
import 'package:flutter/material.dart';
import '../models/vendor_profile.dart';
import '../services/vendor_profile_service.dart';
import '../services/invoice_pdf_service.dart';

/// Invoice profile helper - fetches vendor profile for invoice generation
class InvoiceProfileHelper {
  static final InvoiceProfileHelper _instance =
      InvoiceProfileHelper._internal();
  factory InvoiceProfileHelper() => _instance;
  InvoiceProfileHelper._internal();

  final _profileService = VendorProfileService();

  /// Get InvoiceConfig from vendor profile (real-time fetch)
  /// This is the SINGLE SOURCE OF TRUTH for invoice generation
  Future<InvoiceConfig> getInvoiceConfig({
    InvoiceLanguage language = InvoiceLanguage.english,
    bool showTax = false,
    bool isGstBill = false,
    Uint8List? signatureImage,
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
        debugPrint('Failed to fetch logo: $e');
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
        debugPrint('Failed to load avatar asset: $e');
      }
    }

    return InvoiceConfig(
      shopName: profile.shopName,
      ownerName: profile.vendorName,
      address: profile.shopAddress,
      mobile: profile.shopMobile,
      gstin: profile.gstin,
      email: profile.email,
      logoImage: logoBytes,
      avatarImage: avatarBytes,
      signatureImage: signatureImage,
      language: language,
      showTax: showTax,
      isGstBill:
          isGstBill || (profile.gstin != null && profile.gstin!.isNotEmpty),
    );
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
}

/// Global instance for easy access
final invoiceProfileHelper = InvoiceProfileHelper();

/// Extension on InvoicePdfService for profile-based invoice generation
extension InvoicePdfServiceProfileExtension on InvoicePdfService {
  /// Generate invoice PDF using vendor profile (auto-fetched)
  /// This is the recommended method for invoice generation
  Future<Uint8List> generateInvoiceFromProfile({
    required InvoiceCustomer customer,
    required List<InvoiceItem> items,
    required String invoiceNumber,
    required DateTime invoiceDate,
    DateTime? dueDate,
    double? discount,
    String? notes,
    String? termsAndConditions,
    InvoiceLanguage language = InvoiceLanguage.english,
    bool showTax = false,
    Uint8List? signatureImage,
  }) async {
    // Get config from profile (single source of truth)
    final config = await invoiceProfileHelper.getInvoiceConfig(
      language: language,
      showTax: showTax,
      signatureImage: signatureImage,
    );

    // Generate PDF with profile data
    return generateInvoicePdf(
      config: config,
      customer: customer,
      items: items,
      invoiceNumber: invoiceNumber,
      invoiceDate: invoiceDate,
      dueDate: dueDate,
      discount: discount,
      notes: notes,
      termsAndConditions: termsAndConditions,
    );
  }
}
