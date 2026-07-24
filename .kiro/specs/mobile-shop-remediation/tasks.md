# Implementation Plan: Mobile Shop Remediation

## Overview

This plan converts the authoritative `requirements.md` and `design.md` into incremental Dart/Flutter and TypeScript/backend implementation tasks. It incorporates the re-verified findings in `audit-reports/business-types/audit-mobileShop.md`, protects already-correct behavior with regression locks, and establishes `Dukan_x/my-backend` plus AWS DynamoDB as the only authoritative MobileShop domain path.

Implementation proceeds from shared contracts and tenant isolation, through DynamoDB integrity and backend workflows, into Flutter offline synchronization and mobile-shop UX, then closes with preservation and traceability gates. Each implementation step must reuse the existing router, Sync Engine, Drift database, Serverless deployment, and canonical backend rather than creating parallel authority.

## Tasks

- [x] 1. Establish remediation evidence and shared contracts
  - [x] 1.1 Create a machine-readable AF-01–AF-53 remediation ledger and validator
    - Add version-controlled ledger data for current evidence, root cause, dependencies, requirement/design/task links, planned changes, status, changed files, and completion evidence; make validation reject missing or duplicate audit IDs and support related `MSR-###` defects.
    - _Requirements: 1.1–1.7, 14.1–14.3_
  - [x] 1.2 Implement documented configuration and deterministic outcome contracts
    - Define typed backend and Flutter contracts for validation precedence, bounds, retry/backoff, retention, transaction fit, pagination, offline eligibility, feature policy, model-version support, errors, correlation IDs, and safe recovery actions without scattered production literals.
    - _Requirements: 3.2, 6.7–6.9, 6.14–6.17, 6.20, 6.29–6.38, 7.2–7.3, 12.1–12.6; GR-4_
  - [x] 1.3 Define versioned MobileShop API, domain, and confirmation schemas
    - Add TypeScript schemas and matching Dart DTOs for IMEI units, invoice associations, service jobs, exchanges, warranties, second-hand intake, returns, reservations, finance, recharge, audit, synchronization, idempotency, conflicts, and `AuthoritativeConfirmation`; normalize `mobileShop`, `mobileshop`, and `mobile_shop` to `mobile_shop` at boundaries.
    - _Requirements: 3.3–3.8, 4.1–4.9, 5.1–5.7, 6.3–6.4, 6.18, 6.27, 6.33, 6.42, 10.4–10.12; GR-2_
  - [x] 1.4 Add schema and ledger contract tests
    - Verify alias normalization, deterministic error envelopes, integer-minor-unit money fields, model versions, confirmation requirements, and complete AF-01–AF-53 ledger coverage.
    - _Requirements: 1.7, 6.18, 12.4, 13.1–13.2, 14.1_

- [x] 2. Provision the canonical DynamoDB infrastructure and access paths
  - [x] 2.1 Extend `Dukan_x/my-backend/serverless.yml` with stage-scoped MobileShop resources
    - Add the encrypted DynamoDB table, GSI keys, Streams, PITR, production deletion protection, TTL, EventBridge Pipes, failure destinations, alarms, optional WebSocket connection resources, and environment configuration under the existing deployment path.
    - _Requirements: 6.1–6.2, 6.14, 6.23–6.25, 6.28–6.29, 6.37–6.40_
  - [x] 2.2 Implement the tenant-bound key codec and named access-pattern repositories
    - Encode tenant identity into every base/GSI partition key; implement AP-01–AP-15 as bounded Query/Get methods; reject unsupported query shapes before datastore access; verify tenant identity on returned and condition-checked records.
    - _Requirements: 6.6, 6.14, 6.19, 6.25, 6.28–6.30, 8.9, 9.12_
  - [x] 2.3 Implement opaque continuation-token handling
    - Sign or encrypt tenant-, route-, query-, index-, model-version-, expiry-, and continuation-position-bound tokens and reject altered, expired, cross-tenant, or wrong-query tokens without returning records.
    - _Requirements: 6.15–6.17, 11.10, 12.6_
  - [x] 2.4 Add DynamoDB infrastructure and access-pattern integration tests
    - Use the project’s local AWS test environment to verify tenant-prefixed PK/GSI conditions, bounded limits, no Scan paths, valid continuation, cross-tenant non-disclosure, PITR/encryption settings, and unsupported-query fail-fast behavior.
    - _Requirements: 6.5–6.6, 6.14–6.17, 6.19, 6.25, 6.28–6.30, 13.4, 13.6_
