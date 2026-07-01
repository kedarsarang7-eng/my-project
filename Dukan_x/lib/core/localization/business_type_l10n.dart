// =============================================================================
// BusinessTypeL10n â€” Localized display names for all 19 business types
// =============================================================================
// Maps BusinessType enum â†’ translated display string via AppLocalizations.
//
// Key design decisions:
//   1. Internal enum values are language-neutral identifiers (snake_case).
//   2. Display strings come entirely from ARB â€” zero hardcoded English fallback.
//   3. Extensions keep calling code clean: businessType.localizedName(context)
//
// Usage:
//   Text(context.businessType.localizedName(context))
//   Text(BusinessTypeL10n.name(BusinessType.grocery, context))
// =============================================================================

import 'package:flutter/material.dart';
import '../../generated/app_localizations.dart';
import '../../models/business_type.dart';

extension BusinessTypeL10nExtension on BusinessType {
  /// Localized display name from ARB translations
  String localizedName(BuildContext context) =>
      BusinessTypeL10n.name(this, context);

  /// Localized description (short) for onboarding screen
  String localizedDescription(BuildContext context) =>
      BusinessTypeL10n.description(this, context);
}

class BusinessTypeL10n {
  BusinessTypeL10n._();

  /// Returns localized display name for the given BusinessType.
  /// Uses AppLocalizations ARB keys with English fallback.
  static String name(BusinessType type, BuildContext context) {
    final l = AppLocalizations.of(context);
    if (l == null) return _englishFallback(type);
    switch (type) {
      case BusinessType.grocery:
        return l.businessTypeGrocery;
      case BusinessType.pharmacy:
        return l.businessTypePharmacy;
      case BusinessType.restaurant:
        return l.businessTypeRestaurant;
      case BusinessType.clothing:
        return l.businessTypeClothing;
      case BusinessType.electronics:
        return l.businessTypeElectronics;
      case BusinessType.mobileShop:
        return l.businessTypeMobileShop;
      case BusinessType.computerShop:
        return l.businessTypeComputerShop;
      case BusinessType.hardware:
        return l.businessTypeHardware;
      case BusinessType.service:
        return l.businessTypeService;
      case BusinessType.wholesale:
        return l.businessTypeWholesale;
      case BusinessType.petrolPump:
        return l.businessTypePetrolPump;
      case BusinessType.vegetablesBroker:
        return l.businessTypeVegetablesBroker;
      case BusinessType.clinic:
        return l.businessTypeClinic;
      case BusinessType.bookStore:
        return l.businessTypeBookStore;
      case BusinessType.jewellery:
        return l.businessTypeJewellery;
      case BusinessType.autoParts:
        return l.businessTypeAutoParts;
      case BusinessType.decorationCatering:
        return l.businessTypeDecorationCatering;
      case BusinessType.schoolErp:
        return l.businessTypeSchoolErp;
      case BusinessType.other:
        return l.businessTypeOther;
    }
  }

  /// English fallback when AppLocalizations is not available (e.g. in tests
  /// or before localization delegate initializes).
  static String _englishFallback(BusinessType type) {
    switch (type) {
      case BusinessType.grocery:
        return 'Grocery';
      case BusinessType.pharmacy:
        return 'Pharmacy';
      case BusinessType.restaurant:
        return 'Restaurant';
      case BusinessType.clothing:
        return 'Clothing';
      case BusinessType.electronics:
        return 'Electronics';
      case BusinessType.mobileShop:
        return 'Mobile Shop';
      case BusinessType.computerShop:
        return 'Computer Shop';
      case BusinessType.hardware:
        return 'Hardware';
      case BusinessType.service:
        return 'Service';
      case BusinessType.wholesale:
        return 'Wholesale';
      case BusinessType.petrolPump:
        return 'Petrol Pump';
      case BusinessType.vegetablesBroker:
        return 'Vegetables Broker';
      case BusinessType.clinic:
        return 'Clinic';
      case BusinessType.bookStore:
        return 'Book Store';
      case BusinessType.jewellery:
        return 'Jewellery';
      case BusinessType.autoParts:
        return 'Auto Parts';
      case BusinessType.decorationCatering:
        return 'Decoration & Catering';
      case BusinessType.schoolErp:
        return 'School ERP';
      case BusinessType.other:
        return 'Other';
    }
  }

