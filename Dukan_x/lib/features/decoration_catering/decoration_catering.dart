// ============================================================================
// DECORATION & CATERING MODULE — BARREL FILE
// ============================================================================
//
// DISPOSITION NOTE (Phase 8 / Req 14.6–14.7):
// The go_router DC_Module (`decoration_catering_module.dart` / `lib/modules/`)
// was confirmed dead code in the Phase 0 Verification Report and has already
// been removed from disk. All DC routes are now registered via `legacy_routes.dart`
// with proper Business_Guard and Vendor_Role_Guard wrapping. No further action
// required for this item.
// ============================================================================

// Models
export 'data/models/dc_models.dart';
export 'data/models/event_rental.dart';

// Repository & Providers
export 'data/repositories/dc_repository.dart';

// Migrations
export 'data/migrations/dc_discount_migration.dart';

// Screens
export 'presentation/screens/dc_dashboard_screen.dart';
export 'presentation/screens/dc_bookings_screen.dart';
export 'presentation/screens/dc_decoration_screen.dart';
export 'presentation/screens/dc_catering_screen.dart';
export 'presentation/screens/dc_staff_screen.dart';
export 'presentation/screens/dc_inventory_screen.dart';
export 'presentation/screens/dc_reports_screen.dart';
export 'presentation/screens/dc_billing_screen.dart';
export 'presentation/screens/dc_quotes_screen.dart';
export 'presentation/screens/dc_calendar_screen.dart';
export 'presentation/screens/dc_profitability_screen.dart';
export 'presentation/screens/dc_shopping_list_screen.dart';
export 'presentation/screens/dc_vendor_payments_screen.dart';
export 'presentation/screens/dc_event_detail_screen.dart'
    hide dcExpensesProvider;
export 'presentation/screens/dc_quote_conversion_screen.dart';
export 'presentation/screens/dc_staff_attendance_screen.dart';

// Services
export 'services/dc_pdf_service.dart';

// Utils — cross-cutting infra (tenant scope, RID generation, money math)
export 'utils/dc_tenant_scope.dart';
export 'utils/dc_rid_generator.dart';
export 'utils/dc_money_math.dart';
export 'utils/decoration_catering_business_rules.dart';

// Widgets
export 'presentation/widgets/dc_status_badge.dart';
export 'presentation/widgets/dc_booking_form.dart';
export 'presentation/widgets/dc_ui_kit.dart';
export 'presentation/widgets/dc_vendor_rating_dialog.dart';
