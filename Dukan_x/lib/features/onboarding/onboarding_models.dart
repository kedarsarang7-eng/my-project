// Onboarding Models
// Models for onboarding slides and content
//
// Created: 2024-12-25
// Author: DukanX Team

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/di/service_locator.dart';
import '../../core/session/session_manager.dart';
import '../../core/repository/shop_repository.dart';
import '../../core/repository/onboarding_repository.dart';

/// Language options
enum AppLanguage {
  english,
  hindi,
  marathi,
  tamil,
  telugu,
  kannada,
  malayalam,
  bengali,
  gujarati,
  punjabi,
  urdu,
}

/// Business type configuration
class BusinessTypeConfig {
  final BusinessType type;
  final String name;
  final String description;
  final String emoji;
  final Color primaryColor;
  final Color secondaryColor;
  final List<String> billColumns;
  final IconData icon;
  final String assetImage;

  const BusinessTypeConfig({
    required this.type,
    required this.name,
    required this.description,
    required this.emoji,
    required this.primaryColor,
    required this.secondaryColor,
    required this.billColumns,
    required this.icon,
    required this.assetImage,
  });

  static List<BusinessTypeConfig> get all => [
    BusinessTypeConfig(
      type: BusinessType.grocery,
      name: 'Grocery Store',
      description: 'Fruits, vegetables, daily essentials',
      emoji: 'ðŸ›’',
      primaryColor: const Color(0xFF4CAF50),
      secondaryColor: const Color(0xFFE8F5E9),
      billColumns: ['Item Name', 'Qty', 'Rate', 'Discount', 'Total'],
      icon: Icons.shopping_basket_rounded,
      assetImage: 'assets/images/onboarding/grocery_store.jpg',
    ),
    BusinessTypeConfig(
      type: BusinessType.pharmacy,
      name: 'Medical / Pharmacy',
      description: 'Medicines, healthcare products',
      emoji: 'ðŸ’Š',
      primaryColor: const Color(0xFF2196F3),
      secondaryColor: const Color(0xFFE3F2FD),
      billColumns: ['Medicine', 'Batch No', 'Expiry', 'Qty', 'MRP', 'Total'],
      icon: Icons.medical_services_rounded,
      assetImage: 'assets/images/onboarding/pharmacy.jpg',
    ),
    BusinessTypeConfig(
      type: BusinessType.restaurant,
      name: 'Restaurant / Hotel',
      description: 'Food, beverages, hospitality',
      emoji: 'ðŸ½ï¸',
      primaryColor: const Color(0xFFFF5722),
      secondaryColor: const Color(0xFFFBE9E7),
      billColumns: ['Table', 'Item', 'Qty', 'Price', 'GST', 'Total'],
      icon: Icons.restaurant_rounded,
      assetImage: 'assets/images/onboarding/restaurant.jpg',
    ),
    BusinessTypeConfig(
      type: BusinessType.clothing,
      name: 'Clothing / Fashion',
      description: 'Apparel, accessories, footwear',
      emoji: 'ðŸ‘•',
      primaryColor: const Color(0xFF9C27B0),
      secondaryColor: const Color(0xFFF3E5F5),
      billColumns: [
        'Item',
        'Size',
        'Color',
        'Qty',
        'Price',
        'Discount',
        'Total',
      ],
      icon: Icons.checkroom_rounded,
      assetImage: 'assets/images/onboarding/clothing_store.jpg',
    ),
    BusinessTypeConfig(
      type: BusinessType.electronics,
      name: 'Mobile / Electronics',
      description: 'Phones, gadgets, accessories',
      emoji: 'ðŸ“±',
      primaryColor: const Color(0xFF607D8B),
      secondaryColor: const Color(0xFFECEFF1),
      billColumns: [
        'Product',
        'IMEI/Serial',
        'Warranty',
        'Qty',
        'Price',
        'Total',
      ],
      icon: Icons.phone_android_rounded,
      assetImage: 'assets/images/onboarding/mobile_shop.jpg',
    ),
    BusinessTypeConfig(
      type: BusinessType.hardware,
      name: 'Hardware Store',
      description: 'Tools, building materials',
      emoji: 'ðŸ”§',
      primaryColor: const Color(0xFF795548),
      secondaryColor: const Color(0xFFEFEBE9),
      billColumns: ['Item', 'Brand', 'Qty', 'Unit', 'Rate', 'Total'],
      icon: Icons.hardware_rounded,
      assetImage: 'assets/images/onboarding/hardware_store.jpg',
    ),
    BusinessTypeConfig(
      type: BusinessType.service,
      name: 'Service Business',
      description: 'Salon, repair, consulting',
      emoji: 'ðŸ’ˆ',
      primaryColor: const Color(0xFF00BCD4),
      secondaryColor: const Color(0xFFE0F7FA),
      billColumns: ['Service', 'Duration', 'Rate', 'Notes', 'Total'],
      icon: Icons.miscellaneous_services_rounded,
      assetImage: 'assets/images/onboarding/service_business.jpg',
    ),
    BusinessTypeConfig(
      type: BusinessType.mobileShop,
      name: 'Mobile Shop',
      description: 'Smartphones, repairs, accessories',
      emoji: 'ðŸ“±',
      primaryColor: const Color(0xFF3F51B5),
      secondaryColor: const Color(0xFFC5CAE9),
      billColumns: ['Model', 'IMEI', 'Qty', 'Rate', 'Total'],
      icon: Icons.smartphone_rounded,
      assetImage: 'assets/images/onboarding/mobile_shop.jpg',
    ),
    BusinessTypeConfig(
      type: BusinessType.computerShop,
      name: 'Computer & IT',
      description: 'Laptops, parts, repairs',
      emoji: 'ðŸ’»',
      primaryColor: const Color(0xFF673AB7),
      secondaryColor: const Color(0xFFD1C4E9),
      billColumns: ['Product', 'Serial No', 'Qty', 'Rate', 'Total'],
      icon: Icons.computer_rounded,
      assetImage: 'assets/images/onboarding/electronics.jpg',
    ),
    BusinessTypeConfig(
      type: BusinessType.wholesale,
      name: 'Wholesale / Distributor',
      description: 'Bulk supply, B2B trading',
      emoji: 'ðŸ“¦',
      primaryColor: const Color(0xFF795548),
      secondaryColor: const Color(0xFFD7CCC8),
      billColumns: ['Item', 'Pack Size', 'Qty', 'Rate', 'Total'],
      icon: Icons.inventory_2_rounded,
      assetImage: 'assets/images/onboarding/warehouse.jpg',
    ),
    BusinessTypeConfig(
      type: BusinessType.petrolPump,
      name: 'Petrol Pump',
      description: 'Fuel station management',
      emoji: 'â›½',
      primaryColor: const Color(0xFFD32F2F),
      secondaryColor: const Color(0xFFFFCDD2),
      billColumns: ['Fuel', 'Nozzle', 'Liters', 'Rate', 'Total'],
      icon: Icons.local_gas_station_rounded,
      assetImage: 'assets/images/onboarding/petrol_pump.jpg',
    ),
    BusinessTypeConfig(
      type: BusinessType.vegetablesBroker,
      name: 'Mandi / Veg Broker',
      description: 'Vegetable commission agent',
      emoji: 'ðŸ¥¦',
      primaryColor: const Color(0xFF2E7D32),
      secondaryColor: const Color(0xFFC8E6C9),
      billColumns: ['Farmer', 'Item', 'Weight', 'Rate', 'Total'],
      icon: Icons.agriculture_rounded,
      assetImage: 'assets/images/onboarding/vegetables.jpg',
    ),
    BusinessTypeConfig(
      type: BusinessType.clinic,
      name: 'Doctor Clinic / OPD',
      description: 'Patient prescriptions & billing',
      emoji: 'ðŸ‘¨â€âš•ï¸',
      primaryColor: const Color(0xFF009688),
      secondaryColor: const Color(0xFFB2DFDB),
      billColumns: ['Service', 'Medicine', 'Dosage', 'Fees', 'Total'],
      icon: Icons.local_hospital_rounded,
      assetImage: 'assets/images/onboarding/clinic.jpg',
    ),
    BusinessTypeConfig(
      type: BusinessType.other,
      name: 'Other / General',
      description: 'Multi-category business',
      emoji: 'ðŸª',
      primaryColor: const Color(0xFF607D8B),
      secondaryColor: const Color(0xFFCFD8DC),
      billColumns: ['Item', 'Qty', 'Rate', 'Total'],
      icon: Icons.store_rounded,
      assetImage: 'assets/images/onboarding/general_store.jpg',
    ),
  ];

