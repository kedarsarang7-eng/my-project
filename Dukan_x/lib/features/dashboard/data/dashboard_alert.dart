class DashboardAlert {
  final String title;
  final String message;
  final AlertType type;
  final AlertSeverity severity;
  final String? relatedId; // productId, billId, etc.
  final dynamic data; // Extra data if needed

  DashboardAlert({
    required this.title,
    required this.message,
    required this.type,
    required this.severity,
    this.relatedId,
    this.data,
  });
}

enum AlertType { stock, payment, tax, system }

enum AlertSeverity { low, medium, high, critical }
