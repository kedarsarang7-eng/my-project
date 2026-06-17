# Requirements Document

## Introduction

This feature extends DukanX — a cloud-based, multi-tenant billing SaaS built on AWS (Flutter
frontend + Node.js/TypeScript backend) — so it can also run as a fully offline-capable desktop
billing application protected by a machine-bound license-key activation system.

Offline capability is added **alongside** the existing cloud capability, never as a replacement.
The application supports two operating modes: an offline, lifetime-licensed mode that runs a local
backend on the same machine, and the existing cloud-subscription mode that continues to use the
AWS backend exactly as it does today. The mode is chosen at startup and persisted locally.

This is a **mature codebase**. Substantial infrastructure already exists and MUST be reused rather
than rebuilt:

- A JWT-based license system in `my-backend/src` (`license.types.ts`, `license.service.ts`,
  `license-denylist.service.ts`) that already generates `DKX-`/`DKNX-` keys, encodes plan,
  allowed business types, max users, max devices, features, expiry, and a super-admin override,
  and supports activation, validation, and revocation.
- A Super Admin app/feature (`Dukan_x/lib/features/super_admin/`) that is the only place license
  keys are generated.
- An offline database (`Dukan_x/lib/core/database/app_database.dart`, Drift/SQLite) that already
  includes a `LicenseCache` table and a `SyncQueue` table, and a fallback to the license cache in
  `app_state_providers.dart`.
- A deterministic plan/feature gating engine (`Dukan_x/lib/core/subscription/plan_mapping_builder.dart`
  plus `capability_classifier`, `subscription_tier`, `plan_mapping`) governed by the existing
  `subscription-plan-tiers` spec, which maps a business type's registered capabilities onto a
  cumulative four-tier ladder (Basic → Pro → Premium → Enterprise).
- License-invalid handling already wired through `Dukan_x/lib/security/license_invalid_listener.dart`
  and `lib/app/app.dart`.
- 18+ business verticals as modules under `Dukan_x/lib/modules/`.

**Guiding constraint — preserve what works.** Per the user's directive ("if the license base
system is already well, don't touch it unless it must need modification"), the existing license
key system and the existing cloud/AWS behavior are treated as fixed baselines. Requirements in this
document extend and complete that infrastructure; they do not redesign the cloud path or the
license key payload format. Where a requirement could touch shared code, it is written so that
cloud-mode behavior is unchanged.

**UI constraint — zero Flutter UI changes.** All online/offline switching lives at the
service/repository layer. The Flutter widget/UI layer requires no modification to operate in either
mode.

## Glossary

