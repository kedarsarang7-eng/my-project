# Implementation Plan: Offline License Activation

## Overview

This plan implements Offline_Lifetime_Mode **alongside** the untouched Cloud_Subscription_Mode. The
work is sequenced so the single mode-switch point lands first, the packaged Local_Backend and the
license/activation subsystem build on top of it, and every cloud-parity and security guarantee is
proven by a property-based test placed next to the code it validates.

Two languages are used, matching the design:
- **Dart (Flutter service layer)** for Mode_Manager, Local_Config, Backend_Supervisor,
  Fingerprint_Collector, Activation_Service, License_Validator, Offline_Gating_Engine,
  Sync_Foundation, Backup_Service, Migration_Wizard, LAN_Coordinator, Update_Service. Dart property
  tests use **`glados`** (≥100 cases each).
- **Node.js/TypeScript (`my-backend` + packaged Local_Backend)** for the RS256 signing layer,
  activation endpoint, Offline_Auth_Service, Object_Store, Local_Queue, and security middleware.
  TypeScript property tests use **`fast-check`** with Jest (≥100 runs each).

Hard constraints enforced throughout: **reuse, don't rebuild** (extend `license.service.ts`,
`license-denylist.service.ts`, `plan_mapping_builder.dart`, `app_database.dart`,
`device_fingerprint.dart`, `api_client.dart`, `license_invalid_listener.dart`), **preserve
cloud-mode behavior**, and **zero Flutter UI changes** (all switching at the service/repository
layer). Each property test is tagged `Feature: offline-license-activation, Property {n}: ...`.

## Tasks

- [x] 1. Establish the mode-switch foundation and routing
  - [x] 1.1 Implement Local_Config secure persistence
    - Create a Dart `Local_Config` over secure local storage that persists `operating_mode` plus
      runtime settings (validation interval, backup time/location, LAN role)
    - Keep it confined to the service layer; never reference it from the widget tree
    - _Requirements: 1.3_
  - [x] 1.2 Implement Mode_Manager
    - Implement `resolveActiveMode` (missing/unrecognized → default Cloud_Subscription_Mode and
      persist), `selectMode`, `activeBackendBaseUri` (AWS host vs `http://127.0.0.1:8765`), and a
      `route<T>` wrapper that yields a `RoutingFailure` naming the target when a call neither
      connects nor responds within 10s, leaving the mode unchanged
    - _Requirements: 1.1, 1.2, 1.4, 1.5, 1.8, 1.9_
  - [x] 1.3 Wire ApiClient baseUrl resolution through Mode_Manager
    - Make `lib/core/api/api_client.dart` resolve its `baseUrl` from `Mode_Manager` as the single
      switch point; preserve retry/timeout/tenant-header behavior; expose nothing to the UI
    - _Requirements: 1.4, 1.5, 1.6, 1.7_
  - [x]* 1.4 Write property test for mode persistence
    - **Property 1: Mode persistence round trip and safe default**
    - **Validates: Requirements 1.2, 1.3, 1.9**
  - [x]* 1.5 Write property test for backend target selection
    - **Property 2: Backend target is a total function of mode**
    - **Validates: Requirements 1.4, 1.5**
  - [x]* 1.6 Write property test for routing failure
    - **Property 3: Routing failure names the failed target and preserves mode**
    - **Validates: Requirements 1.8**
  - [x]* 1.7 Write unit + architecture-review tests for mode isolation
    - Assert exactly two `OperatingMode` values and add an import/dependency lint check that the
      UI layer cannot reference the active mode/target
    - _Requirements: 1.1, 1.6, 1.7_

- [x] 2. Build the Local_Backend skeleton and Backend_Supervisor lifecycle
  - [x] 2.1 Scaffold the packaged Node/Express + Socket.io backend
    - Create a packaged Express + Socket.io app bound to the Loopback_Address with a `/health`
      endpoint and route/event stubs that mirror the AWS contract shapes
    - _Requirements: 3.1, 3.2, 3.4, 4.2, 4.3_
  - [x] 2.2 Implement Backend_Supervisor
    - Implement `runStartupSequence` (license → decrypt/validate → spawn → health → connect →
      restore), `healthCheck` (8s window), `shutdown` (graceful then force after 5s), restart up to
      3 times recording each `RestartEvent`, and unrecoverable-failure reporting that marks the
      repository disconnected
    - _Requirements: 3.3, 3.5, 3.6, 3.7, 3.8, 3.9_
  - [x]* 2.3 Write unit tests for supervisor lifecycle
    - Test startup call order, graceful-then-force shutdown, restart-event recording, and
      unrecoverable failure after 3 attempts (with mocked process control)
    - _Requirements: 3.3, 3.7, 3.8, 3.9_
  - [x]* 2.4 Write integration test for contract parity and binding
    - Assert REST + Socket.io contract parity skeleton against AWS shapes and loopback-only binding
    - _Requirements: 3.2, 3.4, 17.6_

