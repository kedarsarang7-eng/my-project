// ============================================================================
// WhatsApp Automation Module — Template Render Service (Task 7.1)
// ============================================================================
// Pure render function that substitutes every placeholder in a message template
// with values from the Business_Event payload.
//
// DESIGN CONTRACTS:
// - Pure function: no side effects, deterministic (same inputs → same outputs)
// - Fail-closed: if ANY placeholder cannot be resolved, rendering FAILS and
//   no message is produced. A partially-rendered template is never returned.
// - Sanitization: all substituted values are sanitized to literal text.
//   Control characters (except basic whitespace) and markup/executable content
//   (HTML/XML tags, script injections, WhatsApp formatting markers) are
//   neutralized so they render as visible, harmless text.
//
// Requirements: 7.3, 7.4, 13.6
// ============================================================================

/**
 * Placeholder pattern: matches `{{placeholderName}}` in template bodies.
 * Supports alphanumeric, underscores, dots, and hyphens inside the braces.
 */
const PLACEHOLDER_REGEX = /\{\{([a-zA-Z0-9_./-]+)\}\}/g;

/**
 * Control characters to neutralize (C0/C1 ranges excluding basic whitespace).
 * We preserve: \t (0x09), \n (0x0A), \r (0x0D) as they are safe whitespace.
 * Everything else in 0x00-0x08, 0x0B-0x0C, 0x0E-0x1F, 0x7F, 0x80-0x9F is stripped.
 */
const CONTROL_CHAR_REGEX = /[\x00-\x08\x0B\x0C\x0E-\x1F\x7F\x80-\x9F]/g;

/**
 * Unicode directional override characters that can be used for text spoofing.
 * LRO, RLO, LRE, RLE, PDF, LRI, RLI, FSI, PDI
 */
const BIDI_OVERRIDE_REGEX = /[\u202A-\u202E\u2066-\u2069\u200E\u200F]/g;

/**
 * Zero-width characters that can be used to obfuscate content.
 */
const ZERO_WIDTH_REGEX = /[\u200B-\u200D\uFEFF]/g;

// ── Result Types ──────────────────────────────────────────────────────────────

export interface RenderSuccess {
  readonly success: true;
  /** The fully rendered message body with all placeholders resolved and sanitized. */
  readonly text: string;
}

export interface RenderFailure {
  readonly success: false;
  /** Descriptive error identifying the missing/unresolved placeholders. */
  readonly error: string;
  /** List of placeholder names that could not be resolved. */
  readonly missingPlaceholders: readonly string[];
}

export type RenderResult = RenderSuccess | RenderFailure;

// ── Input Types ───────────────────────────────────────────────────────────────

export interface TemplateInput {
  /** The template body containing `{{placeholder}}` tokens. 1..4096 chars. */
  readonly body: string;
  /** Declared placeholders for this template (0..50). Used for validation. */
  readonly placeholders: readonly string[];
}

export type RenderPayload = Readonly<Record<string, unknown>>;

// ── Sanitization ──────────────────────────────────────────────────────────────

/**
 * Sanitizes a substituted value to literal text.
 *
 * Neutralizes:
 * 1. Control characters (C0/C1 except tab, newline, CR)
 * 2. HTML/XML tags and script content → angle brackets escaped
 * 3. WhatsApp formatting markers (* _ ~ `) → prefixed with zero-width space
 *    to prevent accidental bold/italic/strikethrough/monospace rendering
 * 4. Unicode bidirectional overrides that could spoof text direction
 * 5. Zero-width characters used for obfuscation
 * 6. Null bytes
 *
 * The result is safe to embed in a WhatsApp message as literal, visible text.
 */
