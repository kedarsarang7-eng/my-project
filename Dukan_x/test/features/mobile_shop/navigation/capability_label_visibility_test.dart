/// Capability Label Visibility Tests — Task 15.3
///
/// Verifies that generic labels (Accounting, Tax, Audit, Backup, Compliance)
/// are only visible when corresponding mobile-shop features are enabled
/// and the user holds appropriate permissions/capabilities.
///
/// Requirements validated: 9.10–9.11, 10.10–10.12
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/features/mobile_shop/config/feature_policy_config.dart';
import 'package:dukanx/features/mobile_shop/navigation/capability_label_visibility.dart';
import 'package:dukanx/features/mobile_shop/permissions/mobile_shop_permissions.dart';

void main() {
  // ─── Default mobileShop tenant with all standard capabilities ──────────────

  group('CapabilityLabelVisibility', () {
    group('accounting label', () {
      test(
        'visible when IMEI_TRACKING enabled and finance:view permission',
        () {
          final visibility = CapabilityLabelVisibility(
            featurePolicy: kFeaturePolicyConfig,
            tenantCapabilities: {'imei_tracking', 'accounting'},
            tenantPermissions: {MobileShopPermissions.financeView},
            enabledFeatureIds: {'IMEI_TRACKING'},
          );

          expect(
            visibility.isVisible(MobileShopCapabilityLabel.accounting),
            isTrue,
          );
        },
      );

      test(
        'visible when BUNDLES enabled and finance:manage permission (implies view)',
        () {
          final visibility = CapabilityLabelVisibility(
            featurePolicy: kFeaturePolicyConfig,
            tenantCapabilities: {'bundles'},
            tenantPermissions: {MobileShopPermissions.financeManage},
            enabledFeatureIds: {'BUNDLES'},
          );

          expect(
            visibility.isVisible(MobileShopCapabilityLabel.accounting),
            isTrue,
          );
        },
      );

      test('hidden when no enabling feature is active', () {
        final visibility = CapabilityLabelVisibility(
          featurePolicy: kFeaturePolicyConfig,
          tenantCapabilities: {'sim_recharge'},
          tenantPermissions: {MobileShopPermissions.financeView},
          enabledFeatureIds: {'SIM_RECHARGE'},
        );

        expect(
          visibility.isVisible(MobileShopCapabilityLabel.accounting),
          isFalse,
        );
      });

      test('hidden when user lacks finance:view permission', () {
        final visibility = CapabilityLabelVisibility(
          featurePolicy: kFeaturePolicyConfig,
          tenantCapabilities: {'imei_tracking'},
          tenantPermissions: {MobileShopPermissions.imeiView},
          enabledFeatureIds: {'IMEI_TRACKING'},
        );

        expect(
          visibility.isVisible(MobileShopCapabilityLabel.accounting),
          isFalse,
        );
      });
    });

    group('tax label', () {
      test(
        'visible when IMEI_TRACKING enabled with tax capability and finance permission',
        () {
          final visibility = CapabilityLabelVisibility(
            featurePolicy: kFeaturePolicyConfig,
            tenantCapabilities: {'imei_tracking', 'tax_management'},
            tenantPermissions: {MobileShopPermissions.financeView},
            enabledFeatureIds: {'IMEI_TRACKING'},
          );

          expect(visibility.isVisible(MobileShopCapabilityLabel.tax), isTrue);
        },
      );

      test('hidden when tenant lacks tax_management capability', () {
        final visibility = CapabilityLabelVisibility(
          featurePolicy: kFeaturePolicyConfig,
          tenantCapabilities: {'imei_tracking'},
          tenantPermissions: {MobileShopPermissions.financeView},
          enabledFeatureIds: {'IMEI_TRACKING'},
        );

        expect(visibility.isVisible(MobileShopCapabilityLabel.tax), isFalse);
      });
    });

    group('audit label', () {
      test('visible when IMEI_TRACKING enabled with audit:view permission', () {
        final visibility = CapabilityLabelVisibility(
          featurePolicy: kFeaturePolicyConfig,
          tenantCapabilities: {'imei_tracking'},
          tenantPermissions: {MobileShopPermissions.auditView},
          enabledFeatureIds: {'IMEI_TRACKING'},
        );

        expect(visibility.isVisible(MobileShopCapabilityLabel.audit), isTrue);
      });

      test('visible when SERVICE_JOBS enabled with audit:view', () {
        final visibility = CapabilityLabelVisibility(
          featurePolicy: kFeaturePolicyConfig,
          tenantCapabilities: {'service_jobs'},
          tenantPermissions: {MobileShopPermissions.auditView},
          enabledFeatureIds: {'SERVICE_JOBS'},
        );

        expect(visibility.isVisible(MobileShopCapabilityLabel.audit), isTrue);
      });

      test('hidden when user lacks audit:view permission', () {
        final visibility = CapabilityLabelVisibility(
          featurePolicy: kFeaturePolicyConfig,
          tenantCapabilities: {'imei_tracking'},
          tenantPermissions: {MobileShopPermissions.imeiView},
          enabledFeatureIds: {'IMEI_TRACKING'},
        );

        expect(visibility.isVisible(MobileShopCapabilityLabel.audit), isFalse);
      });
    });

    group('backup label', () {
      test(
        'visible when MOBILE_REPORTS enabled with reports:export permission',
        () {
          final visibility = CapabilityLabelVisibility(
            featurePolicy: kFeaturePolicyConfig,
            tenantCapabilities: {'reports'},
            tenantPermissions: {MobileShopPermissions.reportsExport},
            enabledFeatureIds: {'MOBILE_REPORTS'},
          );

          expect(
            visibility.isVisible(MobileShopCapabilityLabel.backup),
            isTrue,
          );
        },
      );

      test('hidden when user only has reports:view (not export)', () {
        final visibility = CapabilityLabelVisibility(
          featurePolicy: kFeaturePolicyConfig,
          tenantCapabilities: {'reports'},
          tenantPermissions: {MobileShopPermissions.reportsView},
          enabledFeatureIds: {'MOBILE_REPORTS'},
        );

        expect(visibility.isVisible(MobileShopCapabilityLabel.backup), isFalse);
      });

      test('hidden when MOBILE_REPORTS is not enabled', () {
        final visibility = CapabilityLabelVisibility(
          featurePolicy: kFeaturePolicyConfig,
          tenantCapabilities: {'reports'},
          tenantPermissions: {MobileShopPermissions.reportsExport},
          enabledFeatureIds: {'IMEI_TRACKING'},
        );

        expect(visibility.isVisible(MobileShopCapabilityLabel.backup), isFalse);
      });
    });

    group('compliance label', () {
      test(
        'visible when E_WAY_BILL enabled with e_way capability and settings:manage',
        () {
          final visibility = CapabilityLabelVisibility(
            featurePolicy: kFeaturePolicyConfig,
            tenantCapabilities: {'e_way'},
            tenantPermissions: {MobileShopPermissions.settingsManage},
            enabledFeatureIds: {'E_WAY_BILL'},
          );

          expect(
            visibility.isVisible(MobileShopCapabilityLabel.compliance),
            isTrue,
          );
        },
      );

      test('hidden when E_WAY_BILL is not enabled', () {
        final visibility = CapabilityLabelVisibility(
          featurePolicy: kFeaturePolicyConfig,
          tenantCapabilities: {'e_way'},
          tenantPermissions: {MobileShopPermissions.settingsManage},
          enabledFeatureIds: {'IMEI_TRACKING'},
        );

        expect(
          visibility.isVisible(MobileShopCapabilityLabel.compliance),
          isFalse,
        );
      });

      test('hidden when tenant lacks e_way capability', () {
        final visibility = CapabilityLabelVisibility(
          featurePolicy: kFeaturePolicyConfig,
          tenantCapabilities: {'imei_tracking'},
          tenantPermissions: {MobileShopPermissions.settingsManage},
          enabledFeatureIds: {'E_WAY_BILL'},
        );

        expect(
          visibility.isVisible(MobileShopCapabilityLabel.compliance),
          isFalse,
        );
      });
    });

    group('visibleLabels and hiddenLabels', () {
      test('returns all visible labels for fully-enabled tenant', () {
        final visibility = CapabilityLabelVisibility(
          featurePolicy: kFeaturePolicyConfig,
          tenantCapabilities: {
            'imei_tracking',
            'tax_management',
            'reports',
            'e_way',
          },
          tenantPermissions: {
            MobileShopPermissions.financeView,
            MobileShopPermissions.auditView,
            MobileShopPermissions.reportsExport,
            MobileShopPermissions.settingsManage,
          },
          enabledFeatureIds: {'IMEI_TRACKING', 'MOBILE_REPORTS', 'E_WAY_BILL'},
        );

        final visible = visibility.visibleLabels;
        expect(visible, contains(MobileShopCapabilityLabel.accounting));
        expect(visible, contains(MobileShopCapabilityLabel.tax));
        expect(visible, contains(MobileShopCapabilityLabel.audit));
        expect(visible, contains(MobileShopCapabilityLabel.backup));
        expect(visible, contains(MobileShopCapabilityLabel.compliance));
      });

      test('returns empty set for tenant with no enabled features', () {
        final visibility = CapabilityLabelVisibility(
          featurePolicy: kFeaturePolicyConfig,
          tenantCapabilities: <String>{},
          tenantPermissions: <String>{},
          enabledFeatureIds: <String>{},
        );

        expect(visibility.visibleLabels, isEmpty);
        expect(
          visibility.hiddenLabels.length,
          equals(MobileShopCapabilityLabel.values.length),
        );
      });
    });

    group('falls back to enabledByDefault when enabledFeatureIds is null', () {
      test('audit visible via default-enabled IMEI_TRACKING', () {
        final visibility = CapabilityLabelVisibility(
          featurePolicy: kFeaturePolicyConfig,
          tenantCapabilities: {'imei_tracking'},
          tenantPermissions: {MobileShopPermissions.auditView},
          // enabledFeatureIds is null — uses enabledByDefault
        );

        expect(visibility.isVisible(MobileShopCapabilityLabel.audit), isTrue);
      });

      test('compliance hidden because E_WAY_BILL defaults to disabled', () {
        final visibility = CapabilityLabelVisibility(
          featurePolicy: kFeaturePolicyConfig,
          tenantCapabilities: {'e_way'},
          tenantPermissions: {MobileShopPermissions.settingsManage},
          // enabledFeatureIds is null — E_WAY_BILL.enabledByDefault = false
        );

        expect(
          visibility.isVisible(MobileShopCapabilityLabel.compliance),
          isFalse,
        );
      });
    });
  });
}
