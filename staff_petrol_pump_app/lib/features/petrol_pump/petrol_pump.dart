/// Petrol Pump Feature - FuelPOS
/// 
/// A complete petrol pump management dashboard for fuel stations.
/// Includes real-time sales tracking, inventory management, transactions,
/// and station alerts.
///
/// ## Usage
///
/// ```dart
/// import 'package:saas_platform/features/petrol_pump/petrol_pump.dart';
///
/// // Access providers
/// final license = ref.watch(licenseProvider);
/// final summary = ref.watch(dashboardSummaryProvider);
///
/// // Navigate to dashboard
/// context.go('/dashboard/petrol-pump');
/// ```

library petrol_pump;

export 'providers/providers.dart';
export 'screens/petrol_pump_dashboard_screen.dart';
export 'theme/fuelpos_theme.dart';
export 'widgets/widgets.dart';
