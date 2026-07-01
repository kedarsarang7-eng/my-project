// ============================================================================
// CUSTOMERS REPOSITORY TESTS
// ============================================================================
// Tests for CustomersRepository - offline-first pattern
//
// Author: DukanX Engineering
// Version: 2.0.0
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/repository/customers_repository.dart';
import 'package:dukanx/core/error/error_handler.dart';

void main() {
  group('Customer Model Tests', () {
    test('should create Customer with required fields', () {
      final now = DateTime.now();
      final customer = Customer(
        id: 'test-123',
        odId: 'owner-456',
        name: 'Test Customer',
        createdAt: now,
        updatedAt: now,
      );

      expect(customer.id, 'test-123');
      expect(customer.odId, 'owner-456');
      expect(customer.name, 'Test Customer');
      expect(customer.totalBilled, 0);
      expect(customer.totalPaid, 0);
      expect(customer.totalDues, 0);
      expect(customer.isActive, true);
      expect(customer.isSynced, false);
    });

    test('should create Customer with all optional fields', () {
      final now = DateTime.now();
      final customer = Customer(
        id: 'test-123',
        odId: 'owner-456',
        name: 'Test Customer',
        phone: '9876543210',
        email: 'test@example.com',
        address: '123 Main St',
        gstin: 'GSTIN123456',
        totalBilled: 5000,
        totalPaid: 3000,
        totalDues: 2000,
        isActive: true,
        isSynced: true,
        createdAt: now,
        updatedAt: now,
      );

      expect(customer.phone, '9876543210');
      expect(customer.email, 'test@example.com');
      expect(customer.address, '123 Main St');
      expect(customer.gstin, 'GSTIN123456');
      expect(customer.totalBilled, 5000);
      expect(customer.totalPaid, 3000);
      expect(customer.totalDues, 2000);
    });

    test('balance should return totalDues', () {
      final customer = Customer(
        id: 'test-123',
        odId: 'owner-456',
        name: 'Test Customer',
        totalDues: 1500,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(customer.balance, 1500);
    });

    test('hasOutstanding should be true when totalDues > 0', () {
      final customerWithDues = Customer(
        id: 'test-123',
        odId: 'owner-456',
        name: 'Test Customer',
        totalDues: 500,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final customerWithoutDues = Customer(
        id: 'test-456',
        odId: 'owner-456',
        name: 'Test Customer 2',
        totalDues: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(customerWithDues.hasOutstanding, true);
      expect(customerWithoutDues.hasOutstanding, false);
    });

    test('copyWith should create a copy with updated fields', () {
      final now = DateTime.now();
      final original = Customer(
        id: 'test-123',
        odId: 'owner-456',
        name: 'Original Name',
        phone: '1234567890',
        totalDues: 1000,
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(name: 'Updated Name', totalDues: 500);

      // Changed fields
      expect(updated.name, 'Updated Name');
      expect(updated.totalDues, 500);

      // Unchanged fields
      expect(updated.id, 'test-123');
      expect(updated.odId, 'owner-456');
      expect(updated.phone, '1234567890');
    });

    test('toMap should serialize all fields correctly', () {
      final now = DateTime.now();
      final customer = Customer(
        id: 'test-123',
        odId: 'owner-456',
        name: 'Test Customer',
        phone: '9876543210',
        totalBilled: 5000,
        totalPaid: 3000,
        totalDues: 2000,
        createdAt: now,
        updatedAt: now,
      );

      final map = customer.toMap();

      expect(map['id'], 'test-123');
      expect(map['userId'], 'owner-456'); // Note: maps to userId
      expect(map['name'], 'Test Customer');
      expect(map['phone'], '9876543210');
      expect(map['totalBilled'], 5000);
      expect(map['totalPaid'], 3000);
      expect(map['totalDues'], 2000);
    });

    test('fromMap should deserialize correctly', () {
      final now = DateTime.now();
      final map = {
        'id': 'test-123',
        'userId': 'owner-456',
        'name': 'Test Customer',
        'phone': '9876543210',
        'email': 'test@example.com',
        'totalBilled': 5000.0,
        'totalPaid': 3000.0,
        'totalDues': 2000.0,
        'isActive': true,
        'isSynced': false,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      final customer = Customer.fromMap(map);

      expect(customer.id, 'test-123');
      expect(customer.odId, 'owner-456');
      expect(customer.name, 'Test Customer');
      expect(customer.phone, '9876543210');
      expect(customer.email, 'test@example.com');
      expect(customer.totalBilled, 5000);
      expect(customer.totalPaid, 3000);
      expect(customer.totalDues, 2000);
    });

    test('toFirestoreMap should exclude local-only fields', () {
      final now = DateTime.now();
      final customer = Customer(
        id: 'test-123',
        odId: 'owner-456',
        name: 'Test Customer',
        isSynced: false, // Local-only field
        createdAt: now,
        updatedAt: now,
      );

      final firestoreMap = customer.toFirestoreMap();

      // Should include these
      expect(firestoreMap.containsKey('id'), true);
      expect(firestoreMap.containsKey('name'), true);
      expect(firestoreMap.containsKey('createdAt'), true);

      // Should NOT include these (local-only)
      expect(firestoreMap.containsKey('isSynced'), false);
    });
  });

  group('RepositoryResult Tests', () {
    test('success result should have data and no error', () {
      final result = RepositoryResult.success('test data');

      expect(result.isSuccess, true);
      expect(result.isFailure, false);
      expect(result.data, 'test data');
      expect(result.errorMessage, null);
    });

    test('failure result should have error and no data', () {
      final result = RepositoryResult<String>.failure(
        'Something went wrong',
        RepositoryErrorCategory.network,
      );

      expect(result.isSuccess, false);
      expect(result.isFailure, true);
      expect(result.data, null);
      expect(result.errorMessage, 'Something went wrong');
      expect(result.errorCategory, RepositoryErrorCategory.network);
    });

    test('success with nullable data should work', () {
      final result = RepositoryResult<String?>.success(null);

      expect(result.isSuccess, true);
      expect(result.data, null);
    });

    test('failure with different error categories', () {
      final networkError = RepositoryResult<String>.failure(
        'Network error',
        RepositoryErrorCategory.network,
      );
      final authError = RepositoryResult<String>.failure(
        'Auth error',
        RepositoryErrorCategory.authentication,
      );
      final validationError = RepositoryResult<String>.failure(
        'Validation error',
        RepositoryErrorCategory.validation,
      );

      expect(networkError.errorCategory, RepositoryErrorCategory.network);
      expect(authError.errorCategory, RepositoryErrorCategory.authentication);
      expect(validationError.errorCategory, RepositoryErrorCategory.validation);
    });
  });
}
