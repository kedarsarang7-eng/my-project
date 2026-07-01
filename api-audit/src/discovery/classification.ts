/**
 * Domain classification (Requirement 1.6).
 *
 * Every discovered endpoint is classified into exactly one `Domain` drawn from
 * the enumerated set. Classification is total: when no specific rule matches,
 * the endpoint falls back to `Internal-Service`, so this function never returns
 * an undefined or out-of-set value.
 *
 * Classification is driven first by endpoint kind (GraphQL/WebSocket surfaces
 * are unambiguous) and then by keyword matching against the route path and
 * operation name. Rules are ordered most-specific first so that, for example,
 * an `/admin/users` route classifies as `Admin` rather than `Users`.
 */
import type { Domain, EndpointIdentity, SourceRef } from '../types';
import { normalizeIdentity } from './identity';

/** A single keyword-based classification rule. */
interface ClassificationRule {
  domain: Domain;
  /** Substrings that, if any is present, select this rule's domain. */
  keywords: string[];
}

/**
 * Ordered keyword rules. Earlier rules win, so more specific groupings (Admin,
 * Authorization/RBAC) precede broader ones (Users).
 */
const KEYWORD_RULES: ClassificationRule[] = [
  { domain: 'Admin', keywords: ['admin'] },
  { domain: 'Authentication', keywords: ['auth', 'login', 'logout', 'register', 'signup', 'signin', 'token', 'password', 'mfa', 'otp', 'cognito'] },
  { domain: 'Authorization/RBAC', keywords: ['rbac', 'role', 'permission', 'policy', 'grant', 'scope'] },
  { domain: 'License', keywords: ['license', 'licence', 'activation'] },
  { domain: 'Subscription', keywords: ['subscription', 'subscribe', 'plan', 'tier'] },
  { domain: 'Invoices', keywords: ['invoice'] },
  { domain: 'Billing', keywords: ['billing', 'payment', 'pay', 'charge', 'checkout', 'refund'] },
  { domain: 'Customers', keywords: ['customer', 'client'] },
  { domain: 'Products', keywords: ['product', 'catalog', 'catalogue', 'item', 'sku'] },
  { domain: 'Inventory', keywords: ['inventory', 'stock', 'warehouse'] },
  { domain: 'Reports', keywords: ['report', 'analytic', 'dashboard', 'metric', 'stats'] },
  { domain: 'Search', keywords: ['search', 'query', 'lookup'] },
  { domain: 'Settings', keywords: ['setting', 'config', 'preference'] },
  { domain: 'File-Transfer', keywords: ['file', 'upload', 'download', 'attachment', 'document', 'media', 's3'] },
  { domain: 'AWS-Integrated', keywords: ['aws', 'dynamo', 'lambda', 'sqs', 'sns', 'ses', 'kinesis', 'eventbridge'] },
  { domain: 'Users', keywords: ['user', 'account', 'profile', 'me'] },
  { domain: 'Internal-Service', keywords: ['internal', 'health', 'ping', 'status', 'webhook'] },
];

/** The domain assigned when no keyword rule matches. */
const DEFAULT_DOMAIN: Domain = 'Internal-Service';

/**
 * Classify an endpoint into exactly one `Domain`.
 *
 * The optional `sources` are consulted as a secondary signal: when the route
 * and operation name yield no match, the contributing file paths are scanned
 * for the same keywords (a handler living under `modules/billing/...` should
 * classify as `Billing` even if its route is opaque).
 */
export function classifyDomain(
  identity: EndpointIdentity,
  sources: SourceRef[] = [],
): Domain {
  const normalized = normalizeIdentity(identity);

  // Kind-driven classification for unambiguous surfaces.
  if (normalized.kind.startsWith('graphql')) {
    return 'GraphQL';
  }
  if (normalized.kind.startsWith('ws')) {
    return 'WebSocket';
  }

  // Primary signal: the route path and operation/event name.
  const primaryText = `${normalized.path ?? ''} ${normalized.operationName ?? ''}`.toLowerCase();
  const primaryMatch = matchKeywordRule(primaryText);
  if (primaryMatch) {
    return primaryMatch;
  }

  // Secondary signal: the source file paths the endpoint was discovered from.
  const sourceText = sources.map((source) => source.filePath).join(' ').toLowerCase();
  const sourceMatch = matchKeywordRule(sourceText);
  if (sourceMatch) {
    return sourceMatch;
  }

  return DEFAULT_DOMAIN;
}

/** Return the domain of the first rule whose keyword appears in `text`. */
function matchKeywordRule(text: string): Domain | undefined {
  if (text.trim() === '') {
    return undefined;
  }
  for (const rule of KEYWORD_RULES) {
    if (rule.keywords.some((keyword) => text.includes(keyword))) {
      return rule.domain;
    }
  }
  return undefined;
}
