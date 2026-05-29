// ============================================================================
// BizMate — Flutter Cognito API Helper
// ============================================================================
// Reference implementation for connecting the Flutter app to the
// AWS serverless backend using Cognito authentication.
//
// SETUP:
//   1. Add to pubspec.yaml:
//        amazon_cognito_identity_dart_2: ^3.6.0
//        http: ^1.1.0
//
//   2. Copy this file to: lib/core/network/cognito_api_client.dart
//
//   3. Initialize in main.dart:
//        final api = CognitoApiClient(
//          apiBaseUrl: 'https://xxxxxx.execute-api.us-east-1.amazonaws.com',
//          userPoolId: 'us-east-1_XXXXXXXXX',
//          clientId: 'xxxxxxxxxxxxxxxxxxxxxxxxxx',
//        );
//
// ============================================================================

// ignore_for_file: uri_does_not_exist, depend_on_referenced_packages
import 'dart:convert';
import 'package:http/http.dart' as http;

// To use the full Cognito SDK, add this dependency:
// amazon_cognito_identity_dart_2: ^3.6.0
//
// For this reference implementation, we use plain HTTP calls to the
// backend's /auth endpoints, which handle Cognito internally.

/// BizMate API Client with Cognito JWT Authentication.
///
/// All API calls automatically attach the Cognito ID Token
/// in the Authorization header for tenant-scoped access.
class CognitoApiClient {
  final String apiBaseUrl;
  final String userPoolId;
  final String clientId;
  final http.Client _httpClient;

  // Token storage
  // String? _accessToken; // Unused
  String? _idToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;

  // Decoded tenant context
  String? _tenantId;
  String? _role;
  String? _businessType;

  CognitoApiClient({
    required this.apiBaseUrl,
    required this.userPoolId,
    required this.clientId,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  // ============================================================================
  // AUTHENTICATION
  // ============================================================================

  /// Sign up a new business owner.
  ///
  /// Creates both the Cognito user and the tenant + user records in the
  /// backend database.
  ///
  /// ```dart
  /// final result = await api.signUp(
  ///   email: 'owner@business.com',
  ///   password: 'SecurePass123!',
  ///   businessName: 'My Petrol Station',
  ///   businessType: 'petrol_pump',
  ///   fullName: 'John Doe',
  ///   phone: '+919876543210',
  /// );
  /// print('Tenant ID: ${result['tenantId']}');
  /// ```
  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String businessName,
    required String businessType,
    String? fullName,
    String? phone,
  }) async {
    final response = await _post(
      '/auth/signup',
      body: {
        'email': email,
        'password': password,
        'businessName': businessName,
        'businessType': businessType,
        // ignore: use_null_aware_elements
        if (fullName != null) 'fullName': fullName,
        // ignore: use_null_aware_elements
        if (phone != null) 'phone': phone,
      },
    );

    return response['data'] as Map<String, dynamic>;
  }

  /// Sign in with email and password.
  ///
  /// On success, stores the JWT tokens internally. All subsequent API
  /// calls will automatically use the token.
  ///
  /// ```dart
  /// await api.signIn(email: 'owner@business.com', password: 'SecurePass123!');
  /// // Now you can call authenticated endpoints:
  /// final dashboard = await api.getDashboard();
  /// ```
  Future<void> signIn({required String email, required String password}) async {
    final response = await _post(
      '/auth/login',
      body: {'email': email, 'password': password},
    );

    final data = response['data'] as Map<String, dynamic>;
    // _accessToken = data['accessToken'] as String;
    _idToken = data['idToken'] as String;
    _refreshToken = data['refreshToken'] as String;
    _tokenExpiry = DateTime.now().add(
      Duration(seconds: (data['expiresIn'] as int?) ?? 3600),
    );

    // Decode tenant context from the ID token
    _decodeTenantContext();
  }

