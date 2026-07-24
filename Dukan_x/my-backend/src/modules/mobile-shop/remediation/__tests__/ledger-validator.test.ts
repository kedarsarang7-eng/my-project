/**
 * Tests for the Remediation Ledger Validator
 *
 * Verifies:
 * - Missing AF IDs are rejected
 * - Duplicate AF IDs are rejected
 * - Required fields are validated
 * - MSR-### defects follow same quality gates
 * - Complete valid ledger passes validation
 */

import { validateLedger, getExpectedAfIds } from '../ledger-validator';
import { RemediationLedger, RemediationEntry } from '../ledger.types';
import { mobileShopRemediationLedger } from '../ledger-data';

function makeMinimalEntry(id: string): RemediationEntry {
  return {
    id,
    title: `Finding ${id}`,
    currentEvidence: 'Evidence text',
    rootCause: 'Root cause text',
    severity: 'medium',
    status: 'open',
    dependencies: [],
    requirementLinks: [],
    designLinks: [],
    taskLinks: [],
    plannedChanges: 'Planned changes text',
    changedFiles: [],
  };
}

function makeCompleteLedger(
  overrides: Partial<RemediationLedger> = {},
): RemediationLedger {
  const findings = getExpectedAfIds().map((id) => makeMinimalEntry(id));
  return {
    version: '1.0.0',
    businessType: 'mobileShop',
    auditReportPath: 'audit-reports/business-types/audit-mobileShop.md',
    createdAt: '2025-01-01',
    updatedAt: '2025-01-01',
    findings,
    relatedDefects: [],
    ...overrides,
  };
}

describe('getExpectedAfIds', () => {
  it('returns exactly 53 AF IDs from AF-01 to AF-53', () => {
    const ids = getExpectedAfIds();
    expect(ids).toHaveLength(53);
    expect(ids[0]).toBe('AF-01');
    expect(ids[52]).toBe('AF-53');
    expect(ids[9]).toBe('AF-10');
  });
});