- **DukanX_App**: The Flutter desktop application that hosts both operating modes.
- **Operating_Mode**: One of two runtime modes the application can run in: Offline_Lifetime_Mode or Cloud_Subscription_Mode.
- **Offline_Lifetime_Mode**: The mode in which DukanX_App runs against a Local_Backend on the same machine with no internet dependency after activation.
- **Cloud_Subscription_Mode**: The existing mode in which DukanX_App runs against the AWS backend. Behavior in this mode is the fixed baseline and is unchanged by this feature.
- **Mode_Manager**: The service-layer component that determines, persists, and exposes the current Operating_Mode and selects the active backend target for the repository layer.
- **Local_Config**: The local configuration store that persists the selected Operating_Mode and related runtime settings on the machine.
- **Local_Backend**: A Node.js/Express server packaged inside the desktop application that serves the same API contracts as the AWS backend while bound to the loopback interface.
- **Backend_Supervisor**: The component that spawns, health-checks, monitors, and stops the Local_Backend process.
- **Loopback_Address**: The network address `127.0.0.1` on port `8765` to which the Local_Backend binds.
- **Startup_Sequence**: The ordered offline boot steps: license check → local license decrypt/validate → spawn Local_Backend → health check → connect UI → restore session.
- **Machine_Fingerprint**: A structured device identity composed of cpuId, macAddress, hddSerial, osType, and hostname.
- **Fingerprint_Hash**: The value `SHA256(cpuId + macAddress + hddSerial)` used to bind a license to a machine.
- **Fingerprint_Collector**: The component that gathers Machine_Fingerprint values and computes Fingerprint_Hash.
- **Activation_Service**: The component that performs one-time online license activation and stores the resulting Local_License_File.
- **License_Server**: The existing backend endpoint set that validates a license key, binds it to a Machine_Fingerprint, and returns an RSA-signed license token.
- **License_Token**: The RSA-signed license JWT returned by License_Server, with a one-year time-to-live, carrying the existing LicenseKeyPayload fields (tenantId, plan, allowedBusinessTypes, maxUsers, maxDevices, features, expiresAt, issuedAt, keyVersion, superAdminOverride).
- **Local_License_File**: The activation result stored on disk, encrypted with AES-256-GCM using a key derived via PBKDF2 from Fingerprint_Hash and an application secret, placed in an OS-specific secure location.
- **License_Validator**: The component that performs silent background revalidation of the Local_License_File and applies grace-period state.
- **Grace_Period_State**: The current license-health state derived from days elapsed since last successful validation: Normal, Warning, Read_Only, or Locked.
- **Last_Validated_At**: The server-provided timestamp recorded at the most recent successful validation, used as the trusted time reference for grace-period and clock-tamper checks.
- **Local_Store**: The local SQLite database, encrypted with SQLCipher, that holds all offline business data.
- **System_Columns**: The universal columns present on every Local_Store table: id, tenant_id, created_at, updated_at, deleted_at, sync_status, server_id, local_version.
- **Sync_Queue**: The existing local table that records every offline write for future synchronization.
- **Sync_Status**: The per-row synchronization marker stored in System_Columns (for example: pending, synced).
- **Sync_Foundation**: The service-layer component that records offline writes into the Sync_Queue and owns the documented Conflict_Strategy in preparation for a future synchronization worker.
- **Conflict_Strategy**: The documented per-entity rule that will govern conflict resolution when synchronization is activated in a later version. It is defined but not executed in this version.
- **Offline_Auth_Service**: The component that authenticates users locally using local JWT (RS256) and bcrypt-hashed passwords.
- **RBAC_Engine**: The component that enforces role-based access control locally using the default roles and the per-module permission matrix.
- **Default_Role**: One of the predefined roles: owner, manager, cashier, viewer.
- **Permission_Matrix**: The mapping of each Default_Role to the set of module actions it may perform.
- **Offline_Gating_Engine**: The existing plan/feature gating engine (`plan_mapping_builder` and supporting classes) used in Offline_Lifetime_Mode to enforce plan-tier and business-type feature access from the License_Token.
- **Plan_Tier**: One of the four ordered plans defined by the existing subscription-plan-tiers system: Basic, Pro, Premium, Enterprise.
- **Business_Vertical**: One of the 18+ business modules under `Dukan_x/lib/modules/` (for example grocery, restaurant, pharmacy, hardware, clothing, wholesale, jewellery, clinic, auto_parts, computer_shop, mobile_shop, petrol_pump, book_store, decoration_catering, school_erp, vegetables_broker).
- **Online_Only_Feature**: A feature that depends on a real-time external service and therefore cannot function in Offline_Lifetime_Mode.
- **Backup_Service**: The component that performs scheduled local data backups, integrity checks, and restores.
- **Migration_Wizard**: The component that moves an activated installation from one machine to another.
- **LAN_Coordinator**: The component that lets a secondary device on the same local network use the primary device's Local_Store without internet.
- **Primary_Device**: The machine that holds the authoritative Local_Store in a LAN deployment.
- **Secondary_Device**: A machine on the same local network that connects to the Primary_Device's Local_Backend.
- **Security_Layer**: The set of cross-cutting controls (encryption, key derivation, binding, validation, rate limiting) that protect the offline installation.
- **Update_Service**: The component that checks for and applies application updates in Offline_Lifetime_Mode.
- **Super_Admin**: The privileged operator, served by the existing super_admin feature, who is the only actor permitted to generate license keys and configure device allowances.

## Requirements

### Requirement 1: Dual Operating Modes

**User Story:** As a desktop user, I want the application to run either fully offline on a lifetime license or against the existing cloud account, so that I can use DukanX without internet while existing cloud customers are unaffected.

#### Acceptance Criteria

1. THE DukanX_App SHALL support exactly two Operating_Mode values: Offline_Lifetime_Mode and Cloud_Subscription_Mode.
2. WHEN DukanX_App starts, THE Mode_Manager SHALL determine the active Operating_Mode from Local_Config.
3. WHEN a user selects an Operating_Mode during the startup-selection step, THE Mode_Manager SHALL persist the selected Operating_Mode in Local_Config.
4. WHILE the active Operating_Mode is Cloud_Subscription_Mode, THE Mode_Manager SHALL route all backend calls to the AWS backend using the existing cloud behavior.
5. WHILE the active Operating_Mode is Offline_Lifetime_Mode, THE Mode_Manager SHALL route all backend calls to the Local_Backend at the Loopback_Address.
6. THE Mode_Manager SHALL NOT expose the active Operating_Mode or the active backend target to the Flutter UI layer, restricting that information to the service and repository layer.
7. THE DukanX_App SHALL operate in both Operating_Mode values without any change to the Flutter UI layer.
8. IF a routed backend call does not establish a connection or return a response within 10 seconds, THEN THE Mode_Manager SHALL report a routing failure that identifies the failed backend target to the service layer and SHALL leave the active Operating_Mode unchanged.
9. IF Local_Config contains no persisted Operating_Mode or an unrecognized Operating_Mode value when DukanX_App starts, THEN THE Mode_Manager SHALL default the active Operating_Mode to Cloud_Subscription_Mode and SHALL persist that default in Local_Config.

