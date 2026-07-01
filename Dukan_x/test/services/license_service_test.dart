import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:dukanx/core/database/app_database.dart';
import 'package:dukanx/services/license_service.dart';
import 'package:dukanx/models/business_type.dart';

void main() {
  late AppDatabase database;
  late LicenseService licenseService;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    licenseService = LicenseService(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('LicenseService - validateLicense', () {
    test('Should return notFound when no license is cached', () async {
      // Act
      final result = await licenseService.validateLicense(
        requiredBusinessType: BusinessType.grocery,
      );

      // Assert
      expect(result.isValid, isFalse);
      expect(result.status, LicenseStatus.notFound);
    });

    test('Should return businessTypeMismatch when business types do not match', () async {
      // Arrange
      final now = DateTime.now();
      await database.into(database.licenseCache).insert(
        LicenseCacheCompanion.insert(
          id: 'lic_1',
          licenseKey: 'LIC-GROCERY-123',
          businessType: 'grocery',
          customerId: const Value('cust_1'),
          enabledModulesJson: const Value('["billing"]'),
          issueDate: now,
          expiryDate: now.add(const Duration(days: 30)),
          deviceFingerprint: 'mock_fp',
          deviceId: const Value('dev_1'),
          lastValidatedAt: now,
          validationToken: 'tok',
          tokenSignature: 'sig',
          createdAt: now,
          updatedAt: now,
          status: const Value('active'),
        ),
      );

      // Act
      final result = await licenseService.validateLicense(
        requiredBusinessType: BusinessType.pharmacy, // Mismatch!
      );

      // Assert
      expect(result.isValid, isFalse);
      expect(result.status, LicenseStatus.businessTypeMismatch);
    });

    test('Should return expired when expiry date has passed', () async {
      // Arrange
      final now = DateTime.now();
      await database.into(database.licenseCache).insert(
        LicenseCacheCompanion.insert(
          id: 'lic_1',
          licenseKey: 'LIC-GROCERY-123',
          businessType: 'grocery',
          customerId: const Value('cust_1'),
          enabledModulesJson: const Value('["billing"]'),
          issueDate: now.subtract(const Duration(days: 60)),
          expiryDate: now.subtract(const Duration(days: 1)), // Expired yesterday
          deviceFingerprint: 'mock_fp',
          deviceId: const Value('dev_1'),
          lastValidatedAt: now.subtract(const Duration(days: 1)),
          validationToken: 'tok',
          tokenSignature: 'sig',
          createdAt: now.subtract(const Duration(days: 60)),
          updatedAt: now.subtract(const Duration(days: 1)),
          status: const Value('active'),
        ),
      );

      // Act
      final result = await licenseService.validateLicense(
        requiredBusinessType: BusinessType.grocery,
      );

      // Assert
      expect(result.isValid, isFalse);
      expect(result.status, LicenseStatus.expired);
    });

    test('Should return valid when license is active and correct', () async {
      // Arrange
      final now = DateTime.now();
      await database.into(database.licenseCache).insert(
        LicenseCacheCompanion.insert(
          id: 'lic_1',
          licenseKey: 'LIC-GROCERY-123',
          businessType: 'grocery',
          customerId: const Value('cust_1'),
          enabledModulesJson: const Value('["billing"]'),
          issueDate: now,
          expiryDate: now.add(const Duration(days: 30)),
          deviceFingerprint: 'mock_fp',
          deviceId: const Value('dev_1'),
          lastValidatedAt: now,
          validationToken: 'tok',
          tokenSignature: 'sig',
          createdAt: now,
          updatedAt: now,
          status: const Value('active'),
        ),
      );

      // Act
      final result = await licenseService.validateLicense(
        requiredBusinessType: BusinessType.grocery,
      );

      // Assert
      expect(result.isValid, isTrue);
      expect(result.status, LicenseStatus.valid);
      expect(result.enabledModules, contains('billing'));
    });
  });
}
