import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../entities/staff_user.dart';
import '../repositories/auth_repository.dart';

class BiometricLoginUseCase {
  final AuthRepository repository;

  BiometricLoginUseCase(this.repository);

  Future<Either<Failure, StaffUser>> call() async {
    return await repository.loginWithBiometrics();
  }
}

final biometricLoginUseCaseProvider = Provider<BiometricLoginUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return BiometricLoginUseCase(repository);
});