### Requirement 2: Cloud Mode and License Base Preservation

**User Story:** As a product owner, I want the existing cloud infrastructure and the existing license key system left intact, so that current customers experience no regression and the proven license base is reused rather than rebuilt.

#### Acceptance Criteria

1. THE DukanX_App SHALL preserve the existing Cloud_Subscription_Mode AWS backend behavior so that, for identical inputs, the request contracts, response contracts, and authentication outcomes are identical to the pre-feature baseline.
2. THE Activation_Service SHALL reuse the existing LicenseKeyPayload structure and the existing DKX- and DKNX- key formats without adding, removing, renaming, or changing the type of any existing LicenseKeyPayload field (tenantId, plan, allowedBusinessTypes, maxUsers, maxDevices, features, expiresAt, issuedAt, keyVersion, superAdminOverride).
3. WHERE the existing license generation, activation, validation, or revocation logic already provides the behavior a requirement specifies, THE DukanX_App SHALL invoke that existing logic and SHALL NOT create a separate implementation of that behavior.
4. IF an offline requirement requires a change to shared license code or shared cloud code, THEN THE DukanX_App SHALL apply the change such that, for identical inputs, Cloud_Subscription_Mode continues to produce request contracts, response contracts, and authentication outcomes identical to the pre-change baseline.
5. THE Super_Admin feature SHALL be the only actor permitted to generate license keys.
6. IF an actor other than Super_Admin attempts to generate a license key, THEN THE DukanX_App SHALL block the license key generation, SHALL NOT create or persist any license key, and SHALL return an authorization error indicating the action is not permitted.

### Requirement 3: Local Backend Packaging and Lifecycle

**User Story:** As a desktop user, I want a local backend to start automatically inside the app, so that offline mode serves the same API the cloud serves without me configuring anything.

#### Acceptance Criteria

1. THE DukanX_App SHALL package the Local_Backend as a Node.js/Express server inside the desktop application.
2. THE Local_Backend SHALL expose the same API contracts that the AWS backend exposes.
3. WHEN DukanX_App starts in Offline_Lifetime_Mode, THE Backend_Supervisor SHALL execute the Startup_Sequence in this order: verify the local license check, decrypt and validate the Local_License_File, spawn the Local_Backend, perform a health check, connect the UI, and restore the prior session.
4. THE Backend_Supervisor SHALL bind the Local_Backend to the Loopback_Address.
5. WHEN the Local_Backend health-check endpoint returns a success response within the 8-second startup window, THE Backend_Supervisor SHALL connect the repository layer to the Local_Backend.
6. IF the Local_Backend health-check endpoint does not return a success response within 8 seconds of spawn, THEN THE Backend_Supervisor SHALL report a startup error to the service layer, SHALL terminate any partially started Local_Backend process, and SHALL stop the Startup_Sequence.
7. WHEN DukanX_App exits, THE Backend_Supervisor SHALL request graceful shutdown of the Local_Backend process and SHALL force-terminate the process if it has not exited within 5 seconds.
8. IF the Local_Backend process terminates unexpectedly while DukanX_App is running, THEN THE Backend_Supervisor SHALL attempt to restart the Local_Backend up to 3 consecutive times and SHALL record each restart attempt as a restart event.
9. IF the Local_Backend fails to restart after 3 consecutive attempts, THEN THE Backend_Supervisor SHALL report an unrecoverable backend failure to the service layer and SHALL mark the repository layer as disconnected.

### Requirement 4: Offline Service Equivalents

**User Story:** As an engineer, I want each cloud service to have a defined local equivalent, so that the offline backend reproduces cloud functionality on the local machine.

#### Acceptance Criteria

1. THE Offline_Auth_Service SHALL provide the local equivalent of Cognito by authenticating users against credentials stored in Local_Store and issuing a local JWT signed with RS256, with passwords hashed and verified using bcrypt.
2. THE Local_Backend SHALL provide the local equivalent of Lambda and REST API Gateway by serving the same REST API contracts that the AWS backend exposes through Express routes bound to the Loopback_Address.
3. THE Local_Backend SHALL provide the local equivalent of the WebSocket service by serving the same real-time event contracts that the AWS backend exposes through a Socket.io server bound to the Loopback_Address.
4. THE Local_Store SHALL provide the local equivalent of DynamoDB by performing create, read, update, and delete operations on SQLite encrypted with SQLCipher that return results equivalent to the cloud data operations for identical inputs.
5. THE Local_Backend SHALL provide the local equivalent of S3 by storing, retrieving, and deleting binary objects addressed by a unique object key within a structured local filesystem location under the DukanX data directory, returning stored content byte-for-byte unchanged.
6. THE Local_Backend SHALL provide the local equivalent of SQS and SNS by enqueuing messages into a SQLite-backed queue and making each enqueued message available for retrieval in the order it was enqueued.
7. IF a local-equivalent store, retrieve, enqueue, or dequeue operation fails, THEN THE Local_Backend SHALL report the failure to the service layer and SHALL not leave a partially written object or message in the Local_Store or the filesystem location.

