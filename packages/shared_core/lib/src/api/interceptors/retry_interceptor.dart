import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Retry Interceptor - Handles 429 Rate Limit and network errors
/// 
/// WHY: API Gateway and Lambda rate limiters return 429 when limits exceeded.
/// This interceptor implements exponential backoff and automatic retry.
/// 
/// Algorithm:
/// - On 429: Read Retry-After header, wait, then retry
/// - On network error: Exponential backoff with jitter
/// - Max 3 retries to prevent infinite loops
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int retries;
  final List<Duration> retryDelays;

  RetryInterceptor({
    required this.dio,
    this.retries = 3,
    this.retryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ],
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Don't retry if explicitly cancelled
    if (err.type == DioExceptionType.cancel) {
      handler.next(err);
      return;
    }

    final extra = err.requestOptions.extra;
    final attempt = (extra['retry_attempt'] as int?) ?? 0;

    // Check if we should retry
    if (!_shouldRetry(err, attempt)) {
      handler.next(err);
      return;
    }

    // Calculate delay
    final delay = _calculateDelay(err, attempt);

    debugPrint(
      '[Retry] Attempt ${attempt + 1}/$retries for ${err.requestOptions.path} '
      '- waiting ${delay.inMilliseconds}ms',
    );

    // Wait before retry
    await Future.delayed(delay);

    // Update attempt count
    err.requestOptions.extra['retry_attempt'] = attempt + 1;

    try {
      // Retry the request
      final response = await dio.fetch(err.requestOptions);
      handler.resolve(response);
    } on DioException catch (e) {
      // If retry also failed, pass the error
      handler.next(e);
    }
  }

  /// Determine if request should be retried
  bool _shouldRetry(DioException error, int attempt) {
    if (attempt >= retries) return false;

    // Retry on 429 Too Many Requests
    if (error.response?.statusCode == 429) return true;

    // Retry on 5xx server errors
    final statusCode = error.response?.statusCode;
    if (statusCode != null && statusCode >= 500 && statusCode < 600) return true;

    // Retry on network errors
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      default:
        return false;
    }
  }

  /// Calculate delay with exponential backoff and jitter
  Duration _calculateDelay(DioException error, int attempt) {
    // For 429, respect Retry-After header
    if (error.response?.statusCode == 429) {
      final retryAfter = error.response?.headers.value('retry-after');
      if (retryAfter != null) {
        final seconds = int.tryParse(retryAfter);
        if (seconds != null) {
          return Duration(seconds: seconds);
        }
      }
      // Fallback: use exponential backoff
    }

    // Get base delay for this attempt
    final baseDelay = retryDelays[attempt.clamp(0, retryDelays.length - 1)];

    // Add jitter (±15%) to prevent thundering herd
    final jitter = 0.85 + (DateTime.now().millisecond % 30) / 100;
    final actualDelay = baseDelay * jitter;

    return Duration(milliseconds: actualDelay.inMilliseconds);
  }
}
