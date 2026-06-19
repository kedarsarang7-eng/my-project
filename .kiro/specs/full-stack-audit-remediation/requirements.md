# Requirements Document

## Introduction

DukanX is a multi-tenant SaaS billing and commerce platform serving Indian SMBs across 19+ business verticals. The platform has grown to 460+ screens with inconsistent production-readiness: many screens use mock data, lack offline support, have broken navigation, or miss tenant isolation. This Full-Stack Audit and Remediation System provides a structured methodology to discover all issues, triage them by severity, and systematically fix every screen, API endpoint, and offline flow until the entire platform is production-ready with zero mock data.

## Glossary

- **Audit_Engine**: The automated tooling and manual processes that scan the Flutter codebase, Lambda handlers, and DynamoDB access patterns to identify production-readiness gaps
- **Triage_System**: The priority classification mechanism that assigns P0–P3 severity levels to discovered issues
- **Screen_Fix_Protocol**: The standardized six-step remediation procedure applied to each screen (trace data source → connect API → implement offline → enforce tenant isolation → fix UI → validate E2E)
- **Offline_Queue**: The SQLite-backed mutation queue that stores write operations performed while the device is disconnected, replaying them upon reconnection
- **Tenant_Isolation_Layer**: The security boundary in DynamoDB single-table design ensuring one tenant cannot read or modify another tenant's data
- **Discovery_Registry**: The central inventory that catalogs all screens, API endpoints, navigation routes, and DynamoDB access patterns across the platform
- **Vertical**: A specific business type supported by DukanX (e.g., Restaurant, Pharmacy, Petrol Pump, Jewellery, Clinic, Academic Coaching, Clothing, Hardware, Book Store, Computer Shop, Decoration/Catering, Auto Parts, Vegetable Broker)
- **KPI_Card**: A dashboard widget displaying a key performance indicator with real-time or cached data
- **Sync_Cycle**: The full offline-to-online lifecycle: local read → offline mutation queuing → reconnect detection → conflict resolution → server sync → local state update
- **Lambda_Handler**: A single AWS Lambda function in `my-backend/src/handlers/` or `lambda/` that serves one or more API routes
- **E2E_Validation**: End-to-end testing that verifies a screen works correctly from UI interaction through API call to database persistence and back

## Requirements

### Requirement 1: Screen Discovery and Inventory

**User Story:** As a platform engineer, I want an automated inventory of every screen in the Flutter codebase, so that I can track remediation progress across all 460+ screens.

#### Acceptance Criteria

1. WHEN the Audit_Engine scans the Flutter project, THE Discovery_Registry SHALL catalog every Dart file containing a class that extends StatelessWidget or StatefulWidget where the class name or the file path contains "screen" or "page" (case-insensitive match)
2. WHEN a screen is cataloged, THE Discovery_Registry SHALL record the screen name, file path, associated Vertical (derived from the feature folder name under `lib/features/`; files outside `lib/features/` SHALL use "core/general"), and production-readiness status fields: MockData (True/False), MockReasons (comma-separated list of detected mock indicators, or empty string if none), ApiConnected (True/False), OfflineReady (True/False), UiConsistent (True/False), NavWired (True/False)
3. THE Discovery_Registry SHALL output the inventory in CSV format with columns: Project, Feature, FileName, RelativePath, BusinessTypes, MockData, MockReasons, ApiConnected, OfflineReady, UiConsistent, NavWired, Priority — where Priority is one of "High", "Medium", or "Low" assigned based on whether the screen is a dashboard or entry-point (High), a standard feature screen with navigation wired (Medium), or a secondary/utility screen (Low)
4. WHEN a new screen file is added to the codebase, THE Audit_Engine SHALL detect the addition and append it to the Discovery_Registry within the next scan cycle
5. WHEN a previously cataloged screen file is deleted or renamed in the codebase, THE Audit_Engine SHALL mark the corresponding entry as removed or update its file path in the Discovery_Registry within the next scan cycle
6. IF the Audit_Engine encounters a Dart file matching the naming pattern but containing no valid StatelessWidget or StatefulWidget class declaration, THEN THE Audit_Engine SHALL exclude the file from the Discovery_Registry and log it as a skipped false-positive

### Requirement 2: API Surface Mapping

**User Story:** As a platform engineer, I want a complete map of every API endpoint and its consumer screens, so that I can identify disconnected or orphaned endpoints.

#### Acceptance Criteria

