import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/staff_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({AuthRemoteDataSource? remoteDataSource})
      : remoteDataSource = remoteDataSource ?? AuthRemoteDataSourceImpl();

  @override
  Future<Either<Failure, StaffUser>> loginWithCredentials({
    required String staffId,
    required String password,
  }) async {
    try {
      final userModel = await remoteDataSource.loginWithCredentials(
        staffId: staffId,
        password: password,
      );
      return Right(userModel.toEntity());
    } on ServerFailure catch (e) {
      return Left(e);
    } on NetworkFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(message: 'Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, StaffUser>> loginWithBiometrics() async {
    try {
      final userModel = await remoteDataSource.loginWithBiometrics();
      return Right(userModel.toEntity());
    } on ServerFailure catch (e) {
      return Left(e);
    } on NetworkFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(ServerFailure(message: 'Biometric login failed: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await remoteDataSource.logout();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Logout failed: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> forgotPassword({required String staffId}) async {
    try {
      await remoteDataSource.forgotPassword(staffId: staffId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Forgot password request failed: $e'));
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    return await remoteDataSource.isLoggedIn();
  }

  @override
  Future<StaffUser?> getCurrentUser() async {
    try {
      final userModel = await remoteDataSource.getCurrentUser();
      return userModel?.toEntity();
    } catch (e) {
      return null;
    }
  }
}
