# Implementation Plan: Full-Stack Audit and Remediation System

## Overview

This implementation plan covers the automated audit and remediation pipeline for DukanX. The system uses Dart scripts for Flutter analysis and TypeScript/Node.js scripts for backend analysis, following a pipeline pattern: Discover → Analyze → Triage → Remediate → Validate → Track. Tasks are organized to build foundational infrastructure first, then analyzers, then remediation tooling, then validation and tracking.

## Tasks

- [x] 1. Set up audit infrastructure and configuration
  - [x] 1.1 Create audit directory structure and configuration files
    - Create `scripts/audit/` directory with `analyzers/`, `registry/`, `remediation/`, `validation/`, and `config/` subdirectories
    - Create `scripts/audit/config/verticals.json` with all 14 vertical definitions including id, name, featureFolder, businessType, primaryEntity, criticalJourney, domainScreens, and dashboardRoute
    - Create `scripts/audit/config/audit_rules.json` with configurable patterns for mock detection, tenant ID patterns, and priority thresholds
    - _Requirements: 1.1, 1.2, 5.1, 12.5_

  - [x] 1.2 Create shared TypeScript interfaces and types for the audit system
    - Create `scripts/audit/types.ts` with all shared interfaces: AuditIssue, PriorityLevel, IssueType, Route, CallSite, MatchResult, DynamoDbOperation, ScreenStatus, TransitionResult, TriageReport, ProgressSummary
    - Define enums for PriorityLevel (P0–P3), ScreenStatus, and IssueType
    - Define the VALID_TRANSITIONS map for the status state machine
    - _Requirements: 5.1, 15.1_

  - [x] 1.3 Create shared Dart models for Flutter-side audit tools
    - Create `scripts/audit/models/screen_entry.dart` with ScreenEntry class, Priority enum, ScreenClassification, and MockDetectionResult
    - Create `scripts/audit/models/navigation_models.dart` with NavigationGraph, ScreenNode, NavType, UnreachableScreen, and BrokenLink classes
    - _Requirements: 1.1, 1.2, 3.1_

- [ ] 2. Implement Screen Discovery Engine
  - [x] 2.1 Implement the Screen Discovery Engine scanner (`screen_discovery.dart`)
    - Implement `scan()` method to recursively find all Dart files under `lib/`
    - Implement `classifyFile()` to detect StatelessWidget/StatefulWidget classes where filename or class name contains "screen" or "page" (case-insensitive)
    - Implement `deriveVertical()` to extract vertical from `lib/features/<folder>/` paths, defaulting to "core/general"
    - Exclude files matching naming pattern but lacking valid widget class declarations (log as skipped false-positives)
    - _Requirements: 1.1, 1.2, 1.6_

  - [-] 2.2 Implement mock data detection in Screen Discovery
    - Implement `detectMockData()` to identify: hardcoded sample data arrays with 2+ literal entries, TODO/placeholder comments indicating fake data, imports from paths containing "mock"/"dummy"/"fake"/"sample", conditional logic returning inline literal data without API calls
    - Return MockDetectionResult with boolean flag and comma-separated list of detected patterns
    - _Requirements: 6.1_

  - [~] 2.3 Implement priority assignment and CSV output
    - Implement `assignPriority()` based on: dashboards/entry-points → High, standard feature screens with navigation wired → Medium, all others → Low
    - Implement CSV serialization matching the Discovery Registry schema (Project, Feature, FileName, RelativePath, BusinessTypes, MockData, MockReasons, ApiConnected, OfflineReady, UiConsistent, NavWired, Priority, Status, StatusReason, StatusTimestamp)
    - Handle file additions and deletions between scan cycles (append new, mark removed)
    - _Requirements: 1.3, 1.4, 1.5_

  - [ ]* 2.4 Write property test for Screen Classifier Correctness
    - **Property 1: Screen Classifier Correctness**
    - Use `glados` to generate random Dart file contents and paths, verify inclusion IFF path/class contains "screen"/"page" AND file has StatelessWidget/StatefulWidget class
    - **Validates: Requirements 1.1, 1.6**

  - [ ]* 2.5 Write property test for Vertical Derivation
    - **Property 2: Vertical Derivation Correctness**
    - Use `glados` to generate random file paths, verify paths under `lib/features/<folder>/` derive to `<folder>` and all others derive to "core/general"
    - **Validates: Requirements 1.2**

  - [ ]* 2.6 Write property test for CSV Serialization with Priority Logic
    - **Property 3: CSV Serialization with Priority Logic**
    - Use `glados` to generate random ScreenEntry values, verify round-trip CSV serialize→parse produces equivalent entry, and priority assignment matches rules
    - **Validates: Requirements 1.3**

  - [ ]* 2.7 Write property test for Mock Data Pattern Detection
    - **Property 8: Mock Data Pattern Detection**
    - Use `glados` to generate Dart file contents with and without mock patterns, verify detection aligns with the four defined indicator categories
    - **Validates: Requirements 6.1**

