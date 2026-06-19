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
