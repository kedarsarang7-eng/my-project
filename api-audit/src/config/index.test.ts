/**
 * Config Loader unit tests.
 *
 * Confirms that credentials, tokens, and connection values are sourced from
 * environment variables: the loader reads each environment's required
 * variables from the supplied env source (defaulting to `process.env`) and
 * exposes the resolved values via `EnvironmentConfig.variableValues`, while
 * surfacing only variable *names* in `requiredVars`.
 *
 * Validates: Requirements 14.1
 */
import { EnvConfigLoader, createConfigLoader } from './index';

describe('EnvConfigLoader — reading values from the environment (Req 14.1)', () => {
  it('sources connection values (base URL) from the env source', () => {
    const env = {
      LOCAL_BASE_URL: 'http://localhost:4000',
      LOCAL_AUTH_TOKEN: 'local-token-value',
    };

    const { configs } = new EnvConfigLoader(env).load({ environments: ['Local'] });
    const local = configs.find((c) => c.name === 'Local');

    expect(local).toBeDefined();
    expect(local?.baseUrl).toBe('http://localhost:4000');
  });

  it('resolves credential and token values into variableValues from the env source', () => {
    const env = {
      AWS_BASE_URL: 'https://api.aws.example.com',
      AWS_AUTH_TOKEN: 'aws-secret-token',
      AWS_REGION: 'us-east-1',
      AWS_ACCESS_KEY_ID: 'AKIAEXAMPLE',
      AWS_SECRET_ACCESS_KEY: 'super-secret-access-key',
    };

    const { configs, missing } = new EnvConfigLoader(env).load({
      environments: ['AWS'],
    });
    const aws = configs.find((c) => c.name === 'AWS');

    expect(missing).toEqual([]);
    expect(aws).toBeDefined();
    // Every credential/token/connection value is sourced from the env source.
    expect(aws?.variableValues.get('AWS_BASE_URL')).toBe(
      'https://api.aws.example.com',
    );
    expect(aws?.variableValues.get('AWS_AUTH_TOKEN')).toBe('aws-secret-token');
    expect(aws?.variableValues.get('AWS_REGION')).toBe('us-east-1');
    expect(aws?.variableValues.get('AWS_ACCESS_KEY_ID')).toBe('AKIAEXAMPLE');
    expect(aws?.variableValues.get('AWS_SECRET_ACCESS_KEY')).toBe(
      'super-secret-access-key',
    );
  });

  it('only resolves values for variables present in the env source', () => {
    // AUTH_TOKEN is absent: it must not appear in variableValues.
    const env = { LOCAL_BASE_URL: 'http://localhost:4000' };

    const { configs } = new EnvConfigLoader(env).load({ environments: ['Local'] });
    const local = configs.find((c) => c.name === 'Local');

    expect(local?.variableValues.has('LOCAL_BASE_URL')).toBe(true);
    expect(local?.variableValues.has('LOCAL_AUTH_TOKEN')).toBe(false);
  });

  it('exposes variable names (not values) via requiredVars', () => {
    const env = {
      DEV_BASE_URL: 'http://localhost:3000',
      DEV_AUTH_TOKEN: 'dev-token',
    };

    const { configs } = new EnvConfigLoader(env).load({
      environments: ['Development'],
    });
    const dev = configs.find((c) => c.name === 'Development');

    expect(dev?.requiredVars).toEqual(['DEV_BASE_URL', 'DEV_AUTH_TOKEN']);
    // The names list never carries the resolved secret values.
    expect(dev?.requiredVars).not.toContain('dev-token');
  });

  it('treats whitespace-only values as absent rather than reading them', () => {
    const env = {
      LOCAL_BASE_URL: '   ',
      LOCAL_AUTH_TOKEN: 'token',
    };

    const { configs, missing } = new EnvConfigLoader(env).load({
      environments: ['Local'],
    });
    const local = configs.find((c) => c.name === 'Local');

    expect(local?.variableValues.has('LOCAL_BASE_URL')).toBe(false);
    expect(local?.baseUrl).toBe('');
    expect(missing).toContain('LOCAL_BASE_URL');
  });

  it('defaults to reading from process.env when no env source is provided', () => {
    const VAR = 'DEV_AUTH_TOKEN';
    const previous = process.env[VAR];
    process.env[VAR] = 'token-from-process-env';

    try {
      const { configs } = createConfigLoader().load({
        environments: ['Development'],
      });
      const dev = configs.find((c) => c.name === 'Development');
      expect(dev?.variableValues.get(VAR)).toBe('token-from-process-env');
    } finally {
      if (previous === undefined) {
        delete process.env[VAR];
      } else {
        process.env[VAR] = previous;
      }
    }
  });
});
