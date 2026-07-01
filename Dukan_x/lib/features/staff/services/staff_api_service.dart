import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../data/models/staff_profile_model.dart';

/// Staff API Service
/// Handles all API calls related to staff management
class StaffApiService {
  final Dio _dio;

  StaffApiService({Dio? dio}) : _dio = dio ?? DioClient.instance;

  /// Create new staff member
  Future<CreateStaffResponse> createStaff(CreateStaffRequest request) async {
    try {
      final response = await _dio.post(
        '/staff',
        data: request.toJson(),
      );

      if (response.statusCode == 201 && response.data['success'] == true) {
        return CreateStaffResponse.fromJson(response.data['data']);
      } else {
        throw StaffApiException(
          message: response.data['message'] ?? 'Failed to create staff',
          code: response.data['error'] ?? 'CREATE_FAILED',
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e, 'create staff');
    }
  }

  /// List all staff members with optional filters
  Future<List<StaffListItemModel>> listStaff({
    StaffFilters? filters,
    int page = 1,
    int limit = 20,
    String? lastKey,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
        'lastKey': ?lastKey,
      };

      if (filters != null) {
        queryParams.addAll(filters.toQueryParams());
      }

      final response = await _dio.get(
        '/staff',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        final List<dynamic> staffList = data is List ? data : (data['staff'] ?? []);
        return staffList.map((e) => StaffListItemModel.fromJson(e)).toList();
      } else {
        throw StaffApiException(
          message: response.data['message'] ?? 'Failed to load staff list',
          code: response.data['error'] ?? 'LIST_FAILED',
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e, 'load staff list');
    }
  }

  /// Get staff member details by ID
  Future<StaffProfileModel> getStaffById(String staffId) async {
    try {
      final response = await _dio.get('/staff/$staffId');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return StaffProfileModel.fromJson(response.data['data']);
      } else {
        throw StaffApiException(
          message: response.data['message'] ?? 'Staff not found',
          code: response.data['error'] ?? 'NOT_FOUND',
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e, 'load staff details');
    }
  }

  /// Update staff member
  Future<StaffProfileModel> updateStaff(
    String staffId,
    UpdateStaffRequest request,
  ) async {
    try {
      final response = await _dio.put(
        '/staff/$staffId',
        data: request.toJson(),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return StaffProfileModel.fromJson(response.data['data']);
      } else {
        throw StaffApiException(
          message: response.data['message'] ?? 'Failed to update staff',
          code: response.data['error'] ?? 'UPDATE_FAILED',
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e, 'update staff');
    }
  }

  /// Deactivate staff member
  Future<void> deactivateStaff(String staffId) async {
    try {
      final response = await _dio.patch('/staff/$staffId/deactivate');

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw StaffApiException(
          message: response.data['message'] ?? 'Failed to deactivate staff',
          code: response.data['error'] ?? 'DEACTIVATE_FAILED',
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e, 'deactivate staff');
    }
  }

  /// Reactivate staff member
  Future<void> reactivateStaff(String staffId) async {
    try {
      final response = await _dio.patch('/staff/$staffId/reactivate');

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw StaffApiException(
          message: response.data['message'] ?? 'Failed to reactivate staff',
          code: response.data['error'] ?? 'REACTIVATE_FAILED',
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e, 'reactivate staff');
    }
  }

  /// Reset staff password
  Future<ResetPasswordResponse> resetPassword(String staffId) async {
    try {
      final response = await _dio.post('/staff/$staffId/reset-password');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return ResetPasswordResponse.fromJson(response.data['data']);
      } else {
        throw StaffApiException(
          message: response.data['message'] ?? 'Failed to reset password',
          code: response.data['error'] ?? 'RESET_FAILED',
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e, 'reset password');
    }
  }

  /// Get staff stats
  Future<StaffStatsModel> getStaffStats() async {
    try {
      final response = await _dio.get('/staff/stats');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return StaffStatsModel.fromJson(response.data['data']);
      } else {
        throw StaffApiException(
          message: response.data['message'] ?? 'Failed to load stats',
          code: response.data['error'] ?? 'STATS_FAILED',
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e, 'load staff stats');
    }
  }

  /// Get presigned URL for photo upload
  Future<String> getPhotoUploadUrl(String staffId) async {
    try {
      final response = await _dio.post('/staff/$staffId/photo');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data']['uploadUrl'];
      } else {
        throw StaffApiException(
          message: response.data['message'] ?? 'Failed to get upload URL',
          code: response.data['error'] ?? 'UPLOAD_URL_FAILED',
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e, 'get photo upload URL');
    }
  }

  /// Handle Dio errors
  Exception _handleDioError(DioException error, String operation) {
    if (error.response != null) {
      final statusCode = error.response?.statusCode;
      final data = error.response?.data;

      switch (statusCode) {
        case 400:
          return StaffApiException(
            message: data?['message'] ?? 'Invalid request data',
            code: 'VALIDATION_ERROR',
            fieldErrors: data?['fields'],
          );
        case 401:
          return UnauthorizedException('Session expired. Please login again.');
        case 403:
          return ForbiddenException(
            data?['message'] ?? 'You do not have permission to $operation',
          );
        case 404:
          return NotFoundException('Staff member not found');
        case 409:
          return ConflictException(
            data?['message'] ?? 'Staff member already exists',
          );
        case 500:
          return ServerException('Server error while trying to $operation');
        default:
          return StaffApiException(
            message: 'Failed to $operation: ${error.message}',
            code: 'UNKNOWN_ERROR',
          );
      }
    }

    return StaffApiException(
      message: 'Network error while trying to $operation: ${error.message}',
      code: 'NETWORK_ERROR',
    );
  }
}

/// Custom Exceptions
class StaffApiException implements Exception {
  final String message;
  final String code;
  final Map<String, dynamic>? fieldErrors;

  StaffApiException({
    required this.message,
    required this.code,
    this.fieldErrors,
  });

  @override
  String toString() => 'StaffApiException: $message (code: $code)';
}

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException(this.message);
  @override
  String toString() => 'UnauthorizedException: $message';
}

class ForbiddenException implements Exception {
  final String message;
  ForbiddenException(this.message);
  @override
  String toString() => 'ForbiddenException: $message';
}

class NotFoundException implements Exception {
  final String message;
  NotFoundException(this.message);
  @override
  String toString() => 'NotFoundException: $message';
}

class ConflictException implements Exception {
  final String message;
  ConflictException(this.message);
  @override
  String toString() => 'ConflictException: $message';
}

class ServerException implements Exception {
  final String message;
  ServerException(this.message);
  @override
  String toString() => 'ServerException: $message';
}
