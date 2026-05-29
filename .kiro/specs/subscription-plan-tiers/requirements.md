# Requirements Document

## Introduction

This feature defines a tiered subscription plan architecture for DukanX, a multi-vertical
Indian SMB business management platform built in Flutter (desktop and mobile). The deliverable
is a strategically defensible mapping of every available feature, per business type, to one of
four subscription plans: Basic → Pro → Premium → Enterprise.

The mapping must be grounded in `lib/core/isolation/business_capability.dart`, which contains
`businessCapabilityRegistry`. That registry is the single source of truth for which capabilities
are available to each business type. A capability that is not listed for a business type is
hard-isolated and must never appear in any plan tier for that type.

The mapping directly powers feature-gating logic in `business_capability.dart` and is consumed by
the product, pricing, sales, and engineering teams. The feature produces three artifacts: a
per-type tier mapping with upgrade stories, a cross-plan feature matrix, and a plan-positioning
summary. The mapping must also be machine-consumable so engineering can drive gating logic from
the artifact rather than transcribing it by hand.

This document covers 19 target business types, all of which are first-class registered types that
receive a complete Plan_Mapping. Five of those types (bookStore, jewellery, autoParts,
decorationCatering, schoolErp) have feature code under `lib/features/` and are added to
`businessCapabilityRegistry` as confirmed entries using the `BusinessCapability` values that
already exist in the enum, so that all 19 business types are treated equally and each receives a
full Basic to Pro to Premium to Enterprise mapping.

## Glossary

- **Tiering_System**: The process and ruleset that produces and validates the plan mapping. Acts as the "system" in acceptance criteria.
- **Plan_Mapping**: The artifact that assigns each registered capability of a business type to one or more tiers, per business type.
- **Tier**: One of the four ordered subscription plans. Tier order is Basic (1) < Pro (2) < Premium (3) < Enterprise (4).
- **Basic_Tier**: Entry tier for a solo operator replacing pen-and-paper. Functional minimum.
- **Pro_Tier**: Tier for a growing shop with 1 to 5 staff, focused on efficiency tools.
- **Premium_Tier**: Tier for an established business needing reporting, returns, and multi-workflow depth.
- **Enterprise_Tier**: Top tier for multi-location, high-volume, regulated, or franchise-ready businesses.
- **Capability_Registry**: The `businessCapabilityRegistry` map in `lib/core/isolation/business_capability.dart`. Source of truth.
- **Registered_Capability**: A `BusinessCapability` value listed in `Capability_Registry` for a given business type.
- **Hard_Isolated_Capability**: A `BusinessCapability` value that is not listed in `Capability_Registry` for a given business type.
- **Newly_Registered_Type**: A business type that has feature code under `lib/features/` and whose `Capability_Registry` entry is added as part of this feature (bookStore, jewellery, autoParts, decorationCatering, schoolErp). Once added, a Newly_Registered_Type is treated identically to every other registered type.
- **Available_Capability_Count**: The number of distinct Registered_Capability values for a business type.
- **Tier_Coverage**: The number of distinct Registered_Capability values assigned to a tier, divided by Available_Capability_Count, expressed as a percentage.
- **Billing_Core**: The capability set {useInvoiceCreate (createInvoice), useInvoiceList (invoiceList), useInvoiceSearch (invoiceSearch)}.
- **Tier_Delta**: The set of capabilities a tier adds relative to the next-lower tier.
- **Workflow_Pair**: A set of capabilities that form one logical workflow and must be assigned to the same tier together.
- **Service_Only_Type**: A business type whose Capability_Registry contains no product or inventory capabilities (service, clinic, schoolErp, decorationCatering). All four are confirmed registered types.
- **Feature_Matrix**: A cross-plan deliverable listing every capability against tiers, across all business types.
- **Plan_Positioning_Summary**: A deliverable describing the value narrative and upgrade triggers of each tier for the product and pricing team.
- **Gating_Config**: The machine-consumable representation of Plan_Mapping used to drive gating logic in `business_capability.dart`.
- **Upgrade_Story**: A short narrative explaining the concrete reason a business of a given type would move from one tier to the next-higher tier.

## Requirements

### Requirement 1: Four-Tier Model and Coverage Targets

