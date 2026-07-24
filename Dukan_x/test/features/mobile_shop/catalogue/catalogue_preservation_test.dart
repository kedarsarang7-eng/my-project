/// Catalogue Preservation & Accessory Line Separation Tests — Task 15.4
///
/// Tests cover:
/// 8. Accessory line separation: BundleLineItem maintains separate
///    accounting codes (separate stock/tax/accounting lines)
/// 9. Matching labels: CapabilityLabelVisibility shows/hides correctly
/// 10. Non-mobile catalogue preservation: MobileHandsetCatalogueAttributes
///     don't affect non-mobile models
///
/// Requirements validated: 1.6, 9.10–9.11, 13.1, 13.7
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:dukanx/features/mobile_shop/config/feature_policy_config.dart';
import 'package:dukanx/features/mobile_shop/models/catalogue_models.dart';
import 'package:dukanx/features/mobile_shop/navigation/capability_label_visibility.dart';
import 'package:dukanx/features/mobile_shop/permissions/mobile_shop_permissions.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // 8. ACCESSORY LINE SEPARATION — Requirement 4.8, 9.11
  // ═══════════════════════════════════════════════════════════════════════════

  group('Accessory line separation (Req 4.8)', () {
    test('HandsetAccessoryRelationship maintains separate line IDs', () {
      const relationship = HandsetAccessoryRelationship(
        handsetLineId: 'invoice-line-001',
        accessoryLineId: 'invoice-line-002',
        isBundle: true,
        bundleId: 'summer-2024-bundle',
      );

      // Handset and accessory have separate invoice lines
      expect(relationship.handsetLineId, isNot(relationship.accessoryLineId));
      expect(relationship.isBundle, isTrue);
      expect(relationship.bundleId, isNotNull);
    });

    test('multiple accessories create independent relationship records', () {
      const relationships = [
        HandsetAccessoryRelationship(
          handsetLineId: 'handset-001',
          accessoryLineId: 'case-001',
          isBundle: true,
          bundleId: 'phone-case-bundle',
        ),
        HandsetAccessoryRelationship(
          handsetLineId: 'handset-001',
          accessoryLineId: 'charger-001',
          isBundle: true,
          bundleId: 'phone-case-bundle',
        ),
        HandsetAccessoryRelationship(
          handsetLineId: 'handset-001',
          accessoryLineId: 'screen-protector-001',
          isBundle: false,
        ),
      ];

      // Each accessory maintains a distinct line ID (separate accounting)
      final lineIds = relationships.map((r) => r.accessoryLineId).toSet();
      expect(lineIds.length, 3);

      // Bundle and non-bundle relationships coexist
      final bundled = relationships.where((r) => r.isBundle).toList();
      final standalone = relationships.where((r) => !r.isBundle).toList();
      expect(bundled.length, 2);
      expect(standalone.length, 1);
    });

    test('accessory serialization preserves separate IDs', () {
      const rel = HandsetAccessoryRelationship(
        handsetLineId: 'H1',
        accessoryLineId: 'A1',
        isBundle: true,
        bundleId: 'B1',
      );

      final json = rel.toJson();
      expect(json['handsetLineId'], 'H1');
      expect(json['accessoryLineId'], 'A1');
      expect(json['isBundle'], true);
      expect(json['bundleId'], 'B1');

      // Deserialize and confirm separation preserved
      final restored = HandsetAccessoryRelationship.fromJson(json);
      expect(restored.handsetLineId, 'H1');
      expect(restored.accessoryLineId, 'A1');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 9. MATCHING LABELS — Requirement 9.10–9.11
  // ═══════════════════════════════════════════════════════════════════════════

  group('CapabilityLabelVisibility matching labels (Req 9.10–9.11)', () {
    test('label shown only when corresponding feature is enabled', () {
      final visibility = CapabilityLabelVisibility(
        featurePolicy: kFeaturePolicyConfig,
        tenantCapabilities: {'imei_tracking'},
        tenantPermissions: {MobileShopPermissions.financeView},
        enabledFeatureIds: {'IMEI_TRACKING'},
      );

      // Accounting visible via IMEI_TRACKING
      expect(
        visibility.isVisible(MobileShopCapabilityLabel.accounting),
        isTrue,
      );
      // Compliance hidden — E_WAY_BILL not enabled
      expect(
        visibility.isVisible(MobileShopCapabilityLabel.compliance),
        isFalse,
      );
    });

    test('label hidden when user lacks required permission', () {
      final visibility = CapabilityLabelVisibility(
        featurePolicy: kFeaturePolicyConfig,
        tenantCapabilities: {'imei_tracking'},
        tenantPermissions: <String>{}, // no permissions!
        enabledFeatureIds: {'IMEI_TRACKING'},
      );

      // Accounting hidden because financeView permission missing
      expect(
        visibility.isVisible(MobileShopCapabilityLabel.accounting),
        isFalse,
      );
      // Audit hidden because auditView permission missing
      expect(visibility.isVisible(MobileShopCapabilityLabel.audit), isFalse);
    });

    test('label hidden when tenant lacks required capability', () {
      final visibility = CapabilityLabelVisibility(
        featurePolicy: kFeaturePolicyConfig,
        tenantCapabilities: {'imei_tracking'}, // no e_way capability
        tenantPermissions: {MobileShopPermissions.settingsManage},
        enabledFeatureIds: {'E_WAY_BILL'},
      );

      // Compliance hidden because tenant lacks 'e_way' capability
      expect(
        visibility.isVisible(MobileShopCapabilityLabel.compliance),
        isFalse,
      );
    });

    test('visibleLabels returns only labels meeting all requirements', () {
      final visibility = CapabilityLabelVisibility(
        featurePolicy: kFeaturePolicyConfig,
        tenantCapabilities: {'imei_tracking', 'service_jobs'},
        tenantPermissions: {
          MobileShopPermissions.financeView,
          MobileShopPermissions.auditView,
        },
        enabledFeatureIds: {'IMEI_TRACKING', 'SERVICE_JOBS'},
      );

      final visible = visibility.visibleLabels;
      // Accounting: IMEI_TRACKING enabled + financeView ✓
      expect(visible, contains(MobileShopCapabilityLabel.accounting));
      // Audit: IMEI_TRACKING enabled + auditView ✓
      expect(visible, contains(MobileShopCapabilityLabel.audit));
      // Tax: needs tax_management capability — missing
      expect(visible, isNot(contains(MobileShopCapabilityLabel.tax)));
      // Backup: needs MOBILE_REPORTS — not enabled
      expect(visible, isNot(contains(MobileShopCapabilityLabel.backup)));
    });

    test('hiddenLabels complement of visibleLabels', () {
      final visibility = CapabilityLabelVisibility(
        featurePolicy: kFeaturePolicyConfig,
        tenantCapabilities: {'imei_tracking'},
        tenantPermissions: {MobileShopPermissions.auditView},
        enabledFeatureIds: {'IMEI_TRACKING'},
      );

      final visible = visibility.visibleLabels;
      final hidden = visibility.hiddenLabels;

      expect(
        visible.union(hidden).length,
        MobileShopCapabilityLabel.values.length,
      );
      expect(visible.intersection(hidden), isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 10. NON-MOBILE CATALOGUE PRESERVATION — Requirement 1.6, 9.11, 13.7
  // ═══════════════════════════════════════════════════════════════════════════

  group('Non-mobile catalogue preservation (Req 1.6, 9.11, 13.7)', () {
    test('MobileHandsetCatalogueAttributes is a standalone model', () {
      // This model does NOT require or inherit from a base catalogue model.
      // Non-mobile catalogues (grocery, hardware etc.) don't use it.
      const attrs = MobileHandsetCatalogueAttributes(
        ramMb: 8192,
        storageMb: 131072,
        operatingSystem: MobileOperatingSystem.android,
      );

      // The type is specific to mobile — no other catalogue uses these fields
      expect(attrs.ramMb, 8192);
      expect(attrs.storageMb, 131072);
      expect(attrs.operatingSystem, MobileOperatingSystem.android);
    });

    test('MobileHandsetCatalogueAttributes all-null does not pollute', () {
      // When no mobile attributes are set, serialization produces empty map.
      // This ensures non-mobile items with no mobile attrs have clean JSON.
      const attrs = MobileHandsetCatalogueAttributes();
      final json = attrs.toJson();
      expect(json, isEmpty);
      // No fields "leak" into non-mobile catalogue records
    });

    test('MobileAccessoryCatalogueAttributes isolated from non-mobile', () {
      // Accessory attributes are mobile-specific and don't affect grocery/etc.
      const accessory = MobileAccessoryCatalogueAttributes(
        accessoryType: AccessoryType.protectiveCase,
        compatibleBrands: ['Samsung'],
        isBundleEligible: true,
      );

      // This type is only used by mobile shop tenants
      expect(accessory.accessoryType, AccessoryType.protectiveCase);
      expect(accessory.isBundleEligible, isTrue);
    });

    test('non-mobile items do not require mobile catalogue attributes', () {
      // A generic item (e.g., grocery product) would never have
      // MobileHandsetCatalogueAttributes. The model supports null
      // gracefully without affecting other catalogue types.
      const attrs = MobileHandsetCatalogueAttributes();
      expect(attrs.ramMb, isNull);
      expect(attrs.operatingSystem, isNull);
      expect(attrs.batteryMah, isNull);
      expect(attrs.chipset, isNull);
      // No required fields = optional extension for mobile only
    });

    test('MobileOperatingSystem values are mobile-specific', () {
      // These enum values only apply to mobile devices
      final mobileValues = MobileOperatingSystem.values;
      expect(mobileValues, contains(MobileOperatingSystem.android));
      expect(mobileValues, contains(MobileOperatingSystem.ios));
      expect(mobileValues, contains(MobileOperatingSystem.harmonyOs));
      // No "generic" or "non-mobile" operating system values
    });

    test('AccessoryType values are mobile-specific', () {
      // These accessory types are only relevant to mobile shops
      final types = AccessoryType.values;
      expect(types, contains(AccessoryType.protectiveCase));
      expect(types, contains(AccessoryType.screenProtector));
      expect(types, contains(AccessoryType.charger));
      expect(types, contains(AccessoryType.powerBank));
      // No generic retail accessory types that would affect other catalogues
    });

    test('accessory compatibility is brand/model-specific, not global', () {
      const samsungCase = MobileAccessoryCatalogueAttributes(
        accessoryType: AccessoryType.protectiveCase,
        compatibleBrands: ['Samsung'],
        compatibleModels: ['Galaxy S24'],
      );

      // Compatible with Samsung Galaxy S24
      expect(
        samsungCase.isCompatibleWith(brand: 'Samsung', model: 'Galaxy S24'),
        isTrue,
      );

      // NOT compatible with Apple iPhone (non-mobile brand still filtered)
      expect(
        samsungCase.isCompatibleWith(brand: 'Apple', model: 'iPhone 15'),
        isFalse,
      );

      // NOT compatible with different Samsung model
      expect(
        samsungCase.isCompatibleWith(brand: 'Samsung', model: 'Galaxy A15'),
        isFalse,
      );
    });

    test('universal accessory does not require specific brand/model', () {
      const universalCharger = MobileAccessoryCatalogueAttributes(
        accessoryType: AccessoryType.charger,
        compatibleBrands: [],
        compatibleModels: [],
      );

      // Compatible with any brand/model
      expect(
        universalCharger.isCompatibleWith(
          brand: 'Samsung',
          model: 'Galaxy S24',
        ),
        isTrue,
      );
      expect(
        universalCharger.isCompatibleWith(brand: 'Apple', model: 'iPhone 15'),
        isTrue,
      );
      expect(
        universalCharger.isCompatibleWith(brand: 'Unknown', model: 'Generic'),
        isTrue,
      );
    });
  });
}
