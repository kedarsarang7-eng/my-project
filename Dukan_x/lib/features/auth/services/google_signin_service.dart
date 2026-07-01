// ============================================================================
// GOOGLE SIGN-IN SERVICE — Cognito Federation via Hosted UI
// ============================================================================
// Uses Cognito Hosted UI OAuth2 flow with Google identity provider.
//
// DESKTOP FLOW (Windows/macOS/Linux):
//   1. Start a local HTTP server on a random port
//   2. Open browser ? Cognito /authorize (identity_provider=Google)
//   3. User signs in with Google via Cognito Hosted UI
//   4. Cognito redirects ? http://localhost:{port}/callback?code=xxx
//   5. Local server captures the code, exchanges for tokens
//   6. SessionManager loads the authenticated session
//
// MOBILE FLOW (Android/iOS):
//   Same flow but uses deep link (dukanx://auth/callback) instead of localhost
//
// Author: DukanX Engineering
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/session/secure_cognito_storage.dart';
import '../../../../core/services/deep_link_service.dart';

class GoogleSignInService {
  static final GoogleSignInService _instance = GoogleSignInService._internal();

  GoogleSignInService._internal();

  factory GoogleSignInService() => _instance;

  // Cognito configuration from .env
  String get _cognitoDomain => dotenv.env['COGNITO_DOMAIN'] ?? '';
  String get _clientId => dotenv.env['COGNITO_CLIENT_ID'] ?? '';

  /// Whether we are running on desktop (Windows/macOS/Linux)
  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// For mobile, use the deep link scheme
  String get _mobileRedirectUri =>
      dotenv.env['COGNITO_REDIRECT_URI'] ?? 'dukanx://auth/callback';

  /// Build the Cognito Hosted UI authorize URL for Google federation
  Uri _buildGoogleAuthUrl({required String redirectUri, String? state}) {
    if (_cognitoDomain.isEmpty) {
      throw Exception(
        'COGNITO_DOMAIN not configured. Set it in .env file.',
      );
    }

    final params = <String, String>{
      'identity_provider': 'Google',
      'response_type': 'code',
      'client_id': _clientId,
      'redirect_uri': redirectUri,
      'scope': 'openid email profile',
    };

    if (state != null) {
      params['state'] = state;
    }

    return Uri.https(_cognitoDomain, '/oauth2/authorize', params);
  }

  // ==========================================================================
  // DESKTOP FLOW — localhost callback server
  // ==========================================================================

  /// Launch Google Sign-In for Desktop.
  /// Starts a local HTTP server, opens browser, waits for callback.
  /// Returns when sign-in is complete (or throws on error/timeout).
  Future<void> signInDesktop({String? state}) async {
    // 1. Start local HTTP server on a random port
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    final redirectUri = 'http://localhost:$port/callback';

    developer.log(
      'Desktop OAuth: listening on $redirectUri',
      name: 'GoogleSignInService',
    );

    try {
      // 2. Build Cognito authorize URL with localhost redirect
      final authorizeUrl = _buildGoogleAuthUrl(
        redirectUri: redirectUri,
        state: state,
      );

      // 3. Open browser
      final launched = await launchUrl(
        authorizeUrl,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('Could not open browser for Google Sign-In');
      }

      // 4. Wait for the callback (with timeout)
      final code = await _waitForCallback(server)
          .timeout(const Duration(minutes: 5), onTimeout: () {
        throw TimeoutException('Google Sign-In timed out');
      });

      // 5. Exchange code for tokens
      await _exchangeAndStoreTokens(code, redirectUri);

      developer.log(
        'Desktop Google Sign-In complete!',
        name: 'GoogleSignInService',
      );
    } finally {
      await server.close(force: true);
    }
  }

  /// Wait for the OAuth callback on the local server.
  /// Returns the authorization code.
  Future<String> _waitForCallback(HttpServer server) async {
    final completer = Completer<String>();

    server.listen((HttpRequest request) async {
      try {
        if (request.uri.path == '/callback') {
          final code = request.uri.queryParameters['code'];
          final error = request.uri.queryParameters['error'];

          if (error != null) {
            // Send error page to browser
            request.response
              ..statusCode = 200
              ..headers.contentType = ContentType.html
              ..write(_buildHtmlResponse(
                success: false,
                message: 'Sign-in failed: $error',
              ));
            await request.response.close();

            if (!completer.isCompleted) {
              completer.completeError(Exception('OAuth error: $error'));
            }
            return;
          }

          if (code == null || code.isEmpty) {
            request.response
              ..statusCode = 400
              ..headers.contentType = ContentType.html
              ..write(_buildHtmlResponse(
                success: false,
                message: 'No authorization code received',
              ));
            await request.response.close();

            if (!completer.isCompleted) {
              completer.completeError(Exception('No auth code in callback'));
            }
            return;
          }

          // Success! Send nice page to browser
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.html
            ..write(_buildHtmlResponse(
              success: true,
              message: 'Sign-in successful! You can close this window.',
            ));
          await request.response.close();

          if (!completer.isCompleted) {
            completer.complete(code);
          }
        } else {
          // Unknown path — send 404
          request.response
            ..statusCode = 404
            ..write('Not found');
          await request.response.close();
        }
      } catch (e) {
        developer.log('Callback handler error: $e', name: 'GoogleSignInService');
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      }
    });

    return completer.future;
  }

