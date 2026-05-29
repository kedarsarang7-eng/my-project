import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx_shared/dukanx_shared.dart';
import 'customer_auth_service.dart';

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final TokenData? tokenData;
  final CustomerProfile? profile;
  final String? error;

  const AuthState({
    required this.status,
    this.tokenData,
    this.profile,
    this.error,
  });

  const AuthState.loading() : this(status: AuthStatus.loading);
  const AuthState.unauthenticated({String? error})
      : this(status: AuthStatus.unauthenticated, error: error);
  const AuthState.authenticated(TokenData tokenData, {CustomerProfile? profile})
      : this(
          status: AuthStatus.authenticated,
          tokenData: tokenData,
          profile: profile,
        );

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
  String? get accessToken => tokenData?.accessToken;

  AuthState copyWith({CustomerProfile? profile}) {
    return AuthState(
      status: status,
      tokenData: tokenData,
      profile: profile ?? this.profile,
      error: error,
    );
  }
}

class CustomerSessionManager extends AsyncNotifier<AuthState> {
  late CustomerAuthService _authService;
  late SecureTokenStore _tokenStore;

  @override
  Future<AuthState> build() async {
    _authService = ref.read(customerAuthServiceProvider);
    _tokenStore = ref.read(secureTokenStoreProvider);
    return _restoreSession();
  }

  Future<AuthState> _restoreSession() async {
    final tokenData = await _tokenStore.read();
    if (tokenData == null) return const AuthState.unauthenticated();

    if (tokenData.isExpired) {
      final refreshed = await _authService.refreshTokens(tokenData.refreshToken);
      if (refreshed == null) {
        await _tokenStore.clear();
        return const AuthState.unauthenticated();
      }
      return AuthState.authenticated(refreshed);
    }

    return AuthState.authenticated(tokenData);
  }

  Future<void> signIn(String phone, String otp) async {
    state = const AsyncValue.loading();
    try {
      final tokenData = await _authService.signInWithOtp(phone: phone, otp: otp);
      await _tokenStore.write(tokenData);
      state = AsyncValue.data(AuthState.authenticated(tokenData));
    } catch (e) {
      state = AsyncValue.data(
        AuthState.unauthenticated(error: _friendlyError(e.toString())),
      );
    }
  }

  Future<void> signOut() async {
    final tokenData = await _tokenStore.read();
    if (tokenData != null) {
      await _authService.signOut(accessToken: tokenData.accessToken);
    }
    await _tokenStore.clear();
    state = const AsyncValue.data(AuthState.unauthenticated());
  }

  Future<void> updateProfile(CustomerProfile profile) async {
    final current = state.valueOrNull;
    if (current == null || !current.isAuthenticated) return;
    state = AsyncValue.data(current.copyWith(profile: profile));
  }

  String _friendlyError(String raw) {
    if (raw.contains('CodeMismatchException')) return 'Incorrect OTP. Please try again.';
    if (raw.contains('ExpiredCodeException')) return 'OTP expired. Request a new one.';
    if (raw.contains('UserNotFoundException')) return 'Phone number not registered.';
    if (raw.contains('TooManyRequestsException')) return 'Too many attempts. Try again later.';
    if (raw.contains('OFFLINE')) return 'No internet connection.';
    return 'Sign in failed. Please try again.';
  }
}

final secureTokenStoreProvider = Provider<SecureTokenStore>((_) => SecureTokenStore());

final customerSessionProvider =
    AsyncNotifierProvider<CustomerSessionManager, AuthState>(
  CustomerSessionManager.new,
);
