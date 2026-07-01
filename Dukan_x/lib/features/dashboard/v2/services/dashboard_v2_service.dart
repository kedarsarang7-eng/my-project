import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/monitoring/monitoring_service.dart';
import '../models/dashboard_v2_models.dart';

/// Service to fetch dashboard V2 data from API Gateway.
///
/// AUDIT FIX #3: Methods throw on non-success HTTP responses so that
/// Riverpod FutureProviders surface error state to widgets (retry UI)
/// instead of silently showing empty data.
class DashboardV2Service {
  final ApiClient _api = sl<ApiClient>();

  Future<DashboardSummary> getDashboardSummary({
    required String businessType,
    String period = 'MTD',
  }) async {
    final response = await _api.get(
      '/dashboard/v2/summary',
      queryParams: {'businessType': businessType, 'period': period},
    );
    if (response.isSuccess && response.data != null) {
      final data = response.data!['data'] ?? response.data!;
      if (kDebugMode) {
        developer.log('Dashboard summary raw: $data',
            name: 'DashboardV2Service');
      }
      return DashboardSummary.fromJson(data);
    }
    // P1 AUDIT FIX #7: Log to production monitoring
    monitoring.error('DashboardV2', 'Dashboard summary failed',
        metadata: {'statusCode': response.statusCode, 'error': response.error});
    throw Exception(
      'Dashboard summary failed: ${response.statusCode} — ${response.error}',
    );
  }

  Future<RevenueChartData> getRevenueChart({
    required String businessType,
    int months = 6,
  }) async {
    final response = await _api.get(
      '/dashboard/v2/revenue-chart',
      queryParams: {
        'businessType': businessType,
        'months': months.toString(),
      },
    );
    if (response.isSuccess && response.data != null) {
      final data = response.data!['data'] ?? response.data!;
      if (kDebugMode) {
        developer.log('Revenue chart raw: $data',
            name: 'DashboardV2Service');
      }
      return RevenueChartData.fromJson(data);
    }
    monitoring.error('DashboardV2', 'Revenue chart failed',
        metadata: {'statusCode': response.statusCode, 'error': response.error});
    throw Exception(
      'Revenue chart failed: ${response.statusCode} — ${response.error}',
    );
  }

  Future<InvoiceDistribution> getInvoiceDistribution({
    required String businessType,
  }) async {
    final response = await _api.get(
      '/dashboard/v2/invoice-distribution',
      queryParams: {'businessType': businessType},
    );
    if (response.isSuccess && response.data != null) {
      final data = response.data!['data'] ?? response.data!;
      if (kDebugMode) {
        developer.log('Invoice distribution raw: $data',
            name: 'DashboardV2Service');
      }
      return InvoiceDistribution.fromJson(data);
    }
    monitoring.error('DashboardV2', 'Invoice distribution failed',
        metadata: {'statusCode': response.statusCode, 'error': response.error});
    throw Exception(
      'Invoice distribution failed: ${response.statusCode} — ${response.error}',
    );
  }

  Future<RecentInvoicesData> getRecentInvoices({
    required String businessType,
    String range = '10days',
    String filter = 'all',
  }) async {
    final response = await _api.get(
      '/dashboard/v2/recent-invoices',
      queryParams: {
        'businessType': businessType,
        'range': range,
        'filter': filter,
      },
    );
    if (response.isSuccess && response.data != null) {
      final data = response.data!['data'] ?? response.data!;
      if (kDebugMode) {
        developer.log('Recent invoices raw: $data',
            name: 'DashboardV2Service');
      }
      return RecentInvoicesData.fromJson(data);
    }
    monitoring.error('DashboardV2', 'Recent invoices failed',
        metadata: {'statusCode': response.statusCode, 'error': response.error});
    throw Exception(
      'Recent invoices failed: ${response.statusCode} — ${response.error}',
    );
  }

  Future<CashFlowForecastData> getCashflowForecast({
    required String businessType,
  }) async {
    final response = await _api.get(
      '/dashboard/v2/cashflow-forecast',
      queryParams: {'businessType': businessType},
    );
    if (response.isSuccess && response.data != null) {
      final data = response.data!['data'] ?? response.data!;
      if (kDebugMode) {
        developer.log('Cashflow forecast raw: $data',
            name: 'DashboardV2Service');
      }
      return CashFlowForecastData.fromJson(data);
    }
    monitoring.error('DashboardV2', 'Cashflow forecast failed',
        metadata: {'statusCode': response.statusCode, 'error': response.error});
    throw Exception(
      'Cashflow forecast failed: ${response.statusCode} — ${response.error}',
    );
  }

  /// AUDIT FIX #6: Log notification count errors (non-critical, still returns 0)
  Future<int> getNotificationsCount() async {
    try {
      final response = await _api.get('/dashboard/v2/notifications-count');
      if (response.isSuccess && response.data != null) {
        final data = response.data!['data'] ?? response.data!;
        return (data['count'] as num?)?.toInt() ?? 0;
      }
      return 0;
    } catch (e) {
      developer.log('Notification count error: $e',
          name: 'DashboardV2Service');
      monitoring.warning('DashboardV2', 'Notification count error: $e');
      return 0;
    }
  }

  Future<LicenseInfo?> validateLicense() async {
    try {
      final response = await _api.get('/dashboard/v2/license-validate');
      if (response.isSuccess && response.data != null) {
        final data = response.data!['data'] ?? response.data!;
        return LicenseInfo.fromJson(data);
      }
      return null;
    } catch (e) {
      developer.log('License validation error: $e',
          name: 'DashboardV2Service');
      monitoring.warning('DashboardV2', 'License validation error: $e');
      return null;
    }
  }
}