### Requirement 5: Machine-Bound License Activation

**User Story:** As a Super Admin, I want a license key to bind to a specific machine during a one-time online activation, so that a lifetime license cannot be copied to unauthorized machines.

#### Acceptance Criteria

1. WHEN a user starts activation, THE Fingerprint_Collector SHALL collect the Machine_Fingerprint values cpuId, macAddress, hddSerial, osType, and hostname.
2. THE Fingerprint_Collector SHALL compute the Fingerprint_Hash as SHA256 of the concatenation of cpuId, macAddress, and hddSerial.
3. WHEN a user submits a license key for activation, THE Activation_Service SHALL send the license key and the Machine_Fingerprint to the License_Server over an internet connection and SHALL wait at most 30 seconds for a response.
4. IF no internet connection is available during activation, THEN THE Activation_Service SHALL report an indication that activation requires internet access, SHALL not create the Local_License_File, and SHALL leave the machine unactivated.
5. WHEN the License_Server successfully validates the license key and Machine_Fingerprint, THE License_Server SHALL return a License_Token signed with RSA and carrying a time-to-live of 365 days.
6. WHEN the Activation_Service receives the License_Token, THE Activation_Service SHALL store the License_Token in the Local_License_File encrypted with AES-256-GCM using a key derived via PBKDF2 from the Fingerprint_Hash and the application secret.
7. THE Activation_Service SHALL store the Local_License_File in an OS-specific secure location for Windows, macOS, and Linux.
8. THE Activation_Service SHALL permit one machine per license by default.
9. WHERE the Super_Admin configures a device allowance of exactly 2 or 3 devices for a tenant, user, and business identity, THE License_Server SHALL allow activation on up to that configured number of machines for that license.
10. IF the Super_Admin configures a device allowance that is not an integer in the range 1 to 3 inclusive, THEN THE License_Server SHALL reject the configuration and SHALL retain the previously configured device allowance.
11. IF the License_Server rejects activation because the license key is invalid, expired, or revoked, or because the configured device allowance for that license is already exhausted, THEN THE Activation_Service SHALL report an activation-failure indication that identifies the rejection reason, SHALL not create the Local_License_File, and SHALL leave the machine unactivated.
12. IF the activation request to the License_Server fails or does not return a response within 30 seconds, THEN THE Activation_Service SHALL report a connection-error indication, SHALL not create the Local_License_File, and SHALL leave the machine unactivated.

### Requirement 6: Fingerprint Drift Tolerance

**User Story:** As a user whose hardware changes slightly, I want minor component changes to be tolerated, so that a single replaced part does not force me to reactivate.

#### Acceptance Criteria

1. WHEN the License_Validator compares the current Machine_Fingerprint to the activated Machine_Fingerprint, THE License_Validator SHALL treat the machine as the same machine WHERE at most one fingerprint component differs.
2. IF two or more Machine_Fingerprint components differ from the activated Machine_Fingerprint, THEN THE License_Validator SHALL treat the installation as a new machine requiring reactivation.
3. WHEN a new machine requiring reactivation is detected, THE License_Validator SHALL set the Grace_Period_State to Locked and SHALL require activation before further use.

### Requirement 7: Silent Background Validation and Grace Periods

**User Story:** As a user, I want license validation to happen quietly in the background, so that my work is never blocked and I am warned before the license locks.

#### Acceptance Criteria

