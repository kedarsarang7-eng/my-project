// Invoice PDF Theme - Business-type based color theming
// Different visual themes for different business types
//
// Created: 2024-12-26
// Author: DukanX Team

import 'package:pdf/pdf.dart';
import '../../models/business_type.dart';

/// Invoice PDF theme configuration
class InvoicePdfTheme {
  final PdfColor primaryColor;
  final PdfColor primaryLight;
  final PdfColor primaryDark;
  final PdfColor accentColor;
  final PdfColor textDark;
  final PdfColor textGray;
  final PdfColor borderColor;
  final PdfColor successColor;
  final PdfColor warningColor;
  final PdfColor errorColor;

  const InvoicePdfTheme({
    required this.primaryColor,
    required this.primaryLight,
    required this.primaryDark,
    required this.accentColor,
    required this.textDark,
    required this.textGray,
    required this.borderColor,
    required this.successColor,
    required this.warningColor,
    required this.errorColor,
  });

  /// Get theme based on business type
  static InvoicePdfTheme fromBusinessType(BusinessType type) {
    switch (type) {
      case BusinessType.grocery:
        return groceryTheme;
      case BusinessType.pharmacy:
        return pharmacyTheme;
      case BusinessType.restaurant:
        return restaurantTheme;
      case BusinessType.hardware:
        return hardwareTheme;
      case BusinessType.service:
        return serviceTheme;
      case BusinessType.clothing:
        return clothingTheme;
      case BusinessType.electronics:
        return electronicsTheme;
      case BusinessType.other:
        return otherTheme;
      case BusinessType.wholesale:
        return wholesaleTheme;
      case BusinessType.petrolPump:
        return petrolPumpTheme;
      case BusinessType.mobileShop:
        return mobileShopTheme;
      case BusinessType.vegetablesBroker:
        return vegetablesBrokerTheme;
      case BusinessType.computerShop:
        return computerShopTheme;
      case BusinessType.clinic:
        return clinicTheme;
      case BusinessType.bookStore:
        return bookStoreTheme;
      case BusinessType.jewellery:
        return jewelleryTheme;
      case BusinessType.autoParts:
        return autoPartsTheme;
      case BusinessType.decorationCatering:
        return decorationCateringTheme;
      case BusinessType.schoolErp:
        return schoolErpTheme;
    }
  }

  // ========== GROCERY THEME (GREEN) ==========
  static const InvoicePdfTheme groceryTheme = InvoicePdfTheme(
    primaryColor: PdfColor.fromInt(0xFF059669), // Emerald 600
    primaryLight: PdfColor.fromInt(0xFFD1FAE5), // Emerald 100
    primaryDark: PdfColor.fromInt(0xFF047857), // Emerald 700
    accentColor: PdfColor.fromInt(0xFF10B981), // Emerald 500
    textDark: PdfColor.fromInt(0xFF1F2937), // Gray 800
    textGray: PdfColor.fromInt(0xFF6B7280), // Gray 500
    borderColor: PdfColor.fromInt(0xFFE5E7EB), // Gray 200
    successColor: PdfColor.fromInt(0xFF22C55E), // Green 500
    warningColor: PdfColor.fromInt(0xFFF59E0B), // Amber 500
    errorColor: PdfColor.fromInt(0xFFEF4444), // Red 500
  );

  // ========== PHARMACY THEME (BLUE) ==========
  static const InvoicePdfTheme pharmacyTheme = InvoicePdfTheme(
    primaryColor: PdfColor.fromInt(0xFF1E40AF), // Blue 800
    primaryLight: PdfColor.fromInt(0xFFDBEAFE), // Blue 100
    primaryDark: PdfColor.fromInt(0xFF1E3A8A), // Blue 900
    accentColor: PdfColor.fromInt(0xFF3B82F6), // Blue 500
    textDark: PdfColor.fromInt(0xFF1F2937),
    textGray: PdfColor.fromInt(0xFF6B7280),
    borderColor: PdfColor.fromInt(0xFFE5E7EB),
    successColor: PdfColor.fromInt(0xFF22C55E),
    warningColor: PdfColor.fromInt(0xFFF59E0B),
    errorColor: PdfColor.fromInt(0xFFEF4444),
  );

