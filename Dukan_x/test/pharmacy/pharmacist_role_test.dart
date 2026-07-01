import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/models/user_role.dart';
import 'package:dukanx/core/services/role_management_service.dart';

/// Unit tests for the pharmacist least-privilege role.
///
/// Validates: Requirements 10.1 (distinct pharmacist role exists) and
/// Requirements 10.8 (every granted permission is allowed and every excluded
/// permission is denied via [RolePermissions.hasPermission]).
void main() {
  group('Pharmacist role — existence and distinctness (R10.1)', () {
    test('pharmacist is a defined UserRole enum value', () {
      expect(UserRole.values, contains(UserRole.pharmacist));
    });

    test('pharmacist is distinct from every other role', () {
      // Each role name is unique, so pharmacist must not collide with another.
      final names = UserRole.values.map((r) => r.name).toList();
      final uniqueNames = names.toSet();
      expect(
        uniqueNames.length,
        names.length,
        reason: 'UserRole names must be unique',
      );

      for (final role in UserRole.values) {
        if (role == UserRole.pharmacist) continue;
        expect(
          role == UserRole.pharmacist,
          isFalse,
          reason: 'pharmacist must be distinct from ${role.name}',
        );
      }
    });
  });

  group('Pharmacist granted permissions are allowed (R10.2 / R10.8)', () {
    // Conceptual grant -> actual Permission enum value:
    //  dispensing operations      -> createBill, printBill
    //  prescription capture       -> capturePrescription
    //  batch / expiry view        -> viewStock
    //  narcotic / H1 register      -> registerEntry
    const grantedPermissions = <Permission>{
      Permission.createBill,
      Permission.printBill,
      Permission.capturePrescription,
      Permission.viewStock,
      Permission.registerEntry,
    };

    for (final permission in grantedPermissions) {
      test('pharmacist is GRANTED ${permission.name}', () {
        expect(
          RolePermissions.hasPermission(UserRole.pharmacist, permission),
          isTrue,
          reason: '${permission.name} should be granted to pharmacist',
        );
      });
    }

    test('pharmacist permission set equals exactly the granted set', () {
      expect(
        RolePermissions.getPermissions(UserRole.pharmacist),
        equals(grantedPermissions),
      );
    });
  });

  group('Pharmacist excluded permissions are denied (R10.3 / R10.8)', () {
    // Conceptual denial -> actual Permission enum value:
    //  pricing override     -> applyHighDiscount
    //  business settings    -> manageSettings
    //  financial reports    -> viewReports
    //  user management      -> manageUsers
    const deniedPermissions = <Permission>{
      Permission.applyHighDiscount,
      Permission.manageSettings,
      Permission.viewReports,
      Permission.manageUsers,
    };

    for (final permission in deniedPermissions) {
      test('pharmacist is DENIED ${permission.name}', () {
        expect(
          RolePermissions.hasPermission(UserRole.pharmacist, permission),
          isFalse,
          reason: '${permission.name} should be denied to pharmacist',
        );
      });
    }

    test('pharmacist is denied every permission outside the granted set', () {
      const grantedPermissions = <Permission>{
        Permission.createBill,
        Permission.printBill,
        Permission.capturePrescription,
        Permission.viewStock,
        Permission.registerEntry,
      };

      for (final permission in Permission.values) {
        if (grantedPermissions.contains(permission)) continue;
        expect(
          RolePermissions.hasPermission(UserRole.pharmacist, permission),
          isFalse,
          reason: '${permission.name} must NOT be granted to pharmacist',
        );
      }
    });
  });
}