  /// Refresh the access token using the stored refresh token.
  ///
  /// Called automatically when the token is expired. You can also
  /// call it manually if needed.
  Future<void> refreshTokens() async {
    if (_refreshToken == null) {
      throw Exception('No refresh token available. Please sign in again.');
    }

    final response = await _post(
      '/auth/refresh',
      body: {'refreshToken': _refreshToken},
    );

    final data = response['data'] as Map<String, dynamic>;
    // _accessToken = data['accessToken'] as String;
    _idToken = data['idToken'] as String;
    _tokenExpiry = DateTime.now().add(
      Duration(seconds: (data['expiresIn'] as int?) ?? 3600),
    );

    _decodeTenantContext();
  }

  /// Sign out and clear all stored tokens.
  void signOut() {
    // _accessToken = null;
    _idToken = null;
    _refreshToken = null;
    _tokenExpiry = null;
    _tenantId = null;
    _role = null;
    _businessType = null;
  }

  /// Check if the user is authenticated (has a valid token).
  bool get isAuthenticated =>
      _idToken != null &&
      _tokenExpiry != null &&
      DateTime.now().isBefore(_tokenExpiry!);

  /// Get the current tenant ID.
  String? get tenantId => _tenantId;

  /// Get the current user role.
  String? get role => _role;

  /// Get the current business type.
  String? get businessType => _businessType;

  // ============================================================================
  // DASHBOARD API
  // ============================================================================

  /// Fetch the business-type-specific dashboard data.
  ///
  /// The backend automatically detects the business type from the JWT
  /// and returns the appropriate data:
  /// - Petrol Pump: Tank levels, nozzle sales, shift summaries
  /// - Pharmacy: Near-expiry medicines, batch stock, drug compliance
  /// - etc.
  ///
  /// ```dart
  /// final dashboard = await api.getDashboard();
  /// final revenue = dashboard['summary']['todayRevenueCents'];
  /// final sections = dashboard['sections'] as List;
  /// ```
  Future<Map<String, dynamic>> getDashboard() async {
    final response = await _get('/dashboard');
    return response['data'] as Map<String, dynamic>;
  }

  // ============================================================================
  // INVENTORY API
  // ============================================================================

  /// List inventory items with pagination and optional filters.
  ///
  /// ```dart
  /// final result = await api.getInventory(
  ///   page: 1,
  ///   limit: 20,
  ///   category: 'fuel',
  ///   search: 'diesel',
  /// );
  /// final items = result['data'] as List;
  /// final total = result['meta']['total'];
  /// ```
  Future<Map<String, dynamic>> getInventory({
    int page = 1,
    int limit = 20,
    String? category,
    String? search,
    bool? lowStockOnly,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      // ignore: use_null_aware_elements
      if (category != null) 'category': category,
      // ignore: use_null_aware_elements
      if (search != null) 'search': search,
      if (lowStockOnly == true) 'lowStock': 'true',
    };
    return await _get('/inventory', queryParams: params);
  }

  /// Create a new inventory item.
  Future<Map<String, dynamic>> createInventoryItem(
    Map<String, dynamic> item,
  ) async {
    final response = await _post('/inventory', body: item);
    return response['data'] as Map<String, dynamic>;
  }

  /// Update an existing inventory item.
  Future<Map<String, dynamic>> updateInventoryItem(
    String itemId,
    Map<String, dynamic> updates,
  ) async {
    final response = await _put('/inventory/$itemId', body: updates);
    return response['data'] as Map<String, dynamic>;
  }

  /// Delete an inventory item (soft-delete).
  Future<void> deleteInventoryItem(String itemId) async {
    await _delete('/inventory/$itemId');
  }

  // ============================================================================
  // STORAGE API (S3 Signed URLs)
  // ============================================================================

