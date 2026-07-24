/// Capability Label Visibility — Route Generic Labels to Matching Functionality
///
/// Controls visibility of generic capability labels (Accounting, Tax, Audit,
/// Backup, Compliance) in the mobile shop context. Labels are only shown when
/// the corresponding mobile-shop-specific feature is enabled and functional.
///
/// Generic labels that do not correspond to enabled mobileShop functionality
/// are hidden to avoid exposing unsupported capability surfaces.
///
/// Requirements: 9.10–9.11, 10.10–10.12
/// Audit: AF-01–AF-04, AF-48
library;

import 'package:flutter/foundation.dart';

import '../config/feature_policy_config.dart';
import '../permissions/mobile_shop_permissions.dart';

/// Represents a generic capability label that may or may not be visible
/// in the mobile shop context depending on feature policy.
enum MobileShopCapabilityLabel {
  /// Accounting: visible when mobile-shop accounting lines exist
  /// (invoice/device sale with separate stock/tax/accounting lines).
  accounting,

  /// Tax: visible when mobile GST/tax features are enabled
  /// (e.g. HSN codes, tax rate basis points on device lines).
  tax,

  /// Audit: visible when audit trail feature is available
  /// (immutable audit events for lifecycle changes).
  audit,

  /// Backup: visible when backup/export feature is enabled.
  backup,

  /// Compliance: visible when e-Way or compliance checks are enabled.
  compliance,
}

/// Maps each capability label to its feature requirements.
@immutable
class _LabelRequirement {
  /// Feature IDs from [FeaturePolicyConfig] that enable this label.
  /// Label is visible if ANY of these features is enabled.
  final List<String> enablingFeatureIds;

  /// Required permission to see this label. Null means no permission check.
  final String? requiredPermission;

  /// Required capability string from tenant capability set.
  final String? requiredCapability;

  const _LabelRequirement({
    required this.enablingFeatureIds,
    this.requiredPermission,
    this.requiredCapability,
  });
}

/// Internal mapping from capability label to its visibility requirements.
const Map<MobileShopCapabilityLabel, _LabelRequirement> _labelRequirements = {
  MobileShopCapabilityLabel.accounting: _LabelRequirement(
    enablingFeatureIds: ['IMEI_TRACKING', 'FINANCE_PLANS', 'BUNDLES'],
    requiredPermission: MobileShopPermissions.financeView,
  ),
  MobileShopCapabilityLabel.tax: _LabelRequirement(
    enablingFeatureIds: ['IMEI_TRACKING', 'BUNDLES'],
    requiredPermission: MobileShopPermissions.financeView,
    requiredCapability: 'tax_management',
  ),
  MobileShopCapabilityLabel.audit: _LabelRequirement(
    enablingFeatureIds: ['IMEI_TRACKING', 'SERVICE_JOBS'],
    requiredPermission: MobileShopPermissions.auditView,
  ),
  MobileShopCapabilityLabel.backup: _LabelRequirement(
    enablingFeatureIds: ['MOBILE_REPORTS'],
    requiredPermission: MobileShopPermissions.reportsExport,
  ),
  MobileShopCapabilityLabel.compliance: _LabelRequirement(
    enablingFeatureIds: ['E_WAY_BILL'],
    requiredPermission: MobileShopPermissions.settingsManage,
    requiredCapability: 'e_way',
  ),
};

/// Determines visibility of capability labels for a mobile shop tenant.
///
/// This controller evaluates the tenant's feature policy, capabilities,
/// and permissions to decide which generic labels should be shown.
/// Labels for unsupported or disabled features are hidden.
///
/// Usage:
/// ```dart
/// final visibility = CapabilityLabelVisibility(
///   featurePolicy: kFeaturePolicyConfig,
///   tenantCapabilities: {'imei_tracking', 'service_jobs'},
///   tenantPermissions: {'mobile_shop:audit:view'},
///   enabledFeatureIds: {'IMEI_TRACKING', 'SERVICE_JOBS'},
/// );
///
/// if (visibility.isVisible(MobileShopCapabilityLabel.audit)) {
///   // Show audit label
/// }
/// ```
@immutable
class CapabilityLabelVisibility {
  /// The feature policy configuration.
  final FeaturePolicyConfig featurePolicy;

  /// The set of capabilities available to the current tenant.
  final Set<String> tenantCapabilities;

  /// The set of permissions granted to the current user.
  final Set<String> tenantPermissions;

  /// Feature IDs explicitly enabled for this tenant.
  /// If null, falls back to [FeaturePolicyEntry.enabledByDefault].
  final Set<String>? enabledFeatureIds;

  const CapabilityLabelVisibility({
    required this.featurePolicy,
    required this.tenantCapabilities,
    required this.tenantPermissions,
    this.enabledFeatureIds,
  });

  /// Returns true if the given [label] should be visible to the current user.
  ///
  /// A label is visible when:
  /// 1. At least one of its enabling features is active (enabled + has
  ///    required capability if specified in feature policy)
  /// 2. The user has the required permission (if specified)
  /// 3. The tenant has the required capability (if specified)
  bool isVisible(MobileShopCapabilityLabel label) {
    final requirement = _labelRequirements[label];
    if (requirement == null) return false;

    // Check if at least one enabling feature is active
    final hasEnablingFeature = requirement.enablingFeatureIds.any((featureId) {
      return _isFeatureActive(featureId);
    });
    if (!hasEnablingFeature) return false;

    // Check required capability for the label itself
    if (requirement.requiredCapability != null &&
        !tenantCapabilities.contains(requirement.requiredCapability)) {
      return false;
    }

    // Check required permission
    if (requirement.requiredPermission != null &&
        !_hasPermission(requirement.requiredPermission!)) {
      return false;
    }

    return true;
  }

  /// Returns all labels that are currently visible.
  Set<MobileShopCapabilityLabel> get visibleLabels {
    return MobileShopCapabilityLabel.values.where(isVisible).toSet();
  }

  /// Returns all labels that are currently hidden.
  Set<MobileShopCapabilityLabel> get hiddenLabels {
    return MobileShopCapabilityLabel.values
        .where((label) => !isVisible(label))
        .toSet();
  }

  /// Checks if a feature is considered active based on explicit enablement
  /// or default policy.
  bool _isFeatureActive(String featureId) {
    // If explicit feature set is provided, use it
    if (enabledFeatureIds != null) {
      if (!enabledFeatureIds!.contains(featureId)) return false;
    } else {
      // Fall back to default enablement from policy
      final entry = featurePolicy.getFeature(featureId);
      if (entry == null || !entry.enabledByDefault) return false;
    }

    // Check if the feature's required capability is met
    final entry = featurePolicy.getFeature(featureId);
    if (entry?.requiredCapability != null &&
        !tenantCapabilities.contains(entry!.requiredCapability)) {
      return false;
    }

    return true;
  }

  /// Checks permission with implication support.
  bool _hasPermission(String permission) {
    if (tenantPermissions.contains(permission)) return true;

    // Check if any held permission implies the required one
    for (final entry in MobileShopPermissions.implications.entries) {
      if (entry.value == permission && tenantPermissions.contains(entry.key)) {
        return true;
      }
    }
    return false;
  }
}
