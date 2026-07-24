/// MobileShop Commerce Screens — Barrel Export
///
/// Single import for all mobile commerce UI flows:
/// - Finance Plan (EMI/finance provider forms)
/// - SIM / Recharge (provider-neutral recharge)
/// - OCR Intake (policy-gated document capture)
/// - Bundle Sale (handset + accessories with separate lines)
/// - Price Adjustment (approval workflow with margin impact)
///
/// Requirements: 7.3, 10.1–10.12, 12.1–12.8
library;

export 'bundle_sale_screen.dart';
export 'commerce_ui_utils.dart';
export 'finance_plan_screen.dart';
export 'mobile_commerce_service.dart';
export 'ocr_intake_screen.dart';
export 'price_adjustment_screen.dart';
export 'sim_recharge_screen.dart';
