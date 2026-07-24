/**
 * Ledger Completeness Tests
 *
 * Verifies the actual AF-01–AF-53 remediation ledger data:
 * - All 53 AF IDs are present with no gaps
 * - Every finding has requirement links
 * - Every finding has task links
 * - Every finding has a severity
 * - No duplicate IDs exist
 *
 * Requirements: 1.7, 13.1–13.2, 14.1
 */

import { mobileShopRemediationLedger } from '../ledger-data';
import { getExpectedAfIds } from '../ledger-validator';

describe('Ledger Completeness', () => {
  const { findings } = mobileShopRemediationLedger;
  const expectedIds = getExpectedAfIds();

  describe('all 53 AF IDs are present with no gaps', () => {
    it('has exactly 53 findings', () => {
      expect(findings).toHaveLength(53);
    });

    it('contains every expected ID from AF-01 to AF-53', () => {
      const actualIds = findings.map((f) => f.id);
      for (const expectedId of expectedIds) {
        expect(actualIds).toContain(expectedId);
      }
    });

    it('IDs follow AF-## format', () => {
      const afPattern = /^AF-\d{2}$/;
      for (const finding of findings) {
        expect(finding.id).toMatch(afPattern);
      }
    });

    it('IDs are in ascending order', () => {
      for (let i = 1; i < findings.length; i++) {
        const prev = parseInt(findings[i - 1].id.replace('AF-', ''), 10);
        const curr = parseInt(findings[i].id.replace('AF-', ''), 10);
        expect(curr).toBeGreaterThan(prev);
      }
    });
  });

  describe('every finding has requirement links', () => {
    it.each(findings.map((f) => [f.id, f]))(
      '%s has at least one requirement link',
      (_id, finding) => {
        expect(Array.isArray(finding.requirementLinks)).toBe(true);
        expect(finding.requirementLinks.length).toBeGreaterThan(0);
      },
    );

    it('requirement links have requirementId field', () => {
      for (const finding of findings) {
        for (const link of finding.requirementLinks) {
          expect(link.requirementId).toBeDefined();
          expect(typeof link.requirementId).toBe('string');
          expect(link.requirementId.length).toBeGreaterThan(0);
        }
      }
    });
  });

  describe('every finding has task links', () => {
    it.each(findings.map((f) => [f.id, f]))(
      '%s has at least one task link',
      (_id, finding) => {
        expect(Array.isArray(finding.taskLinks)).toBe(true);
        expect(finding.taskLinks.length).toBeGreaterThan(0);
      },
    );

    it('task links have taskId field', () => {
      for (const finding of findings) {
        for (const link of finding.taskLinks) {
          expect(link.taskId).toBeDefined();
          expect(typeof link.taskId).toBe('string');
          expect(link.taskId.length).toBeGreaterThan(0);
        }
      }
    });
  });

  describe('every finding has a severity', () => {
    const validSeverities = ['critical', 'high', 'medium', 'low'];

    it.each(findings.map((f) => [f.id, f]))(
      '%s has a valid severity',
      (_id, finding) => {
        expect(validSeverities).toContain(finding.severity);
      },
    );
  });

  describe('no duplicate IDs exist', () => {
    it('all finding IDs are unique', () => {
      const ids = findings.map((f) => f.id);
      const uniqueIds = new Set(ids);
      expect(uniqueIds.size).toBe(ids.length);
    });

    it('no overlap between findings and related defects', () => {
      const findingIds = new Set(findings.map((f) => f.id));
      const defectIds = mobileShopRemediationLedger.relatedDefects.map((d) => d.id);
      for (const defectId of defectIds) {
        expect(findingIds.has(defectId)).toBe(false);
      }
    });
  });
});