- [x] 3. Add the RS256 signing layer and activation endpoint (my-backend, additive)
  - [x] 3.1 Add the RS256 token signing layer
    - In `my-backend`, add a signing layer that wraps the **unchanged** `LicenseKeyPayload` into a
      365-day RS256 License_Token plus a 12-hour local-auth JWT helper; add no field to the payload
    - _Requirements: 2.2, 5.5_
  - [x] 3.2 Implement the activation endpoint reusing existing license logic
    - Add an endpoint that reuses `validateLicenseKey` and fail-closed `isKeyDenylisted`, enforces
      the device allowance, and returns a signed License_Token on success
    - _Requirements: 5.3, 5.9, 17.13_
  - [x] 3.3 Implement device-allowance configuration validation
    - Accept a Super_Admin allowance update only when it is an integer in [1, 3], otherwise retain
      the previously configured allowance
    - _Requirements: 5.8, 5.10_
  - [x]* 3.4 Write property test for token sign/verify
    - **Property 9: Token sign/verify round trip with the configured TTL**
    - **Validates: Requirements 4.1, 5.5, 9.1**
  - [x]* 3.5 Write property test for license-key generation authorization
    - **Property 5: Only Super_Admin can generate a license key**
    - **Validates: Requirements 2.5, 2.6**
  - [x]* 3.6 Write property test for device allowance
    - **Property 8: Device allowance is range-validated and enforced**
    - **Validates: Requirements 5.8, 5.9, 5.10**
  - [x]* 3.7 Write property/model test for cloud-path preservation
    - **Property 4: Shared cloud/license code preserves baseline outcomes**
    - **Validates: Requirements 2.1, 2.4**

- [x] 4. Implement fingerprint collection and the Activation_Service (Dart)
  - [x] 4.1 Extend device_fingerprint.dart into Fingerprint_Collector
    - Extend the existing collector to gather cpuId, macAddress, hddSerial, osType, hostname and
      implement `isSameMachine` (same iff at most one component differs)
    - _Requirements: 5.1, 6.1, 6.2_
  - [x] 4.2 Implement Fingerprint_Hash
    - Compute `Fingerprint_Hash = SHA256(cpuId + macAddress + hddSerial)`
    - _Requirements: 5.2_
  - [x] 4.3 Implement the Activation_Service
    - Send key + fingerprint to the License_Server (≤30s), on success write the token to the
      AES-256-GCM Local_License_File in the OS-specific secure location; on any failure (no
      internet, rejection, denylist, allowance exhausted, connection/timeout) report the reason and
      create no file (machine stays unactivated)
    - _Requirements: 5.3, 5.4, 5.6, 5.7, 5.11, 5.12, 20.4_
  - [x]* 4.4 Write property test for the fingerprint hash
    - **Property 6: Fingerprint_Hash is deterministic over the bound components**
    - **Validates: Requirements 5.2**
  - [ ]* 4.5 Write property test for activation failure atomicity
    - **Property 7: Activation never leaves partial state on failure**
    - **Validates: Requirements 5.4, 5.11, 5.12, 17.13**
  - [ ]* 4.6 Write unit + smoke tests for collection and OS paths
    - Test fingerprint collection completeness and the OS-specific license-file location
    - _Requirements: 5.1, 5.7, 20.4_

