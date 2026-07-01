/**
 * Deliverable persistence (`writeAll`) — Task 17.2.
 *
 * Implements the persistence half of the Report Aggregator interface. When an
 * audit run completes, `writeAll` emits every deliverable in both a
 * machine-readable (JSON) and a human-readable (Markdown) representation
 * (Requirement 13.6) by routing each artifact through {@link writeArtifact} —
 * the single secret-redaction choke point (Requirements 3.5, 14.2).
 *
 * The deliverable set covers:
 *   - the API_Inventory, API_Catalog, Postman_Collection, the five Postman
 *     environments, and the generated automated test scripts (Requirement 13.1);
 *   - the Security_Audit_Report, Performance_Report, API_Coverage_Report, and
 *     AWS_Validation_Report (Requirement 13.2);
 *   - the failed endpoint report and the recommended fixes (Requirement 13.3);
 *   - the production readiness report when present (Requirement 13.4).
 *
 * Output layout mirrors design.md ("Run Output Layout"):
 *
 * ```
 * <outputDir>/
 *   api-inventory.{json,md}
 *   api-catalog.{json,md}
 *   postman/
 *     collection.{json,md}
 *     env.development.{json,md} ... env.production.{json,md}
 *     test-scripts.{json,md}
 *   reports/
 *     security-audit.{json,md}
 *     performance.{json,md}
 *     coverage.{json,md}
 *     aws-validation.{json,md}
 *     failed-endpoints.{json,md}
 *     recommended-fixes.{json,md}
 *     production-readiness.{json,md}
 * ```
 *
 * The function performs filesystem I/O but holds no other side effects: it
 * derives the failed-endpoint/recommended-fix reports from the run result and
 * the readiness report from the artifacts (when not already supplied) so a
 * single call produces the complete deliverable set.
 */

import type {
  ApiInventory,
  AuditArtifacts,
  CatalogEntry,
  CoverageReport,
  EnvironmentConfig,
  GeneratedTest,
  PerfMeasurement,
  PostmanCollection,
  PostmanEnvironment,
  ProductionReadinessReport,
  SecurityFinding,
  ServiceValidation,
} from '../types';
import {
  buildFailedEndpointReport,
} from './failed-endpoints';
import { aggregateReadiness } from './production-readiness';
import {
  collectSecretValues,
  writeArtifact,
  type ArtifactInput,
  type WrittenArtifact,
} from './writeArtifact';

/** The collected automated test scripts deliverable (Requirement 13.1). */
interface TestScriptsArtifact {
  /** Every Postman test script attached across the collection. */
  scripts: GeneratedTest[];
}

/**
 * Persists every deliverable produced by an audit run in both formats.
 *
 * All output is routed through {@link writeArtifact}; secret values are
 * collected from the supplied environment configurations and redacted before
 * anything reaches disk. Reports that are derived rather than stored on
 * {@link AuditArtifacts} (the failed-endpoint report, recommended fixes, and —
 * when absent — the readiness report) are computed here from the available
 * inputs so the deliverable set is complete.
 *
 * @param outputDir - The run output directory artifacts are written under.
 * @param artifacts - The artifacts produced by the run.
 * @param configs - Environment configurations whose resolved values are the
 *   secrets to redact (typically every environment the run loaded).
 * @returns The list of written artifacts (JSON + Markdown paths) in emission
 *   order, useful for verifying deliverable presence.
 */