- [x] 3. Enforce tenant context, business policy, and least-privilege permissions
  - [x] 3.1 Implement backend MobileShop authorization middleware
    - Resolve tenant, business, subject, permissions, and correlation identity from verified authentication/membership; fail closed before DynamoDB or provider access and ignore client-supplied ownership fields.
    - _Requirements: 6.4–6.6, 6.19, 8.3–8.10, 12.3_
  - [x] 3.2 Add dedicated MobileShop permissions and compatibility mappings
    - Define view/manage permissions for service, IMEI, exchange, warranty, second-hand, finance, reports, settings, and export; migrate approved legacy roles additively through an idempotent compatibility matrix.
    - _Requirements: 8.1–8.2, 8.5–8.7, 8.13_
  - [x] 3.3 Centralize Flutter tenant and policy resolution
    - Make sidebar dispatch, quick actions, deep links, named routes, repositories, and synchronization use one authoritative `TenantContextResolver` and equivalent business/capability/permission checks.
    - _Requirements: 2.1–2.4, 5.8–5.9, 8.3–8.7_
  - [x] 3.4 Restrict workload identities and immutable audit access
    - Grant application, stream, migration/backfill, backup, and restore identities only required table/index/environment actions; prevent application update/delete of audit records and keep DynamoDB credentials out of Flutter.
    - _Requirements: 6.39–6.41, 8.10, 8.14_
  - [x] 3.5 Add authorization and IAM boundary tests
    - Verify missing/stale/contradictory evidence, wrong business type, absent permission, cross-tenant IDs, direct routes, repository calls, sync calls, and provider calls all fail before protected access and disclose no existence signal.
    - _Requirements: 6.5–6.6, 6.19, 8.3–8.10, 13.1, 13.6_

- [x] 4. Build DynamoDB integrity, idempotency, audit, and observability primitives
  - [x] 4.1 Implement conditional uniqueness and idempotency records
    - Create tenant-scoped IMEI/reservation claims and Operation_Id records in accepted transactions; replay matching fingerprints, reject mismatches without mutation, and enforce configured retention independently of TTL cleanup.
    - _Requirements: 3.7–3.9, 6.7–6.13, 6.26–6.27; GR-4.3_
  - [x] 4.2 Implement immutable audit and change-event persistence
    - Append audit and change items with model version, actor, operation, correlation, before/after digest, evidence, and correction link in the source transaction; expose no update/delete application methods.
    - _Requirements: 3.3, 4.3, 5.2, 8.11–8.12, 8.14_
  - [x] 4.3 Implement conditional-write and transaction error mapping
    - Translate uniqueness, lifecycle, version, idempotency, transaction cancellation, throttling, and ambiguous SDK outcomes into documented deterministic outcomes while preserving pre-operation state.
    - _Requirements: 3.2, 6.7–6.13, 6.31–6.32, 6.38, 12.4–12.5, 12.8–12.10_
  - [x] 4.4 Add secret-free DynamoDB telemetry
    - Emit correlation, tenant, operation, entity/access-pattern, table/index, latency, capacity, throttling reason, retries/backoff, conditional result, transaction result, and reconciliation outcome; wire dashboards and alarms for the designed signals.
    - _Requirements: 6.23, 6.37–6.38, 13.6_
  - [x] 4.5 Add persistence primitive integration tests
    - Verify first claim wins, concurrent claims accept at most one, matching replay is side-effect-free, fingerprint mismatch preserves all records, audit is append-only, conditional failure preserves exact pre-state, and telemetry contains no secrets.
    - _Requirements: 3.7–3.9, 6.7–6.13, 6.23, 6.26–6.27, 8.14, 13.6_

