// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pharmacy_dashboard_models.dart';
import '../services/pharmacy_dashboard_service.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../services/websocket_service.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../pharmacy/utils/tenant_scope.dart';

// ── Main Dashboard Provider ─────────────────────────────────────────────────────

class PharmacyDashboardNotifier extends AsyncNotifier<PharmacyDashboardData> {
  @override
  Future<PharmacyDashboardData> build() async {
    final session = sl<SessionManager>().currentSession;
    if (!session.isAuthenticated) throw Exception('User not authenticated');
    return _fetch();
  }

  Future<PharmacyDashboardData> _fetch() {
    final session = sl<SessionManager>().currentSession;
    final filters = ref.read(dateRangeFilterProvider);
    return sl<PharmacyDashboardService>().fetchAllDashboardData(
      tenantId: session.odId,
      filters: filters,
    );
  }

  Future<void> loadDashboardData() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> refreshAll() async {
    state = await AsyncValue.guard(_fetch);
  }

  void updateDateRange(DateRangeFilter newRange) {
    ref.read(dateRangeFilterProvider.notifier).state = PharmacyDashboardFilters(
      dateRange: newRange,
    );
    loadDashboardData();
  }

  void updateCustomDateRange(DateTime start, DateTime end) {
    ref.read(dateRangeFilterProvider.notifier).state = PharmacyDashboardFilters(
      dateRange: DateRangeFilter.custom,
      customStartDate: start,
      customEndDate: end,
    );
    loadDashboardData();
  }
}

final pharmacyDashboardProvider =
    AsyncNotifierProvider<PharmacyDashboardNotifier, PharmacyDashboardData>(
      PharmacyDashboardNotifier.new,
    );

// ── Individual Widget Providers ───────────────────────────────────────────────

// KPI Cards
final pharmacyKpiProvider = FutureProvider<PharmacyKpiData>((ref) async {
  // SM-AUDIT #4/#5: Gate on auth + react to business type changes
  final auth = ref.watch(authStateProvider);
  if (!auth.isAuthenticated) throw Exception('Not authenticated');
  ref.watch(businessTypeProvider);

  // R12.2 / R12.4 (Dashboard reconciliation): resolve the active tenantId
  // through the shared TenantScope chokepoint. When no tenantId can be
  // resolved, raise the canonical TenantScopeError and SKIP the KPI request
  // entirely — the service is never called and the dashboard surfaces a
  // "tenant context unavailable" state.
  final tenantId = TenantScope().tryResolve();
  if (tenantId == null) {
    throw const TenantScopeError.missing();
  }

  final filters = ref.watch(dateRangeFilterProvider);
  final service = sl<PharmacyDashboardService>();

  // R12.3: bound the KPI request to 10 seconds. A timeout (or a propagated
  // service error) surfaces as the provider's error state so the dashboard can
  // show an error indication + retry without navigating away.
  return await service
      .fetchKpiData(tenantId: tenantId, filters: filters)
      .timeout(const Duration(seconds: 10));
});

// Sales Performance Chart
final pharmacySalesPerformanceProvider = FutureProvider<SalesPerformanceData>((
  ref,
) async {
  final auth = ref.watch(authStateProvider);
  if (!auth.isAuthenticated) throw Exception('Not authenticated');
  ref.watch(businessTypeProvider);
  final session = sl<SessionManager>().currentSession;
  final filters = ref.watch(dateRangeFilterProvider);
  final service = sl<PharmacyDashboardService>();

  return await service.fetchSalesPerformanceData(
    tenantId: session.odId,
    filters: filters,
  );
});

// Prescriptions by Category
final pharmacyPrescriptionsCategoryProvider =
    FutureProvider<PrescriptionsByCategoryData>((ref) async {
      final auth = ref.watch(authStateProvider);
      if (!auth.isAuthenticated) throw Exception('Not authenticated');
      ref.watch(businessTypeProvider);
      final session = sl<SessionManager>().currentSession;
      final service = sl<PharmacyDashboardService>();

      return await service.fetchPrescriptionsByCategoryData(
        tenantId: session.odId,
      );
    });

