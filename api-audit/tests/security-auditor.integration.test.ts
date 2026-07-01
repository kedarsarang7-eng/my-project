/**
 * Security_Auditor — integration test for security probing against stub
 * endpoints (Task 12.3).
 *
 * Feature: api-audit-testing-automation
 * Validates: Requirements 7.1, 7.2, 7.3, 7.4, 7.5 — when a security audit is
 * started, the Security_Auditor executes test cases across the injection /
 * scripting / forgery (7.1), token / authentication / authorization (7.2),
 * object-reference / traversal / header / escalation (7.3), file-upload (7.4),
 * and sensitive-data-exposure (7.5) categories and records a finding for every
 * endpoint detected vulnerable.
 *
 * Approach: a lightweight local HTTP stub server (Node `http`, loopback only,
 * no external network) exposes two endpoints with identical capabilities but
 * opposite security posture:
 *
 *   /vulnerable/records/:id — a deliberately insecure endpoint that reflects
 *     caller input verbatim, ignores authentication/authorization, leaks
 *     `/etc/passwd`-style content on traversal, reflects injected header
 *     content, accepts arbitrary uploads, and discloses secrets/PII/stack
 *     traces in every response.
 *   /safe/records/:id — a hardened endpoint that rejects every probe with a
 *     clean `403` and never reflects input or leaks sensitive data.
 *
 * A real {@link ProbeExecutor} issues each crafted probe against the stub over
 * HTTP, then decides vulnerability from the live response. The test asserts
 * that findings are produced for the vulnerable endpoint across all five
 * requirement groups and that the safe endpoint yields no findings.
 *
 * Running a loopback HTTP stub is always practical in this environment, so the
 * suite runs unconditionally (no skip gate needed) and performs no external
 * network I/O.
 *
 * Routing note: the stub classifies a request as "safe" vs "vulnerable" from
 * the *raw* request target prefix rather than the normalized URL pathname. A
 * path-traversal payload (`../../../../etc/passwd`) injected into the `:id`
 * segment would otherwise be collapsed by `new URL()` dot-segment
 * normalization and escape the `/safe` prefix entirely, mis-routing a hardened
 * request to the vulnerable handler. Matching on the raw target models a
 * hardened endpoint that still owns and rejects traversal attempts.
 */

import { AddressInfo } from 'net';
import http, { IncomingMessage, Server, ServerResponse } from 'http';

import {
  auditSecurity,
  ProbeExecutor,
  ProbeResult,
  SecurityProbeCase,
} from '../src/audit/security-auditor';
import {
  CatalogEntry,
  PostmanCollection,
  PostmanEnvironment,
  VulnCategory,
} from '../src/types';

// ---------------------------------------------------------------------------
// Local stub server
//
// /vulnerable/* — insecure: always 200, reflects query `q`, query
//   `header_inject`, and the raw request body, leaks file content on traversal,
//   and always discloses sensitive data.
// /safe/*       — hardened: always 403 with a clean body, no reflection, no leak.
// ---------------------------------------------------------------------------

/** Sensitive content the vulnerable endpoint discloses in every response. */
const SENSITIVE_BLOCK =
  ' SENSITIVE password:"hunter2" ssn:"123-45-6789" apiKey:"AKIAABCDEFGHIJ"' +
  ' stacktrace: Error at /app/server.js:42';

function startStubServer(): Promise<Server> {
  const server = http.createServer(
    (req: IncomingMessage, res: ServerResponse) => {
      const chunks: Buffer[] = [];
      req.on('data', (c) => chunks.push(c as Buffer));
      req.on('end', () => {
        const rawBody = Buffer.concat(chunks).toString('utf8');
        const rawTarget = req.url ?? '/';
        const url = new URL(rawTarget, 'http://stub.local');

        // Hardened endpoint: classify from the RAW request target so a
        // traversal payload in the path cannot normalize its way out of the
        // `/safe` prefix and reach the vulnerable handler. Reject everything
        // with a clean, leak-free body.
        if (rawTarget.startsWith('/safe')) {
          res.writeHead(403, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'forbidden' }));
          return;
        }

        // Deliberately vulnerable endpoint: reflect input and leak data.
        const q = url.searchParams.get('q') ?? '';
        const injected = url.searchParams.get('header_inject') ?? '';
        const decodedPath = safeDecode(rawTarget);

        let out = `reflected q=${q} inject=${injected} body=${rawBody}`;
        if (decodedPath.includes('etc/passwd') || decodedPath.includes('..')) {
          // Path-traversal leak of a system file.
          out += ' root:x:0:0:root:/root:/bin/bash ';
        }
        out += SENSITIVE_BLOCK;

        res.writeHead(200, { 'Content-Type': 'text/plain' });
        res.end(out);
      });
    }
  );

  return new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => resolve(server));
  });
}

/** Decodes a URI component, tolerating malformed encodings. */
function safeDecode(value: string): string {
  try {
    return decodeURIComponent(value);
  } catch {
    return value;
  }
}

