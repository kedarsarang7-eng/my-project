// ============================================================================
// RESTAURANT GUARD
// ============================================================================

/// Guard to check if restaurant features should be visible
/// Only visible when businessType == RESTAURANT
class RestaurantGuard {
  /// Check if user can access restaurant features
  static bool canAccess(String? businessType) {
    if (businessType == null) return false;
    final type = businessType.toLowerCase();
    return type == 'restaurant';
  }

  /// List of valid business types for restaurant features
  static const validBusinessTypes = ['restaurant'];

  /// Check if business type is valid for restaurant
  static bool isValidBusinessType(String? type) {
    if (type == null) return false;
    return validBusinessTypes.contains(type.toLowerCase());
  }
}
