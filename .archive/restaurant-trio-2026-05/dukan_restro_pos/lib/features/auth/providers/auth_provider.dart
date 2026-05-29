import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/cognito_auth_service.dart';

part 'auth_provider.g.dart';

@riverpod
class AuthState extends _$AuthState {
  @override
  FutureOr<bool> build() async {
    final authService = ref.watch(authServiceProvider);
    return await authService.isAuthenticated();
  }

  Future<void> login(String username, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final authService = ref.read(authServiceProvider);
      await authService.login(username, password);
      return true;
    });
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final authService = ref.read(authServiceProvider);
      await authService.logout();
      return false;
    });
  }
}
