// ============================================================================
// BUSINESS TYPE VALIDATION HELPERS
// ============================================================================
// Provides consistent validation across business types for:
// - BUG-060: Staff management features per business type
// - BUG-061: IMEI vs Serial validation consistency
// - BUG-033: Data integrity checks

import '../../models/business_type.dart';

/// Business type capability checks (BUG-060 fix)
class BusinessTypeCapabilities {
  /// Check if staff management has full features (attendance, shifts, ID cards)
  static bool hasFullStaffManagement(BusinessType type) {
    switch (type) {
      case BusinessType.petrolPump:
        return true; // Full staff management
      case BusinessType.restaurant:
      case BusinessType.clinic:
      case BusinessType.pharmacy:
      case BusinessType.grocery:
      case BusinessType.hardware:
        return false; // Basic staff management only
      default:
        return false;
    }
  }
  
  /// Check if attendance tracking is available
  static bool hasAttendanceTracking(BusinessType type) {
    return hasFullStaffManagement(type);
  }
  
  /// Check if shift management is available
  static bool hasShiftManagement(BusinessType type) {
    return hasFullStaffManagement(type);
  }
  
  /// Check if ID card designer is available
  static bool hasIDCardDesigner(BusinessType type) {
    return hasFullStaffManagement(type);
  }
  
  /// Get description of available features
  static String getStaffFeaturesDescription(BusinessType type) {
    if (hasFullStaffManagement(type)) {
      return 'Full staff management with attendance, shifts, and ID cards';
    }
    return 'Basic staff management (add/edit/deactivate staff)';
  }
}

/// IMEI vs Serial validation (BUG-061 fix)
class DeviceIdentifierValidation {
  /// Validate IMEI (15 digits, Luhn check)
  static bool isValidIMEI(String imei) {
    if (imei.length != 15) return false;
    if (!RegExp(r'^\d{15}$').hasMatch(imei)) return false;
    
    // Luhn algorithm check
    return _luhnCheck(imei);
  }
  
  /// Validate Serial Number (alphanumeric, 6-30 chars)
  static bool isValidSerialNumber(String serial) {
    if (serial.length < 6 || serial.length > 30) return false;
    return RegExp(r'^[A-Za-z0-9-]+$').hasMatch(serial);
  }
  
  /// Generic device identifier validation based on business type
  static bool isValidDeviceId(String id, BusinessType businessType) {
    switch (businessType) {
      case BusinessType.mobileShop:
        return isValidIMEI(id);
      case BusinessType.computerShop:
      case BusinessType.electronics:
        return isValidSerialNumber(id);
      default:
        // For other business types, accept any non-empty string
        return id.isNotEmpty;
    }
  }
  
  /// Get expected identifier type for business
  static String getIdentifierType(BusinessType businessType) {
    switch (businessType) {
      case BusinessType.mobileShop:
        return 'IMEI';
      case BusinessType.computerShop:
        return 'Serial Number';
      case BusinessType.electronics:
        return 'Serial Number or IMEI';
      default:
        return 'Device Identifier';
    }
  }
  
  /// Luhn algorithm for IMEI validation
  static bool _luhnCheck(String digits) {
    int sum = 0;
    bool doubleDigit = false;
    
    for (int i = digits.length - 1; i >= 0; i--) {
      int digit = int.parse(digits[i]);
      
      if (doubleDigit) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      
      sum += digit;
      doubleDigit = !doubleDigit;
    }
    
    return sum % 10 == 0;
  }
}

/// Data integrity validation (BUG-033, BUG-036, BUG-037)
class DataIntegrityValidation {
  /// Validate HSN code format (4-8 digits)
  static bool isValidHSN(String? hsn) {
    if (hsn == null || hsn.isEmpty) return true; // Optional
    return RegExp(r'^\d{4,8}$').hasMatch(hsn);
  }
  
  /// Check if HSN codes match between product and bill item
  static bool doHSNCodesMatch(String? productHSN, String? billedHSN) {
    if (productHSN == null || productHSN.isEmpty) return true;
    if (billedHSN == null || billedHSN.isEmpty) return true;
    
    return productHSN == billedHSN;
  }
  
  /// Validate unit of measure
  static bool isValidUOM(String uom) {
    final validUOMs = [
      'PCS', 'KG', 'G', 'L', 'ML', 'M', 'CM', 'MM',
      'BOX', 'PACK', 'BOTTLE', 'CAN', 'TIN', 'DOZEN',
      'SET', 'PAIR', 'UNIT', 'NOS', 'NONE'
    ];
    return validUOMs.contains(uom.toUpperCase());
  }
  
  /// Check if UOMs match between product and bill item (BUG-037)
  static bool doUOMsMatch(String productUOM, String billedUOM) {
    // Normalize UOMs
    final normalizedProduct = productUOM.toUpperCase().trim();
    final normalizedBilled = billedUOM.toUpperCase().trim();
    
    // Direct match
    if (normalizedProduct == normalizedBilled) return true;
    
    // Equivalent UOMs
    final equivalentUOMs = {
      'PCS': ['PCS', 'NOS', 'UNIT', 'NONE'],
      'KG': ['KG', 'KILO'],
      'G': ['G', 'GRAM', 'GMS'],
      'L': ['L', 'LT', 'LTR', 'LITER'],
      'ML': ['ML', 'MLT'],
    };
    
    final productEquivalents = equivalentUOMs[normalizedProduct] ?? [normalizedProduct];
    return productEquivalents.contains(normalizedBilled);
  }
  
  /// Validate order line item integrity (BUG-033)
  static Map<String, dynamic> validateOrderLineItem({
    required String? orderId,
    required String productId,
    required String productName,
    required int quantity,
    required double price,
  }) {
    final errors = <String>[];
    
    // Check for orphaned item
    if (orderId == null || orderId.isEmpty) {
      errors.add('Line item has no parent order reference');
    }
    
    // Validate product reference
    if (productId.isEmpty) {
      errors.add('Product ID is required');
    }
    if (productName.isEmpty) {
      errors.add('Product name is required');
    }
    
    // Validate quantities
    if (quantity <= 0) {
      errors.add('Quantity must be greater than 0');
    }
    if (quantity > 999999) {
      errors.add('Quantity exceeds maximum allowed');
    }
    
    // Validate price
    if (price < 0) {
      errors.add('Price cannot be negative');
    }
    if (price > 999999999) {
      errors.add('Price exceeds maximum allowed');
    }
    
    return {
      'valid': errors.isEmpty,
      'errors': errors,
      'warnings': <String>[],
    };
  }
}

/// Extension for easy access
extension BusinessTypeValidation on BusinessType {
  bool get hasFullStaffManagement => BusinessTypeCapabilities.hasFullStaffManagement(this);
  bool get hasAttendanceTracking => BusinessTypeCapabilities.hasAttendanceTracking(this);
  bool get hasShiftManagement => BusinessTypeCapabilities.hasShiftManagement(this);
  bool get hasIDCardDesigner => BusinessTypeCapabilities.hasIDCardDesigner(this);
  String get staffFeaturesDescription => BusinessTypeCapabilities.getStaffFeaturesDescription(this);
  String get deviceIdentifierType => DeviceIdentifierValidation.getIdentifierType(this);
}
