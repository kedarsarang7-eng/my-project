import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../context/permission_context.dart';

class RoleGuard extends ConsumerWidget {
  final List<String> roles;
  final Widget child;
  final Widget? fallback;

  const RoleGuard({
    super.key,
    required this.roles,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(permissionProvider);
    if (roles.contains(state.role)) {
      return child;
    }
    return fallback ?? const SizedBox.shrink();
  }
}
