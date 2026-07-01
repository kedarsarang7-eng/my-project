// ============================================================================
// DATABASE CONNECTION - CROSS-PLATFORM
// ============================================================================
// Provides database connection for both native and web platforms
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

export 'connection_native.dart' if (dart.library.html) 'connection_web.dart';