1. WHEN the Audit_Engine scans the backend, THE Discovery_Registry SHALL catalog every route defined in `my-backend/serverless.yml` and `template.yaml` with its HTTP method, path, handler file, and authentication status (authenticated or unauthenticated based on whether an authorizer is configured for the route)
2. WHEN the Audit_Engine scans the Flutter codebase, THE Discovery_Registry SHALL identify every HTTP request call site (including calls through HTTP client classes and service wrapper methods) and map it to a backend route by matching the request path against cataloged route paths, treating path parameters (e.g., `{id}`) as wildcards
3. IF a screen references an API endpoint path that does not match any cataloged backend route path after path-parameter normalization, THEN THE Audit_Engine SHALL flag that screen as having a broken API dependency with P1 priority in the scan output report
4. IF a cataloged backend route has no matching API call site identified across the Flutter codebase, THEN THE Audit_Engine SHALL flag that route as orphaned with P2 priority in the scan output report
5. IF the Audit_Engine cannot parse a route definition file due to syntax errors or an unsupported format, THEN THE Audit_Engine SHALL skip the unparseable file, log a warning identifying the file path and parse error reason, and continue scanning remaining files
6. WHEN the scan completes, THE Audit_Engine SHALL produce a summary listing the total number of cataloged routes, the total number of mapped call sites, the count of broken dependencies, and the count of orphaned routes

### Requirement 3: Navigation Graph Mapping

**User Story:** As a platform engineer, I want a navigation graph showing how every screen connects, so that I can identify dead-end screens and broken navigation paths.

#### Acceptance Criteria

1. WHEN the Audit_Engine scans the Flutter codebase, THE Discovery_Registry SHALL build a directed graph of all navigation transitions (Navigator.push, Navigator.pushNamed, GoRouter routes, context.go, context.push, named routes) starting from the app's root route as the reachability root
2. IF a screen has no inbound navigation path from any screen reachable from the root route, THEN THE Audit_Engine SHALL flag it as unreachable with P2 priority, including the screen name and file path in the finding
3. IF a screen references a navigation route string that does not resolve to any registered screen in the router configuration, THEN THE Audit_Engine SHALL flag it as having a broken navigation link with P1 priority, including the unresolved route string and source location
4. THE Discovery_Registry SHALL output the navigation graph as an adjacency list mapping each screen identifier to its outbound navigation targets, grouped by Vertical-specific entry points and their sub-screen hierarchies

### Requirement 4: DynamoDB Access Pattern Mapping

**User Story:** As a platform engineer, I want a catalog of every DynamoDB access pattern, so that I can verify tenant isolation and identify inefficient queries.

#### Acceptance Criteria

1. WHEN the Audit_Engine scans the backend handlers, THE Discovery_Registry SHALL catalog every DynamoDB operation (get, put, query, scan, update, delete) with its table name, key conditions, filter expressions, and the source handler file and line number where the operation is defined
2. WHEN a DynamoDB operation is cataloged, THE Discovery_Registry SHALL verify that the partition key condition or filter expression references a tenant identifier, defined as a key or attribute whose name matches a configurable pattern (default: `tenantId` or `tenant_id`)
3. IF a DynamoDB operation does not reference a tenant identifier in its partition key condition or filter expression, THEN THE Audit_Engine SHALL flag it as a P0 security issue with the table name, operation type, and source location included in the finding
4. IF a DynamoDB scan operation is used and the table's partition key value is determinable from variables in scope within the same handler, THEN THE Audit_Engine SHALL flag it as a P2 performance issue recommending a query operation instead
5. IF a DynamoDB operation uses a dynamically constructed table name or key condition that cannot be statically resolved, THEN THE Audit_Engine SHALL flag it as a P1 audit-incomplete issue requiring manual review

### Requirement 5: Issue Triage and Priority Classification

**User Story:** As a project manager, I want all discovered issues classified by severity, so that the team can address critical problems first.

#### Acceptance Criteria