- [x] 5. Implement authoritative IMEI, lifecycle, and validation policies
  - [x] 5.1 Implement one normalized IMEI validation path in Dart and TypeScript
    - Apply configured separator normalization, 15 ASCII digits, Luhn checksum, required-field behavior, field-associated errors, and shared fixtures; reserve authoritative uniqueness/lifecycle decisions for DynamoDB conditions.
    - _Requirements: 2.5–2.6, 3.1–3.2, 3.12, 4.2–4.4, 12.1–12.3_
  - [x] 5.2 Implement versioned IMEI units and lifecycle transitions
    - Model new, second-hand, demo, reserved, sale-pending, sold, returned, in-service, exchanged, damaged, and retired states; require expected version, actor, reason, evidence, and allowed transition for every command.
    - _Requirements: 3.5–3.6, 3.10–3.11, 4.1, 4.5–4.7, 4.9, 5.2–5.4_
  - [x] 5.3 Implement warranty and monetary validation policies
    - Validate configured ranges and integer-minor-unit values; calculate month-end warranty dates using the last valid target-month day; preserve valid sibling fields on validation failure.
    - _Requirements: 5.5–5.7, 12.1–12.2, 12.6; GR-2.1_
  - [x] 5.4 Add policy and lifecycle unit tests
    - Cover empty/malformed/non-Luhn IMEIs, deterministic precedence, all allowed and forbidden lifecycle edges, month-end/leap-year warranty dates, bounds, and unchanged pre-state on rejection.
    - _Requirements: 3.1–3.2, 3.10–3.12, 4.2–4.7, 5.2–5.7, 13.1–13.2_

- [x] 6. Implement atomic mobile sale consistency and durable reconciliation acceptance
  - [x] 6.1 Build the transaction planner and atomic sale handler
    - Preflight configured item/size headroom and atomically write invoice, device associations, IMEI state/customer/warranty, claims, idempotency, audit, and change records with expected-version conditions.
    - _Requirements: 3.1–3.4, 3.7–3.9, 6.9–6.13, 6.31, 6.42_
  - [x] 6.2 Build accepted-pending sale handling for oversized operations
    - Persist the accepted aggregate state, reservations, idempotency outcome, initial audit event, and ordered `Reconciliation_Record` before returning accepted-pending confirmation; keep involved IMEIs unavailable to competing sales.
    - _Requirements: 3.4–3.6, 6.9, 6.32, 6.42; GR-2.3, GR-3.3_
  - [x] 6.3 Expose versioned sale, cancellation, return, and reconciliation APIs
    - Validate authorization, schemas, fingerprints, versions, and lifecycle preconditions; return committed, accepted-pending, conflict, rejected, or current outcomes with authoritative confirmation only when DynamoDB proves them.
    - _Requirements: 3.3–3.11, 6.3–6.13, 6.42, 12.7–12.10_
  - [x] 6.4 Add sale consistency integration tests
    - Verify atomic success, transaction rollback, oversized accepted-pending durability, retry replay, mismatched fingerprint, concurrent duplicate sale, cancellation/return transitions, unknown SDK outcome, and confirmation semantics.
    - _Requirements: 3.1–3.11, 6.9–6.13, 6.31–6.32, 6.42, 13.6_
- [x] 7. Implement the remaining authoritative MobileShop workflows
  - [x] 7.1 Implement device inventory, second-hand intake, reservation, demo, and return handlers
    - Persist complete unit condition, ownership, evidence, inspection, valuation, exchange linkage, reservation claims, return eligibility/disposition, and immutable events through conditional transactions or durable reconciliation.
    - _Requirements: 4.1–4.7, 8.12_
  - [x] 7.2 Implement service-job, exchange, and warranty handlers
    - Enforce tenant-owned devices, expected versions, allowed statuses, technician/customer/fault data, both exchange transitions, financial adjustment, warranty evidence, claim resolution, and audit coupling.
    - _Requirements: 5.1–5.8, 8.12_
  - [x] 7.3 Implement finance, SIM/recharge, bundle, price-protection, OCR, and compliance ports
    - Add provider-neutral APIs and domain persistence, feature-policy gating, separate stock/tax/accounting lines, approval and margin impact, Provider_Request_Id creation/reuse, ambiguous-outcome reconciliation, and existing e-Way architecture integration.
    - _Requirements: 4.8, 10.1–10.12_
  - [x] 7.4 Implement tenant-bound reports and KPI projections
    - Maintain confirmed projections and bounded queries for lifecycle stock, repairs, exchanges, warranties, used stock, returns, finance, conflicts, reconciliation, margins, and audit history with source watermark metadata.
    - _Requirements: 4.9, 9.1–9.9, 9.12–9.13_
  - [x] 7.5 Add workflow and provider integration tests
    - Cover valid and conflicting lifecycle operations, expected-version failures, provider replay/mismatch/ambiguity, bundle accounting separation, OCR policy alternatives, report tenant isolation, and no fabricated values.
    - _Requirements: 4.1–4.9, 5.1–5.8, 9.7–9.13, 10.1–10.12, 13.1, 13.6_

