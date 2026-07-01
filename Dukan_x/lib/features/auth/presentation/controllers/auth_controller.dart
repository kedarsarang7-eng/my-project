import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../providers/app_state_providers.dart';
import '../../../../core/auth/auth_intent_service.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/services/device_registration_service.dart';
import '../../data/auth_repository.dart';
import '../../../../core/repository/shop_repository.dart';

class AuthController extends Notifier<bool> {
  String? _cachedPassword;

  @override
  bool build() {
    return false; // isLoading state
  }

  Future<void> signInAsCustomer({
    required String email,
    required String password,
  }) async {
    state = true;
    try {
      await authIntent.initialize();
      await authIntent.setCustomerIntent();

      final userPool = sl<CognitoUserPool>();
      final cognitoUser = CognitoUser(email.trim(), userPool);
      final authDetails = AuthenticationDetails(
        username: email.trim(),
        password: password.trim(),
      );

      try {
        await cognitoUser.authenticateUser(authDetails);
      } on CognitoUserConfirmationNecessaryException catch (_) {
        // Enforce OTP constraint: DO NOT generate or save JWT tokens yet
        await authIntent.clearIntent();
        _cachedPassword = password.trim(); // Cache to auto-login later
        ref.read(authStateProvider.notifier).requireOtp(email.trim());
        state = false;
        return;
      } on CognitoUserNewPasswordRequiredException catch (_) {
        await cognitoUser.sendNewPasswordRequiredAnswer(password.trim());
      }

      final session = sl<SessionManager>();
      await session.refreshSession();

      // Register device for multi-device tracking (non-blocking)
      _registerDeviceInBackground();

      final validationResult = authIntent.validateRole(
        session.isOwner
            ? 'vendor'
            : session.isCustomer
            ? 'customer'
            : null,
      );

      if (validationResult == RoleValidationResult.mismatch) {
        final errorMessage = authIntent.getMismatchErrorMessage(
          session.isOwner ? 'vendor' : 'unknown',
        );
        await cognitoUser.signOut();
        await authIntent.clearIntent();
        throw Exception(errorMessage);
      }

      await authIntent.clearIntent();
    } catch (e) {
      state = false;
      rethrow;
    }
    state = false;
  }

  Future<void> signInAsVendor({
    required String email,
    required String password,
  }) async {
    state = true;
    try {
      await authIntent.initialize();
      await authIntent.setVendorIntent();

      final userPool = sl<CognitoUserPool>();
      final cognitoUser = CognitoUser(email.trim(), userPool);
      final authDetails = AuthenticationDetails(
        username: email.trim(),
        password: password.trim(),
      );

      try {
        await cognitoUser.authenticateUser(authDetails);
      } on CognitoUserConfirmationNecessaryException catch (_) {
        // Enforce OTP constraint: DO NOT generate or save JWT tokens yet
        await authIntent.clearIntent();
        _cachedPassword = password.trim(); // Cache to auto-login later
        ref.read(authStateProvider.notifier).requireOtp(email.trim());
        state = false;
        return;
      } on CognitoUserNewPasswordRequiredException catch (_) {
        await cognitoUser.sendNewPasswordRequiredAnswer(password.trim());
      }

      final session = sl<SessionManager>();
      await session.refreshSession();

      // Register device for multi-device tracking (non-blocking)
      _registerDeviceInBackground();

      final validationResult = authIntent.validateRole(
        session.isOwner
            ? 'vendor'
            : session.isCustomer
            ? 'customer'
            : null,
      );

      if (validationResult == RoleValidationResult.mismatch) {
        final errorMessage = authIntent.getMismatchErrorMessage(
          session.isCustomer ? 'customer' : 'unknown',
        );
        await cognitoUser.signOut();
        await authIntent.clearIntent();
        throw Exception(errorMessage);
      }

      await authIntent.clearIntent();
    } catch (e) {
      state = false;
      rethrow;
    }
    state = false;
  }