- [ ] 3. Implement API Surface Mapper
  - [x] 3.1 Implement backend route parser (`api_mapper.ts`)
    - Implement `parseRoutes()` to parse `serverless.yml` and `template.yaml` extracting HTTP method, path, handler file, and authentication status
    - Handle YAML parse errors gracefully: skip file, log warning with path and error, continue
    - Implement `normalizePath()` to replace path parameters (e.g., `{id}`) with wildcards for matching
    - _Requirements: 2.1, 2.5_

  - [-] 3.2 Implement Flutter HTTP call site scanner
    - Implement `scanCallSites()` to find all HTTP request call sites in Flutter code (direct HTTP calls, service wrappers, repository methods)
    - Extract request path, HTTP method, source file, and line number for each call site
    - Normalize discovered call site paths using the same normalization as routes
    - _Requirements: 2.2_

  - [~] 3.3 Implement call-site-to-route matching and reporting
    - Implement `matchCallSitesToRoutes()` to match normalized call site paths to normalized route paths
    - Identify broken dependencies (call sites with no matching route → P1) and orphaned routes (routes with no matching call site → P2)
    - Generate summary with totals: cataloged routes, mapped call sites, broken dependencies, orphaned routes
    - _Requirements: 2.3, 2.4, 2.6_

  - [ ]* 3.4 Write property test for API Path Matching
    - **Property 4: API Path Matching**
    - Use `fast-check` to generate random HTTP paths and route sets, verify connection IFF normalized paths are equal, and broken/orphaned classification is correct
    - **Validates: Requirements 2.2, 2.3, 2.4**

- [ ] 4. Implement Navigation Graph Builder
  - [x] 4.1 Implement navigation graph construction (`navigation_graph.dart`)
    - Implement `buildGraph()` to parse all navigation calls (Navigator.push, Navigator.pushNamed, GoRouter routes, context.go, context.push, named routes) and construct a directed graph
    - Set the app's root route as the reachability root
    - Handle circular navigation routes by breaking cycles at second visit and logging warnings
    - _Requirements: 3.1_

  - [-] 4.2 Implement reachability analysis and broken link detection
    - Implement `findUnreachable()` using BFS/DFS from root to identify screens with no inbound path from any reachable screen (flag as P2)
    - Implement `findBrokenLinks()` to detect route references that don't resolve to registered screens (flag as P1)
    - Implement `toAdjacencyList()` to export graph grouped by vertical entry points
    - _Requirements: 3.2, 3.3, 3.4_

  - [ ]* 4.3 Write property test for Navigation Graph Reachability
    - **Property 5: Navigation Graph Reachability**
    - Use `glados` to generate random directed graphs with root nodes, verify unreachable detection IFF no directed path from root exists, and broken link detection for unresolved routes
    - **Validates: Requirements 3.2, 3.3**

- [~] 5. Checkpoint - Ensure discovery tools pass tests
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 6. Implement DynamoDB Access Analyzer
  - [x] 6.1 Implement DynamoDB operation scanner (`dynamodb_analyzer.ts`)
    - Implement `scanOperations()` to parse handler files for DynamoDB operations (get, put, query, scan, update, delete) extracting table name, key conditions, filter expressions, handler file, and line number
    - Implement `isDynamicConstruction()` to detect dynamically constructed table names or key conditions that can't be statically resolved (flag as P1)
    - _Requirements: 4.1, 4.5_

  - [-] 6.2 Implement tenant isolation and efficiency checks
    - Implement `hasTenantIsolation()` to check if partition key or filter expression references tenant identifier matching configurable pattern (default: `tenantId` or `tenant_id`)
    - Flag operations without tenant isolation as P0 security issues
    - Implement `detectInefficientScans()` to flag scan operations where partition key is determinable (P2 performance issue)
    - _Requirements: 4.2, 4.3, 4.4_

  - [ ]* 6.3 Write property test for DynamoDB Tenant Isolation Detection
    - **Property 6: DynamoDB Tenant Isolation Detection**
    - Use `fast-check` to generate random DynamoDB operations with varying key conditions, verify P0 flagging IFF no tenant identifier reference exists
    - **Validates: Requirements 4.2, 4.3**

