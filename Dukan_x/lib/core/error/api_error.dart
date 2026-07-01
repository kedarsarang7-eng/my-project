// ============================================================================
// STRUCTURED API ERROR HANDLING (BUG-038)
// ============================================================================
// Provides structured error parsing for API responses
// Converts DioError, network errors, and HTTP errors into user-friendly messages

import 'package:dio/dio.dart';

/// Structured API Error Model
/// 
/// BUG-038: Replaces generic `e.toString()` with structured error handling
class ApiError {
  final String code;
  final String message;
  final String? userMessage;
  final int? statusCode;
  final dynamic originalError;
  final Map<String, dynamic>? details;

  ApiError({
    required this.code,
    required this.message,
    this.userMessage,
    this.statusCode,
    this.originalError,
    this.details,
  });

  /// Parse from DioError with structure
  factory ApiError.fromDioError(DioException error) {
    final response = error.response;
    
    // Handle different DioError types
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiError(
          code: 'TIMEOUT',
          message: 'Request timed out',
          userMessage: 'The server is taking too long to respond. Please try again.',
          statusCode: null,
          originalError: error,
        );
        
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        if (error.message?.contains('SocketException') == true) {
          return ApiError(
            code: 'NO_INTERNET',
            message: 'No internet connection',
            userMessage: 'Please check your internet connection and try again.',
            statusCode: null,
            originalError: error,
          );
        }
        return ApiError(
          code: 'CONNECTION_ERROR',
          message: 'Connection error: ${error.message}',
          userMessage: 'Unable to connect to server. Please try again later.',
          statusCode: null,
          originalError: error,
        );
        
      case DioExceptionType.badResponse:
        final statusCode = response?.statusCode;
        final data = response?.data;
        
        // Try to parse server error message
        String serverMessage = 'An error occurred';
        if (data is Map) {
          serverMessage = data['message'] ?? data['error'] ?? serverMessage;
        }
        
        // Map status codes to user-friendly messages
        String userMessage;
        switch (statusCode) {
          case 400:
            userMessage = 'Invalid request. Please check your input.';
            break;
          case 401:
            userMessage = 'Session expired. Please log in again.';
            break;
          case 403:
            userMessage = 'You don\'t have permission to perform this action.';
            break;
          case 404:
            userMessage = 'The requested resource was not found.';
            break;
          case 422:
            userMessage = 'Validation failed. Please check your input.';
            break;
          case 429:
            userMessage = 'Too many requests. Please wait a moment and try again.';
            break;
          case 500:
          case 502:
          case 503:
          case 504:
            userMessage = 'Server error. Please try again later.';
            break;
          default:
            userMessage = 'Something went wrong. Please try again.';
        }
        
        return ApiError(
          code: 'HTTP_${statusCode ?? 'UNKNOWN'}',
          message: 'HTTP $statusCode: $serverMessage',
          userMessage: userMessage,
          statusCode: statusCode,
          originalError: error,
          details: data is Map ? Map<String, dynamic>.from(data) : null,
        );
        
      case DioExceptionType.cancel:
        return ApiError(
          code: 'CANCELLED',
          message: 'Request was cancelled',
          userMessage: 'The request was cancelled.',
          statusCode: null,
          originalError: error,
        );
        
      case DioExceptionType.badCertificate:
        return ApiError(
          code: 'CERTIFICATE_ERROR',
          message: 'SSL certificate error',
          userMessage: 'Security certificate error. Please contact support.',
          statusCode: null,
          originalError: error,
        );
    }
  }

  /// Parse from generic error
  factory ApiError.fromError(dynamic error) {
    if (error is DioException) {
      return ApiError.fromDioError(error);
    }
    
    if (error is Exception) {
      return ApiError(
        code: 'GENERIC_ERROR',
        message: error.toString(),
        userMessage: 'An unexpected error occurred. Please try again.',
        originalError: error,
      );
    }
    
    return ApiError(
      code: 'UNKNOWN',
      message: error?.toString() ?? 'Unknown error',
      userMessage: 'Something went wrong. Please try again.',
      originalError: error,
    );
  }

  @override
  String toString() => 'ApiError(code: $code, message: $message, statusCode: $statusCode)';
}

/// Extension for easier error handling
extension ApiErrorExtension on Object {
  ApiError toApiError() => ApiError.fromError(this);
}
