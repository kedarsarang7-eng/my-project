# Requirements Document

## Introduction

This specification defines complete remediation of only the `mobileShop` business type in Dukan_x. The specification consolidates the approved audit review and completed requirement detailing for `audit-reports/business-types/audit-mobileShop.md`. Existing corrected behavior is protected by regression requirements; remaining local/cloud consistency, backend, synchronization, authorization, workflow, UX, and verification gaps require production implementation.

The remediation SHALL preserve every other business type. `Dukan_x/my-backend` is the sole Canonical_Backend, and AWS DynamoDB is the sole Canonical_Datastore for authoritative MobileShop_Domain data. This requirements workflow changes no application code.

## Glossary

- **MobileShop_System**: The end-to-end Flutter, local database, API, backend, datastore, and synchronization behavior enabled only for `BusinessType.mobileShop`.
- **MobileShop_Tenant**: An authenticated tenant whose canonical active business type is `mobileShop`.
- **Non_MobileShop_Tenant**: An authenticated tenant whose active business type is not `mobileShop`.
- **Remediation_Ledger**: A version-controlled artifact mapping every Audit_Finding to current evidence, root cause, dependencies, remediation status, and verifying evidence.
- **Audit_Finding**: An issue, uncertainty, benchmark gap, or protection target in `audit-mobileShop.md`, identified by AF-01 through AF-53.
- **Root_Cause_Closure**: Correction of the earliest faulty contract or dependency plus verification of every affected consumer.
- **Canonical_Backend**: The sole operational backend at `Dukan_x/my-backend` that owns MobileShop_Domain APIs.
- **Canonical_Datastore**: AWS DynamoDB, the sole authoritative backend datastore for MobileShop_Domain data.
- **MobileShop_Domain**: IMEI units, device inventory, service jobs, exchanges, warranties, second-hand intake, device returns, reservations, finance plans, and related audit events.
- **IMEI_Unit**: A tenant-scoped device unit identified by a normalized 15-digit Luhn-valid IMEI and a lifecycle state.
- **Device_Lifecycle**: The approved transitions among in-stock, reserved, sold, returned, demo, in-service, exchanged, damaged, and retired states.
- **Consistency_Orchestrator**: The component that provides atomic completion or durable reconciliation for invoice and IMEI lifecycle mutations.
- **Reconciliation_Record**: A durable record of incomplete side effects, attempts, latest outcome, and required recovery action for one logical mutation.
- **Sync_Engine**: The idempotent push, pull, and real-time reconciliation path between Drift and the Canonical_Backend.
- **Operation_Id**: A tenant-scoped idempotency key generated once per logical mutation and reused for every retry.
- **Mutation_Fingerprint**: A deterministic digest of the operation type and normalized immutable request fields associated with an Operation_Id.
- **Deterministic_Outcome**: A documented outcome category, code, field association, and state effect selected from the normalized request and authoritative preconditions so that the same request and preconditions produce the same result.
- **Authoritative_Confirmation**: Evidence returned by the Canonical_Backend only after AWS DynamoDB confirms either the authoritative transaction or write, or the durable idempotency and Reconciliation_Record writes that define an accepted pending state.
- **Immutable_Audit_Event**: A tenant-scoped append-only event that application workload identities may create and read but may not update or delete; a correction is represented by a new linked event.
- **Provider_Request_Id**: A stable external-provider request identity derived from one logical provider submission and reused across safe retries.
- **Conditional_Write**: A Canonical_Datastore mutation that succeeds only when stated tenant, uniqueness, lifecycle, idempotency, and version conditions hold.
- **Continuation_Token**: An opaque, integrity-protected, tenant-bound value identifying the next page for one query shape and continuation position.
- **Tenant_Bound_Access_Path**: A primary-key or defined secondary-index access path whose key conditions include the authenticated tenant identity.
- **Data_Model_Version**: A persisted version used to interpret and migrate a Canonical_Datastore record or queued mutation.
- **Conflict_Record**: A durable record of a rejected or concurrent mutation with local version, server version, reason, resolution state, and resolution evidence.
- **Tenant_Context**: The authoritative owner identifier and canonical business type resolved from SessionManager/OwnerIdResolver and propagated through every boundary.
- **MobileShop_Permission**: A least-privilege permission dedicated to mobile operations, including view/manage variants for service, IMEI, exchange, warranty, second-hand, finance, reports, and settings.
- **Live_KPI**: A dashboard value derived from reconciled data with explicit loading, current, stale, unavailable, empty, and error states.
- **Offline_Write**: A locally accepted mutation stored in a durable queue for later Sync_Engine delivery.
- **Regression_Lock**: An automated test that preserves behavior already corrected since the audit.
- **Traceability_Matrix**: The mapping from every Audit_Finding to requirements, design, tasks, changed files, and passing evidence.
- **Supported_Viewport**: Phone, tablet, and desktop width classes defined by the existing responsive framework.
- **Accessible_Control**: A control with a semantic name, role, value/state, keyboard and focus behavior, target size, and theme-compliant contrast.
- **Documented_Configuration**: Approved, version-controlled configuration that defines validation precedence; operational bounds for input size, value ranges, precision, query and page size, debounce behavior, and transaction-fit decisions; retention and expiry; retry, backoff, and throttling budgets; offline eligibility; feature policy; and supported model-version, migration, and backfill policy without embedding unapproved numeric literals in requirements.
- **Completion_Evidence**: Reproducible commands, test identifiers, results, artifacts, and environment metadata proving a completion criterion.
- **Production_Validation**: Formatting, generated-code, analysis, test, build, security, migration, and preservation checks required for release.
## Audit Finding Catalog