- [ ] 7. Implement Triage Classifier
  - [-] 7.1 Implement priority classification logic (`triage_classifier.ts`)
    - Implement `classify()` with priority rules: P0 for tenant leakage, P1 for mock data in production or broken navigation, P2 for missing offline on write screens, P3 for UI inconsistency
    - Implement highest-priority-wins logic when multiple criteria match
    - Default to P3 for issues matching no specific criteria
    - _Requirements: 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8_

  - [~] 7.2 Implement triage report generation
    - Implement `generateReport()` to group issues by priority level with total counts per Vertical and overall totals
    - Output summary on each scan completion
    - _Requirements: 5.9_

  - [ ]* 7.3 Write property test for Priority Classification Function
    - **Property 7: Priority Classification Function**
    - Use `fast-check` to generate random AuditIssue objects, verify P0/P1/P2/P3 assignment matches rules and highest-priority-wins for multi-criteria matches
    - **Validates: Requirements 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8**

- [ ] 8. Implement UI Auditor and Lambda Auditor
  - [~] 8.1 Implement UI consistency auditor (`ui_auditor.dart`)
    - Detect hardcoded Color literals, TextStyle literals, and numeric padding/margin that duplicate theme-available values
    - Verify sidebar usage (EnterpriseDesktopSidebar on desktop, MobileDrawer on mobile), KpiCard usage, shared DataTable/ListView, FormFields, and theme-defined button styles
    - Verify responsive breakpoint compliance (mobile < 600px, tablet 600–1100px, desktop ≥ 1100px)
    - Check accessibility: 48x48dp touch targets, semantic labels on interactive elements
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

  - [~] 8.2 Implement Lambda handler auditor (`lambda_auditor.ts`)
    - Verify input validation (Zod/schema library usage), structured error responses with correlation IDs, correct HTTP status codes, and request/response logging
    - Detect batch operation opportunities (2+ DynamoDB ops on same table)
    - Detect inadequate catch blocks (neither re-throw, error response, nor logging)
    - Detect direct DynamoDB client usage bypassing repository layer
    - Detect sensitive data in log statements (passwords, tokens, emails, phone numbers, government IDs)
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 11.7_

  - [ ]* 8.3 Write property test for UI Compliance Detection
    - **Property 15: UI Compliance Detection — Hardcoded Style Values**
    - Use `glados` to generate Dart widget code with inline style values vs. theme references, verify flagging only for inline duplicates of theme-available values
    - **Validates: Requirements 10.3**

  - [ ]* 8.4 Write property test for Contrast Ratio Accessibility Check
    - **Property 16: Contrast Ratio Accessibility Check**
    - Use `glados` to generate random foreground/background color pairs, compute WCAG 2.1 contrast ratio, verify non-compliance flagging below 4.5:1 normal text or 3:1 large text
    - **Validates: Requirements 10.4**

  - [ ]* 8.5 Write property test for Handler Compliance Detection
    - **Property 22: Handler Compliance Detection**
    - Use `fast-check` to generate Lambda handler code snippets, verify correct identification of missing validation, missing correlation IDs, incorrect status codes, missing logging, inadequate catch blocks, repository bypass, and sensitive data in logs
    - **Validates: Requirements 11.1, 11.3, 11.4, 11.5**

- [ ] 9. Implement Code Quality Checker
  - [~] 9.1 Implement code quality scorer and enforcement (`code_quality.ts`)
    - Enforce TypeScript strict mode with zero unannoted `any` usage
    - Enforce Flutter analysis rules: no unused imports/variables, prefer const, explicit type annotations on public members
    - Verify test file existence for each repository class (success + error path tests)
    - Enforce performance requirements: no sync DynamoDB calls, no unbounded list/scan, no per-iteration DB calls
    - _Requirements: 13.1, 13.2, 13.3, 13.4_

  - [~] 9.2 Implement quality score calculation and diff-based classification
    - Calculate per-module quality score (0–100) as equally-weighted average of: widget test coverage %, handler validation %, responsive layout compliance %
    - Implement diff-based violation classification: new code (in diff added lines) → blocking, existing code (unchanged) → non-blocking, indeterminate → blocking
    - _Requirements: 13.5, 13.6, 13.7, 13.8_

  - [ ]* 9.3 Write property test for Code Quality Score Calculation
    - **Property 17: Code Quality Score Calculation**
    - Use `fast-check` to generate random metric triples (test coverage %, validation %, responsive %), verify score equals equally-weighted average on 0–100 scale
    - **Validates: Requirements 13.5**

  - [ ]* 9.4 Write property test for Diff-Based Violation Classification
    - **Property 18: Diff-Based Violation Classification**
    - Use `fast-check` to generate random violations with diff contexts, verify blocking/non-blocking classification based on whether violation appears in added lines, unchanged lines, or indeterminate
    - **Validates: Requirements 13.6, 13.7, 13.8**