  // ========== RESTAURANT THEME (ORANGE/WARM) ==========
  static const InvoicePdfTheme restaurantTheme = InvoicePdfTheme(
    primaryColor: PdfColor.fromInt(0xFFEA580C), // Orange 600
    primaryLight: PdfColor.fromInt(0xFFFFEDD5), // Orange 100
    primaryDark: PdfColor.fromInt(0xFFC2410C), // Orange 700
    accentColor: PdfColor.fromInt(0xFFF97316), // Orange 500
    textDark: PdfColor.fromInt(0xFF1F2937),
    textGray: PdfColor.fromInt(0xFF6B7280),
    borderColor: PdfColor.fromInt(0xFFE5E7EB),
    successColor: PdfColor.fromInt(0xFF22C55E),
    warningColor: PdfColor.fromInt(0xFFF59E0B),
    errorColor: PdfColor.fromInt(0xFFEF4444),
  );

  // ========== HARDWARE THEME (GRAY/INDUSTRIAL) ==========
  static const InvoicePdfTheme hardwareTheme = InvoicePdfTheme(
    primaryColor: PdfColor.fromInt(0xFF374151), // Gray 700
    primaryLight: PdfColor.fromInt(0xFFF3F4F6), // Gray 100
    primaryDark: PdfColor.fromInt(0xFF1F2937), // Gray 800
    accentColor: PdfColor.fromInt(0xFF4B5563), // Gray 600
    textDark: PdfColor.fromInt(0xFF111827), // Gray 900
    textGray: PdfColor.fromInt(0xFF6B7280),
    borderColor: PdfColor.fromInt(0xFF9CA3AF), // Gray 400 (stronger borders)
    successColor: PdfColor.fromInt(0xFF22C55E),
    warningColor: PdfColor.fromInt(0xFFF59E0B),
    errorColor: PdfColor.fromInt(0xFFEF4444),
  );

  // ========== SERVICE THEME (PURPLE) ==========
  static const InvoicePdfTheme serviceTheme = InvoicePdfTheme(
    primaryColor: PdfColor.fromInt(0xFF7C3AED), // Violet 600
    primaryLight: PdfColor.fromInt(0xFFEDE9FE), // Violet 100
    primaryDark: PdfColor.fromInt(0xFF6D28D9), // Violet 700
    accentColor: PdfColor.fromInt(0xFF8B5CF6), // Violet 500
    textDark: PdfColor.fromInt(0xFF1F2937),
    textGray: PdfColor.fromInt(0xFF6B7280),
    borderColor: PdfColor.fromInt(0xFFE5E7EB),
    successColor: PdfColor.fromInt(0xFF22C55E),
    warningColor: PdfColor.fromInt(0xFFF59E0B),
    errorColor: PdfColor.fromInt(0xFFEF4444),
  );

  // ========== WHOLESALE THEME (TEAL) ==========
  static const InvoicePdfTheme wholesaleTheme = InvoicePdfTheme(
    primaryColor: PdfColor.fromInt(0xFF0D9488), // Teal 600
    primaryLight: PdfColor.fromInt(0xFFCCFBF1), // Teal 100
    primaryDark: PdfColor.fromInt(0xFF0F766E), // Teal 700
    accentColor: PdfColor.fromInt(0xFF14B8A6), // Teal 500
    textDark: PdfColor.fromInt(0xFF1F2937),
    textGray: PdfColor.fromInt(0xFF6B7280),
    borderColor: PdfColor.fromInt(0xFFE5E7EB),
    successColor: PdfColor.fromInt(0xFF22C55E),
    warningColor: PdfColor.fromInt(0xFFF59E0B),
    errorColor: PdfColor.fromInt(0xFFEF4444),
  );

  // ========== PETROL PUMP THEME (RED/ORANGE) ==========
  static const InvoicePdfTheme petrolPumpTheme = InvoicePdfTheme(
    primaryColor: PdfColor.fromInt(0xFFDC2626), // Red 600
    primaryLight: PdfColor.fromInt(0xFFFEE2E2), // Red 100
    primaryDark: PdfColor.fromInt(0xFFB91C1C), // Red 700
    accentColor: PdfColor.fromInt(0xFFF97316), // Orange 500
    textDark: PdfColor.fromInt(0xFF1F2937),
    textGray: PdfColor.fromInt(0xFF6B7280),
    borderColor: PdfColor.fromInt(0xFFE5E7EB),
    successColor: PdfColor.fromInt(0xFF22C55E),
    warningColor: PdfColor.fromInt(0xFFF59E0B),
    errorColor: PdfColor.fromInt(0xFFEF4444),
  );