- [x] 8. Implement reconciliation, change delivery, model migration, and recovery operations
  - [x] 8.1 Implement durable reconciliation workers
    - Conditionally lease ordered bounded steps, record attempts/completed markers/latest errors, make every step idempotent, finalize only after all effects are confirmed, and preserve visible reserved failure until explicit recovery or reversal.
    - _Requirements: 3.4–3.6, 5.2, 6.9, 6.32, 6.38, 12.9_
  - [x] 8.2 Implement Streams, EventBridge, and WebSocket consumers
    - Decode versioned changes, use partial-batch failure handling and DLQs, deduplicate events, remove stale connections, revalidate tenant binding, and publish only minimal pull hints; preserve authenticated pull as authority.
    - _Requirements: 7.4, 7.10–7.15, 8.4_
  - [x] 8.3 Implement version adapters and resumable backfill
    - Add supported-version reads/upgrades, bounded pages, durable checkpoints, conditional writes, safe resume, idempotent reruns, queued-mutation compatibility, and rollback/forward-recovery tooling.
    - _Requirements: 6.20–6.21, 6.33–6.36, 13.3–13.4_
  - [x] 8.4 Remove non-authoritative mobile persistence paths after compatibility checks
    - Inventory duplicate backend roots and obsolete mobile module/router/sync ownership, migrate or drain supported data, prove no traffic/dependency remains, and remove only superseded authority while retaining one documented deployment path.
    - _Requirements: 1.4, 2.8, 6.1–6.2, 6.22, 6.24; GR-1.2_
  - [x] 8.5 Implement backup, restore, and throttling recovery controls
    - Add approved encrypted backup/export controls, restore-drill automation, separate operational identities, retry budgets, typed rate-limited/pending outcomes, and retained idempotency for exhausted retries.
    - _Requirements: 6.37–6.40, 8.13, 13.6_
  - [x] 8.6 Add reconciliation, event, migration, and recovery tests
    - Verify duplicate/out-of-order delivery, lease contention, retry exhaustion, DLQ behavior, uninterrupted-vs-resumed migration equivalence, concurrent newer writes, backup/export permission, restore evidence, and model-version compatibility.
    - _Requirements: 6.20–6.22, 6.33–6.40, 7.10, 8.13, 13.3–13.6_

- [x] 9. Checkpoint — Canonical backend foundation complete
  - Ensure all tests pass, ask the user if questions arise.

- [x] 10. Add tenant-scoped Drift models and repositories
  - [x] 10.1 Extend Drift schema for MobileShop projections and synchronization state
    - Add tenant/version/confirmation-aware tables for domain projections, invoice associations, outbox mutations, conflicts, event inbox, continuation checkpoints, reconciliation status, and provider state; store money in integer minor units.
    - _Requirements: 6.24, 7.1–7.2, 7.6–7.9, 7.13–7.15; GR-2_
  - [x] 10.2 Implement tenant-bound local repository methods
    - Require `TenantContext` on every local method, include tenant in all predicates and unique keys, separate drafts/pending/confirmed records, atomically apply pulled pages with checkpoint advancement, and expose stale/pending/conflict states.
    - _Requirements: 7.1, 7.4, 7.8, 7.12, 7.14–7.15, 8.9_
  - [x] 10.3 Implement supported Drift migrations and generated-code updates
    - Regenerate database artifacts and migrate every supported prior schema without dropping queued work, conflicts, confirmation metadata, or tenant ownership.
    - _Requirements: 6.20, 13.3_
  - [x] 10.4 Add local database isolation and migration tests
    - Verify tenant predicates, duplicate event keys, atomic page/checkpoint apply, persisted outbox/conflicts, prior-version migrations, and no prior-tenant row/count/token leakage.
    - _Requirements: 7.6–7.12, 13.1, 13.3_

