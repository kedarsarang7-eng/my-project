import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../entities/staff_user.dart';

abstract class AuthRepository {
  Future<Either<Failure, StaffUser>> loginWithCredentials({
    required String staffId,
    required String password,
  });

  Future<Either<Failure, StaffUser>> loginWithBiometrics();

  Future<Either<Failure, void>> logout();

  Future<Either<Failure, void>> forgotPassword({required String staffId});

  Future<bool> isLoggedIn();

  Future<StaffUser?> getCurrentUser();
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});