**User Story:** As a Senior Product Strategist, I want four clearly bounded tiers with coverage targets per business type, so that the plan ladder is defensible and consistent across all verticals.

#### Acceptance Criteria

1. THE Tiering_System SHALL define exactly four tiers in ascending order: Basic_Tier, Pro_Tier, Premium_Tier, Enterprise_Tier.
2. WHEN the Plan_Mapping is produced for a business type, THE Tiering_System SHALL assign Basic_Tier a Tier_Coverage between 30 percent and 40 percent of Available_Capability_Count.
3. WHEN the Plan_Mapping is produced for a business type, THE Tiering_System SHALL assign Pro_Tier a Tier_Coverage between 55 percent and 65 percent of Available_Capability_Count.
4. WHEN the Plan_Mapping is produced for a business type, THE Tiering_System SHALL assign Premium_Tier a Tier_Coverage between 75 percent and 85 percent of Available_Capability_Count.
5. WHEN the Plan_Mapping is produced for a business type, THE Tiering_System SHALL assign Enterprise_Tier a Tier_Coverage of 100 percent of Available_Capability_Count.
6. IF a business type has too few Registered_Capability values to satisfy a coverage band exactly, THEN THE Tiering_System SHALL select the assignment closest to the band that preserves tier ordering and SHALL record the deviation with a justification.
7. WHERE a business type has an Available_Capability_Count of zero, THE Tiering_System SHALL skip coverage-band evaluation and deviation recording for that business type.

### Requirement 2: Tier Subset Monotonicity

**User Story:** As a growing-business owner, I want each higher plan to include everything in the plan below it, so that upgrading never removes a feature I already rely on.

#### Acceptance Criteria

1. THE Tiering_System SHALL ensure every capability assigned to Basic_Tier is also assigned to Pro_Tier, Premium_Tier, and Enterprise_Tier for the same business type.
2. THE Tiering_System SHALL ensure every capability assigned to Pro_Tier is also assigned to Premium_Tier and Enterprise_Tier for the same business type.
3. THE Tiering_System SHALL ensure every capability assigned to Premium_Tier is also assigned to Enterprise_Tier for the same business type.
4. IF a proposed Plan_Mapping assigns a capability to a tier but omits that capability from a higher tier for the same business type, THEN THE Tiering_System SHALL reject the proposed Plan_Mapping and SHALL report the violating capability and tier.

### Requirement 3: Hard Isolation Enforcement

**User Story:** As an engineer integrating the gating logic, I want the mapping to never reference a capability outside a business type's registry, so that gating logic stays consistent with hard isolation and cannot grant forbidden features.

#### Acceptance Criteria

1. THE Tiering_System SHALL assign to a tier only capabilities that are Registered_Capability values for that business type.
2. IF a proposed Plan_Mapping assigns a Hard_Isolated_Capability to any tier of a business type, THEN THE Tiering_System SHALL reject the proposed Plan_Mapping and SHALL report the offending capability and business type.
3. IF the rejection mechanism for a Hard_Isolated_Capability is unavailable, THEN THE Tiering_System SHALL block the proposed Plan_Mapping from taking effect rather than allow a forbidden capability to be granted.
4. WHEN the Plan_Mapping for a business type is validated, THE Tiering_System SHALL confirm that the union of capabilities across all four tiers equals the set of Registered_Capability values for that business type.
5. THE Tiering_System SHALL treat `Capability_Registry` as the source of truth and SHALL derive Available_Capability_Count solely from `Capability_Registry`.

### Requirement 4: Registration of All Business Types

**User Story:** As a product manager, I want every business type that has feature code to be a confirmed entry in the Capability_Registry, so that all 19 business types are treated equally and each receives a complete plan mapping.

#### Acceptance Criteria