- [x] 5. Implement License_Validator and the Grace_Period state machine (Dart)
  - [x] 5.1 Implement the pure classify() function
    - Implement deterministic classification: Locked when `now < lastValidatedAt` or `drift >= 2`;
      otherwise Normal (≤7d), Warning (>7–14d), Read_Only (>14–21d), Locked (>21d)
    - _Requirements: 6.1, 6.2, 6.3, 7.6, 7.7, 7.8, 7.10, 7.11_
  - [x] 5.2 Implement silent background validation
    - Run every 24h (configurable whole-hours [1,168], ±5min), each attempt completing/abandoning
      within 2s, executed asynchronously (UI never blocked >100ms); record server `Last_Validated_At`
      on success; on failure retain state and let the user continue
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.12_
  - [x] 5.3 Wire Read_Only/Locked into license_invalid_listener
    - Drive the existing `license_invalid_listener.dart` so Read_Only disables bill-creation and
      blocks creation, and Locked disables all but reactivation — with no widget-tree changes
    - _Requirements: 7.9, 7.13_
  - [ ]* 5.4 Write property test for grace-period classification
    - **Property 12: Grace-period and machine-binding classification**
    - **Validates: Requirements 6.1, 6.2, 6.3, 7.6, 7.7, 7.8, 7.9, 7.10, 7.11, 7.13**
  - [ ]* 5.5 Write property test for failed-validation state preservation
    - **Property 13: Failed validation preserves trusted state**
    - **Validates: Requirements 7.5, 7.12**
  - [ ]* 5.6 Write property test for the validation interval setter
    - **Property 14: Validation interval is range-validated**
    - **Validates: Requirements 7.2**

- [x] 6. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Extend the Local_Store schema and migration ladder (Drift)
  - [x] 7.1 Add System_Columns and missing cloud entity tables
    - Extend `app_database.dart` at schemaVersion v39+ via the existing `onUpgrade` ladder:
      `addColumn` for missing System_Columns on existing tables and `createTable` for missing cloud
      entities; never drop/redefine existing tables (incl. `SyncQueue`, `LicenseCache`)
    - _Requirements: 8.1, 8.2, 8.7_
  - [x] 7.2 Add indexes, WAL mode, and SQLCipher key derivation
    - Add per-table indexes on tenant_id, sync_status, deleted_at; enable WAL; derive the SQLCipher
      key from Fingerprint_Hash + tenant id + app secret
    - _Requirements: 8.3, 8.4, 8.5, 16.2_
  - [x]* 7.3 Write property test for table structure
    - **Property 16: Every table declares System_Columns and the required indexes**
    - **Validates: Requirements 8.1, 8.5, 16.2**
  - [x]* 7.4 Write property test for migration atomicity
    - **Property 17: Schema migration is atomic and preserves existing data**
    - **Validates: Requirements 8.7, 8.8**
  - [x]* 7.5 Write unit test for required-table presence
    - Assert all required cloud entity tables exist after migration
    - _Requirements: 8.2_

- [x] 8. Implement the S3 and SQS/SNS offline equivalents (Node/TS)
  - [x] 8.1 Implement the Object_Store (S3 equivalent)
    - Content-addressed binary store under the DukanX data dir returning bytes byte-for-byte
    - _Requirements: 4.5_
  - [x] 8.2 Implement the Local_Queue (SQS/SNS equivalent)
    - SQLite-backed FIFO queue preserving enqueue order on dequeue
    - _Requirements: 4.6_
  - [x] 8.3 Implement atomic rollback on failed store/enqueue/dequeue
    - On failure, roll back so no partial object or message remains and report to the service layer
    - _Requirements: 4.7_
  - [ ]* 8.4 Write property test for store and queue round trips
    - **Property 18: Object store and message queue round trips**
    - **Validates: Requirements 4.5, 4.6**

- [x] 9. Implement Offline_Auth_Service and the RBAC_Engine (Node/TS)
  - [x] 9.1 Implement the Offline_Auth_Service
    - Authenticate against Local_Store, issue RS256 12h local JWT (signing key from OS keychain),
      hash/verify passwords with bcrypt(12), reject invalid credentials with no token
    - _Requirements: 4.1, 9.1, 9.2, 9.9, 17.4, 17.5_
  - [x] 9.2 Implement rate limiting and lockout
    - 5 failures in 15min → 60s rate limit; 10 failures in 30min → 30min lock; resume after windows
    - _Requirements: 9.7, 9.8_
  - [x] 9.3 Implement the RBAC_Engine and Permission_Matrix
    - Provide roles {owner, manager, cashier, viewer}, enforce the Permission_Matrix, apply role
      changes without internet, and invalidate exactly that user's sessions on role change
    - _Requirements: 9.3, 9.4, 9.5, 9.6_
  - [ ]* 9.4 Write property test for credential hashing
    - **Property 10: Credential hashing round trip at the required cost**
    - **Validates: Requirements 9.2, 9.9, 17.4**
  - [ ]* 9.5 Write property test for the login gate
    - **Property 20: Login gate enforces rate limiting and lockout**
    - **Validates: Requirements 9.7, 9.8**
  - [ ]* 9.6 Write property test for role-change session invalidation
    - **Property 19: Role change invalidates exactly that user's sessions**
    - **Validates: Requirements 9.6**
  - [ ]* 9.7 Write property test for Permission_Matrix enforcement
    - **Property 21: Permission_Matrix enforcement**
    - **Validates: Requirements 9.4**
  - [ ]* 9.8 Write unit tests for roles and offline role change
    - Assert the Default_Role set and that role changes apply without internet
    - _Requirements: 9.3, 9.5_