| IDs | Findings captured from the audit and current re-verification |
|---|---|
| AF-01–AF-04 | Generic or irrelevant sidebar, missing mobile tools, configuration/capability mismatch, and obsolete parallel-router/module architecture |
| AF-05–AF-09 | Partial billing, non-unit inventory, dead scan/POS action, missing credit/EMI behavior, and no IMEI-specific reservation/order flow |
| AF-10–AF-18 | OCR contradiction, missing mobile reports, weak RBAC/audit semantics, tenant identity inconsistency, unverified backup encryption, generic catalogue, missing e-Way support, missing loyalty/bundles, and unverified offline sync |
| AF-19–AF-21 | Unwired IMEI validation, non-required UI entry, and unreachable duplicate-sale prevention |
| AF-22–AF-32 | Missing used-stock workflow, exchange/repair discoverability, blocked warranty/history, missing EMI, generic accessories, missing SIM/recharge, price protection, IMEI-aware returns, and demo-unit state |
| AF-33–AF-37 | Hardcoded or missing KPIs, guard bypass, dead business-type string branch, absent backend reconciliation, and divergent identity sources |
| AF-38–AF-47 | Responsive/theming inconsistency, inefficient filtering, unsuitable permissions, missing data-layer capability enforcement, weak IMEI checks, warranty date/range errors, accessibility gaps, null-session spinner, and dead status-card action |
| AF-48–AF-53 | Non-mobile placeholder/remap surfaces, non-atomic invoice/IMEI completion, fragmented backend ownership, absent cloud domain contracts, business-type value mismatch, and missing dedicated test coverage |

## Requirements

### Requirement 1: Scope, evidence, and root-cause closure

**User Story:** As a maintainer, I want every audit claim re-verified and every dependency inspected, so that remediation closes current root causes rather than stale symptoms.

#### Acceptance Criteria

1. WHEN a production component is selected for remediation, THE Remediation_Ledger SHALL record the applicable Audit_Finding, current evidence, status, root cause, dependency chain, planned change, and intended verification before the change begins.
2. WHEN investigation identifies an undocumented defect in the same dependency chain, THE Remediation_Ledger SHALL assign the defect an identifier and the same evidence and quality gates as an Audit_Finding.
3. IF current evidence proves an Audit_Finding is already corrected, THEN THE MobileShop_System SHALL preserve the corrected behavior with a Regression_Lock instead of a speculative production change.
4. IF current evidence proves an Audit_Finding is superseded by removed or replaced architecture, THEN THE Remediation_Ledger SHALL identify the authoritative replacement and a test that prevents the superseded path from becoming authoritative.
5. THE MobileShop_System SHALL limit behavior changes to MobileShop_Tenant paths and shared abstractions required for tenant isolation.
6. WHEN remediation changes a shared abstraction, THE MobileShop_System SHALL preserve observable Non_MobileShop_Tenant behavior with automated preservation tests.
7. THE Remediation_Ledger SHALL map every identifier from AF-01 through AF-53 without a gap or duplicate disposition.

### Requirement 2: Reachability and current-fix regression locks

**User Story:** As a mobile-shop merchant, I want every device workflow discoverable and functional, so that shared changes cannot return the vertical to a generic retail experience.

#### Acceptance Criteria

1. WHILE a MobileShop_Tenant is active, THE MobileShop_System SHALL expose dedicated entries for service jobs, exchanges, IMEI tracking, warranty, and second-hand intake under matching capability and permission gates.
2. WHILE a MobileShop_Tenant is active, THE MobileShop_System SHALL exclude generic retail entries whose required capability is absent.
3. WHEN a dedicated mobileShop entry is activated, THE MobileShop_System SHALL open the guarded production screen represented by the entry without a placeholder, no-op, redirect loop, or business-type denial.
4. WHEN the IMEI Lookup quick action is activated, THE MobileShop_System SHALL open tenant-scoped IMEI and serial history.
5. WHEN a mobileShop bill editor displays an IMEI field, THE MobileShop_System SHALL identify the field as required and return a field error for an empty value.
6. WHEN the MobileShop_System constructs BillsRepository, THE MobileShop_System SHALL provide the authoritative non-null IMEI validation dependency.
7. WHEN the MobileShop_System renders service dashboard metrics, THE MobileShop_System SHALL derive every displayed value from a live repository or provider contract.
8. THE MobileShop_System SHALL use the authoritative `MaterialApp.router` route composition and keep removed parallel mobile module/router code absent.
9. WHEN an automated reachability test activates each mobileShop sidebar item and quick action, THE MobileShop_System SHALL render the expected guarded destination without an uncaught exception.
### Requirement 3: IMEI and invoice consistency

**User Story:** As a mobile-shop merchant, I want each device sale and IMEI change to complete consistently, so that duplicate sales and silent history loss cannot occur.

#### Acceptance Criteria

1. WHEN a MobileShop_Tenant submits a device sale, THE MobileShop_System SHALL validate IMEI presence, normalization, 15-digit length, Luhn checksum, tenant-scoped uniqueness, saleable lifecycle state, and bill-item association before acceptance.
2. IF a submitted IMEI fails one or more validation rules, THEN THE MobileShop_System SHALL return the Deterministic_Outcome selected by the documented validation precedence, associate every reported field code with the applicable input, and preserve the complete pre-operation invoice and IMEI states.
3. WHEN a valid device sale commits atomically, THE Consistency_Orchestrator SHALL persist the invoice, item-to-IMEI associations, sold state, customer association, sale timestamp, warranty dates, idempotency outcome, and Immutable_Audit_Event in one DynamoDB transaction and obtain Authoritative_Confirmation before reporting the sale as committed.
4. IF one atomic transaction cannot contain every sale effect, THEN THE Consistency_Orchestrator SHALL obtain Authoritative_Confirmation that the accepted sale state, idempotency outcome, and Reconciliation_Record are durable before reporting acceptance.
5. WHILE a Reconciliation_Record remains unresolved, THE MobileShop_System SHALL identify the sale as pending or failed reconciliation and reserve each associated IMEI from another sale.
6. WHEN Authoritative_Confirmation proves that reconciliation completed every recorded effect, THE Consistency_Orchestrator SHALL mark the Reconciliation_Record complete and expose the sale as server-confirmed.
7. WHEN a retry presents the original Operation_Id and matching Mutation_Fingerprint, THE Canonical_Backend SHALL return the recorded outcome without creating another invoice, IMEI event, warranty record, or audit event.
8. IF a retry presents an existing Operation_Id with a different Mutation_Fingerprint, THEN THE Canonical_Backend SHALL return an idempotency-mismatch conflict and leave domain and idempotency records unchanged.
9. IF concurrent requests attempt to claim the same tenant-scoped IMEI, THEN THE Canonical_Backend SHALL accept at most one request and return a deterministic conflict for each rejected request.
10. WHEN an invoice is cancelled, THE MobileShop_System SHALL apply the documented Device_Lifecycle transition to every associated IMEI and append an immutable audit event.
11. WHEN a device return is accepted, THE MobileShop_System SHALL apply the documented Device_Lifecycle transition to the returned IMEI and append an immutable audit event.
12. THE MobileShop_System SHALL use one authoritative IMEI validation path for UI, repository, synchronization, and backend sale enforcement.

