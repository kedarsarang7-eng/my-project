import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'license_provider.dart';

/// Inventory alert model
class InventoryAlert {
  final String type;
  final String fuel;
  final int currentPercent;
  final int threshold;
  final String message;
  final String severity;

  const InventoryAlert({
    required this.type,
    required this.fuel,
    required this.currentPercent,
    required this.threshold,
    required this.message,
    required this.severity,
  });

  factory InventoryAlert.fromJson(Map<String, dynamic> json) {
    return InventoryAlert(
      type: json['type'] ?? '',
      fuel: json['fuel'] ?? '',
      currentPercent: (json['currentPercent'] ?? 0).toInt(),
      threshold: (json['threshold'] ?? 0).toInt(),
      message: json['message'] ?? '',
      severity: json['severity'] ?? 'low',
    );
  }

  bool get isHigh => severity == 'high';
  bool get isMedium => severity == 'medium';
  bool get isLow => severity == 'low';
}

/// Operational alert model
class OperationalAlert {
  final String type;
  final String? item;
  final String message;
  final String severity;

  const OperationalAlert({
    required this.type,
    this.item,
    required this.message,
    required this.severity,
  });

  factory OperationalAlert.fromJson(Map<String, dynamic> json) {
    return OperationalAlert(
      type: json['type'] ?? '',
      item: json['item'],
      message: json['message'] ?? '',
      severity: json['severity'] ?? 'low',
    );
  }
}

/// Pump status model
class PumpStatus {
  final int active;
  final int total;
  final int offline;

  const PumpStatus({
    required this.active,
    required this.total,
    required this.offline,
  });

  factory PumpStatus.fromJson(Map<String, dynamic> json) {
    return PumpStatus(
      active: (json['active'] ?? 0).toInt(),
      total: (json['total'] ?? 0).toInt(),
      offline: (json['offline'] ?? 0).toInt(),
    );
  }

  String get statusText => '$active/$total Active';
  double get activePercent => total > 0 ? (active / total) * 100 : 0;
}

/// Alerts data model
class AlertsData {
  final List<InventoryAlert> inventory;
  final List<OperationalAlert> operational;
  final PumpStatus pumps;
  final int employeesOnDuty;
  final DateTime lastUpdated;

  const AlertsData({
    required this.inventory,
    required this.operational,
    required this.pumps,
    required this.employeesOnDuty,
    required this.lastUpdated,
  });

  factory AlertsData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    return AlertsData(
      inventory: (data['inventory'] as List<dynamic>? ?? [])
          .map((e) => InventoryAlert.fromJson(e as Map<String, dynamic>))
          .toList(),
      operational: (data['operational'] as List<dynamic>? ?? [])
          .map((e) => OperationalAlert.fromJson(e as Map<String, dynamic>))
          .toList(),
      pumps: PumpStatus.fromJson(data['pumps'] ?? {}),
      employeesOnDuty: (data['employeesOnDuty'] ?? 0).toInt(),
      lastUpdated: DateTime.tryParse(data['lastUpdated'] ?? '') ?? DateTime.now(),
    );
  }

  // Get critical inventory alerts (red)
  List<InventoryAlert> get criticalAlerts =>
      inventory.where((a) => a.isHigh).toList();

  // Get warning inventory alerts (yellow)
  List<InventoryAlert> get warningAlerts =>
      inventory.where((a) => a.isMedium).toList();

  // Check if there are any low stock alerts
  bool get hasLowStock => inventory.any((a) => a.currentPercent < 35);
}

/// Alerts state
class AlertsState {
  final AlertsData? alerts;
  final bool isLoading;
  final String? error;

  const AlertsState({
    this.alerts,
    this.isLoading = false,
    this.error,
  });

  AlertsState copyWith({
    AlertsData? alerts,
    bool? isLoading,
    String? error,
  }) {
    return AlertsState(
      alerts: alerts ?? this.alerts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Alerts notifier
class AlertsNotifier extends StateNotifier<AlertsState> {
  final Ref _ref;

  AlertsNotifier(this._ref) : super(const AlertsState());

  Future<void> loadAlerts() async {
    if (state.isLoading) return;

    final license = _ref.read(licenseProvider).profile;
    if (license == null) {
      state = state.copyWith(error: 'No license profile available');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final apiClient = ApiClient();

      final response = await apiClient.get(
        '/dashboard/alerts?stationId=${license.stationId}',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = AlertsData.fromJson(response.data);
        state = state.copyWith(
          alerts: data,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.data['error'] ?? 'Failed to load alerts',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Network error: $e',
      );
    }
  }

  void refresh() {
    loadAlerts();
  }
}

/// Provider for alerts
final alertsProvider = StateNotifierProvider<AlertsNotifier, AlertsState>((ref) {
  return AlertsNotifier(ref);
});

/// Provider for inventory alerts (convenience)
final inventoryAlertsProvider = Provider<List<InventoryAlert>>((ref) {
  return ref.watch(alertsProvider).alerts?.inventory ?? [];
});

/// Provider for operational alerts (convenience)
final operationalAlertsProvider = Provider<List<OperationalAlert>>((ref) {
  return ref.watch(alertsProvider).alerts?.operational ?? [];
});

/// Provider for pump status (convenience)
final pumpStatusProvider = Provider<PumpStatus>((ref) {
  return ref.watch(alertsProvider).alerts?.pumps ??
      const PumpStatus(active: 0, total: 0, offline: 0);
});

/// Provider for employees on duty (convenience)
final employeesOnDutyProvider = Provider<int>((ref) {
  return ref.watch(alertsProvider).alerts?.employeesOnDuty ?? 0;
});

/// Provider for critical alert count
final criticalAlertCountProvider = Provider<int>((ref) {
  final alerts = ref.watch(alertsProvider).alerts;
  if (alerts == null) return 0;
  return alerts.criticalAlerts.length +
      alerts.operational.where((o) => o.severity == 'high').length;
});