  static BusinessTypeConfig getConfig(BusinessType type) {
    return all.firstWhere((c) => c.type == type, orElse: () => all.last);
  }
}

/// Language configuration with native names
class LanguageConfig {
  final AppLanguage language;
  final String code;
  final String nativeName;
  final String englishName;
  final String flag;

  const LanguageConfig({
    required this.language,
    required this.code,
    required this.nativeName,
    required this.englishName,
    required this.flag,
  });

  static List<LanguageConfig> get all => [
    const LanguageConfig(
      language: AppLanguage.english,
      code: 'en',
      nativeName: 'English',
      englishName: 'English',
      flag: 'ðŸ‡ºðŸ‡¸',
    ),
    const LanguageConfig(
      language: AppLanguage.hindi,
      code: 'hi',
      nativeName: 'à¤¹à¤¿à¤‚à¤¦à¥€',
      englishName: 'Hindi',
      flag: 'ðŸ‡®ðŸ‡³',
    ),
    const LanguageConfig(
      language: AppLanguage.marathi,
      code: 'mr',
      nativeName: 'à¤®à¤°à¤¾à¤ à¥€',
      englishName: 'Marathi',
      flag: 'ðŸ‡®ðŸ‡³',
    ),
    const LanguageConfig(
      language: AppLanguage.tamil,
      code: 'ta',
      nativeName: 'à®¤à®®à®¿à®´à¯',
      englishName: 'Tamil',
      flag: 'ðŸ‡®ðŸ‡³',
    ),
    const LanguageConfig(
      language: AppLanguage.telugu,
      code: 'te',
      nativeName: 'à°¤à±†à°²à±à°—à±',
      englishName: 'Telugu',
      flag: 'ðŸ‡®ðŸ‡³',
    ),
    const LanguageConfig(
      language: AppLanguage.kannada,
      code: 'kn',
      nativeName: 'à²•à²¨à³à²¨à²¡',
      englishName: 'Kannada',
      flag: 'ðŸ‡®ðŸ‡³',
    ),
    const LanguageConfig(
      language: AppLanguage.malayalam,
      code: 'ml',
      nativeName: 'à´®à´²à´¯à´¾à´³à´‚',
      englishName: 'Malayalam',
      flag: 'ðŸ‡®ðŸ‡³',
    ),
    const LanguageConfig(
      language: AppLanguage.bengali,
      code: 'bn',
      nativeName: 'à¦¬à¦¾à¦‚à¦²à¦¾',
      englishName: 'Bengali',
      flag: 'ðŸ‡®ðŸ‡³',
    ),
    const LanguageConfig(
      language: AppLanguage.gujarati,
      code: 'gu',
      nativeName: 'àª—à«àªœàª°àª¾àª¤à«€',
      englishName: 'Gujarati',
      flag: 'ðŸ‡®ðŸ‡³',
    ),
    const LanguageConfig(
      language: AppLanguage.punjabi,
      code: 'pa',
      nativeName: 'à¨ªà©°à¨œà¨¾à¨¬à©€',
      englishName: 'Punjabi',
      flag: 'ðŸ‡®ðŸ‡³',
    ),
    const LanguageConfig(
      language: AppLanguage.urdu,
      code: 'ur',
      nativeName: 'Ø§Ø±Ø¯Ùˆ',
      englishName: 'Urdu',
      flag: 'ðŸ‡µðŸ‡°',
    ),
  ];
}

