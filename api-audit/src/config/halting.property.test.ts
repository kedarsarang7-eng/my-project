/**
 * Property-based test for the Config Loader's fail-fast behavior.
 *
 * Feature: api-audit-testing-automation, Property 28: Missing required
 * environment variables halt before any stage.
 *
 * Validates: Requirements 14.5
 *
 * The Config Loader is the only stage that can halt a run before discovery.
 * When any required environment variable is absent, it must report exactly the
 * absent variable names (names only, never values) and signal that the run
 * must stop before any stage executes. Because the loader itself runs no
 * pipeline stages, the non-empty `missing` list IS the halt signal the
 * orchestrator consumes (see design "Error Handling": fatal pre-run errors).
 */

import fc from 'fast-check';

import { EnvConfigLoader } from './index';

/**
 * Derive the full, deduplicated set of required variable names directly from
 * the loader, so the test stays in sync with the loader's contract without
 * duplicating the environment definitions. Variable *names* are static and
 * independent of any values, so loading against an empty env is sufficient to
 * read the `requiredVars` contract for every environment.
 */
function allRequiredVarNames(): string[] {
  const { configs } = new EnvConfigLoader({}).load({});
  const names = new Set<string>();
  for (const config of configs) {
    for (const name of config.requiredVars) {
      names.add(name);
    }
  }
  return [...names];
}

describe('Feature: api-audit-testing-automation, Property 28: Missing required environment variables halt before any stage', () => {
  const requiredVars = allRequiredVarNames();

  it('reports exactly the absent required variable names and signals halt', () => {
    fc.assert(
      fc.property(
        // A non-empty subset of required vars to leave absent...
        fc.subarray(requiredVars, { minLength: 1 }),
        // ...plus arbitrary non-empty values for every present var.
        fc.dictionary(
          fc.constantFrom(...requiredVars),
          fc.string({ minLength: 1 }).filter((s) => s.trim().length > 0),
        ),
        (absentSubset, generatedValues) => {
          const absent = new Set(absentSubset);

          // Build the env source: every required var that is NOT in the
          // absent subset is present with a non-empty value; absent vars are
          // simply omitted (undefined).
          const env: Record<string, string> = {};
          for (const name of requiredVars) {
            if (absent.has(name)) {
              continue;
            }
            const value = generatedValues[name];
            env[name] = value && value.trim().length > 0 ? value : 'present';
          }

          const result = new EnvConfigLoader(env).load({});

          // The loader must signal a halt: a non-empty missing list is the
          // pre-stage stop condition the orchestrator acts on (14.5).
          expect(result.missing.length).toBeGreaterThan(0);

          // It must report EXACTLY the absent variable names, no more, no less.
          expect(new Set(result.missing)).toEqual(absent);

          // Names only, never values: each reported entry is a known required
          // variable name, and none equals any resolved value.
          const presentValues = new Set(Object.values(env));
          for (const name of result.missing) {
            expect(requiredVars).toContain(name);
            expect(presentValues.has(name)).toBe(false);
          }

          // The missing list is deduplicated.
          expect(result.missing.length).toBe(new Set(result.missing).size);
        },
      ),
      { numRuns: 100 },
    );
  });
});
