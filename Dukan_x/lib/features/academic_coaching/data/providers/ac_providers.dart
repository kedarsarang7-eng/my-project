import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/ac_repository.dart';
import '../../../../core/di/service_locator.dart';

/// Provider for the Academic Coaching repository
final acRepositoryProvider = Provider<AcRepository>((ref) {
  return sl<AcRepository>();
});
