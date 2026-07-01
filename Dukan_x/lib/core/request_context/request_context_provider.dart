// ============================================================================
// REQUEST CONTEXT PROVIDER - Riverpod State Management
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'request_context.dart';

/// Current request context - generates new RID for each user action
final requestContextProvider =
    NotifierProvider<RequestContextNotifier, RequestContext?>(
      RequestContextNotifier.new,
    );

class RequestContextNotifier extends Notifier<RequestContext?> {
  @override
  RequestContext? build() => null;

  /// Generate new context for user action
  void startNewRequest({required String tenantId, String? userId}) {
    state = RequestContext.generate(tenantId: tenantId, userId: userId);
  }

  /// Set context from existing (e.g., inherited from background sync)
  void setContext(RequestContext context) {
    state = context;
  }

  /// Clear context after request completes
  void clear() {
    state = null;
  }

  /// Create child context for WebSocket
  RequestContext? createChildContext() {
    if (state == null) return null;
    return state!.createChildContext();
  }
}