describe('validateLedger', () => {
  describe('complete valid ledger', () => {
    it('passes validation with all 53 findings', () => {
      const ledger = makeCompleteLedger();
      const result = validateLedger(ledger);

      expect(result.valid).toBe(true);
      expect(result.errors).toHaveLength(0);
      expect(result.summary.totalFindings).toBe(53);
      expect(result.summary.missingIds).toHaveLength(0);
      expect(result.summary.duplicateIds).toHaveLength(0);
    });
  });

  describe('missing audit IDs', () => {
    it('rejects when AF-01 is missing', () => {
      const findings = getExpectedAfIds()
        .filter((id) => id !== 'AF-01')
        .map((id) => makeMinimalEntry(id));
      const ledger = makeCompleteLedger({ findings });
      const result = validateLedger(ledger);

      expect(result.valid).toBe(false);
      expect(result.summary.missingIds).toContain('AF-01');
    });

    it('rejects when multiple IDs are missing', () => {
      const findings = getExpectedAfIds()
        .filter((id) => id !== 'AF-10' && id !== 'AF-30' && id !== 'AF-53')
        .map((id) => makeMinimalEntry(id));
      const ledger = makeCompleteLedger({ findings });
      const result = validateLedger(ledger);

      expect(result.valid).toBe(false);
      expect(result.summary.missingIds).toEqual(
        expect.arrayContaining(['AF-10', 'AF-30', 'AF-53']),
      );
    });

    it('rejects an empty findings array', () => {
      const ledger = makeCompleteLedger({ findings: [] });
      const result = validateLedger(ledger);

      expect(result.valid).toBe(false);
      expect(result.summary.missingIds).toHaveLength(53);
    });
  });

  describe('duplicate audit IDs', () => {
    it('rejects duplicate AF-05', () => {
      const findings = getExpectedAfIds().map((id) => makeMinimalEntry(id));
      findings.push(makeMinimalEntry('AF-05'));
      const ledger = makeCompleteLedger({ findings });
      const result = validateLedger(ledger);

      expect(result.valid).toBe(false);
      expect(result.summary.duplicateIds).toContain('AF-05');
    });
  });

  describe('required fields validation', () => {
    it('rejects entry with empty title', () => {
      const findings = getExpectedAfIds().map((id) => makeMinimalEntry(id));
      findings[0] = { ...findings[0], title: '' };
      const ledger = makeCompleteLedger({ findings });
      const result = validateLedger(ledger);

      expect(result.valid).toBe(false);
      expect(result.errors).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            entryId: 'AF-01',
            field: 'title',
          }),
        ]),
      );
    });

    it('rejects entry with empty currentEvidence', () => {
      const findings = getExpectedAfIds().map((id) => makeMinimalEntry(id));
      findings[2] = { ...findings[2], currentEvidence: '  ' };
      const ledger = makeCompleteLedger({ findings });
      const result = validateLedger(ledger);

      expect(result.valid).toBe(false);
      expect(result.errors).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            entryId: 'AF-03',
            field: 'currentEvidence',
          }),
        ]),
      );
    });

    it('rejects entry with invalid status', () => {
      const findings = getExpectedAfIds().map((id) => makeMinimalEntry(id));
      findings[5] = { ...findings[5], status: 'unknown' as any };
      const ledger = makeCompleteLedger({ findings });
      const result = validateLedger(ledger);

      expect(result.valid).toBe(false);
      expect(result.errors).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            entryId: 'AF-06',
            field: 'status',
          }),
        ]),
      );
    });

    it('rejects entry with invalid severity', () => {
      const findings = getExpectedAfIds().map((id) => makeMinimalEntry(id));
      findings[0] = { ...findings[0], severity: 'urgent' as any };
      const ledger = makeCompleteLedger({ findings });
      const result = validateLedger(ledger);

      expect(result.valid).toBe(false);
      expect(result.errors).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            entryId: 'AF-01',
            field: 'severity',
          }),
        ]),
      );
    });

    it('rejects resolved entry without completionEvidence', () => {
      const findings = getExpectedAfIds().map((id) => makeMinimalEntry(id));
      findings[10] = { ...findings[10], status: 'resolved' };
      const ledger = makeCompleteLedger({ findings });
      const result = validateLedger(ledger);

      expect(result.valid).toBe(false);
      expect(result.errors).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            entryId: 'AF-11',
            field: 'completionEvidence',
          }),
        ]),
      );
    });
  });

  describe('MSR-### related defects', () => {
    it('accepts valid MSR-### defects with same quality gates', () => {
      const ledger = makeCompleteLedger({
        relatedDefects: [
          makeMinimalEntry('MSR-001'),
          makeMinimalEntry('MSR-002'),
        ],
      });
      const result = validateLedger(ledger);

      expect(result.valid).toBe(true);
      expect(result.summary.totalDefects).toBe(2);
    });

    it('rejects MSR defect with invalid ID format', () => {
      const ledger = makeCompleteLedger({
        relatedDefects: [makeMinimalEntry('MSR-1')],
      });
      const result = validateLedger(ledger);

      expect(result.valid).toBe(false);
      expect(result.errors).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            entryId: 'MSR-1',
            field: 'id',
          }),
        ]),
      );
    });

    it('rejects duplicate MSR defect IDs', () => {
      const ledger = makeCompleteLedger({
        relatedDefects: [
          makeMinimalEntry('MSR-001'),
          makeMinimalEntry('MSR-001'),
        ],
      });
      const result = validateLedger(ledger);

      expect(result.valid).toBe(false);
      expect(result.summary.duplicateIds).toContain('MSR-001');
    });

    it('rejects MSR defect with missing required fields', () => {
      const defect = makeMinimalEntry('MSR-003');
      const ledger = makeCompleteLedger({
        relatedDefects: [{ ...defect, rootCause: '' }],
      });
      const result = validateLedger(ledger);

      expect(result.valid).toBe(false);
      expect(result.errors).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            entryId: 'MSR-003',
            field: 'rootCause',
          }),
        ]),
      );
    });
  });

  describe('dependency warnings', () => {
    it('warns when dependency references unknown ID', () => {
      const findings = getExpectedAfIds().map((id) => makeMinimalEntry(id));
      findings[0] = { ...findings[0], dependencies: ['AF-99'] };
      const ledger = makeCompleteLedger({ findings });
      const result = validateLedger(ledger);

      expect(result.valid).toBe(true);
      expect(result.warnings).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            entryId: 'AF-01',
            message: expect.stringContaining('AF-99'),
          }),
        ]),
      );
    });
  });

  describe('top-level field validation', () => {
    it('rejects ledger missing version', () => {
      const ledger = makeCompleteLedger({ version: '' });
      const result = validateLedger(ledger);

      expect(result.valid).toBe(false);
      expect(result.errors).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            message: expect.stringContaining('version'),
          }),
        ]),
      );
    });

    it('rejects ledger missing businessType', () => {
      const ledger = makeCompleteLedger({ businessType: '' });
      const result = validateLedger(ledger);

      expect(result.valid).toBe(false);
    });
  });

  describe('actual ledger data validation', () => {
    it('validates the real mobileShopRemediationLedger', () => {
      const result = validateLedger(mobileShopRemediationLedger);

      expect(result.summary.totalFindings).toBe(53);
      expect(result.summary.missingIds).toHaveLength(0);
      expect(result.summary.duplicateIds).toHaveLength(0);
      expect(result.valid).toBe(true);
    });
  });
});
