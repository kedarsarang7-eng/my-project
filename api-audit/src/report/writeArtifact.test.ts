/**
 * Property test for the secret-redaction boundary.
 *
 * Feature: api-audit-testing-automation, Property 16: No secret values appear
 * in any artifact.
 *
 * Validates: Requirements 3.5, 7.7, 14.2
 *
 * Strategy: build arbitrary artifact data that embeds randomly-generated secret
 * values in many positions (object values, array elements, object keys, and
 * concatenated inside larger strings), route it through the
 * serialization/redaction boundary (`serializeArtifact`, which performs the
 * same redaction as `writeArtifact` without disk I/O), and assert that no
 * verbatim secret value survives in either the JSON or the Markdown output.
 */
import fc from 'fast-check';

import type { EnvironmentConfig } from '../types';
import {
  REDACTION_PLACEHOLDER,
  collectSecretValues,
  deepRedact,
  redactString,
  serializeArtifact,
} from './writeArtifact';

const MIN_RUNS = 100;

/**
 * Alphabet for generated secret values: alphanumerics only. Real audit secrets
 * (tokens, keys, connection strings) are effectively drawn from this space.
 * Keeping secrets free of the placeholder's `<`/`>` delimiters means a redacted
 * `<redacted>` placeholder can never accidentally recombine with surrounding
 * text to form a verbatim secret, so the property cannot fail spuriously.
 */
const SECRET_CHARS =
  'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'.split('');

/** A single non-empty, alphanumeric secret value. */
const secretArb: fc.Arbitrary<string> = fc
  .array(fc.constantFrom(...SECRET_CHARS), { minLength: 1, maxLength: 24 })
  .map((chars) => chars.join(''))
  // A secret that is itself a fragment of the placeholder text (e.g. "redacted")
  // would be reintroduced by redaction; such fragments are out of scope.
  .filter((value) => !REDACTION_PLACEHOLDER.includes(value));

/** A distinct set of secret values, mimicking several env-sourced credentials. */
const secretsArb: fc.Arbitrary<string[]> = fc.uniqueArray(secretArb, {
  minLength: 1,
  maxLength: 6,
});

/** Non-secret filler text, free of the placeholder delimiters. */
const fillerArb: fc.Arbitrary<string> = fc
  .array(fc.constantFrom(...SECRET_CHARS, ' ', '/', ':', '.', '-', '_'), {
    minLength: 0,
    maxLength: 12,
  })
  .map((chars) => chars.join(''));

/**
 * Builds artifact data that embeds every secret in a variety of shapes so the
 * redaction pass is exercised across nested values, arrays, keys, and strings
 * where a secret is concatenated with surrounding filler.
 */
function buildArtifactData(
  secrets: string[],
  fillers: string[],
): Record<string, unknown> {
  const filler = (i: number): string => fillers[i % fillers.length] ?? '';

  const embeddedAsKeys: Record<string, unknown> = {};
  secrets.forEach((secret, i) => {
    // Secret as an object key, with a (possibly secret) value.
    embeddedAsKeys[secret] = `${filler(i)}${secrets[(i + 1) % secrets.length]}`;
  });

  return {
    baseUrl: `https://${filler(0)}.example.com/${secrets[0]}`,
    // Secrets as standalone array elements.
    tokens: [...secrets],
    // Secrets concatenated inside larger strings.
    authHeaders: secrets.map(
      (secret, i) => `Bearer ${secret} ${filler(i)} session=${secret}`,
    ),
    // Secrets nested several levels deep.
    nested: {
      level1: {
        level2: {
          credential: secrets[secrets.length - 1],
          mixed: secrets.join(`${filler(1)}|`),
        },
      },
    },
    // Secrets used as object keys.
    byKey: embeddedAsKeys,
    // A list of structured records carrying secrets.
    records: secrets.map((secret, i) => ({
      id: `record-${i}`,
      value: secret,
      note: `${filler(i)} contains ${secret}`,
    })),
  };
}

/**
 * Builds EnvironmentConfig objects whose resolved variable values are the
 * generated secrets, so the redaction list is produced via the real
 * `collectSecretValues` path used by the orchestrator.
 */
function buildConfigs(secrets: string[]): EnvironmentConfig[] {
  const variableValues = new Map<string, string>();
  secrets.forEach((secret, i) => variableValues.set(`SECRET_VAR_${i}`, secret));
  return [
    {
      name: 'Local',
      baseUrl: 'http://localhost',
      requiredVars: [...variableValues.keys()],
      variableValues,
    },
  ];
}

describe('writeArtifact secret redaction', () => {
  it('Feature: api-audit-testing-automation, Property 16: No secret values appear in any artifact', () => {
    fc.assert(
      fc.property(secretsArb, fc.array(fillerArb), (secrets, fillers) => {
        const configs = buildConfigs(secrets);
        const secretValues = collectSecretValues(configs);

        const data = buildArtifactData(secrets, fillers);

        // A custom Markdown renderer that re-emits raw secrets, ensuring the
        // Markdown redaction path (not just JSON) is exercised.
        const { json, markdown } = serializeArtifact(
          {
            name: 'reports/secret-probe',
            data,
            toMarkdown: (d) =>
              `# Probe\n\n${secrets
                .map((s) => `- raw: ${s}`)
                .join('\n')}\n\n\`\`\`json\n${JSON.stringify(d)}\n\`\`\`\n`,
          },
          secretValues,
        );

        for (const secret of secrets) {
          expect(json.includes(secret)).toBe(false);
          expect(markdown.includes(secret)).toBe(false);
        }
      }),
      { numRuns: MIN_RUNS },
    );
  });

  // Focused example checks that complement the property test.
  it('redactString replaces every verbatim occurrence of a secret', () => {
    const out = redactString('token=abc123 and again abc123', ['abc123']);
    expect(out).toBe(
      `token=${REDACTION_PLACEHOLDER} and again ${REDACTION_PLACEHOLDER}`,
    );
    expect(out.includes('abc123')).toBe(false);
  });

  it('deepRedact redacts secrets in nested values and object keys', () => {
    const result = deepRedact(
      { secretKey: { nested: ['secretKey', 'safe'] } },
      ['secretKey'],
    );
    expect(JSON.stringify(result).includes('secretKey')).toBe(false);
  });

  it('redaction handles overlapping secrets without leaving fragments', () => {
    // "abc" is a substring of "abcdef"; longest-first ordering must prevent a
    // partial "def" or "abc" fragment from surviving.
    const { json } = serializeArtifact(
      { name: 'overlap', data: { a: 'abcdef', b: 'abc' } },
      ['abc', 'abcdef'],
    );
    expect(json.includes('abcdef')).toBe(false);
    expect(json.includes('abc')).toBe(false);
  });
});
