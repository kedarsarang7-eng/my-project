/**
 * Property-based test for the Discovery_Engine's parse-error tolerance
 * guarantee.
 *
 * Feature: api-audit-testing-automation, Property 4: Discovery tolerates
 * unparseable sources.
 *
 * Validates: Requirements 1.10
 *
 * For any set of sources containing an arbitrary subset of unparseable files,
 * `discover` must:
 *   1. complete without throwing,
 *   2. record exactly one StageIssue per unparseable file, each carrying that
 *      file's path and a parse-error reason, and
 *   3. still produce inventory entries attributed to every parseable source.
 *
 * The test materializes real fixture files in a temporary directory on each
 * run. GraphQL files are used because their parser is deterministic: a valid
 * GraphQL document always yields an endpoint, and a syntactically invalid one
 * always throws (which `discover` catches and records as a StageIssue).
 */

import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';

import fc from 'fast-check';

import { discover } from './discover';
import type { ScanRoots } from './scanners';

/**
 * A valid GraphQL operation document. Each file gets a unique operation name so
 * its discovered endpoint is distinct and easy to trace back to its source.
 */
function validGraphql(index: number): string {
  return `query Op${index} { field${index} }`;
}

/**
 * Snippets that are guaranteed to be rejected by the GraphQL parser, so the
 * scanner throws and `discover` must record a StageIssue. None are empty (an
 * empty document is a valid no-op), and none are accidentally valid GraphQL.
 */
const INVALID_GRAPHQL_SNIPPETS = [
  '}{ this is ) not ( valid graphql',
  'type Query {', // unterminated type definition
  'query { field', // unterminated selection set
  '@@@ %%% ###', // illegal characters
  'mutation )( {}', // misplaced punctuation
  'query Op { field( }', // unbalanced parentheses
];

/** One planned fixture file: either a parseable or an unparseable GraphQL file. */
interface FileSpec {
  parseable: boolean;
  invalidIndex: number;
}

const fileSpecArb: fc.Arbitrary<FileSpec> = fc.record({
  parseable: fc.boolean(),
  invalidIndex: fc.nat({ max: INVALID_GRAPHQL_SNIPPETS.length - 1 }),
});

/** An arbitrary mix of parseable and unparseable files (including all of one kind). */
const fileSpecsArb: fc.Arbitrary<FileSpec[]> = fc.array(fileSpecArb, {
  minLength: 1,
  maxLength: 12,
});

describe('Feature: api-audit-testing-automation, Property 4: Discovery tolerates unparseable sources', () => {
  it('records exactly one issue per unparseable file and still discovers every parseable source', () => {
    fc.assert(
      fc.property(fileSpecsArb, (specs) => {
        const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'api-audit-disc-'));
        try {
          const parseablePaths: string[] = [];
          const unparseablePaths: string[] = [];
          const graphqlFiles: string[] = [];

          specs.forEach((spec, index) => {
            const filePath = path.join(tmpDir, `source-${index}.graphql`);
            const content = spec.parseable
              ? validGraphql(index)
              : INVALID_GRAPHQL_SNIPPETS[spec.invalidIndex];
            fs.writeFileSync(filePath, content, 'utf8');
            graphqlFiles.push(filePath);
            (spec.parseable ? parseablePaths : unparseablePaths).push(filePath);
          });

          const roots: ScanRoots = { graphqlFiles };

          // (1) Discovery completes without throwing.
          const inventory = discover(roots);

          // (2) Exactly one issue per unparseable file, each with its path and
          //     a non-empty parse-error reason; no parseable file is reported.
          expect(inventory.issues.length).toBe(unparseablePaths.length);

          const issuePaths = inventory.issues.map((issue) => issue.filePath);
          for (const issue of inventory.issues) {
            expect(issue.stage).toBe('discovery');
            expect(typeof issue.filePath).toBe('string');
            expect(issue.filePath && issue.filePath.length).toBeGreaterThan(0);
            expect(typeof issue.reason).toBe('string');
            expect(issue.reason.length).toBeGreaterThan(0);
          }

          // Each unparseable file appears exactly once in the issue list.
          for (const unparseablePath of unparseablePaths) {
            const occurrences = issuePaths.filter((p) => p === unparseablePath).length;
            expect(occurrences).toBe(1);
          }

          // No parseable file is ever reported as an issue.
          for (const parseablePath of parseablePaths) {
            expect(issuePaths).not.toContain(parseablePath);
          }

          // (3) Every parseable source still contributes to the inventory: its
          //     file path appears as a source on at least one entry.
          const attributedPaths = new Set<string>();
          for (const entry of inventory.entries) {
            for (const source of entry.sources) {
              attributedPaths.add(source.filePath);
            }
          }
          for (const parseablePath of parseablePaths) {
            expect(attributedPaths.has(parseablePath)).toBe(true);
          }
        } finally {
          fs.rmSync(tmpDir, { recursive: true, force: true });
        }
      }),
      { numRuns: 100 },
    );
  });
});