- [x] 10. Implement the Offline_Gating_Engine (Dart, reuse plan_mapping_builder)
  - [x] 10.1 Derive plan/types/flags and delegate to the existing engine
    - Derive granted tier, allowed business types, and feature flags from the License_Token, then
      reuse `plan_mapping_builder.dart` + capability classifier to resolve access (no new tier logic)
    - _Requirements: 10.1, 10.2, 10.6, 10.7_
  - [x] 10.2 Implement override, above-tier denial, and vertical denial
    - super-admin override grants everything; access above the granted tier is denied without
      changing the tier; a vertical absent from `allowedBusinessTypes` is denied with a clear reason
    - _Requirements: 10.3, 10.4, 10.5, 10.8, 10.9_
  - [ ]* 10.3 Write property test for cumulative tier gating
    - **Property 22: Cumulative tier gating with super-admin override and derivation**
    - **Validates: Requirements 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.8**
  - [ ]* 10.4 Write property test for existing tier assignments
    - **Property 23: Existing capabilities keep their pre-feature tier assignment**
    - **Validates: Requirements 10.7**
  - [ ]* 10.5 Write property test for business-vertical membership
    - **Property 24: Business-vertical access requires license membership**
    - **Validates: Requirements 10.9**

- [x] 11. Implement Sync_Foundation and offline write atomicity (Dart)
  - [x] 11.1 Implement Sync_Foundation write recording
    - In one transaction, persist the business record with `sync_status = pending`, increment
      `local_version`, and insert exactly one matching `SyncQueue` entry; if the queue insert fails,
      persist nothing and surface the failure
    - _Requirements: 8.6, 12.1, 12.2, 12.7_
  - [x] 11.2 Implement the documented Conflict_Strategy and disabled-sync guard
    - Encode the per-entity Conflict_Strategy map (documented, not executed) and a guard that blocks
      any sync trigger, leaves the store unchanged, and reports sync disabled
    - _Requirements: 12.3, 12.4, 12.5, 12.6_
  - [ ]* 11.3 Write property test for atomic offline writes
    - **Property 15: Offline write is atomic and produces a pending, queued row**
    - **Validates: Requirements 4.7, 8.6, 12.1, 12.2, 12.7**
  - [ ]* 11.4 Write property test for disabled synchronization
    - **Property 27: Synchronization is disabled and inert this version**
    - **Validates: Requirements 12.5**
  - [ ]* 11.5 Write unit test for the Conflict_Strategy map
    - Assert each entity class maps to its documented strategy value
    - _Requirements: 12.3_

- [x] 12. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 13. Implement cross-mode feature parity and online-only handling
  - [x] 13.1 Wire offline GST through the reused engine and build the online-only registry
    - Route offline bill GST through the existing `gst_service.calculateInvoiceGst`; build an
      Online_Only_Feature registry and document each entry as unavailable offline
    - _Requirements: 11.2, 11.8, 11.9_
  - [x] 13.2 Block online-only features in offline mode
    - When offline, prevent execution of any Online_Only_Feature and return an unavailable indication
    - _Requirements: 11.10_
  - [ ]* 13.3 Write property/model test for cross-mode parity
    - **Property 26: Cross-mode output parity within tolerance**
    - **Validates: Requirements 11.2, 11.8**
  - [ ]* 13.4 Write property test for online-only blocking
    - **Property 25: Online-only features are blocked offline**
    - **Validates: Requirements 11.10**
  - [ ]* 13.5 Write integration test for offline printing and reports
    - Test thermal/A4/PDF printing and report generation offline
    - _Requirements: 11.3, 11.6_

