/// MobileShop BusinessType — Enum with Wire Normalization (Dart)
///
/// Provides canonical business-type representation for the MobileShop domain.
/// All wire aliases are normalized to a single canonical value.
///
/// Requirements: 2.1–2.4, 6.18
library;

/// Canonical business types supported in the Dukan ecosystem.
///
/// Each variant maps to one canonical wire value used in API requests,
/// DynamoDB keys, and persistence. Wire aliases are normalized at boundaries.
enum MobileShopBusinessType {
  mobileShop,
  grocery,
  electronics,
  pharmacy,
  restaurant,
  clothing,
  computerShop,
  hardware,
  service,
  wholesale,
  petrolPump,
  vegetablesBroker,
  clinic,
  bookStore,
  jewellery,
  autoParts,
  decorationCatering,
  schoolErp,
  other;

  /// Canonical wire value for API/persistence boundaries.
  String get toWireValue {
    switch (this) {
      case MobileShopBusinessType.mobileShop:
        return 'mobile_shop';
      case MobileShopBusinessType.grocery:
        return 'grocery';
      case MobileShopBusinessType.electronics:
        return 'electronics';
      case MobileShopBusinessType.pharmacy:
        return 'pharmacy';
      case MobileShopBusinessType.restaurant:
        return 'restaurant';
      case MobileShopBusinessType.clothing:
        return 'clothing';
      case MobileShopBusinessType.computerShop:
        return 'computer_shop';
      case MobileShopBusinessType.hardware:
        return 'hardware';
      case MobileShopBusinessType.service:
        return 'service';
      case MobileShopBusinessType.wholesale:
        return 'wholesale';
      case MobileShopBusinessType.petrolPump:
        return 'petrol_pump';
      case MobileShopBusinessType.vegetablesBroker:
        return 'vegetables_broker';
      case MobileShopBusinessType.clinic:
        return 'clinic';
      case MobileShopBusinessType.bookStore:
        return 'book_store';
      case MobileShopBusinessType.jewellery:
        return 'jewellery';
      case MobileShopBusinessType.autoParts:
        return 'auto_parts';
      case MobileShopBusinessType.decorationCatering:
        return 'decoration_catering';
      case MobileShopBusinessType.schoolErp:
        return 'school_erp';
      case MobileShopBusinessType.other:
        return 'other';
    }
  }

  /// Whether this business type represents a mobile shop.
  bool get isMobileShop => this == MobileShopBusinessType.mobileShop;

  /// Resolves a wire/stored value to the canonical enum variant.
  ///
  /// Normalizes known mobile-shop aliases (`mobileShop`, `mobileshop`,
  /// `mobile_shop`, `MobileShop`, `MOBILESHOP`, `MOBILE_SHOP`) to
  /// [MobileShopBusinessType.mobileShop].
  ///
  /// Returns [MobileShopBusinessType.other] for unrecognized values.
  static MobileShopBusinessType fromWireValue(String raw) {
    final normalized = raw.trim().toLowerCase();

    // Mobile shop alias normalization
    if (normalized == 'mobileshop' || normalized == 'mobile_shop') {
      return MobileShopBusinessType.mobileShop;
    }

    // Standard lookups
    switch (normalized) {
      case 'grocery':
        return MobileShopBusinessType.grocery;
      case 'electronics':
        return MobileShopBusinessType.electronics;
      case 'pharmacy':
        return MobileShopBusinessType.pharmacy;
      case 'restaurant':
        return MobileShopBusinessType.restaurant;
      case 'clothing':
        return MobileShopBusinessType.clothing;
      case 'computershop':
      case 'computer_shop':
        return MobileShopBusinessType.computerShop;
      case 'hardware':
        return MobileShopBusinessType.hardware;
      case 'service':
        return MobileShopBusinessType.service;
      case 'wholesale':
        return MobileShopBusinessType.wholesale;
      case 'petrolpump':
      case 'petrol_pump':
        return MobileShopBusinessType.petrolPump;
      case 'vegetablesbroker':
      case 'vegetables_broker':
        return MobileShopBusinessType.vegetablesBroker;
      case 'clinic':
        return MobileShopBusinessType.clinic;
      case 'bookstore':
      case 'book_store':
        return MobileShopBusinessType.bookStore;
      case 'jewellery':
        return MobileShopBusinessType.jewellery;
      case 'autoparts':
      case 'auto_parts':
        return MobileShopBusinessType.autoParts;
      case 'decorationcatering':
      case 'decoration_catering':
        return MobileShopBusinessType.decorationCatering;
      case 'schoolerp':
      case 'school_erp':
        return MobileShopBusinessType.schoolErp;
      default:
        return MobileShopBusinessType.other;
    }
  }
}
