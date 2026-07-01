/**
 * Security_Auditor, Performance_Auditor, and AWS_Validator stages.
 *
 * Execute targeted security cases, measure performance metrics, and validate
 * AWS service integrations, each emitting its report
 * (Requirements 7, 8, 9).
 */

// ---------------------------------------------------------------------------
// Security_Auditor (Requirement 7)
// ---------------------------------------------------------------------------
export {
  DefaultSecurityAuditor,
  auditSecurity,
  deriveProbeCases,
  noopProbeExecutor,
} from './security-auditor';
export type {
  ProbeExecutor,
  // Aliased to avoid a name collision with the AWS_Validator's ProbeResult.
  ProbeResult as SecurityProbeResult,
  SecurityAuditor,
  SecurityAuditorOptions,
  SecurityAuditResult,
  SecurityPayload,
  SecurityProbeCase,
  Severity,
} from './security-auditor';

// ---------------------------------------------------------------------------
// Performance_Auditor (Requirement 8)
// ---------------------------------------------------------------------------
export {
  DEFAULT_PERF_THRESHOLDS,
  CloudWatchPerfMetricsProvider,
  DefaultPerformanceAuditor,
  aggregateMeasurements,
  buildMeasurement,
  collectSamples,
} from './performance-auditor';
export type {
  AwsBacking,
  AwsBackingResolver,
  AwsEndpointMetrics,
  AwsPerfMetricsProvider,
  EndpointSamples,
  LogEventFetcher,
  PerfThresholds,
  PerformanceAuditor,
  PerformanceAuditorOptions,
  PerformanceReport,
} from './performance-auditor';

export {
  createCloudWatchLogFetcher,
  defaultCloudWatchLogsClient,
} from './aws-cloudwatch-logs';
export type { CloudWatchLogsClientLike } from './aws-cloudwatch-logs';

// ---------------------------------------------------------------------------
// AWS_Validator (Requirement 9)
// ---------------------------------------------------------------------------
export {
  AWS_SERVICES,
  DefaultAwsValidator,
  createDefaultProbes,
  validateAwsServices,
} from './aws-validator';
export type {
  AwsValidator,
  DefaultProbeClients,
  DefaultProbeOptions,
  // Aliased to avoid a name collision with the Security_Auditor's ProbeResult.
  ProbeResult as AwsProbeResult,
  ServiceProbe,
  ServiceProbes,
} from './aws-validator';