1. WHILE DukanX_App runs in Offline_Lifetime_Mode, THE License_Validator SHALL perform a background validation every 24 hours (within a tolerance of ±5 minutes) measured from the last completed attempt.
2. THE License_Validator SHALL allow the background validation interval to be configured to any whole-hour value between 1 hour and 168 hours, defaulting to 24 hours, and SHALL reject any configured value outside this range while retaining the previously applied interval.
3. WHEN a background validation runs, THE License_Validator SHALL complete or abandon the attempt within 2 seconds.
4. WHILE a background validation is running, THE License_Validator SHALL execute it asynchronously such that the user interface remains responsive to user input and is never blocked for more than 100 milliseconds.
5. WHEN a background validation succeeds, THE License_Validator SHALL record the server-provided Last_Validated_At value.
6. WHILE the days elapsed since Last_Validated_At are 7 or fewer, THE License_Validator SHALL set the Grace_Period_State to Normal.
7. WHILE the days elapsed since Last_Validated_At are greater than 7 and 14 or fewer, THE License_Validator SHALL set the Grace_Period_State to Warning and SHALL display a renewal warning at each application launch and at most once every 24 hours during a continuous session.
8. WHILE the days elapsed since Last_Validated_At are greater than 14 and 21 or fewer, THE License_Validator SHALL set the Grace_Period_State to Read_Only, permitting viewing of records while preventing creation of new bills.
9. WHILE the Grace_Period_State is Read_Only, THE DukanX_App SHALL disable the user-interface controls that create new bills and SHALL block any creation attempt.
10. WHILE the days elapsed since Last_Validated_At are greater than 21, THE License_Validator SHALL set the Grace_Period_State to Locked and SHALL require reactivation.
11. IF the system clock reports a time earlier than Last_Validated_At, THEN THE License_Validator SHALL treat the condition as clock tampering and SHALL set the Grace_Period_State to Locked.
12. IF a background validation fails because the License_Server is unreachable, a network error occurs, or the attempt is abandoned due to the 2-second timeout, THEN THE License_Validator SHALL retain the most recently recorded Last_Validated_At value, SHALL NOT advance the Grace_Period_State as a result of the failure itself, and SHALL allow the user to continue working without interruption.
13. WHILE the Grace_Period_State is Locked, THE DukanX_App SHALL disable all user-interface controls except those required to complete reactivation and SHALL block all record creation and editing until reactivation completes successfully.

### Requirement 8: Local Data Store Schema

**User Story:** As an engineer, I want the local database to mirror the cloud entities with universal system columns, so that offline data is complete and ready for future synchronization.

#### Acceptance Criteria

1. THE Local_Store SHALL include System_Columns on every table: id, tenant_id, created_at, updated_at, deleted_at, sync_status, server_id, and local_version.
2. THE Local_Store SHALL provide at minimum a table for each of the following cloud entities: users, roles, permissions, sessions, products, categories, units, inventory, inventory_movements, customers, sales, sale_items, payments, vendors, purchases, purchase_items, business_settings, and tax_rates.
3. THE Local_Store SHALL encrypt all data using SQLCipher with a key derived from the Fingerprint_Hash, the tenant identifier, and the application secret.
4. THE Local_Store SHALL operate in write-ahead logging mode.
5. THE Local_Store SHALL define an index on the tenant_id, sync_status, and deleted_at columns of every table.
6. WHEN a record is created or updated offline, THE Local_Store SHALL set that record's sync_status to pending and SHALL increment that record's local_version.
7. WHERE the existing Drift schema already defines a required table or the LicenseCache table, THE Local_Store SHALL extend the existing schema through its migration mechanism rather than redefine or drop the existing tables, and SHALL preserve all existing rows and their column values during the migration.
8. IF a schema migration does not complete successfully, THEN THE Local_Store SHALL retain the prior schema and all existing data unchanged and SHALL report an indication that the migration did not complete.

### Requirement 9: Offline Authentication and RBAC

**User Story:** As a shop owner offline, I want users to log in and have role-based access enforced locally, so that staff can only do what their role allows even without internet.

#### Acceptance Criteria

1. WHEN a user submits valid credentials in Offline_Lifetime_Mode, THE Offline_Auth_Service SHALL authenticate the user against Local_Store and SHALL issue a local JWT signed with RS256 that expires 12 hours after issuance.
2. THE Offline_Auth_Service SHALL hash and verify passwords using bcrypt with a work factor of 12.
3. THE RBAC_Engine SHALL provide the Default_Role values owner, manager, cashier, and viewer.
4. THE RBAC_Engine SHALL enforce the Permission_Matrix for each module action based on the authenticated user's role, and SHALL deny any module action not permitted for that role with an indication that the action is not permitted.
5. WHEN a Super_Admin or owner changes a user's role, THE RBAC_Engine SHALL apply the new role without requiring internet access.
6. WHEN a user's role changes, THE Offline_Auth_Service SHALL invalidate that user's active sessions and SHALL require that user to re-authenticate before performing any further action.
7. IF a user submits 5 failed login attempts within 15 minutes, THEN THE Offline_Auth_Service SHALL reject all further login attempts for that account for 60 seconds and SHALL report an indication that login is temporarily rate limited.
8. IF a user accumulates 10 failed login attempts within 30 minutes, THEN THE Offline_Auth_Service SHALL lock that account for 30 minutes, SHALL reject every login attempt during the 30-minute lock window with an indication that the account is locked, and SHALL permit login attempts again after the 30-minute lock window elapses.
9. IF a user submits credentials that do not match a stored user in Local_Store, THEN THE Offline_Auth_Service SHALL deny authentication, SHALL not issue a JWT, and SHALL report an indication that the credentials are invalid.

### Requirement 10: Offline Plan-Tier and Business-Type Gating

**User Story:** As a licensed user, I want my plan and business type to gate features offline, so that I can access exactly the features my license grants without internet.

#### Acceptance Criteria