### Requirement 4: Device inventory and lifecycle workflows

**User Story:** As a mobile-shop merchant, I want unit-level inventory for new, used, demo, reserved, returned, and damaged devices, so that stock reflects each physical handset.

#### Acceptance Criteria

1. THE MobileShop_System SHALL represent each handset as an IMEI_Unit with condition, ownership source, valuation, acquisition cost, sale price, warranty, and Device_Lifecycle state.
2. WHEN a second-hand device is submitted for intake, THE MobileShop_System SHALL validate normalized IMEI, seller identity reference, ownership-evidence status, inspection result, valuation approval, and exchange linkage before acceptance.
3. WHEN a valid second-hand intake is accepted, THE MobileShop_System SHALL create one tenant-scoped IMEI_Unit and one immutable intake audit event.
4. IF a second-hand IMEI is invalid, prohibited by documented policy, duplicate, or active in an incompatible lifecycle state, THEN THE MobileShop_System SHALL return a deterministic intake error and leave inventory unchanged.
5. WHEN an authorized user assigns a device as a demo unit, THE MobileShop_System SHALL transition the IMEI_Unit to demo state and exclude the unit from saleable quantity.
6. WHEN a device is reserved or booked, THE MobileShop_System SHALL bind the reservation to one IMEI_Unit through a Conditional_Write that rejects conflicting sale or reservation claims.
7. WHEN an IMEI-aware return is submitted, THE MobileShop_System SHALL validate the originating sale, return eligibility, physical IMEI match, condition, disposition, and target lifecycle state before acceptance.
8. WHEN an accessory is attached to a handset sale, THE MobileShop_System SHALL preserve separate stock and tax lines plus the handset-accessory relationship for bundle reporting.
9. THE MobileShop_System SHALL provide inventory views and reports that distinguish new, second-hand, demo, reserved, sold, returned, in-service, exchanged, damaged, and retired units.
### Requirement 5: Repair, exchange, warranty, and service lifecycle

**User Story:** As a mobile-shop merchant, I want connected repair, exchange, and warranty workflows, so that device history is complete and operationally usable.

#### Acceptance Criteria

1. WHEN a service job is submitted, THE MobileShop_System SHALL validate a tenant-owned IMEI_Unit, customer, fault, estimate, technician, warranty status, timestamps, and initial status before creation.
2. WHEN a service-job status change satisfies the expected version and an allowed transition, THE MobileShop_System SHALL append an audit event and update the associated IMEI_Unit state atomically or through a Reconciliation_Record.
3. IF a service-job status change fails the expected-version or transition condition, THEN THE MobileShop_System SHALL return a deterministic conflict and preserve the current service job and IMEI_Unit states.
4. WHEN an exchange is accepted, THE MobileShop_System SHALL preserve old-device valuation, new-device IMEI, financial adjustment, approval, and both lifecycle transitions as one atomic or durably reconciled operation.
5. WHEN a warranty is registered or claimed, THE MobileShop_System SHALL associate the sale, IMEI_Unit, warranty period, provider, claim status, evidence, and resolution.
6. IF warranty-month input is outside the range in Documented_Configuration, THEN THE MobileShop_System SHALL return a field error and preserve valid sibling input.
7. WHEN warranty dates are calculated from a month-end sale date, THE MobileShop_System SHALL use the final valid day of the target month.
8. WHEN a MobileShop_Tenant opens service, exchange, warranty, history, or job detail through any navigation path, THE MobileShop_System SHALL enforce the same business, capability, tenant, and permission policy.
9. IF Tenant_Context cannot be resolved, THEN THE MobileShop_System SHALL render an actionable signed-out or session-error state and perform no domain read or write.
10. WHEN a status summary card is interactive, THE MobileShop_System SHALL apply the represented tenant-scoped list filter.
11. WHEN a status summary card has no action, THE MobileShop_System SHALL expose a non-interactive semantic state.

### Requirement 6: Canonical backend, DynamoDB datastore, and API contracts

**User Story:** As a system operator, I want one authoritative backend contract and DynamoDB datastore, so that local correctness extends across devices and sessions.

#### Acceptance Criteria

