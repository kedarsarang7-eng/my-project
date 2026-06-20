# Implementation Plan: Comprehensive Test & Certification

## Overview

This plan builds the **Certification_System** — a Dart test-and-tooling layer under
`Dukan_x/test/certification/` (pure decision core + property/unit tests) plus the four deliverable
test suites under their required roots (`test/unit/`, `test/widget/`, `integration_test/`, `e2e/`).

The implementation follows the design pipeline **scan → plan → test → gate → trace → decide**. The
pure "decision core" components are built first and validated with `dartproptest` property tests
(one test per design property, `kNumRuns = 200`). The IO shell (scanners, runners, artifact writers)
and the deliverable test suites are wired on top. Every step builds on the previous one and ends
with full pipeline wiring, leaving no orphaned code.

Language: **Dart** (matches the existing repo and the design). PBT library: **dartproptest ^0.2.1**.

## Tasks

- [x] 1. Set up certification tooling structure and shared domain
  - [x] 1.1 Create directory structure, dependencies, and shared domain types
    - Create `Dukan_x/test/certification/` with `core/`, `io/`, and `pbt/` subfolders, and the layer roots `test/unit/`, `test/widget/`, `integration_test/`, `e2e/`
    - Add `golden_toolkit` and `patrol` to `dev_dependencies` in `Dukan_x/pubspec.yaml`; confirm `dartproptest`, `decimal`, and `mockito` are present
    - Define the 19 `Business_Type` mirror set, `kServiceOnlyTypes`, and the `Module` enum in `core/domain.dart`
    - _Requirements: 1.4, 16.1, 16.3_
  - [x]* 1.2 Build PBT generators and test harness
    - Implement business-type and Service_Only_Type generators, money generator (scale 2, domain edges 0.01 / 999,999,999.99 / .xx5 half-up boundary), quantity generator (scale 3), and a one-rule mutation generator
    - Add `const int kNumRuns = 200;` and the property-tagging comment convention
    - _Requirements: 2.2, 2.5_

- [x] 2. Implement calculation engine and Layer 1 unit tests
  - [x] 2.1 Implement `CalculationEngine` and `CalcResult`
    - Implement `CalcValue`/`CalcError`, fixed-precision decimal arithmetic for tax, GST, VAT, discounts, invoice totals, payment reconciliation, inventory adjustments, credit/debit entries, and `roundCurrency` (half-up, scale 2)
    - Return `CalcError` and persist nothing for null, non-numeric, illegally negative, or out-of-domain `[0.01, 999999999.99]` inputs
    - _Requirements: 2.1, 2.2, 2.3, 2.6, 2.7_
  - [x]* 2.2 Write property test for currency rounding and scale
    - **Property 2: Currency rounding is half-up at scale 2 and results carry the fixed scale**
    - **Validates: Requirements 2.2, 2.3**
  - [x]* 2.3 Write property test for invalid calculation input
    - **Property 3: Invalid calculation input yields a defined error and persists nothing**
    - **Validates: Requirements 2.6, 2.7**
  - [x]* 2.4 Write Layer 1 unit tests for calculation categories and edge cases
    - Cover all ten calculation categories with ≥1 case per applicable Business_Type and the seven edge cases (zero quantity, negative stock, partial payments, refunds, expired licenses, min-limit, max-limit) under `test/unit/<type>/<module>/`
    - _Requirements: 2.1, 2.4, 2.5, 2.8_

- [x] 3. Implement invariants and entitlement logic
  - [x] 3.1 Implement `LedgerInvariant` and `InventoryInvariant`
    - `expectedBalance = subtotal - discount - payment` at scale 2; `expectedOnHand = received - invoiced` at scale 3
    - _Requirements: 5.2, 5.3_
  - [x]* 3.2 Write property test for ledger balance invariant
    - **Property 4: Ledger balance invariant**
    - **Validates: Requirements 5.2**
  - [x]* 3.3 Write property test for inventory on-hand invariant
    - **Property 5: Inventory on-hand invariant**
    - **Validates: Requirements 5.3**
  - [x] 3.4 Implement subscription/license entitlement checker
    - Pure function: a gated feature is accessible iff the active subscription's entitlement set contains it; otherwise blocked with a denial indication (covers license activation and upgrade/downgrade gating)
    - _Requirements: 5.4_
  - [x]* 3.5 Write property test for entitlement gating
    - **Property 6: Subscription and license gating is accessible exactly when entitled**
    - **Validates: Requirements 5.4**

