import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../services/websocket_service.dart';
import '../config/dashboard_business_config.dart';
import '../models/dashboard_v2_models.dart';
import '../services/dashboard_v2_service.dart';

final _dashboardService = Provider((ref) => DashboardV2Service());

/// Active business type name (string key for API calls)
final activeBusinessTypeNameProvider = Provider<String>((ref) {
  return ref.watch(businessTypeProvider).type.name;
});

/// Dynamic business-type config (labels change per type)
final dashboardBusinessConfigProvider = Provider<DashboardBusinessConfig>((ref) {
  final bt = ref.watch(businessTypeProvider).type;
  return DashboardBusinessConfig.forType(bt);
});

/// Dashboard Summary (Performance Cards)
final dashboardV2SummaryProvider =
    FutureProvider.autoDispose<DashboardSummary>((ref) async {
  final auth = ref.watch(authStateProvider);
  if (!auth.isAuthenticated) throw Exception('Not authenticated');
  final bt = ref.watch(activeBusinessTypeNameProvider);
  return ref.read(_dashboardService).getDashboardSummary(businessType: bt);
});

/// Revenue Chart (Last 6 Months)
final dashboardV2RevenueChartProvider =
    FutureProvider.autoDispose<RevenueChartData>((ref) async {
  final auth = ref.watch(authStateProvider);
  if (!auth.isAuthenticated) throw Exception('Not authenticated');
  final bt = ref.watch(activeBusinessTypeNameProvider);
  return ref.read(_dashboardService).getRevenueChart(businessType: bt);
});

/// Invoice Distribution (Donut Chart)
final dashboardV2InvoiceDistributionProvider =
    FutureProvider.autoDispose<InvoiceDistribution>((ref) async {
  final auth = ref.watch(authStateProvider);
  if (!auth.isAuthenticated) throw Exception('Not authenticated');
  final bt = ref.watch(activeBusinessTypeNameProvider);
  return ref.read(_dashboardService).getInvoiceDistribution(businessType: bt);
});

/// Recent Invoices (Table)
final dashboardV2RecentInvoicesProvider =
    FutureProvider.autoDispose.family<RecentInvoicesData, String>(
        (ref, filter) async {
  final auth = ref.watch(authStateProvider);
  if (!auth.isAuthenticated) throw Exception('Not authenticated');
  final bt = ref.watch(activeBusinessTypeNameProvider);
  return ref
      .read(_dashboardService)
      .getRecentInvoices(businessType: bt, filter: filter);
});

/// Cash Flow Forecast
final dashboardV2CashflowProvider =
    FutureProvider.autoDispose<CashFlowForecastData>((ref) async {
  final auth = ref.watch(authStateProvider);
  if (!auth.isAuthenticated) throw Exception('Not authenticated');
  final bt = ref.watch(activeBusinessTypeNameProvider);
  return ref.read(_dashboardService).getCashflowForecast(businessType: bt);
});

/// Notification Badge Count
final dashboardV2NotificationCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final auth = ref.watch(authStateProvider);
  if (!auth.isAuthenticated) throw Exception('Not authenticated');
  return ref.read(_dashboardService).getNotificationsCount();
});

/// License Info
final dashboardV2LicenseProvider =
    FutureProvider.autoDispose<LicenseInfo?>((ref) async {
  final auth = ref.watch(authStateProvider);
  if (!auth.isAuthenticated) throw Exception('Not authenticated');
  return ref.read(_dashboardService).validateLicense();
});

// ── Grocery WebSocket Provider for Real-time Updates ────────────────────────
// Mirrors PharmacyWebSocketNotifier but targets grocery dashboard providers.
// Subscribes to inventoryUpdated, lowStockAlert, expiryAlert, dashboardUpdated
// and invalidates all grocery-relevant FutureProviders on receipt.

class GroceryWebSocketNotifier extends Notifier<void> {
  @override
  void build() {
    _connect();
  }

  void _connect() {
    final ws = sl<WebSocketService>();
    ws.subscribe(WSEventName.inventoryUpdated, _onInventoryEvent);
    ws.subscribe(WSEventName.lowStockAlert, _onStockAlertEvent);
    ws.subscribe(WSEventName.expiryAlert, _onExpiryAlertEvent);
    ws.subscribe(WSEventName.dashboardUpdated, _onDashboardEvent);
  }

  void _onInventoryEvent(WSEvent _) {
    ref.invalidate(dashboardV2SummaryProvider);
    ref.invalidate(dashboardV2RevenueChartProvider);
    ref.invalidate(dashboardV2InvoiceDistributionProvider);
  }

  void _onStockAlertEvent(WSEvent _) {
    ref.invalidate(dashboardV2SummaryProvider);
  }

  void _onExpiryAlertEvent(WSEvent _) {
    ref.invalidate(dashboardV2SummaryProvider);
  }

  void _onDashboardEvent(WSEvent _) {
    ref.invalidate(dashboardV2SummaryProvider);
    ref.invalidate(dashboardV2RevenueChartProvider);
    ref.invalidate(dashboardV2CashflowProvider);
    ref.invalidate(dashboardV2RecentInvoicesProvider('all'));
  }
}

final groceryWebSocketProvider =
    NotifierProvider<GroceryWebSocketNotifier, void>(
  GroceryWebSocketNotifier.new,
);