// Top Selling Products
final pharmacyTopProductsProvider = FutureProvider<TopSellingProductsData>((
  ref,
) async {
  final auth = ref.watch(authStateProvider);
  if (!auth.isAuthenticated) throw Exception('Not authenticated');
  ref.watch(businessTypeProvider);
  final session = sl<SessionManager>().currentSession;
  final filters = ref.watch(dateRangeFilterProvider);
  final service = sl<PharmacyDashboardService>();

  return await service.fetchTopSellingProductsData(
    tenantId: session.odId,
    filters: filters,
  );
});

// Inventory Status
final pharmacyInventoryStatusProvider = FutureProvider<InventoryStatusData>((
  ref,
) async {
  final auth = ref.watch(authStateProvider);
  if (!auth.isAuthenticated) throw Exception('Not authenticated');
  ref.watch(businessTypeProvider);
  final session = sl<SessionManager>().currentSession;
  final service = sl<PharmacyDashboardService>();

  return await service.fetchInventoryStatusData(tenantId: session.odId);
});

// Low Stock Alerts
final pharmacyLowStockAlertsProvider = FutureProvider<LowStockAlertsData>((
  ref,
) async {
  final auth = ref.watch(authStateProvider);
  if (!auth.isAuthenticated) throw Exception('Not authenticated');
  ref.watch(businessTypeProvider);
  final session = sl<SessionManager>().currentSession;
  final service = sl<PharmacyDashboardService>();

  return await service.fetchLowStockAlertsData(tenantId: session.odId);
});

// Recent Activity
final pharmacyRecentActivityProvider = FutureProvider<RecentActivityData>((
  ref,
) async {
  final auth = ref.watch(authStateProvider);
  if (!auth.isAuthenticated) throw Exception('Not authenticated');
  ref.watch(businessTypeProvider);
  final session = sl<SessionManager>().currentSession;
  final service = sl<PharmacyDashboardService>();

  return await service.fetchRecentActivityData(tenantId: session.odId);
});

// Patient Feedback
final pharmacyPatientFeedbackProvider = FutureProvider<PatientFeedbackData>((
  ref,
) async {
  final auth = ref.watch(authStateProvider);
  if (!auth.isAuthenticated) throw Exception('Not authenticated');
  ref.watch(businessTypeProvider);
  final session = sl<SessionManager>().currentSession;
  final filters = ref.watch(dateRangeFilterProvider);
  final service = sl<PharmacyDashboardService>();

  return await service.fetchPatientFeedbackData(
    tenantId: session.odId,
    filters: filters,
  );
});

// ── Date Range Filter Provider ─────────────────────────────────────────────────

class _DateRangeFilterNotifier extends Notifier<PharmacyDashboardFilters> {
  @override
  PharmacyDashboardFilters build() => PharmacyDashboardFilters.defaultFilters;
  void update(PharmacyDashboardFilters f) => state = f;
}

final dateRangeFilterProvider =
    NotifierProvider<_DateRangeFilterNotifier, PharmacyDashboardFilters>(
      _DateRangeFilterNotifier.new,
    );

// ── WebSocket Provider for Real-time Updates ─────────────────────────────────────

class PharmacyWebSocketNotifier extends Notifier<void> {
  @override
  void build() {
    connect();
  }

  void connect() {
    final ws = sl<WebSocketService>();
    ws.subscribe(WSEventName.inventoryUpdated, (e) => _handleWebSocketEvent(e));
    ws.subscribe(
      WSEventName.prescriptionCreated,
      (e) => _handleWebSocketEvent(e),
    );
    ws.subscribe(WSEventName.staffActivity, (e) => _handleWebSocketEvent(e));
    ws.subscribe(WSEventName.lowStockAlert, (e) => _handleWebSocketEvent(e));
    ws.subscribe(WSEventName.billCreated, (e) => _handleWebSocketEvent(e));
  }

  void disconnect() {
    // Subscriptions are managed by WebSocketService
  }

