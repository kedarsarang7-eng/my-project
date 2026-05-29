class ApiResponseDto<T> {
  final bool success;
  final T? data;
  final String? message;
  final String? errorCode;

  const ApiResponseDto({
    required this.success,
    this.data,
    this.message,
    this.errorCode,
  });

  factory ApiResponseDto.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromData,
  ) {
    return ApiResponseDto<T>(
      success: json['success'] as bool? ?? false,
      data: fromData != null && json['data'] != null
          ? fromData(json['data'])
          : json['data'] as T?,
      message: json['message'] as String?,
      errorCode: json['errorCode'] as String?,
    );
  }
}
