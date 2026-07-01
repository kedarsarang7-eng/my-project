/// Capability classification for the Tiering_System.
///
/// Each [BusinessCapability] is tagged with a [GatingCategory] that fixes the
/// lowest legal tier (its *floor*) and the highest legal tier (its *ceiling*)
/// at which the plan-mapping builder may place it. This file also declares the
/// [workflowPairs] that must always share a tier and the ordering constraint
/// that keeps stock entry from unlocking after purchase order.
///
/// This is pure-Dart classification logic. It depends only on the
/// [BusinessCapability] enum and the [SubscriptionTier] model, so it is safe to
/// use from any layer and is independently testable.
library;

import '../isolation/business_capability.dart';
import 'subscription_tier.dart';

/// The gating category of a capability.
///
/// A category fixes the legal tier range (`floor..ceiling`) for every
/// capability that belongs to it:
///
/// | Category             | Floor      | Ceiling    | Requirement |
/// |----------------------|------------|------------|-------------|
/// | [billingCore]        | basic      | basic      | Req 5       |
/// | [analyticsExport]    | premium    | enterprise | Req 9       |
/// | [enterpriseOnly]     | enterprise | enterprise | Req 10      |
/// | [complianceSeasonal] | premium    | enterprise | Req 11      |
/// | [standard]           | basic      | enterprise | (default)   |
enum GatingCategory {
  /// Billing_Core. Always lives at Basic and never higher (Req 5). Wins over
  /// analytics gating for any member that would otherwise qualify (Req 5.6).
  billingCore,

  /// Reporting, export, and analysis features. Premium or Enterprise only
  /// (Req 9).
  analyticsExport,

  /// Bulk, B2B, and financial-risk capabilities. Enterprise only (Req 10).
  enterpriseOnly,

  /// Regulated and seasonal capabilities. Premium or Enterprise only (Req 11).
  complianceSeasonal,

  /// Every other capability. May sit anywhere from Basic to Enterprise.
  standard,
}

/// Classifies a [BusinessCapability] into a [GatingCategory] and reports the
/// floor and ceiling tier implied by that category.
///
/// The classifier is stateless and registry-independent: it answers the same
/// way for a capability regardless of which business type owns it. The builder
/// applies these bounds only to the capabilities that are actually registered
/// for a given type.
class CapabilityClassifier {
  /// Creates a stateless classifier. Instances are interchangeable.
  const CapabilityClassifier();

  // ---------------------------------------------------------------------------
  // Fixed category membership (from the enum identifiers in
  // business_capability.dart). Sets are unmodifiable and shared.
  // ---------------------------------------------------------------------------

  /// Billing_Core members (Req 5).
  static const Set<BusinessCapability> billingCoreCapabilities = {
    BusinessCapability.useInvoiceCreate,
    BusinessCapability.useInvoiceList,
    BusinessCapability.useInvoiceSearch,
  };

  /// Analytics / export members (Req 9). `useRevenueOverview` is treated as
  /// full-history revenue analytics.
  static const Set<BusinessCapability> analyticsExportCapabilities = {
    BusinessCapability.useInventoryExport,
    BusinessCapability.usePurchaseRegister,
    BusinessCapability.useDeadStock,
    BusinessCapability.useRevenueOverview,
  };

  /// Enterprise-only members: bulk, B2B, and financial-risk capabilities
  /// (Req 10).
  static const Set<BusinessCapability> enterpriseOnlyCapabilities = {
    BusinessCapability.useCreditManagement,
    BusinessCapability.useCreditLimit,
    BusinessCapability.useDispatchNote,
    BusinessCapability.useStockReversal,
    BusinessCapability.useProformaInvoice,
  };

  /// Compliance / seasonal members (Req 11).
  static const Set<BusinessCapability> complianceSeasonalCapabilities = {
    BusinessCapability.useDrugSchedule,
    BusinessCapability.useBatchExpiry,
    BusinessCapability.useFuelManagement,
    BusinessCapability.useShiftManagement,
  };