  /// Get a pre-signed URL for uploading a file.
  ///
  /// ```dart
  /// final signedUrl = await api.getUploadUrl(
  ///   path: 'invoices/INV-001.pdf',
  ///   contentType: 'application/pdf',
  /// );
  /// // Use the URL to upload directly to S3:
  /// await http.put(Uri.parse(signedUrl), body: fileBytes,
  ///   headers: {'Content-Type': 'application/pdf'});
  /// ```
  Future<String> getUploadUrl({
    required String path,
    required String contentType,
  }) async {
    final response = await _get(
      '/storage/signed-url',
      queryParams: {
        'action': 'upload',
        'path': path,
        'contentType': contentType,
      },
    );
    return (response['data'] as Map<String, dynamic>)['url'] as String;
  }

  /// Get a pre-signed URL for downloading a file.
  ///
  /// ```dart
  /// final url = await api.getDownloadUrl(path: 'products/img-001.jpg');
  /// // Use in Image.network(url) or launch in browser
  /// ```
  Future<String> getDownloadUrl({required String path}) async {
    final response = await _get(
      '/storage/signed-url',
      queryParams: {'action': 'download', 'path': path},
    );
    return (response['data'] as Map<String, dynamic>)['url'] as String;
  }

  // ============================================================================
  // PRIVATE HELPERS
  // ============================================================================

  /// Build headers with the Cognito ID Token.
  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (_idToken != null) {
      headers['Authorization'] = 'Bearer $_idToken';
    }

    return headers;
  }

  /// Ensure the token is valid; auto-refresh if expired.
  Future<void> _ensureAuthenticated() async {
    if (_idToken == null) {
      throw Exception('Not authenticated. Call signIn() first.');
    }

    // Auto-refresh 5 minutes before expiry
    if (_tokenExpiry != null &&
        DateTime.now().isAfter(
          _tokenExpiry!.subtract(const Duration(minutes: 5)),
        )) {
      await refreshTokens();
    }
  }

  Future<Map<String, dynamic>> _get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    await _ensureAuthenticated();

    final uri = Uri.parse(
      '$apiBaseUrl$endpoint',
    ).replace(queryParameters: queryParams);

    final response = await _httpClient.get(uri, headers: _buildHeaders());
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    // Don't require auth for /auth/* endpoints
    if (!endpoint.startsWith('/auth/')) {
      await _ensureAuthenticated();
    }

    final uri = Uri.parse('$apiBaseUrl$endpoint');
    final response = await _httpClient.post(
      uri,
      headers: _buildHeaders(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _put(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    await _ensureAuthenticated();

    final uri = Uri.parse('$apiBaseUrl$endpoint');
    final response = await _httpClient.put(
      uri,
      headers: _buildHeaders(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<void> _delete(String endpoint) async {
    await _ensureAuthenticated();

    final uri = Uri.parse('$apiBaseUrl$endpoint');
    final response = await _httpClient.delete(uri, headers: _buildHeaders());
    _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    final error = body['error'] as Map<String, dynamic>?;
    throw ApiException(
      statusCode: response.statusCode,
      code: error?['code'] as String? ?? 'UNKNOWN',
      message: error?['message'] as String? ?? 'Request failed',
    );
  }

  /// Decode the JWT ID Token to extract tenant context.
  ///
  /// JWT structure: header.payload.signature
  /// We only need the payload (base64-encoded JSON).
  void _decodeTenantContext() {
    if (_idToken == null) return;

    try {
      final parts = _idToken!.split('.');
      if (parts.length != 3) return;

      // Decode the payload (second part)
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final claims = jsonDecode(decoded) as Map<String, dynamic>;

      _tenantId = claims['custom:tenant_id'] as String?;
      _role = claims['custom:role'] as String?;
      _businessType = claims['custom:business_type'] as String?;
    } catch (_) {
      // If decoding fails, the middleware will catch it server-side
    }
  }
}

/// API Exception thrown by [CognitoApiClient].
class ApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  @override
  String toString() => 'ApiException($statusCode/$code): $message';
}
