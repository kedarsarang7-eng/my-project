import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/staff_user.dart';
import '../../domain/usecases/biometric_login_usecase.dart';
import '../../data/datasources/auth_remote_datasource_provider.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error, newPasswordRequired }

class AuthState {
  final AuthStatus status;
  final StaffUser? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({AuthStatus? status, StaffUser? user, String? errorMessage}) {
    return AuthState(
      status: status ?? this.status,
      user:   user   ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(const AuthState());

  Future<void> login({required String staffId, required String password}) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final dataSource = _ref.read(authRemoteDataSourceProvider);
      final user = await dataSource.loginWithCredentials(
        staffId: staffId,
        password: password,
      );

      state = AuthState(
        status: AuthStatus.authenticated,
        user: user.toEntity(),
      );
    } on Exception catch (e) {
      final errorMessage = e.toString();

      if (errorMessage.contains('NEW_PASSWORD_REQUIRED') ||
          errorMessage.contains('new password')) {
        state = const AuthState(
          status: AuthStatus.newPasswordRequired,
        );
      } else {
        state = AuthState(
          status: AuthStatus.error,
          errorMessage: errorMessage.replaceAll('Exception: ', ''),
        );
      }
    }
  }

  Future<void> biometricLogin() async {
    state = state.copyWith(status: AuthStatus.loading);

    final useCase = _ref.read(biometricLoginUseCaseProvider);
    final result  = await useCase();

    result.fold(
      (failure) => state = AuthState(
        status: AuthStatus.error,
        errorMessage: failure.message,
      ),
      (user) => state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
      ),
    );
  }

  Future<bool> completeNewPassword({
    required String staffId,
    required String temporaryPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final dataSource = _ref.read(authRemoteDataSourceProvider);
      final user = await dataSource.completeNewPassword(
        staffId: staffId,
        temporaryPassword: temporaryPassword,
        newPassword: newPassword,
      );

      state = AuthState(
        status: AuthStatus.authenticated,
        user: user.toEntity(),
      );
      return true;
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(status: AuthStatus.unauthenticated);
  }

  Future<void> signOut() async {
    state = const AuthState(status: AuthStatus.initial);
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref),
);
