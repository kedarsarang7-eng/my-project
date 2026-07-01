/**
 * Config Loader stage.
 *
 * Resolves the five target environment configurations (Development, Local,
 * Staging, AWS, Production), reads variable values from `process.env`, and
 * computes the set of missing required variables so the run can be stopped
 * before any stage executes (Requirements 14.1, 14.5).
 *
 * Secret safety: only variable *names* are ever surfaced (in `requiredVars`
 * and the `missing` list). Resolved values live in `variableValues` and are
 * never logged or echoed by this module (Requirement 14.5).
 */

import type { EnvironmentConfig, RunOptions } from '../types';

/** Convenience alias for the five supported environment names. */
type EnvironmentName = EnvironmentConfig['name'];

/**
 * Static definition of a single environment: which env var supplies its base
 * URL and the full set of variable names it requires to run. The base-URL var
 * is always part of `requiredVars`.
 */
interface EnvironmentDefinition {
  name: EnvironmentName;
  baseUrlVar: string;
  requiredVars: string[];
}

/**
 * The required-variable contract for each environment.
 *
 * Variable names are configuration, not secret values: the actual credentials
 * and connection strings are read from `process.env` at load time. AWS needs
 * the additional SDK credential/region variables to exercise live services.
 */
const ENVIRONMENT_DEFINITIONS: readonly EnvironmentDefinition[] = [
  {
    name: 'Development',
    baseUrlVar: 'DEV_BASE_URL',
    requiredVars: ['DEV_BASE_URL', 'DEV_AUTH_TOKEN'],
  },
  {
    name: 'Local',
    baseUrlVar: 'LOCAL_BASE_URL',
    requiredVars: ['LOCAL_BASE_URL', 'LOCAL_AUTH_TOKEN'],
  },
  {
    name: 'Staging',
    baseUrlVar: 'STAGING_BASE_URL',
    requiredVars: ['STAGING_BASE_URL', 'STAGING_AUTH_TOKEN'],
  },
  {
    name: 'AWS',
    baseUrlVar: 'AWS_BASE_URL',
    requiredVars: [
      'AWS_BASE_URL',
      'AWS_AUTH_TOKEN',
      'AWS_REGION',
      'AWS_ACCESS_KEY_ID',
      'AWS_SECRET_ACCESS_KEY',
    ],
  },
  {
    name: 'Production',
    baseUrlVar: 'PROD_BASE_URL',
    requiredVars: ['PROD_BASE_URL', 'PROD_AUTH_TOKEN'],
  },
] as const;

/** The result of resolving environment configuration for a run. */
export interface ConfigLoadResult {
  /** Resolved configuration for each active environment. */
  configs: EnvironmentConfig[];
  /**
   * Names of required variables that were absent from `process.env`, in
   * deterministic definition order with duplicates removed. Empty when every
   * required variable is present.
   */
  missing: string[];
}

/** The source of environment variables. Defaults to `process.env`. */
type EnvSource = Record<string, string | undefined>;

/**
 * Resolves environment configuration and validates that every required
 * variable is present before any pipeline stage runs (Requirements 14.1,
 * 14.5).
 */
export interface ConfigLoader {
  /**
   * Resolve the active environment configs and the list of missing required
   * variables. When `missing` is non-empty the caller MUST stop the run
   * before executing any stage (Requirement 14.5).
   */
  load(runOptions: RunOptions): ConfigLoadResult;
}

/**
 * Treat a variable as missing when it is undefined or contains only
 * whitespace. An empty value cannot satisfy a required connection/credential,
 * so it is reported alongside truly absent variables (Requirement 14.5).
 */
function isPresent(value: string | undefined): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

/**
 * Build the resolved {@link EnvironmentConfig} for a single environment,
 * reading any present variable values from the supplied env source. Absent
 * variables are simply omitted from `variableValues`.
 */
function buildConfig(
  definition: EnvironmentDefinition,
  env: EnvSource,
): EnvironmentConfig {
  const variableValues = new Map<string, string>();
  for (const varName of definition.requiredVars) {
    const value = env[varName];
    if (isPresent(value)) {
      variableValues.set(varName, value);
    }
  }

  const baseUrlValue = env[definition.baseUrlVar];

  return {
    name: definition.name,
    baseUrl: isPresent(baseUrlValue) ? baseUrlValue : '',
    // Copy so callers cannot mutate the shared definition array.
    requiredVars: [...definition.requiredVars],
    variableValues,
  };
}

/**
 * Default {@link ConfigLoader} implementation. Reads from a configurable env
 * source (defaulting to `process.env`) so the loader is deterministic and
 * testable without mutating the real process environment.
 */
export class EnvConfigLoader implements ConfigLoader {
  private readonly env: EnvSource;

  constructor(env: EnvSource = process.env) {
    this.env = env;
  }

  load(runOptions: RunOptions = {}): ConfigLoadResult {
    const activeDefinitions = this.resolveActiveDefinitions(runOptions);

    const configs = activeDefinitions.map((definition) =>
      buildConfig(definition, this.env),
    );

    const missing = this.computeMissing(activeDefinitions);

    return { configs, missing };
  }

  /**
   * Select the environment definitions to load. When `runOptions.environments`
   * is provided, restrict to that subset (preserving canonical definition
   * order); otherwise load all five.
   */
  private resolveActiveDefinitions(
    runOptions: RunOptions,
  ): EnvironmentDefinition[] {
    const requested = runOptions.environments;
    if (!requested || requested.length === 0) {
      return [...ENVIRONMENT_DEFINITIONS];
    }
    const requestedSet = new Set<EnvironmentName>(requested);
    return ENVIRONMENT_DEFINITIONS.filter((definition) =>
      requestedSet.has(definition.name),
    );
  }

  /**
   * Compute the deduplicated, deterministically ordered list of required
   * variable names that are absent from the env source across all active
   * environments. Returns names only, never values (Requirement 14.5).
   */
  private computeMissing(definitions: EnvironmentDefinition[]): string[] {
    const missing: string[] = [];
    const seen = new Set<string>();
    for (const definition of definitions) {
      for (const varName of definition.requiredVars) {
        if (seen.has(varName)) {
          continue;
        }
        seen.add(varName);
        if (!isPresent(this.env[varName])) {
          missing.push(varName);
        }
      }
    }
    return missing;
  }
}

/**
 * Convenience factory returning a {@link ConfigLoader} bound to `process.env`.
 */
export function createConfigLoader(env: EnvSource = process.env): ConfigLoader {
  return new EnvConfigLoader(env);
}

/** The canonical environment names, in definition order. */
export const ENVIRONMENT_NAMES: readonly EnvironmentName[] =
  ENVIRONMENT_DEFINITIONS.map((definition) => definition.name);
