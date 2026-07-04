// Unit tests for `ComputerShopCache` (task 14.1) — verifies the Drift-backed
// offline read cache for job cards, warranty, and serials is tenant-scoped
// and round-trips the exact JSON payload it was given.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/features/computer_shop/data/repositories/computer_shop_cache.dart';

void main() {
  late AppDatabase database;
  late ComputerShopCache cache;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    cache = ComputerShopCache(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('ComputerShopCache — job cards', () {
    test('caches and retrieves a single job card by id', () async {
      final payload = {
        'id': 'job-1',
        'status': 'INTAKE',
        'deviceBrand': 'Dell',
        'deviceModel': 'Inspiron',
        'reportedIssue': 'Wont boot',
        'createdAt': '2024-01-01T00:00:00.000Z',
        'updatedAt': '2024-01-01T00:00:00.000Z',
      };

      await cache.upsertJobCard(
        tenantId: 'tenant-a',
        id: 'job-1',
        payload: payload,
      );

      final cached = await cache.getCachedJobCard(
        tenantId: 'tenant-a',
        id: 'job-1',
      );
      expect(cached, equals(payload));
    });

    test('does not leak a cached job card across tenants', () async {
      await cache.upsertJobCard(
        tenantId: 'tenant-a',
        id: 'job-1',
        payload: {'id': 'job-1', 'status': 'INTAKE'},
      );

      final cachedForOtherTenant = await cache.getCachedJobCard(
        tenantId: 'tenant-b',
        id: 'job-1',
      );
      expect(cachedForOtherTenant, isNull);
    });

    test(
      'upsertJobCards caches a batch and getCachedJobCards returns all of them',
      () async {
        await cache.upsertJobCards(
          tenantId: 'tenant-a',
          payloads: [
            {'id': 'job-1', 'status': 'INTAKE'},
            {'id': 'job-2', 'status': 'DIAGNOSIS'},
          ],
        );

        final cached = await cache.getCachedJobCards(tenantId: 'tenant-a');
        expect(cached.length, 2);
        expect(cached.map((j) => j['id']), containsAll(['job-1', 'job-2']));
      },
    );

    test(
      'upserting the same job card id replaces the previous payload',
      () async {
        await cache.upsertJobCard(
          tenantId: 'tenant-a',
          id: 'job-1',
          payload: {'id': 'job-1', 'status': 'INTAKE'},
        );
        await cache.upsertJobCard(
          tenantId: 'tenant-a',
          id: 'job-1',
          payload: {'id': 'job-1', 'status': 'DELIVERED'},
        );

        final cached = await cache.getCachedJobCard(
          tenantId: 'tenant-a',
          id: 'job-1',
        );
        expect(cached?['status'], 'DELIVERED');
      },
    );
  });

  group('ComputerShopCache — warranty', () {
    test('caches and retrieves a warranty by serial number', () async {
      final payload = {
        'id': 'warr-1',
        'serialNumber': 'SN123',
        'warrantyExpiryDate': '2025-06-01',
      };

      await cache.upsertWarranty(
        tenantId: 'tenant-a',
        id: 'warr-1',
        serialNumber: 'SN123',
        payload: payload,
        warrantyExpiryDate: DateTime.parse('2025-06-01'),
      );

      final cached = await cache.getCachedWarrantyBySerial(
        tenantId: 'tenant-a',
        serialNumber: 'SN123',
      );
      expect(cached, equals(payload));
    });

    test('caches and retrieves a warranty by warranty id', () async {
      final payload = {'id': 'warr-1', 'serialNumber': 'SN123'};

      await cache.upsertWarranty(
        tenantId: 'tenant-a',
        id: 'warr-1',
        serialNumber: 'SN123',
        payload: payload,
      );

      final cached = await cache.getCachedWarrantyById(
        tenantId: 'tenant-a',
        warrantyId: 'warr-1',
      );
      expect(cached, equals(payload));
    });

    test('returns null for an unknown serial number', () async {
      final cached = await cache.getCachedWarrantyBySerial(
        tenantId: 'tenant-a',
        serialNumber: 'unknown',
      );
      expect(cached, isNull);
    });
  });

  group('ComputerShopCache — serials', () {
    test('caches and retrieves all serials for a tenant', () async {
      await cache.upsertSerials(
        tenantId: 'tenant-a',
        payloads: [
          {'serialNumber': 'SN1', 'status': 'available'},
          {'serialNumber': 'SN2', 'status': 'assigned'},
        ],
      );

      final cached = await cache.getCachedSerials(tenantId: 'tenant-a');
      expect(cached.length, 2);
      expect(cached.map((s) => s['serialNumber']), containsAll(['SN1', 'SN2']));
    });

    test('does not leak cached serials across tenants', () async {
      await cache.upsertSerial(
        tenantId: 'tenant-a',
        serialNumber: 'SN1',
        payload: {'serialNumber': 'SN1'},
      );

      final cachedForOtherTenant = await cache.getCachedSerials(
        tenantId: 'tenant-b',
      );
      expect(cachedForOtherTenant, isEmpty);
    });
  });
}
