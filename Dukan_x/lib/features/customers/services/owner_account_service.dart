// ignore_for_file: deprecated_member_use_from_same_package
import 'dart:async';
import 'dart:developer' as developer;

import 'package:dukanx/core/compat/firestore_compat.dart';
import 'package:dukanx/core/api/api_client.dart';
import 'package:dukanx/core/di/service_locator.dart' hide sessionService;
import 'package:amazon_cognito_identity_dart_2/cognito.dart';

import '../../../../core/di/service_locator.dart' show sl;
import '../../../../core/session/session_manager.dart' show SessionManager;
import '../../../../core/services/session_service.dart' show SessionService, sessionService;

/// Handles owner bootstrap, enforcing single-owner constraint and
/// email/password authentication.
class OwnerAccountService {
  OwnerAccountService({
    CognitoUserPool? userPool,
        SessionManager? sessionManager,
    SessionService? session,
  }) : _userPool = userPool ?? sl<CognitoUserPool>(),
       
       _sessionManager = sessionManager ?? sl<SessionManager>(),
       _session = session ?? sessionService;

  final CognitoUserPool _userPool;
    ApiClient get _api => sl<ApiClient>();
  final SessionManager _sessionManager;
  final SessionService _session;

  static const String _ownersCollection = 'owners';

  CollectionReference<Map<String, dynamic>> get _ownersRef =>
      _api.collection(_ownersCollection);