- [~] 10. Checkpoint - Ensure all analyzer tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 11. Implement Offline Queue and Sync
  - [~] 11.1 Implement SQLite offline mutation queue (`core/sync/` extension)
    - Create SQLite table schema for offline_mutations with id, tenant_id, timestamp, operation_type, entity_type, payload, retry_count, status, failure_reason, affected_record_id, created_at, synced_at
    - Create indexes on status, tenant_id, and timestamp columns
    - Implement SQLCipher encryption with tenant-specific encryption key
    - _Requirements: 8.1, 8.2, 8.6_

  - [~] 11.2 Implement enqueue and capacity management
    - Implement `enqueue()` method with max capacity check (5000 mutations), reject with warning when at capacity
    - Implement `queueSize` and `isAtCapacity` getters
    - Store mutations with timestamp, operation type, payload, tenant_id, and retry count
    - _Requirements: 8.2, 8.8_

  - [~] 11.3 Implement replay and conflict resolution
    - Implement `replay()` to process mutations in chronological order, batches of 50, 60-second timeout per batch
    - Implement last-write-wins conflict resolution using server timestamp comparison
    - After 3 failed sync attempts per mutation, display persistent notification with operation type, affected record, and failure reason
    - Implement `getFailedMutations()` and `discard()` for user retry/discard actions
    - _Requirements: 8.3, 8.4_

  - [~] 11.4 Implement offline UI indicators and restrictions
    - Display visible offline indicator when device is disconnected
    - Disable real-time-only actions while offline: payment processing, account deletion, subscription changes
    - Show "data unavailable until first sync" message when no cached data exists for a screen
    - Restrict to write-only operations where applicable when offline with no cache
    - _Requirements: 8.5, 8.7_

  - [ ]* 11.5 Write property test for Offline Cache Round-Trip with Encryption
    - **Property 9: Offline Cache Round-Trip with Encryption**
    - Use `glados` to generate random data entities, verify store→retrieve round-trip produces equivalent values and encrypted on-disk representation lacks plaintext payload
    - **Validates: Requirements 8.1, 8.6**

  - [ ]* 11.6 Write property test for Mutation Queue Chronological Ordering
    - **Property 10: Mutation Queue Chronological Ordering**
    - Use `glados` to generate mutation sequences with distinct timestamps, verify replay processes in strictly ascending timestamp order
    - **Validates: Requirements 8.2, 8.3**

  - [ ]* 11.7 Write property test for Queue Capacity Enforcement
    - **Property 11: Queue Capacity Enforcement**
    - Use `glados` to test enqueue at capacity (5000) → rejected, below capacity → succeeds and increments by 1
    - **Validates: Requirements 8.4, 8.8**

