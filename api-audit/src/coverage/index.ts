/**
 * Coverage_Analyzer stage.
 *
 * Computes coverage metrics and (in Task 15.2) structural gap lists against
 * the 100% Coverage_Targets (Requirement 12).
 */

export {
  COVERAGE_METRIC_NAMES,
  COVERAGE_TARGET,
  CoverageAnalyzer,
  CoverageMetricName,
  DefaultCoverageAnalyzer,
  MISSING_DOC_ASPECTS,
  MissingDocAspect,
  analyzeCoverage,
  computeCoverageMetrics,
  listDuplicateRoutes,
  listMissingDocs,
  listUnexercisedEndpoints,
  listUnreferencedRoutes,
} from './coverage-analyzer';
