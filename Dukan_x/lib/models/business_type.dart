import 'package:flutter/material.dart';

enum BusinessType {
  grocery,
  pharmacy,
  restaurant,
  clothing,
  electronics,
  mobileShop, // New: Specialized mobile phone shop
  computerShop, // New: Specialized computer shop
  hardware,
  service,
  wholesale,
  petrolPump,
  vegetablesBroker, // 🥦 Mandi / Vegetable Broker
  clinic, // 👨‍⚕️ Clinic / Doctor Practice
  bookStore, // 📚 Book Store
  jewellery, // 💍 Jewellery Shop
  autoParts, // 🔧 Auto Parts Shop
  decorationCatering, // 🎪 Decoration & Catering
  schoolErp, // 🏫 School ERP
  other,
}

extension BusinessTypeExtension on BusinessType {
  String get displayName {
    switch (this) {
      case BusinessType.grocery:
        return 'Grocery Store';
      case BusinessType.pharmacy:
        return 'Medical / Pharmacy';
      case BusinessType.restaurant:
        return 'Restaurant / Hotel';
      case BusinessType.clothing:
        return 'Clothing / Fashion';
      case BusinessType.electronics:
        return 'Mobile / Electronics';
      case BusinessType.mobileShop:
        return 'Mobile Phone Shop';
      case BusinessType.computerShop:
        return 'Computer Shop';
      case BusinessType.hardware:
        return 'Hardware Store';
      case BusinessType.service:
        return 'Service Business';
      case BusinessType.wholesale:
        return 'Wholesale';
      case BusinessType.petrolPump:
        return 'Petrol Pump';
      case BusinessType.vegetablesBroker:
        return 'Vegetable Broker / Mandi';
      case BusinessType.clinic:
        return 'Doctor Clinic / OPD';
      case BusinessType.bookStore:
        return 'Book Store';
      case BusinessType.jewellery:
        return 'Jewellery Shop';
      case BusinessType.autoParts:
        return 'Auto Parts';
      case BusinessType.decorationCatering:
        return 'Decoration & Catering';
      case BusinessType.schoolErp:
        return 'School ERP';
      case BusinessType.other:
        return 'Other / General';
    }
  }

  IconData get icon {
    switch (this) {
      case BusinessType.grocery:
        return Icons.shopping_basket_rounded;
      case BusinessType.pharmacy:
        return Icons.medical_services_rounded;
      case BusinessType.restaurant:
        return Icons.restaurant_rounded;
      case BusinessType.clothing:
        return Icons.checkroom_rounded;
      case BusinessType.electronics:
        return Icons.phone_android_rounded;
      case BusinessType.mobileShop:
        return Icons.smartphone_rounded;
      case BusinessType.computerShop:
        return Icons.computer_rounded;
      case BusinessType.hardware:
        return Icons.hardware_rounded;
      case BusinessType.service:
        return Icons.miscellaneous_services_rounded;
      case BusinessType.wholesale:
        return Icons.inventory_2_rounded;
      case BusinessType.petrolPump:
        return Icons.local_gas_station_rounded;
      case BusinessType.vegetablesBroker:
        return Icons.agriculture_rounded;
      case BusinessType.clinic:
        return Icons.local_hospital_rounded;
      case BusinessType.bookStore:
        return Icons.menu_book_rounded;
      case BusinessType.jewellery:
        return Icons.diamond_rounded;
      case BusinessType.autoParts:
        return Icons.build_rounded;
      case BusinessType.decorationCatering:
        return Icons.celebration_rounded;
      case BusinessType.schoolErp:
        return Icons.school_rounded;
      case BusinessType.other:
        return Icons.store_rounded;
    }
  }

  // ============================================================
  // DEPRECATED HELPERS REMOVED
  // Use BusinessTypeRegistry.getConfig(type) instead.
  // ============================================================
}