  // ========== CLOTHING THEME (PINK) ==========
  static const InvoicePdfTheme clothingTheme = InvoicePdfTheme(
    primaryColor: PdfColor.fromInt(0xFFDB2777), // Pink 600
    primaryLight: PdfColor.fromInt(0xFFFCE7F3), // Pink 100
    primaryDark: PdfColor.fromInt(0xFFBE185D), // Pink 700
    accentColor: PdfColor.fromInt(0xFFEC4899), // Pink 500
    textDark: PdfColor.fromInt(0xFF1F2937),
    textGray: PdfColor.fromInt(0xFF6B7280),
    borderColor: PdfColor.fromInt(0xFFE5E7EB),
    successColor: PdfColor.fromInt(0xFF22C55E),
    warningColor: PdfColor.fromInt(0xFFF59E0B),
    errorColor: PdfColor.fromInt(0xFFEF4444),
  );

  // ========== ELECTRONICS THEME (CYAN) ==========
  static const InvoicePdfTheme electronicsTheme = InvoicePdfTheme(
    primaryColor: PdfColor.fromInt(0xFF0891B2), // Cyan 600
    primaryLight: PdfColor.fromInt(0xFFCFFAFE), // Cyan 100
    primaryDark: PdfColor.fromInt(0xFF0E7490), // Cyan 700
    accentColor: PdfColor.fromInt(0xFF06B6D4), // Cyan 500
    textDark: PdfColor.fromInt(0xFF1F2937),
    textGray: PdfColor.fromInt(0xFF6B7280),
    borderColor: PdfColor.fromInt(0xFFE5E7EB),
    successColor: PdfColor.fromInt(0xFF22C55E),
    warningColor: PdfColor.fromInt(0xFFF59E0B),
    errorColor: PdfColor.fromInt(0xFFEF4444),
  );

  // ========== MOBILE SHOP THEME (LIGHT CYAN) ==========
  static const InvoicePdfTheme mobileShopTheme = InvoicePdfTheme(
    primaryColor: PdfColor.fromInt(0xFF06B6D4), // Cyan 500
    primaryLight: PdfColor.fromInt(0xFFE0F2FE), // Sky 100
    primaryDark: PdfColor.fromInt(0xFF0891B2), // Cyan 600
    accentColor: PdfColor.fromInt(0xFF38BDF8), // Sky 400
    textDark: PdfColor.fromInt(0xFF1F2937),
    textGray: PdfColor.fromInt(0xFF6B7280),
    borderColor: PdfColor.fromInt(0xFFE5E7EB),
    successColor: PdfColor.fromInt(0xFF22C55E),
    warningColor: PdfColor.fromInt(0xFFF59E0B),
    errorColor: PdfColor.fromInt(0xFFEF4444),
  );

  // ========== COMPUTER SHOP THEME (BLUE) ==========
  static const InvoicePdfTheme computerShopTheme = InvoicePdfTheme(
    primaryColor: PdfColor.fromInt(0xFF3B82F6), // Blue 500
    primaryLight: PdfColor.fromInt(0xFFDBEAFE), // Blue 100
    primaryDark: PdfColor.fromInt(0xFF1D4ED8), // Blue 700
    accentColor: PdfColor.fromInt(0xFF60A5FA), // Blue 400
    textDark: PdfColor.fromInt(0xFF1F2937),
    textGray: PdfColor.fromInt(0xFF6B7280),
    borderColor: PdfColor.fromInt(0xFFE5E7EB),
    successColor: PdfColor.fromInt(0xFF22C55E),
    warningColor: PdfColor.fromInt(0xFFF59E0B),
    errorColor: PdfColor.fromInt(0xFFEF4444),
  );