1. THE Canonical_Backend SHALL be `Dukan_x/my-backend` and use the Canonical_Datastore as the sole authoritative persistence system for MobileShop_Domain data.
2. THE MobileShop_System SHALL maintain one documented Canonical_Backend deployment path, ownership boundary, and versioned data-migration strategy.
3. THE Canonical_Backend SHALL expose versioned tenant-scoped APIs for IMEI units, invoice associations, service jobs, exchanges, warranties, second-hand intake, returns, reservations, finance plans, and audit events.
4. WHEN the Canonical_Backend receives a MobileShop_Domain mutation, THE Canonical_Backend SHALL validate authentication, canonical business type, MobileShop_Permission, tenant ownership, input schema, Operation_Id, Mutation_Fingerprint, entity version, and lifecycle preconditions before persistence.
5. IF authentication, business type, permission, or Tenant_Context validation fails, THEN THE Canonical_Backend SHALL return a non-disclosing authorization Deterministic_Outcome before issuing a MobileShop_Domain datastore request and return no domain record, identifier, count, metadata, continuation position, or entity-existence signal.
6. WHEN the Canonical_Backend reads or writes MobileShop_Domain data, THE Canonical_Backend SHALL use a Tenant_Bound_Access_Path whose DynamoDB partition-key condition contains the authenticated tenant identity and verify that every returned, condition-checked, or mutated record contains the same tenant identity.
7. WHEN a mutation depends on version, lifecycle state, uniqueness, prior absence, or idempotency state, THE Canonical_Backend SHALL enforce the dependency with a Conditional_Write.
8. IF a Conditional_Write condition fails, THEN THE Canonical_Backend SHALL return the documented Deterministic_Outcome and preserve every authoritative record exactly as stored before the attempted mutation.
9. WHEN a MobileShop_Domain operation requires multiple records to succeed together, THE Canonical_Backend SHALL commit the records in one Canonical_Datastore transaction or durably persist the accepted state, idempotency outcome, and Reconciliation_Record and obtain Authoritative_Confirmation before reporting acceptance.
10. WHEN a mutation first presents an Operation_Id, THE Canonical_Backend SHALL atomically persist the Operation_Id, Mutation_Fingerprint, and outcome with the domain transaction or durable reconciliation acceptance.
11. WHEN a mutation repeats an Operation_Id with the recorded Mutation_Fingerprint, THE Canonical_Backend SHALL return the recorded status and response without duplicating a domain record or audit event.
12. IF a mutation repeats an Operation_Id with a different Mutation_Fingerprint, THEN THE Canonical_Backend SHALL return an idempotency-mismatch conflict and leave all records unchanged.
13. IF concurrent mutations claim the same normalized IMEI or Operation_Id within one tenant, THEN THE Canonical_Backend SHALL accept at most one claim and return the recorded idempotent outcome or deterministic conflict for each other claim.
14. WHEN a supported list, lookup, dashboard, report, or synchronization query executes, THE Canonical_Backend SHALL use a bounded Tenant_Bound_Access_Path backed by a DynamoDB primary key or a documented DynamoDB global secondary index.
15. WHEN a query returns the page size defined by Documented_Configuration and more results exist, THE Canonical_Backend SHALL return an opaque Continuation_Token bound to tenant, query shape, access path, and continuation position.
16. WHEN a valid Continuation_Token is presented with the bound tenant and query shape, THE Canonical_Backend SHALL resume the same bounded access path after the recorded continuation position.
17. IF a Continuation_Token is invalid, altered, expired under Documented_Configuration, or used with a different tenant or query shape, THEN THE Canonical_Backend SHALL return a deterministic pagination error without returning domain records.
18. WHEN the Flutter client sends `mobileShop`, `mobileshop`, or legacy `mobile_shop`, THE MobileShop_System SHALL normalize the value to one canonical wire and persisted value.
19. IF a request references an entity owned by another tenant, THEN THE Canonical_Backend SHALL return the non-disclosing authorization or not-found Deterministic_Outcome selected by Documented_Configuration, return no domain record, identifier, count, metadata, continuation position, or entity-existence signal from the other tenant, and preserve every authoritative record unchanged.
20. WHEN a Canonical_Datastore record or API schema changes, THE Canonical_Backend SHALL assign a Data_Model_Version and provide an explicit compatibility, migration, or backfill path for stored data, queued mutations, and older supported clients.
21. WHEN a migration or backfill is retried, THE Canonical_Backend SHALL produce the same migrated state without duplicate domain records or audit events.
22. WHEN migration and preservation evidence proves a non-authoritative mobile-domain implementation is unused, THE MobileShop_System SHALL remove the duplicate implementation from non-authoritative backend roots.
23. WHEN the Canonical_Backend performs a Canonical_Datastore operation, THE Canonical_Backend SHALL emit secret-free structured observability data containing correlation id, tenant id, Operation_Id, entity type, result, retry status, latency, capacity or throttling outcome, conditional outcome, and transaction or reconciliation outcome where applicable.
24. THE MobileShop_System SHALL treat Drift, exports, read projections, and backend roots other than the Canonical_Backend as non-authoritative copies of MobileShop_Domain data.
25. WHEN the Canonical_Backend creates a MobileShop_Domain record or access path, THE Canonical_Backend SHALL use a DynamoDB partition-key value that includes the authenticated tenant identity.
26. WHEN MobileShop_Domain uniqueness is required, THE Canonical_Backend SHALL create a tenant-scoped claim record for the normalized unique value through a Conditional_Write in the same transaction as the accepted domain mutation.
27. WHEN the Canonical_Backend accepts a new Operation_Id, THE Canonical_Backend SHALL create a tenant-scoped idempotency record containing the Mutation_Fingerprint, operation status, response reference, retention expiry, and Data_Model_Version.
28. WHEN an access pattern cannot use the DynamoDB primary key, THE Canonical_Backend SHALL use a documented DynamoDB global secondary index whose partition-key value includes the authenticated tenant identity.
29. WHEN the Canonical_Backend executes a list, lookup, dashboard, report, or synchronization query, THE Canonical_Backend SHALL apply the request limit defined by Documented_Configuration to the DynamoDB primary-key or global-secondary-index query.
30. IF a requested access pattern lacks a tenant-bound DynamoDB primary-key or global-secondary-index key condition, THEN THE Canonical_Backend SHALL return a deterministic unsupported-query outcome before issuing the datastore request.
31. WHEN an accepted operation mutates multiple MobileShop_Domain records, THE Canonical_Backend SHALL include the domain records, uniqueness claims, idempotency record, and Immutable_Audit_Event in one DynamoDB transaction when the operation fits documented DynamoDB transaction limits.
32. IF an accepted operation exceeds documented DynamoDB transaction limits, THEN THE Canonical_Backend SHALL durably persist the accepted state, idempotency outcome, and Reconciliation_Record and obtain Authoritative_Confirmation before reporting acceptance.
33. THE Canonical_Backend SHALL persist a Data_Model_Version on every authoritative MobileShop_Domain record, uniqueness claim, idempotency record, Immutable_Audit_Event, and Reconciliation_Record.
34. WHEN the Canonical_Backend reads a supported earlier Data_Model_Version, THE Canonical_Backend SHALL apply the documented compatible interpretation or deterministic upgrade path before returning or mutating the record.
35. WHEN a migration or backfill processes Canonical_Datastore records, THE Canonical_Backend SHALL use bounded pages, durable checkpoints, and Conditional_Writes that preserve records already migrated or changed by a newer operation.
36. WHEN a migration or backfill resumes from a durable checkpoint, THE Canonical_Backend SHALL continue after the last confirmed position and preserve the same result as one uninterrupted execution.
37. WHEN the Canonical_Backend receives DynamoDB consumed-capacity or throttling metadata, THE Canonical_Backend SHALL emit secret-free structured fields for table or index identity, operation type, consumed capacity, throttling reason, retry count, and backoff duration.
38. IF a DynamoDB operation remains throttled after the retry budget in Documented_Configuration, THEN THE Canonical_Backend SHALL return a typed rate-limited or pending-reconciliation outcome that preserves idempotency and authoritative state.
39. THE Canonical_Backend SHALL access the Canonical_Datastore through approved workload identities restricted to the required DynamoDB actions, tables, indexes, and deployment environment.
40. WHERE migration, backfill, backup, or restore access is enabled, THE Canonical_Datastore SHALL use a separate approved identity restricted to the actions and resources required for that operation.
41. THE MobileShop_System SHALL authorize authoritative MobileShop_Domain access through Canonical_Backend APIs without distributing Canonical_Datastore credentials to Flutter clients.
42. WHEN the Canonical_Backend represents a mutation as committed, accepted-pending, current, or server-confirmed, THE Canonical_Backend SHALL include Authoritative_Confirmation for the corresponding DynamoDB transaction, write, or durable reconciliation acceptance.

