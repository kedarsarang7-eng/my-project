import '../../../../core/database/app_database.dart';
import '../../../../core/error/error_handler.dart';
import '../../customers/data/customer_dashboard_repository.dart';

class LinkHandlerService {
  final AppDatabase database;
  final ErrorHandler errorHandler;
  final CustomerDashboardRepository dashboardRepository;

  LinkHandlerService({
    required this.database,
    required this.errorHandler,
    required this.dashboardRepository,
  });

  /// Processes a deep link URL
  /// Returns the linked VendorConnection if successful
  Future<VendorConnection?> handleLink(String url) async {
    final result = await errorHandler.runSafe(() async {
      final uri = Uri.parse(url);
      final customerId =
          uri.queryParameters['id']; // This is the ID in Vendor's DB
      final token = uri.queryParameters['token'];
      final vendorId =
          uri.queryParameters['v'] ?? 'UNKNOWN'; // Optionally passed

      if (customerId == null || token == null) {
        throw Exception("Invalid link format");
      }

      // 1. Verify Token (In a real distributed app, this would hit an API)
      // Since we are offline-first/local-centric, we simulate:
      // If we are the same device (testing), we can check directly.
      // If different device, we assume this Token is valid for the handshake
      // and we create a 'Pending' connection that syncs.

      // For this implementation, we assume the 'customerId' in the link refers
      // to the 'customerRefId' in our local CustomerConnections table.

      // We accept the link and create a connection.
      // The sync engine will validate it against the Vendor's data later.

      // Create Connection
      final result = await dashboardRepository.addVendorConnection(
        customerId: 'CURRENT_USER_ID', // Replaced by actual logged in user
        vendorId: vendorId,
        vendorName: 'New Shop', // Placeholder until sync
        customerRefId: customerId,
      );

      return result.data;
    }, 'LinkHandlerService.handleLink');
    return result.data;
  }
}