- [x] 4. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Implement defect validation and store
  - [x] 5.1 Implement `Defect` model and `DefectValidator`
    - Define `Severity`, `ResolutionStatus`, `GapCategory`, `Defect`, and `DefectValidation`
    - Pure structural validation rejecting (and naming the offending field) missing id, out-of-set severity/status, empty repro steps, or not-exactly-one category; retain no partial record
    - _Requirements: 7.1, 7.2, 7.3_
  - [x]* 5.2 Write property test for defect-record validation
    - **Property 9: Defect-record validation accepts well-formed records and rejects malformed ones**
    - **Validates: Requirements 7.1, 7.2, 7.3**
  - [x] 5.3 Implement `DefectStore`
    - Persist only validated defects under `defects/`; expose `allClosed`; on status → Resolved/Closed update status and link the resolution into the matrix in one operation
    - _Requirements: 7.4, 7.5_
  - [x]* 5.4 Write example test for defect transactional resolution update
    - Assert a status change to Resolved/Closed updates status and links the resolution into the Traceability_Matrix within the same operation
    - _Requirements: 7.5_

- [x] 6. Implement coverage-gap and reconciliation logic
  - [x] 6.1 Implement `CoverageGapCalculator`
    - Record a gap iff actual < expected (460 screens, 19 types), stating expected, actual, and non-negative shortfall; detect zero-test requirements
    - _Requirements: 1.8, 1.9, 13.3, 13.4_
  - [x]* 6.2 Write property test for coverage-gap shortfall arithmetic
    - **Property 1: Coverage-gap shortfall arithmetic**
    - **Validates: Requirements 1.8, 1.9**
  - [x] 6.3 Implement `ReconciliationChecker`
    - Detect orphaned references across invoice/payment/inventory/ledger and compute net aggregate balance difference (expected 0.00)
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5_
  - [x]* 6.4 Write property test for data-integrity verdict
    - **Property 13: Data-integrity verdict requires zero orphans and a zero reconciliation difference**
    - **Validates: Requirements 11.1, 11.2, 11.3, 11.4, 11.5**

- [x] 7. Implement quality-gate reducers
  - [x] 7.1 Implement `GateStatusReducer` for performance and security
    - `PerfThresholds`, `PerfMeasurement`, `SecurityCaseResult`; performance green iff every metric is measured and within threshold; security green iff zero failing cases across all five categories; one defect per offending metric/category with measurements retained
    - _Requirements: 9.3, 9.4, 9.6, 10.1, 10.5_
  - [x]* 7.2 Write property test for performance gate
    - **Property 11: Performance gate is green only when every metric is measured and within threshold**
    - **Validates: Requirements 9.3, 9.4, 9.6**
  - [x]* 7.3 Write property test for security gate
    - **Property 12: Security gate is green only with zero failing cases across all five categories**
    - **Validates: Requirements 10.1, 10.5**
  - [x] 7.4 Implement regression reduction logic
    - Reduce per-test results to an overall status: failed iff ≥1 test failed; when failed block release and notify exactly the failed set; when all pass do not block
    - _Requirements: 8.2, 8.3_
  - [x]* 7.5 Write property test for regression conjunction
    - **Property 10: Regression result reduces to a conjunction and blocks on any failure**
    - **Validates: Requirements 8.2, 8.3**

- [x] 8. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 9. Implement benchmark validator
  - [x] 9.1 Implement `BenchmarkValidator` and `BenchmarkDocument`
    - Validation succeeds iff each of the six practice categories maps to ≥1 concrete named action; otherwise reject, name each unmapped category, and retain prior valid content
    - _Requirements: 12.2, 12.3_
  - [x]* 9.2 Write property test for benchmark mapping
    - **Property 14: Benchmark document is valid only when all six practice categories are mapped**
    - **Validates: Requirements 12.2, 12.3**