- [x] 14. Implement the Backup_Service (Dart)
  - [x] 14.1 Implement the first-run writable-location prompt
    - Block use until the user selects a writable backup location; reject non-writable selections
      with a clear indication and keep requiring a writable location
    - _Requirements: 13.1, 13.6_
  - [x] 14.2 Implement scheduled verified backups with retention and failure banner
    - Daily backup at a configured time, verify by open + checksum, retain ≥7 verified backups, and
      show a persistent non-dismissible banner after 2 consecutive failures until a verified backup
    - _Requirements: 13.2, 13.3, 13.4, 13.7_
  - [x] 14.3 Implement the restore wizard with an integrity gate
    - Let the user select a backup; restore only when integrity verifies, otherwise abort and
      preserve the existing store unchanged with a reason
    - _Requirements: 13.5, 13.8_
  - [ ]* 14.4 Write property test for backup verification and retention
    - **Property 28: Backup verification, retention, and failure banner**
    - **Validates: Requirements 13.2, 13.3, 13.4, 13.7**
  - [ ]* 14.5 Write property test for backup-location writability
    - **Property 29: Backup location must be writable**
    - **Validates: Requirements 13.6**
  - [ ]* 14.6 Write property test for restore/import safety
    - **Property 30: Restore and migration import never corrupt the live store**
    - **Validates: Requirements 13.5, 13.8, 14.4, 14.7**

- [x] 15. Implement the Migration_Wizard (Dart)
  - [x] 15.1 Implement export, overlap window, and verified import
    - Export Local_Store data + a deactivation token keeping the source usable; allow target
      activation only with a valid token within 48h; verify integrity before import; keep both
      machines usable during the window; auto-deactivate the source when it elapses
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6, 14.7_
  - [ ]* 15.2 Write property test for the migration overlap window
    - **Property 31: Machine-migration overlap window**
    - **Validates: Requirements 14.1, 14.2, 14.3, 14.5, 14.6**

- [x] 16. Implement the LAN_Coordinator (Dart)
  - [x] 16.1 Implement primary/secondary coordination and the allowance cap
    - Designate one Primary_Device; connect secondaries to the primary's loopback backend over LAN
      within 10s using an authenticated session; cap connected devices at the license allowance;
      block secondary writes when the primary is unreachable; operate without internet
    - _Requirements: 15.1, 15.2, 15.3, 15.4, 15.5, 15.6_
  - [ ]* 16.2 Write property test for LAN connection gating
    - **Property 32: LAN connection gating and device-allowance cap**
    - **Validates: Requirements 15.2, 15.4, 15.5, 15.6**

- [x] 17. Implement Local_Backend security middleware (Node/TS)
  - [x] 17.1 Implement authentication middleware on non-health endpoints
    - Require valid auth on every endpoint except `/health`; reject without executing and return an
      authentication-required error otherwise
    - _Requirements: 17.7, 17.14_
  - [x] 17.2 Implement schema validation and parameterized SQL
    - Validate every request input before processing; reject schema-invalid input with no
      persistence; execute all DB access via parameterized statements only
    - _Requirements: 17.8, 17.9, 17.15_
  - [ ]* 17.3 Write property test for endpoint authentication
    - **Property 34: Authentication required on every non-health endpoint**
    - **Validates: Requirements 17.7, 17.14**
  - [ ]* 17.4 Write property test for schema validation
    - **Property 35: Schema validation precedes persistence**
    - **Validates: Requirements 17.8, 17.15**

- [x] 18. Implement the cross-cutting Security_Layer (Dart + Node/TS)
  - [x] 18.1 Centralize key derivation, integrity verification, and log scrubbing
    - Centralize runtime key derivation (license-file AES-256-GCM, SQLCipher AES-256, keys never in
      source), verify Local_License_File integrity before use, and scrub secrets/keys/license keys
      from all log output (reuse the `maskKey` pattern)
    - _Requirements: 8.3, 17.1, 17.2, 17.3, 17.10, 17.11, 17.16_
  - [x] 18.2 Implement tamper detection and read-only forensic mode
    - On a swapped/tampered Local_Store, permit reads, block all writes, and report the condition
    - _Requirements: 17.12_
  - [ ]* 18.3 Write property test for encryption round trips
    - **Property 11: Encryption round trip and authenticated-failure on wrong key or tamper**
    - **Validates: Requirements 5.6, 8.3, 17.1, 17.3, 17.11, 17.16**
  - [ ]* 18.4 Write property test for log scrubbing
    - **Property 36: Secrets and license keys are excluded from logs**
    - **Validates: Requirements 17.10**
  - [ ]* 18.5 Write property test for tamper-forced read-only mode
    - **Property 37: Tamper detection forces read-only forensic mode**
    - **Validates: Requirements 17.12**