  void _handleWebSocketEvent(WSEvent event) {
    switch (event.event) {
      case 'inventory.stock.updated':
        _handleInventoryUpdate(event.data);
        break;
      case 'prescription.dispensed':
        _handlePrescriptionDispensed(event.data);
        break;
      case 'activity.new':
        _handleNewActivity(event.data);
        break;
      case 'stock.threshold.breach':
        _handleStockThresholdBreach(event.data);
        break;
      case 'bill_created':
        _handleInvoiceCreated(event.data);
        break;
    }
  }

  void _handleInventoryUpdate(Map<String, dynamic> data) {
    ref.invalidate(pharmacyInventoryStatusProvider);
    ref.invalidate(pharmacyLowStockAlertsProvider);
  }

  void _handleInvoiceCreated(Map<String, dynamic> data) {
    // Refresh revenue KPI and sales chart when a new invoice is created
    ref.invalidate(pharmacyKpiProvider);
    ref.invalidate(pharmacySalesPerformanceProvider);
    ref.invalidate(pharmacyRecentActivityProvider);
    ref.invalidate(pharmacyDashboardProvider);
  }

  void _handlePrescriptionDispensed(Map<String, dynamic> data) {
    // Refresh prescription-related widgets
    ref.invalidate(pharmacyKpiProvider);
    ref.invalidate(pharmacyRecentActivityProvider);
  }

  void _handleNewActivity(Map<String, dynamic> data) {
    // Refresh activity feed
    ref.invalidate(pharmacyRecentActivityProvider);
  }

  void _handleStockThresholdBreach(Map<String, dynamic> data) {
    // Refresh low stock alerts and KPI
    ref.invalidate(pharmacyLowStockAlertsProvider);
    ref.invalidate(pharmacyKpiProvider);

    // Optionally show browser notification
    _showStockAlertNotification(data);
  }

  void _showStockAlertNotification(Map<String, dynamic> data) {
    final productName = data['productName'] as String? ?? 'Unknown product';
    final currentStock = data['currentStock'] as int? ?? 0;
    debugPrint(
      '[PharmacyWS] Stock Alert: $productName is running low ($currentStock units)',
    );
  }
}

final pharmacyWebSocketProvider =
    NotifierProvider<PharmacyWebSocketNotifier, void>(
      PharmacyWebSocketNotifier.new,
    );

// ── Dashboard Data Container ───────────────────────────────────────────────────

class PharmacyDashboardData {
  final PharmacyKpiData kpiData;
  final SalesPerformanceData salesPerformance;
  final PrescriptionsByCategoryData prescriptionsByCategory;
  final TopSellingProductsData topProducts;
  final InventoryStatusData inventoryStatus;
  final LowStockAlertsData lowStockAlerts;
  final RecentActivityData recentActivity;
  final PatientFeedbackData patientFeedback;

  const PharmacyDashboardData({
    required this.kpiData,
    required this.salesPerformance,
    required this.prescriptionsByCategory,
    required this.topProducts,
    required this.inventoryStatus,
    required this.lowStockAlerts,
    required this.recentActivity,
    required this.patientFeedback,
  });

  factory PharmacyDashboardData.empty() {
    return const PharmacyDashboardData(
      kpiData: PharmacyKpiData.empty,
      salesPerformance: SalesPerformanceData.empty,
      prescriptionsByCategory: PrescriptionsByCategoryData.empty,
      topProducts: TopSellingProductsData.empty,
      inventoryStatus: InventoryStatusData.empty,
      lowStockAlerts: LowStockAlertsData.empty,
      recentActivity: RecentActivityData.empty,
      patientFeedback: PatientFeedbackData.empty,
    );
  }
}

// ── Action Providers ───────────────────────────────────────────────────────────

// Reorder action for low stock items
final reorderProductProvider = FutureProvider.family<void, String>((
  ref,
  productId,
) async {
  final session = sl<SessionManager>().currentSession;
  final service = sl<PharmacyDashboardService>();

  await service.reorderProduct(tenantId: session.odId, productId: productId);

  // Refresh low stock alerts after reorder
  ref.invalidate(pharmacyLowStockAlertsProvider);
});