1. THE Offline_Gating_Engine SHALL derive the granted Plan_Tier, allowed business types, and feature flags from the License_Token.
2. THE Offline_Gating_Engine SHALL reuse the existing plan_mapping_builder and capability gating logic to determine accessible features.
3. WHILE the License_Token grants the Basic Plan_Tier, THE Offline_Gating_Engine SHALL permit only the Basic_Tier features for the active Business_Vertical.
4. WHILE the License_Token grants the Pro, Premium, or Enterprise Plan_Tier, THE Offline_Gating_Engine SHALL permit the cumulative features of that Plan_Tier and all lower tiers for the active Business_Vertical.
5. IF a user attempts to access a feature above the granted Plan_Tier, THEN THE Offline_Gating_Engine SHALL deny access to that feature and SHALL report an indication that the feature requires a higher Plan_Tier, without modifying the granted Plan_Tier.
6. THE Offline_Gating_Engine SHALL enforce gating per Plan_Tier and per Business_Vertical.
7. THE Offline_Gating_Engine SHALL require Plan_Tier assignment only for features newly added by this feature, and SHALL reuse the existing tier assignments for all existing capabilities.
8. WHERE the License_Token carries the super-admin override, THE Offline_Gating_Engine SHALL grant access to all features regardless of the granted Plan_Tier and the active Business_Vertical.
9. IF the active Business_Vertical is not among the allowed business types derived from the License_Token, THEN THE Offline_Gating_Engine SHALL deny access to that Business_Vertical's features and SHALL report an indication that the Business_Vertical is not included in the license.

### Requirement 11: Offline Feature Parity Across Verticals

**User Story:** As a user of any business vertical, I want every feature that works online to work offline, so that switching to offline mode causes no loss of capability.

#### Acceptance Criteria

1. THE DukanX_App SHALL make each of its Business_Vertical modules, numbering at least 18, available for use in both Offline_Lifetime_Mode and Cloud_Subscription_Mode.
2. WHEN a user creates a bill in Offline_Lifetime_Mode, THE Local_Backend SHALL compute GST as CGST, SGST, and IGST values that match the Cloud_Subscription_Mode calculation for identical inputs to within 0.01 (two decimal places).
3. THE DukanX_App SHALL support thermal printing, A4 printing, and PDF invoice generation in Offline_Lifetime_Mode.
4. THE DukanX_App SHALL support barcode-based item entry in Offline_Lifetime_Mode.
5. THE DukanX_App SHALL provide inventory, purchases, and customer management in Offline_Lifetime_Mode.
6. THE DukanX_App SHALL provide the reporting features, including at least 10 report types, PDF export, Excel export, and GSTR-1 output, in Offline_Lifetime_Mode.
7. THE DukanX_App SHALL provide user and access management in Offline_Lifetime_Mode.
8. WHEN given identical inputs, THE DukanX_App SHALL produce billing, inventory, and report outputs in Offline_Lifetime_Mode whose field values are equal to the corresponding Cloud_Subscription_Mode outputs, with monetary values matching to within 0.01 (two decimal places).
9. WHERE a feature is an Online_Only_Feature, THE DukanX_App SHALL document that feature as unavailable in Offline_Lifetime_Mode.
10. WHILE the DukanX_App is in Offline_Lifetime_Mode, WHEN a user attempts to access an Online_Only_Feature, THE DukanX_App SHALL display an indication that the feature is unavailable offline and SHALL not execute the feature.

### Requirement 12: Synchronization Foundations

**User Story:** As an engineer, I want offline writes recorded and a conflict strategy defined now, so that a future synchronization worker can be added without changing the data model.

#### Acceptance Criteria

1. WHEN any record is written in Offline_Lifetime_Mode, THE Local_Store SHALL record a corresponding entry in the Sync_Queue.
2. WHEN any record is written in Offline_Lifetime_Mode, THE Local_Store SHALL set the Sync_Status of that record to pending.
3. THE Sync_Foundation SHALL define a Conflict_Strategy for each entity class as follows: sales resolve to local wins, inventory resolves to last-write-wins, roles and permissions resolve to cloud wins, user profiles resolve to cloud wins, product catalog resolves to merge-with-prompt, and settings resolve to cloud wins.
4. THE Sync_Foundation SHALL not execute synchronization or conflict resolution in this version.
5. IF a synchronization operation is triggered in this version, THEN THE Sync_Foundation SHALL prevent the operation from executing, SHALL leave the Local_Store unchanged, and SHALL indicate to the caller that synchronization is disabled.
6. THE Sync_Foundation SHALL document the Conflict_Strategy so that a later synchronization worker can apply it without changing the Local_Store schema.
7. IF recording the Sync_Queue entry fails during an offline write, THEN THE Local_Store SHALL not persist the corresponding record and SHALL indicate the failure to the caller.

### Requirement 13: Data Protection and Recovery

