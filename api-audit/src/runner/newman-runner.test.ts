/**
 * Test_Runner — negative-case execution unit test (Task 10.2).
 *
 * Verifies that when a negative test case is executed, the Test_Runner asserts
 * the documented error status and error response and faithfully maps the
 * outcome into a `RequestOutcome` — the `passed` flag, `assertionFailures`,
 * and `statusCode` (Requirement 6.7).
 *
 * Approach: a lightweight local HTTP stub server stands in for the backend and
 * returns documented negative-case responses (e.g. 401 with an error body).
 * The real Newman runner executes a small collection whose requests carry the
 * negative-case assertions, exercising the full collection → Newman → mapping
 * path that `runCollection` owns.
 *
 * Validates: Requirement 6.7
 */
import { AddressInfo } from 'net';
import http, { IncomingMessage, Server, ServerResponse } from 'http';

import { runCollection } from './newman-runner';
import {
  GeneratedTest,
  PostmanCollection,
  PostmanEnvironment,
  PostmanRequest,
} from '../types';

// ---------------------------------------------------------------------------
// Local stub server
//
// Stands in for the backend and returns the documented error responses for the
// negative cases under test:
//   POST /login with a wrong password -> 401 { error: 'invalid_credentials' }
//   anything else                     -> 404 { error: 'not_found' }
// ---------------------------------------------------------------------------

function startStubServer(): Promise<Server> {
  const server = http.createServer(
    (req: IncomingMessage, res: ServerResponse) => {
      const chunks: Buffer[] = [];
      req.on('data', (c) => chunks.push(c as Buffer));
      req.on('end', () => {
        const raw = Buffer.concat(chunks).toString('utf8');
        let body: Record<string, unknown> = {};
        try {
          body = raw ? (JSON.parse(raw) as Record<string, unknown>) : {};
        } catch {
          body = {};
        }

        if (req.method === 'POST' && req.url === '/login') {
          // Negative case: invalid credentials yield the documented 401.
          if (body.password !== 'correct-password') {
            res.writeHead(401, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'invalid_credentials' }));
            return;
          }
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ token: 'ok' }));
          return;
        }

        res.writeHead(404, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'not_found' }));
      });
    }
  );

  return new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => resolve(server));
  });
}

// ---------------------------------------------------------------------------
// Collection helpers
// ---------------------------------------------------------------------------

function makeRequest(
  name: string,
  endpointId: string,
  scriptLines: string[]
): PostmanRequest {
  const tests: GeneratedTest[] = [
    {
      type: 'negative-bad-token',
      endpointId,
      script: scriptLines.join('\n'),
    },
  ];
  return {
    name,
    endpointId,
    method: 'POST',
    url: '{{baseUrl}}/login',
    body: { username: 'alice', password: 'wrong-password' },
    tests,
  };
}

function makeCollection(requests: PostmanRequest[]): PostmanCollection {
  return {
    info: { schema: 'v2.1.0' },
    folders: [{ name: 'Authentication', items: requests }],
  };
}

function makeEnvironment(baseUrl: string): PostmanEnvironment {
  return {
    name: 'Local',
    values: [{ key: 'baseUrl', value: baseUrl }],
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('Test_Runner negative-case execution against a stub server', () => {
  let server: Server;
  let baseUrl: string;

  beforeAll(async () => {
    server = await startStubServer();
    const { port } = server.address() as AddressInfo;
    baseUrl = `http://127.0.0.1:${port}`;
  });

  afterAll((done) => {
    server.close(() => done());
  });

  it('maps a passing negative case (documented 401 + error body) into a passed RequestOutcome', async () => {
    const collection = makeCollection([
      makeRequest('Login with invalid credentials returns 401', 'auth-login', [
        "pm.test('returns documented 401 status', function () {",
        '  pm.response.to.have.status(401);',
        '});',
        "pm.test('returns documented error response', function () {",
        "  pm.expect(pm.response.json().error).to.eql('invalid_credentials');",
        '});',
      ]),
    ]);

    const result = await runCollection(
      collection,
      makeEnvironment(baseUrl),
      { timeoutRequestMs: 5000 }
    );

    expect(result.environment).toBe('Local');
    expect(result.allPassed).toBe(true);
    expect(result.outcomes).toHaveLength(1);

    const [outcome] = result.outcomes;
    expect(outcome.endpointId).toBe('auth-login');
    expect(outcome.requestName).toBe(
      'Login with invalid credentials returns 401'
    );
    expect(outcome.passed).toBe(true);
    expect(outcome.assertionFailures).toEqual([]);
    expect(outcome.statusCode).toBe(401);
  });

  it('captures assertion failures and statusCode when the documented error status is not met', async () => {
    // The server returns 401, but this negative case wrongly expects 200 — the
    // assertion must surface as a failure and the outcome must not pass.
    const collection = makeCollection([
      makeRequest('Login expecting 200 (mismatched assertion)', 'auth-login', [
        "pm.test('expects status 200', function () {",
        '  pm.response.to.have.status(200);',
        '});',
      ]),
    ]);

    const result = await runCollection(
      collection,
      makeEnvironment(baseUrl),
      { timeoutRequestMs: 5000 }
    );

    expect(result.allPassed).toBe(false);
    expect(result.outcomes).toHaveLength(1);

    const [outcome] = result.outcomes;
    expect(outcome.passed).toBe(false);
    expect(outcome.statusCode).toBe(401);
    expect(outcome.assertionFailures.length).toBeGreaterThan(0);
    expect(outcome.assertionFailures[0]).toContain('expects status 200');
  });
});
