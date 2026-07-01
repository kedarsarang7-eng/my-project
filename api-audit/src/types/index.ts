/**
 * Shared domain types and artifact interfaces for the Audit_System.
 *
 * These types define the contracts exchanged between pipeline stages
 * (discovery, documentation, generation, running, auditing, coverage,
 * reporting). They are the single source of truth for artifact shapes and
 * mirror the interfaces described in the design document.
 */

// ---------------------------------------------------------------------------
// Domain classification (Requirement 1.6)
// ---------------------------------------------------------------------------

/**
 * Functional grouping an endpoint is classified into. Discovery classifies
 * every endpoint into exactly one Domain drawn from this set.
 */
export type Domain =
  | 'Authentication'
  | 'Authorization/RBAC'
  | 'Users'
  | 'Customers'
  | 'Products'
  | 'Inventory'
  | 'Billing'
  | 'Invoices'
  | 'Reports'
  | 'Search'
  | 'Settings'
  | 'License'
  | 'Subscription'
  | 'File-Transfer'
  | 'GraphQL'
  | 'WebSocket'
  | 'Admin'
  | 'AWS-Integrated'
  | 'Internal-Service';

// ---------------------------------------------------------------------------
// Discovery types (Requirements 1.6, 1.7, 1.8)
// ---------------------------------------------------------------------------

/** The kind of endpoint surface an entry represents. */
export type EndpointKind =
  | 'rest'
  | 'graphql-query'
  | 'graphql-mutation'
  | 'graphql-subscription'
  | 'ws-route'
  | 'ws-event';

/** A reference to the source an endpoint was discovered from (Requirement 1.7). */
export interface SourceRef {
  /** Source file path the endpoint was identified from. */
  filePath: string;
  /** Whether the endpoint came from application code or configuration. */
  artifactType: 'code' | 'configuration';
  /** Optional template key / OpenAPI operationId / line reference. */
  locator?: string;
}

/** The identity used to deduplicate endpoints across sources (Requirement 1.8). */
export interface EndpointIdentity {
  kind: EndpointKind;
  /** For REST: GET/POST/... */
  method?: string;
  /** Normalized route path or operation name. */
  path?: string;
  /** GraphQL/WebSocket operation or event name. */
  operationName?: string;
}

/** A single deduplicated endpoint in the inventory. */
export interface InventoryEntry {
  /** Stable hash of the EndpointIdentity. */
  id: string;
  identity: EndpointIdentity;
  /** Classified domain (Requirement 1.6). */
  domain: Domain;
  /** All contributing sources (Requirement 1.8). */
  sources: SourceRef[];
}

/** The complete, deduplicated inventory of discovered endpoints. */
export interface ApiInventory {
  /** Entries sorted deterministically by id (Requirement 1.9). */
  entries: InventoryEntry[];
  /** Non-fatal issues recorded while scanning continued (Requirement 1.10). */
  issues: StageIssue[];
}

/** A non-fatal problem recorded by a stage that continued processing. */
export interface StageIssue {
  stage: string;
  filePath?: string;
  endpointId?: string;
  reason: string;
}

// ---------------------------------------------------------------------------
// Documentation types (Requirements 2.2-2.6)
// ---------------------------------------------------------------------------

/** A value that is either concretely determined or explicitly undetermined. */
export type Determinable<T> = T | 'undetermined';

/** A single request/response parameter. */
export interface ParamSpec {
  name: string;
  in: 'body' | 'query' | 'path' | 'header';
  type?: string;
  required: boolean;
}

/** A documented error response for an endpoint. */
export interface ErrorResponse {
  status: number;
  code?: string;
  description?: string;
}

/** An input validation rule applied to a field. */
export interface ValidationRule {
  field: string;
  rule: string;
}

/** A business rule that applies to an endpoint. */
export interface BusinessRule {
  id: string;
  description: string;
}

/**
 * A JSON Schema fragment describing a request or response body. Kept as an
 * open record because schemas are arbitrary, source-derived structures.
 */
export type JsonSchema = Record<string, unknown>;

/** Security enforcement metadata; never empty, defaults to `public`. */
export interface SecurityMeta {
  enforcement: 'public' | 'authenticated' | 'authorized';
  requiredRole?: string;
  requiredPermission?: string;
}

/** Per-endpoint documentation entry produced by the Documentation_Engine. */
export interface CatalogEntry {
  /** Matches InventoryEntry.id. */
  id: string;
  urlPath: Determinable<string>;
  methodOrOperation: Determinable<string>;
  module: Determinable<string>;
  controllerOrHandler: Determinable<string>;
  requestBodyParams: Determinable<ParamSpec[]>;
  queryParams: Determinable<ParamSpec[]>;
  pathParams: Determinable<ParamSpec[]>;
  headers: Determinable<ParamSpec[]>;
  /** `public` when no enforcement is present (Requirement 2.4). */
  security: SecurityMeta;
  requestSchema: Determinable<JsonSchema>;
  responseSchema: Determinable<JsonSchema>;
  errorResponses: Determinable<ErrorResponse[]>;
  validationRules: Determinable<ValidationRule[]>;
  businessRules: Determinable<BusinessRule[]>;
  /** Field name -> reason it could not be determined (Requirement 2.7). */
  undeterminedReasons: Record<string, string>;
}

