/**
 * Unit tests for the Discovery_Engine source scanners against fixtures
 * (task 4.8).
 *
 * Each scanner is exercised against a representative fixture file under
 * `tests/fixtures/scanners/` and asserted to extract the expected
 * `RawEndpoint` sightings — both endpoint identities and their source
 * attribution — including the WebSocket `$connect`/`$disconnect` lifecycle
 * routes.
 *
 * Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5
 */
import * as fs from 'fs';
import * as path from 'path';

import {
  scanCodeFile,
  scanConfigFile,
  scanGraphqlSource,
  scanOpenApiFile,
} from '../src/discovery/scanners';
import type { RawEndpoint } from '../src/discovery/dedup';
import type { EndpointIdentity, SourceRef } from '../src/types';

const FIXTURE_ROOT = path.join(__dirname, 'fixtures', 'scanners');

/** Read a fixture file's text content. */
function readFixture(...segments: string[]): string {
  return fs.readFileSync(path.join(FIXTURE_ROOT, ...segments), 'utf8');
}

/** Find the single raw endpoint matching a predicate (fails if 0 or >1). */
function findOne(
  endpoints: RawEndpoint[],
  predicate: (e: RawEndpoint) => boolean,
): RawEndpoint {
  const matches = endpoints.filter(predicate);
  expect(matches).toHaveLength(1);
  return matches[0];
}

/** True when a raw endpoint's identity matches the given REST signature. */
function isRest(method: string, routePath: string) {
  return (e: RawEndpoint): boolean =>
    e.identity.kind === 'rest' &&
    e.identity.method === method &&
    e.identity.path === routePath;
}

/** True when a raw endpoint's identity matches the given kind + operation name. */
function isNamed(kind: EndpointIdentity['kind'], operationName: string) {
  return (e: RawEndpoint): boolean =>
    e.identity.kind === kind && e.identity.operationName === operationName;
}

describe('code scanner (scanCodeFile)', () => {
  it('extracts Express-style REST route registrations with code attribution (Req 1.1)', () => {
    const file = path.join(FIXTURE_ROOT, 'code', 'routes', 'customer.routes.ts');
    const endpoints = scanCodeFile(file, fs.readFileSync(file, 'utf8'));

    const get = findOne(endpoints, isRest('GET', '/customers'));
    expect(get.source.artifactType).toBe('code');
    expect(get.source.locator).toBe('route-registration');
    expect(get.source.filePath).toBe(file);

    expect(endpoints.filter(isRest('POST', '/customers'))).toHaveLength(1);
    expect(endpoints.filter(isRest('PUT', '/customers/:id'))).toHaveLength(1);
    expect(endpoints.filter(isRest('DELETE', '/customers/:id'))).toHaveLength(1);
  });

  it('extracts REST routes from doc-comment annotations (Req 1.1)', () => {
    const file = path.join(FIXTURE_ROOT, 'code', 'handlers', 'health.handler.js');
    const endpoints = scanCodeFile(file, fs.readFileSync(file, 'utf8'));

    const health = findOne(endpoints, isRest('GET', '/health'));
    expect(health.source.artifactType).toBe('code');
    expect(health.source.locator).toBe('doc-comment');

    expect(endpoints.filter(isRest('GET', '/health/deep'))).toHaveLength(1);
  });

  it('extracts WebSocket lifecycle routes including $connect/$disconnect (Req 1.5)', () => {
    const file = path.join(FIXTURE_ROOT, 'code', 'websocket', 'inventory.ws.ts');
    const endpoints = scanCodeFile(file, fs.readFileSync(file, 'utf8'));

    const connect = findOne(endpoints, isNamed('ws-route', '$connect'));
    expect(connect.source.artifactType).toBe('code');
    expect(connect.source.locator).toBe('ws-route');

    expect(endpoints.filter(isNamed('ws-route', '$disconnect'))).toHaveLength(1);
    expect(endpoints.filter(isNamed('ws-route', '$default'))).toHaveLength(1);
  });

  it('extracts dotted WebSocket event names within a WebSocket file (Req 1.5)', () => {
    const file = path.join(FIXTURE_ROOT, 'code', 'websocket', 'inventory.ws.ts');
    const endpoints = scanCodeFile(file, fs.readFileSync(file, 'utf8'));

    const event = findOne(endpoints, isNamed('ws-event', 'inventory.stock.updated'));
    expect(event.source.locator).toBe('ws-event');

    expect(
      endpoints.filter(isNamed('ws-event', 'inventory.item.created')),
    ).toHaveLength(1);
  });

  it('extracts GraphQL operations from gql tagged templates (Req 1.4)', () => {
    const file = path.join(FIXTURE_ROOT, 'code', 'graphql', 'product.queries.ts');
    const endpoints = scanCodeFile(file, fs.readFileSync(file, 'utf8'));

    const query = findOne(endpoints, isNamed('graphql-query', 'GetProducts'));
    expect(query.source.artifactType).toBe('code');
    expect(query.source.locator).toBe('graphql-literal');

    expect(
      endpoints.filter(isNamed('graphql-mutation', 'CreateProduct')),
    ).toHaveLength(1);
  });
});