  Future<void> signUpAsCustomer({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    state = true;
    _cachedPassword = password.trim();
    try {
      await authIntent.setCustomerIntent();

      final userPool = sl<CognitoUserPool>();
      final signUpResult = await userPool.signUp(
        email.trim(),
        password.trim(),
        userAttributes: [AttributeArg(name: 'email', value: email.trim())],
      );

      final uid = signUpResult.userSub;
      if (uid == null) {
        throw Exception('Failed to get user sub from signup.');
      }

      try {
        final authRepo = AuthRepository();
        await authRepo.createCustomerProfile(
          uid: uid,
          name: name.trim(),
          phone: phone.trim(),
          email: email.trim(),
        );
      } catch (e) {
        LoggerService.d('AuthController', 'CustomerAuth: Failed to create profile: $e');
      }

      if (signUpResult.userConfirmed != true) {
        ref.read(authStateProvider.notifier).requireOtp(email.trim());
      } else {
        // Auto-login if unconfirmed is not strictly necessary, although usually Cognito requires it.
        final cognitoUser = CognitoUser(email.trim(), userPool);
        final authDetails = AuthenticationDetails(
          username: email.trim(),
          password: password.trim(),
        );
        try {
          await cognitoUser.authenticateUser(authDetails);
          final session = sl<SessionManager>();
          await session.refreshSession();
        } catch (_) {}
      }
    } catch (e) {
      state = false;
      rethrow;
    }
    state = false;
  }

  Future<void> signUpAsVendor({
    required String shopName,
    required String phone,
    required String email,
    required String password,
  }) async {
    state = true;
    _cachedPassword = password.trim();
    try {
      await authIntent.setVendorIntent();

      final userPool = sl<CognitoUserPool>();
      final signUpResult = await userPool.signUp(
        email.trim(),
        password.trim(),
        userAttributes: [AttributeArg(name: 'email', value: email.trim())],
      );

      final uid = signUpResult.userSub;
      if (uid != null) {
        try {
          final shopRepo = sl<ShopRepository>();
          await shopRepo.updateShopProfile(
            ownerId: uid,
            shopName: shopName.trim().isNotEmpty ? shopName.trim() : 'My Shop',
            phone: phone.trim(),
            email: email.trim(),
          );
        } catch (e) {
          LoggerService.d('AuthController', 'VendorAuth: Repository error: $e');
        }
      }

      if (signUpResult.userConfirmed != true) {
        ref.read(authStateProvider.notifier).requireOtp(email.trim());
      } else {
        final cognitoUser = CognitoUser(email.trim(), userPool);
        final authDetails = AuthenticationDetails(
          username: email.trim(),
          password: password.trim(),
        );
        try {
          await cognitoUser.authenticateUser(authDetails);
          final session = sl<SessionManager>();
          await session.refreshSession();
        } catch (_) {}
      }
    } catch (e) {
      state = false;
      rethrow;
    }
    state = false;
  }

  Future<bool> verifyOtp({
    required String email,
    required String otpCode,
  }) async {
    state = true;
    try {
      final userPool = sl<CognitoUserPool>();
      final cognitoUser = CognitoUser(email.trim(), userPool);

      await cognitoUser.confirmRegistration(otpCode.trim());

      ref.read(authStateProvider.notifier).clearOtpState();

      if (_cachedPassword != null) {
        final authDetails = AuthenticationDetails(
          username: email.trim(),
          password: _cachedPassword!,
        );
        try {
          await cognitoUser.authenticateUser(authDetails);
          final session = sl<SessionManager>();
          await session.refreshSession();
        } catch (authError) {
          LoggerService.d('AuthController', 'Auto-login failed after OTP: $authError');
        } finally {
          _cachedPassword = null;
        }
      }

      state = false;
      return true;
    } catch (e) {
      state = false;
      rethrow;
    }
  }

  /// Register device after successful login (fire-and-forget).
  void _registerDeviceInBackground() {
    Future.microtask(() async {
      try {
        await DeviceRegistrationService.instance.registerDevice();
      } catch (e) {
        LoggerService.d('AuthController', 'AuthController: Device registration failed: $e');
      }
    });
  }
}

final authControllerProvider = NotifierProvider<AuthController, bool>(
  AuthController.new,
);