// ---------------------------------------------------------------------------
// Postman generation types (Requirements 3.1, 3.3)
// ---------------------------------------------------------------------------

/** A Postman v2.1 request item. */
export interface PostmanRequest {
  name: string;
  /** Id of the catalog endpoint this request represents. */
  endpointId: string;
  method: string;
  /** Request URL, expressed with Postman variable references. */
  url: string;
  headers?: { key: string; value: string }[];
  body?: unknown;
  /** Attached Postman test scripts (populated by the Test_Generator). */
  tests?: GeneratedTest[];
}

/** A Postman folder grouping requests for a single domain. */
export interface PostmanFolder {
  name: Domain;
  items: PostmanRequest[];
}

/** A generated Postman Collection Format v2.1 collection. */
export interface PostmanCollection {
  info: { schema: 'v2.1.0' };
  folders: PostmanFolder[];
}

/** A generated per-environment Postman environment file. */
export interface PostmanEnvironment {
  name: string;
  values: { key: string; value: string }[];
}

// ---------------------------------------------------------------------------
// Test generation types
// ---------------------------------------------------------------------------

/** A generated Postman test script attached to a request. */
export interface GeneratedTest {
  type:
    | 'status'
    | 'response-time'
    | 'schema'
    | 'auth'
    | 'authz'
    | 'validation'
    | 'business-rule'
    | 'positive'
    | 'negative-missing-field'
    | 'negative-invalid-value'
    | 'negative-bad-token'
    | 'negative-expired-token'
    | 'negative-no-permission'
    | 'negative-bad-id'
    | 'negative-bad-upload'
    | 'negative-malformed-graphql'
    | 'negative-malformed-ws';
  endpointId: string;
  /** Postman test script text. */
  script: string;
}

// ---------------------------------------------------------------------------
// Config types (Requirements 14.1, 14.5)
// ---------------------------------------------------------------------------

/** Resolved configuration for a single target environment. */
export interface EnvironmentConfig {
  name: 'Development' | 'Local' | 'Staging' | 'AWS' | 'Production';
  baseUrl: string;
  /** Required environment variable names only, never values. */
  requiredVars: string[];
  /** Values resolved from process.env, keyed by variable name. */
  variableValues: Map<string, string>;
}

/** Options controlling a single audit run. */
export interface RunOptions {
  /** Restrict the run to a subset of environments, when provided. */
  environments?: EnvironmentConfig['name'][];
  /** Output directory for generated artifacts. */
  outputDir?: string;
  /** Run without any interactive input. */
  nonInteractive?: boolean;
}

// ---------------------------------------------------------------------------
// Run / report types
// ---------------------------------------------------------------------------

/** The outcome of executing a single request. */
export interface RequestOutcome {
  endpointId: string;
  requestName: string;
  passed: boolean;
  assertionFailures: string[];
  responseTimeMs: number;
  statusCode?: number;
}

/** The aggregate result of running the collection against one environment. */
export interface RunResult {
  environment: EnvironmentConfig['name'];
  outcomes: RequestOutcome[];
  allPassed: boolean;
}

/**
 * A single row of the Local-vs-AWS comparison: one request that appeared in
 * the local run, the AWS run, or both (Requirement 11.4).
 *
 * Either outcome may be absent when the request only appears in one run. A row
 * is flagged `environmentSpecific` if and only if the request passed locally
 * and failed on AWS (Requirement 11.5).
 */
export interface RequestComparisonRow {
  /** The endpoint id this row is keyed on. */
  endpointId: string;
  /** Best-effort human-readable request name from whichever run reported it. */
  requestName: string;
  /** The local outcome, or undefined if the request only appears in the AWS run. */
  local?: RequestOutcome;
  /** The AWS outcome, or undefined if the request only appears in the local run. */
  aws?: RequestOutcome;
  /** True iff the request passed locally and failed on AWS (Requirement 11.5). */
  environmentSpecific: boolean;
}

/**
 * The Local-vs-AWS comparison artifact (Requirements 11.4, 11.5).
 *
 * Contains one row per request appearing in either run, plus the list of
 * endpoint ids classified as environment-specific issues.
 */
export interface LocalVsAwsComparison {
  /** One row per request appearing in the local run, the AWS run, or both. */
  rows: RequestComparisonRow[];
  /** Endpoint ids that passed locally but failed on AWS (Requirement 11.5). */
  environmentSpecificIssues: string[];
}

