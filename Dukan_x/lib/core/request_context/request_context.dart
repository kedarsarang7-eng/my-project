// ============================================================================
// REQUEST CONTEXT - RID (Request ID) System Implementation
// ============================================================================
// Format: {tenantId}-{timestamp_ms}-{uuid_v4_short}
// Example: tenant_abc-1715000000000-f3a9b2

import 'package:uuid/uuid.dart';

/// Request Context for tracking operations across the system
class RequestContext {
  final String requestId;
  final String tenantId;
  final String? userId;
  final DateTime startTime;
  final String? sessionRid;
  
  RequestContext._({
    required this.requestId,
    required this.tenantId,
    this.userId,
    required this.startTime,
    this.sessionRid,
  });
  
  /// Generate a new RID at the point of user action
  factory RequestContext.generate({
    required String tenantId,
    String? userId,
    String? sessionRid,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uuidShort = const Uuid().v4().substring(0, 6);
    final requestId = '$tenantId-$timestamp-$uuidShort';
    
    return RequestContext._(
      requestId: requestId,
      tenantId: tenantId,
      userId: userId,
      startTime: DateTime.now(),
      sessionRid: sessionRid,
    );
  }
  
  /// Create from existing RID (when inheriting from parent context)
  factory RequestContext.inherit({
    required String requestId,
    required String tenantId,
    String? userId,
    String? sessionRid,
  }) {
    return RequestContext._(
      requestId: requestId,
      tenantId: tenantId,
      userId: userId,
      startTime: DateTime.now(),
      sessionRid: sessionRid,
    );
  }
  
  /// Create child context for WebSocket messages
  RequestContext createChildContext() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uuidShort = const Uuid().v4().substring(0, 6);
    final childRid = '$tenantId-$timestamp-$uuidShort';
    
    return RequestContext._(
      requestId: childRid,
      tenantId: tenantId,
      userId: userId,
      startTime: DateTime.now(),
      sessionRid: sessionRid ?? requestId,
    );
  }
  
  /// Get shortened RID for user-facing display (last 6 chars)
  String get shortReference => requestId.split('-').last;
  
  /// Get duration since context creation
  Duration get duration => DateTime.now().difference(startTime);
  
  /// Convert to headers map for HTTP requests
  Map<String, String> toHeaders() {
    return {
      'X-Request-ID': requestId,
      'X-Tenant-ID': tenantId,
      'X-User-ID': ?userId,
      'X-Session-RID': ?sessionRid,
    };
  }
  
  /// Convert to JSON for logging
  Map<String, dynamic> toLogMap() {
    return {
      'requestId': requestId,
      'tenantId': tenantId,
      'userId': userId,
      'startTime': startTime.toIso8601String(),
      'duration': duration.inMilliseconds,
      'sessionRid': sessionRid,
    };
  }
  
  @override
  String toString() => 'RequestContext(requestId: $requestId, tenant: $tenantId)';
}

/// Extension for easy access
extension RequestContextExtension on RequestContext {
  /// Create error display message with reference
  String get userErrorReference => 'Reference: $shortReference';
}
