/**
 * Endpoint identity and stable hashing (Requirement 1.8).
 *
 * The identity of an endpoint is what deduplication is keyed on: two endpoints
 * discovered from different sources are "the same" endpoint when their
 * normalized identities are equal. To make that comparison robust across the
 * different ways sources express the same route (for example `:id` in code vs
 * `{id}` in OpenAPI), identities are normalized to a canonical form before a
 * stable hash is computed.
 *
 * The hash is deterministic: the same identity always yields the same id, so a
 * discovery run over an unchanged codebase produces equivalent ids each time
 * (Requirement 1.9).
 */
import { createHash } from 'crypto';
import type { EndpointIdentity } from '../types';

/**
 * Normalize a route path into a canonical form so the same logical route from
 * different sources compares equal.
 *
 * - Trims surrounding whitespace.
 * - Collapses repeated slashes (`//` -> `/`).
 * - Ensures a single leading slash.
 * - Removes a trailing slash (except for the root path `/`).
 * - Replaces named path parameters (`:id`, `{id}`) with a uniform `{}`
 *   placeholder so differing parameter names do not split one endpoint into
 *   several entries.
 *
 * Static segments keep their original case because HTTP paths are
 * case-sensitive in general.
 */
export function normalizePath(rawPath: string): string {
  const trimmed = rawPath.trim();
  if (trimmed === '') {
    return '';
  }

  const segments = trimmed
    .split('/')
    .filter((segment) => segment.length > 0)
    .map((segment) => normalizeSegment(segment));

  const joined = `/${segments.join('/')}`;
  // Collapse any accidental empty result back to a single root slash.
  return joined === '/' ? '/' : joined.replace(/\/+$/, '');
}

/** Replace a single `:param` or `{param}` segment with the `{}` placeholder. */
function normalizeSegment(segment: string): string {
  if (segment.startsWith(':')) {
    return '{}';
  }
  if (segment.startsWith('{') && segment.endsWith('}')) {
    return '{}';
  }
  return segment;
}

/**
 * Produce a canonical, normalized copy of an identity. Method is upper-cased,
 * paths are normalized, and operation/event names are trimmed. Undefined
 * optional fields are preserved as undefined so they do not contribute to the
 * identity hash.
 */
export function normalizeIdentity(identity: EndpointIdentity): EndpointIdentity {
  const normalized: EndpointIdentity = { kind: identity.kind };

  if (identity.method !== undefined) {
    normalized.method = identity.method.trim().toUpperCase();
  }
  if (identity.path !== undefined) {
    normalized.path = normalizePath(identity.path);
  }
  if (identity.operationName !== undefined) {
    normalized.operationName = identity.operationName.trim();
  }

  return normalized;
}

/**
 * Build the canonical string used as the hash input. Ordering of the fields is
 * fixed so the string is stable regardless of object key order.
 */
export function identityKey(identity: EndpointIdentity): string {
  const normalized = normalizeIdentity(identity);
  return [
    normalized.kind,
    normalized.method ?? '',
    normalized.path ?? '',
    normalized.operationName ?? '',
  ].join('|');
}

/**
 * Compute a stable id for an endpoint identity (Requirement 1.8). Equal
 * identities (after normalization) always produce the same id, and distinct
 * identities produce different ids with overwhelming probability.
 */
export function computeEndpointId(identity: EndpointIdentity): string {
  return createHash('sha256').update(identityKey(identity)).digest('hex').slice(0, 16);
}