  /// The [GatingCategory] of [cap].
  ///
  /// Billing_Core is checked first so that it always wins, even for a member
  /// that might also appear to qualify for analytics gating (Req 5.6). The
  /// remaining categories are mutually exclusive, so their evaluation order
  /// does not matter.
  GatingCategory categoryOf(BusinessCapability cap) {
    // Req 5.6: Billing_Core takes precedence over any other gating.
    if (billingCoreCapabilities.contains(cap)) {
      return GatingCategory.billingCore;
    }
    if (analyticsExportCapabilities.contains(cap)) {
      return GatingCategory.analyticsExport;
    }
    if (enterpriseOnlyCapabilities.contains(cap)) {
      return GatingCategory.enterpriseOnly;
    }
    if (complianceSeasonalCapabilities.contains(cap)) {
      return GatingCategory.complianceSeasonal;
    }
    return GatingCategory.standard;
  }

  /// The lowest tier [cap] may be assigned to.
  SubscriptionTier floorFor(BusinessCapability cap) {
    switch (categoryOf(cap)) {
      case GatingCategory.billingCore:
        return SubscriptionTier.basic;
      case GatingCategory.analyticsExport:
        return SubscriptionTier.premium;
      case GatingCategory.enterpriseOnly:
        return SubscriptionTier.enterprise;
      case GatingCategory.complianceSeasonal:
        return SubscriptionTier.premium;
      case GatingCategory.standard:
        return SubscriptionTier.basic;
    }
  }

  /// The highest tier [cap] may be assigned to.
  SubscriptionTier ceilingFor(BusinessCapability cap) {
    switch (categoryOf(cap)) {
      case GatingCategory.billingCore:
        return SubscriptionTier.basic;
      case GatingCategory.analyticsExport:
        return SubscriptionTier.enterprise;
      case GatingCategory.enterpriseOnly:
        return SubscriptionTier.enterprise;
      case GatingCategory.complianceSeasonal:
        return SubscriptionTier.enterprise;
      case GatingCategory.standard:
        return SubscriptionTier.enterprise;
    }
  }
}

/// Capabilities that must always be assigned to the same tier when both
/// registered members are present for a business type.
///
/// Only the registered members of a pair are constrained; a pair with a single
/// registered member imposes no co-location requirement.
///
/// - `{usePurchaseOrder, useSupplierBill}` (Req 7.1)
/// - `{useIMEI, useWarranty}` (Req 8.1)
/// - `{useJobSheets, useRepairStatus}` (Req 8.2)
/// - `{usePrescription, useDoctorLinking}` (Req 8.3)
/// - `{usePatientRegistry, useAppointments}` (Req 8.4)
const List<Set<BusinessCapability>> workflowPairs = [
  {BusinessCapability.usePurchaseOrder, BusinessCapability.useSupplierBill},
  {BusinessCapability.useIMEI, BusinessCapability.useWarranty},
  {BusinessCapability.useJobSheets, BusinessCapability.useRepairStatus},
  {BusinessCapability.usePrescription, BusinessCapability.useDoctorLinking},
  {BusinessCapability.usePatientRegistry, BusinessCapability.useAppointments},
];

/// A directional ordering constraint between two capabilities.
///
/// Unlike a [workflowPairs] entry (which requires equal tiers), this requires
/// only that the tier of [lower] be less than or equal to the tier of
/// [higher] when both are registered for a business type.
class OrderingConstraint {
  /// The capability whose tier must be the lower (or equal) of the two.
  final BusinessCapability lower;

  /// The capability whose tier must be the higher (or equal) of the two.
  final BusinessCapability higher;

  /// Creates an ordering constraint requiring `tier(lower) <= tier(higher)`.
  const OrderingConstraint(this.lower, this.higher);
}

/// `useStockEntry` must never unlock at a tier higher than `usePurchaseOrder`
/// (Req 7.2). This is an ordering rule, not an equality pair, so it lives apart
/// from [workflowPairs]. The builder and validator can consume it directly.
const OrderingConstraint stockEntryBeforePurchaseOrder = OrderingConstraint(
  BusinessCapability.useStockEntry,
  BusinessCapability.usePurchaseOrder,
);

/// All directional ordering constraints the builder and validator must honor.
const List<OrderingConstraint> tierOrderingConstraints = [
  stockEntryBeforePurchaseOrder,
];
