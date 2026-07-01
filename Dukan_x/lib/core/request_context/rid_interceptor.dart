// ============================================================================
// RID INTERCEPTOR - Injects X-Request-ID into all HTTP requests
// ============================================================================

import 'package:dio/dio.dart';
import '../services/logger_service.dart';
import 'request_context.dart';

/// Dio interceptor that injects X-Request-ID header
class RidInterceptor extends Interceptor {
  final RequestContext? Function() getContext;
  
  RidInterceptor({required this.getContext});
  
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final context = getContext();
    
    if (context != null) {
      // Inject RID headers
      options.headers.addAll(context.toHeaders());
      
      // Log request with RID
      LoggerService.d('RID', '[RID: ${context.shortReference}] â†’ ${options.method} ${options.path}');
    } else {
      // No context - generate emergency RID for this request
      LoggerService.d('RID', '[RID: WARNING] No request context found for ${options.path}');
      
      // Generate emergency RID
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final emergencyRid = 'emergency-$timestamp-${100000 + DateTime.now().millisecond}';
      options.headers['X-Request-ID'] = emergencyRid;
    }
    
    handler.next(options);
  }
  
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final rid = response.requestOptions.headers['X-Request-ID'];
    final shortRef = rid?.toString().split('-').last ?? 'unknown';
    
    LoggerService.d('RID', '[RID: $shortRef] â† ${response.statusCode} ${response.requestOptions.path}');
    
    // Extract correlation ID from response if present
    final correlationId = response.headers.value('X-Correlation-ID');
    if (correlationId != null) {
      LoggerService.d('RID', '[RID: $shortRef] Correlation: $correlationId');
    }
    
    handler.next(response);
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final rid = err.requestOptions.headers['X-Request-ID'];
    final shortRef = rid?.toString().split('-').last ?? 'unknown';
    
    LoggerService.d('RID', '[RID: $shortRef] âœ— ERROR: ${err.type} ${err.message}');
    
    // Log detailed error info
    if (err.response != null) {
      final errorData = err.response?.data;
      final errorRequestId = errorData?['error']?['requestId'];
      
      if (errorRequestId != null) {
        LoggerService.d('RID', '[RID: $shortRef] Server returned requestId: $errorRequestId');
      }
    }
    
    handler.next(err);
  }
}