1. THE Tiering_System SHALL ensure `Capability_Registry` contains a confirmed capability set for all 19 business types, including bookStore, jewellery, autoParts, decorationCatering, and schoolErp.
2. WHERE a Newly_Registered_Type has no existing `Capability_Registry` entry, THE Tiering_System SHALL add a `Capability_Registry` entry for that type using `BusinessCapability` values that already exist in the enum.
3. THE Tiering_System SHALL define the bookStore entry with useISBN, usePublisherReturns, and the standard product, inventory, invoice, and purchase capabilities.
4. THE Tiering_System SHALL define the jewellery entry with useLoyaltyPoints and the standard product, inventory, and invoice capabilities.
5. THE Tiering_System SHALL define the autoParts entry with useJobSheets, useRepairStatus, useWarranty, and the standard product, inventory, invoice, and purchase capabilities.
6. THE Tiering_System SHALL define the decorationCatering entry with useDecorationThemes, useCateringMenu, useCateringKitchen, useVenueManagement, useEventBooking, useEventInventory, useEventStaffAllocation, useEventReports, and the invoice capabilities.
7. THE Tiering_System SHALL define the schoolErp entry with useStudentRegistry, useFeeCollection, useAttendanceTracking, useTimetable, useTestResults, useCertificates, useScholarshipDiscount, useParentNotifications, useCourseMaterial, useDemoClasses, and the invoice capabilities.
8. WHEN a `Capability_Registry` entry for a Newly_Registered_Type is confirmed, THE Tiering_System SHALL produce the Plan_Mapping for that type using the same rules applied to every other registered type.
9. IF a proposed `Capability_Registry` entry for a Newly_Registered_Type references an identifier that is not defined in the `BusinessCapability` enum, THEN THE Tiering_System SHALL reject the entry and SHALL report the undefined identifier.

### Requirement 5: Billing as Permanent Core

**User Story:** As a solo shop owner, I want billing to work on every plan including the entry plan, so that I can create and find bills without paying for a higher tier.

#### Acceptance Criteria

1. WHERE a business type's Registered_Capability set includes all of Billing_Core, THE Tiering_System SHALL assign useInvoiceCreate, useInvoiceList, and useInvoiceSearch together to Basic_Tier and to every higher tier for that business type.
2. THE Tiering_System SHALL never place any member of Billing_Core behind a tier higher than Basic_Tier for a business type whose Registered_Capability set includes that member.
3. WHERE a business type's Registered_Capability set includes some but not all members of Billing_Core, THE Tiering_System SHALL assign to Basic_Tier only the Billing_Core members that are Registered_Capability values for that type and SHALL record the absent members as a hard-isolation exception.
4. WHERE a business type's Registered_Capability set includes no member of Billing_Core, THE Tiering_System SHALL omit the hard-isolation exception for that business type.
5. IF a proposed Plan_Mapping splits the registered members of Billing_Core across different tiers for a business type, THEN THE Tiering_System SHALL reject the proposed Plan_Mapping and SHALL report the split.
6. WHERE a member of Billing_Core would also fall under the analytics-or-export gating of Requirement 9, THE Tiering_System SHALL apply the Billing_Core rule and SHALL assign that member to Basic_Tier.

### Requirement 6: Non-Empty Tiers and Meaningful Deltas

**User Story:** As a Senior Product Strategist, I want every tier to add real value over the one below it, so that the price ladder is justifiable and no tier is a dead step.

#### Acceptance Criteria

1. THE Tiering_System SHALL ensure each of Pro_Tier, Premium_Tier, and Enterprise_Tier has a Tier_Delta of at least one capability relative to the next-lower tier, for any business type whose Available_Capability_Count permits.
2. IF a proposed Plan_Mapping produces an empty Tier_Delta for Pro_Tier, Premium_Tier, or Enterprise_Tier for a business type whose Available_Capability_Count permits a non-empty delta, THEN THE Tiering_System SHALL reject the proposed Plan_Mapping and SHALL report the affected tier.
3. WHERE a business type has insufficient Available_Capability_Count to create a non-empty Tier_Delta for a tier, THE Tiering_System SHALL allow the empty Tier_Delta for that tier and SHALL record the reason.
4. THE Tiering_System SHALL record the Tier_Delta of each tier in the Plan_Mapping for every business type.

### Requirement 7: Workflow Cohesion

**User Story:** As a growing-business owner, I want related steps of one workflow to unlock together, so that I never receive half of a process on one plan and the other half on a higher plan.

#### Acceptance Criteria

