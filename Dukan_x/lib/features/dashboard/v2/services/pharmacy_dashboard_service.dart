import '../models/pharmacy_dashboard_models.dart';
import '../providers/pharmacy_dashboard_providers.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';

/// Pharmacy Dashboard Service
/// Handles all API calls for pharmacy dashboard data
/// Implements caching, error handling, and real-time data fetching
class PharmacyDashboardService {
  final ApiClient _apiClient;

  PharmacyDashboardService() : _apiClient = sl<ApiClient>();

  // ── Main Dashboard Data Fetch (Parallel) ─────────────────────────────────────

  Future<PharmacyDashboardData> fetchAllDashboardData({
    required String tenantId,
    required PharmacyDashboardFilters filters,
  }) async {
    try {
      // Fetch all data in parallel for better performance
      final results = await Future.wait([
        fetchKpiData(tenantId: tenantId, filters: filters),
        fetchSalesPerformanceData(tenantId: tenantId, filters: filters),
        fetchPrescriptionsByCategoryData(tenantId: tenantId),
        fetchTopSellingProductsData(tenantId: tenantId, filters: filters),
        fetchInventoryStatusData(tenantId: tenantId),
        fetchLowStockAlertsData(tenantId: tenantId),
        fetchRecentActivityData(tenantId: tenantId),
        fetchPatientFeedbackData(tenantId: tenantId, filters: filters),
      ]);

      return PharmacyDashboardData(
        kpiData: results[0] as PharmacyKpiData,
        salesPerformance: results[1] as SalesPerformanceData,
        prescriptionsByCategory: results[2] as PrescriptionsByCategoryData,
        topProducts: results[3] as TopSellingProductsData,
        inventoryStatus: results[4] as InventoryStatusData,
        lowStockAlerts: results[5] as LowStockAlertsData,
        recentActivity: results[6] as RecentActivityData,
        patientFeedback: results[7] as PatientFeedbackData,
      );
    } catch (e) {
      // AUDIT FIX #5: Rethrow so provider surfaces error state with retry UI
      rethrow;
    }
  }

  // ── KPI Cards Data ─────────────────────────────────────────────────────────

  Future<PharmacyKpiData> fetchKpiData({
    required String tenantId,
    required PharmacyDashboardFilters filters,
  }) async {
    try {
      final params = filters.toApiParams();
      
      // Fetch all KPI data in parallel
      final results = await Future.wait([
        _get('/api/pharmacy/revenue', params, tenantId),
        _get('/api/pharmacy/patients/new', params, tenantId),
        _get('/api/pharmacy/prescriptions/count', {...params, 'status': 'dispensed'}, tenantId),
        _get('/api/pharmacy/inventory/low-stock/count', {}, tenantId),
      ]);

      return PharmacyKpiData(
        totalRevenue: TotalRevenueKpi.fromJson(results[0]),
        newPatients: NewPatientsKpi.fromJson(results[1]),
        prescriptionsFilled: PrescriptionsFilledKpi.fromJson(results[2]),
        lowStockItems: LowStockItemsKpi.fromJson(results[3]),
      );
    } catch (e) {
      return PharmacyKpiData.empty;
    }
  }

  // ── Sales Performance Chart ─────────────────────────────────────────────────

  Future<SalesPerformanceData> fetchSalesPerformanceData({
    required String tenantId,
    required PharmacyDashboardFilters filters,
  }) async {
    try {
      final params = filters.toApiParams();
      final response = await _get('/api/pharmacy/sales/daily', params, tenantId);
      
      return SalesPerformanceData.fromJson(response);
    } catch (e) {
      return SalesPerformanceData.empty;
    }
  }

  // ── Prescriptions by Category ───────────────────────────────────────────────

  Future<PrescriptionsByCategoryData> fetchPrescriptionsByCategoryData({
    required String tenantId,
  }) async {
    try {
      final response = await _get('/api/pharmacy/prescriptions/by-category', 
          {'granularity': 'weekly'}, tenantId);
      
      return PrescriptionsByCategoryData.fromJson(response);
    } catch (e) {
      return PrescriptionsByCategoryData.empty;
    }
  }

  // ── Top Selling Products ─────────────────────────────────────────────────────

