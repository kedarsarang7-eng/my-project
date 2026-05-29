/// Shared Core Package for DukanX Ecosystem
/// 
/// This package contains shared code between main_software and customer_app:
/// - API client with interceptors
/// - DTOs (Data Transfer Objects)
/// - Models
/// - Validators
/// - Utilities
///
/// Usage:
/// ```dart
/// import 'package:shared_core/shared_core.dart';
/// ```

library shared_core;

// API
export 'src/api/api_client.dart';
export 'src/api/exceptions/api_exceptions.dart';
export 'src/api/interceptors/auth_interceptor.dart';
export 'src/api/interceptors/retry_interceptor.dart';
export 'src/api/interceptors/logging_interceptor.dart';

// DTOs
export 'src/dto/auth_dto.dart';
export 'src/dto/bill_dto.dart';
export 'src/dto/api_response.dart';

// Models
export 'src/models/user_role.dart';
export 'src/models/user_context.dart';

// Validators
export 'src/validators/email_validator.dart';
export 'src/validators/gst_validator.dart';

// Utils
export 'src/utils/jwt_utils.dart';
export 'src/utils/result.dart';
