// ============================================================================
// RESTAURANT / HOTEL FOOD ORDERING SYSTEM
// ============================================================================
// Feature barrel export
//
// This module is ONLY visible when businessType == RESTAURANT || HOTEL
// ============================================================================

// Models
export 'data/models/food_menu_item_model.dart';
export 'data/models/food_category_model.dart';
export 'data/models/food_order_model.dart';
export 'data/models/restaurant_table_model.dart';
export 'data/models/restaurant_bill_model.dart';

// Repositories
export 'data/repositories/food_menu_repository.dart';
export 'data/repositories/food_order_repository.dart';
export 'data/repositories/restaurant_table_repository.dart';
export 'data/repositories/restaurant_bill_repository.dart';

// Services
export 'domain/services/restaurant_sync_service.dart';
export 'domain/services/qr_code_service.dart';
export 'domain/services/restaurant_notification_service.dart';
export 'domain/services/restaurant_notification_snapshot.dart';
export 'domain/services/restaurant_pdf_bill_service.dart';

// Guards
export 'domain/guards/restaurant_guard.dart';

// Presentation - Vendor Screens
export 'presentation/screens/food_menu_management_screen.dart';
export 'presentation/screens/kitchen_display_screen.dart';
export 'presentation/screens/table_management_screen.dart';
export 'presentation/screens/restaurant_daily_summary_screen.dart';

// Presentation - Customer Screens
export 'presentation/screens/customer/customer_menu_screen.dart';
export 'presentation/screens/customer/order_tracking_screen.dart';
export 'presentation/screens/customer/rate_review_screen.dart';

// Widgets
export 'presentation/widgets/table_qr_code_widget.dart';