- [x] 19. Implement data archival and the Update_Service
  - [x] 19.1 Implement the two-year archival partition
    - Move records older than 2 years into an archive store, keeping the remainder live, with
      indexes maintained on high-frequency query columns
    - _Requirements: 16.1, 16.2_
  - [x] 19.2 Implement the Update_Service
    - Background update checks; mandatory security patches cannot be deferred, others can; updates
      never modify Local_Store data
    - _Requirements: 18.1, 18.2, 18.3, 18.4, 18.5_
  - [ ]* 19.3 Write property test for archival partitioning
    - **Property 33: Two-year archival partition**
    - **Validates: Requirements 16.1**
  - [ ]* 19.4 Write property test for update deferral policy
    - **Property 38: Update deferral policy and data preservation**
    - **Validates: Requirements 18.2, 18.3, 18.4, 18.5**

- [x] 20. Integrate, wire, and verify performance
  - [x] 20.1 Wire all services into the startup sequence via service_locator
    - Register every new service through the existing `sl`, connect the Backend_Supervisor startup
      sequence end to end, and verify Cloud_Subscription_Mode behavior and the UI are unchanged
    - _Requirements: 1.7, 2.1, 2.3, 11.1, 11.5, 11.7_
  - [ ]* 20.2 Write integration benchmark suite for performance targets
    - Benchmark cold/warm start, bill creation, product search, report, PDF, indexed query, and
      1M-row queries against the seeded dataset
    - _Requirements: 16.3, 19.1, 19.2, 19.3, 19.4, 19.5, 19.6, 19.7, 19.8_

- [x] 21. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional test sub-tasks and can be skipped for a faster MVP.
- Each property test maps 1:1 to a design property (Properties 1–38), runs ≥100 generated cases,
  and is tagged `Feature: offline-license-activation, Property {n}: ...`.
- Dart code uses `glados`; Node/TypeScript code uses `fast-check` with Jest, per the design.
- Infrastructure, packaging, timing, and fixed-configuration criteria are covered by the unit,
  integration, and smoke sub-tasks rather than property tests, per the prework classification.
- "Reuse, don't rebuild": existing `license.service.ts`, `license-denylist.service.ts`,
  `plan_mapping_builder.dart`, `app_database.dart`, `device_fingerprint.dart`, `api_client.dart`,
  and `license_invalid_listener.dart` are extended additively, never duplicated.
- Cloud_Subscription_Mode behavior and the Flutter UI remain unchanged in every task.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "2.1", "3.1", "4.1", "7.1"] },
    { "id": 1, "tasks": ["1.2", "2.2", "3.2", "3.3", "4.2", "7.2"] },
    { "id": 2, "tasks": ["1.3", "4.3", "5.1", "8.1", "8.2", "9.1", "10.1", "11.1", "1.4", "1.5", "1.6", "2.3", "2.4", "3.4", "3.5", "3.6", "3.7", "4.4", "7.3", "7.4", "7.5"] },
    { "id": 3, "tasks": ["5.2", "5.3", "8.3", "9.2", "9.3", "10.2", "11.2", "13.1", "14.1", "15.1", "16.1", "17.1", "17.2", "18.1", "19.1", "19.2", "1.7", "4.5", "4.6", "5.4", "8.4", "9.4", "10.4", "11.3"] },
    { "id": 4, "tasks": ["13.2", "14.2", "14.3", "18.2", "5.5", "5.6", "9.5", "9.6", "9.7", "9.8", "10.3", "10.5", "11.4", "11.5", "13.3", "13.5", "14.5", "15.2", "16.2", "17.3", "17.4", "18.3", "18.4", "19.3", "19.4"] },
    { "id": 5, "tasks": ["20.1", "13.4", "14.4", "14.6", "18.5"] },
    { "id": 6, "tasks": ["20.2"] }
  ]
}
```
