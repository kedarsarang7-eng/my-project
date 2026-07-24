/**
 * Remediation Ledger Validator
 *
 * Validates the machine-readable AF-01–AF-53 remediation ledger:
 * - Rejects missing audit IDs (any gap in AF-01 through AF-53)
 * - Rejects duplicate audit IDs
 * - Validates required fields on each entry
 * - Supports related MSR-### defects with same quality gates
 */

import {
  RemediationEntry,
  RemediationLedger,
  RemediationStatus,
  FindingSeverity,
} from './ledger.types';

/** Validation error detail */
export interface LedgerValidationError {
  readonly entryId?: string;
  readonly field?: string;
  readonly message: string;
  readonly severity: 'error' | 'warning';
}

/** Validation result */
export interface LedgerValidationResult {
  readonly valid: boolean;
  readonly errors: LedgerValidationError[];
  readonly warnings: LedgerValidationError[];
  readonly summary: {
    readonly totalFindings: number;
    readonly totalDefects: number;
    readonly missingIds: string[];
    readonly duplicateIds: string[];
  };
}

const VALID_STATUSES: ReadonlySet<RemediationStatus> = new Set([
  'open',
  'investigating',
  'in_progress',
  'corrected_regression_locked',
  'superseded',
  'deferred',
  'resolved',
  'accepted_risk',
]);

const VALID_SEVERITIES: ReadonlySet<FindingSeverity> = new Set([
  'critical',
  'high',
  'medium',
  'low',
]);

/** AF-## pattern: AF-01 through AF-53 */
const AF_ID_PATTERN = /^AF-(\d{2})$/;

/** MSR-### pattern for related defects */
const MSR_ID_PATTERN = /^MSR-(\d{3})$/;

/** Total expected audit findings */
const EXPECTED_AF_COUNT = 53;

/**
 * Generate the complete expected set of AF IDs from AF-01 to AF-53.
 */
export function getExpectedAfIds(): string[] {
  const ids: string[] = [];
  for (let i = 1; i <= EXPECTED_AF_COUNT; i++) {
    ids.push(`AF-${i.toString().padStart(2, '0')}`);
  }
  return ids;
}

/**
 * Validate a single remediation entry against required field rules.
 */
function validateEntry(
  entry: RemediationEntry,
  idPattern: RegExp,
  patternLabel: string,
): LedgerValidationError[] {
  const errors: LedgerValidationError[] = [];
  const id = entry.id;

  // ID format check
  if (!idPattern.test(id)) {
    errors.push({
      entryId: id,
      field: 'id',
      message: `Entry id "${id}" does not match expected ${patternLabel} format`,
      severity: 'error',
    });
  }

  // Required non-empty string fields
  const requiredStrings: Array<{ field: keyof RemediationEntry; label: string }> = [
    { field: 'title', label: 'title' },
    { field: 'currentEvidence', label: 'currentEvidence' },
    { field: 'rootCause', label: 'rootCause' },
    { field: 'plannedChanges', label: 'plannedChanges' },
  ];

  for (const { field, label } of requiredStrings) {
    const value = entry[field];
    if (typeof value !== 'string' || value.trim().length === 0) {
      errors.push({
        entryId: id,
        field: label,
        message: `Entry "${id}" is missing required field "${label}"`,
        severity: 'error',
      });
    }
  }

  // Status validation
  if (!VALID_STATUSES.has(entry.status)) {
    errors.push({
      entryId: id,
      field: 'status',
      message: `Entry "${id}" has invalid status "${entry.status}"`,
      severity: 'error',
    });
  }

  // Severity validation
  if (!VALID_SEVERITIES.has(entry.severity)) {
    errors.push({
      entryId: id,
      field: 'severity',
      message: `Entry "${id}" has invalid severity "${entry.severity}"`,
      severity: 'error',
    });
  }

  // Arrays must be present (can be empty for initial placeholder)
  if (!Array.isArray(entry.dependencies)) {
    errors.push({
      entryId: id,
      field: 'dependencies',
      message: `Entry "${id}" is missing required field "dependencies" (array)`,
      severity: 'error',
    });
  }
  if (!Array.isArray(entry.requirementLinks)) {
    errors.push({
      entryId: id,
      field: 'requirementLinks',
      message: `Entry "${id}" is missing required field "requirementLinks" (array)`,
      severity: 'error',
    });
  }
  if (!Array.isArray(entry.designLinks)) {
    errors.push({
      entryId: id,
      field: 'designLinks',
      message: `Entry "${id}" is missing required field "designLinks" (array)`,
      severity: 'error',
    });
  }
  if (!Array.isArray(entry.taskLinks)) {
    errors.push({
      entryId: id,
      field: 'taskLinks',
      message: `Entry "${id}" is missing required field "taskLinks" (array)`,
      severity: 'error',
    });
  }
  if (!Array.isArray(entry.changedFiles)) {
    errors.push({
      entryId: id,
      field: 'changedFiles',
      message: `Entry "${id}" is missing required field "changedFiles" (array)`,
      severity: 'error',
    });
  }

  // Completion evidence required when resolved
  if (entry.status === 'resolved' && !entry.completionEvidence) {
    errors.push({
      entryId: id,
      field: 'completionEvidence',
      message: `Entry "${id}" has status "resolved" but no completionEvidence`,
      severity: 'error',
    });
  }

  return errors;
}

