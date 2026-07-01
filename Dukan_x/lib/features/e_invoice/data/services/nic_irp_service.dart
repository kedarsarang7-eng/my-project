import 'dart:convert';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/nic_auth_model.dart';
import '../models/irn_response_model.dart';
import 'nic_irp_config.dart';

/// NIC IRP Service for e-Invoice Integration
///
/// SECURITY: This service requires proper configuration via [NicIrpConfig].
/// All credentials are stored securely and NEVER hardcoded.
///
/// Usage:
/// 1. First configure via [NicIrpConfig.configure()]
/// 2. Create instance via [NicIrpService.create()]
/// 3. Call authenticate() before any API calls
class NicIrpService {
  final NicIrpConfig _config;

  String? _authToken;
  Uint8List? _decryptedSek; // Decrypted Session Encryption Key
  Uint8List? _appKeyBytes; // Original AppKey bytes for SEK decryption
  DateTime? _tokenExpiry;

  NicIrpService._(this._config);

  /// Create a properly configured NicIrpService
  ///
  /// Returns null if NIC IRP is not configured.
  /// Call [NicIrpConfig.configure()] first.
  static Future<NicIrpService?> create() async {
    final config = await NicIrpConfig.fromSecureStorage();
    if (config == null) {
      debugPrint(
        'NicIrpService: Not configured. Call NicIrpConfig.configure() first.',
      );
      return null;
    }
    return NicIrpService._(config);
  }

  /// Check if service is properly configured
  static Future<bool> isConfigured() async {
    return await NicIrpConfig.isConfigured();
  }