  /// Returns the first owner record if it exists, or one matching a specific UID.
  Future<Map<String, dynamic>?> fetchOwnerRecord({
    String? uid,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      Query<Map<String, dynamic>> query = _ownersRef;
      if (uid != null && uid.isNotEmpty) {
        query = query.where('authUid', isEqualTo: uid);
      }

      final snapshot = await query.limit(1).get().timeout(timeout);
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      final data = doc.data();
      data['docId'] = doc.id;
      return data;
    } on TimeoutException catch (e, st) {
      developer.log(
        'Owner lookup timed out: $e',
        name: 'OwnerAccountService',
        stackTrace: st,
      );
      throw TimeoutException('Timed out while contacting owner record.');
    } catch (e, st) {
      developer.log(
        'Failed to fetch owner record: $e',
        name: 'OwnerAccountService',
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Returns true if an owner document already exists in Firestore.
  Future<bool> ownerExists({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final uid = _sessionManager.userId;
    final record = await fetchOwnerRecord(uid: uid, timeout: timeout);
    return record != null;
  }

  Future<String?> fetchOwnerEmail({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final uid = _sessionManager.userId;
    final record = await fetchOwnerRecord(uid: uid, timeout: timeout);
    return record == null ? null : record['email'] as String?;
  }

  Future<String?> fetchOwnerDocId({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final uid = _sessionManager.userId;
    final record = await fetchOwnerRecord(uid: uid, timeout: timeout);
    if (record == null) return null;
    final explicitId = record['ownerId'] as String?;
    return explicitId?.isNotEmpty == true
        ? explicitId
        : record['docId'] as String?;
  }

  /// Creates the first owner and stores metadata at owners/{ownerId}.
  Future<void> createOwner({
    required String ownerId,
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();

    final signUpResult = await _userPool.signUp(
      trimmedEmail,
      password,
      userAttributes: [AttributeArg(name: 'email', value: trimmedEmail)],
    );

    final uid = signUpResult.userSub;
    if (uid == null) {
      throw StateError('Unable to create owner. Please try again.');
    }

    final docRef = _ownersRef.doc(ownerId);
    final existingDoc = await docRef.get();
    if (existingDoc.exists) {
      throw StateError('Owner ID "$ownerId" is already in use.');
    }

    await docRef.set({
      'ownerId': ownerId,
      'authUid': uid,
      'email': trimmedEmail,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Save to SessionService (for backward compatibility)
    if (!_session.isInitialized) {
      await _session.init();
    }
    await _session.saveSession(
      userId: uid,
      role: 'owner',
      contact: trimmedEmail,
      ownerDocId: ownerId,
      ownerEmail: trimmedEmail,
    );

    // Also update SessionManager
    await _sessionManager.refreshSession();
  }

  /// Logs the existing owner in with strict validation.
  Future<void> loginOwner({
    required String email,
    required String password,
    required String shopId,
  }) async {
    final docRef = _ownersRef.doc(shopId);
    final docSnap = await docRef.get();

    if (!docSnap.exists) {
      throw CognitoClientException('Invalid shop ID');
    }

    final record = docSnap.data()!;
    record['docId'] = docSnap.id;

    final storedEmail = (record['email'] as String?)?.trim();
    final ownerId =
        (record['ownerId'] as String?) ?? record['docId'] as String?;
    final authUid = record['authUid'] as String?;

    if (ownerId != shopId) {
      throw CognitoClientException('Shop ID mismatch.');
    }

    if (storedEmail != null && storedEmail.isNotEmpty) {
      final normalizedRecord = storedEmail.toLowerCase();
      final normalizedInput = email.trim().toLowerCase();
      if (normalizedRecord != normalizedInput) {
        throw CognitoClientException(
          'Email does not match the registered owner account for this Shop ID.',
        );
      }
    }

    final cognitoUser = CognitoUser(storedEmail ?? email.trim(), _userPool);
    final authDetails = AuthenticationDetails(
      username: storedEmail ?? email.trim(),
      password: password,
    );

    CognitoUserSession? sessionResult;
    try {
      sessionResult = await cognitoUser.authenticateUser(authDetails);
    } on CognitoUserNewPasswordRequiredException catch (_) {
      sessionResult = await cognitoUser.sendNewPasswordRequiredAnswer(password);
    }
    final uid = sessionResult?.getIdToken().payload['sub'] as String?;
    if (uid == null) {
      throw StateError('Failed to sign in. Please try again.');
    }

    if (authUid != null && authUid.isNotEmpty && authUid != uid) {
      await cognitoUser.signOut();
      throw CognitoClientException(
        'Authentication mismatch. Contact support to reset.',
      );
    }

    // Save to SessionService (for backward compatibility)
    if (!_session.isInitialized) {
      await _session.init();
    }
    await _session.saveSession(
      userId: uid,
      role: 'owner',
      contact: storedEmail ?? email.trim(),
      ownerDocId: ownerId,
      ownerEmail: storedEmail ?? email.trim(),
    );

    // Also update SessionManager
    await _sessionManager.refreshSession();
  }

  /// Logs in using only email and password, resolving the Shop ID automatically.
  Future<void> loginOwnerWithEmailOnly({
    required String email,
    required String password,
  }) async {
    final cognitoUser = CognitoUser(email.trim(), _userPool);
    final authDetails = AuthenticationDetails(
      username: email.trim(),
      password: password,
    );

    CognitoUserSession? sessionResult;
    try {
      sessionResult = await cognitoUser.authenticateUser(authDetails);
    } on CognitoUserNewPasswordRequiredException catch (_) {
      sessionResult = await cognitoUser.sendNewPasswordRequiredAnswer(password);
    }
    final uid = sessionResult?.getIdToken().payload['sub'] as String?;
    if (uid == null) {
      throw StateError('Failed to sign in. Please try again.');
    }

    final snapshot = await _ownersRef
        .where('authUid', isEqualTo: uid)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      await cognitoUser.signOut();
      throw CognitoClientException('No shop associated with this account.');
    }

    final doc = snapshot.docs.first;
    final record = doc.data();
    final ownerId = record['ownerId'] as String? ?? doc.id;
    final storedEmail = record['email'] as String?;

    // Save to SessionService (for backward compatibility)
    if (!_session.isInitialized) {
      await _session.init();
    }
    await _session.saveSession(
      userId: uid,
      role: 'owner',
      contact: storedEmail ?? email.trim(),
      ownerDocId: ownerId,
      ownerEmail: storedEmail ?? email.trim(),
    );

    // Also update SessionManager
    await _sessionManager.refreshSession();
  }

  Future<void> signOutOwner() async {
    try {
      final lastUser = await _userPool.getCurrentUser();
      await lastUser?.signOut();
    } finally {
      if (_session.isInitialized) {
        await _session.clearSession();
      }
    }
    await _sessionManager.signOut();
  }
}

final ownerAccountService = OwnerAccountService();