- [x] 11. Implement Flutter API adapters and deterministic synchronization
  - [x] 11.1 Implement the versioned `MobileShopApi` adapter
    - Send authentication, correlation, operation, fingerprint, client/model versions, expected versions, bounded limits, and opaque tokens; parse typed outcomes and reject authoritative labels lacking confirmation.
    - _Requirements: 6.3–6.4, 6.15–6.18, 6.42, 12.4–12.5, 12.9_
  - [x] 11.2 Implement durable outbox submission and pull cycles
    - Queue offline-approved commands before local acceptance, preserve online-only input when disconnected, topologically push dependencies, reuse identities on retry, pull from checkpoints, and create durable conflicts for mismatches/version collisions.
    - _Requirements: 7.2–7.9, 7.13–7.15_
  - [x] 11.3 Implement tenant switching and real-time convergence
    - Cancel prior network work/subscriptions, release leases, revoke active tokens/cursors, clear memory, bind the new local scope, deduplicate WebSocket events, prevent version regression, detect gaps, and trigger bounded pulls.
    - _Requirements: 7.10–7.12, 8.4_
  - [x] 11.4 Apply authoritative confirmation atomically to local state
    - Mark only matching tenant records and returned entity versions server-confirmed; retain unknown, failed, or unconfirmed operations as pending/conflicted with retry-safe recovery details.
    - _Requirements: 7.14–7.15, 12.4–12.5, 12.9–12.10; GR-3_
  - [x] 11.5 Add API-contract and synchronization integration tests
    - Verify offline persistence, dependency order, identity reuse, mismatch conflict, page/checkpoint recovery, tenant switch, duplicate/out-of-order hints, failed pulls, and confirmation-scoped state transitions.
    - _Requirements: 7.1–7.15, 8.3–8.4, 13.1_
- [x] 12. Wire mobile billing to authoritative IMEI consistency
  - [x] 12.1 Replace nullable/dead IMEI validation wiring with required dependencies
    - Inject the authoritative validator/orchestrator into `BillsRepository`, remove or replace the no-op business-type string branch, and fail closed for mobileShop when required dependencies or tenant context are absent.
    - _Requirements: 2.5–2.6, 3.12, 12.3; Audit: AF-19–AF-21, AF-37, AF-49_
  - [x] 12.2 Enforce required IMEI and scan-to-bill behavior in billing UI
    - Use required-field configuration, inline deterministic errors, Luhn validation, duplicate-scan rejection, manual fallback, busy-state duplicate prevention, and preservation of valid line-item input.
    - _Requirements: 2.5, 3.1–3.2, 10.3, 11.7–11.8, 12.1–12.2_
  - [x] 12.3 Route mobile sale, cancellation, and return through the consistency orchestrator
    - Save only local draft/pending state before backend confirmation, reuse one operation/fingerprint across retries, display reconciliation status, and prevent unconfirmed outcomes from appearing committed or current.
    - _Requirements: 3.3–3.11, 7.2–7.6, 12.7–12.10; GR-3_
  - [x] 12.4 Add billing repository and widget regression tests
    - Verify dependency injection, blank/invalid/duplicate IMEI blocking, valid sibling preservation, scan duplicate behavior, pending-vs-confirmed labels, retry identity reuse, and unchanged non-mobile billing behavior.
    - _Requirements: 1.3, 1.5–1.6, 2.5–2.6, 3.1–3.12, 10.3, 13.1, 13.7_