### Requirement 7: Offline-first synchronization and real-time reconciliation

**User Story:** As a mobile-shop merchant, I want safe offline work and deterministic synchronization, so that connectivity changes do not lose or duplicate device operations.

#### Acceptance Criteria

1. WHILE connectivity is unavailable, THE MobileShop_System SHALL read MobileShop_Domain data from tenant-scoped Drift tables and identify stale or pending data visibly.
2. WHERE Documented_Configuration permits an operation offline, WHEN a MobileShop_Tenant submits the operation without connectivity, THE MobileShop_System SHALL durably queue the mutation, Operation_Id, Mutation_Fingerprint, base version, dependency identifiers, and retry metadata before reporting local acceptance.
3. WHERE an operation requires online authorization or external verification, WHEN the operation is attempted without connectivity, THE MobileShop_System SHALL return a specific connectivity requirement and preserve entered data.
4. WHEN connectivity returns, THE Sync_Engine SHALL push queued mutations in dependency order, pull server changes from the recorded cursor, and update Drift through a recoverable synchronization cycle.
5. WHEN the Sync_Engine retries a queued mutation, THE Sync_Engine SHALL reuse the original Operation_Id and Mutation_Fingerprint.
6. IF a queued Operation_Id is associated with a different Mutation_Fingerprint, THEN THE Sync_Engine SHALL create a Conflict_Record and prevent submission of the mismatched mutation.
7. IF local and server versions conflict, THEN THE Sync_Engine SHALL apply the documented entity-specific conflict policy or create a Conflict_Record requiring explicit resolution.
8. WHILE a Conflict_Record is unresolved, THE Sync_Engine SHALL retain the local version, server version, reason, attempted operation, and resolution state without discarding either version.
9. WHEN a conflict is resolved, THE Sync_Engine SHALL retain immutable resolution evidence for the retention period in Documented_Configuration.
10. WHEN a server or websocket event is duplicated or arrives out of order, THE Sync_Engine SHALL apply the logical event at most once and prevent state-version regression.
11. WHEN the active MobileShop_Tenant changes, THE Sync_Engine SHALL stop prior-tenant subscriptions, revoke prior-tenant continuation and synchronization cursors from the active session, and clear in-memory prior-tenant state before loading the new tenant.
12. WHILE a new MobileShop_Tenant session is active, THE Sync_Engine SHALL exclude every prior-tenant row, event, count, identifier, token, queued mutation, conflict, and subscription update from reads, writes, synchronization, and presentation.
13. THE Sync_Engine SHALL synchronize IMEI units, invoice associations, service jobs, exchanges, warranties, second-hand records, returns, reservations, and finance records.
14. IF synchronization fails, THEN THE MobileShop_System SHALL retain queued work, expose the retry and conflict Deterministic_Outcome, and identify unsynchronized data as not server-confirmed.
15. WHEN the Sync_Engine receives Authoritative_Confirmation for a queued mutation or pulled version, THE Sync_Engine SHALL mark only the confirmed tenant-scoped records and versions as server-confirmed.
### Requirement 8: RBAC, capability isolation, and security

**User Story:** As an administrator, I want least-privilege permissions enforced everywhere, so that users access only authorized tenant data and operations.

#### Acceptance Criteria

1. THE MobileShop_System SHALL define MobileShop_Permission constants and role mappings that separate viewing and managing service, IMEI, exchange, warranty, second-hand, finance, reports, and settings operations.
2. WHEN an existing role is migrated to MobileShop_Permission values, THE MobileShop_System SHALL preserve approved access through an explicit compatibility matrix.
3. WHEN a user invokes a mobileShop operation through sidebar dispatch, quick action, deep link, named route, repository, synchronization, or backend API, THE MobileShop_System SHALL enforce equivalent business-type, capability, permission, and Tenant_Context checks.
4. IF a Non_MobileShop_Tenant or mismatched tenant identity requests a MobileShop_Domain operation, THEN THE MobileShop_System SHALL return a non-disclosing Deterministic_Outcome and expose no domain record, identifier, count, metadata, cached row, event, token, continuation position, or entity-existence signal from another tenant.
5. IF a user lacks a required MobileShop_Permission, THEN THE MobileShop_System SHALL deny direct invocation before any domain read, write, or external-provider call.
6. WHILE a user lacks a required MobileShop_Permission, THE MobileShop_System SHALL hide the corresponding entry point or expose an Accessible_Control with a programmatically disabled state and no invocation path.
7. IF authorization evidence is missing, malformed, stale, or contradictory, THEN THE MobileShop_System SHALL fail closed and perform no protected operation.
8. WHEN the MobileShop_System accepts API input, THE MobileShop_System SHALL validate schema, sanitize text, apply bounds from Documented_Configuration, and use typed values.
9. WHEN the MobileShop_System performs a datastore operation, THE MobileShop_System SHALL bind Tenant_Context through a Tenant_Bound_Access_Path rather than a presentation-layer filter alone.
10. WHEN the MobileShop_System handles secrets or sensitive identifiers, THE MobileShop_System SHALL apply the project-approved storage, masking, logging, and transmission policy.
11. WHEN a sensitive read succeeds, THE MobileShop_System SHALL append an Immutable_Audit_Event before returning the protected data.
12. WHEN a lifecycle, valuation, refund, permission, reconciliation, or deletion mutation succeeds or enters accepted-pending state, THE MobileShop_System SHALL include an Immutable_Audit_Event in the same DynamoDB transaction or durable reconciliation acceptance as the audited mutation.
13. WHEN backup or export includes MobileShop_Domain data, THE MobileShop_System SHALL enforce export permission and encrypt the output through the project-approved mechanism.
14. THE Canonical_Backend SHALL restrict application workload identities for audit records to the DynamoDB actions required to append and read Immutable_Audit_Events and represent every correction as a new linked Immutable_Audit_Event.