  Future<TopSellingProductsData> fetchTopSellingProductsData({
    required String tenantId,
    required PharmacyDashboardFilters filters,
  }) async {
    try {
      final params = {...filters.toApiParams(), 'limit': '5'};
      final response = await _get('/api/pharmacy/products/top-sellers', params, tenantId);
      
      return TopSellingProductsData.fromJson(response);
    } catch (e) {
      return TopSellingProductsData.empty;
    }
  }

  // ── Inventory Status ───────────────────────────────────────────────────────

  Future<InventoryStatusData> fetchInventoryStatusData({
    required String tenantId,
  }) async {
    try {
      final response = await _get('/api/pharmacy/inventory/status-summary', {}, tenantId);
      
      return InventoryStatusData.fromJson(response);
    } catch (e) {
      return InventoryStatusData.empty;
    }
  }

  // ── Low Stock Alerts ───────────────────────────────────────────────────────

  Future<LowStockAlertsData> fetchLowStockAlertsData({
    required String tenantId,
  }) async {
    try {
      final response = await _get('/api/pharmacy/inventory/low-stock', {'limit': '10'}, tenantId);
      
      return LowStockAlertsData.fromJson(response);
    } catch (e) {
      return LowStockAlertsData.empty;
    }
  }

  // ── Recent Activity Feed ───────────────────────────────────────────────────

  Future<RecentActivityData> fetchRecentActivityData({
    required String tenantId,
  }) async {
    try {
      final response = await _get('/api/pharmacy/activity/recent', {'limit': '20'}, tenantId);
      
      return RecentActivityData.fromJson(response);
    } catch (e) {
      return RecentActivityData.empty;
    }
  }

  // ── Patient Feedback ───────────────────────────────────────────────────────

  Future<PatientFeedbackData> fetchPatientFeedbackData({
    required String tenantId,
    required PharmacyDashboardFilters filters,
  }) async {
    try {
      final params = filters.toApiParams();
      final response = await _get('/api/pharmacy/feedback/summary', params, tenantId);
      
      return PatientFeedbackData.fromJson(response);
    } catch (e) {
      return PatientFeedbackData.empty;
    }
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> reorderProduct({
    required String tenantId,
    required String productId,
  }) async {
    try {
      await _post('/api/pharmacy/inventory/reorder', {
        'productId': productId,
      }, tenantId);
    } catch (e) {
      throw Exception('Failed to reorder product: $e');
    }
  }

  // ── HTTP Helper Methods ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _get(
    String endpoint,
    Map<String, String> params,
    String tenantId,
  ) async {
    try {
      final response = await _apiClient.get(
        endpoint,
        queryParams: params,
        // AUDIT FIX #9: Removed redundant X-Tenant-ID — ApiClient sets x-tenant-id
        headers: {
          'X-Business-Type': 'pharmacy',
        },
      );

      if (response.isSuccess && response.data != null) {
        return response.data!;
      } else if (response.statusCode == 404) {
        return {'isEmpty': true, 'message': 'No data available'};
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.error}');
      }
    } catch (e) {
      return {'isEmpty': true, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body,
    String tenantId,
  ) async {
    try {
      final response = await _apiClient.post(
        endpoint,
        body: body,
        // AUDIT FIX #9: Removed redundant X-Tenant-ID — ApiClient sets x-tenant-id
        headers: {
          'X-Business-Type': 'pharmacy',
        },
      );

      if (response.isSuccess && response.data != null) {
        return response.data!;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.error}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // ── Cache Management ───────────────────────────────────────────────────────

  void clearCache() {
    // Clear any cached data
    // This would integrate with the actual caching mechanism
  }

  // ── Real-time Subscription Management ───────────────────────────────────────

  void subscribeToRealTimeUpdates({
    required String tenantId,
    required Function(Map<String, dynamic>) onInventoryUpdate,
    required Function(Map<String, dynamic>) onPrescriptionUpdate,
    required Function(Map<String, dynamic>) onActivityUpdate,
    required Function(Map<String, dynamic>) onStockAlert,
  }) {
    // This would integrate with WebSocket service
    // Implementation depends on the actual WebSocket setup
  }

  void unsubscribeFromRealTimeUpdates() {
    // Unsubscribe from all real-time updates
  }
}
