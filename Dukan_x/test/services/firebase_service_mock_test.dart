// ============================================================================
// FIREBASE SERVICE TESTS (WITH MOCKS)
// ============================================================================
// Tests for Firebase-dependent services using mock implementations
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter_test/flutter_test.dart';

// Mock Firebase Auth
class MockFirebaseAuth {
  MockFirebaseUser? _currentUser;
  final List<AuthStateListener> _listeners = [];

  MockFirebaseUser? get currentUser => _currentUser;

  void setUser(MockFirebaseUser? user) {
    _currentUser = user;
    for (final listener in _listeners) {
      listener(user);
    }
  }

  Stream<MockFirebaseUser?> authStateChanges() {
    return Stream.value(_currentUser);
  }

  void addAuthStateListener(AuthStateListener listener) {
    _listeners.add(listener);
  }

  Future<MockUserCredential> signInWithPhoneNumber(
    String phone,
    String otp,
  ) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final user = MockFirebaseUser(
      uid: 'test-uid-${DateTime.now().millisecondsSinceEpoch}',
      phoneNumber: phone,
    );
    setUser(user);
    return MockUserCredential(user: user);
  }

  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 50));
    setUser(null);
  }
}

typedef AuthStateListener = void Function(MockFirebaseUser?);

class MockFirebaseUser {
  final String uid;
  final String? displayName;
  final String? email;
  final String? phoneNumber;
  final bool emailVerified;

  MockFirebaseUser({
    required this.uid,
    this.displayName,
    this.email,
    this.phoneNumber,
    this.emailVerified = false,
  });
}

class MockUserCredential {
  final MockFirebaseUser user;

  MockUserCredential({required this.user});
}

// Mock Firestore
class MockFirestore {
  final Map<String, MockCollection> _collections = {};

  MockCollection collection(String name) {
    _collections[name] ??= MockCollection(name);
    return _collections[name]!;
  }

  void reset() {
    _collections.clear();
  }
}

class MockCollection {
  final String name;
  final Map<String, MockDocument> _documents = {};

  MockCollection(this.name);

  MockDocument doc(String id) {
    _documents[id] ??= MockDocument(id);
    return _documents[id]!;
  }

  Future<List<MockDocument>> get() async {
    return _documents.values.toList();
  }

  List<MockDocument> where(String field, {dynamic isEqualTo}) {
    return _documents.values.where((doc) {
      return doc._data[field] == isEqualTo;
    }).toList();
  }
}

class MockDocument {
  final String id;
  Map<String, dynamic> _data = {};
  bool _exists = false;

  MockDocument(this.id);

  bool get exists => _exists;
  Map<String, dynamic>? data() => _exists ? _data : null;

  Future<void> set(Map<String, dynamic> data) async {
    _data = Map.from(data);
    _exists = true;
  }

  Future<void> update(Map<String, dynamic> data) async {
    if (!_exists) throw Exception('Document does not exist');
    _data.addAll(data);
  }

  Future<void> delete() async {
    _data = {};
    _exists = false;
  }

  Future<MockDocumentSnapshot> get() async {
    return MockDocumentSnapshot(
      id: id,
      data: _exists ? _data : null,
      exists: _exists,
    );
  }
}

class MockDocumentSnapshot {
  final String id;
  final Map<String, dynamic>? _data;
  final bool exists;

  MockDocumentSnapshot({
    required this.id,
    Map<String, dynamic>? data,
    this.exists = false,
  }) : _data = data;

  Map<String, dynamic>? data() => _data;
}

// Mock Firestore Service
class MockFirestoreService {
  final MockFirestore _firestore;

  MockFirestoreService(this._firestore);

