import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';
import '../../features/petrol_pump/providers/license_provider.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthNotifier(authRepository, ref);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final Ref ref;

  AuthNotifier(this._authRepository, this.ref) : super(AuthState.initial()) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    state = state.copyWith(isLoading: true);

    try {
      final isAuthenticated = await _authRepository.isAuthenticated();
      if (isAuthenticated) {
        final userId = await _authRepository.getCurrentUserId();
        final tenantId = await _authRepository.getCurrentTenantId();
        state = state.copyWith(
          isAuthenticated: true,
          userId: userId,
          tenantId: tenantId,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // ENHANCED: Get full login response with license data
      final loginResponse = await _authRepository.signIn(email, password);
      final userId = await _authRepository.getCurrentUserId();
      final tenantId = await _authRepository.getCurrentTenantId();
      
      // Pass license data to LicenseProvider
      final licenseNotifier = ref.read(licenseProvider.notifier);
      licenseNotifier.loadLicenseFromLoginResponse(loginResponse);
      
      state = state.copyWith(
        isAuthenticated: true,
        userId: userId,
        tenantId: tenantId,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> signUp(String name, String email, String password, String role, String? tenantId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _authRepository.signUp(name, email, password, role, tenantId);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> confirmSignUp(String email, String code) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _authRepository.confirmSignUp(email, code);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);

    try {
      await _authRepository.signOut();
      state = AuthState.initial();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? userId;
  final String? tenantId;
  final String? error;

  AuthState({
    required this.isAuthenticated,
    required this.isLoading,
    this.userId,
    this.tenantId,
    this.error,
  });

  factory AuthState.initial() {
    return AuthState(
      isAuthenticated: false,
      isLoading: false,
    );
  }

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? userId,
    String? tenantId,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      userId: userId ?? this.userId,
      tenantId: tenantId ?? this.tenantId,
      error: error ?? this.error,
    );
  }
}