/// Onboarding Service - Manages onboarding state and data
///
/// ARCHITECTURE: Firestore-first approach
/// - Firestore is the SOURCE OF TRUTH for onboarding status
/// - SharedPreferences is only a local cache for offline fallback
/// - OnboardingRepository handles the Firestore-first logic
class OnboardingService {
  static final OnboardingService _instance = OnboardingService._internal();
  factory OnboardingService() => _instance;
  OnboardingService._internal();

  // Keys for SharedPreferences (LOCAL CACHE ONLY)
  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _businessTypeKey = 'business_type';
  static const String _appLanguageKey = 'app_language';

  // Cache to prevent race conditions during session
  bool? _inMemoryCache;

  /// Check if onboarding is completed
  ///
  /// CRITICAL: Uses Hybrid approach
  /// 1. Checks memory cache first (instant)
  /// 2. Checks Firestore via Repository
  /// 3. Checks SharedPreferences
  /// If ANY source says true, we consider it completed and update others if possible.
  Future<bool> isOnboardingCompleted() async {
    // 1. Memory Cache
    if (_inMemoryCache == true) return true;

    final ownerId = sl<SessionManager>().ownerId;
    if (ownerId == null || ownerId.isEmpty) {
      return false;
    }

    bool isCompleted = false;

    // 2. Repository Check (Firestore)
    try {
      isCompleted = await sl<OnboardingRepository>().hasCompletedOnboarding(
        ownerId,
      );
    } catch (e) {
      debugPrint('[OnboardingService] Repository check failed: $e');
    }

    // 3. Fallback/Hybrid Check (SharedPreferences)
    // If repository said NO, we still check prefs because we might have just completed it locally
    if (!isCompleted) {
      final prefs = await SharedPreferences.getInstance();
      isCompleted = prefs.getBool(_onboardingCompletedKey) ?? false;
    }

    // Update memory cache if found true
    if (isCompleted) {
      _inMemoryCache = true;
    }

    return isCompleted;
  }

