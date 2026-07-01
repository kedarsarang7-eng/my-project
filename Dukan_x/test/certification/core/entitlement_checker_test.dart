import 'package:flutter_test/flutter_test.dart';

import 'entitlement_checker.dart';

void main() {
  const checker = EntitlementChecker();

  group('EntitlementChecker', () {
    group('accessible when all conditions met', () {
      test('grants access when subscription is active, license activated, '
          'and feature is entitled', () {
        final sub = Subscription(
          id: 'sub-001',
          entitlements: {'billing', 'reports', 'analytics'},
          isActive: true,
          licenseActivated: true,
        );

        final decision = checker.check(sub, 'billing');

        expect(decision.result, AccessResult.accessible);
        expect(decision.denialReason, isNull);
      });

      test('grants access for any entitled feature in the set', () {
        final sub = Subscription(
          id: 'sub-002',
          entitlements: {'inventory', 'invoicing', 'multi-branch'},
          isActive: true,
          licenseActivated: true,
        );

        expect(checker.check(sub, 'inventory').result, AccessResult.accessible);
        expect(checker.check(sub, 'invoicing').result, AccessResult.accessible);
        expect(
          checker.check(sub, 'multi-branch').result,
          AccessResult.accessible,
        );
      });
    });

    group('blocked when subscription is inactive', () {
      test('denies access with reason when subscription is not active', () {
        final sub = Subscription(
          id: 'sub-expired',
          entitlements: {'billing', 'reports'},
          isActive: false,
          licenseActivated: true,
        );

        final decision = checker.check(sub, 'billing');

        expect(decision.result, AccessResult.blocked);
        expect(decision.denialReason, isNotNull);
        expect(decision.denialReason, contains('not active'));
      });
    });

    group('blocked when license is not activated', () {
      test('denies access with reason when license not activated', () {
        final sub = Subscription(
          id: 'sub-003',
          entitlements: {'billing', 'reports'},
          isActive: true,
          licenseActivated: false,
        );

        final decision = checker.check(sub, 'billing');

        expect(decision.result, AccessResult.blocked);
        expect(decision.denialReason, isNotNull);
        expect(decision.denialReason, contains('not activated'));
      });
    });

    group(
      'blocked when feature is not entitled (upgrade/downgrade gating)',
      () {
        test('denies access when feature is not in entitlement set', () {
          final sub = Subscription(
            id: 'sub-basic',
            entitlements: {'billing'},
            isActive: true,
            licenseActivated: true,
          );

          final decision = checker.check(sub, 'advanced-analytics');

          expect(decision.result, AccessResult.blocked);
          expect(decision.denialReason, isNotNull);
          expect(decision.denialReason, contains('not entitled'));
        });

        test('denies access for empty entitlement set', () {
          final sub = Subscription(
            id: 'sub-empty',
            entitlements: <String>{},
            isActive: true,
            licenseActivated: true,
          );

          final decision = checker.check(sub, 'billing');

          expect(decision.result, AccessResult.blocked);
          expect(decision.denialReason, contains('not entitled'));
        });
      },
    );

    group('priority of denial reasons', () {
      test(
        'inactive subscription takes precedence over unactivated license',
        () {
          final sub = Subscription(
            id: 'sub-both-bad',
            entitlements: {'billing'},
            isActive: false,
            licenseActivated: false,
          );

          final decision = checker.check(sub, 'billing');

          expect(decision.result, AccessResult.blocked);
          expect(decision.denialReason, contains('not active'));
        },
      );

      test(
        'inactive subscription takes precedence over missing entitlement',
        () {
          final sub = Subscription(
            id: 'sub-inactive-no-ent',
            entitlements: <String>{},
            isActive: false,
            licenseActivated: true,
          );

          final decision = checker.check(sub, 'billing');

          expect(decision.result, AccessResult.blocked);
          expect(decision.denialReason, contains('not active'));
        },
      );

      test('unactivated license takes precedence over missing entitlement', () {
        final sub = Subscription(
          id: 'sub-no-license-no-ent',
          entitlements: <String>{},
          isActive: true,
          licenseActivated: false,
        );

        final decision = checker.check(sub, 'billing');

        expect(decision.result, AccessResult.blocked);
        expect(decision.denialReason, contains('not activated'));
      });
    });
  });
}
