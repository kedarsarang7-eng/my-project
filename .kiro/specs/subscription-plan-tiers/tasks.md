# Implementation Plan: Subscription Plan Tiers

## Overview

This plan implements the Tiering_System as a pure-Dart module under
`lib/core/subscription/` in the DukanX Flutter app. Work proceeds bottom-up:
first the tier model and the registry source of truth, then capability
classification and coverage math, then the deterministic mapping builder and the
independent validator, and finally the human-facing artifacts, the
machine-consumable Gating_Config, and the wiring into
`lib/core/isolation/business_capability.dart`.

The validator encodes every mapping invariant, so the design's correctness
properties are implemented as property-based tests that feed builder output to
the validator (forward direction) and feed mutated mappings to the validator
(rejection direction). A property-based testing library (e.g. `glados`) is added
to `dev_dependencies`; each property test runs at least 100 iterations.

## Tasks

- [x] 1. Set up subscription module and tier model
  - [x] 1.1 Create the `SubscriptionTier` enum and `CoverageBand` value type
    - Create `lib/core/subscription/subscription_tier.dart`
    - Define `SubscriptionTier { basic, pro, premium, enterprise }` with index-based ordering operators
    - Define `CoverageBand(minPercent, maxPercent)` and the per-tier band accessor (Basic 30–40, Pro 55–65, Premium 75–85, Enterprise 100–100)
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_
  - [x] 1.2 Add a property-based testing library to dev_dependencies
    - Add `glados` (or equivalent Dart PBT library) under `dev_dependencies` in `Dukan_x/pubspec.yaml`
    - Run package resolution so the library is available to tests
  - [~]* 1.3 Write unit test for tier enum shape
    - Assert four tiers exist in ascending order basic < pro < premium < enterprise
    - _Requirements: 1.1_

- [x] 2. Register all business types in the capability registry
  - [x] 2.1 Add the five Newly_Registered_Type entries to `businessCapabilityRegistry`
    - Edit `lib/core/isolation/business_capability.dart`
    - Add `bookStore`, `jewellery`, `autoParts`, `decorationCatering`, `schoolErp` entries using only existing `BusinessCapability` enum members, per the design registry table
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7_
  - [x] 2.2 Implement the registry-entry integrity guard
    - Create `lib/core/subscription/registry_integrity.dart`
    - Validate that every identifier in a proposed (string-keyed) registry entry resolves to an existing `BusinessCapability`; reject and report any undefined identifier
    - _Requirements: 4.2, 4.9_
  - [~]* 2.3 Write unit tests for registry completeness and new-type membership
    - Assert all 19 types are present and each new type contains its required identifiers
    - _Requirements: 4.1, 4.3, 4.4, 4.5, 4.6, 4.7_
  - [~]* 2.4 Write unit test for undefined-identifier rejection
    - Assert a proposed entry naming an unknown identifier is rejected and the identifier reported
    - _Requirements: 4.9_

- [x] 3. Implement capability classification and workflow pairs
  - [x] 3.1 Implement `GatingCategory`, `CapabilityClassifier`, and `workflowPairs`
    - Create `lib/core/subscription/capability_classifier.dart`
    - Map each capability to a category with `floorFor`/`ceilingFor` (billingCore→basic/basic, analyticsExport→premium/enterprise, enterpriseOnly→enterprise/enterprise, complianceSeasonal→premium/enterprise, standard→basic/enterprise)
    - Define the five Workflow_Pairs and the `useStockEntry ≤ usePurchaseOrder` ordering rule
    - _Requirements: 5.1, 5.2, 5.6, 7.1, 7.2, 8.1, 8.2, 8.3, 8.4, 9.1, 9.2, 9.3, 9.4, 10.1, 10.2, 10.3, 10.4, 10.5, 11.1, 11.2, 11.3, 11.4, 12.1, 12.2_
  - [~]* 3.2 Write unit tests for classifier floor/ceiling/category
    - Verify category membership and floor/ceiling for each gated capability set
    - _Requirements: 5.1, 9.1, 10.1, 11.1_

- [x] 4. Implement coverage calculation
  - [x] 4.1 Implement `CoverageBand.feasibleSizes`, `CoverageCalculator`, and `TierCoverageRecord`
    - Create `lib/core/subscription/coverage_calculator.dart`
    - Compute `availableCount` from the registry only, per-tier `coverageOf`, feasible integer band sizes, and deviation records; skip band evaluation for zero-capability types
    - _Requirements: 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 3.5_
  - [~]* 4.2 Write property test for Available_Capability_Count source
    - **Property 5: Available_Capability_Count is sourced only from the registry**
    - **Validates: Requirements 3.5**
  - [~]* 4.3 Write unit tests for feasible band sizes and deviation records
    - Cover the closest-ordering-preserving size selection and zero-capability skip path
    - _Requirements: 1.6, 1.7_