- [ ] 12. Implement Tenant Isolation Layer
  - [~] 12.1 Implement tenant ID extraction and validation (`my-backend/src/middleware/`)
    - Implement `extractTenantId()` to extract tenant ID from Cognito JWT claims
    - Implement format validation: non-empty, max 128 chars, `[a-zA-Z0-9_-]+` pattern
    - Return HTTP 403 for absent, empty, or invalid format tenant IDs
    - _Requirements: 9.2_

  - [~] 12.2 Implement tenant scoping and cross-tenant rejection
    - Implement `scopeToTenant()` to inject tenant ID into all DynamoDB operation key conditions (query, get, put, update, delete)
    - Implement `verifyOwnership()` to check resource tenant matches authenticated tenant
    - Return HTTP 403 with zero target-tenant data for cross-tenant access attempts
    - Implement `logSecurityEvent()` for all security violations (authenticated tenant ID, target resource, operation type, timestamp)
    - _Requirements: 9.1, 9.3, 9.4_

  - [~] 12.3 Implement repository-layer enforcement and deployment gate
    - Ensure all DynamoDB operations are accessible only through tenant-scoped repository methods
    - Implement deployment-time static analysis to detect raw DynamoDB client calls bypassing repository layer
    - Fail deployment and report violating handler name and call location on bypass detection
    - _Requirements: 9.5, 9.6_

  - [ ]* 12.4 Write property test for Tenant ID Format Validation
    - **Property 12: Tenant ID Format Validation**
    - Use `fast-check` to generate random strings, verify acceptance IFF non-empty, ≤128 chars, and matches `[a-zA-Z0-9_-]+`; failures result in 403 rejection
    - **Validates: Requirements 9.2**

  - [ ]* 12.5 Write property test for Cross-Tenant Access Rejection
    - **Property 13: Cross-Tenant Access Rejection**
    - Use `fast-check` to generate tenant ID pairs and resource identifiers, verify 403 + zero data response when resource tenant ≠ authenticated tenant
    - **Validates: Requirements 9.3**

- [~] 13. Checkpoint - Ensure offline and tenant isolation tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 14. Implement Remediation Protocol
  - [~] 14.1 Implement mock data eliminator (`remediation/mock_eliminator.dart`)
    - Map each detected mock data usage to the corresponding real API endpoint or local database query
    - Flag "unresolved" occurrences that cannot be mapped to a real source
    - Verify screens render empty-state widget with "no data available" message when real source returns zero records
    - Implement CI assertion that fails pipeline for new mock data patterns in non-test code
    - _Requirements: 6.2, 6.3, 6.4, 6.5_

  - [~] 14.2 Implement API connector (`remediation/api_connector.dart`)
    - Connect screens to real API endpoints using existing repository pattern (feature repository → ApiClient)
    - Implement loading state (visual indicator during API response), error state (message on failure), and retry logic (3 attempts, exponential backoff starting at 1s)
    - Create missing backend endpoints following `authorizedHandler` pattern with input validation, tenant context, and structured error responses
    - Preserve user-entered form data and navigation state on API failure after retries
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

  - [ ]* 14.3 Write property test for Error State Preserves Form Data
    - **Property 14: Error State Preserves Form Data**
    - Use `glados` to generate random form field values and navigation states, simulate API failure after retries, verify all values and state remain identical to pre-failure state
    - **Validates: Requirements 7.5**

  - [~] 14.4 Implement offline mode scaffolding (`remediation/offline_implementer.dart`)
    - Implement local SQLite caching for read operations so screens render from cache when offline
    - Wire write screens to the OfflineQueue for mutation storage while offline
    - Apply offline indicator and action restrictions per requirement 8.5
    - _Requirements: 8.1, 8.2, 8.5_

  - [~] 14.5 Implement tenant enforcement verifier (`remediation/tenant_enforcer.ts`)
    - Verify tenant scoping is applied at the repository layer for all DynamoDB operations on each remediated handler
    - Log all detected bypasses with handler name and call location
    - _Requirements: 9.5, 9.6_

- [ ] 15. Implement Vertical-Specific Validation
  - [~] 15.1 Implement vertical validator (`validation/vertical_validator.dart`)
    - Verify each vertical's domain screens are reachable within 3 navigation hops from dashboard entry point
    - Verify each vertical's data models have CRUD API endpoints and offline cache tables
    - Verify KPI_Cards reference live data-source queries (not hardcoded constants)
    - _Requirements: 12.1, 12.2, 12.3_

  - [~] 15.2 Implement critical journey executor
    - Execute critical user journey per vertical's primary entity: create → list → edit → report → export/print
    - Run each of the 14 verticals independently with isolated test data
    - On step failure: mark vertical validation as failed, record failing step, continue remaining verticals
    - _Requirements: 12.4, 12.5, 12.6_

  - [ ]* 15.3 Write property test for Vertical Navigation Depth
    - **Property 21: Vertical Navigation Depth**
    - Use `glados` to generate navigation graphs with dashboard entry points and domain screens, verify reachability within 3 hops and report violations for screens requiring more
    - **Validates: Requirements 12.1**