- [x] 13. Make every mobile workflow reachable through one guarded route catalog
  - [x] 13.1 Implement the dedicated mobileShop route/sidebar catalog
    - Expose service jobs, exchanges, IMEI tracking/history, warranty, second-hand intake, finance, reports, and settings under matching business/capability/permission metadata; exclude generic entries whose capabilities are absent.
    - _Requirements: 2.1–2.3, 8.3, 8.6; Audit: AF-01–AF-04, AF-22–AF-26, AF-48_
  - [x] 13.2 Wire quick actions, deep links, named routes, and detail routes through the same policy
    - Make IMEI lookup functional, route all entry points to production screens without placeholders/loops/denials, widen device screens only to approved verticals, and apply equivalent guards to content-host dispatch.
    - _Requirements: 2.3–2.4, 2.9, 5.8, 8.3–8.7_
  - [x] 13.3 Remove obsolete parallel mobile navigation and dead dispatch branches
    - Keep `MaterialApp.router`/`appRouterProvider` as the sole composition, remove superseded module routes/redirect stubs and dead business-type string branches only after reachability and compatibility evidence exists.
    - _Requirements: 1.4, 2.8, 6.22; GR-1.2_
  - [x] 13.4 Replace null-session spinners and inert controls
    - Render actionable signed-out/session-error states without domain access; make status cards apply exact filters or expose non-interactive semantics; disable unavailable actions programmatically.
    - _Requirements: 5.9–5.11, 11.12_
  - [x] 13.5 Add navigation, reachability, guard, and session-state tests
    - Enumerate every mobile sidebar item/quick action/deep link, assert the guarded destination builds, verify denial before domain access, ensure absent capabilities stay hidden, and lock the sole-router composition.
    - _Requirements: 2.1–2.9, 5.8–5.11, 8.3–8.7, 13.1_

- [x] 14. Build complete mobile inventory and service presentation workflows
  - [x] 14.1 Implement IMEI inventory, second-hand intake, reservation, demo, and return screens
    - Provide unit-level lifecycle views, seller/evidence/inspection/valuation capture, conflict-aware reservation, IMEI-aware return confirmation, and distinct pending/confirmed states using application services rather than direct authority.
    - _Requirements: 4.1–4.9, 11.1–11.8, 12.7_
  - [x] 14.2 Integrate service-job, exchange, warranty, history, and detail screens
    - Use unified tenant identity and policy, expected versions, live repository data, exact status filters, connected device history, month-end warranty behavior, and typed loading/empty/error/session states.
    - _Requirements: 2.7, 5.1–5.11, 9.1–9.8, 12.4_
  - [x] 14.3 Implement finance, SIM/recharge, OCR, bundle, and price-adjustment UI flows
    - Render provider-neutral forms and pending/ambiguous outcomes, mask sensitive values, preserve entered data offline when online verification is required, and gate each capability by documented policy.
    - _Requirements: 7.3, 10.1–10.12, 12.1–12.8_
  - [x] 14.4 Add workflow widget and application-service tests
    - Cover validation, lifecycle confirmations, filter activation, session loss, conflict/pending states, provider ambiguity, policy-disabled OCR, and tenant/permission boundaries across supported workflows.
    - _Requirements: 4.1–4.9, 5.1–5.11, 10.1–10.12, 13.1_

- [x] 15. Replace fabricated dashboards with live KPIs, reports, and catalogue semantics
  - [x] 15.1 Implement confirmation-aware Live KPI providers and cards
    - Replace hardcoded warranty/repair/exchange values with tenant-bound providers for every required metric and represent loading, current, empty, stale, unavailable, and error states with watermark/version metadata.
    - _Requirements: 2.7, 9.1–9.8, 9.13, 12.10; Audit: AF-33, AF-47_
  - [x] 15.2 Implement mobile reports and exact KPI-to-filter navigation
    - Add bounded tenant/permission-scoped views for IMEI history, brand/model sales, unit margin, repair revenue/status, exchange margin, warranty, used-stock aging, demo, return, sync, and reconciliation exceptions.
    - _Requirements: 9.7–9.9, 9.12–9.13_
  - [x] 15.3 Align catalogue, accessory, accounting, tax, audit, backup, and compliance labels with behavior
    - Add mobile model attributes and handset/accessory relationships without changing other catalogues; route available generic labels only to matching functionality and hide unsupported capability surfaces.
    - _Requirements: 4.8, 9.10–9.11, 10.10–10.12_
  - [x] 15.4 Add dashboard, report, and catalogue tests
    - Verify no fabricated count before confirmed data, stale/unavailable/error semantics, exact card filters, tenant-bound source calls, report pagination, accessory line separation, matching labels, and non-mobile catalogue preservation.
    - _Requirements: 1.6, 9.1–9.13, 13.1, 13.7_