// ---------------------------------------------------------------------------
// Real probe executor — issues the crafted probe against the stub over HTTP
// and decides vulnerability from the observed response.
// ---------------------------------------------------------------------------

/** A minimal HTTP response captured from the stub. */
interface HttpResponse {
  status: number;
  body: string;
}

/** Issues a single HTTP request against the loopback stub. */
function httpRequest(
  base: string,
  path: string,
  method: string,
  headers: Record<string, string>,
  body?: string
): Promise<HttpResponse> {
  return new Promise((resolve, reject) => {
    const target = new URL(base);
    const req = http.request(
      {
        hostname: target.hostname,
        port: target.port,
        path,
        method,
        headers,
      },
      (res) => {
        const chunks: Buffer[] = [];
        res.on('data', (c) => chunks.push(c as Buffer));
        res.on('end', () =>
          resolve({
            status: res.statusCode ?? 0,
            body: Buffer.concat(chunks).toString('utf8'),
          })
        );
      }
    );
    req.on('error', reject);
    if (body !== undefined) {
      req.write(body);
    }
    req.end();
  });
}

/** Patterns that signal sensitive data exposure in a response body. */
const SENSITIVE_PATTERNS: RegExp[] = [
  /password/i,
  /\bssn\b/i,
  /AKIA[0-9A-Z]{6,}/,
  /stacktrace/i,
  /Error at \//,
];

/** Decides whether a probe's observed response indicates a vulnerability. */
function isVulnerable(probe: SecurityProbeCase, res: HttpResponse): boolean {
  const is2xx = res.status >= 200 && res.status < 300;
  switch (probe.category) {
    case 'sql-injection':
    case 'nosql-injection':
    case 'xss':
      // Unsanitized verbatim reflection of the crafted payload.
      return is2xx && res.body.includes(probe.payload.value);
    case 'privilege-escalation':
      // Elevation field accepted/reflected.
      return is2xx && res.body.toLowerCase().includes('admin');
    case 'path-traversal':
      // System file content leaked back.
      return res.body.includes('root:');
    case 'header-injection':
      // Injected header content reflected into the response.
      return res.body.includes('hijacked');
    case 'sensitive-data-exposure':
      return SENSITIVE_PATTERNS.some((re) => re.test(res.body));
    case 'csrf':
    case 'jwt':
    case 'broken-auth':
    case 'broken-authz':
    case 'idor':
    case 'file-upload':
      // The crafted (unauthorized / forged / disguised) request was accepted.
      return is2xx;
    default:
      return false;
  }
}

/**
 * Builds a real probe executor bound to the stub's base URL. It crafts a live
 * HTTP request per probe — injecting the payload at its declared injection
 * point — sends it, and reports vulnerability based on the response.
 */
function makeRealExecutor(base: string): ProbeExecutor {
  return async (probe, request): Promise<ProbeResult> => {
    // Resolve the request URL template against the stub base URL.
    let path = request.url.replace('{{baseUrl}}', '');
    const headers: Record<string, string> = {};
    const query = new URLSearchParams();
    let body: string | undefined;

    const value = probe.payload.value;
    switch (probe.payload.injectionPoint) {
      case 'path':
        // Inject the payload into the `:id` path segment.
        path = replacePlaceholder(path, value);
        break;
      case 'query':
        path = replacePlaceholder(path, '123');
        query.set('q', value);
        break;
      case 'body':
        path = replacePlaceholder(path, '123');
        headers['Content-Type'] = 'application/json';
        body = value;
        break;
      case 'header':
        path = replacePlaceholder(path, '123');
        applyHeaderPayload(value, headers, query);
        break;
      case 'token':
        path = replacePlaceholder(path, '123');
        headers['Authorization'] = `Bearer ${value}`;
        break;
      case 'upload':
        path = replacePlaceholder(path, '123');
        headers['Content-Type'] = 'application/octet-stream';
        headers['X-Filename'] = 'shell.php';
        body = value;
        break;
    }

    const search = query.toString();
    if (search.length > 0) {
      path += (path.includes('?') ? '&' : '?') + search;
    }
    if (body !== undefined) {
      headers['Content-Length'] = String(Buffer.byteLength(body));
    }

    const res = await httpRequest(base, path, request.method, headers, body);
    return {
      vulnerable: isVulnerable(probe, res),
      observedResponse: res.body.slice(0, 200),
    };
  };
}

/** Replaces an Express/OpenAPI path placeholder (`:id` / `{id}`) with a value. */
function replacePlaceholder(path: string, value: string): string {
  return path.replace(/:[A-Za-z_]+|\{[^}]+\}/, value);
}

/**
 * Applies a header-style payload. CRLF-bearing values (response-splitting
 * attempts, which a real HTTP client cannot place in a header) are routed
 * through a query parameter the stub reflects, modelling a query→header
 * reflection sink. Well-formed `Name: value` headers are set directly.
 */
function applyHeaderPayload(
  value: string,
  headers: Record<string, string>,
  query: URLSearchParams
): void {
  if (/[\r\n]/.test(value)) {
    query.set('header_inject', value);
    return;
  }
  const idx = value.indexOf(':');
  if (idx > 0) {
    headers[value.slice(0, idx).trim()] = value.slice(idx + 1).trim();
  } else {
    query.set('header_inject', value);
  }
}

