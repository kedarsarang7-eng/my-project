import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../context/permission_context.dart';

PermissionState usePermission(WidgetRef ref) {
  return ref.watch(permissionProvider);
}
