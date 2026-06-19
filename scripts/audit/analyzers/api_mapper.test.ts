/**
 * Unit tests for api_mapper — parseRoutes() and normalizePath()
 */

import * as fs from 'fs';
import * as path from 'path';
import * as yaml from 'js-yaml';
import { parseRoutes, normalizePath } from './api_mapper';
import { Route } from '../types';

// ─── normalizePath Tests ────────────────────────────────────────────────────

describe('normalizePath', () => {
  it('replaces single path parameter with wildcard', () => {
    expect(normalizePath('/users/{userId}')).toBe('/users/{*}');
  });

  it('replaces multiple path parameters', () => {
    expect(normalizePath('/users/{userId}/orders/{orderId}')).toBe('/users/{*}/orders/{*}');
  });

  it('leaves paths without parameters unchanged', () => {
    expect(normalizePath('/inventory')).toBe('/inventory');
    expect(normalizePath('/health/ready')).toBe('/health/ready');
  });

  it('handles parameter at the start of path', () => {
    expect(normalizePath('/{tenantId}/resources')).toBe('/{*}/resources');
  });

  it('handles path with only a parameter', () => {
    expect(normalizePath('/{id}')).toBe('/{*}');
  });

  it('handles various parameter names', () => {
    expect(normalizePath('/tenants/{tenantId}')).toBe('/tenants/{*}');
    expect(normalizePath('/storage/{key}')).toBe('/storage/{*}');
    expect(normalizePath('/admin/tenants/{id}')).toBe('/admin/tenants/{*}');
  });
});

// ─── parseRoutes Tests — Serverless Framework Format ────────────────────────