1. THE Tiering_System SHALL treat {usePurchaseOrder, useSupplierBill} as a Workflow_Pair and SHALL assign the registered members of that pair to the same tier for a business type.
2. THE Tiering_System SHALL assign useStockEntry to the same tier as usePurchaseOrder or to a lower tier for a business type whose Registered_Capability set includes both.
3. IF a proposed Plan_Mapping assigns the registered members of a Workflow_Pair to different tiers for a business type, THEN THE Tiering_System SHALL reject the proposed Plan_Mapping and SHALL report the split pair and business type.
4. THE Tiering_System SHALL document each Workflow_Pair and its assigned tier in the Plan_Mapping for every affected business type.

### Requirement 8: Paired Specialized Workflows

**User Story:** As a product manager, I want specialized vertical capabilities that depend on each other to share a tier, so that a customer never unlocks one half of a paired feature without the other.

#### Acceptance Criteria

1. THE Tiering_System SHALL treat {useIMEI, useWarranty} as a Workflow_Pair and SHALL assign the registered members of that pair to the same tier for a business type.
2. THE Tiering_System SHALL treat {useJobSheets, useRepairStatus} as a Workflow_Pair and SHALL assign the registered members of that pair to the same tier for a business type.
3. THE Tiering_System SHALL treat {usePrescription, useDoctorLinking} as a Workflow_Pair and SHALL assign the registered members of that pair to the same tier for a business type.
4. THE Tiering_System SHALL treat {usePatientRegistry, useAppointments} as a Workflow_Pair and SHALL assign the registered members of that pair to the same tier for a business type.
5. IF a proposed Plan_Mapping assigns the registered members of any of these Workflow_Pairs to different tiers for a business type, THEN THE Tiering_System SHALL reject the proposed Plan_Mapping and SHALL report the split pair and business type.

### Requirement 9: Analytics and Exports Gated at Premium and Above

**User Story:** As a Senior Product Strategist, I want reporting, export, and analysis features positioned at Premium and above, so that the value narrative of the upper tiers is anchored in business intelligence.

#### Acceptance Criteria

1. WHERE useInventoryExport is a Registered_Capability for a business type, THE Tiering_System SHALL assign useInventoryExport to Premium_Tier or Enterprise_Tier only.
2. WHERE usePurchaseRegister is a Registered_Capability for a business type, THE Tiering_System SHALL assign usePurchaseRegister to Premium_Tier or Enterprise_Tier only.
3. WHERE useDeadStock is a Registered_Capability for a business type, THE Tiering_System SHALL assign useDeadStock to Premium_Tier or Enterprise_Tier only.
4. WHERE useRevenueOverview represents full-history revenue analytics and is a Registered_Capability for a business type, THE Tiering_System SHALL assign that full-history capability to Premium_Tier or Enterprise_Tier only.
5. IF a proposed Plan_Mapping assigns any analytics-or-export capability named in this requirement to Basic_Tier or Pro_Tier, THEN THE Tiering_System SHALL reject the proposed Plan_Mapping and SHALL report the violating capability and tier.

### Requirement 10: Bulk, B2B, and Financial-Risk Capabilities Gated at Enterprise

**User Story:** As a Senior Product Strategist, I want high-risk and high-volume B2B capabilities reserved for Enterprise, so that financial-risk and franchise-grade features anchor the top tier.

#### Acceptance Criteria

1. WHERE useCreditManagement is a Registered_Capability for a business type, THE Tiering_System SHALL assign useCreditManagement to Enterprise_Tier only.
2. WHERE useCreditLimit is a Registered_Capability for a business type, THE Tiering_System SHALL assign useCreditLimit to Enterprise_Tier only.
3. WHERE useDispatchNote is a Registered_Capability for a business type, THE Tiering_System SHALL assign useDispatchNote to Enterprise_Tier only.
4. WHERE useStockReversal is a Registered_Capability for a business type, THE Tiering_System SHALL assign useStockReversal to Enterprise_Tier only.
5. WHERE useProformaInvoice is a Registered_Capability for a business type, THE Tiering_System SHALL assign useProformaInvoice to Enterprise_Tier only.
6. IF a proposed Plan_Mapping assigns any capability named in this requirement to a tier below Enterprise_Tier, THEN THE Tiering_System SHALL reject the proposed Plan_Mapping and SHALL report the violating capability and tier.

### Requirement 11: Compliance and Seasonal Capabilities Gated at Premium and Above

**User Story:** As a product manager, I want regulated and seasonal capabilities positioned at Premium or above, so that compliance-driven verticals have a clear upgrade reason.

#### Acceptance Criteria

