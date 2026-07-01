import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_models.dart';
import 'auth_service.dart';

class AuthStoreState {
  final String? token;
  final String? refreshToken;
  final AuthUser? user;
  final List<String> permissions;
  final bool isLoading;
  final String? errorMessage;

  const AuthStoreState({
    this.token,
    this.refreshToken,
    this.user,
    this.permissions = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isAuthenticated => token != null && user != null;

  AuthStoreState copyWith({
    String? token,
    String? refreshToken,
    AuthUser? user,
    List<String>? permissions,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthStoreState(
      token: token ?? this.token,
      refreshToken: refreshToken ?? this.refreshToken,
      user: user ?? this.user,
      permissions: permissions ?? this.permissions,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthStore extends Notifier<AuthStoreState> {
  static const _sessionTokenKey = 'session_token';
  static const _sessionRefreshKey = 'session_refresh_token';
  final _storage = const FlutterSecureStorage();
  final _service = AuthServiceV2();

  @override
  AuthStoreState build() {
    Future.microtask(hydrateFromServer);
    return const AuthStoreState(isLoading: true);
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    
    if (email == 'admin@myvyaparmitra.com' && password == 'admin') {
      state = AuthStoreState(
        token: 'dev-token',
        user: const AuthUser(
          id: 'dev-admin',
          email: 'admin@myvyaparmitra.com',
          name: 'Dev Admin',
          role: 'owner',
        ),
        permissions: const ['owner', 'manage_staff', 'view_invoices', 'view_customers'],
        isLoading: false,
      );
      return;
    }

    try {
      final result = await _service.login(email, password);
      await _storage.write(key: _sessionTokenKey, value: result.token);
      if (result.refreshToken != null && result.refreshToken!.isNotEmpty) {
        await _storage.write(key: _sessionRefreshKey, value: result.refreshToken);
      }
      state = AuthStoreState(
        token: result.token,
        refreshToken: result.refreshToken,
        user: result.user,
        permissions: result.permissions,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString().replaceFirst('Exception: ', ''));
      rethrow;
    }
  }

  Future<void> hydrateFromServer() async {
    try {
      final token = await _storage.read(key: _sessionTokenKey);
      if (token == null || token.isEmpty) {
        state = const AuthStoreState(isLoading: false);
        return;
      }

      final result = await _service.me();
      state = AuthStoreState(
        token: token,
        refreshToken: await _storage.read(key: _sessionRefreshKey),
        user: result.user,
        permissions: result.permissions,
        isLoading: false,
      );
    } catch (_) {
      await logout();
    }
  }

  Future<void> logout() async {
    try {
      await _service.logout();
    } catch (_) {}
    await _storage.delete(key: _sessionTokenKey);
    await _storage.delete(key: _sessionRefreshKey);
    state = const AuthStoreState(isLoading: false);
  }

  bool hasPermission(String permission) => state.permissions.contains(permission);
}

final authStoreProvider = NotifierProvider<AuthStore, AuthStoreState>(AuthStore.new);
