/**
 * Report Aggregator and artifact-writing boundary.
 *
 * Persists all deliverables through writeArtifact() (JSON + Markdown) with a
 * single secret-redaction pass, and aggregates the production readiness
 * report (Requirements 13, 3.5, 14.2).
 */
export {
  REDACTION_PLACEHOLDER,
  collectSecretValues,
  deepRedact,
  redactString,
  serializeArtifact,
  writeArtifact,
} from './writeArtifact';
export type {
  ArtifactInput,
  SerializedArtifact,
  WrittenArtifact,
} from './writeArtifact';
export {
  buildFailedEndpointReport,
  deriveRecommendedFix,
} from './failed-endpoints';
export { aggregateReadiness } from './production-readiness';
export type { AggregationStep } from './production-readiness';
export { writeAll } from './writeAll';