export function writeAll(
  outputDir: string,
  artifacts: AuditArtifacts,
  configs: readonly EnvironmentConfig[] = [],
): WrittenArtifact[] {
  const secrets = collectSecretValues(configs);
  const written: WrittenArtifact[] = [];

  const emit = <T>(input: ArtifactInput<T>): void => {
    written.push(writeArtifact(outputDir, input, secrets));
  };

  // --- Requirement 13.1: inventory, catalog, collection, environments, scripts
  emit<ApiInventory>({
    name: 'api-inventory',
    data: artifacts.inventory,
    toMarkdown: renderInventory,
  });

  emit<CatalogEntry[]>({
    name: 'api-catalog',
    data: artifacts.catalog,
    toMarkdown: renderCatalog,
  });

  emit<PostmanCollection>({
    name: join('postman', 'collection'),
    data: artifacts.collection,
    toMarkdown: renderCollection,
  });

  for (const environment of artifacts.environments) {
    emit<PostmanEnvironment>({
      name: join('postman', `env.${environmentSlug(environment.name)}`),
      data: environment,
      toMarkdown: renderEnvironment,
    });
  }

  emit<TestScriptsArtifact>({
    name: join('postman', 'test-scripts'),
    data: { scripts: collectTestScripts(artifacts.collection) },
    toMarkdown: renderTestScripts,
  });

  // --- Requirement 13.2: the four audit reports
  emit<SecurityFinding[]>({
    name: join('reports', 'security-audit'),
    data: artifacts.securityFindings,
    toMarkdown: renderSecurityFindings,
  });

  emit<PerfMeasurement[]>({
    name: join('reports', 'performance'),
    data: artifacts.perfMeasurements,
    toMarkdown: renderPerformance,
  });

  emit<CoverageReport>({
    name: join('reports', 'coverage'),
    data: artifacts.coverage,
    toMarkdown: renderCoverage,
  });

  emit<ServiceValidation[]>({
    name: join('reports', 'aws-validation'),
    data: artifacts.serviceValidations,
    toMarkdown: renderAwsValidation,
  });

  // --- Requirement 13.3: failed endpoint report and recommended fixes
  // Derived from the local run when present, otherwise the AWS run. With no run
  // result, both reports are empty rather than absent so the deliverable set is
  // always complete.
  const run = artifacts.localRun ?? artifacts.awsRun;
  const failedReport = run
    ? buildFailedEndpointReport(run)
    : { failures: [], recommendedFixes: [] };

  emit({
    name: join('reports', 'failed-endpoints'),
    data: { failures: failedReport.failures },
    toMarkdown: renderFailedEndpoints,
  });

  emit({
    name: join('reports', 'recommended-fixes'),
    data: { recommendedFixes: failedReport.recommendedFixes },
    toMarkdown: renderRecommendedFixes,
  });

  // --- Requirement 13.4: production readiness report
  const readiness = artifacts.readiness ?? aggregateReadiness(artifacts);
  emit<ProductionReadinessReport>({
    name: join('reports', 'production-readiness'),
    data: readiness,
    toMarkdown: renderReadiness,
  });

  return written;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Joins path segments with a forward slash for stable, cross-platform names. */
function join(...segments: string[]): string {
  return segments.join('/');
}

/** Maps an environment name to its lowercase file slug (e.g. `Local` → `local`). */
function environmentSlug(name: PostmanEnvironment['name']): string {
  return name.toLowerCase();
}

/** Collects every test script attached across all requests in the collection. */
function collectTestScripts(collection: PostmanCollection): GeneratedTest[] {
  const scripts: GeneratedTest[] = [];
  for (const folder of collection.folders) {
    for (const item of folder.items) {
      if (item.tests) {
        scripts.push(...item.tests);
      }
    }
  }
  return scripts;
}

// ---------------------------------------------------------------------------
// Markdown renderers
//
// Each renderer receives the already-redacted data (deepRedact runs before the
// renderer in writeArtifact) so secrets cannot leak through custom rendering.
// ---------------------------------------------------------------------------

/** Escapes pipe characters so values do not break Markdown table cells. */
function cell(value: unknown): string {
  return String(value ?? '').replace(/\|/g, '\\|').replace(/\n/g, ' ');
}

/** Renders a value that may be the literal `"undetermined"` sentinel. */
function determinable(value: unknown): string {
  if (value === 'undetermined') {
    return 'undetermined';
  }
  if (Array.isArray(value)) {
    return value.length === 0 ? '(none)' : String(value.length);
  }
  if (value !== null && typeof value === 'object') {
    return 'present';
  }
  return cell(value);
}

function renderInventory(inventory: ApiInventory): string {
  const lines: string[] = ['# API Inventory', ''];
  lines.push(`Total endpoints: ${inventory.entries.length}`);
  lines.push(`Issues recorded: ${inventory.issues.length}`, '');
  lines.push('| Id | Kind | Method | Path / Operation | Domain | Sources |');
  lines.push('| --- | --- | --- | --- | --- | --- |');
  for (const entry of inventory.entries) {
    const id = entry.identity;
    const target = id.path ?? id.operationName ?? '';
    lines.push(
      `| ${cell(entry.id)} | ${cell(id.kind)} | ${cell(id.method ?? '')} | ` +
        `${cell(target)} | ${cell(entry.domain)} | ${entry.sources.length} |`,
    );
  }
  if (inventory.issues.length > 0) {
    lines.push('', '## Issues', '');
    for (const issue of inventory.issues) {
      lines.push(`- **${cell(issue.stage)}** ${cell(issue.filePath ?? '')}: ${cell(issue.reason)}`);
    }
  }
  return lines.join('\n') + '\n';
}

function renderCatalog(catalog: CatalogEntry[]): string {
  const lines: string[] = ['# API Catalog', ''];
  lines.push(`Total entries: ${catalog.length}`, '');
  lines.push('| Id | Method/Operation | URL | Module | Security | Undetermined |');
  lines.push('| --- | --- | --- | --- | --- | --- |');
  for (const entry of catalog) {
    const undetermined = Object.keys(entry.undeterminedReasons).length;
    lines.push(
      `| ${cell(entry.id)} | ${determinable(entry.methodOrOperation)} | ` +
        `${determinable(entry.urlPath)} | ${determinable(entry.module)} | ` +
        `${cell(entry.security.enforcement)} | ${undetermined} |`,
    );
  }
  return lines.join('\n') + '\n';
}

function renderCollection(collection: PostmanCollection): string {
  const lines: string[] = ['# Postman Collection', ''];
  lines.push(`Schema: ${collection.info.schema}`);
  const requestCount = collection.folders.reduce((sum, f) => sum + f.items.length, 0);
  lines.push(`Folders: ${collection.folders.length}`);
  lines.push(`Requests: ${requestCount}`, '');
  for (const folder of collection.folders) {
    lines.push(`## ${folder.name} (${folder.items.length})`, '');
    for (const item of folder.items) {
      lines.push(`- \`${cell(item.method)}\` ${cell(item.name)} → ${cell(item.url)}`);
    }
    lines.push('');
  }
  return lines.join('\n') + '\n';
}

function renderEnvironment(environment: PostmanEnvironment): string {
  const lines: string[] = [`# Postman Environment: ${environment.name}`, ''];
  lines.push('| Variable | Value |');
  lines.push('| --- | --- |');
  for (const variable of environment.values) {
    lines.push(`| ${cell(variable.key)} | ${cell(variable.value)} |`);
  }
  return lines.join('\n') + '\n';
}

function renderTestScripts(artifact: TestScriptsArtifact): string {
  const lines: string[] = ['# Generated Test Scripts', ''];
  lines.push(`Total scripts: ${artifact.scripts.length}`, '');
  for (const script of artifact.scripts) {
    lines.push(`## ${script.type} — ${cell(script.endpointId)}`, '');
    lines.push('```js', script.script, '```', '');
  }
  return lines.join('\n') + '\n';
}

function renderSecurityFindings(findings: SecurityFinding[]): string {
  const lines: string[] = ['# Security Audit Report', ''];
  lines.push(`Total findings: ${findings.length}`, '');
  lines.push('| Endpoint | Category | Severity | Payload Ref | Observed Response |');
  lines.push('| --- | --- | --- | --- | --- |');
  for (const finding of findings) {
    lines.push(
      `| ${cell(finding.endpointId)} | ${cell(finding.category)} | ` +
        `${cell(finding.severity)} | ${cell(finding.payloadRef)} | ` +
        `${cell(finding.observedResponse ?? '')} |`,
    );
  }
  return lines.join('\n') + '\n';
}

function renderPerformance(measurements: PerfMeasurement[]): string {
  const lines: string[] = ['# Performance Report', ''];
  lines.push(`Total measurements: ${measurements.length}`, '');
  lines.push('| Endpoint | Response (ms) | Throughput | Latency (ms) | Slow | Suspected Inefficiency |');
  lines.push('| --- | --- | --- | --- | --- | --- |');
  for (const m of measurements) {
    lines.push(
      `| ${cell(m.endpointId)} | ${cell(m.responseTimeMs)} | ${cell(m.throughput)} | ` +
        `${cell(m.latencyMs)} | ${m.flaggedSlow ? 'yes' : 'no'} | ` +
        `${cell(m.suspectedInefficiency ?? '')} |`,
    );
  }
  return lines.join('\n') + '\n';
}

function renderCoverage(coverage: CoverageReport): string {
  const lines: string[] = ['# API Coverage Report', '', '## Metrics', ''];
  lines.push('| Metric | Value | Target | Met | Contributing Gaps |');
  lines.push('| --- | --- | --- | --- | --- |');
  for (const metric of coverage.metrics) {
    lines.push(
      `| ${cell(metric.name)} | ${cell(metric.value)} | ${cell(metric.target)} | ` +
        `${metric.met ? 'yes' : 'no'} | ${metric.contributingGaps.length} |`,
    );
  }
  lines.push('', `Unexercised endpoints: ${coverage.unexercisedEndpoints.length}`);
  lines.push(`Duplicate routes: ${coverage.duplicateRoutes.length}`);
  lines.push(`Unreferenced routes: ${coverage.unreferencedRoutes.length}`);
  lines.push(`Endpoints missing documentation: ${coverage.missingDocs.length}`);
  return lines.join('\n') + '\n';
}

function renderAwsValidation(validations: ServiceValidation[]): string {
  const lines: string[] = ['# AWS Validation Report', ''];
  lines.push('| Service | Outcome | Logging Configured | Config Issues |');
  lines.push('| --- | --- | --- | --- |');
  for (const v of validations) {
    lines.push(
      `| ${cell(v.service)} | ${cell(v.outcome)} | ` +
        `${v.loggingConfigured ? 'yes' : 'no'} | ${v.configIssues.length} |`,
    );
  }
  return lines.join('\n') + '\n';
}

function renderFailedEndpoints(data: {
  failures: ReturnType<typeof buildFailedEndpointReport>['failures'];
}): string {
  const lines: string[] = ['# Failed Endpoint Report', ''];
  lines.push(`Total failures: ${data.failures.length}`, '');
  for (const failure of data.failures) {
    lines.push(`## ${cell(failure.requestName)} (${cell(failure.endpointId)})`, '');
    lines.push(`- Status code: ${cell(failure.statusCode ?? 'n/a')}`);
    lines.push(`- Response time: ${cell(failure.responseTimeMs)} ms`);
    lines.push('- Assertion failures:');
    for (const af of failure.assertionFailures) {
      lines.push(`  - ${cell(af)}`);
    }
    lines.push('');
  }
  return lines.join('\n') + '\n';
}

function renderRecommendedFixes(data: {
  recommendedFixes: ReturnType<typeof buildFailedEndpointReport>['recommendedFixes'];
}): string {
  const lines: string[] = ['# Recommended Fixes', ''];
  lines.push(`Total entries: ${data.recommendedFixes.length}`, '');
  for (const fix of data.recommendedFixes) {
    lines.push(`## ${cell(fix.requestName)} (${cell(fix.endpointId)})`, '');
    for (const suggestion of fix.suggestions) {
      lines.push(`- **${cell(suggestion.category)}** — ${cell(suggestion.recommendation)}`);
      lines.push(`  - Trigger: ${cell(suggestion.trigger)}`);
    }
    lines.push('');
  }
  return lines.join('\n') + '\n';
}

function renderReadiness(report: ProductionReadinessReport): string {
  const lines: string[] = ['# Production Readiness Report', ''];
  lines.push(`Partial: ${report.partial ? 'yes' : 'no'}`);
  if (report.failedAggregationSteps.length > 0) {
    lines.push(`Failed aggregation steps: ${report.failedAggregationSteps.join(', ')}`);
  }
  lines.push('', '## Coverage', '');
  lines.push('| Metric | Value | Target | Met |');
  lines.push('| --- | --- | --- | --- |');
  for (const metric of report.coverage) {
    lines.push(
      `| ${cell(metric.name)} | ${cell(metric.value)} | ${cell(metric.target)} | ` +
        `${metric.met ? 'yes' : 'no'} |`,
    );
  }
  lines.push('', `Open security findings: ${report.openSecurityFindings.length}`);
  lines.push(`Open performance issues: ${report.openPerformanceIssues.length}`);
  lines.push(`Unresolved failed endpoints: ${report.unresolvedFailedEndpoints.length}`);
  return lines.join('\n') + '\n';
}