- [ ] 16. Implement E2E Validator and Progress Tracker
  - [~] 16.1 Implement E2E validation runner (`validation/e2e_runner.dart`)
    - Implement `validateDataFlow()` for full data flow test (UI → API → DB → response → UI) with 30-second per-stage timeout
    - Implement `validateSyncCycle()` for offline sync validation (offline write → queue → reconnect → sync → cache) with 60-second sync timeout
    - Implement `validateTenantIsolation()` for cross-tenant access test (Tenant A token → Tenant B resource → expect 403 + zero data)
    - On failure: reopen issue within 5 minutes, assign P1, include failure details (stage, input, expected, actual, timestamp)
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5_

  - [~] 16.2 Implement Progress Tracker (`registry/progress_tracker.ts`)
    - Implement `transition()` with state machine validation: only allow valid transitions per VALID_TRANSITIONS map
    - Reject transitions with empty reasons; require non-empty string ≤500 characters
    - Implement `getSummary()` showing per-vertical: total screens, count per status, blocking reasons
    - Implement `getReadinessPercentage()` as (Validated / Total) × 100 rounded to 1 decimal
    - _Requirements: 15.1, 15.2, 15.3, 15.4, 15.5_

  - [ ]* 16.3 Write property test for Status State Machine Transitions
    - **Property 19: Status State Machine Transitions**
    - Use `fast-check` to generate random (currentStatus, targetStatus, reason) triples, verify success IFF transition is in valid set AND reason is non-empty; invalid transitions preserve current status
    - **Validates: Requirements 15.1, 15.3**

  - [ ]* 16.4 Write property test for Progress Aggregation and Readiness Percentage
    - **Property 20: Progress Aggregation and Readiness Percentage**
    - Use `fast-check` to generate random sets of screen statuses, verify per-vertical counts are correct and readiness = (Validated / Total) × 100 rounded to 1 decimal
    - **Validates: Requirements 15.4, 15.5**

- [ ] 17. Implement Discovery Registry Manager and CI Integration
  - [~] 17.1 Implement Discovery Registry CSV manager (`registry/discovery_registry.ts`)
    - Implement read/write for the Discovery Registry CSV with all columns matching the schema
    - Implement file-watch integration: detect additions, deletions, and renames between scan cycles
    - Integrate all analyzer outputs into a single registry update pass
    - _Requirements: 1.3, 1.4, 1.5_

  - [~] 17.2 Implement CI pipeline integration
    - Implement mock-data-free CI assertion that fails pipeline for patterns in non-test code
    - Implement TypeScript `any` detection (blocking for new code, backlog for existing)
    - Implement Flutter analysis violation reporting (blocking/non-blocking per diff analysis)
    - Implement deployment gate for repository bypass detection
    - _Requirements: 6.5, 13.1, 13.6, 13.7, 13.8, 9.6_

- [~] 18. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation between major phases
- Property tests use `fast-check` for TypeScript and `glados` for Dart, minimum 100 iterations per test
- The implementation uses Dart scripts for Flutter analysis and TypeScript/Node.js for backend analysis
- The existing `audit_results.csv`, `core/sync/`, `core/database/`, `core/offline/`, `core/responsive/`, and `my-backend/src/middleware/handler-wrapper.ts` patterns are reused
- Unit tests complement property tests for specific scenarios per the testing strategy in the design

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3"] },
    { "id": 1, "tasks": ["2.1", "3.1", "4.1", "6.1"] },
    { "id": 2, "tasks": ["2.2", "3.2", "4.2", "6.2", "7.1"] },
    { "id": 3, "tasks": ["2.3", "3.3", "7.2", "8.1", "8.2"] },
    { "id": 4, "tasks": ["2.4", "2.5", "2.6", "2.7", "3.4", "4.3", "6.3", "7.3"] },
    { "id": 5, "tasks": ["8.3", "8.4", "8.5", "9.1"] },
    { "id": 6, "tasks": ["9.2", "9.3", "9.4"] },
    { "id": 7, "tasks": ["11.1", "12.1"] },
    { "id": 8, "tasks": ["11.2", "11.3", "12.2"] },
    { "id": 9, "tasks": ["11.4", "11.5", "11.6", "11.7", "12.3"] },
    { "id": 10, "tasks": ["12.4", "12.5"] },
    { "id": 11, "tasks": ["14.1", "14.2", "14.4", "14.5"] },
    { "id": 12, "tasks": ["14.3", "15.1", "15.2"] },
    { "id": 13, "tasks": ["15.3", "16.1", "16.2"] },
    { "id": 14, "tasks": ["16.3", "16.4", "17.1"] },
    { "id": 15, "tasks": ["17.2"] }
  ]
}
```