// ---------------------------------------------------------------------------
// Collection + catalog helpers
// ---------------------------------------------------------------------------

/**
 * Builds a catalog entry whose capabilities enable every security category:
 * authorized (auth/JWT/authz/escalation), path param (IDOR/traversal), body +
 * file param (injection/upload), POST (CSRF).
 */
function makeCatalogEntry(id: string): CatalogEntry {
  return {
    id,
    urlPath: 'undetermined',
    methodOrOperation: 'POST',
    module: 'undetermined',
    controllerOrHandler: 'undetermined',
    requestBodyParams: [
      { name: 'file', in: 'body', type: 'file', required: true },
      { name: 'note', in: 'body', type: 'string', required: false },
    ],
    queryParams: [{ name: 'q', in: 'query', type: 'string', required: false }],
    pathParams: [{ name: 'id', in: 'path', type: 'string', required: true }],
    headers: 'undetermined',
    security: { enforcement: 'authorized', requiredRole: 'admin' },
    requestSchema: 'undetermined',
    responseSchema: 'undetermined',
    errorResponses: 'undetermined',
    validationRules: 'undetermined',
    businessRules: 'undetermined',
    undeterminedReasons: {},
  };
}

function buildCollection(): PostmanCollection {
  return {
    info: { schema: 'v2.1.0' },
    folders: [
      {
        name: 'File-Transfer',
        items: [
          {
            name: 'Vulnerable record fetch',
            endpointId: 'vuln-ep',
            method: 'POST',
            url: '{{baseUrl}}/vulnerable/records/:id',
          },
          {
            name: 'Hardened record fetch',
            endpointId: 'safe-ep',
            method: 'POST',
            url: '{{baseUrl}}/safe/records/:id',
          },
        ],
      },
    ],
  };
}

function makeEnvironment(baseUrl: string): PostmanEnvironment {
  return { name: 'Local', values: [{ key: 'baseUrl', value: baseUrl }] };
}

/** The categories belonging to each requirement group (7.1–7.5). */
const REQUIREMENT_GROUPS: Record<string, VulnCategory[]> = {
  '7.1': ['sql-injection', 'nosql-injection', 'xss', 'csrf'],
  '7.2': ['jwt', 'broken-auth', 'broken-authz'],
  '7.3': ['idor', 'path-traversal', 'header-injection', 'privilege-escalation'],
  '7.4': ['file-upload'],
  '7.5': ['sensitive-data-exposure'],
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('Security_Auditor integration: probing vulnerable/safe stub endpoints', () => {
  let server: Server;
  let baseUrl: string;
  let executor: ProbeExecutor;

  beforeAll(async () => {
    server = await startStubServer();
    const { port } = server.address() as AddressInfo;
    baseUrl = `http://127.0.0.1:${port}`;
    executor = makeRealExecutor(baseUrl);
  });

  afterAll((done) => {
    server.close(() => done());
  });

  it('records findings across all five security categories for the vulnerable endpoint', async () => {
    const collection = buildCollection();
    const catalog = [makeCatalogEntry('vuln-ep'), makeCatalogEntry('safe-ep')];

    const result = await auditSecurity(collection, makeEnvironment(baseUrl), {
      probeExecutor: executor,
      catalog,
    });

    // No probe failed to execute against the live stub.
    expect(result.issues).toEqual([]);

    const vulnFindings = result.findings.filter(
      (f) => f.endpointId === 'vuln-ep'
    );
    expect(vulnFindings.length).toBeGreaterThan(0);

    const foundCategories = new Set(vulnFindings.map((f) => f.category));

    // At least one finding from every requirement group (7.1–7.5).
    for (const [requirement, categories] of Object.entries(REQUIREMENT_GROUPS)) {
      const covered = categories.some((c) => foundCategories.has(c));
      expect(covered).toBe(true);
      // (Annotate which requirement each assertion guards.)
      if (!covered) {
        throw new Error(`No finding for Requirement ${requirement}`);
      }
    }

    // Every finding is well-formed: endpoint, category, severity, payload ref.
    for (const finding of vulnFindings) {
      expect(finding.endpointId).toBe('vuln-ep');
      expect(typeof finding.category).toBe('string');
      expect(['low', 'medium', 'high', 'critical']).toContain(finding.severity);
      expect(finding.payloadRef.length).toBeGreaterThan(0);
    }
  }, 20000);

  it('produces no findings for the hardened (safe) endpoint', async () => {
    const collection = buildCollection();
    const catalog = [makeCatalogEntry('vuln-ep'), makeCatalogEntry('safe-ep')];

    const result = await auditSecurity(collection, makeEnvironment(baseUrl), {
      probeExecutor: executor,
      catalog,
    });

    const safeFindings = result.findings.filter(
      (f) => f.endpointId === 'safe-ep'
    );
    expect(safeFindings).toEqual([]);
  }, 20000);
});