1. THE Triage_System SHALL classify issues into four priority levels: P0 (security/data-leak, fix immediately), P1 (blocking user flow, fix within 24 hours), P2 (degraded experience, fix within 1 week), P3 (cosmetic/enhancement, fix within 2 weeks)
2. WHEN an issue involves tenant data leakage or missing tenant isolation, THE Triage_System SHALL assign P0 priority
3. WHEN an issue involves a screen displaying mock data to end users in production, THE Triage_System SHALL assign P1 priority
4. WHEN an issue involves broken navigation preventing users from reaching a feature, THE Triage_System SHALL assign P1 priority
5. WHEN an issue involves missing offline mode on a screen that performs write operations, THE Triage_System SHALL assign P2 priority
6. WHEN an issue involves UI inconsistency (wrong theme, broken layout, non-responsive design), THE Triage_System SHALL assign P3 priority
7. IF an issue matches multiple priority criteria, THEN THE Triage_System SHALL assign the highest (most severe) priority among the matching criteria
8. IF an issue does not match any of the specific criteria in items 2–6, THEN THE Triage_System SHALL assign P3 priority as the default classification
9. THE Triage_System SHALL generate a summary report on each scan completion, grouping issues by priority level with total counts per Vertical and overall totals per priority

### Requirement 6: Mock Data Elimination

**User Story:** As a product owner, I want zero mock or dummy data visible in any production screen, so that users always see real business data.

#### Acceptance Criteria

1. WHEN the Audit_Engine scans a screen file, THE Audit_Engine SHALL detect mock data patterns including: hardcoded sample data arrays with 2 or more literal entries, TODO/placeholder comments indicating fake data, imports from files whose path contains "mock", "dummy", "fake", or "sample", and conditional logic that returns inline literal data when an API call or query reference is absent
2. WHEN mock data is detected in a screen, THE Screen_Fix_Protocol SHALL produce a mapping that associates each detected mock data usage with the corresponding real API endpoint or local database query that should supply the data
3. IF the Screen_Fix_Protocol cannot identify a real data source for a detected mock data usage, THEN THE Screen_Fix_Protocol SHALL flag the occurrence as "unresolved" in the audit report and halt replacement for that data usage until a real source is manually specified
4. WHEN a screen's mock data is replaced, THE Screen_Fix_Protocol SHALL verify that the screen renders a designated empty-state widget displaying a "no data available" message and no unhandled exceptions when the real data source returns zero records
5. THE Audit_Engine SHALL maintain a mock-data-free assertion that fails the CI pipeline if any new mock data pattern is introduced in files outside directories named "test", "test_*", "mocks", or files with a "_test.dart" suffix

### Requirement 7: Real API Connection

**User Story:** As a developer, I want every screen connected to its real backend API, so that data flows end-to-end without hardcoded values.

#### Acceptance Criteria

1. WHEN a screen is identified as using hardcoded, mock, or static data instead of calling a repository method, THE Screen_Fix_Protocol SHALL identify the correct API endpoint from the Discovery_Registry's API surface map by matching the screen's data entity type to a registered endpoint that serves that entity
2. WHEN connecting a screen to its API, THE Screen_Fix_Protocol SHALL implement a loading state (visual indicator displayed while awaiting the API response), an error state (message displayed when the API call fails after all retry attempts), and retry logic with a maximum of 3 retry attempts using exponential backoff starting at 1 second delay
3. WHEN connecting a screen to its API, THE Screen_Fix_Protocol SHALL use the existing repository pattern (feature-specific repository class calling the core API service via ApiClient)
4. IF a required API endpoint does not exist in the backend, THEN THE Screen_Fix_Protocol SHALL create the endpoint following the project's handler pattern in `my-backend/src/handlers/` using the `authorizedHandler` wrapper with input validation, tenant context extraction from the auth object, and structured error responses via the response utility module
5. IF an API call returns a non-success response after all retry attempts are exhausted, THEN THE Screen_Fix_Protocol SHALL display the error state to the user and preserve any user-entered data on the screen without clearing form fields or navigation state

### Requirement 8: Offline Mode Implementation

**User Story:** As an SMB operator working in areas with unreliable internet, I want every data-entry screen to work offline, so that I can continue billing and managing inventory without connectivity.

#### Acceptance Criteria

1. WHEN a screen performs read operations, THE Screen_Fix_Protocol SHALL implement local SQLite caching so the screen renders from cache when offline
2. WHEN a screen performs write operations while offline, THE Offline_Queue SHALL store the mutation with timestamp, operation type, payload, and retry count, up to a maximum of 5000 queued mutations per device
3. WHEN network connectivity is restored, THE Offline_Queue SHALL replay queued mutations in chronological order within 60 seconds per batch of 50 mutations, and handle conflicts using last-write-wins with server timestamp comparison
4. IF a queued mutation fails during sync (server rejects due to conflict or validation), THEN THE Offline_Queue SHALL retain the failed mutation, increment its retry count, and after 3 failed attempts display a persistent notification listing the failed operation type, affected record identifier, and failure reason, allowing the user to retry or discard
5. WHILE the device is offline, THE Screen_Fix_Protocol SHALL display a visible offline indicator and disable actions that require real-time server confirmation, specifically: payment processing, account deletion, and subscription changes
6. THE Offline_Queue SHALL encrypt all cached data using SQLCipher with the tenant-specific encryption key
7. IF a screen is accessed offline and no cached data exists for that screen, THEN THE Screen_Fix_Protocol SHALL display an informational message indicating that data is unavailable until the first successful sync, and restrict the screen to write-only operations where applicable
8. IF the Offline_Queue reaches its maximum capacity of 5000 mutations, THEN THE Offline_Queue SHALL reject new write operations and display a warning message indicating that the queue is full and connectivity is required to sync pending changes