  // ========== VEGETABLES BROKER THEME (GREEN) ==========
  static const InvoicePdfTheme vegetablesBrokerTheme = InvoicePdfTheme(
    primaryColor: PdfColor.fromInt(0xFF16A34A), // Green 600
    primaryLight: PdfColor.fromInt(0xFFDCFCE7), // Green 100
    primaryDark: PdfColor.fromInt(0xFF15803D), // Green 700
    accentColor: PdfColor.fromInt(0xFF22C55E), // Green 500
    textDark: PdfColor.fromInt(0xFF1F2937),
    textGray: PdfColor.fromInt(0xFF6B7280),
    borderColor: PdfColor.fromInt(0xFFE5E7EB),
    successColor: PdfColor.fromInt(0xFF22C55E),
    warningColor: PdfColor.fromInt(0xFFF59E0B),
    errorColor: PdfColor.fromInt(0xFFEF4444),
  );

  // ========== OTHER THEME (STONE) ==========
  static const InvoicePdfTheme otherTheme = InvoicePdfTheme(
    primaryColor: PdfColor.fromInt(0xFF57534E), // Stone 600
    primaryLight: PdfColor.fromInt(0xFFF5F5F4), // Stone 100
    primaryDark: PdfColor.fromInt(0xFF44403C), // Stone 700
    accentColor: PdfColor.fromInt(0xFF78716C), // Stone 500
    textDark: PdfColor.fromInt(0xFF1F2937),
    textGray: PdfColor.fromInt(0xFF6B7280),
    borderColor: PdfColor.fromInt(0xFFE5E7EB),
    successColor: PdfColor.fromInt(0xFF22C55E),
    warningColor: PdfColor.fromInt(0xFFF59E0B),
    errorColor: PdfColor.fromInt(0xFFEF4444),
  );

  // ========== CLINIC THEME (SKY BLUE) ==========
  static const InvoicePdfTheme clinicTheme = InvoicePdfTheme(
    primaryColor: PdfColor.fromInt(0xFF0EA5E9), // Sky 500
    primaryLight: PdfColor.fromInt(0xFFE0F2FE), // Sky 100
    primaryDark: PdfColor.fromInt(0xFF0369A1), // Sky 700
    accentColor: PdfColor.fromInt(0xFF38BDF8), // Sky 400
    textDark: PdfColor.fromInt(0xFF1F2937),
    textGray: PdfColor.fromInt(0xFF6B7280),
    borderColor: PdfColor.fromInt(0xFFE5E7EB),
    successColor: PdfColor.fromInt(0xFF22C55E),
    warningColor: PdfColor.fromInt(0xFFF59E0B),
    errorColor: PdfColor.fromInt(0xFFEF4444),
  );

  // ========== BOOK STORE THEME (AMBER/BROWN) ==========
  static const InvoicePdfTheme bookStoreTheme = InvoicePdfTheme(
    primaryColor: PdfColor.fromInt(0xFFD97706), // Amber 600
    primaryLight: PdfColor.fromInt(0xFFFEF3C7), // Amber 100
    primaryDark: PdfColor.fromInt(0xFFB45309), // Amber 700
    accentColor: PdfColor.fromInt(0xFFF59E0B), // Amber 500
    textDark: PdfColor.fromInt(0xFF1F2937),
    textGray: PdfColor.fromInt(0xFF6B7280),
    borderColor: PdfColor.fromInt(0xFFE5E7EB),
    successColor: PdfColor.fromInt(0xFF22C55E),
    warningColor: PdfColor.fromInt(0xFFF59E0B),
    errorColor: PdfColor.fromInt(0xFFEF4444),
  );

  // ========== JEWELLERY THEME (GOLD/YELLOW) ==========
  static const InvoicePdfTheme jewelleryTheme = InvoicePdfTheme(
    primaryColor: PdfColor.fromInt(0xFFEAB308), // Yellow 500
    primaryLight: PdfColor.fromInt(0xFFFEF9C3), // Yellow 100
    primaryDark: PdfColor.fromInt(0xFFA16207), // Yellow 700
    accentColor: PdfColor.fromInt(0xFFFACC15), // Yellow 400
    textDark: PdfColor.fromInt(0xFF1F2937),
    textGray: PdfColor.fromInt(0xFF6B7280),
    borderColor: PdfColor.fromInt(0xFFE5E7EB),
    successColor: PdfColor.fromInt(0xFF22C55E),
    warningColor: PdfColor.fromInt(0xFFF59E0B),
    errorColor: PdfColor.fromInt(0xFFEF4444),
  );