  /// Business-type specific description shown during onboarding.
  /// Hybrid strategy: technical terms stay in English (GST, UPI, KOT).
  /// Natural language wrapper is translated.
  static String description(BusinessType type, BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final langCode = Localizations.localeOf(context).languageCode;

    // For major Indian languages, return localized short descriptions
    // Technical acronyms (GST, UPI, KOT, IMEI) are intentionally kept in
    // English across all locales â€” this is standard Indian enterprise UX.
    switch (type) {
      case BusinessType.grocery:
        return _localizedDesc(
          langCode,
          en: 'Billing, inventory & customer ledger',
          hi: 'à¤¬à¤¿à¤²à¤¿à¤‚à¤—, à¤¸à¥à¤Ÿà¥‰à¤• à¤”à¤° à¤–à¤¾à¤¤à¤¾-à¤¬à¤¹à¥€',
          mr: 'à¤¬à¤¿à¤²à¤¿à¤‚à¤—, à¤¸à¤¾à¤ à¤¾ à¤†à¤£à¤¿ à¤–à¤¾à¤¤à¤¾-à¤µà¤¹à¥€',
        );
      case BusinessType.pharmacy:
        return _localizedDesc(
          langCode,
          en: 'Drug schedule, expiry tracking & GST',
          hi: 'à¤¦à¤µà¤¾ à¤…à¤¨à¥à¤¸à¥‚à¤šà¥€, à¤¸à¤®à¤¾à¤ªà¥à¤¤à¤¿ à¤Ÿà¥à¤°à¥ˆà¤•à¤¿à¤‚à¤— à¤”à¤° GST',
          mr: 'à¤”à¤·à¤§ à¤…à¤¨à¥à¤¸à¥‚à¤šà¥€, à¤¸à¤®à¤¾à¤ªà¥à¤¤à¥€ à¤Ÿà¥à¤°à¥…à¤•à¤¿à¤‚à¤— à¤†à¤£à¤¿ GST',
        );
      case BusinessType.restaurant:
        return _localizedDesc(
          langCode,
          en: 'KOT, table management & billing',
          hi: 'KOT, à¤Ÿà¥‡à¤¬à¤² à¤ªà¥à¤°à¤¬à¤‚à¤§à¤¨ à¤”à¤° à¤¬à¤¿à¤²à¤¿à¤‚à¤—',
          mr: 'KOT, à¤Ÿà¥‡à¤¬à¤² à¤µà¥à¤¯à¤µà¤¸à¥à¤¥à¤¾à¤ªà¤¨ à¤†à¤£à¤¿ à¤¬à¤¿à¤²à¤¿à¤‚à¤—',
        );
      case BusinessType.petrolPump:
        return _localizedDesc(
          langCode,
          en: 'Nozzle-wise sales, shift report & credit',
          hi: 'à¤¨à¥‹à¤œà¤¼à¤² à¤¬à¤¿à¤•à¥à¤°à¥€, à¤¶à¤¿à¤«à¥à¤Ÿ à¤°à¤¿à¤ªà¥‹à¤°à¥à¤Ÿ à¤”à¤° à¤‰à¤§à¤¾à¤°',
          mr: 'à¤¨à¥‹à¤à¤² à¤µà¤¿à¤•à¥à¤°à¥€, à¤¶à¤¿à¤«à¥à¤Ÿ à¤…à¤¹à¤µà¤¾à¤² à¤†à¤£à¤¿ à¤‰à¤§à¤¾à¤°',
        );
      case BusinessType.clinic:
        return _localizedDesc(
          langCode,
          en: 'Patient records, prescriptions & OPD',
          hi: 'à¤°à¥‹à¤—à¥€ à¤°à¤¿à¤•à¥‰à¤°à¥à¤¡, à¤ªà¤°à¥à¤šà¥‡ à¤”à¤° OPD',
          mr: 'à¤°à¥à¤—à¥à¤£ à¤¨à¥‹à¤‚à¤¦à¥€, à¤ªà¥à¤°à¤¿à¤¸à¥à¤•à¥à¤°à¤¿à¤ªà¥à¤¶à¤¨ à¤†à¤£à¤¿ OPD',
        );
      case BusinessType.jewellery:
        return _localizedDesc(
          langCode,
          en: 'Weight, purity, hallmark & GST 3%',
          hi: 'à¤µà¤œà¤¨, à¤¶à¥à¤¦à¥à¤§à¤¤à¤¾, à¤¹à¥‰à¤²à¤®à¤¾à¤°à¥à¤• à¤”à¤° 3% GST',
          mr: 'à¤µà¤œà¤¨, à¤¶à¥à¤¦à¥à¤§à¤¤à¤¾, à¤¹à¥‰à¤²à¤®à¤¾à¤°à¥à¤• à¤†à¤£à¤¿ 3% GST',
        );
      case BusinessType.wholesale:
        return _localizedDesc(
          langCode,
          en: 'Price tiers, bulk orders & distribution',
          hi: 'à¤®à¥‚à¤²à¥à¤¯ à¤¸à¥à¤¤à¤°, à¤¥à¥‹à¤• à¤‘à¤°à¥à¤¡à¤° à¤”à¤° à¤µà¤¿à¤¤à¤°à¤£',
          mr: 'à¤•à¤¿à¤‚à¤®à¤¤ à¤¸à¥à¤¤à¤°, à¤˜à¤¾à¤Šà¤• à¤‘à¤°à¥à¤¡à¤° à¤†à¤£à¤¿ à¤µà¤¿à¤¤à¤°à¤£',
        );
      case BusinessType.schoolErp:
        return _localizedDesc(
          langCode,
          en: 'Fees, attendance, results & staff',
          hi: 'à¤¶à¥à¤²à¥à¤•, à¤‰à¤ªà¤¸à¥à¤¥à¤¿à¤¤à¤¿, à¤ªà¤°à¤¿à¤£à¤¾à¤® à¤”à¤° à¤•à¤°à¥à¤®à¤šà¤¾à¤°à¥€',
          mr: 'à¤¶à¥à¤²à¥à¤•, à¤‰à¤ªà¤¸à¥à¤¥à¤¿à¤¤à¥€, à¤¨à¤¿à¤•à¤¾à¤² à¤†à¤£à¤¿ à¤•à¤°à¥à¤®à¤šà¤¾à¤°à¥€',
        );
      default:
        return 'Other';
    }
  }

  static String _localizedDesc(
    String langCode, {
    required String en,
    required String hi,
    required String mr,
  }) {
    switch (langCode) {
      case 'hi':
        return hi;
      case 'mr':
        return mr;
      default:
        return en;
    }
  }

  /// Sorted list of all BusinessTypes for display in UI.
  /// Primary (commonly used) types first, then others.
  static List<BusinessType> get priorityOrder => const [
    BusinessType.grocery,
    BusinessType.pharmacy,
    BusinessType.restaurant,
    BusinessType.clothing,
    BusinessType.hardware,
    BusinessType.mobileShop,
    BusinessType.computerShop,
    BusinessType.wholesale,
    BusinessType.petrolPump,
    BusinessType.jewellery,
    BusinessType.clinic,
    BusinessType.autoParts,
    BusinessType.bookStore,
    BusinessType.electronics,
    BusinessType.service,
    BusinessType.vegetablesBroker,
    BusinessType.decorationCatering,
    BusinessType.schoolErp,
    BusinessType.other,
  ];
}