/**
 * Validate the complete remediation ledger.
 *
 * Rejects:
 * - Missing audit IDs (any gap in AF-01 through AF-53)
 * - Duplicate audit IDs
 * - Missing required fields on entries
 * - Invalid MSR-### identifiers on related defects
 */
export function validateLedger(ledger: RemediationLedger): LedgerValidationResult {
  const errors: LedgerValidationError[] = [];
  const warnings: LedgerValidationError[] = [];

  // Top-level required fields
  if (!ledger.version || typeof ledger.version !== 'string') {
    errors.push({ message: 'Ledger is missing required "version" field', severity: 'error' });
  }
  if (!ledger.businessType || typeof ledger.businessType !== 'string') {
    errors.push({ message: 'Ledger is missing required "businessType" field', severity: 'error' });
  }
  if (!ledger.auditReportPath || typeof ledger.auditReportPath !== 'string') {
    errors.push({ message: 'Ledger is missing required "auditReportPath" field', severity: 'error' });
  }
  if (!Array.isArray(ledger.findings)) {
    errors.push({ message: 'Ledger is missing required "findings" array', severity: 'error' });
    return {
      valid: false,
      errors,
      warnings,
      summary: { totalFindings: 0, totalDefects: 0, missingIds: [], duplicateIds: [] },
    };
  }

  // Validate AF findings: check for completeness and duplicates
  const expectedIds = getExpectedAfIds();
  const seenAfIds = new Set<string>();
  const duplicateIds: string[] = [];

  for (const entry of ledger.findings) {
    if (seenAfIds.has(entry.id)) {
      duplicateIds.push(entry.id);
      errors.push({
        entryId: entry.id,
        message: `Duplicate audit finding ID "${entry.id}"`,
        severity: 'error',
      });
    }
    seenAfIds.add(entry.id);

    // Validate entry fields
    const entryErrors = validateEntry(entry, AF_ID_PATTERN, 'AF-##');
    errors.push(...entryErrors);
  }

  // Check for missing AF IDs
  const missingIds = expectedIds.filter((id) => !seenAfIds.has(id));
  for (const id of missingIds) {
    errors.push({
      entryId: id,
      message: `Missing audit finding "${id}" — all AF-01 through AF-53 must be present`,
      severity: 'error',
    });
  }

  // Validate MSR-### related defects
  const seenMsrIds = new Set<string>();
  const relatedDefects = ledger.relatedDefects ?? [];

  for (const entry of relatedDefects) {
    if (seenMsrIds.has(entry.id) || seenAfIds.has(entry.id)) {
      duplicateIds.push(entry.id);
      errors.push({
        entryId: entry.id,
        message: `Duplicate defect ID "${entry.id}"`,
        severity: 'error',
      });
    }
    seenMsrIds.add(entry.id);

    // Validate entry fields with MSR pattern
    const entryErrors = validateEntry(entry, MSR_ID_PATTERN, 'MSR-###');
    errors.push(...entryErrors);
  }

  // Warnings for entries referencing unknown IDs in dependencies
  const allKnownIds = new Set([...seenAfIds, ...seenMsrIds]);
  for (const entry of [...ledger.findings, ...relatedDefects]) {
    if (Array.isArray(entry.dependencies)) {
      for (const dep of entry.dependencies) {
        if (!allKnownIds.has(dep)) {
          warnings.push({
            entryId: entry.id,
            field: 'dependencies',
            message: `Entry "${entry.id}" references unknown dependency "${dep}"`,
            severity: 'warning',
          });
        }
      }
    }
  }

  return {
    valid: errors.length === 0,
    errors,
    warnings,
    summary: {
      totalFindings: ledger.findings.length,
      totalDefects: relatedDefects.length,
      missingIds,
      duplicateIds,
    },
  };
}