export function sanitize(value: string): string {
  let sanitized = value;

  // 1. Strip control characters (preserving \t, \n, \r)
  sanitized = sanitized.replace(CONTROL_CHAR_REGEX, '');

  // 2. Escape HTML/XML angle brackets to prevent markup injection
  sanitized = sanitized.replace(/</g, '\uFF1C'); // fullwidth less-than
  sanitized = sanitized.replace(/>/g, '\uFF1E'); // fullwidth greater-than

  // 3. Escape ampersand to prevent HTML entity injection
  sanitized = sanitized.replace(/&/g, '\uFF06'); // fullwidth ampersand

  // 4. Remove bidirectional override characters (text spoofing prevention)
  sanitized = sanitized.replace(BIDI_OVERRIDE_REGEX, '');

  // 5. Remove zero-width characters (obfuscation prevention)
  // Must happen BEFORE our own ZWNJ insertion for formatting escapes.
  sanitized = sanitized.replace(ZERO_WIDTH_REGEX, '');

  // 6. Neutralize WhatsApp formatting markers by prefixing with ZWNJ
  // This prevents user-supplied values from accidentally triggering
  // bold (*), italic (_), strikethrough (~), or monospace (```) formatting.
  sanitized = sanitized.replace(/([*_~`])/g, '\u200C$1');

  return sanitized;
}

// ── Value Resolution ──────────────────────────────────────────────────────────

/**
 * Resolves a dotted placeholder path against the payload object.
 * Supports nested access: "customer.name" → payload.customer.name
 *
 * Returns undefined if the path cannot be resolved or the value is null/undefined.
 */
function resolveValue(path: string, payload: RenderPayload): string | undefined {
  const parts = path.split('.');
  let current: unknown = payload;

  for (const part of parts) {
    if (current === null || current === undefined) {
      return undefined;
    }
    if (typeof current !== 'object') {
      return undefined;
    }
    current = (current as Record<string, unknown>)[part];
  }

  if (current === null || current === undefined) {
    return undefined;
  }

  // Convert to string representation
  if (typeof current === 'string') {
    return current;
  }
  if (typeof current === 'number' || typeof current === 'boolean') {
    return String(current);
  }
  // Objects/arrays are not valid substitution values — fail
  return undefined;
}

// ── Core Render Function ──────────────────────────────────────────────────────

/**
 * Renders a message template by substituting every placeholder with the
 * corresponding value from the payload.
 *
 * **Fail-closed behavior**: If ANY placeholder in the template body cannot be
 * resolved from the payload, the entire render operation fails. No partially
 * rendered message is ever produced.
 *
 * **Sanitization**: Every substituted value is sanitized to literal text before
 * insertion, neutralizing control characters, markup, and executable content.
 *
 * This function is PURE: no side effects, fully deterministic.
 *
 * @param template - The message template with body and declared placeholders
 * @param payload - The Business_Event data to substitute into placeholders
 * @returns RenderSuccess with the fully rendered text, or RenderFailure with
 *          descriptive error and list of unresolved placeholders
 */
export function render(template: TemplateInput, payload: RenderPayload): RenderResult {
  const { body, placeholders: declaredPlaceholders } = template;

  // Phase 1: Discover all placeholders actually present in the template body.
  // This catches placeholders in the body that may not be in the declared list,
  // ensuring we never leave ANY unresolved token.
  const bodyPlaceholders = new Set<string>();
  let match: RegExpExecArray | null;
  const regex = new RegExp(PLACEHOLDER_REGEX.source, PLACEHOLDER_REGEX.flags);

  while ((match = regex.exec(body)) !== null) {
    bodyPlaceholders.add(match[1]);
  }

  // Phase 2: Also include declared placeholders — the template contract says
  // these MUST be resolvable. Even if the body has a typo/mismatch, declared
  // placeholders must have corresponding payload values.
  for (const declared of declaredPlaceholders) {
    bodyPlaceholders.add(declared);
  }

  // Phase 3: Resolve every placeholder and collect failures.
  const missingPlaceholders: string[] = [];
  const resolvedValues = new Map<string, string>();

  for (const placeholder of bodyPlaceholders) {
    const rawValue = resolveValue(placeholder, payload);
    if (rawValue === undefined) {
      missingPlaceholders.push(placeholder);
    } else {
      // Sanitize the resolved value immediately
      resolvedValues.set(placeholder, sanitize(rawValue));
    }
  }

  // Phase 4: FAIL CLOSED if any placeholder is unresolved.
  if (missingPlaceholders.length > 0) {
    // Sort for deterministic error messages
    missingPlaceholders.sort();
    return {
      success: false,
      error: `Template render failed: unresolved placeholder(s): ${missingPlaceholders.map((p) => `{{${p}}}`).join(', ')}. Message suppressed (fail-closed).`,
      missingPlaceholders,
    };
  }

  // Phase 5: Perform substitution in the template body.
  const renderedText = body.replace(regex, (_fullMatch, placeholderName: string) => {
    // We already validated all placeholders are resolved, so this is safe
    return resolvedValues.get(placeholderName)!;
  });

  // Phase 6: Final safety check — ensure no unresolved placeholder tokens remain.
  // This is a defense-in-depth check against regex edge cases.
  const finalCheckRegex = new RegExp(PLACEHOLDER_REGEX.source, PLACEHOLDER_REGEX.flags);
  if (finalCheckRegex.test(renderedText)) {
    // Extract any remaining unresolved placeholders
    const remaining: string[] = [];
    let remainingMatch: RegExpExecArray | null;
    const finalScanRegex = new RegExp(PLACEHOLDER_REGEX.source, PLACEHOLDER_REGEX.flags);
    while ((remainingMatch = finalScanRegex.exec(renderedText)) !== null) {
      remaining.push(remainingMatch[1]);
    }
    return {
      success: false,
      error: `Template render failed: post-substitution unresolved placeholder(s): ${remaining.map((p) => `{{${p}}}`).join(', ')}. Message suppressed (fail-closed).`,
      missingPlaceholders: remaining,
    };
  }

  return {
    success: true,
    text: renderedText,
  };
}