  /// Mark onboarding as completed
  ///
  /// Persists to BOTH Firestore (via repository) and SharedPreferences (cache)
  Future<void> completeOnboarding() async {
    // Get current business type for completion payload
    final prefs = await SharedPreferences.getInstance();
    final businessType = prefs.getString(_businessTypeKey) ?? 'other';

    // Primary: Save via OnboardingRepository (Firestore + local DB)
    try {
      final ownerId = sl<SessionManager>().ownerId;
      if (ownerId != null && ownerId.isNotEmpty) {
        final result = await sl<OnboardingRepository>().completeOnboarding(
          userId: ownerId,
          businessType: businessType,
        );

        if (result.isSuccess) {
          debugPrint('[OnboardingService] Onboarding completed via repository');
        } else {
          debugPrint(
            '[OnboardingService] Repository completion failed: ${result.errorMessage}',
          );
        }
      }
    } catch (e) {
      debugPrint('[OnboardingService] Error completing onboarding: $e');
    }

    // Secondary: Also cache in SharedPreferences for quick offline checks
    await prefs.setBool(_onboardingCompletedKey, true);
    // Update memory cache
    _inMemoryCache = true;
  }

  /// Save business type selection
  Future<void> saveBusinessType(BusinessType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_businessTypeKey, type.name);

    final ownerId = sl<SessionManager>().ownerId;
    if (ownerId != null) {
      await sl<ShopRepository>().saveBusinessType(ownerId, type.name);
    }
  }

  /// Get saved business type
  Future<BusinessType> getBusinessType() async {
    final prefs = await SharedPreferences.getInstance();
    final typeName = prefs.getString(_businessTypeKey);
    if (typeName == null) {
      return BusinessType.other;
    }

    // Handle legacy enum names
    switch (typeName) {
      case 'groceryStore':
        return BusinessType.grocery;
      case 'medicalPharmacy':
        return BusinessType.pharmacy;
      case 'restaurantHotel':
        return BusinessType.restaurant;
      case 'clothingFashion':
        return BusinessType.clothing;
      case 'mobileElectronics':
        return BusinessType.electronics;
      case 'serviceBusiness':
        return BusinessType.service;
      case 'grocery':
        return BusinessType.other;
      default:
        // Try to match exact name (for new types or already migrated)
        try {
          return BusinessType.values.byName(typeName);
        } catch (_) {
          return BusinessType.other;
        }
    }
  }

  /// Save language selection
  Future<void> saveLanguage(AppLanguage language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appLanguageKey, language.name);

    final ownerId = sl<SessionManager>().ownerId;
    if (ownerId != null) {
      final config = LanguageConfig.all.firstWhere(
        (l) => l.language == language,
      );
      await sl<ShopRepository>().saveLanguage(
        ownerId,
        language.name,
        config.code,
      );
    }
  }

  /// Get saved language
  Future<AppLanguage> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final langName = prefs.getString(_appLanguageKey);
    if (langName == null) {
      return AppLanguage.english;
    }
    return AppLanguage.values.firstWhere(
      (l) => l.name == langName,
      orElse: () => AppLanguage.english,
    );
  }

  /// Check if business type is PERMANENTLY LOCKED
  Future<bool> isBusinessTypeLocked() async {
    final ownerId = sl<SessionManager>().ownerId;
    if (ownerId == null || ownerId.isEmpty) {
      return false;
    }

    try {
      return await sl<OnboardingRepository>().isBusinessTypeLocked(ownerId);
    } catch (e) {
      debugPrint('[OnboardingService] Lock check failed: $e');
      return false; // Fail safe to open, or should we fail safe to locked?
      // Failsafe to unlocked allows user to fix things if DB is down,
      // provided backend guards are in place.
    }
  }
}