### Requirement 9: Tenant Isolation Enforcement

**User Story:** As a security engineer, I want every API call and database query scoped to the authenticated tenant, so that no tenant can access another tenant's data.

#### Acceptance Criteria

1. THE Tenant_Isolation_Layer SHALL inject the tenant identifier from the authenticated session into every DynamoDB operation's key condition, including query, get-item, put-item, update-item, and delete-item operations
2. WHEN a Lambda_Handler processes a request, THE Tenant_Isolation_Layer SHALL extract the tenant ID from the Cognito JWT claims and reject the request with HTTP 403 if the tenant ID claim is absent, empty, or does not match the expected format of a non-empty string with a maximum length of 128 characters containing only alphanumeric characters, hyphens, and underscores
3. IF a request includes a resource identifier whose tenant partition key does not match the authenticated tenant's ID, THEN THE Tenant_Isolation_Layer SHALL return HTTP 403, discard the operation without modifying any data, and log a security event containing the authenticated tenant ID, the target resource identifier, the attempted operation type, and a timestamp
4. IF the Tenant_Isolation_Layer fails to resolve or inject the tenant identifier into a DynamoDB operation, THEN THE Tenant_Isolation_Layer SHALL reject the operation with HTTP 500 and log the failure as a security event without executing the database call
5. THE Tenant_Isolation_Layer SHALL apply tenant scoping at the repository layer such that all DynamoDB operations are accessible only through tenant-scoped repository methods, and no Lambda_Handler can invoke DynamoDB operations directly without passing through the repository layer
6. WHEN the Audit_Engine performs a deployment-time static analysis of a Lambda_Handler, THE Audit_Engine SHALL verify that no raw DynamoDB client call bypasses the tenant-scoped repository methods, and IF a bypass is detected, THEN THE Audit_Engine SHALL fail the deployment and report the violating handler name and call location

### Requirement 10: UI Audit and Consistency

**User Story:** As a UX designer, I want every screen following the same design system, so that the app feels cohesive across all 19+ verticals.

#### Acceptance Criteria

1. THE Screen_Fix_Protocol SHALL verify each screen against the UI checklist: sidebar navigation uses the shared EnterpriseDesktopSidebar widget on desktop and MobileDrawer on mobile, KPI displays use the standardized KpiCard component from features/shared/widgets, data lists use the shared DataTable/ListView pattern, forms use the FormFields widgets from core/forms, and buttons use only the theme-defined ElevatedButton, OutlinedButton, TextButton, or IconButton styles without inline ButtonStyle overrides
2. WHEN a screen uses a custom layout that does not match the responsive breakpoint system (mobile < 600px, tablet 600–1100px, desktop ≥ 1100px as defined in ResponsiveBreakpoints), THE Screen_Fix_Protocol SHALL refactor it to use the core ResponsiveLayout wrapper or AdaptiveScaffold so that the screen renders a distinct layout per form factor
3. WHEN a screen's typography, color usage, or spacing does not match the app theme, THE Screen_Fix_Protocol SHALL replace hardcoded values with theme references (Theme.of(context).textTheme, Theme.of(context).colorScheme, Theme.of(context).elevatedButtonTheme), where a hardcoded value is defined as any inline Color literal, TextStyle literal, or numeric padding/margin that duplicates a value already available in the theme
4. THE Screen_Fix_Protocol SHALL ensure all screens pass accessibility checks: minimum touch target size of 48x48dp, text contrast ratio of 4.5:1 minimum for normal text and 3:1 minimum for large text (18sp or 14sp bold), and semantic labels on all interactive elements
5. IF a screen fails one or more UI checklist items from criteria 1–4, THEN THE Screen_Fix_Protocol SHALL log each violation with the screen name, the failed checklist item, and the specific widget or line reference, and mark the screen as non-compliant until all violations are resolved

