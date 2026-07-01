import '../../../../models/business_type.dart';
import 'dashboard_strategies.dart';
import 'concrete_strategies.dart';

class DashboardStrategyFactory {
  /// Cache strategies to avoid recreation
  static final Map<BusinessType, DashboardStrategy> _cache = {};

  static DashboardStrategy getStrategy(BusinessType type) {
    if (_cache.containsKey(type)) {
      return _cache[type]!;
    }

    DashboardStrategy strategy;
    switch (type) {
      case BusinessType.grocery:
        strategy = GroceryDashboardStrategy();
        break;
      case BusinessType.pharmacy:
        strategy = PharmacyDashboardStrategy();
        break;
      case BusinessType.clinic:
        strategy = ClinicDashboardStrategy();
        break;
      case BusinessType.restaurant:
        strategy = RestaurantDashboardStrategy();
        break;
      case BusinessType.vegetablesBroker:
        strategy = VegetableBrokerStrategy();
        break;

      // Map specialized electronics/mobile logic to Default or create new ones
      case BusinessType.electronics:
      case BusinessType.mobileShop:
      case BusinessType.computerShop:
        // Use default for now, but with proper titles/icons logic from DefaultStrategy
        strategy = DefaultDashboardStrategy(type);
        break;

      default:
        strategy = DefaultDashboardStrategy(type);
    }

    _cache[type] = strategy;
    return strategy;
  }
}
