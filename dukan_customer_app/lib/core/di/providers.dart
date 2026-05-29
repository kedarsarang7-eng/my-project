import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx_shared/dukanx_shared.dart';
import '../../config/app_config.dart';
import '../auth/customer_auth_service.dart';
import '../auth/customer_session_manager.dart';

export '../auth/customer_session_manager.dart'
    show customerSessionProvider, secureTokenStoreProvider;
export '../auth/customer_auth_service.dart' show customerAuthServiceProvider;
export '../../config/app_config.dart' show appConfigProvider;

/// Central provider for CustomerApiClient, wired to the session's token store
/// and the auth service's refresh callback.
final customerApiClientProvider = Provider<CustomerApiClient>((ref) {
  final config = ref.read(appConfigProvider);
  final tokenStore = ref.read(secureTokenStoreProvider);
  final authService = ref.read(customerAuthServiceProvider);

  return CustomerApiClient(
    baseUrl: config.apiBaseUrl,
    tokenStore: tokenStore,
    onRefreshToken: (refreshToken) async {
      final data = await authService.refreshTokens(refreshToken);
      return data?.accessToken;
    },
  );
});