- [x] 10. Implement traceability matrix and atomic artifact store
  - [x] 10.1 Implement `ArtifactStore` with atomic temp-write-plus-rename
    - A failed/interrupted write leaves the last good artifact intact and returns an error identifying the failed update; entries are append-preserved
    - _Requirements: 13.6, 15.3_
  - [x] 10.2 Implement `TraceabilityMatrix` and `TraceEntry`
    - Exactly one entry per requirement linking test cases → latest results → defects → resolutions; flag `isCoverageGap` when test cases empty; apply changes and persist via `ArtifactStore`
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5_
  - [x]* 10.3 Write property test for coverage-gap flag round-trip
    - **Property 15: Traceability coverage-gap flag tracks linked test cases (round-trip)**
    - **Validates: Requirements 13.3, 13.4**
  - [x]* 10.4 Write property test for traceability persistence stability
    - **Property 16: Traceability persistence is stable across no-op cycles**
    - **Validates: Requirements 13.5**
  - [x]* 10.5 Write example tests for atomic write and within-5s update
    - Assert temp-write-plus-rename atomicity (last good matrix retained on failure) and that a committed test-case change updates the entry within 5 seconds
    - _Requirements: 13.2, 13.6_

- [x] 11. Implement production-readiness decider and mock-data scanner
  - [x] 11.1 Implement `ProductionReadinessDecider` and `ReadinessInputs`
    - Pure decision: go iff mock data absent, debug flags absent, env matches production, crash-free, every gate green, zero unresolved Critical/High defects, and no unevaluatable item; otherwise no-go with itemized reasons
    - _Requirements: 7.4, 12.5, 14.2, 14.3, 14.4, 14.5, 15.3, 15.4_
  - [x]* 11.2 Write property test for production-readiness decision
    - **Property 17: Production-readiness decision is go exactly when all evidence is clean**
    - **Validates: Requirements 7.4, 12.5, 14.2, 14.3, 14.4, 14.5, 15.3, 15.4**
  - [x] 11.3 Implement `MockDataScanner`
    - Scan 100% of a Release_Build's source modules, assets, and config within 300s; classify hardcoded samples, stubbed responses, in-memory fakes, fixtures, and placeholder creds as Mock_Data; one release-blocking defect per occurrence; scan failure → no-go
    - _Requirements: 15.1, 15.2, 15.5, 15.6_
  - [x]* 11.4 Write example test for mock-data classification
    - Run the scanner over a fixture build tree and assert clean vs detected classification and per-occurrence defect creation
    - _Requirements: 15.1, 15.2_

- [x] 12. Implement test-file classifier and service-only omission
  - [x] 12.1 Implement test-file classifier and service-only test-set rules
    - Associate each test path under the four layer roots with exactly one Business_Type and one Module; record a defect for any unassignable file; build service-only test sets that omit and record product/inventory cases with rationale, rejecting injected product/inventory cases
    - _Requirements: 16.3, 16.4, 16.5_
  - [x]* 12.2 Write property test for test-file classification
    - **Property 18: Every test file maps to exactly one business type and one module**
    - **Validates: Requirements 16.3, 16.4**
  - [x]* 12.3 Write property test for service-only omission
    - **Property 19: Service-only certification omits product and inventory test cases**
    - **Validates: Requirements 16.5**

- [x] 13. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 14. Implement inventory scanner (IO shell)
  - [x] 14.1 Implement `InventoryScanner.scan` and `SystemMap` model
    - Walk `lib/features/*` reusing `test/audit/audit_walker.dart` helpers; build business types, screens, routes, modules, roles, backend calls, DB access points, and detected mock data with source paths; continue past unreadable files recording a Coverage_Gap each
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.10_
  - [x] 14.2 Implement `writeSystemMap` to `inventory/system-map.md`
    - Emit one Markdown table per section plus the Coverage_Gap list (including <460 screens and <19 types seeds)
    - _Requirements: 1.7, 1.8, 1.9_
  - [x]* 14.3 Write scanner example tests over a fixture tree
    - Assert the eight system-map tables, evidence source paths, mock-data classification, and gap seeding on a small fixture
    - _Requirements: 1.1, 1.2, 1.5, 1.6, 1.7, 1.10_

