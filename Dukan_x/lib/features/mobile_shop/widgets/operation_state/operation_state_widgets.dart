/// OperationState Widgets — Barrel Export (Dart)
///
/// Single import for the centralized operation state management system.
/// Provides:
/// - [OperationState] sealed hierarchy with 10 distinct states
/// - [RecoveryAction] typed recovery guidance with correlation/retry info
/// - [OperationStateCard] reusable state display widget
/// - [OperationProgressBanner] screen-reader announcing progress widget
/// - [OperationBusyGuard] duplicate-activation prevention
/// - [RecoveryActionButton] / [RecoveryActionGroup] action widgets
/// - Mappers from [ConsistencyOutcome], [CommerceOutcome], [ScreenState], [KpiState]
///
/// Requirements: 7.14, 9.1–9.6, 11.7–11.8, 12.4–12.10; GR-3
library;

export 'operation_progress_banner.dart';
export 'operation_state.dart';
export 'operation_state_card.dart';
export 'operation_state_mappers.dart';
export 'recovery_action_button.dart';