**User Story:** As a business owner, I want my offline data backed up and recoverable, so that I never lose my records to a disk failure or corruption.

#### Acceptance Criteria

1. WHEN DukanX_App runs for the first time in Offline_Lifetime_Mode, THE Backup_Service SHALL prompt the user to choose a backup location and SHALL block use of DukanX_App until the user selects a writable backup location.
2. THE Backup_Service SHALL create a backup of the Local_Store to the user-chosen location once per 24-hour period at a configured daily time and SHALL retain at least the 7 most recent verified backups.
3. WHEN a backup completes, THE Backup_Service SHALL verify backup integrity by confirming the backup opens successfully and its computed checksum matches the source, and SHALL mark the backup as verified only when both checks pass.
4. IF 2 or more consecutive backup attempts fail, THEN THE Backup_Service SHALL display a persistent, non-dismissible failure banner and SHALL keep the banner displayed until a backup completes and passes integrity verification.
5. WHEN a user starts a restore, THE Backup_Service SHALL guide the user through a restore wizard that lets the user select a backup, and WHEN the user confirms a backup that passes integrity verification, THE Backup_Service SHALL restore the Local_Store from that backup.
6. IF the backup location selected during first-run setup is not writable, THEN THE Backup_Service SHALL reject the selection, report an indication that the location is not writable, and continue to require selection of a writable backup location.
7. IF backup integrity verification fails, THEN THE Backup_Service SHALL discard the failed backup, retain the most recent previously verified backup, and treat the attempt as a failed backup attempt.
8. IF a backup selected for restore fails integrity verification, THEN THE Backup_Service SHALL abort the restore, preserve the existing Local_Store unchanged, and report an indication that the selected backup cannot be restored.

### Requirement 14: Machine Migration

**User Story:** As a user replacing a computer, I want to move my activated installation to a new machine, so that I can keep working without losing data or my license.

#### Acceptance Criteria

1. WHEN a user starts a migration, THE Migration_Wizard SHALL export the Local_Store data and a deactivation token from the source machine and SHALL keep the source machine activated and usable until the source machine is deactivated.
2. WHEN the source machine is deactivated, THE Migration_Wizard SHALL allow activation on the target machine using the exported deactivation token within 48 hours of the deactivation.
3. WHILE the 48-hour overlap window that begins at source-machine deactivation is in effect, THE Migration_Wizard SHALL keep both the source machine and the target machine usable.
4. WHEN migration completes on the target machine, THE Migration_Wizard SHALL verify the integrity of the exported Local_Store data and SHALL import the verified data into the target machine's Local_Store.
5. WHEN the 48-hour overlap window elapses, THE Migration_Wizard SHALL deactivate the source machine and SHALL set the source machine to require reactivation before further use.
6. IF the exported deactivation token is invalid or its 48-hour validity window has elapsed when a user attempts activation on the target machine, THEN THE Migration_Wizard SHALL reject the activation, report an indication that identifies the rejection reason, and leave the target machine unactivated.
7. IF the exported Local_Store data fails integrity verification during import on the target machine, THEN THE Migration_Wizard SHALL abort the import, preserve the target machine's existing Local_Store unchanged, and report an indication that the migration data cannot be imported.

### Requirement 15: LAN Multi-Device Operation

**User Story:** As a shop with multiple counters, I want secondary devices to share the primary machine's data over the local network, so that several terminals can bill without internet.

#### Acceptance Criteria

1. THE LAN_Coordinator SHALL designate exactly one Primary_Device that holds the authoritative Local_Store for the local network deployment.
2. WHEN a Secondary_Device connects, THE LAN_Coordinator SHALL connect the Secondary_Device to the Primary_Device's Local_Backend over the local network using the Primary_Device IP address and an authenticated session, and SHALL complete or abandon the connection attempt within 10 seconds.
3. THE LAN_Coordinator SHALL operate without internet access.
4. IF the Primary_Device is unreachable on the local network, THEN the LAN_Coordinator on the Secondary_Device SHALL report the connection failure to the service layer regardless of the previously reported connection status.
5. THE LAN_Coordinator SHALL limit the deployment so that the count of concurrently connected Secondary_Devices plus the Primary_Device does not exceed the device allowance configured for the license.
6. WHILE a Secondary_Device cannot reach the Primary_Device on the local network, THE LAN_Coordinator on the Secondary_Device SHALL prevent the Secondary_Device from creating or modifying records in the Primary_Device's Local_Store.

### Requirement 16: Local Data Scale

**User Story:** As a high-volume business, I want the local database to stay fast as data grows, so that performance does not degrade after years of use.

#### Acceptance Criteria

1. THE Local_Store SHALL archive records older than 2 years into an archive store.
2. THE Local_Store SHALL maintain indexes on the columns used by high-frequency queries.
3. WHEN the Local_Store contains 1 million records in a queried table, THE Local_Store SHALL return any indexed query result within 400 milliseconds.

