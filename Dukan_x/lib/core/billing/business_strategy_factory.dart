import 'business_type_config.dart';
import 'strategies/business_strategy.dart';
import 'strategies/general_store_strategy.dart';
import 'strategies/pharmacy_strategy.dart';
import 'strategies/restaurant_strategy.dart';
import 'strategies/clothing_strategy.dart';
import 'strategies/electronics_strategy.dart';
import 'strategies/hardware_strategy.dart';
import 'strategies/service_strategy.dart';
import 'strategies/petrol_pump_strategy.dart';
import 'strategies/book_store_strategy.dart';
import 'strategies/jewellery_strategy.dart';
import 'strategies/auto_parts_strategy.dart';

class BusinessStrategyFactory {
  // Singleton instances to avoid recreation
  static final _general = GeneralStoreStrategy();
  static final _pharmacy = PharmacyStrategy();
  static final _restaurant = RestaurantStrategy();
  static final _clothing = ClothingStrategy();
  static final _electronics = ElectronicsStrategy();
  static final _hardware = HardwareStrategy();
  static final _service = ServiceStrategy();
  static final _petrolPump = PetrolPumpStrategy();
  static final _bookStore = BookStoreStrategy();
  static final _jewellery = JewelleryStrategy();
  static final _autoParts = AutoPartsStrategy();

  static BusinessStrategy getStrategy(BusinessType type) {
    switch (type) {
      case BusinessType.grocery:
        return _general;
      case BusinessType.pharmacy:
        return _pharmacy;
      case BusinessType.restaurant:
        return _restaurant;
      case BusinessType.clothing:
        return _clothing;
      case BusinessType.electronics:
        return _electronics;
      case BusinessType.hardware:
        return _hardware;
      case BusinessType.service:
        return _service;
      case BusinessType.petrolPump:
        return _petrolPump;
      case BusinessType.mobileShop:
        return _electronics;
      case BusinessType.computerShop:
        return _electronics;
      case BusinessType.vegetablesBroker:
        return _general;
      case BusinessType.other:
        return _general;
      case BusinessType.clinic:
        return _pharmacy; // Reusing pharmacy strategy lightly or need dedicated? Using Pharmacy for now as nearest relative (Prescriptions)
      case BusinessType.wholesale:
        return _general;
      case BusinessType.bookStore:
        return _bookStore;
      case BusinessType.jewellery:
        return _jewellery;
      case BusinessType.autoParts:
        return _autoParts;
      case BusinessType.decorationCatering:
        return _service;
      case BusinessType.schoolErp:
        return _general;
    }
  }
}
