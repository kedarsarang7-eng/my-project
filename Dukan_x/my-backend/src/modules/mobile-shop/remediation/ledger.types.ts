/**
 * Remediation Ledger Type Definitions
 *
 * Machine-readable types for the AF-01–AF-53 remediation ledger
 * and related MSR-### defects.
 */

/** Status of a remediation entry */
export type RemediationStatus =
  | 'open'
  | 'investigating'
  | 'in_progress'
  | 'corrected_regression_locked'
  | 'superseded'
  | 'deferred'
  | 'resolved'
  | 'accepted_risk';

/** Severity of a finding */
export type FindingSeverity = 'critical' | 'high' | 'medium' | 'low';

/** Link to a requirement clause */
export interface RequirementLink {
  readonly requirementId: string;   // e.g. "1.1", "6.4"
  readonly clause?: string;         // Brief clause description
}

/** Link to a design component */
export interface DesignLink {
  readonly componentId: string;     // e.g. "1", "8"
  readonly componentName: string;   // e.g. "Remediation Ledger and Traceability Gate"
}

/** Link to an implementation task */
export interface TaskLink {
  readonly taskId: string;          // e.g. "1.1", "5.1"
  readonly description?: string;
}

/** A changed file reference */
export interface ChangedFile {
  readonly path: string;
  readonly changeType: 'added' | 'modified' | 'deleted';
  readonly description?: string;
}

/** Completion evidence for a resolved finding */
export interface CompletionEvidence {
  readonly testIds?: string[];
  readonly commands?: string[];
  readonly artifacts?: string[];
  readonly environment?: string;
  readonly result?: string;
  readonly verifiedAt?: string;     // ISO 8601
}

/** A single remediation ledger entry */
export interface RemediationEntry {
  /** Unique identifier: AF-01 through AF-53, or MSR-### for related defects */
  readonly id: string;

  /** Short title of the finding */
  readonly title: string;

  /** Current evidence description */
  readonly currentEvidence: string;

  /** Identified root cause */
  readonly rootCause: string;

  /** Severity classification */
  readonly severity: FindingSeverity;

  /** Current remediation status */
  readonly status: RemediationStatus;

  /** Dependencies that must be resolved first */
  readonly dependencies: string[];

  /** Links to requirement clauses */
  readonly requirementLinks: RequirementLink[];

  /** Links to design components */
  readonly designLinks: DesignLink[];

  /** Links to implementation tasks */
  readonly taskLinks: TaskLink[];

  /** Planned changes description */
  readonly plannedChanges: string;

  /** Changed files (populated as remediation progresses) */
  readonly changedFiles: ChangedFile[];

  /** Completion evidence (populated when resolved) */
  readonly completionEvidence?: CompletionEvidence;

  /** Related defect IDs discovered in the same dependency chain */
  readonly relatedDefects?: string[];

  /** Audit report section reference */
  readonly auditSection?: string;

  /** Notes */
  readonly notes?: string;
}

/** The complete remediation ledger */
export interface RemediationLedger {
  /** Schema version for forward compatibility */
  readonly version: string;

  /** Business type this ledger covers */
  readonly businessType: string;

  /** Source audit report path */
  readonly auditReportPath: string;

  /** Date ledger was created */
  readonly createdAt: string;

  /** Date ledger was last updated */
  readonly updatedAt: string;

  /** AF-01 through AF-53 entries */
  readonly findings: RemediationEntry[];

  /** MSR-### related defects discovered during remediation */
  readonly relatedDefects: RemediationEntry[];
}