- [x] 16. Standardize responsive, accessible, and performant mobile UX
  - [x] 16.1 Apply shared themes, responsive layouts, semantics, and keyboard behavior
    - Update service, exchange, warranty, history, second-hand, scanner, status, and icon controls for supported viewports, theme tokens, WCAG AA contrast, 48x48 targets, names/roles/states, visible focus, and non-color status.
    - _Requirements: 11.1–11.8, 11.12_
  - [x] 16.2 Implement bounded, debounced, latest-query-wins list behavior
    - Move service/exchange/search/report filtering to reusable debounced controllers and bounded repositories, use stable keys/virtualization or continuation pagination, and avoid unchanged full-list rescans and subtree rebuilds.
    - _Requirements: 6.14–6.17, 11.9–11.11_
  - [x] 16.3 Centralize visible operation states and recovery actions
    - Render distinct loading, empty, disabled, pending, stale, conflicted, unavailable, failed, complete, and signed-out states; announce progress and expose typed correlation/retry guidance without false success.
    - _Requirements: 7.14, 9.1–9.6, 11.7–11.8, 12.4–12.10; GR-3_
  - [x] 16.4 Add responsive, accessibility, and performance widget tests
    - Exercise phone/tablet/desktop and light/dark themes, semantics/focus/busy states, status-card interaction, debounce cancellation, stable pagination, and rebuild bounds.
    - _Requirements: 11.1–11.12, 13.1_

- [x] 17. Checkpoint — Flutter workflows and integration complete
  - Ensure all tests pass, ask the user if questions arise.
- [ ] 18. Add layered regression and end-to-end verification
  - [-] 18.1 Complete canonical backend verification suites
    - Add unit, API-contract, local-DynamoDB, concurrency, authorization, pagination, migration, throttling, reconciliation, audit-immutability, IAM-template, telemetry, and packaging tests for all MobileShop endpoints and access patterns.
    - _Requirements: 13.1–13.6_
  - [-] 18.2 Complete Flutter verification suites
    - Add dedicated unit, widget, repository, routing, permission, Drift, sync, API-contract, and generated-schema tests for mobileShop, including every audit regression lock that current evidence shows is already corrected.
    - _Requirements: 1.3–1.4, 13.1–13.5_
  - [-] 18.3 Add automated end-to-end mobileShop scenarios
    - Exercise authenticated sale, duplicate conflict, offline queue/reconnect, tenant switch, service/exchange/warranty/intake, dashboard/report filters, provider pending behavior, and denied cross-tenant/direct-route access against the canonical backend test stack.
    - _Requirements: 2.9, 3.1–3.11, 4.1–4.9, 5.1–5.11, 7.1–7.15, 8.3–8.7, 13.1_
  - [-] 18.4 Add non-mobile preservation suites for every changed shared abstraction
    - Snapshot and behavior-test affected navigation, capability, permission, billing, database, synchronization, dashboard, catalogue, and backend paths for representative non-mobile business types without changing their expected behavior.
    - _Requirements: 1.5–1.6, 13.7; GR-1.1_