### Requirement 11: Backend Lambda Audit

**User Story:** As a backend engineer, I want every Lambda function reviewed for security, error handling, and performance, so that the API layer is production-hardened.

#### Acceptance Criteria

1. WHEN the Audit_Engine reviews a Lambda_Handler, THE Audit_Engine SHALL verify: input validation using Zod or equivalent schema library that enforces type and constraint checks, structured error responses containing a correlation ID field, HTTP status codes matching the response condition (4xx for client errors, 5xx for server errors, 2xx for success), and request/response logging that records method, path, status code, and duration
2. WHEN the Audit_Engine reviews a Lambda_Handler that performs 2 or more DynamoDB read or write operations on the same table within a single invocation, THE Audit_Engine SHALL verify that batch operations (BatchGetItem for multiple reads, BatchWriteItem for multiple writes) are used instead of sequential calls
3. IF a Lambda_Handler catches errors with a catch block that neither re-throws, returns an error response with a specific error category, nor logs the error type and message, THEN THE Audit_Engine SHALL flag it as P2 for inadequate error handling
4. IF a Lambda_Handler performs DynamoDB operations without using the shared repository layer, THEN THE Audit_Engine SHALL flag it as P1 for potential tenant isolation bypass
5. WHEN the Audit_Engine reviews a Lambda_Handler, THE Audit_Engine SHALL verify that sensitive data (passwords, authentication tokens, refresh tokens, email addresses, phone numbers, and government-issued identifiers) is not logged in plaintext
6. IF a Lambda_Handler fails verification of input validation, error response structure, status code correctness, or request/response logging as defined in criterion 1, THEN THE Audit_Engine SHALL flag it as P1 for missing security or observability controls
7. IF a Lambda_Handler fails the batch operation check as defined in criterion 2, THEN THE Audit_Engine SHALL flag it as P2 for suboptimal DynamoDB performance

### Requirement 12: Vertical-Specific Validation

**User Story:** As a vertical product manager, I want each business type's screens validated against its domain-specific workflows, so that Restaurant operators see menu management, Pharmacy operators see drug schedules, and Clinic operators see patient queues.

#### Acceptance Criteria

1. WHEN the Audit_Engine validates a Vertical, THE Audit_Engine SHALL verify that every domain-specific screen registered for that Vertical has a navigable route reachable within 3 navigation actions from its dashboard entry point, and SHALL report each unreachable screen as a validation failure with the screen name and expected route
2. WHEN the Audit_Engine validates a Vertical, THE Audit_Engine SHALL verify that each Vertical-specific data model (e.g., Restaurant menu items, Pharmacy drug batches, Clinic appointments) has at least one corresponding API endpoint for CRUD operations and at least one offline cache table, and SHALL report any model lacking either as a validation failure
3. IF a Vertical's dashboard screen displays KPI_Cards, THEN THE Audit_Engine SHALL verify each KPI_Card references a data-source query that retrieves live aggregated data rather than returning a static literal value, and SHALL flag any KPI_Card backed by a hardcoded constant
4. WHEN the Audit_Engine validates a Vertical, THE Audit_Engine SHALL execute the Vertical's critical user journey using the Vertical's primary entity (Restaurant: menu item, Pharmacy: drug batch, Clinic: appointment, Petrol Pump: fuel sale, Jewellery: custom order, Academic Coaching: student, Clothing: tailoring order, Hardware: dimension item, Book Store: book, Computer Shop: job card, Decoration/Catering: quote, Auto Parts: job card, Vegetable Broker: lot, General Retail: product) through the sequence: create entity → list entities → edit entity → generate report → export/print
5. THE Audit_Engine SHALL validate each of the following Verticals independently in a separate validation run with isolated test data: Restaurant, Pharmacy, Petrol Pump, Jewellery, Clinic, Academic Coaching, Clothing, Hardware, Book Store, Computer Shop, Decoration/Catering, Auto Parts, Vegetable Broker, and General Retail
6. IF any step in a Vertical's critical user journey fails or a domain-specific screen is unreachable, THEN THE Audit_Engine SHALL mark that Vertical's validation as failed, record the failing step or screen identifier, and continue validating the remaining Verticals without aborting the overall audit run

### Requirement 13: Code Quality Standards Enforcement

**User Story:** As a tech lead, I want automated enforcement of coding standards, so that new code maintains production quality and existing violations are tracked for remediation.

#### Acceptance Criteria

