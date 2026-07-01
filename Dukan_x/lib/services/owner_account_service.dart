// ignore_for_file: deprecated_member_use_from_same_package
import 'dart:async';
import 'dart:developer' as developer;

import 'package:dukanx/core/compat/firestore_compat.dart';
import 'package:dukanx/core/compat/firebase_auth_compat.dart';

import '../core/di/service_locator.dart' show sl;
import '../core/session/session_manager.dart' show SessionManager;
import 'session_service.dart' show SessionService, sessionService;

/// Handles owner bootstrap, enforcing single-owner constraint and
/// email/password authentication.
class OwnerAccountService {
  OwnerAccountService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    SessionManager? sessionManager,
    SessionService? session,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _sessionManager = sessionManager ?? sl<SessionManager>(),
       _session = session ?? sessionService;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final SessionManager _sessionManager;
  final SessionService _session;

  static const String _ownersCollection = 'owners';

  CollectionReference<Map<String, dynamic>> get _ownersRef =>
      _firestore.collection(_ownersCollection);

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
    final uid = _auth.currentUser?.uid;
    final record = await fetchOwnerRecord(uid: uid, timeout: timeout);
    return record != null;
  }

  Future<String?> fetchOwnerEmail({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final uid = _auth.currentUser?.uid;
    final record = await fetchOwnerRecord(uid: uid, timeout: timeout);
    return record == null ? null : record['email'] as String?;
  }

  Future<String?> fetchOwnerDocId({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final uid = _auth.currentUser?.uid;
    final record = await fetchOwnerRecord(uid: uid, timeout: timeout);
    if (record == null) return null;
    final explicitId = record['ownerId'] as String?;
    return explicitId?.isNotEmpty == true
        ? explicitId
        : record['docId'] as String?;
  }

  /// Creates the first owner and stores metadata at owners/{ownerId}.
  Future<UserCredential> createOwner({
    required String ownerId,
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    final credential = await _auth.createUserWithEmailAndPassword(
      email: trimmedEmail,
      password: password,
    );

    final uid = credential.user?.uid;
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

    return credential;
  }

  /// Logs the existing owner in with strict validation.
  Future<UserCredential> loginOwner({
    required String email,
    required String password,
    required String shopId,
  }) async {
    final docRef = _ownersRef.doc(shopId);
    final docSnap = await docRef.get();

    if (!docSnap.exists) {
      throw FirebaseAuthException(
        code: 'invalid-shop-id',
        message: 'Shop ID not found.',
      );
    }

    final record = docSnap.data()!;
    record['docId'] = docSnap.id;

    final storedEmail = (record['email'] as String?)?.trim();
    final ownerId =
        (record['ownerId'] as String?) ?? record['docId'] as String?;
    final authUid = record['authUid'] as String?;

    if (ownerId != shopId) {
      throw FirebaseAuthException(
        code: 'invalid-shop-id',
        message: 'Shop ID mismatch.',
      );
    }

    if (storedEmail != null && storedEmail.isNotEmpty) {
      final normalizedRecord = storedEmail.toLowerCase();
      final normalizedInput = email.trim().toLowerCase();
      if (normalizedRecord != normalizedInput) {
        throw FirebaseAuthException(
          code: 'wrong-email',
          message:
              'Email does not match the registered owner account for this Shop ID.',
        );
      }
    }

    final credential = await _auth.signInWithEmailAndPassword(
      email: storedEmail ?? email.trim(),
      password: password,
    );

    final uid = credential.user?.uid;
    if (uid == null) {
      throw StateError('Failed to sign in. Please try again.');
    }

    if (authUid != null && authUid.isNotEmpty && authUid != uid) {
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'owner-mismatch',
        message: 'Authentication mismatch. Contact support to reset.',
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

    return credential;
  }

  /// Logs in using only email and password, resolving the Shop ID automatically.
  Future<UserCredential> loginOwnerWithEmailOnly({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user?.uid;
    if (uid == null) {
      throw StateError('Failed to sign in. Please try again.');
    }

    final snapshot = await _ownersRef
        .where('authUid', isEqualTo: uid)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No shop associated with this account.',
      );
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

    return credential;
  }

  Future<void> signOutOwner() async {
    try {
      await _auth.signOut();
    } finally {
      if (_session.isInitialized) {
        await _session.clearSession();
      }
    }
    await _sessionManager.signOut();
  }
}

final ownerAccountService = OwnerAccountService();
