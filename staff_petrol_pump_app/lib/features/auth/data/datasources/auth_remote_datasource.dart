import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import '../../../../core/auth/token_storage.dart';
import '../../../../core/config/aws_config.dart';
import '../models/staff_user_model.dart';

abstract class AuthRemoteDataSource {
  Future<StaffUserModel> loginWithCredentials({
    required String staffId,
    required String password,
  });
  Future<StaffUserModel> loginWithBiometrics();
  Future<void> logout();
  Future<void> forgotPassword({required String staffId});
  Future<bool> isLoggedIn();
  Future<StaffUserModel?> getCurrentUser();
  Future<StaffUserModel> completeNewPassword({
    required String staffId,
    required String temporaryPassword,
    required String newPassword,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final CognitoUserPool _userPool = AwsConfig.userPool;

  @override
  Future<StaffUserModel> loginWithCredentials({
    required String staffId,
    required String password,
  }) async {
    try {
      final cognitoUser = CognitoUser(staffId, _userPool);
      final authDetails = AuthenticationDetails(
        username: staffId,
        password: password,
      );

      final session = await cognitoUser.authenticateUser(authDetails);
      
      if (session == null) {
        throw Exception('Authentication failed');
      }

      // Store tokens securely
      await TokenStorage.saveTokens(
        accessToken: session.getAccessToken().getJwtToken()!,
        idToken: session.getIdToken().getJwtToken()!,
        refreshToken: session.getRefreshToken()?.getToken() ?? '',
      );

      // Get user attributes
      final attributes = await cognitoUser.getUserAttributes();
      
      return StaffUserModel(
        staffId: staffId,
        fullName: _getAttribute(attributes, 'name') ?? '',
        role: _getAttribute(attributes, 'custom:role') ?? 'staff',
        pumpStationId: _getAttribute(attributes, 'custom:station_id') ?? '',
        isFirstLogin: false,
        isActive: true,
        permissions: [],
      );
    } on CognitoClientException catch (e) {
      // Check for NEW_PASSWORD_REQUIRED challenge
      if (e.code == 'NEW_PASSWORD_REQUIRED' || 
          (e.message?.contains('new password') ?? false)) {
        throw Exception('NEW_PASSWORD_REQUIRED: ${e.message}');
      }
      throw Exception('Cognito error: ${e.message}');
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  @override
  Future<StaffUserModel> loginWithBiometrics() async {
    // For biometric login, we retrieve stored tokens and validate them
    // If valid, we return the user from stored data
    // If expired, we try to refresh
    
    final accessToken = await TokenStorage.getAccessToken();
    final refreshToken = await TokenStorage.getRefreshToken();
    
    if (accessToken == null || refreshToken == null) {
      throw Exception('No stored credentials found. Please login with credentials first.');
    }

    // TODO: Implement token validation and refresh logic
    // For now, return a mock user - implement properly based on your backend
    return StaffUserModel(
      staffId: 'PSC-001',
      fullName: 'Staff User',
      role: 'pump_operator',
      pumpStationId: 'STATION-001',
      isFirstLogin: false,
      isActive: true,
      permissions: ['view_sales', 'start_shift'],
    );
  }

  @override
  Future<void> logout() async {
    final cognitoUser = CognitoUser(
      await TokenStorage.getAccessToken() ?? '',
      _userPool,
    );
    await cognitoUser.signOut();
    await TokenStorage.clearTokens();
  }

  @override
  Future<void> forgotPassword({required String staffId}) async {
    final cognitoUser = CognitoUser(staffId, _userPool);
    await cognitoUser.forgotPassword();
  }

  @override
  Future<bool> isLoggedIn() async {
    final accessToken = await TokenStorage.getAccessToken();
    if (accessToken == null) return false;
    
    // TODO: Validate token expiration
    return true;
  }

  @override
  Future<StaffUserModel?> getCurrentUser() async {
    final accessToken = await TokenStorage.getAccessToken();
    if (accessToken == null) return null;
    
    // TODO: Fetch current user details from backend or cache
    return null;
  }

  @override
  Future<StaffUserModel> completeNewPassword({
    required String staffId,
    required String temporaryPassword,
    required String newPassword,
  }) async {
    try {
      final cognitoUser = CognitoUser(staffId, _userPool);
      final authDetails = AuthenticationDetails(
        username: staffId,
        password: temporaryPassword,
      );

      // Initiate authentication which will trigger NEW_PASSWORD_REQUIRED challenge
      final session = await cognitoUser.authenticateUser(authDetails);
      
      if (session != null) {
        // If session is returned, password was already changed
        return StaffUserModel(
          staffId: staffId,
          fullName: '',
          role: 'staff',
          pumpStationId: '',
          isFirstLogin: false,
          isActive: true,
          permissions: [],
        );
      }

      // If we get here, we need to complete the new password challenge
      // Actually, the cognito library should throw a CognitoNewPasswordRequiredException
      // which we need to catch and handle
      throw Exception('New password required but not handled');
    } on CognitoClientException catch (e) {
      if (e.code == 'NEW_PASSWORD_REQUIRED') {
        // Complete the new password challenge
        final cognitoUser = CognitoUser(staffId, _userPool);
        
        // Set the new password
        await cognitoUser.sendNewPasswordRequiredAnswer(newPassword);

        // Now authenticate with the new password
        final authDetails = AuthenticationDetails(
          username: staffId,
          password: newPassword,
        );

        final session = await cognitoUser.authenticateUser(authDetails);
        
        if (session == null) {
          throw Exception('Authentication failed after password change');
        }

        // Store tokens securely
        await TokenStorage.saveTokens(
          accessToken: session.getAccessToken().getJwtToken()!,
          idToken: session.getIdToken().getJwtToken()!,
          refreshToken: session.getRefreshToken()?.getToken() ?? '',
        );

        // Get user attributes
        final attributes = await cognitoUser.getUserAttributes();
        
        return StaffUserModel(
          staffId: staffId,
          fullName: _getAttribute(attributes, 'name') ?? '',
          role: _getAttribute(attributes, 'custom:role') ?? 'staff',
          pumpStationId: _getAttribute(attributes, 'custom:station_id') ?? '',
          isFirstLogin: false,
          isActive: true,
          permissions: [],
        );
      }
      throw Exception('Cognito error: ${e.message}');
    } catch (e) {
      throw Exception('Password change failed: $e');
    }
  }

  String? _getAttribute(List<CognitoUserAttribute>? attributes, String name) {
    if (attributes == null) return null;
    try {
      return attributes.firstWhere((attr) => attr.name == name).value;
    } catch (e) {
      return null;
    }
  }
}