  /// Build a nice HTML response page for the browser
  String _buildHtmlResponse({required bool success, required String message}) {
    final color = success ? '#00C853' : '#FF1744';
    final icon = success ? '?' : '?';
    return '''
<!DOCTYPE html>
<html>
<head><title>DukanX - Google Sign-In</title></head>
<body style="display:flex;justify-content:center;align-items:center;height:100vh;
  background:#0B0D1F;color:white;font-family:sans-serif;margin:0;">
  <div style="text-align:center;">
    <div style="font-size:64px;color:$color;margin-bottom:20px;">$icon</div>
    <h2 style="margin:0 0 10px;">$message</h2>
    <p style="color:#888;">Return to the DukanX app.</p>
  </div>
</body>
</html>''';
  }

  // ==========================================================================
  // MOBILE FLOW — deep link callback
  // ==========================================================================

  /// Launch Google Sign-In for Mobile.
  /// Opens Cognito Hosted UI; the result comes via deep link callback
  /// handled by DeepLinkService.
  Future<void> launchGoogleSignIn({String? state}) async {
    // SEC-07 FIX: Generate cryptographic state for CSRF protection
    final oauthState = await DeepLinkService.generateOAuthState();

    if (_isDesktop) {
      // On desktop, use the full synchronous flow
      await signInDesktop(state: oauthState);
      return;
    }

    // Mobile flow — opens browser, result comes via deep link
    final url = _buildGoogleAuthUrl(
      redirectUri: _mobileRedirectUri,
      state: oauthState,
    );

    developer.log(
      'Launching Google Sign-In via Cognito: $url',
      name: 'GoogleSignInService',
    );

    final launched = await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      throw Exception('Could not launch Google Sign-In URL');
    }
  }

  // ==========================================================================
  // TOKEN EXCHANGE (shared by both desktop and mobile flows)
  // ==========================================================================

  /// Exchange authorization code for Cognito tokens and store them.
  Future<void> _exchangeAndStoreTokens(String code, String redirectUri) async {
    final tokenData = await _exchangeCode(code, redirectUri);

    final idToken = tokenData['id_token'] as String?;
    final accessToken = tokenData['access_token'] as String?;
    final refreshToken = tokenData['refresh_token'] as String?;

    if (idToken == null || accessToken == null) {
      throw Exception('Missing tokens in Cognito response');
    }

    // Decode JWT to get username
    final username = _extractUsernameFromIdToken(idToken);

    developer.log(
      'Google user: $username',
      name: 'GoogleSignInService',
    );

    // Store tokens using CognitoUserPool key format
    final storage = sl<SecureCognitoStorage>();
    final clientId = _clientId;
    final prefix = 'CognitoIdentityServiceProvider.$clientId';

    await storage.setItem('$prefix.LastAuthUser', username);
    await storage.setItem('$prefix.$username.idToken', idToken);
    await storage.setItem('$prefix.$username.accessToken', accessToken);
    if (refreshToken != null) {
      await storage.setItem('$prefix.$username.refreshToken', refreshToken);
    }
    await storage.setItem('$prefix.$username.clockDrift', '0');

    developer.log('Tokens stored. Refreshing session...', name: 'GoogleSignInService');

    // Refresh session
    final session = sl<SessionManager>();
    await session.refreshSession();

    developer.log(
      'Google Sign-In complete. Authenticated: ${session.isAuthenticated}',
      name: 'GoogleSignInService',
    );
  }

  /// Exchange auth code for tokens via Cognito /oauth2/token endpoint.
  Future<Map<String, dynamic>> _exchangeCode(
      String code, String redirectUri) async {
    final tokenUrl = Uri.https(_cognitoDomain, '/oauth2/token');

    developer.log(
      'Exchanging auth code for tokens...',
      name: 'GoogleSignInService',
    );

    final response = await http.post(
      tokenUrl,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'client_id': _clientId,
        'redirect_uri': redirectUri,
      },
    );

    if (response.statusCode != 200) {
      developer.log(
        'Token exchange failed: ${response.statusCode} ${response.body}',
        name: 'GoogleSignInService',
      );
      throw Exception(
        'Token exchange failed (${response.statusCode}): ${response.body}',
      );
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }

  /// Extract username (sub or email) from a JWT ID token.
  String _extractUsernameFromIdToken(String idToken) {
    final parts = idToken.split('.');
    if (parts.length != 3) {
      throw Exception('Invalid ID token format');
    }

    String payload = parts[1];
    final remainder = payload.length % 4;
    if (remainder > 0) {
      payload += '=' * (4 - remainder);
    }

    final decoded = json.decode(utf8.decode(base64Url.decode(payload)));
    final username = decoded['sub'] as String? ??
        decoded['cognito:username'] as String? ??
        decoded['email'] as String? ??
        '';

    if (username.isEmpty) {
      throw Exception('Could not determine username from ID token');
    }

    return username;
  }

  /// Complete sign-in from a mobile deep link callback code.
  /// Called by DeepLinkService when it receives dukanx://auth/callback?code=xxx
  Future<void> completeSignIn(String code) async {
    await _exchangeAndStoreTokens(code, _mobileRedirectUri);
  }

  /// Signs out — clears stored Google federation tokens.
  Future<void> signOut() async {
    try {
      final session = sl<SessionManager>();
      await session.signOut();
    } catch (e) {
      developer.log('Sign out error: $e', name: 'GoogleSignInService');
    }
  }
}
