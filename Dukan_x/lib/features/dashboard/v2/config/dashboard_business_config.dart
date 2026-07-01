import '../../../../models/business_type.dart';

/// Per-business-type dashboard labels and configuration
/// Controls what text appears on cards, charts, tables
class DashboardBusinessConfig {
  final String revenueCardLabel;
  final String kpi2Label;
  final String kpi3Label;
  final String chartYAxisLabel;
  final String invoiceTableName;
  final String forecastLabel;

  const DashboardBusinessConfig({
    required this.revenueCardLabel,
    required this.kpi2Label,
    required this.kpi3Label,
    required this.chartYAxisLabel,
    required this.invoiceTableName,
    required this.forecastLabel,
  });

  static DashboardBusinessConfig forType(BusinessType type) {
    return _configs[type] ?? _defaultConfig;
  }

  static const _defaultConfig = DashboardBusinessConfig(
    revenueCardLabel: 'Total Revenue',
    kpi2Label: 'Low Stock Items',
    kpi3Label: 'Pending Orders',
    chartYAxisLabel: '₹ Revenue',
    invoiceTableName: 'Invoice',
    forecastLabel: 'Cash Forecast',
  );

  static const Map<BusinessType, DashboardBusinessConfig> _configs = {
    BusinessType.grocery: DashboardBusinessConfig(
      revenueCardLabel: 'Daily Sales',
      kpi2Label: 'Low Stock Items',
      kpi3Label: 'Expiry Alerts',
      chartYAxisLabel: '₹ Revenue',
      invoiceTableName: 'Sales Bill',
      forecastLabel: 'Stock Forecast',
    ),
    BusinessType.hardware: DashboardBusinessConfig(
      revenueCardLabel: 'Project Revenue',
      kpi2Label: 'Pending Orders',
      kpi3Label: 'Quote Requests',
      chartYAxisLabel: '₹ Revenue',
      invoiceTableName: 'Work Order',
      forecastLabel: 'Project Cashflow',
    ),
    BusinessType.bookStore: DashboardBusinessConfig(
      revenueCardLabel: 'Book Sales',
      kpi2Label: 'Bestsellers',
      kpi3Label: 'Returns',
      chartYAxisLabel: '₹ Revenue',
      invoiceTableName: 'Book Invoice',
      forecastLabel: 'Royalty Forecast',
    ),
    BusinessType.clothing: DashboardBusinessConfig(
      revenueCardLabel: 'Season Revenue',
      kpi2Label: 'Size Stock Alerts',
      kpi3Label: 'Return Rate',
      chartYAxisLabel: '₹ Revenue',
      invoiceTableName: 'Fashion Bill',
      forecastLabel: 'Season Forecast',
    ),
    BusinessType.mobileShop: DashboardBusinessConfig(
      revenueCardLabel: 'Device Revenue',
      kpi2Label: 'IMEI Alerts',
      kpi3Label: 'Repair Jobs',
      chartYAxisLabel: '₹ Revenue',
      invoiceTableName: 'Device Invoice',
      forecastLabel: 'Device Forecast',
    ),
    BusinessType.computerShop: DashboardBusinessConfig(
      revenueCardLabel: 'System Revenue',
      kpi2Label: 'Warranty Alerts',
      kpi3Label: 'Open Tickets',
      chartYAxisLabel: '₹ Revenue',
      invoiceTableName: 'Tech Invoice',
      forecastLabel: 'Parts Forecast',
    ),
    BusinessType.autoParts: DashboardBusinessConfig(
      revenueCardLabel: 'Parts Revenue',
      kpi2Label: 'Part Requests',
      kpi3Label: 'Core Deposits',
      chartYAxisLabel: '₹ Revenue',
      invoiceTableName: 'Parts Invoice',
      forecastLabel: 'Core Forecast',
    ),
    BusinessType.wholesale: DashboardBusinessConfig(
      revenueCardLabel: 'Bulk Revenue',
      kpi2Label: 'Bulk Overdue',
      kpi3Label: 'Pending POs',
      chartYAxisLabel: '₹ Revenue',
      invoiceTableName: 'Bulk Invoice',
      forecastLabel: 'Volume Forecast',
    ),
    BusinessType.electronics: DashboardBusinessConfig(
      revenueCardLabel: 'Electronics Revenue',
      kpi2Label: 'Warranty Alerts',
      kpi3Label: 'Service Requests',
      chartYAxisLabel: '₹ Revenue',
      invoiceTableName: 'Electronics Invoice',
      forecastLabel: 'Sales Forecast',
    ),
    BusinessType.pharmacy: DashboardBusinessConfig(
      revenueCardLabel: 'Pharmacy Sales',
      kpi2Label: 'Expiry Alerts',
      kpi3Label: 'Pending Prescriptions',
      chartYAxisLabel: '₹ Revenue',
      invoiceTableName: 'Rx Invoice',
      forecastLabel: 'Stock Forecast',
    ),
    BusinessType.restaurant: DashboardBusinessConfig(
      revenueCardLabel: 'Daily Revenue',
      kpi2Label: 'Active Orders',
      kpi3Label: 'Kitchen Queue',
      chartYAxisLabel: '₹ Revenue',
      invoiceTableName: 'Order Bill',
      forecastLabel: 'Revenue Forecast',
    ),
    BusinessType.clinic: DashboardBusinessConfig(
      revenueCardLabel: 'OPD Revenue',
      kpi2Label: 'Today Appointments',
      kpi3Label: 'Pending Reports',
      chartYAxisLabel: '₹ Revenue',
      invoiceTableName: 'Consultation Bill',
      forecastLabel: 'Patient Forecast',
    ),
    BusinessType.jewellery: DashboardBusinessConfig(
      revenueCardLabel: 'Jewellery Sales',
      kpi2Label: 'Gold Rate Alerts',
      kpi3Label: 'Custom Orders',
      chartYAxisLabel: '₹ Revenue',
      invoiceTableName: 'Jewellery Invoice',
      forecastLabel: 'Metal Forecast',
    ),
    BusinessType.service: DashboardBusinessConfig(
      revenueCardLabel: 'Service Revenue',
      kpi2Label: 'Open Jobs',
      kpi3Label: 'Pending Quotes',
      chartYAxisLabel: '₹ Revenue',
      invoiceTableName: 'Service Invoice',
      forecastLabel: 'Job Forecast',
    ),
    BusinessType.petrolPump: DashboardBusinessConfig(
      revenueCardLabel: 'Fuel Sales',
      kpi2Label: 'Tank Levels',
      kpi3Label: 'Shift Settlement',
      chartYAxisLabel: '₹ Revenue',
      invoiceTableName: 'Fuel Invoice',
      forecastLabel: 'Fuel Forecast',
    ),
    BusinessType.vegetablesBroker: DashboardBusinessConfig(
      revenueCardLabel: 'Mandi Sales',
      kpi2Label: 'Lot Pending',
      kpi3Label: 'Commission Due',
      chartYAxisLabel: '₹ Revenue',
      invoiceTableName: 'Mandi Bill',
      forecastLabel: 'Mandi Forecast',
    ),
  };
}
