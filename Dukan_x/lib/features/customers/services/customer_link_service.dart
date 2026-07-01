import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/error/error_handler.dart';

class CustomerLinkService {
  final AppDatabase database;
  final ErrorHandler errorHandler;

  CustomerLinkService({required this.database, required this.errorHandler});

  /// Generates a new secure link token for the customer
  /// Returns the full invite URL
  Future<String?> generateLink(String customerId) async {
    final result = await errorHandler.runSafe(() async {
      // 1. Generate a secure random token
      final token = const Uuid().v4();
      final now = DateTime.now();

      // 2. Calculate expiry (e.g., 7 days or unlimited - let's do 30 days for now)
      final expiresAt = now.add(const Duration(days: 30));

      // 3. Update Database
      await (database.update(
        database.customers,
      )..where((t) => t.id.equals(customerId))).write(
        CustomersCompanion(
          linkToken: Value(token),
          linkExpiresAt: Value(expiresAt),
          linkStatus: const Value('PENDING'),
          updatedAt: Value(now),
        ),
      );

      // 4. Construct URL
      // Format: https://dukanx.com/link?c={customerId}&t={token}
      // In production, this would be a Firebase Dynamic Link or specific Deep Link
      // For now, we return a structured string that can be shared
      return "https://dukanx.com/connect?id=$customerId&token=$token";
    }, 'CustomerLinkService.generateLink');
    return result.data;
  }

  /// Revokes the current link access
  Future<bool> revokeLink(String customerId) async {
    final result = await errorHandler.runSafe(() async {
      await (database.update(
        database.customers,
      )..where((t) => t.id.equals(customerId))).write(
        CustomersCompanion(
          linkToken: const Value(null),
          linkExpiresAt: const Value(null),
          linkStatus: const Value('UNLINKED'),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return true;
    }, 'CustomerLinkService.revokeLink');
    return result.data ?? false;
  }

  /// Get current link status
  Future<Map<String, dynamic>> getLinkStatus(String customerId) async {
    final customer = await (database.select(
      database.customers,
    )..where((t) => t.id.equals(customerId))).getSingleOrNull();

    if (customer == null) return {};

    return {
      'status': customer.linkStatus,
      'token': customer.linkToken,
      'expiresAt': customer.linkExpiresAt,
      'isExpired': customer.linkExpiresAt?.isBefore(DateTime.now()) ?? true,
    };
  }
}