describe('parseRoutes — serverless.yml format', () => {
  const tmpDir = path.join(__dirname, '__test_tmp__');

  beforeAll(() => {
    fs.mkdirSync(tmpDir, { recursive: true });
  });

  afterAll(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  function writeYaml(filename: string, content: unknown): string {
    const filePath = path.join(tmpDir, filename);
    fs.writeFileSync(filePath, yaml.dump(content), 'utf-8');
    return filePath;
  }

  it('extracts routes with method, path, handler, and auth status', () => {
    const config = {
      functions: {
        getItems: {
          handler: 'dist/handlers/inventory.getItems',
          events: [
            { httpApi: { path: '/inventory', method: 'GET' } },
          ],
        },
        createItem: {
          handler: 'dist/handlers/inventory.createItem',
          events: [
            { httpApi: { path: '/inventory', method: 'POST' } },
          ],
        },
      },
    };

    const filePath = writeYaml('serverless.yml', config);
    const routes = parseRoutes([filePath]);

    expect(routes).toHaveLength(2);
    expect(routes[0]).toEqual({
      method: 'GET',
      path: '/inventory',
      normalizedPath: '/inventory',
      handlerFile: 'dist/handlers/inventory.getItems',
      authenticated: true,
      source: 'serverless.yml',
    });
    expect(routes[1]).toEqual({
      method: 'POST',
      path: '/inventory',
      normalizedPath: '/inventory',
      handlerFile: 'dist/handlers/inventory.createItem',
      authenticated: true,
      source: 'serverless.yml',
    });
  });

  it('marks routes with authorizer: { name: none } as unauthenticated', () => {
    const config = {
      functions: {
        health: {
          handler: 'dist/handlers/health.health',
          events: [
            { httpApi: { path: '/health', method: 'GET', authorizer: { name: 'none' } } },
          ],
        },
      },
    };

    const filePath = writeYaml('serverless.yml', config);
    const routes = parseRoutes([filePath]);

    expect(routes).toHaveLength(1);
    expect(routes[0].authenticated).toBe(false);
  });

  it('normalizes path parameters in extracted routes', () => {
    const config = {
      functions: {
        updateItem: {
          handler: 'dist/handlers/inventory.updateItem',
          events: [
            { httpApi: { path: '/inventory/{id}', method: 'PUT' } },
          ],
        },
      },
    };

    const filePath = writeYaml('serverless.yml', config);
    const routes = parseRoutes([filePath]);

    expect(routes[0].path).toBe('/inventory/{id}');
    expect(routes[0].normalizedPath).toBe('/inventory/{*}');
  });

  it('handles functions with multiple HTTP events', () => {
    const config = {
      functions: {
        authSignup: {
          handler: 'dist/handlers/auth.signup',
          events: [
            { httpApi: { path: '/auth/signup', method: 'POST', authorizer: { name: 'none' } } },
            { httpApi: { path: '/owner/register', method: 'POST', authorizer: { name: 'none' } } },
          ],
        },
      },
    };

    const filePath = writeYaml('serverless.yml', config);
    const routes = parseRoutes([filePath]);

    expect(routes).toHaveLength(2);
    expect(routes[0].path).toBe('/auth/signup');
    expect(routes[1].path).toBe('/owner/register');
  });

  it('skips non-HTTP events (e.g., cognito, s3, sqs)', () => {
    const config = {
      functions: {
        cognitoTrigger: {
          handler: 'dist/handlers/cognito.handler',
          events: [
            { cognitoUserPool: { pool: 'MyPool', trigger: 'PreTokenGeneration' } },
          ],
        },
        s3Trigger: {
          handler: 'dist/handlers/s3.handler',
          events: [
            { s3: { bucket: 'my-bucket', event: 's3:ObjectCreated:*' } },
          ],
        },
      },
    };

    const filePath = writeYaml('serverless.yml', config);
    const routes = parseRoutes([filePath]);

    expect(routes).toHaveLength(0);
  });

  it('uppercases HTTP methods', () => {
    const config = {
      functions: {
        fn: {
          handler: 'dist/handlers/fn.handler',
          events: [
            { httpApi: { path: '/test', method: 'get' } },
          ],
        },
      },
    };

    const filePath = writeYaml('serverless.yml', config);
    const routes = parseRoutes([filePath]);

    expect(routes[0].method).toBe('GET');
  });
});

// ─── parseRoutes Tests — SAM Template Format ────────────────────────────────

describe('parseRoutes — template.yaml format', () => {
  const tmpDir = path.join(__dirname, '__test_tmp_sam__');

  beforeAll(() => {
    fs.mkdirSync(tmpDir, { recursive: true });
  });

  afterAll(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  function writeYaml(filename: string, content: unknown): string {
    const filePath = path.join(tmpDir, filename);
    fs.writeFileSync(filePath, yaml.dump(content), 'utf-8');
    return filePath;
  }

  it('extracts routes from SAM template with HttpApi events', () => {
    const template = {
      Resources: {
        TenantHandler: {
          Type: 'AWS::Serverless::Function',
          Properties: {
            CodeUri: 'lambda/tenantHandler/',
            Handler: 'index.handler',
            Events: {
              CreateTenant: {
                Type: 'HttpApi',
                Properties: { Path: '/tenants', Method: 'POST' },
              },
              GetTenant: {
                Type: 'HttpApi',
                Properties: { Path: '/tenants/{tenantId}', Method: 'GET' },
              },
            },
          },
        },
      },
    };

    const filePath = writeYaml('template.yaml', template);
    const routes = parseRoutes([filePath]);

    expect(routes).toHaveLength(2);
    expect(routes[0]).toEqual({
      method: 'POST',
      path: '/tenants',
      normalizedPath: '/tenants',
      handlerFile: 'lambda/tenantHandler/index.handler',
      authenticated: true,
      source: 'template.yaml',
    });
    expect(routes[1]).toEqual({
      method: 'GET',
      path: '/tenants/{tenantId}',
      normalizedPath: '/tenants/{*}',
      handlerFile: 'lambda/tenantHandler/index.handler',
      authenticated: true,
      source: 'template.yaml',
    });
  });

  it('marks routes with Auth Authorizer NONE as unauthenticated', () => {
    const template = {
      Resources: {
        PublicHandler: {
          Type: 'AWS::Serverless::Function',
          Properties: {
            CodeUri: 'lambda/public/',
            Handler: 'index.handler',
            Events: {
              PublicRoute: {
                Type: 'HttpApi',
                Properties: {
                  Path: '/public/health',
                  Method: 'GET',
                  Auth: { Authorizer: 'NONE' },
                },
              },
            },
          },
        },
      },
    };

    const filePath = writeYaml('template.yaml', template);
    const routes = parseRoutes([filePath]);

    expect(routes[0].authenticated).toBe(false);
  });

  it('skips non-function resources', () => {
    const template = {
      Resources: {
        MyTable: {
          Type: 'AWS::DynamoDB::Table',
          Properties: { TableName: 'test' },
        },
        MyBucket: {
          Type: 'AWS::S3::Bucket',
          Properties: { BucketName: 'test-bucket' },
        },
      },
    };

    const filePath = writeYaml('template.yaml', template);
    const routes = parseRoutes([filePath]);

    expect(routes).toHaveLength(0);
  });

  it('handles CodeUri without trailing slash', () => {
    const template = {
      Resources: {
        Handler: {
          Type: 'AWS::Serverless::Function',
          Properties: {
            CodeUri: 'lambda/handler',
            Handler: 'index.handler',
            Events: {
              Get: {
                Type: 'HttpApi',
                Properties: { Path: '/test', Method: 'GET' },
              },
            },
          },
        },
      },
    };

    const filePath = writeYaml('template.yaml', template);
    const routes = parseRoutes([filePath]);

    expect(routes[0].handlerFile).toBe('lambda/handler/index.handler');
  });
});

// ─── parseRoutes Error Handling ─────────────────────────────────────────────

describe('parseRoutes — error handling', () => {
  const tmpDir = path.join(__dirname, '__test_tmp_err__');

  beforeAll(() => {
    fs.mkdirSync(tmpDir, { recursive: true });
  });

  afterAll(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('skips files that do not exist and continues', () => {
    const routes = parseRoutes(['/nonexistent/path/serverless.yml']);
    expect(routes).toHaveLength(0);
  });

  it('skips files with invalid YAML and continues with remaining files', () => {
    const invalidPath = path.join(tmpDir, 'serverless.yml');
    fs.writeFileSync(invalidPath, '{{{{invalid yaml: [[[', 'utf-8');

    const validPath = path.join(tmpDir, 'template.yaml');
    const validTemplate = {
      Resources: {
        Fn: {
          Type: 'AWS::Serverless::Function',
          Properties: {
            CodeUri: 'src/',
            Handler: 'index.handler',
            Events: {
              Api: {
                Type: 'HttpApi',
                Properties: { Path: '/valid', Method: 'GET' },
              },
            },
          },
        },
      },
    };
    fs.writeFileSync(validPath, yaml.dump(validTemplate), 'utf-8');

    // Should not throw, should parse the valid file
    const warnSpy = jest.spyOn(console, 'warn').mockImplementation(() => {});
    const routes = parseRoutes([invalidPath, validPath]);
    warnSpy.mockRestore();

    expect(routes).toHaveLength(1);
    expect(routes[0].path).toBe('/valid');
  });

  it('logs a warning for unparseable files', () => {
    const invalidPath = path.join(tmpDir, 'bad.yml');
    fs.writeFileSync(invalidPath, '{{{{invalid yaml content', 'utf-8');

    const warnSpy = jest.spyOn(console, 'warn').mockImplementation(() => {});
    parseRoutes([invalidPath]);

    expect(warnSpy).toHaveBeenCalledWith(
      expect.stringContaining('[api_mapper] Skipping')
    );
    expect(warnSpy).toHaveBeenCalledWith(
      expect.stringContaining(invalidPath)
    );
    warnSpy.mockRestore();
  });

  it('handles empty YAML files gracefully', () => {
    const emptyPath = path.join(tmpDir, 'serverless.yml');
    fs.writeFileSync(emptyPath, '', 'utf-8');

    const warnSpy = jest.spyOn(console, 'warn').mockImplementation(() => {});
    const routes = parseRoutes([emptyPath]);
    warnSpy.mockRestore();

    expect(routes).toHaveLength(0);
  });

  it('handles YAML with no functions key gracefully', () => {
    const noFunctionsPath = path.join(tmpDir, 'serverless.yml');
    fs.writeFileSync(noFunctionsPath, yaml.dump({ service: 'my-service' }), 'utf-8');

    const routes = parseRoutes([noFunctionsPath]);
    expect(routes).toHaveLength(0);
  });
});

// ─── parseRoutes — Multiple Files ───────────────────────────────────────────

describe('parseRoutes — multiple config files', () => {
  const tmpDir = path.join(__dirname, '__test_tmp_multi__');

  beforeAll(() => {
    fs.mkdirSync(tmpDir, { recursive: true });
  });

  afterAll(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('combines routes from multiple config files', () => {
    const slsPath = path.join(tmpDir, 'serverless.yml');
    fs.writeFileSync(slsPath, yaml.dump({
      functions: {
        fn1: {
          handler: 'dist/handlers/fn1.handler',
          events: [{ httpApi: { path: '/sls-route', method: 'GET' } }],
        },
      },
    }), 'utf-8');

    const samPath = path.join(tmpDir, 'template.yaml');
    fs.writeFileSync(samPath, yaml.dump({
      Resources: {
        Fn2: {
          Type: 'AWS::Serverless::Function',
          Properties: {
            CodeUri: 'lambda/fn2/',
            Handler: 'index.handler',
            Events: {
              Api: { Type: 'HttpApi', Properties: { Path: '/sam-route', Method: 'POST' } },
            },
          },
        },
      },
    }), 'utf-8');

    const routes = parseRoutes([slsPath, samPath]);

    expect(routes).toHaveLength(2);
    expect(routes[0].source).toBe('serverless.yml');
    expect(routes[1].source).toBe('template.yaml');
  });
});


// ─── scanCallSites Tests ────────────────────────────────────────────────────

import { scanCallSites } from './api_mapper';

describe('scanCallSites', () => {
  const tmpDir = path.join(__dirname, '__test_tmp_callsites__');
  const libDir = path.join(tmpDir, 'lib');

  beforeAll(() => {
    fs.mkdirSync(libDir, { recursive: true });
  });

  afterAll(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  function writeDartFile(relativePath: string, content: string): void {
    const fullPath = path.join(tmpDir, relativePath);
    fs.mkdirSync(path.dirname(fullPath), { recursive: true });
    fs.writeFileSync(fullPath, content, 'utf-8');
  }

  it('detects apiClient.get() call sites', () => {
    writeDartFile('lib/features/test/repo.dart', `
class TestRepo {
  final _apiClient = ApiClient();

  Future<void> getItems() async {
    final response = await _apiClient.get('/items');
  }
}
`);

    const sites = scanCallSites(tmpDir);
    expect(sites.length).toBeGreaterThanOrEqual(1);
    const match = sites.find(s => s.requestPath === '/items');
    expect(match).toBeDefined();
    expect(match!.httpMethod).toBe('GET');
    expect(match!.normalizedPath).toBe('/items');
  });

  it('detects apiClient.post() with path parameters and normalizes them', () => {
    writeDartFile('lib/features/orders/order_repo.dart', `
class OrderRepo {
  Future<void> createOrder(String id) async {
    final response = await _apiClient.post('/orders/\$id/items');
  }
}
`);

    const sites = scanCallSites(tmpDir);
    const match = sites.find(s => s.requestPath === '/orders/{id}/items');
    expect(match).toBeDefined();
    expect(match!.httpMethod).toBe('POST');
    expect(match!.normalizedPath).toBe('/orders/{*}/items');
  });

  it('detects http.get(Uri.parse(...)) pattern', () => {
    writeDartFile('lib/services/config_service.dart', `
class ConfigService {
  Future<void> loadConfig() async {
    final response = await http.get(Uri.parse('\$baseUrl/tenant/config'));
  }
}
`);

    const sites = scanCallSites(tmpDir);
    const match = sites.find(s => s.requestPath === '/tenant/config');
    expect(match).toBeDefined();
    expect(match!.httpMethod).toBe('GET');
  });

  it('detects dio.get() call sites', () => {
    writeDartFile('lib/services/payment_service.dart', `
class PaymentService {
  Future<void> getStatus(String billId) async {
    final response = await _dio.get('/billing/payment/status/\$billId');
  }
}
`);

    const sites = scanCallSites(tmpDir);
    const match = sites.find(s => s.requestPath === '/billing/payment/status/{billId}');
    expect(match).toBeDefined();
    expect(match!.httpMethod).toBe('GET');
    expect(match!.normalizedPath).toBe('/billing/payment/status/{*}');
  });

  it('detects http.post(Uri.parse(...)) pattern', () => {
    writeDartFile('lib/services/device_service.dart', `
class DeviceService {
  Future<void> register() async {
    final response = await http.post(Uri.parse('\$_baseUrl/devices/register'));
  }
}
`);

    const sites = scanCallSites(tmpDir);
    const match = sites.find(s => s.requestPath === '/devices/register');
    expect(match).toBeDefined();
    expect(match!.httpMethod).toBe('POST');
  });

  it('records correct line numbers', () => {
    writeDartFile('lib/features/simple/simple_repo.dart', `line1
line2
line3
class Repo {
  Future<void> fetch() async {
    final r = await _apiClient.get('/simple/path');
  }
}
`);

    const sites = scanCallSites(tmpDir);
    const match = sites.find(s => s.requestPath === '/simple/path');
    expect(match).toBeDefined();
    expect(match!.lineNumber).toBe(6);
  });

  it('records correct source file path', () => {
    writeDartFile('lib/features/billing/billing_repo.dart', `
class BillingRepo {
  Future<void> get() async {
    await _apiClient.get('/billing/invoices');
  }
}
`);

    const sites = scanCallSites(tmpDir);
    const match = sites.find(s => s.requestPath === '/billing/invoices');
    expect(match).toBeDefined();
    expect(match!.screenFile).toBe('lib/features/billing/billing_repo.dart');
  });

  it('handles multi-line apiClient calls', () => {
    writeDartFile('lib/features/multi/multi_repo.dart', `
class MultiRepo {
  Future<void> list() async {
    final response = await _apiClient.get(
      '/multi/items',
      queryParameters: {},
    );
  }
}
`);

    const sites = scanCallSites(tmpDir);
    const match = sites.find(s => s.requestPath === '/multi/items');
    expect(match).toBeDefined();
    expect(match!.httpMethod).toBe('GET');
  });

  it('detects multiple call sites in a single file', () => {
    writeDartFile('lib/features/crud/crud_repo.dart', `
class CrudRepo {
  Future<void> list() async {
    await _apiClient.get('/crud/items');
  }
  Future<void> create(Map data) async {
    await _apiClient.post('/crud/items');
  }
  Future<void> update(String id, Map data) async {
    await _apiClient.put('/crud/items/\$id');
  }
  Future<void> remove(String id) async {
    await _apiClient.delete('/crud/items/\$id');
  }
}
`);

    const sites = scanCallSites(tmpDir);
    const crudSites = sites.filter(s => s.requestPath.startsWith('/crud/'));
    expect(crudSites.length).toBe(4);
    expect(crudSites.map(s => s.httpMethod).sort()).toEqual(['DELETE', 'GET', 'POST', 'PUT']);
  });

  it('returns empty array for non-existent flutter root', () => {
    const sites = scanCallSites('/nonexistent/path');
    expect(sites).toEqual([]);
  });

  it('skips non-API URIs (tel:, upi:, etc.)', () => {
    writeDartFile('lib/screens/contact_screen.dart', `
class ContactScreen {
  void call() {
    final uri = Uri.parse('tel:\${customer.phone}');
  }
}
`);

    const sites = scanCallSites(tmpDir);
    const telSites = sites.filter(s => s.requestPath.includes('tel'));
    expect(telSites).toHaveLength(0);
  });

  it('detects patch HTTP method', () => {
    writeDartFile('lib/features/patch_test/patch_repo.dart', `
class PatchRepo {
  Future<void> update(String id) async {
    await _apiClient.patch('/resources/\$id/status');
  }
}
`);

    const sites = scanCallSites(tmpDir);
    const match = sites.find(s => s.requestPath === '/resources/{id}/status');
    expect(match).toBeDefined();
    expect(match!.httpMethod).toBe('PATCH');
  });

  it('handles ${expression} style interpolation', () => {
    writeDartFile('lib/features/expr/expr_repo.dart', `
class ExprRepo {
  Future<void> get(String userId) async {
    await _apiClient.get('/users/\${widget.userId}/profile');
  }
}
`);

    const sites = scanCallSites(tmpDir);
    const match = sites.find(s => s.requestPath.includes('/users/'));
    expect(match).toBeDefined();
    expect(match!.requestPath).toBe('/users/{widget.userId}/profile');
    expect(match!.normalizedPath).toBe('/users/{*}/profile');
  });
});


// ─── matchCallSitesToRoutes Tests ───────────────────────────────────────────

import { matchCallSitesToRoutes, generateMatchSummary } from './api_mapper';
import { CallSite, MatchResult } from '../types';

describe('matchCallSitesToRoutes', () => {
  const makeRoute = (method: string, routePath: string, handlerFile = 'handler.ts'): Route => ({
    method: method.toUpperCase(),
    path: routePath,
    normalizedPath: normalizePath(routePath),
    handlerFile,
    authenticated: true,
    source: 'serverless.yml',
  });

  const makeCallSite = (httpMethod: string, requestPath: string, screenFile = 'lib/test.dart'): CallSite => ({
    screenFile,
    requestPath,
    normalizedPath: normalizePath(requestPath),
    httpMethod: httpMethod.toUpperCase(),
    lineNumber: 1,
  });

  it('matches call sites to routes by normalized path and method', () => {
    const routes = [makeRoute('GET', '/users/{userId}')];
    const callSites = [makeCallSite('GET', '/users/{id}')];

    const result = matchCallSitesToRoutes(callSites, routes);

    expect(result.matched).toHaveLength(1);
    expect(result.matched[0].callSite).toBe(callSites[0]);
    expect(result.matched[0].route).toBe(routes[0]);
    expect(result.brokenDependencies).toHaveLength(0);
    expect(result.orphanedRoutes).toHaveLength(0);
  });

  it('identifies broken dependencies (call sites with no matching route)', () => {
    const routes = [makeRoute('GET', '/products')];
    const callSites = [makeCallSite('GET', '/nonexistent/path')];

    const result = matchCallSitesToRoutes(callSites, routes);

    expect(result.matched).toHaveLength(0);
    expect(result.brokenDependencies).toHaveLength(1);
    expect(result.brokenDependencies[0]).toBe(callSites[0]);
  });

  it('identifies orphaned routes (routes with no matching call site)', () => {
    const routes = [makeRoute('GET', '/orphaned'), makeRoute('POST', '/used')];
    const callSites = [makeCallSite('POST', '/used')];

    const result = matchCallSitesToRoutes(callSites, routes);

    expect(result.matched).toHaveLength(1);
    expect(result.orphanedRoutes).toHaveLength(1);
    expect(result.orphanedRoutes[0].path).toBe('/orphaned');
  });

  it('does not match when methods differ', () => {
    const routes = [makeRoute('POST', '/items')];
    const callSites = [makeCallSite('GET', '/items')];

    const result = matchCallSitesToRoutes(callSites, routes);

    expect(result.matched).toHaveLength(0);
    expect(result.brokenDependencies).toHaveLength(1);
    expect(result.orphanedRoutes).toHaveLength(1);
  });

  it('performs case-insensitive path matching', () => {
    const routes = [makeRoute('GET', '/Users/{userId}')];
    const callSites = [makeCallSite('GET', '/users/{id}')];

    const result = matchCallSitesToRoutes(callSites, routes);

    expect(result.matched).toHaveLength(1);
  });

  it('handles empty call sites array', () => {
    const routes = [makeRoute('GET', '/test')];
    const callSites: CallSite[] = [];

    const result = matchCallSitesToRoutes(callSites, routes);

    expect(result.matched).toHaveLength(0);
    expect(result.brokenDependencies).toHaveLength(0);
    expect(result.orphanedRoutes).toHaveLength(1);
  });

  it('handles empty routes array', () => {
    const routes: Route[] = [];
    const callSites = [makeCallSite('GET', '/test')];

    const result = matchCallSitesToRoutes(callSites, routes);

    expect(result.matched).toHaveLength(0);
    expect(result.brokenDependencies).toHaveLength(1);
    expect(result.orphanedRoutes).toHaveLength(0);
  });

  it('handles both arrays empty', () => {
    const result = matchCallSitesToRoutes([], []);

    expect(result.matched).toHaveLength(0);
    expect(result.brokenDependencies).toHaveLength(0);
    expect(result.orphanedRoutes).toHaveLength(0);
  });

  it('matches multiple call sites to same route', () => {
    const routes = [makeRoute('GET', '/items')];
    const callSites = [
      makeCallSite('GET', '/items', 'lib/screen_a.dart'),
      makeCallSite('GET', '/items', 'lib/screen_b.dart'),
    ];

    const result = matchCallSitesToRoutes(callSites, routes);

    // Both call sites should match the same route
    expect(result.matched).toHaveLength(2);
    expect(result.brokenDependencies).toHaveLength(0);
    expect(result.orphanedRoutes).toHaveLength(0);
  });

  it('handles mixed scenario with matches, broken deps, and orphans', () => {
    const routes = [
      makeRoute('GET', '/items'),
      makeRoute('POST', '/items'),
      makeRoute('DELETE', '/admin/cleanup'),
    ];
    const callSites = [
      makeCallSite('GET', '/items'),
      makeCallSite('POST', '/items'),
      makeCallSite('PUT', '/items/{id}'),
    ];

    const result = matchCallSitesToRoutes(callSites, routes);

    expect(result.matched).toHaveLength(2);
    expect(result.brokenDependencies).toHaveLength(1);
    expect(result.brokenDependencies[0].httpMethod).toBe('PUT');
    expect(result.orphanedRoutes).toHaveLength(1);
    expect(result.orphanedRoutes[0].path).toBe('/admin/cleanup');
  });
});

// ─── generateMatchSummary Tests ─────────────────────────────────────────────

describe('generateMatchSummary', () => {
  it('generates summary with correct totals', () => {
    const result: MatchResult = {
      matched: [{ callSite: {} as CallSite, route: {} as Route }],
      brokenDependencies: [],
      orphanedRoutes: [],
    };

    const summary = generateMatchSummary(result, 5, 3);

    expect(summary).toContain('Cataloged routes:       5');
    expect(summary).toContain('Mapped call sites:      3');
    expect(summary).toContain('Matched pairs:          1');
    expect(summary).toContain('Broken dependencies:    0 (P1)');
    expect(summary).toContain('Orphaned routes:        0 (P2)');
  });

  it('lists broken dependencies when present', () => {
    const brokenCallSite: CallSite = {
      screenFile: 'lib/features/billing/repo.dart',
      requestPath: '/billing/unknown',
      normalizedPath: '/billing/unknown',
      httpMethod: 'GET',
      lineNumber: 42,
    };

    const result: MatchResult = {
      matched: [],
      brokenDependencies: [brokenCallSite],
      orphanedRoutes: [],
    };

    const summary = generateMatchSummary(result, 2, 1);

    expect(summary).toContain('Broken Dependencies (P1)');
    expect(summary).toContain('[GET] /billing/unknown');
    expect(summary).toContain('lib/features/billing/repo.dart:42');
  });

  it('lists orphaned routes when present', () => {
    const orphanedRoute: Route = {
      method: 'DELETE',
      path: '/admin/purge/{tenantId}',
      normalizedPath: '/admin/purge/{*}',
      handlerFile: 'dist/handlers/admin.purge',
      authenticated: true,
      source: 'serverless.yml',
    };

    const result: MatchResult = {
      matched: [],
      brokenDependencies: [],
      orphanedRoutes: [orphanedRoute],
    };

    const summary = generateMatchSummary(result, 3, 0);

    expect(summary).toContain('Orphaned Routes (P2)');
    expect(summary).toContain('[DELETE] /admin/purge/{tenantId}');
    expect(summary).toContain('dist/handlers/admin.purge (serverless.yml)');
  });

  it('omits broken dependencies section when none exist', () => {
    const result: MatchResult = {
      matched: [],
      brokenDependencies: [],
      orphanedRoutes: [{ method: 'GET', path: '/x', normalizedPath: '/x', handlerFile: 'h', authenticated: true, source: 'serverless.yml' }],
    };

    const summary = generateMatchSummary(result, 1, 0);

    expect(summary).not.toContain('Broken Dependencies (P1) —');
    expect(summary).toContain('Orphaned Routes (P2)');
  });

  it('omits orphaned routes section when none exist', () => {
    const result: MatchResult = {
      matched: [],
      brokenDependencies: [{ screenFile: 'a.dart', requestPath: '/x', normalizedPath: '/x', httpMethod: 'GET', lineNumber: 1 }],
      orphanedRoutes: [],
    };

    const summary = generateMatchSummary(result, 0, 1);

    expect(summary).toContain('Broken Dependencies (P1)');
    expect(summary).not.toContain('Orphaned Routes (P2) —');
  });
});