1. WHERE useDrugSchedule is a Registered_Capability for a business type, THE Tiering_System SHALL assign useDrugSchedule to Premium_Tier or Enterprise_Tier only.
2. WHERE useBatchExpiry is a Registered_Capability for a business type, THE Tiering_System SHALL assign useBatchExpiry to Premium_Tier or Enterprise_Tier only.
3. WHERE useFuelManagement is a Registered_Capability for a business type, THE Tiering_System SHALL assign useFuelManagement to Premium_Tier or Enterprise_Tier only.
4. WHERE useShiftManagement is a Registered_Capability for a business type, THE Tiering_System SHALL assign useShiftManagement to Premium_Tier or Enterprise_Tier only.
5. IF a proposed Plan_Mapping assigns any capability named in this requirement to Basic_Tier or Pro_Tier, THEN THE Tiering_System SHALL reject the proposed Plan_Mapping and SHALL report the violating capability and tier.

### Requirement 12: Single Essential Vertical Feature at Pro

**User Story:** As a growing-business owner, I want the one feature that defines my vertical available at the Pro plan, so that the efficiency tier delivers the core reason my business adopted DukanX.

#### Acceptance Criteria

1. THE Tiering_System SHALL identify, for each business type, exactly one Registered_Capability as the single most essential vertical capability for that type.
2. THE Tiering_System SHALL assign the identified single most essential vertical capability to Pro_Tier or to a lower tier for that business type.
3. THE Tiering_System SHALL record the identified single most essential vertical capability and the rationale for the selection in the Plan_Mapping for each business type.
4. IF the identified single most essential vertical capability is part of a Workflow_Pair, THEN THE Tiering_System SHALL assign the registered members of that pair together no higher than Pro_Tier.

### Requirement 13: Service-Only Type Upgrade Path

**User Story:** As a product manager for service verticals, I want an upgrade path that does not depend on inventory features, so that service-only businesses still see clear value at every tier.

#### Acceptance Criteria

1. THE Tiering_System SHALL classify service, clinic, schoolErp, and decorationCatering as confirmed Service_Only_Type values.
2. WHERE a business type is a Service_Only_Type, THE Tiering_System SHALL build Tier_Delta values from workflow-depth, reporting, automation, staff-management, and customer-management capabilities rather than product or stock capabilities.
3. IF a proposed Plan_Mapping for a Service_Only_Type relies on a product or inventory capability to satisfy a Tier_Delta, THEN THE Tiering_System SHALL reject the proposed Plan_Mapping and SHALL report the affected tier.
4. THE Tiering_System SHALL ensure each tier of a Service_Only_Type satisfies the non-empty Tier_Delta rule in Requirement 6 using only Registered_Capability values for that type.

### Requirement 14: 'other' Type Mapping

**User Story:** As an engineer integrating the gating logic, I want a precise mapping for the generic 'other' type, so that the smallest capability set is handled deterministically.

#### Acceptance Criteria

1. THE Tiering_System SHALL treat the 'other' type as having exactly six Registered_Capability values, consistent with `Capability_Registry`.
2. THE Tiering_System SHALL assign exactly three of the six Registered_Capability values of the 'other' type to Basic_Tier.
3. THE Tiering_System SHALL assign all six Registered_Capability values of the 'other' type to Pro_Tier.
4. THE Tiering_System SHALL assign to Premium_Tier and Enterprise_Tier of the 'other' type the same set of capabilities assigned to Pro_Tier.
5. THE Tiering_System SHALL record the 'other' type as an explicit exception to the no-plan-washing rule and the Enterprise distinct-addition rule.

### Requirement 15: No Plan-Washing

**User Story:** As a sales team member, I want Premium and Enterprise to be genuinely different for verticals that can support it, so that I can defend the Enterprise price to prospects.

#### Acceptance Criteria