### Requirement 9: Dashboard, reports, catalogue, and financial visibility

**User Story:** As a mobile-shop merchant, I want trustworthy operational and financial views, so that I can manage devices, repairs, exchanges, and margins.

#### Acceptance Criteria

1. WHEN a Live_KPI request has no completed source response and no previously confirmed value, THE Live_KPI SHALL render loading state without a count.
2. WHEN a Live_KPI source returns Authoritative_Confirmation and one or more matching records, THE Live_KPI SHALL render the derived value as current and identify the confirmed data version or refresh time.
3. WHEN a Live_KPI source returns Authoritative_Confirmation and no matching records, THE Live_KPI SHALL render the documented empty state and render zero only where the metric contract defines zero for a confirmed empty result.
4. WHEN a Live_KPI retains a previously confirmed value while refresh is pending or unsuccessful, THE Live_KPI SHALL render the value as stale with the last-confirmed version or time and the typed refresh status.
5. IF a Live_KPI source is unavailable and no previously confirmed value exists, THEN THE Live_KPI SHALL render unavailable state without a count.
6. IF a Live_KPI source returns a terminal typed error, THEN THE Live_KPI SHALL render error state and retain a previously confirmed value only as visibly stale data.
7. THE MobileShop_System SHALL provide Live_KPIs for repair statuses, overdue repairs, exchange pipeline quantity and value, IMEI stock by lifecycle, warranty expiries and claims, second-hand intake, unresolved conflicts, and reconciliation failures.
8. WHEN a Live_KPI is activated, THE MobileShop_System SHALL open a permission-gated tenant-scoped detail view whose filter matches the displayed metric.
9. THE MobileShop_System SHALL provide tenant-scoped reports for IMEI history, brand/model sales, unit margin, repair revenue/status, exchange margin, warranty claims, used-stock aging, demo units, returns, and synchronization or reconciliation exceptions.
10. WHEN accounting, tax, e-Way, cash/bank, receivable/payable, audit, backup, or catalogue functionality is available to a MobileShop_Tenant, THE MobileShop_System SHALL open functionality whose semantics match the selected label.
11. THE MobileShop_System SHALL support mobile-model catalogue attributes and accessory relationships without changing Non_MobileShop_Tenant catalogue behavior.
12. WHEN a report or dashboard query executes, THE MobileShop_System SHALL apply Tenant_Context and permission constraints at the data source.
13. IF a report or dashboard source fails, THEN THE MobileShop_System SHALL render the applicable stale, unavailable, or error state defined by criteria 4 through 6 and return no fabricated or cross-tenant value.
### Requirement 10: Mobile commerce capabilities

**User Story:** As a mobile-shop merchant, I want the industry capabilities identified by the audit, so that the vertical is complete rather than a generic retail subset.

#### Acceptance Criteria

1. WHERE OCR is enabled for mobileShop, THE MobileShop_System SHALL grant `useScanOCR`, apply the configured mobile OCR focus, and validate extracted model and IMEI data before acceptance.
2. WHERE product policy disables OCR for mobileShop, THE MobileShop_System SHALL remove the mobile OCR focus and every OCR entry point.
3. WHEN barcode or IMEI scanning is available, THE MobileShop_System SHALL support scan-to-lookup and scan-to-bill with duplicate-scan rejection and manual fallback.
4. THE MobileShop_System SHALL support finance and EMI plans with financier, principal, fees, installment schedule, payment status, eligibility result, consent reference, and accounting linkage.
5. THE MobileShop_System SHALL support SIM and recharge transactions with provider, masked mobile number, plan, amount, external reference, result, and Operation_Id.
6. WHEN the MobileShop_System first submits an external finance, recharge, OCR, or compliance operation, THE MobileShop_System SHALL associate the Operation_Id, Mutation_Fingerprint, and one Provider_Request_Id before transmitting the request.
7. WHEN the MobileShop_System safely retries an external-provider operation, THE MobileShop_System SHALL reuse the original Provider_Request_Id and semantically identical provider payload.
8. IF a retry would reuse a Provider_Request_Id with a different provider payload, THEN THE MobileShop_System SHALL return an idempotency-mismatch error and make no external submission.
9. IF an external provider returns an ambiguous or unavailable outcome, THEN THE MobileShop_System SHALL preserve local data, expose a pending or unavailable state, and reconcile by Provider_Request_Id before another submission.
10. THE MobileShop_System SHALL support handset/accessory bundles, configured discounts or loyalty effects, and separate inventory, tax, and accounting lines.
11. THE MobileShop_System SHALL support authorized price-protection or markdown adjustments with approval, reason, effective period, margin impact, and audit event.
12. WHERE transaction thresholds and jurisdiction rules require e-Way documentation, THE MobileShop_System SHALL use the existing compliance architecture to produce the applicable document.

### Requirement 11: Responsive, accessible, and performant UX

**User Story:** As a user on any supported device or assistive technology, I want consistent and efficient mobile-shop workflows, so that operations remain usable without ambiguity.

#### Acceptance Criteria