describe('config scanner (scanConfigFile)', () => {
  it('extracts serverless http and websocket events incl. $connect/$disconnect (Req 1.2, 1.5)', () => {
    const file = path.join(FIXTURE_ROOT, 'config', 'serverless.yml');
    const endpoints = scanConfigFile(file, readFixture('config', 'serverless.yml'));

    // REST http events (object form and "METHOD /path" string form).
    const list = findOne(endpoints, isRest('GET', '/invoices'));
    expect(list.source.artifactType).toBe('configuration');
    expect(list.source.locator).toBe('listInvoices');
    expect(endpoints.filter(isRest('GET', '/invoices/{id}'))).toHaveLength(1);

    // WebSocket lifecycle routes (object form and string form).
    const connect = findOne(endpoints, isNamed('ws-route', '$connect'));
    expect(connect.source.locator).toBe('websocketConnect');
    expect(endpoints.filter(isNamed('ws-route', '$disconnect'))).toHaveLength(1);
  });

  it('extracts SAM HttpApi/Api function events (Req 1.2)', () => {
    const file = path.join(FIXTURE_ROOT, 'config', 'template.yaml');
    const endpoints = scanConfigFile(file, readFixture('config', 'template.yaml'));

    const getUser = findOne(endpoints, isRest('GET', '/users/{id}'));
    expect(getUser.source.artifactType).toBe('configuration');
    expect(getUser.source.locator).toBe('GetUser');

    const createUser = findOne(endpoints, isRest('POST', '/users'));
    expect(createUser.source.locator).toBe('CreateUser');
  });

  it('extracts CloudFormation V2 routes and reconstructs V1 method paths (Req 1.2, 1.5)', () => {
    const file = path.join(FIXTURE_ROOT, 'config', 'api-gateway.yml');
    const endpoints = scanConfigFile(file, readFixture('config', 'api-gateway.yml'));

    // ApiGatewayV2 WebSocket lifecycle routes.
    expect(endpoints.filter(isNamed('ws-route', '$connect'))).toHaveLength(1);
    expect(endpoints.filter(isNamed('ws-route', '$disconnect'))).toHaveLength(1);

    // ApiGatewayV2 REST-shaped route key.
    expect(endpoints.filter(isRest('POST', '/messages'))).toHaveLength(1);

    // ApiGateway (v1) Method joined with the Resource tree to rebuild the path.
    const productsGet = findOne(endpoints, isRest('GET', '/products'));
    expect(productsGet.source.artifactType).toBe('configuration');
    expect(productsGet.source.locator).toBe('ProductsGetMethod');
  });
});

describe('openapi scanner (scanOpenApiFile)', () => {
  it('extracts paths, methods, and operationIds (Req 1.3)', () => {
    const file = path.join(FIXTURE_ROOT, 'openapi', 'openapi.yaml');
    const endpoints = scanOpenApiFile(file, readFixture('openapi', 'openapi.yaml'));

    const health = findOne(endpoints, isRest('GET', '/health'));
    expect(health.source.artifactType).toBe('configuration');
    expect(health.source.locator).toBe('getHealth');

    const getCustomer = findOne(endpoints, isRest('GET', '/customers/{id}'));
    expect(getCustomer.source.locator).toBe('getCustomer');

    const deleteCustomer = findOne(endpoints, isRest('DELETE', '/customers/{id}'));
    expect(deleteCustomer.source.locator).toBe('deleteCustomer');
  });
});

describe('graphql scanner (scanGraphqlSource)', () => {
  it('extracts query, mutation, and subscription root fields (Req 1.4)', () => {
    const content = readFixture('graphql', 'schema.graphql');
    const source: SourceRef = {
      filePath: path.join(FIXTURE_ROOT, 'graphql', 'schema.graphql'),
      artifactType: 'configuration',
    };
    const endpoints = scanGraphqlSource(content, source);

    expect(endpoints.filter(isNamed('graphql-query', 'customers'))).toHaveLength(1);
    expect(endpoints.filter(isNamed('graphql-query', 'customer'))).toHaveLength(1);
    expect(
      endpoints.filter(isNamed('graphql-mutation', 'createCustomer')),
    ).toHaveLength(1);
    expect(
      endpoints.filter(isNamed('graphql-subscription', 'customerUpdated')),
    ).toHaveLength(1);

    for (const endpoint of endpoints) {
      expect(endpoint.source.artifactType).toBe('configuration');
    }
  });
});
