import 'dart:convert';
import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';

class AuthUser {
  final String sub;
  final String email;
  final String name;
  final String role;
  final String tenantId;

  AuthUser({required this.sub, required this.email, required this.name, required this.role, required this.tenantId});

  factory AuthUser.fromToken(String token) {
    final parts = token.split('.');
    final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map<String, dynamic>;
    return AuthUser(sub: payload['sub'] ?? '', email: payload['email'] ?? '', name: payload['name'] ?? payload['email'] ?? '', role: (payload['custom:role'] ?? 'admin').toString().toLowerCase(), tenantId: payload['custom:tenantId'] ?? '');
  }

  bool get isAdmin => role == 'admin' || role == 'principal' || role == 'owner';
}

class AuthState {
  final bool isLoading;
  final AuthUser? user;
  final String? error;
  bool get isAuthenticated => user != null;
  const AuthState({this.isLoading = false, this.user, this.error});
  AuthState copyWith({bool? isLoading, AuthUser? user, String? error, bool clearError = false}) =>
      AuthState(isLoading: isLoading ?? this.isLoading, user: user ?? this.user, error: clearError ? null : (error ?? this.error));
}

class AuthService {
  final _storage = const FlutterSecureStorage();
  late final CognitoUserPool _pool;
  AuthService() { _pool = CognitoUserPool(AppConfig.cognitoUserPoolId, AppConfig.cognitoClientId); }

  Future<AuthUser> signIn(String email, String password) async {
    final user = CognitoUser(email, _pool);
    final session = await user.authenticateUser(AuthenticationDetails(username: email, password: password));
    final token = session!.idToken.jwtToken!;
    await _storage.write(key: 'id_token', value: token);
    await _storage.write(key: 'access_token', value: session.accessToken.jwtToken!);
    await _storage.write(key: 'refresh_token', value: session.refreshToken!.token!);
    final authUser = AuthUser.fromToken(token);
    if (!authUser.isAdmin) throw Exception('Access denied: admin credentials required.');
    return authUser;
  }

  Future<AuthUser?> restoreSession() async {
    final token = await _storage.read(key: 'id_token');
    if (token == null) return null;
    try { return AuthUser.fromToken(token); } catch (_) { return null; }
  }

  Future<void> signOut() async => _storage.deleteAll();
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier(ref.read(authServiceProvider)));

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _service;
  AuthNotifier(this._service) : super(const AuthState()) { _restore(); }

  Future<void> _restore() async { state = state.copyWith(isLoading: true); final user = await _service.restoreSession(); state = AuthState(user: user); }
  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try { state = AuthState(user: await _service.signIn(email, password)); }
    catch (e) { state = state.copyWith(isLoading: false, error: e.toString().replaceFirst('Exception: ', '')); }
  }
  Future<void> signOut() async { await _service.signOut(); state = const AuthState(); }
  void clearError() => state = state.copyWith(clearError: true);
}