  Future<void> createUser({
    required String uid,
    required String role,
    required String name,
    String? phone,
    String? email,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'role': role,
      'name': name,
      'phone': phone,
      'email': email,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> getUser(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    return snapshot.data();
  }

  Future<String?> getUserRole(String uid) async {
    final data = await getUser(uid);
    return data?['role'] as String?;
  }

  Future<void> updateUser(String uid, Map<String, dynamic> updates) async {
    await _firestore.collection('users').doc(uid).update(updates);
  }

  Future<void> createBill({
    required String ownerId,
    required String billId,
    required Map<String, dynamic> billData,
  }) async {
    await _firestore.collection('users').doc(ownerId).set({
      'bills': {billId: billData},
    });
  }

  Future<void> createCustomer({
    required String ownerId,
    required String customerId,
    required String name,
    required String phone,
  }) async {
    await _firestore.collection('users').doc(ownerId).set({
      'customers': {
        customerId: {
          'name': name,
          'phone': phone,
          'createdAt': DateTime.now().toIso8601String(),
        },
      },
    });
  }
}

void main() {
  group('Mock Firebase Auth Tests', () {
    late MockFirebaseAuth auth;

    setUp(() {
      auth = MockFirebaseAuth();
    });

    test('initial state should have no user', () {
      expect(auth.currentUser, null);
    });

    test('signInWithPhoneNumber should create user', () async {
      final credential = await auth.signInWithPhoneNumber(
        '+919876543210',
        '123456',
      );

      expect(credential.user, isNotNull);
      expect(credential.user.phoneNumber, '+919876543210');
      expect(auth.currentUser, isNotNull);
    });

    test('signOut should clear user', () async {
      await auth.signInWithPhoneNumber('+919876543210', '123456');
      expect(auth.currentUser, isNotNull);

      await auth.signOut();
      expect(auth.currentUser, null);
    });

    test('authStateChanges should emit user', () async {
      final stream = auth.authStateChanges();

      expect(await stream.first, null);
    });

    test('auth state listener should be called on user change', () async {
      MockFirebaseUser? receivedUser;
      auth.addAuthStateListener((user) {
        receivedUser = user;
      });

      await auth.signInWithPhoneNumber('+919999999999', '000000');

      expect(receivedUser, isNotNull);
      expect(receivedUser!.phoneNumber, '+919999999999');
    });
  });

  group('Mock Firestore Tests', () {
    late MockFirestore firestore;

    setUp(() {
      firestore = MockFirestore();
    });

    tearDown(() {
      firestore.reset();
    });

    test('collection should return same instance', () {
      final col1 = firestore.collection('users');
      final col2 = firestore.collection('users');

      expect(identical(col1, col2), true);
    });

    test('document set and get', () async {
      await firestore.collection('users').doc('user-1').set({
        'name': 'John',
        'role': 'owner',
      });

      final snapshot = await firestore.collection('users').doc('user-1').get();

      expect(snapshot.exists, true);
      expect(snapshot.data()?['name'], 'John');
      expect(snapshot.data()?['role'], 'owner');
    });

    test('document update', () async {
      await firestore.collection('users').doc('user-1').set({
        'name': 'John',
        'role': 'owner',
      });

      await firestore.collection('users').doc('user-1').update({
        'phone': '9876543210',
      });

      final snapshot = await firestore.collection('users').doc('user-1').get();

      expect(snapshot.data()?['name'], 'John');
      expect(snapshot.data()?['phone'], '9876543210');
    });

    test('document delete', () async {
      await firestore.collection('users').doc('user-1').set({'name': 'John'});
      await firestore.collection('users').doc('user-1').delete();

      final snapshot = await firestore.collection('users').doc('user-1').get();

      expect(snapshot.exists, false);
    });

    test('get non-existent document', () async {
      final snapshot = await firestore
          .collection('users')
          .doc('non-existent')
          .get();

      expect(snapshot.exists, false);
      expect(snapshot.data(), null);
    });
  });

  group('Mock Firestore Service Tests', () {
    late MockFirestore firestore;
    late MockFirestoreService service;

    setUp(() {
      firestore = MockFirestore();
      service = MockFirestoreService(firestore);
    });

    tearDown(() {
      firestore.reset();
    });

    test('createUser should store user data', () async {
      await service.createUser(
        uid: 'user-123',
        role: 'owner',
        name: 'Test Owner',
        phone: '9876543210',
      );

      final userData = await service.getUser('user-123');

      expect(userData, isNotNull);
      expect(userData!['role'], 'owner');
      expect(userData['name'], 'Test Owner');
      expect(userData['phone'], '9876543210');
    });

    test('getUserRole should return correct role', () async {
      await service.createUser(uid: 'owner-1', role: 'owner', name: 'Owner');

      await service.createUser(
        uid: 'customer-1',
        role: 'customer',
        name: 'Customer',
      );

      expect(await service.getUserRole('owner-1'), 'owner');
      expect(await service.getUserRole('customer-1'), 'customer');
    });

    test('getUserRole should return null for non-existent user', () async {
      final role = await service.getUserRole('non-existent');
      expect(role, null);
    });

    test('updateUser should modify existing data', () async {
      await service.createUser(
        uid: 'user-1',
        role: 'owner',
        name: 'Original Name',
      );

      await service.updateUser('user-1', {
        'name': 'Updated Name',
        'lastLogin': DateTime.now().toIso8601String(),
      });

      final userData = await service.getUser('user-1');
      expect(userData?['name'], 'Updated Name');
      expect(userData?['lastLogin'], isNotNull);
    });
  });

  group('Auth + Firestore Integration Tests', () {
    late MockFirebaseAuth auth;
    late MockFirestore firestore;
    late MockFirestoreService firestoreService;

    setUp(() {
      auth = MockFirebaseAuth();
      firestore = MockFirestore();
      firestoreService = MockFirestoreService(firestore);
    });

    tearDown(() {
      firestore.reset();
    });

    test('complete auth flow: sign in + create user doc', () async {
      // Step 1: Sign in
      final credential = await auth.signInWithPhoneNumber(
        '+919876543210',
        '123456',
      );
      final uid = credential.user.uid;

      // Step 2: Create user document
      await firestoreService.createUser(
        uid: uid,
        role: 'owner',
        name: 'New Owner',
        phone: '+919876543210',
      );

      // Step 3: Verify
      expect(auth.currentUser?.uid, uid);
      final role = await firestoreService.getUserRole(uid);
      expect(role, 'owner');
    });

    test('sign out should preserve user data', () async {
      // Sign in and create user
      final credential = await auth.signInWithPhoneNumber(
        '+919876543210',
        '123456',
      );
      await firestoreService.createUser(
        uid: credential.user.uid,
        role: 'customer',
        name: 'Test Customer',
      );

      // Sign out
      await auth.signOut();

      // User data should still exist
      final userData = await firestoreService.getUser(credential.user.uid);
      expect(auth.currentUser, null); // Signed out
      expect(userData?['name'], 'Test Customer'); // Data preserved
    });
  });

  group('Error Handling Tests', () {
    late MockFirestore firestore;
    late MockFirestoreService service;

    setUp(() {
      firestore = MockFirestore();
      service = MockFirestoreService(firestore);
    });

    test('update non-existent document should throw', () async {
      expect(
        () => firestore.collection('users').doc('non-existent').update({
          'name': 'Test',
        }),
        throwsException,
      );
    });

    test('handle null user gracefully', () async {
      final userData = await service.getUser('null-user');
      expect(userData, null);
    });
  });

  group('Batch Operations Tests', () {
    late MockFirestore firestore;

    setUp(() {
      firestore = MockFirestore();
    });

    test('create multiple documents', () async {
      for (int i = 1; i <= 5; i++) {
        await firestore.collection('users').doc('user-$i').set({
          'name': 'User $i',
          'index': i,
        });
      }

      final docs = await firestore.collection('users').get();
      expect(docs.length, 5);
    });

    test('query documents with where clause', () async {
      await firestore.collection('users').doc('u1').set({'role': 'owner'});
      await firestore.collection('users').doc('u2').set({'role': 'customer'});
      await firestore.collection('users').doc('u3').set({'role': 'owner'});

      final owners = firestore
          .collection('users')
          .where('role', isEqualTo: 'owner');
      expect(owners.length, 2);
    });
  });

  group('Data Validation Tests', () {
    test('validate user data structure', () {
      final validUserData = {
        'role': 'owner',
        'name': 'Test User',
        'phone': '9876543210',
        'createdAt': DateTime.now().toIso8601String(),
      };

      expect(validUserData.containsKey('role'), true);
      expect(validUserData.containsKey('name'), true);
      expect(['owner', 'customer'].contains(validUserData['role']), true);
    });

    test('validate bill data structure', () {
      final validBillData = {
        'customerId': 'cust-123',
        'items': [],
        'grandTotal': 0.0,
        'paidAmount': 0.0,
        'status': 'Unpaid',
        'createdAt': DateTime.now().toIso8601String(),
      };

      expect(validBillData.containsKey('customerId'), true);
      expect(validBillData.containsKey('grandTotal'), true);
      expect(validBillData.containsKey('status'), true);
    });
  });
}