1. WHILE a Supported_Viewport is active, THE MobileShop_System SHALL present every mobileShop workflow without clipped primary actions, inaccessible fields, horizontal overflow, or pointer-only dependency.
2. THE MobileShop_System SHALL use shared theme tokens for color, typography, spacing, elevation, and gradients across service, exchange, warranty, history, and second-hand screens.
3. WHEN status is communicated, THE MobileShop_System SHALL provide text or semantic state in addition to color and icon.
4. WHEN a custom card, scanner, status tile, or icon control is interactive, THE MobileShop_System SHALL render an Accessible_Control.
5. WHEN keyboard navigation traverses a mobileShop workflow, THE MobileShop_System SHALL provide logical focus order and visible focus indication.
6. THE MobileShop_System SHALL meet WCAG 2.1 AA contrast for normal text and interactive states in supported light and dark themes.
7. WHEN a mobileShop surface is loading, empty, disabled, pending, stale, conflicted, unavailable, failed, or complete, THE MobileShop_System SHALL expose the matching distinct visible label and programmatic accessibility state without relying on color, icon, or position alone.
8. WHEN an asynchronous action starts, THE MobileShop_System SHALL announce progress, expose busy state, and prevent duplicate activation until the action reaches a documented terminal or retryable state.
9. WHEN a user enters service or exchange search text, THE MobileShop_System SHALL debounce filtering according to Documented_Configuration and display results only for the latest query.
10. WHEN a large mobileShop list is displayed, THE MobileShop_System SHALL use bounded queries, opaque Continuation_Token pagination or virtualization, stable keys, and Tenant_Bound_Access_Path access.
11. WHILE query, tab, and stream state remain unchanged, THE MobileShop_System SHALL avoid repeated full-list scans and unnecessary subtree rebuilds.
12. IF a control cannot perform the represented action, THEN THE MobileShop_System SHALL expose the control as programmatically disabled or render the content as non-interactive semantics, remove the activation path, and communicate the unavailable action without accepting focus activation as success.
### Requirement 12: Validation and error behavior

**User Story:** As a mobile-shop merchant, I want precise validation and recoverable errors, so that mistakes do not corrupt device or financial records.

#### Acceptance Criteria

1. WHEN user input fails one or more validation rules, THE MobileShop_System SHALL return the Deterministic_Outcome selected by the documented validation precedence, associate each reported field code and message with the applicable input, and preserve every valid sibling value.
2. WHEN user input satisfies every applicable validation rule, THE MobileShop_System SHALL clear stale validation errors and permit the next authorized workflow step.
3. IF Tenant_Context, capability, permission, or a required dependency is absent or invalid, THEN THE MobileShop_System SHALL fail closed before a domain read, write, synchronization mutation, or provider submission.
4. IF a repository, API, datastore, synchronization, or provider operation fails, THEN THE MobileShop_System SHALL return a documented Deterministic_Outcome containing the typed error category, correlation id, terminal or retryable classification, and safe recovery action.
5. IF a failed operation has no documented retry-safe classification, THEN THE MobileShop_System SHALL classify the operation as terminal until reconciliation or explicit user action establishes a safe retry.
6. WHEN warranty months, prices, valuations, quantities, discounts, finance terms, text, or pagination values are entered, THE MobileShop_System SHALL enforce the ranges, precision, and size bounds in Documented_Configuration.
7. WHEN a destructive or financially material action is requested, THE MobileShop_System SHALL present the affected device, amount, resulting lifecycle state, and required confirmation before submission.
8. IF an operation is rejected, THEN THE MobileShop_System SHALL preserve every authoritative record exactly as stored before the attempted operation and expose whether local draft data was retained.
9. IF an operation outcome lacks Authoritative_Confirmation, THEN THE MobileShop_System SHALL expose a pending reconciliation state and prevent the outcome from being represented as committed, server-confirmed, current, successful, or terminally failed.
10. IF a live dependency is unavailable, THEN THE MobileShop_System SHALL return an unavailable or pending Deterministic_Outcome instead of mock, hardcoded, unrelated, or cross-tenant data.

### Requirement 13: Automated verification and production validation

**User Story:** As a maintainer, I want layered automated verification, so that remediation quality and regressions are objectively evaluated before release.

#### Acceptance Criteria

1. THE MobileShop_System SHALL have dedicated unit, widget, repository, routing, permission, local-database, synchronization, API-contract, Canonical_Datastore integration, backend integration, and end-to-end tests for mobileShop behavior.
2. WHEN a correctness property is implemented, THE MobileShop_System SHALL execute the property test for at least 100 generated cases and associate the test with the corresponding design property.
3. WHEN local schemas or generated code change, THE MobileShop_System SHALL regenerate artifacts and verify migration from every supported prior schema version.
4. WHEN a Canonical_Datastore model, primary access path, or secondary index changes, THE Canonical_Backend SHALL produce compatibility and tenant-isolation evidence that verifies tenant-bound DynamoDB partition-key and global-secondary-index key conditions, bounded pagination, Data_Model_Version handling, idempotent migration or backfill, and rollback or forward recovery for every supported Data_Model_Version.
5. WHEN Flutter remediation is complete, THE MobileShop_System SHALL produce passing Completion_Evidence for formatter, generated-code, targeted analysis, full analysis, targeted tests, relevant suites, and supported release builds.
6. WHEN Canonical_Backend remediation is complete, THE Canonical_Backend SHALL produce passing Completion_Evidence for formatting, lint, type checking, unit tests, integration tests, API contracts, tenant-bound DynamoDB primary-key and global-secondary-index queries, cross-tenant non-disclosure, Conditional_Write pre-state preservation, transaction atomicity or durable reconciliation, Operation_Id and Mutation_Fingerprint behavior, Continuation_Token pagination, Data_Model_Version compatibility, idempotent migration or backfill, capacity and throttling outcomes, immutable audit access, least-privilege workload identities, structured observability, Authoritative_Confirmation, and production build or packaging validation.
7. WHEN shared navigation, capability, RBAC, billing, database, synchronization, or dashboard code changes, THE MobileShop_System SHALL produce passing preservation evidence for every affected Non_MobileShop_Tenant path.
8. IF required validation cannot run in the implementation environment, THEN THE Remediation_Ledger SHALL record the exact command, blocker, risk, unavailable evidence, and required owner follow-up before completion is evaluated.
9. WHEN a validation command completes, THE Completion_Evidence SHALL record command identity, environment, relevant configuration, result, and artifact or log reference.
10. THE Production_Validation SHALL contain no newly introduced analyzer error, build error, failing required test, exposed secret, hardcoded production datum, or unresolved high-severity security finding.
### Requirement 14: Final traceability and completion gate

