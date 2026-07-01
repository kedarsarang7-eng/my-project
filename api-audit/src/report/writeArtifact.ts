/**
 * Artifact-writing boundary.
 *
 * Every artifact the Audit_System produces is written through {@link writeArtifact},
 * the single choke point for artifact output. It:
 *   1. serializes each artifact to both JSON (machine-readable) and Markdown
 *      (human-readable) — Requirement 13.6, and
 *   2. runs a single redaction pass that replaces any verbatim secret value
 *      sourced from the environment with the `<redacted>` placeholder before
 *      anything is written — Requirements 3.5, 14.2.
 *
 * Centralizing redaction here makes the "no secrets in any artifact" guarantee
 * enforceable and testable: no output path can bypass it.
 */

import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';

import type { EnvironmentConfig } from '../types';

/** The placeholder substituted for every redacted secret value. */
export const REDACTION_PLACEHOLDER = '<redacted>';

/**
 * A structured artifact to serialize and persist.
 *
 * @typeParam T - The shape of the structured data serialized to JSON.
 */
export interface ArtifactInput<T> {
  /**
   * Output path relative to the run output directory, without a file
   * extension (for example `"api-inventory"` or `"reports/security-audit"`).
   * `.json` and `.md` files are written alongside each other.
   */
  name: string;
  /** The structured data serialized to JSON. */
  data: T;
  /**
   * Renders the human-readable Markdown representation. Receives the
   * already-redacted data so secrets cannot leak through custom rendering.
   * When omitted, a generic Markdown rendering is produced.
   */
  toMarkdown?: (data: T) => string;
}

/** The JSON and Markdown serializations of an artifact, after redaction. */
export interface SerializedArtifact {
  json: string;
  markdown: string;
}

/** The result of writing an artifact to disk. */
export interface WrittenArtifact extends SerializedArtifact {
  jsonPath: string;
  markdownPath: string;
}

/**
 * Replaces every verbatim occurrence of each secret value in `text` with the
 * redaction placeholder.
 *
 * Secrets are applied longest-first so that a secret which is a substring of a
 * longer secret cannot leave a partial fragment behind. Empty values are
 * ignored to avoid corrupting unrelated output.
 */
export function redactString(
  text: string,
  secretValues: Iterable<string>,
): string {
  let result = text;
  for (const secret of orderedSecrets(secretValues)) {
    // split/join performs a global, literal (non-regex) replacement.
    result = result.split(secret).join(REDACTION_PLACEHOLDER);
  }
  return result;
}

/**
 * Recursively replaces verbatim secret substrings in every string contained in
 * `value`, including object keys. Plain objects and arrays are cloned; other
 * values are returned unchanged. This redacts the structure before JSON
 * serialization so escaping cannot reveal a secret in the output.
 */
export function deepRedact<T>(value: T, secretValues: Iterable<string>): T {
  const secrets = orderedSecrets(secretValues);
  if (secrets.length === 0) {
    return value;
  }
  return redactValue(value, secrets) as T;
}

/**
 * Collects the resolved secret values from a set of environment
 * configurations. These are the values read from `process.env`; only the
 * values (never the variable names) are treated as secrets to redact.
 */
export function collectSecretValues(
  configs: readonly EnvironmentConfig[],
): string[] {
  const values = new Set<string>();
  for (const config of configs) {
    for (const value of config.variableValues.values()) {
      if (value.length > 0) {
        values.add(value);
      }
    }
  }
  return [...values];
}

/**
 * Serializes an artifact to redacted JSON and Markdown without touching the
 * filesystem. Exposed so the serialization/redaction behavior can be tested in
 * isolation from disk I/O.
 */
export function serializeArtifact<T>(
  input: ArtifactInput<T>,
  secretValues: Iterable<string>,
): SerializedArtifact {
  const secrets = orderedSecrets(secretValues);

  // Redact the structure first so JSON escaping cannot surface a secret.
  const redactedData = deepRedact(input.data, secrets);

  const render = input.toMarkdown ?? ((data: T) => defaultMarkdown(input.name, data));

  // Belt-and-suspenders: redact the serialized strings as well, covering any
  // secret introduced during JSON serialization or custom Markdown rendering.
  const json = redactString(JSON.stringify(redactedData, null, 2), secrets);
  const markdown = redactString(render(redactedData), secrets);

  return { json, markdown };
}

/**
 * Writes an artifact to disk as both `<name>.json` and `<name>.md`, with all
 * secret values redacted. This is the single output choke point: every
 * deliverable must be written through here.
 *
 * @param outputDir - The run output directory artifacts are written under.
 * @param input - The artifact to write.
 * @param secretValues - Secret values to redact (typically from
 *   {@link collectSecretValues}).
 */
export function writeArtifact<T>(
  outputDir: string,
  input: ArtifactInput<T>,
  secretValues: Iterable<string>,
): WrittenArtifact {
  const { json, markdown } = serializeArtifact(input, secretValues);

  const jsonPath = join(outputDir, `${input.name}.json`);
  const markdownPath = join(outputDir, `${input.name}.md`);

  mkdirSync(dirname(jsonPath), { recursive: true });
  writeFileSync(jsonPath, json, 'utf8');
  writeFileSync(markdownPath, markdown, 'utf8');

  return { json, markdown, jsonPath, markdownPath };
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/** De-duplicates, drops empty values, and orders secrets longest-first. */
function orderedSecrets(secretValues: Iterable<string>): string[] {
  const unique = new Set<string>();
  for (const value of secretValues) {
    if (value.length > 0) {
      unique.add(value);
    }
  }
  return [...unique].sort((a, b) => b.length - a.length);
}

/** Recursively redacts strings within a value, given pre-ordered secrets. */
function redactValue(value: unknown, secrets: string[]): unknown {
  if (typeof value === 'string') {
    return redactWithOrdered(value, secrets);
  }
  if (Array.isArray(value)) {
    return value.map((item) => redactValue(item, secrets));
  }
  if (value !== null && typeof value === 'object') {
    const out: Record<string, unknown> = {};
    for (const [key, val] of Object.entries(value)) {
      out[redactWithOrdered(key, secrets)] = redactValue(val, secrets);
    }
    return out;
  }
  return value;
}

/** Literal global replacement using already-ordered secrets. */
function redactWithOrdered(text: string, secrets: string[]): string {
  let result = text;
  for (const secret of secrets) {
    result = result.split(secret).join(REDACTION_PLACEHOLDER);
  }
  return result;
}

/** Generic Markdown rendering used when no custom renderer is supplied. */
function defaultMarkdown(name: string, data: unknown): string {
  const title = name.split(/[\\/]/).pop() ?? name;
  return `# ${title}\n\n\`\`\`json\n${JSON.stringify(data, null, 2)}\n\`\`\`\n`;
}