// ---------------------------------------------------------------------------
// Failed endpoint report and recommended fixes (Requirements 10.2, 10.3)
// ---------------------------------------------------------------------------

/**
 * A single failed request listed in the failed endpoint report.
 *
 * Mirrors the failing {@link RequestOutcome} exactly, carrying its assertion
 * failure detail so the report lists why each request failed (Requirement
 * 10.2).
 */
export interface FailedEndpointEntry {
  endpointId: string;
  requestName: string;
  /** The assertion failures reported for this request (Requirement 10.2). */
  assertionFailures: string[];
  responseTimeMs: number;
  statusCode?: number;
}

/**
 * The category a recommended fix addresses, derived from the request's
 * assertion failures and/or observed status code.
 */
export type FixCategory =
  | 'authentication'
  | 'authorization'
  | 'not-found'
  | 'validation'
  | 'server-error'
  | 'schema'
  | 'performance'
  | 'status-mismatch'
  | 'unknown';

/** A single actionable suggestion derived for a failed request. */
export interface FixSuggestion {
  category: FixCategory;
  /** Human-readable, actionable recommendation. */
  recommendation: string;
  /** The assertion text or status code that triggered this suggestion. */
  trigger: string;
}

/**
 * The recommended-fix entry for one failed request (Requirement 10.3).
 *
 * Exactly one entry exists per failed request; `suggestions` is keyed on the
 * request's assertion failures and status code and is never empty.
 */
export interface RecommendedFix {
  endpointId: string;
  requestName: string;
  suggestions: FixSuggestion[];
}

/**
 * The failed endpoint report deliverable (Requirements 10.2, 10.3).
 *
 * `failures` lists exactly the failed request outcomes (those with
 * `passed === false`) with their assertion-failure detail, and
 * `recommendedFixes` contains exactly one entry per failed request.
 */
export interface FailedEndpointReport {
  failures: FailedEndpointEntry[];
  recommendedFixes: RecommendedFix[];
}

/** A category of security vulnerability probed by the Security_Auditor. */
export type VulnCategory =
  | 'sql-injection'
  | 'nosql-injection'
  | 'xss'
  | 'csrf'
  | 'jwt'
  | 'broken-auth'
  | 'broken-authz'
  | 'idor'
  | 'path-traversal'
  | 'header-injection'
  | 'privilege-escalation'
  | 'file-upload'
  | 'sensitive-data-exposure';

/** A single security finding recorded in the Security_Audit_Report. */
export interface SecurityFinding {
  endpointId: string;
  category: VulnCategory;
  severity: 'low' | 'medium' | 'high' | 'critical';
  payloadRef: string;
  observedResponse?: string;
}

/** A single performance measurement for an endpoint. */
export interface PerfMeasurement {
  endpointId: string;
  responseTimeMs: number;
  throughput: number;
  latencyMs: number;
  lambdaDurationMs?: number;
  apiGwLatencyMs?: number;
  flaggedSlow: boolean;
  suspectedInefficiency?: string;
}

/** An AWS service validated by the AWS_Validator. */
export type AwsService =
  | 'cognito'
  | 'dynamodb'
  | 's3'
  | 'lambda'
  | 'apigateway'
  | 'websocket';

/** The validation result for a single AWS service. */
export interface ServiceValidation {
  service: AwsService;
  outcome: 'ok' | 'failed';
  loggingConfigured: boolean;
  configIssues: string[];
}

/** A single coverage metric measured against its target. */
export interface CoverageMetric {
  name: string;
  value: number;
  target: number;
  met: boolean;
  contributingGaps: string[];
}

/** The full coverage report produced by the Coverage_Analyzer. */
export interface CoverageReport {
  /** endpoint, response-validation, security, auth, authz metrics. */
  metrics: CoverageMetric[];
  unexercisedEndpoints: string[];
  duplicateRoutes: string[];
  unreferencedRoutes: string[];
  missingDocs: { endpointId: string; missing: string[] }[];
}

/** The aggregated production readiness report. */
export interface ProductionReadinessReport {
  coverage: CoverageMetric[];
  openSecurityFindings: SecurityFinding[];
  openPerformanceIssues: PerfMeasurement[];
  unresolvedFailedEndpoints: RequestOutcome[];
  /** True if any aggregation step failed (Requirement 13.5). */
  partial: boolean;
  failedAggregationSteps: string[];
}

/** The full set of artifacts produced by an audit run. */
export interface AuditArtifacts {
  inventory: ApiInventory;
  catalog: CatalogEntry[];
  collection: PostmanCollection;
  environments: PostmanEnvironment[];
  localRun?: RunResult;
  awsRun?: RunResult;
  securityFindings: SecurityFinding[];
  perfMeasurements: PerfMeasurement[];
  serviceValidations: ServiceValidation[];
  coverage: CoverageReport;
  readiness?: ProductionReadinessReport;
  issues: StageIssue[];
}