**User Story:** As a release owner, I want objective evidence for every audit finding, so that complete remediation is reproducible and verifiable.

#### Acceptance Criteria

1. WHEN remediation completion is evaluated, THE Traceability_Matrix SHALL map AF-01 through AF-53 to requirement clauses, design components, leaf tasks, changed files, and passing Completion_Evidence.
2. IF an Audit_Finding is deferred or rejected, THEN THE Traceability_Matrix SHALL identify the approving owner, rationale, risk, compensating control, and follow-up identifier.
3. WHEN implementation identifies an additional related defect, THE Traceability_Matrix SHALL add the defect identifier and evidence before the completion gate runs.
4. WHEN the completion gate runs, THE MobileShop_System SHALL require zero unresolved critical or high-severity Audit_Findings.
5. WHEN the completion gate runs, THE MobileShop_System SHALL require each medium or low-severity Audit_Finding to be corrected, owner-accepted, or linked to a scheduled follow-up and compensating control.
6. WHEN the completion gate runs, THE MobileShop_System SHALL compare implemented capabilities, configuration, navigation, routes, permissions, API contracts, synchronization entities, DynamoDB tenant-bound access paths, Conditional_Writes, transactions or durable reconciliation, pagination, Data_Model_Versions, migrations or backfills, capacity and throttling behavior, workload identities, audit immutability, and tests for mutual consistency.
7. IF an expected feature is unreachable, unauthorized or cross-tenant access succeeds, fabricated data is displayed, a required cloud contract is absent, Authoritative_Confirmation is absent for a claimed authoritative outcome, an Offline_Write is lost, or an Audit_Finding lacks traceability, THEN THE MobileShop_System SHALL return a failed completion outcome.
8. WHEN the completion gate succeeds, THE Traceability_Matrix SHALL identify the reproducible Completion_Evidence supporting every passed gate condition.

## Cross-Cutting Ground Rules

### GR-1: Isolation

1. WHEN shared code changes, THE MobileShop_System SHALL use the smallest maintainable change that preserves Non_MobileShop_Tenant behavior.
2. THE MobileShop_System SHALL use the existing authoritative router, Sync_Engine, domain model, and Canonical_Backend rather than creating parallel implementations.

### GR-2: Data integrity and money

1. THE MobileShop_System SHALL represent monetary values in integer minor units at persistence and business-logic boundaries.
2. THE MobileShop_System SHALL associate synchronized mutations with explicit versions, timestamps, Operation_Id values, Mutation_Fingerprints, and immutable audit events.
3. WHEN a multi-record mutation cannot complete atomically, THE MobileShop_System SHALL persist a Reconciliation_Record before reporting acceptance.

### GR-3: No fabricated success

1. IF a backend endpoint or external integration is unavailable, THEN THE MobileShop_System SHALL expose a typed unavailable or pending outcome instead of success.
2. WHEN a Live_KPI has no source value, THE MobileShop_System SHALL render zero, empty, or unavailable only according to the source contract.
3. IF an operation outcome cannot be proven, THEN THE MobileShop_System SHALL retain pending or conflict state until reconciliation produces a documented terminal outcome.

### GR-4: Deterministic boundaries

1. WHEN the same validated request is evaluated against the same authoritative preconditions, THE MobileShop_System SHALL return the same success, validation, authorization, conflict, or unavailable outcome category.
2. IF a documented bound is required, THEN THE MobileShop_System SHALL obtain the bound from Documented_Configuration rather than an unapproved literal.
3. WHEN authorization, idempotency, concurrency, pagination, or provider-identity validation fails, THE MobileShop_System SHALL preserve authoritative domain state and return the documented typed outcome.
## Requirements-to-Audit Traceability

| Requirement | Audit findings |
|---|---|
| 1 | AF-01–AF-53 |
| 2 | AF-01–AF-04, AF-07, AF-19–AF-26, AF-33–AF-35, AF-48, AF-53 |
| 3 | AF-05, AF-19–AF-21, AF-35, AF-41–AF-43, AF-49, AF-51 |
| 4 | AF-06, AF-09, AF-22, AF-28, AF-30–AF-32 |
| 5 | AF-23–AF-26, AF-33–AF-37, AF-40, AF-43–AF-47 |
| 6 | AF-18, AF-36, AF-49–AF-52 |
| 7 | AF-18, AF-36–AF-37, AF-46, AF-49–AF-52 |
| 8 | AF-12–AF-14, AF-34, AF-37, AF-40–AF-41, AF-50–AF-52 |
| 9 | AF-11–AF-17, AF-28, AF-33, AF-48 |
| 10 | AF-07–AF-10, AF-15–AF-17, AF-27–AF-30 |
| 11 | AF-38–AF-39, AF-45, AF-47 |
| 12 | AF-19–AF-21, AF-37, AF-42–AF-46, AF-49 |
| 13 | AF-01–AF-53 |
| 14 | AF-01–AF-53 |

## Resolved Decisions

- **RD-1 Canonical backend datastore:** `Dukan_x/my-backend` remains the sole Canonical_Backend, and AWS DynamoDB remains the sole Canonical_Datastore for all authoritative MobileShop_Domain data.

## Unresolved Decisions

- **UD-2 Sale consistency mechanism:** The requirements mandate atomic user-visible behavior. Owners must confirm which invoice and IMEI effects fit one Canonical_Datastore transaction and which require the defined durable reconciliation path.
- **UD-3 IMEI uniqueness scope:** The requirements use tenant-scoped uniqueness. Product and security owners must confirm whether regulatory or fraud controls also require global uniqueness or a cross-tenant warning.
- **UD-4 External capabilities:** Provider choices and jurisdiction rules for EMI, SIM/recharge, OCR, and e-Way integration remain unselected; contracts remain provider-neutral until selection.
- **UD-5 Second-hand compliance:** Required seller KYC and ownership evidence, blocked-device checks, retention, and consent vary by jurisdiction and require legal and product confirmation.
- **UD-6 Role matrix:** The permission semantics are defined; administrators must approve final role mappings before migration.
- **UD-7 Conflict policy:** Automatic server-wins remains prohibited for financial and IMEI lifecycle conflicts; owners must approve the entity-specific merge or manual-resolution policies enumerated in design.md.