- [ ] 19. Automate production validation, traceability, and completion gates
  - [ ] 19.1 Implement reproducible frontend and backend validation runners
    - Add non-watch scripts/CI jobs for formatting, generated code, targeted/full analysis, lint, type checking, targeted/relevant/full tests, security checks, migration checks, backend packaging, and supported Flutter release builds; capture command, environment, configuration, result, and artifact reference.
    - _Requirements: 13.3–13.6, 13.8–13.10_
  - [ ] 19.2 Implement traceability evidence collection
    - Update the machine-readable matrix from AF-01–AF-53 and any `MSR-###` records to requirement clauses, design components, leaf tasks, changed files, test IDs, validation artifacts, deferral approvals, risks, controls, and follow-ups.
    - _Requirements: 1.1–1.7, 14.1–14.3, 14.8_
  - [ ] 19.3 Implement the executable completion gate
    - Fail when any critical/high finding is unresolved, a lower finding lacks correction/acceptance/follow-up, route/capability/permission/API/sync/datastore contracts disagree, a required cloud contract or confirmation is absent, offline work is lost, fabricated/cross-tenant data appears, or traceability is incomplete.
    - _Requirements: 14.4–14.8_
  - [ ] 19.4 Add completion-gate tests
    - Provide passing fixtures plus counterexamples for missing audit IDs, duplicate disposition, unresolved severity, absent evidence, unreachable feature, cross-tenant disclosure, fabricated KPI, lost outbox mutation, missing confirmation, and inconsistent contracts.
    - _Requirements: 14.1–14.8_

- [ ] 20. Final checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional test sub-tasks and can be skipped for a faster MVP; core implementation tasks are never optional.
- The design uses Dart for Flutter contracts and TypeScript for canonical backend contracts, so no implementation-language choice is pending.
- `design.md` currently has no `Correctness Properties` section. Per the feature workflow, this plan does not invent property-based test tasks; it uses example, edge-case, concurrency, contract, integration, migration, and end-to-end tests. If numbered design properties are added later, add one optional property-test sub-task per property with 100+ generated cases and explicit requirement mapping.
- Existing corrected router/sidebar/IMEI/warranty behavior must be protected with regression locks rather than rewritten speculatively. Production changes should be made only where current tests/evidence show a gap.
- External provider selection, jurisdiction-specific second-hand controls, final role mapping, and entity conflict policies remain configurable ports/policies. Tasks must not fabricate provider success or weaken financial/IMEI conflict handling while those decisions remain pending.
- The dependency graph is intentionally conservative: each wave starts only after every earlier wave completes, tests follow the code they verify, and broad shared-file changes are separated to reduce merge conflicts.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2"] },
    { "id": 2, "tasks": ["1.3"] },
    { "id": 3, "tasks": ["1.4", "2.1", "3.2"] },
    { "id": 4, "tasks": ["2.2", "3.1", "3.3", "5.1", "5.2", "5.3", "10.1"] },
    { "id": 5, "tasks": ["2.3", "3.4", "4.1", "10.2", "10.3", "13.1"] },
    { "id": 6, "tasks": ["2.4", "3.5", "4.2", "5.4", "10.4", "13.2"] },
    { "id": 7, "tasks": ["4.3", "13.3", "13.4"] },
    { "id": 8, "tasks": ["4.4", "13.5"] },
    { "id": 9, "tasks": ["4.5", "6.1", "7.1", "7.2", "7.3", "7.4", "8.3", "8.5", "11.1"] },
    { "id": 10, "tasks": ["6.2", "7.5", "8.2", "11.2"] },
    { "id": 11, "tasks": ["6.3", "8.1"] },
    { "id": 12, "tasks": ["6.4", "8.4", "11.3", "11.4"] },
    { "id": 13, "tasks": ["8.6", "11.5", "12.1"] },
    { "id": 14, "tasks": ["12.2"] },
    { "id": 15, "tasks": ["12.3"] },
    { "id": 16, "tasks": ["12.4", "14.1", "14.2", "14.3", "15.1", "15.2", "15.3"] },
    { "id": 17, "tasks": ["14.4", "15.4", "16.1", "16.2", "16.3"] },
    { "id": 18, "tasks": ["16.4"] },
    { "id": 19, "tasks": ["18.1", "18.2", "18.3", "18.4"] },
    { "id": 20, "tasks": ["19.1"] },
    { "id": 21, "tasks": ["19.2"] },
    { "id": 22, "tasks": ["19.3"] },
    { "id": 23, "tasks": ["19.4"] }
  ]
}
```
 