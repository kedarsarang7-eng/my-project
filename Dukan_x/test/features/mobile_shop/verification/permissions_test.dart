// ============================================================================
// MOBILE SHOP — PERMISSION ENFORCEMENT TESTS
// ============================================================================
// Tests for MobilePolicyGuardWidget enforcement, permission expansion,
// compatibility matrix migration, and permission checker.
//
// **Validates: Requirements 8.1–8.7, 8.13, 13.1–13.2**
//
// Run: flutter test test/features/mobile_shop/verification/permissions_test.dart
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/features/mobile_shop/auth/business_type.dart';
import 'package:dukanx/features/mobile_shop/auth/domain_error.dart';
import 'package:dukanx/features/mobile_shop/auth/mobile_policy_guard.dart';
import 'package:dukanx/features/mobile_shop/auth/tenant_context.dart';
import 'package:dukanx/features/mobile_shop/auth/tenant_context_resolver.dart';
import 'package:dukanx/features/mobile_shop/models/common_models.dart';
import 'package:dukanx/features/mobile_shop/permissions/compatibility_matrix.dart';
import 'package:dukanx/features/mobile_shop/permissions/mobile_shop_permissions.dart';
import 'package:dukanx/features/mobile_shop/permissions/permission_checker.dart';

// ─── Mock Resolvers ──────────────────────────────────────────────────────────

class _GrantedResolver implements TenantContextResolver {
  final Set<String> permissions;

  _GrantedResolver({this.permissions = const {}});

  @override
  TenantResult<TenantContext> require() => TenantSuccess(
    TenantContext(
      tenantId: 'test-tenant',
      businessId: 'test-biz',
      subjectId: 'test-user',
      businessType: MobileShopBusinessType.mobileShop,
      permissions: permissions,
      correlationId: 'corr-001',
    ),
  );

  @override
  TenantResult<TenantContext> requireMobileShop() => require();

  @override
  TenantContext? get current =>
      (require() as TenantSuccess<TenantContext>).value;

  @override
  void invalidate() {}
}

class _SessionExpiredResolver implements TenantContextResolver {
  @override
  TenantResult<TenantContext> require() =>
      const TenantFailure(DomainError.sessionExpired());

  @override
  TenantResult<TenantContext> requireMobileShop() =>
      const TenantFailure(DomainError.sessionExpired());

  @override
  TenantContext? get current => null;

  @override
  void invalidate() {}
}

class _WrongBusinessTypeResolver implements TenantContextResolver {
  @override
  TenantResult<TenantContext> require() => const TenantSuccess(
    TenantContext(
      tenantId: 'grocery-tenant',
      businessId: 'grocery-biz',
      subjectId: 'grocery-user',
      businessType: MobileShopBusinessType.grocery,
      permissions: {},
      correlationId: 'corr-002',
    ),
  );

  @override
  TenantResult<TenantContext> requireMobileShop() =>
      const TenantFailure(DomainError.wrongBusinessType());

  @override
  TenantContext? get current => null;

  @override
  void invalidate() {}
}

Widget _testApp(Widget child) => MaterialApp(home: Scaffold(body: child));

// ─── Main Test Suite ─────────────────────────────────────────────────────────

