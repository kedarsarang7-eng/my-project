import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../context/permission_context.dart';

class CanAccess extends ConsumerWidget {
  final String module;
  final String action;
  final Widget child;
  final Widget? fallback;

  const CanAccess({
    super.key,
    required this.module,
    required this.action,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(permissionProvider);
    if (state.can(module, action)) {
      return child;
    }
    return fallback ?? const SizedBox.shrink();
  }
}
