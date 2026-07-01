import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/alert_service.dart';

import '../../../../core/repository/products_repository.dart';
import '../../../../core/repository/bills_repository.dart';
import '../../../../services/auth_service.dart';
import '../../domain/entities/alert.dart';
import '../../../billing/data/repositories/billing_repository_impl.dart';

import '../../../../core/di/service_locator.dart';

/// Alert service provider with proper repository dependencies
/// Now includes core BillsRepository for expiry alert checking
final alertServiceProvider = Provider<AlertService>((ref) {
  final billingRepo = BillingRepositoryImpl(localStorageService);
  final productRepo = sl<ProductsRepository>();

  // Try to get core BillsRepository for expiry alerts (optional)
  BillsRepository? coreBillsRepo;
  try {
    coreBillsRepo = sl<BillsRepository>();
  } catch (_) {
    // If not registered, expiry alerts will be skipped
  }

  return AlertService(billingRepo, productRepo, coreBillsRepo);
});

final activeAlertsProvider = FutureProvider((ref) async {
  final service = ref.watch(alertServiceProvider);
  final authService = sl<AuthService>();
  final userId = authService.currentUser?.uid;

  if (userId == null) return <Alert>[];

  return service.checkAlerts(userId);
});