- [x] 15. Implement certification pass orchestrator
  - [x] 15.1 Implement `CertificationPass.run` and the six checks
    - Run auth/onboarding, modules-in-workflow-order, route reachability, role-permission enforcement, report/analytics accuracy (mismatch when |diff| > 0.01), and billing/inventory persistence; record defects for failures
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_
  - [x]* 15.2 Write property test for report-accuracy mismatch threshold
    - **Property 7: Report-accuracy mismatch threshold**
    - **Validates: Requirements 6.4**
  - [x]* 15.3 Write property test for certification conjunction
    - **Property 8: Certification result is the conjunction of its checks**
    - **Validates: Requirements 6.7**
  - [x] 15.4 Implement `runAll` and certification report writer
    - Write `reports/business-type-<name>.md` per type with per-check PASS/FAIL, defect ids, overall result, and service-only omissions; produce exactly 19 reports
    - _Requirements: 6.6, 6.7, 6.8, 16.5_
  - [x]* 15.5 Write example test for certification orchestration
    - Over a fixture type set assert the six checks run, defects recorded on failure, and exactly 19 reports written
    - _Requirements: 6.1, 6.6, 6.8_

- [x] 16. Implement the four deliverable test suites
  - [x] 16.1 Implement Layer 2 widget test suite and goldens
    - Under `test/widget/<type>/<module>/`: build/first-frame, input-validation, state (loading/empty/error/success), and one `golden_toolkit` snapshot per screen per type; ≥1-pixel diff fails and records screen + type
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_
  - [x] 16.2 Implement Layer 3 integration test suite against real backend and DynamoDB
    - Under `integration_test/<module>/`: per-module coverage, auth valid/invalid, token refresh within 5s, role-guard grant/deny, offline-sync within 60s with no data loss and deterministic conflict resolution; assert no mock data in Release_Build
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9_
  - [x] 16.3 Implement Layer 4 E2E suite with patrol
    - Under `e2e/<type>/`: one scenario per Business_Type (retail and distribution invariants, license/subscription gating), `patrol` native flows, platform-specific assertions, scenario isolation, and 300s timeout handling
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 5.9_
  - [x]* 16.4 Write CI/scheduler smoke tests
    - Assert the regression trigger (within 10 min of commit), the nightly 24-hour schedule, and that each suite resides under its required root
    - _Requirements: 8.1, 8.4, 8.5_

- [x] 17. Wire the pipeline and deliverable checks
  - [x] 17.1 Wire the scan → plan → test → gate → trace → decide entry point
    - Connect Inventory_Scanner, layer suites, quality gates, Certification_Pass, Defect_Store, Traceability_Matrix, Benchmark builder, Mock_Data_Scanner, and Production_Readiness_Decider into a single orchestration that writes `production-readiness-checklist.md`
    - _Requirements: 14.1, 12.1, 12.4_
  - [x] 17.2 Implement deliverable existence/empty checks
    - Verify all required deliverables exist and are non-empty; record a defect and mark certification incomplete for any missing/empty deliverable
    - _Requirements: 16.1, 16.2_
  - [x]* 17.3 Write integration test for full pipeline wiring
    - Drive the orchestration over a fixture workspace and assert the checklist decision, reasons, and deliverable set
    - _Requirements: 14.1, 14.5, 16.1_

- [x] 18. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional test sub-tasks and can be skipped for a faster MVP.
- Each task references specific requirement sub-clauses for traceability.
- Property tests use `dartproptest` with `kNumRuns = 200`; one test per design property (Properties 1–19), each carrying the `Feature: comprehensive-test-certification, Property {n}` tag comment.
- The pure decision core (calculations, invariants, validators, gate reducers, reconciliation, readiness decider) is built and property-tested before the IO shell and deliverable suites depend on it.
- Deviation: the design keeps `mockito` (already wired) instead of `mocktail` named in the requirements glossary.
- Checkpoints provide incremental validation; Layers 3 and 4 require the real Node.js backend and real DynamoDB certification stage.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "2.1", "3.1", "3.4", "5.1", "6.1", "6.3", "7.1", "7.4", "9.1", "10.1", "12.1", "14.1"] },
    { "id": 2, "tasks": ["2.2", "2.3", "2.4", "3.2", "3.3", "3.5", "5.2", "5.3", "6.2", "6.4", "7.2", "7.3", "7.5", "9.2", "10.2", "11.1", "11.3", "12.2", "12.3", "14.2"] },
    { "id": 3, "tasks": ["5.4", "10.3", "10.4", "10.5", "11.2", "11.4", "14.3", "15.1"] },
    { "id": 4, "tasks": ["15.2", "15.3", "15.4", "16.1", "16.2", "16.3"] },
    { "id": 5, "tasks": ["15.5", "16.4", "17.1", "17.2"] },
    { "id": 6, "tasks": ["17.3"] }
  ]
}
```