- [x] 5. Implement the plan mapping data model
  - [x] 5.1 Implement `PlanMapping`, `MappingNote`, and `UpgradeStory` models
    - Create `lib/core/subscription/plan_mapping.dart`
    - Store cumulative per-tier capability sets, per-tier deltas, essential-vertical capability + rationale, workflow-pair tiers, and recorded notes
    - _Requirements: 6.4, 7.4, 12.3, 16.1_

- [x] 6. Implement the plan mapping builder
  - [x] 6.1 Implement `PlanMappingBuilder` (`buildFor` and `buildAll`)
    - Create `lib/core/subscription/plan_mapping_builder.dart`
    - Deterministically assign registered capabilities to cumulative tiers honoring billing-core-at-Basic, gating floors/ceilings, workflow-pair cohesion, the stock-entry ordering rule, essential-vertical-by-Pro, service-only deltas, Enterprise = 100%, and the Enterprise-distinct-addition target
    - Handle the `'other'` special case (Basic = 3 fixed, Pro = Premium = Enterprise = all 6) and record deviations/exceptions as notes
    - _Requirements: 2.1, 2.2, 2.3, 5.1, 5.3, 6.1, 6.3, 7.1, 7.2, 8.1, 8.2, 8.3, 8.4, 12.2, 12.4, 13.2, 13.4, 14.1, 14.2, 14.3, 14.4, 14.5, 15.1, 15.2_
  - [ ]* 6.2 Write unit tests for special-case and degenerate inputs
    - Cover `'other'` exact counts, service-only classification, empty registry, partial/absent Billing_Core, and tiny-registry empty deltas
    - _Requirements: 1.7, 5.4, 6.3, 13.1, 14.1, 14.2, 14.3, 14.4, 14.5_

- [x] 7. Implement the plan mapping validator and prove the invariants
  - [x] 7.1 Implement `PlanMappingValidator`, `ValidationViolation`, `ValidationResult`, and fail-safe fallback
    - Create `lib/core/subscription/plan_mapping_validator.dart`
    - Re-check every invariant independently (monotonicity, hard isolation + completeness, coverage bands, billing core, non-empty deltas, workflow cohesion, all gating tiers, essential vertical, service-only deltas, `'other'` exception, no plan-washing) and report each violation with rule, type, tier, and capability
    - Block any mapping from taking effect when the validator cannot run (default deny)
    - _Requirements: 2.4, 3.1, 3.2, 3.3, 3.4, 5.5, 6.2, 7.3, 8.5, 9.5, 10.6, 11.5, 13.3, 14.5, 15.3, 15.4_
  - [ ]* 7.2 Write unit test for fail-safe fallback
    - With the validator forced to fail, assert no mapping is applied and gating defaults to denied
    - _Requirements: 3.3_
  - [ ]* 7.3 Write property test for tier subset monotonicity
    - **Property 3: Tier subset monotonicity**
    - **Validates: Requirements 2.1, 2.2, 2.3, 2.4**
  - [ ]* 7.4 Write property test for hard isolation and completeness
    - **Property 4: Hard isolation and completeness**
    - **Validates: Requirements 3.1, 3.2, 3.4**
  - [ ]* 7.5 Write property test for billing-core placement
    - **Property 6: Registered billing-core members live at Basic**
    - **Validates: Requirements 5.1, 5.2, 5.3, 5.5, 5.6**
  - [ ]* 7.6 Write property test for non-empty tier deltas
    - **Property 7: Tier deltas are non-empty and correctly recorded**
    - **Validates: Requirements 6.1, 6.2, 6.4**
  - [ ]* 7.7 Write property test for workflow-pair cohesion
    - **Property 8: Workflow pairs share a tier**
    - **Validates: Requirements 7.1, 7.3, 7.4, 8.1, 8.2, 8.3, 8.4, 8.5**
  - [ ]* 7.8 Write property test for stock-entry ordering
    - **Property 9: Stock entry never unlocks after purchase order**
    - **Validates: Requirements 7.2**
  - [ ]* 7.9 Write property test for analytics/export gating
    - **Property 10: Analytics and export capabilities gated at Premium and above**
    - **Validates: Requirements 9.1, 9.2, 9.3, 9.4, 9.5**
  - [ ]* 7.10 Write property test for enterprise-only gating
    - **Property 11: Bulk, B2B, and financial-risk capabilities gated at Enterprise**
    - **Validates: Requirements 10.1, 10.2, 10.3, 10.4, 10.5, 10.6**
  - [ ]* 7.11 Write property test for compliance/seasonal gating
    - **Property 12: Compliance and seasonal capabilities gated at Premium and above**
    - **Validates: Requirements 11.1, 11.2, 11.3, 11.4, 11.5**
  - [ ]* 7.12 Write property test for essential-vertical-by-Pro
    - **Property 13: Single essential vertical capability available by Pro**
    - **Validates: Requirements 12.1, 12.2, 12.3, 12.4**
  - [ ]* 7.13 Write property test for service-only deltas
    - **Property 14: Service-only deltas avoid product and inventory capabilities**
    - **Validates: Requirements 13.2, 13.3, 13.4**
  - [ ]* 7.14 Write property test for no plan-washing
    - **Property 15: No plan-washing for differentiable types**
    - **Validates: Requirements 15.1, 15.2, 15.3, 15.4**
  - [ ]* 7.15 Write property test for coverage bands
    - **Property 1: Coverage bands hold per tier**
    - **Validates: Requirements 1.2, 1.3, 1.4, 1.5**
  - [ ]* 7.16 Write property test for infeasible-band size selection
    - **Property 2: Infeasible bands pick the closest ordering-preserving size**
    - **Validates: Requirements 1.6**