1. WHERE a business type has an Available_Capability_Count large enough to differentiate tiers, THE Tiering_System SHALL ensure Premium_Tier and Enterprise_Tier are not identical for that business type.
2. WHERE a business type has an Available_Capability_Count large enough to differentiate tiers, THE Tiering_System SHALL assign Enterprise_Tier a Tier_Delta of at least two distinct capabilities relative to Premium_Tier, with a target of two to three distinct capabilities.
3. THE Tiering_System SHALL record, for each business type, the distinct capabilities that justify Enterprise_Tier over Premium_Tier.
4. IF a proposed Plan_Mapping makes Premium_Tier and Enterprise_Tier identical for a business type whose Available_Capability_Count permits differentiation, THEN THE Tiering_System SHALL reject the proposed Plan_Mapping and SHALL report the business type.
5. THE Tiering_System SHALL exempt the 'other' type from this requirement, consistent with Requirement 14.

### Requirement 16: Per-Type Tier Mapping with Upgrade Stories

**User Story:** As a product manager, I want a per-type mapping that includes the reason a customer upgrades, so that product, sales, and pricing share one narrative per vertical.

#### Acceptance Criteria

1. THE Tiering_System SHALL produce, for each of the 19 target business types, a Plan_Mapping that lists the capabilities assigned to Basic_Tier, Pro_Tier, Premium_Tier, and Enterprise_Tier.
2. THE Tiering_System SHALL produce an Upgrade_Story for each tier transition: Basic to Pro, Pro to Premium, and Premium to Enterprise, for each of the 19 target business types.
3. THE Tiering_System SHALL produce a complete, non-pending Plan_Mapping for each Newly_Registered_Type using the confirmed `Capability_Registry` entry defined in Requirement 4.
4. THE Tiering_System SHALL express each Upgrade_Story in terms of Registered_Capability values that the higher tier adds.

### Requirement 17: Cross-Plan Feature Matrix

**User Story:** As a sales team member, I want a single matrix of features against plans across all verticals, so that I can compare coverage at a glance during a customer conversation.

#### Acceptance Criteria

1. THE Tiering_System SHALL produce a Feature_Matrix that lists every Registered_Capability against the four tiers for each business type.
2. WHEN a capability is assigned to a tier in the Plan_Mapping, THE Feature_Matrix SHALL mark that capability as included for that tier and every higher tier.
3. WHEN a capability is a Hard_Isolated_Capability for a business type, THE Feature_Matrix SHALL omit that capability or mark that capability as not applicable for that business type.
4. THE Feature_Matrix SHALL remain consistent with the Plan_Mapping, and IF the Feature_Matrix and the Plan_Mapping disagree for any capability and tier, THEN THE Tiering_System SHALL report the discrepancy.

### Requirement 18: Plan-Positioning Summary

**User Story:** As a Senior Product Strategist, I want a positioning summary per tier, so that the pricing and product team can set prices and messaging from a shared rationale.

#### Acceptance Criteria

1. THE Tiering_System SHALL produce a Plan_Positioning_Summary that describes the target customer, value narrative, and primary upgrade trigger of each tier.
2. THE Plan_Positioning_Summary SHALL describe Basic_Tier as the pen-and-paper replacement for a solo operator, Pro_Tier as the efficiency tier for a shop with 1 to 5 staff, Premium_Tier as the reporting and multi-workflow tier for an established business, and Enterprise_Tier as the multi-location and regulated and franchise-ready tier.
3. THE Plan_Positioning_Summary SHALL reference the coverage targets defined in Requirement 1 for each tier.
4. THE Plan_Positioning_Summary SHALL identify, for each tier, the categories of capability that anchor that tier's value, consistent with Requirements 9, 10, and 11.

### Requirement 19: Machine-Consumable Gating Output

**User Story:** As an engineer integrating the gating logic, I want the mapping in a machine-consumable form, so that I can drive gating in `business_capability.dart` from the artifact without manual transcription.

#### Acceptance Criteria

1. THE Tiering_System SHALL produce a Gating_Config that maps each business type and tier to the set of `BusinessCapability` values granted at that tier.
2. THE Gating_Config SHALL use the exact `BusinessCapability` enum identifiers defined in `lib/core/isolation/business_capability.dart`.
3. WHEN the Gating_Config is generated, THE Tiering_System SHALL validate that every capability in the Gating_Config is a Registered_Capability for the corresponding business type.
4. IF the Gating_Config references a capability that is not present in `Capability_Registry` for a business type, THEN THE Tiering_System SHALL reject the Gating_Config and SHALL report the offending entry.
5. THE Gating_Config SHALL represent tier order such that the capabilities of a higher tier include the capabilities of every lower tier for the same business type.