### Requirement 17: Security Controls

**User Story:** As a security-conscious owner, I want strong encryption and access controls on the offline installation, so that my data and license cannot be stolen or bypassed.

#### Acceptance Criteria

1. THE Security_Layer SHALL encrypt the Local_Store using SQLCipher with AES-256.
2. THE Security_Layer SHALL derive all encryption keys from the Fingerprint_Hash and the application secret at runtime and SHALL NOT store encryption keys in source code.
3. THE Security_Layer SHALL encrypt the Local_License_File using AES-256-GCM.
4. THE Security_Layer SHALL hash passwords using bcrypt with a work factor of 12.
5. THE Security_Layer SHALL sign local JWTs using RS256 and SHALL store the signing key in the operating system keychain.
6. THE Security_Layer SHALL bind the Local_Backend exclusively to the Loopback_Address.
7. THE Local_Backend SHALL require valid authentication credentials on every endpoint except the health-check endpoint.
8. THE Local_Backend SHALL validate all request inputs using schema validation before processing them.
9. THE Local_Backend SHALL execute all database access using parameterized SQL statements.
10. THE Security_Layer SHALL exclude secrets and license keys from all log output.
11. WHEN DukanX_App starts in Offline_Lifetime_Mode, THE Security_Layer SHALL verify the integrity of the Local_License_File before use.
12. IF the Local_Store is detected as swapped or tampered, THEN THE Security_Layer SHALL permit read-only access for forensic inspection while preventing all write operations on the Local_Store, and SHALL report the tamper condition.
13. IF a license key presented for activation is listed in the existing license denylist, THEN THE Security_Layer SHALL reject the license key and SHALL prevent activation.
14. IF a request to any endpoint other than the health-check endpoint is received without valid authentication credentials, THEN THE Local_Backend SHALL reject the request without executing the requested operation and SHALL return an error response indicating that authentication is required.
15. IF a request input fails schema validation, THEN THE Local_Backend SHALL reject the request without persisting any data and SHALL return an error response indicating the validation failure.
16. IF the integrity verification of the Local_License_File fails, THEN THE Security_Layer SHALL prevent use of the Local_License_File and SHALL report the integrity-verification failure.

### Requirement 18: Application Updates

**User Story:** As a user, I want to control when updates install while still receiving critical fixes, so that updates do not interrupt my work but security patches are not missed.

#### Acceptance Criteria

1. WHEN the user triggers an update check, THE Update_Service SHALL check for available updates in the background.
2. WHERE an available update is a mandatory security patch, THE Update_Service SHALL require the update to be applied.
3. WHERE an available update is not a mandatory security patch, THE Update_Service SHALL allow the user to defer the update.
4. WHERE an available update is a mandatory security patch, THE Update_Service SHALL not allow the user to defer the update.
5. THE Update_Service SHALL apply updates without modifying the Local_Store data.

### Requirement 19: Performance Targets

**User Story:** As a cashier, I want the application to respond quickly, so that billing and lookups feel instant during a busy counter.

#### Acceptance Criteria

1. WHEN DukanX_App performs a cold start, THE DukanX_App SHALL become usable within 4 seconds and SHALL not exceed 8 seconds.
2. WHEN DukanX_App performs a warm start, THE DukanX_App SHALL become usable within 1.5 seconds and SHALL not exceed 3 seconds.
3. WHEN a user creates a bill, THE Local_Backend SHALL complete bill creation within 300 milliseconds and SHALL not exceed 500 milliseconds.
4. WHEN a user searches products in a catalog of 10,000 or more items, THE Local_Backend SHALL return results within 200 milliseconds and SHALL not exceed 400 milliseconds.
5. WHEN a user generates a 30-day report, THE Local_Backend SHALL produce the report within 2 seconds and SHALL not exceed 5 seconds.
6. WHEN a user generates an invoice PDF, THE Local_Backend SHALL produce the PDF within 1 second and SHALL not exceed 2 seconds.
7. WHEN the Local_Backend executes an indexed query, THE Local_Backend SHALL return the result within 50 milliseconds and SHALL not exceed 100 milliseconds.
8. WHEN the Local_Store contains 1 million records, THE Local_Backend SHALL keep every query under 400 milliseconds.

### Requirement 20: Platform Support

**User Story:** As a desktop user on any major OS, I want the offline app to run on my platform, so that I can use DukanX regardless of operating system.

#### Acceptance Criteria

1. THE DukanX_App SHALL run in Offline_Lifetime_Mode on Windows.
2. THE DukanX_App SHALL run in Offline_Lifetime_Mode on macOS.
3. THE DukanX_App SHALL run in Offline_Lifetime_Mode on Linux.
4. THE Activation_Service SHALL store the Local_License_File in the OS-specific secure location appropriate to Windows, macOS, and Linux.
