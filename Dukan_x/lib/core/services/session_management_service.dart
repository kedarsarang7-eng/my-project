// ============================================================================
// SESSION MANAGEMENT SERVICE
// ============================================================================
// Manages user sessions, device control, and force logout.
// ============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dukanx/core/compat/firestore_compat.dart';

import '../repository/audit_repository.dart';

/// User Session Model
class UserSession {
  final String id;
  final String userId;
  final String businessId;
  final String deviceId;
  final String? deviceName;
  final String? platform;
  final DateTime loginAt;
  final DateTime lastActiveAt;
  final DateTime expiresAt;
  final bool isActive;
  final String? loginLocation;
  final bool forceLogout;

  const UserSession({
    required this.id,
    required this.userId,
    required this.businessId,
    required this.deviceId,
    this.deviceName,
    this.platform,
    required this.loginAt,
    required this.lastActiveAt,
    required this.expiresAt,
    this.isActive = true,
    this.loginLocation,
    this.forceLogout = false,
  });

  factory UserSession.fromMap(String id, Map<String, dynamic> map) {
    return UserSession(
      id: id,
      userId: map['userId'] as String,
      businessId: map['businessId'] as String,
      deviceId: map['deviceId'] as String,
      deviceName: map['deviceName'] as String?,
      platform: map['platform'] as String?,
      loginAt: _parseDate(map['loginAt']) ?? DateTime.now(),
      lastActiveAt: _parseDate(map['lastActiveAt']) ?? DateTime.now(),
      expiresAt: _parseDate(map['expiresAt']) ?? DateTime.now(),
      isActive: map['isActive'] as bool? ?? true,
      loginLocation: map['loginLocation'] as String?,
      forceLogout: map['forceLogout'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'businessId': businessId,
    'deviceId': deviceId,
    'deviceName': deviceName,
    'platform': platform,
    'loginAt': Timestamp.fromDate(loginAt),
    'lastActiveAt': Timestamp.fromDate(lastActiveAt),
    'expiresAt': Timestamp.fromDate(expiresAt),
    'isActive': isActive,
    'loginLocation': loginLocation,
    'forceLogout': forceLogout,
  };

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get shouldLogout => forceLogout || isExpired || !isActive;

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}

/// Session Management Service - Device and session control.
///
/// Features:
/// - Create/validate sessions
/// - Device registration
/// - Session expiry
/// - Force logout by owner
/// - One device per user (optional)
class SessionManagementService {
  final FirebaseFirestore _firestore;
  final AuditRepository _auditRepository;

  /// Current session
  UserSession? _currentSession;

  /// Session expiry hours (default: 24)
  int sessionExpiryHours = 24;

  /// Enforce one device per user
  bool enforceOneDevicePerUser = false;

  /// Stream controller for force logout
  final StreamController<bool> _forceLogoutController =
      StreamController<bool>.broadcast();

  SessionManagementService({
    FirebaseFirestore? firestore,
    required AuditRepository auditRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auditRepository = auditRepository;

  /// Stream of force logout events
  Stream<bool> get forceLogoutStream => _forceLogoutController.stream;

  /// Current session
  UserSession? get currentSession => _currentSession;

  /// Create a new session
  Future<UserSession> createSession({
    required String userId,
    required String businessId,
    String? location,
  }) async {
    final deviceId = _getDeviceId();
    final deviceName = _getDeviceName();
    final platform = _getPlatform();
    final now = DateTime.now();

    // If enforcing one device, terminate other sessions
    if (enforceOneDevicePerUser) {
      await _terminateOtherSessions(userId, deviceId);
    }

    final sessionId = '${userId}_${now.millisecondsSinceEpoch}';

    final session = UserSession(
      id: sessionId,
      userId: userId,
      businessId: businessId,
      deviceId: deviceId,
      deviceName: deviceName,
      platform: platform,
      loginAt: now,
      lastActiveAt: now,
      expiresAt: now.add(Duration(hours: sessionExpiryHours)),
      loginLocation: location,
    );

    await _firestore
        .collection('user_sessions')
        .doc(sessionId)
        .set(session.toFirestore());

    _currentSession = session;

    // Start listening for force logout
    _startForceLogoutListener(sessionId);

    // Audit log
    await _auditRepository.logAction(
      userId: userId,
      targetTableName: 'user_sessions',
      recordId: sessionId,
      action: 'LOGIN',
      newValueJson: '{"deviceId": "$deviceId", "platform": "$platform"}',
    );

    debugPrint('SessionManagementService: Created session $sessionId');
    return session;
  }

  /// Validate current session
  Future<bool> validateSession() async {
    if (_currentSession == null) return false;

    try {
      final doc = await _firestore
          .collection('user_sessions')
          .doc(_currentSession!.id)
          .get();

      if (!doc.exists) return false;

      final session = UserSession.fromMap(doc.id, doc.data()!);

      if (session.shouldLogout) {
        await endSession();
        return false;
      }

      // Update last active
      await _updateLastActive();

      _currentSession = session;
      return true;
    } catch (e) {
      debugPrint('SessionManagementService: Error validating session: $e');
      return false;
    }
  }

  /// End current session
  Future<void> endSession() async {
    if (_currentSession == null) return;

    try {
      await _firestore
          .collection('user_sessions')
          .doc(_currentSession!.id)
          .update({
            'isActive': false,
            'lastActiveAt': Timestamp.fromDate(DateTime.now()),
          });

      // Audit log
      await _auditRepository.logAction(
        userId: _currentSession!.userId,
        targetTableName: 'user_sessions',
        recordId: _currentSession!.id,
        action: 'LOGOUT',
        newValueJson: '{}',
      );

      debugPrint(
        'SessionManagementService: Ended session ${_currentSession!.id}',
      );
      _currentSession = null;
    } catch (e) {
      debugPrint('SessionManagementService: Error ending session: $e');
    }
  }

  /// Force logout a user (owner action)
  Future<void> forceLogout({
    required String targetSessionId,
    required String performedBy,
  }) async {
    await _firestore.collection('user_sessions').doc(targetSessionId).update({
      'forceLogout': true,
      'isActive': false,
    });

    // Audit log
    await _auditRepository.logAction(
      userId: performedBy,
      targetTableName: 'user_sessions',
      recordId: targetSessionId,
      action: 'FORCE_LOGOUT',
      newValueJson: '{"performedBy": "$performedBy"}',
    );

    debugPrint(
      'SessionManagementService: Force logged out session $targetSessionId',
    );
  }

  /// Get active sessions for a business
  Future<List<UserSession>> getActiveSessions(String businessId) async {
    final query = await _firestore
        .collection('user_sessions')
        .where('businessId', isEqualTo: businessId)
        .where('isActive', isEqualTo: true)
        .orderBy('lastActiveAt', descending: true)
        .get();

    return query.docs
        .map((doc) => UserSession.fromMap(doc.id, doc.data()))
        .where((s) => !s.isExpired)
        .toList();
  }

  /// Get login history for a user
  Future<List<UserSession>> getLoginHistory({
    required String userId,
    int limit = 20,
  }) async {
    final query = await _firestore
        .collection('user_sessions')
        .where('userId', isEqualTo: userId)
        .orderBy('loginAt', descending: true)
        .limit(limit)
        .get();

    return query.docs
        .map((doc) => UserSession.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<void> _updateLastActive() async {
    if (_currentSession == null) return;

    await _firestore
        .collection('user_sessions')
        .doc(_currentSession!.id)
        .update({'lastActiveAt': Timestamp.fromDate(DateTime.now())});
  }

  Future<void> _terminateOtherSessions(
    String userId,
    String currentDeviceId,
  ) async {
    final query = await _firestore
        .collection('user_sessions')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();

    for (final doc in query.docs) {
      if (doc.data()['deviceId'] != currentDeviceId) {
        await doc.reference.update({'isActive': false, 'forceLogout': true});
      }
    }
  }

  void _startForceLogoutListener(String sessionId) {
    _firestore.collection('user_sessions').doc(sessionId).snapshots().listen((
      snapshot,
    ) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        if (data['forceLogout'] == true) {
          _forceLogoutController.add(true);
        }
      }
    });
  }

  String _getDeviceId() {
    // Simplified device ID - in production use device_info_plus
    return 'device_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _getDeviceName() {
    // Simplified device name
    return 'Unknown Device';
  }

  String _getPlatform() {
    // Check for platform in Flutter
    if (kIsWeb) return 'web';
    return 'mobile';
  }

  /// Dispose resources
  void dispose() {
    _forceLogoutController.close();
  }
}