  // ========== AUTO PARTS THEME (SLATE) ==========
  static const InvoicePdfTheme autoPartsTheme = InvoicePdfTheme(
    primaryColor: PdfColor.fromInt(0xFF475569), // Slate 600
    primaryLight: PdfColor.fromInt(0xFFF1F5F9), // Slate 100
    primaryDark: PdfColor.fromInt(0xFF334155), // Slate 700
    accentColor: PdfColor.fromInt(0xFF64748B), // Slate 500
    textDark: PdfColor.fromInt(0xFF1F2937),
    textGray: PdfColor.fromInt(0xFF6B7280),
    borderColor: PdfColor.fromInt(0xFFE5E7EB),
    successColor: PdfColor.fromInt(0xFF22C55E),
    warningColor: PdfColor.fromInt(0xFFF59E0B),
    errorColor: PdfColor.fromInt(0xFFEF4444),
  );

  // ========== DECORATION CATERING THEME (ROSE) ==========
  static const InvoicePdfTheme decorationCateringTheme = InvoicePdfTheme(
    primaryColor: PdfColor.fromInt(0xFFF43F5E), // Rose 500
    primaryLight: PdfColor.fromInt(0xFFFFE4E6), // Rose 100
    primaryDark: PdfColor.fromInt(0xFFBE123C), // Rose 700
    accentColor: PdfColor.fromInt(0xFFFB7185), // Rose 400
    textDark: PdfColor.fromInt(0xFF1F2937),
    textGray: PdfColor.fromInt(0xFF6B7280),
    borderColor: PdfColor.fromInt(0xFFE5E7EB),
    successColor: PdfColor.fromInt(0xFF22C55E),
    warningColor: PdfColor.fromInt(0xFFF59E0B),
    errorColor: PdfColor.fromInt(0xFFEF4444),
  );

  // ========== SCHOOL ERP THEME (INDIGO) ==========
  static const InvoicePdfTheme schoolErpTheme = InvoicePdfTheme(
    primaryColor: PdfColor.fromInt(0xFF4F46E5), // Indigo 600
    primaryLight: PdfColor.fromInt(0xFFE0E7FF), // Indigo 100
    primaryDark: PdfColor.fromInt(0xFF3730A3), // Indigo 800
    accentColor: PdfColor.fromInt(0xFF6366F1), // Indigo 500
    textDark: PdfColor.fromInt(0xFF1F2937),
    textGray: PdfColor.fromInt(0xFF6B7280),
    borderColor: PdfColor.fromInt(0xFFE5E7EB),
    successColor: PdfColor.fromInt(0xFF22C55E),
    warningColor: PdfColor.fromInt(0xFFF59E0B),
    errorColor: PdfColor.fromInt(0xFFEF4444),
  );

  /// Default theme (Blue - Professional)
  static const InvoicePdfTheme defaultTheme = pharmacyTheme;
}

/// Invoice status for visual indicators
enum InvoiceStatus { paid, unpaid, partial }

/// Payment mode for display
enum PaymentMode { cash, upi, card, credit, mixed }

/// Extension to get display text and colors for status
extension InvoiceStatusExtension on InvoiceStatus {
  String get displayText {
    switch (this) {
      case InvoiceStatus.paid:
        return 'PAID';
      case InvoiceStatus.unpaid:
        return 'UNPAID';
      case InvoiceStatus.partial:
        return 'PARTIAL';
    }
  }

  PdfColor getColor(InvoicePdfTheme theme) {
    switch (this) {
      case InvoiceStatus.paid:
        return theme.successColor;
      case InvoiceStatus.unpaid:
        return theme.errorColor;
      case InvoiceStatus.partial:
        return theme.warningColor;
    }
  }
}

/// Extension to get display text for payment mode
extension PaymentModeExtension on PaymentMode {
  String get displayText {
    switch (this) {
      case PaymentMode.cash:
        return 'Cash';
      case PaymentMode.upi:
        return 'UPI';
      case PaymentMode.card:
        return 'Card';
      case PaymentMode.credit:
        return 'Credit';
      case PaymentMode.mixed:
        return 'Mixed';
    }
  }
}
