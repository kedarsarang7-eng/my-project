import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_store.dart';

final hasPermissionProvider = Provider.family<bool, String>((ref, permission) {
  final authState = ref.watch(authStoreProvider);
  return authState.permissions.contains(permission);
});