1. THE Audit_Engine SHALL enforce TypeScript strict mode (`strict: true` in tsconfig.json) for all backend code with zero `any` type usage unless the line is annotated with a `// @allow-any: <justification>` comment
2. THE Audit_Engine SHALL enforce Flutter analysis rules: no unused imports, no unused variables, prefer const constructors, and require explicit type annotations on all public class members (public methods, properties, and top-level function signatures)
3. WHEN the Audit_Engine scans a repository class, THE Audit_Engine SHALL verify that a corresponding test file exists containing at least one test exercising a successful return value and at least one test exercising an error or exception path
4. THE Audit_Engine SHALL enforce performance requirements: no synchronous DynamoDB calls in request-handling code paths (Lambda handler functions and their direct call chain), no list or scan operations without a `Limit` parameter or pagination token, and no loops that issue a database call per iteration without batching
5. THE Audit_Engine SHALL generate a code quality score per feature module on a 0–100 scale calculated as the equally-weighted average of: percentage of screens with at least one widget test, percentage of handlers with input validation on all required parameters, and percentage of screens passing the responsive layout checklist
6. WHEN the Audit_Engine detects a violation in new code (code changed in the current commit), THE Audit_Engine SHALL report the violation as a blocking finding that prevents merge until resolved
7. WHEN the Audit_Engine detects a violation in existing code (code unchanged in the current commit), THE Audit_Engine SHALL report the violation as a non-blocking finding and add it to the remediation backlog with the file path, rule violated, and detection date
8. IF the Audit_Engine cannot determine whether a violation is in new or existing code, THEN THE Audit_Engine SHALL treat the violation as a blocking finding

### Requirement 14: E2E Validation Protocol

**User Story:** As a QA engineer, I want an end-to-end validation protocol for each remediated screen, so that fixes are verified across the full data flow.

#### Acceptance Criteria

1. WHEN a screen completes the Screen_Fix_Protocol, THE E2E_Validation SHALL execute a test transaction through the full data flow (user action → Flutter state update → API request → Lambda handler → DynamoDB operation → response → Flutter state update → UI render) and SHALL mark the step as passed only if each stage produces an observable output within 30 seconds of the preceding stage completing
2. WHEN a screen completes offline mode implementation, THE E2E_Validation SHALL execute a test transaction through the Sync_Cycle (offline write → queue storage → reconnect → sync replay → server persistence → local cache update) and SHALL mark the step as passed only if the queued operation reaches server persistence within 60 seconds of reconnection and the local cache reflects the server-confirmed state
3. WHEN a screen completes tenant isolation enforcement, THE E2E_Validation SHALL send an authenticated request using Tenant A's token attempting to access Tenant B's data, and SHALL mark the step as passed only if the system returns an authorization error response containing no Tenant B data
4. IF E2E_Validation fails for a remediated screen, THEN THE Screen_Fix_Protocol SHALL reopen the screen's issue within 5 minutes of failure detection, assign P1 priority, and include failure details specifying: the failed stage name, the input data used, the expected outcome, the actual outcome, and a timestamp
5. IF any stage in the E2E data flow does not produce an observable output within 30 seconds, THEN THE E2E_Validation SHALL mark that stage as failed and record a timeout indication with the stage name and elapsed duration

### Requirement 15: Remediation Progress Tracking

**User Story:** As a stakeholder, I want real-time visibility into remediation progress, so that I can track how many screens are production-ready and what remains.

#### Acceptance Criteria

1. THE Discovery_Registry SHALL maintain a per-screen status with values: Not Started, In Progress, Remediated, Validated, and Blocked, where valid transitions are: Not Started → In Progress, In Progress → Remediated, In Progress → Blocked, Blocked → In Progress, Remediated → Validated, and Validated → Remediated
2. WHEN a screen's status changes, THE Discovery_Registry SHALL update the inventory file and record the timestamp and a mandatory reason for the change, where the reason is a non-empty string of at most 500 characters
3. IF a status change is attempted with an empty reason or to a transition not in the valid set, THEN THE Discovery_Registry SHALL reject the change, preserve the current status, and return an error message indicating the specific validation failure
4. THE Discovery_Registry SHALL generate a progress summary in the inventory file showing per Vertical: total screens, screens in each status (Not Started, In Progress, Remediated, Validated, Blocked), and for each Blocked screen the associated blocking reason
5. THE Discovery_Registry SHALL calculate an overall platform readiness percentage as (Validated screens / Total screens) × 100, rounded to 1 decimal place, where Total screens includes screens in all statuses including Blocked