- [x] 8. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 9. Implement the human-facing artifact generators
  - [x] 9.1 Implement per-type Plan_Mapping assembly and Upgrade_Story generation
    - Create `lib/core/subscription/upgrade_story.dart`
    - Produce three Upgrade_Stories per type whose added capabilities equal the higher tier's Tier_Delta
    - _Requirements: 16.1, 16.2, 16.3, 16.4_
  - [x] 9.2 Implement the Feature_Matrix generator
    - Create `lib/core/subscription/feature_matrix.dart`
    - Record every registered capability against the four tiers, mark hard-isolated capabilities as not-applicable, and keep cumulative inclusion consistent with the mapping
    - _Requirements: 17.1, 17.2, 17.3, 17.4_
  - [x] 9.3 Implement the Plan_Positioning_Summary generator
    - Create `lib/core/subscription/positioning_summary.dart`
    - Produce one entry per tier with target customer, value narrative, upgrade trigger, coverage-target reference, and category anchors
    - _Requirements: 18.1, 18.2, 18.3, 18.4_
  - [ ]* 9.4 Write property test for mapping and upgrade-story completeness
    - **Property 16: Mapping and upgrade-story completeness**
    - **Validates: Requirements 16.1, 16.2, 16.3, 16.4**
  - [ ]* 9.5 Write property test for feature-matrix consistency
    - **Property 17: Feature matrix is consistent with the mapping**
    - **Validates: Requirements 17.1, 17.2, 17.3, 17.4**
  - [ ]* 9.6 Write unit test for the plan-positioning summary
    - Verify one non-empty entry per tier referencing coverage targets and category anchors
    - _Requirements: 18.1, 18.2, 18.3, 18.4_

- [x] 10. Implement the machine-consumable Gating_Config
  - [x] 10.1 Implement `GatingConfig` with `toJson`/`fromJson` and `fromMappings`
    - Create `lib/core/subscription/gating_config.dart`
    - Serialize `(businessType, tier) → Set<BusinessCapability>` using exact enum identifier names, keep tiers cumulative, and validate every granted capability is registered
    - _Requirements: 19.1, 19.2, 19.3, 19.5_
  - [ ]* 10.2 Write property test for Gating_Config validity and round-trip
    - **Property 18: Gating_Config validity and serialization round-trip**
    - **Validates: Requirements 19.1, 19.2, 19.3, 19.4, 19.5**
  - [ ]* 10.3 Write unit test for non-registered capability rejection in the codec
    - Assert decoding a config with a non-registered capability is rejected and the entry reported
    - _Requirements: 19.4_

- [x] 11. Integrate and wire into gating
  - [x] 11.1 Wire the validated Gating_Config into `business_capability.dart` gating
    - Edit `lib/core/isolation/business_capability.dart` to consume the validated Gating_Config (default-deny when no validated entry exists), without breaking existing isolation behavior
    - _Requirements: 3.3, 19.1, 19.5_
  - [ ]* 11.2 Write integration test for the full pipeline
    - Run `buildAll` → `validateAll` → artifact generation → `GatingConfig.fromMappings` → JSON round-trip across all 19 types with zero violations
    - _Requirements: 2.1, 3.1, 16.1, 17.1, 18.1, 19.1_

- [x] 12. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional test sub-tasks and can be skipped for a faster MVP.
- Each task references specific requirements (granular clauses) for traceability.
- The validator and the builder are separate implementations: property tests feed builder output to the validator (forward direction) and feed mutated mappings to the validator (rejection direction).
- Each property test is tagged with `Feature: subscription-plan-tiers, Property {number}` and runs at least 100 iterations.
- Checkpoints ensure incremental validation; ask the user if questions arise.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "2.1", "2.2"] },
    { "id": 1, "tasks": ["1.3", "2.3", "2.4", "3.1", "4.1", "5.1"] },
    { "id": 2, "tasks": ["3.2", "4.2", "4.3", "6.1", "7.1"] },
    { "id": 3, "tasks": ["6.2", "7.2", "7.3", "7.4", "7.5", "7.6", "7.7", "7.8", "7.9", "7.10", "7.11", "7.12", "7.13", "7.14", "7.15", "7.16", "9.1", "9.2", "9.3", "10.1"] },
    { "id": 4, "tasks": ["9.4", "9.5", "9.6", "10.2", "10.3", "11.1"] },
    { "id": 5, "tasks": ["11.2"] }
  ]
}
```