void main() {
  // ==========================================================================
  // GROUP 1: MobilePolicyGuard — Logic
  // ==========================================================================
  group('MobilePolicyGuard — logic', () {
    test('valid session + correct permission → GuardGranted', () {
      final resolver = _GrantedResolver(
        permissions: {MobileShopPermissions.serviceView},
      );
      final guard = MobilePolicyGuard(resolver: resolver);

      final result = guard.check(
        requiredPermission: MobileShopPermissions.serviceView,
      );
      expect(result, isA<GuardGranted>());
    });

    test(
      'valid session + missing permission → GuardDenied permissionDenied',
      () {
        final resolver = _GrantedResolver(permissions: const {});
        final guard = MobilePolicyGuard(resolver: resolver);

        final result = guard.check(
          requiredPermission: MobileShopPermissions.serviceView,
        );
        expect(result, isA<GuardDenied>());
        expect(
          (result as GuardDenied).denial.kind,
          GuardDenialKind.permissionDenied,
        );
      },
    );

    test('null permission check → only business type required', () {
      final resolver = _GrantedResolver(permissions: const {});
      final guard = MobilePolicyGuard(resolver: resolver);

      final result = guard.check(requiredPermission: null);
      expect(result, isA<GuardGranted>());
    });

    test('expired session → GuardDenied sessionMissing', () {
      final resolver = _SessionExpiredResolver();
      final guard = MobilePolicyGuard(resolver: resolver);

      final result = guard.check(
        requiredPermission: MobileShopPermissions.imeiView,
      );
      expect(result, isA<GuardDenied>());
      expect(
        (result as GuardDenied).denial.kind,
        GuardDenialKind.sessionMissing,
      );
    });

    test('wrong business type → GuardDenied wrongBusinessType', () {
      final resolver = _WrongBusinessTypeResolver();
      final guard = MobilePolicyGuard(resolver: resolver);

      final result = guard.check(
        requiredPermission: MobileShopPermissions.imeiView,
      );
      expect(result, isA<GuardDenied>());
      expect(
        (result as GuardDenied).denial.kind,
        GuardDenialKind.wrongBusinessType,
      );
    });

    test('checkAny grants when at least one permission present', () {
      final resolver = _GrantedResolver(
        permissions: {MobileShopPermissions.warrantyView},
      );
      final guard = MobilePolicyGuard(resolver: resolver);

      final result = guard.checkAny(
        permissions: [
          MobileShopPermissions.serviceView,
          MobileShopPermissions.warrantyView,
        ],
      );
      expect(result, isA<GuardGranted>());
    });

    test('checkAny denies when no permission matches', () {
      final resolver = _GrantedResolver(permissions: const {});
      final guard = MobilePolicyGuard(resolver: resolver);

      final result = guard.checkAny(
        permissions: [
          MobileShopPermissions.serviceView,
          MobileShopPermissions.warrantyView,
        ],
      );
      expect(result, isA<GuardDenied>());
    });

    test('checkAll grants when all permissions present', () {
      final resolver = _GrantedResolver(
        permissions: {
          MobileShopPermissions.serviceView,
          MobileShopPermissions.imeiView,
        },
      );
      final guard = MobilePolicyGuard(resolver: resolver);

      final result = guard.checkAll(
        permissions: [
          MobileShopPermissions.serviceView,
          MobileShopPermissions.imeiView,
        ],
      );
      expect(result, isA<GuardGranted>());
    });

    test('checkAll denies when one permission is missing', () {
      final resolver = _GrantedResolver(
        permissions: {MobileShopPermissions.serviceView},
      );
      final guard = MobilePolicyGuard(resolver: resolver);

      final result = guard.checkAll(
        permissions: [
          MobileShopPermissions.serviceView,
          MobileShopPermissions.imeiView, // missing
        ],
      );
      expect(result, isA<GuardDenied>());
    });
  });

  // ==========================================================================
  // GROUP 2: MobilePolicyGuardWidget — Widget Rendering
  // ==========================================================================
  group('MobilePolicyGuardWidget — widget rendering', () {
    testWidgets('granted renders builder content', (tester) async {
      final resolver = _GrantedResolver(
        permissions: {MobileShopPermissions.imeiView},
      );

      await tester.pumpWidget(
        _testApp(
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.imeiView,
            builder: (context, ctx) => const Text('Protected Content'),
          ),
        ),
      );

      expect(find.text('Protected Content'), findsOneWidget);
    });

    testWidgets('denied renders default denial widget (not builder)', (
      tester,
    ) async {
      final resolver = _SessionExpiredResolver();

      await tester.pumpWidget(
        _testApp(
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.imeiView,
            builder: (context, ctx) => const Text('Should NOT appear'),
          ),
        ),
      );

      expect(find.text('Should NOT appear'), findsNothing);
      expect(find.text('Session Expired'), findsOneWidget);
    });

    testWidgets('wrong business type shows "Not Available"', (tester) async {
      final resolver = _WrongBusinessTypeResolver();

      await tester.pumpWidget(
        _testApp(
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.imeiView,
            builder: (context, ctx) => const Text('Should NOT appear'),
          ),
        ),
      );

      expect(find.text('Not Available'), findsOneWidget);
    });

    testWidgets('permission denied shows "Access Denied"', (tester) async {
      final resolver = _GrantedResolver(permissions: const {});

      await tester.pumpWidget(
        _testApp(
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.settingsManage,
            builder: (context, ctx) => const Text('Should NOT appear'),
          ),
        ),
      );

      expect(find.text('Access Denied'), findsOneWidget);
    });

    testWidgets('custom deniedBuilder is used when provided', (tester) async {
      final resolver = _SessionExpiredResolver();

      await tester.pumpWidget(
        _testApp(
          MobilePolicyGuardWidget(
            resolver: resolver,
            requiredPermission: MobileShopPermissions.imeiView,
            builder: (context, ctx) => const Text('Never'),
            deniedBuilder: (context, denial) =>
                const Text('Custom Denial Widget'),
          ),
        ),
      );

      expect(find.text('Custom Denial Widget'), findsOneWidget);
    });

    testWidgets('no spinner shown on session expiry (AF-46 regression)', (
      tester,
    ) async {
      final resolver = _SessionExpiredResolver();

      await tester.pumpWidget(
        _testApp(
          MobilePolicyGuardWidget(
            resolver: resolver,
            builder: (context, ctx) => const Text('Never'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  // ==========================================================================
  // GROUP 3: Permission Expansion — Manage Implies View
  // ==========================================================================
  group('Permission expansion — manage implies view', () {
    test('serviceManage implies serviceView', () {
      final expanded = expandPermissions([MobileShopPermissions.serviceManage]);
      expect(expanded, contains(MobileShopPermissions.serviceView));
      expect(expanded, contains(MobileShopPermissions.serviceManage));
    });

    test('reportsExport implies reportsView', () {
      final expanded = expandPermissions([MobileShopPermissions.reportsExport]);
      expect(expanded, contains(MobileShopPermissions.reportsView));
    });

    test('view permission alone does NOT expand', () {
      final expanded = expandPermissions([MobileShopPermissions.serviceView]);
      expect(expanded, contains(MobileShopPermissions.serviceView));
      expect(expanded, isNot(contains(MobileShopPermissions.serviceManage)));
    });

    test(
      'all implications documented in MobileShopPermissions.implications',
      () {
        expect(
          MobileShopPermissions.implications.length,
          greaterThanOrEqualTo(8),
        );
      },
    );
  });

  // ==========================================================================
  // GROUP 4: Permission Checker — Business Type Guard
  // ==========================================================================
  group('Permission checker — business type guard', () {
    test('non-mobile_shop business type → denied', () {
      final ctx = TenantContextWire(
        tenantId: 't1',
        businessId: 'b1',
        subjectId: 's1',
        businessType: 'grocery',
        permissions: MobileShopPermissions.all,
        correlationId: 'c1',
      );

      final result = checkMobileShopPermission(
        ctx,
        MobileShopPermissions.imeiView,
      );
      expect(result.granted, isFalse);
    });

    test('mobile_shop with required permission → allowed', () {
      final ctx = TenantContextWire(
        tenantId: 't1',
        businessId: 'b1',
        subjectId: 's1',
        businessType: 'mobile_shop',
        permissions: [MobileShopPermissions.imeiView],
        correlationId: 'c2',
      );

      final result = checkMobileShopPermission(
        ctx,
        MobileShopPermissions.imeiView,
      );
      expect(result.granted, isTrue);
    });

    test('mobile_shop with manage implies view → view allowed', () {
      final ctx = TenantContextWire(
        tenantId: 't1',
        businessId: 'b1',
        subjectId: 's1',
        businessType: 'mobile_shop',
        permissions: [MobileShopPermissions.imeiManage],
        correlationId: 'c3',
      );

      // imeiManage implies imeiView
      final result = checkMobileShopPermission(
        ctx,
        MobileShopPermissions.imeiView,
      );
      expect(result.granted, isTrue);
    });
  });

  // ==========================================================================
  // GROUP 5: Compatibility Matrix — Role Migration
  // ==========================================================================
  group('Compatibility matrix — role migration', () {
    test('owner role grants all permissions', () {
      final result = migratePermissions(
        currentPermissions: [],
        role: 'owner',
        capabilities: [],
      );
      expect(result.changed, isTrue);
      expect(result.permissions, containsAll(MobileShopPermissions.all));
    });

    test('staff role grants limited view permissions', () {
      final result = migratePermissions(
        currentPermissions: [],
        role: 'staff',
        capabilities: [],
      );
      expect(result.permissions, contains(MobileShopPermissions.serviceView));
      expect(result.permissions, contains(MobileShopPermissions.imeiView));
      expect(result.permissions, contains(MobileShopPermissions.warrantyView));
      expect(
        result.permissions,
        isNot(contains(MobileShopPermissions.serviceManage)),
      );
    });

    test('unknown role adds nothing from role map', () {
      final result = migratePermissions(
        currentPermissions: ['mobile_shop:imei:view'],
        role: 'unknown_role',
        capabilities: [],
      );
      // Only the existing permission remains (no role-based additions)
      expect(result.permissions, contains(MobileShopPermissions.imeiView));
      expect(result.changed, isFalse);
    });

    test('capability useIMEI adds imeiView and imeiManage', () {
      final result = migratePermissions(
        currentPermissions: [],
        role: 'staff',
        capabilities: ['useIMEI'],
      );
      expect(result.permissions, contains(MobileShopPermissions.imeiView));
      expect(result.permissions, contains(MobileShopPermissions.imeiManage));
    });

    test('legacy manage_staff maps to serviceView + serviceManage', () {
      final result = migratePermissions(
        currentPermissions: ['manage_staff'],
        role: 'cashier',
        capabilities: [],
      );
      expect(result.permissions, contains(MobileShopPermissions.serviceView));
      expect(result.permissions, contains(MobileShopPermissions.serviceManage));
    });

    test('idempotency — calling twice produces same result', () {
      final first = migratePermissions(
        currentPermissions: [],
        role: 'manager',
        capabilities: ['useWarranty'],
      );
      final second = migratePermissions(
        currentPermissions: first.permissions,
        role: 'manager',
        capabilities: ['useWarranty'],
      );
      expect(second.changed, isFalse);
      expect(second.permissions, equals(first.permissions));
    });

    test('migration never removes existing permissions', () {
      const existing = ['mobile_shop:custom:special'];
      final result = migratePermissions(
        currentPermissions: existing,
        role: 'staff',
        capabilities: [],
      );
      expect(result.permissions, contains('mobile_shop:custom:special'));
    });
  });

  // ==========================================================================
  // GROUP 6: MobileShopPermissions — Constants
  // ==========================================================================
  group('MobileShopPermissions — constants', () {
    test('all list has 17 permissions', () {
      expect(MobileShopPermissions.all.length, 17);
    });

    test('no duplicate permissions in the all list', () {
      final unique = MobileShopPermissions.all.toSet();
      expect(unique.length, MobileShopPermissions.all.length);
    });

    test('every permission follows domain:resource:action naming', () {
      for (final perm in MobileShopPermissions.all) {
        expect(
          perm.split(':').length,
          3,
          reason: '$perm does not follow domain:resource:action',
        );
        expect(
          perm.startsWith('mobile_shop:'),
          isTrue,
          reason: '$perm does not start with mobile_shop:',
        );
      }
    });

    test('isValidMobileShopPermission works correctly', () {
      expect(
        isValidMobileShopPermission(MobileShopPermissions.imeiView),
        isTrue,
      );
      expect(isValidMobileShopPermission('fake:permission:value'), isFalse);
    });
  });
}