  /// Authenticate with NIC IRP
  /// Exchanges ClientID/Secret/User/Pass for AuthToken and SEK
  Future<bool> authenticate() async {
    try {
      // Generate encrypted password and AppKey
      final encryptedPassword = _config.encryptPassword();
      final (encryptedAppKey, appKeyBytes) = _config.generateAppKey();
      _appKeyBytes = appKeyBytes;

      final headers = {
        'Content-Type': 'application/json',
        'Gstin': _config.gstin,
        'client_id': _config.clientId,
        'client_secret': _config.clientSecret,
      };

      final body = {
        'UserName': _config.username,
        'Password': encryptedPassword,
        'AppKey': encryptedAppKey,
        'ForceRefreshAccessToken': true,
      };

      final response = await http.post(
        Uri.parse(_config.authUrl),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final authResponse = NicAuthModel.fromJson(jsonDecode(response.body));

        if (authResponse.isSuccess && authResponse.data != null) {
          _authToken = authResponse.data!.authToken;
          _tokenExpiry = DateTime.now().add(const Duration(hours: 6));

          // Check if SEK is present
          if (authResponse.data!.sek == null) {
            debugPrint('NicIrpService: Auth successful but SEK is missing');
            return false;
          }

          // Decrypt SEK using our AppKey
          _decryptedSek = _decryptSek(authResponse.data!.sek!, _appKeyBytes!);

          debugPrint('NicIrpService: Authentication successful');
          return true;
        } else {
          debugPrint(
            'NicIrpService: Auth Failed: ${authResponse.error?.errorMessage}',
          );
          return false;
        }
      }

      debugPrint('NicIrpService: Auth HTTP Error: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('NicIrpService: Auth Error: $e');
      return false;
    }
  }

  /// Decrypt the Session Encryption Key (SEK) using AppKey
  ///
  /// NIC sends SEK encrypted with our AppKey (AES-256-ECB).
  /// We need to decrypt it to use for payload encryption.
  Uint8List _decryptSek(String encryptedSek, Uint8List appKeyBytes) {
    try {
      final encryptedBytes = base64Decode(encryptedSek);

      final key = encrypt.Key(appKeyBytes);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.ecb),
      );

      final decrypted = encrypter.decryptBytes(
        encrypt.Encrypted(encryptedBytes),
      );

      return Uint8List.fromList(decrypted);
    } catch (e) {
      debugPrint('NicIrpService: Error decrypting SEK: $e');
      rethrow;
    }
  }

  /// Encrypt payload using SEK (for production API calls)
  String _encryptPayload(String jsonPayload) {
    if (_decryptedSek == null) {
      throw StateError('Not authenticated. Call authenticate() first.');
    }

    final key = encrypt.Key(_decryptedSek!);
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
    );

    return encrypter.encrypt(jsonPayload, iv: iv).base64;
  }

  /// Decrypt response payload using SEK
  String _decryptPayload(String encryptedPayload) {
    if (_decryptedSek == null) {
      throw StateError('Not authenticated. Call authenticate() first.');
    }

    final key = encrypt.Key(_decryptedSek!);
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
    );

    return encrypter.decrypt64(encryptedPayload, iv: iv);
  }

  /// Generate IRN for invoice
  ///
  /// Returns [IrnResponseModel] with IRN, QR code, and signed invoice.
  /// Throws if not authenticated or on API error.
  Future<IrnResponseModel?> generateIrn(
    Map<String, dynamic> invoiceData,
  ) async {
    if (!await _ensureAuth()) {
      throw StateError('Authentication failed. Cannot generate IRN.');
    }

    try {
      final headers = _getHeaders();

      // For sandbox, we may send unencrypted payload
      // For production, payload must be encrypted with SEK
      String requestBody;
      if (_config.isSandbox) {
        requestBody = jsonEncode(invoiceData);
      } else {
        final jsonPayload = jsonEncode(invoiceData);
        requestBody = jsonEncode({'Data': _encryptPayload(jsonPayload)});
      }

      final response = await http.post(
        Uri.parse(_config.generateIrnUrl),
        headers: headers,
        body: requestBody,
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> responseJson;

        if (_config.isSandbox) {
          responseJson = jsonDecode(response.body);
        } else {
          // Production response is encrypted
          final encryptedResponse = jsonDecode(response.body);
          final decryptedData = _decryptPayload(encryptedResponse['Data']);
          responseJson = jsonDecode(decryptedData);
        }

        return IrnResponseModel.fromJson(responseJson);
      } else {
        try {
          return IrnResponseModel.fromJson(jsonDecode(response.body));
        } catch (_) {
          debugPrint(
            'NicIrpService: Generate IRN HTTP Error: ${response.statusCode}',
          );
          return null;
        }
      }
    } catch (e) {
      debugPrint('NicIrpService: Generate IRN Error: $e');
      rethrow;
    }
  }

  /// Cancel IRN (within 24 hours of generation)
  Future<bool> cancelIrn(String irn, String reasonCode, String remarks) async {
    if (!await _ensureAuth()) {
      throw StateError('Authentication failed. Cannot cancel IRN.');
    }

    try {
      final headers = _getHeaders();
      final body = {'Irn': irn, 'CnlRsn': reasonCode, 'CnlRem': remarks};

      String requestBody;
      if (_config.isSandbox) {
        requestBody = jsonEncode(body);
      } else {
        requestBody = jsonEncode({'Data': _encryptPayload(jsonEncode(body))});
      }

      final response = await http.post(
        Uri.parse(_config.cancelIrnUrl),
        headers: headers,
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['Status'] == '1';
      }
      return false;
    } catch (e) {
      debugPrint('NicIrpService: Cancel IRN Error: $e');
      return false;
    }
  }

  /// Validate/Get IRN details
  Future<IrnResponseModel?> getIrnDetails(String irn) async {
    if (!await _ensureAuth()) {
      throw StateError('Authentication failed. Cannot validate IRN.');
    }

    try {
      final headers = _getHeaders();
      headers['irn'] = irn;

      final response = await http.get(
        Uri.parse(_config.validateIrnUrl),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return IrnResponseModel.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('NicIrpService: Get IRN Details Error: $e');
      return null;
    }
  }

  Future<bool> _ensureAuth() async {
    if (_authToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return true;
    }
    return await authenticate();
  }

  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Gstin': _config.gstin,
      'AuthToken': _authToken ?? '',
      'client_id': _config.clientId,
    };
  }

  /// Get GSTIN from configuration
  String get configuredGstin => _config.gstin;

  /// Check if using sandbox environment
  bool get isSandbox => _config.isSandbox;
}
