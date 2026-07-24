/**
 * IAM Validation Tests — CloudFormation Template Policy Checks
 *
 * Verifies:
 * - Template with Scan in app role → error finding
 * - Template without Scan in app role → no error
 * - Template with separate migration role → no warning
 * - Template without migration role → warning
 * - Template with dynamodb:* wildcard → error
 * - Template with DynamoDB actions on client resource → error
 *
 * Requirements: 6.5–6.6, 6.19, 8.3–8.10, 13.1, 13.6
 */

import {
  validateIamPolicies,
  type CloudFormationTemplate,
} from '../iam-validation';

// ─── Fixtures ───────────────────────────────────────────────────────────────

function makeTemplate(overrides: Partial<CloudFormationTemplate> = {}): CloudFormationTemplate {
  return {
    provider: {
      iam: {
        role: {
          statements: [],
        },
      },
    },
    Resources: {},
    ...overrides,
  };
}

// ─── Tests ──────────────────────────────────────────────────────────────────

describe('validateIamPolicies', () => {
  it('reports error when Scan is in provider application role statements', () => {
    const template = makeTemplate({
      provider: {
        iam: {
          role: {
            statements: [
              {
                Effect: 'Allow',
                Action: ['dynamodb:PutItem', 'dynamodb:Scan'],
                Resource: 'arn:aws:dynamodb:*:*:table/MobileShop*',
              },
            ],
          },
        },
      },
    });

    const result = validateIamPolicies(template);

    expect(result.valid).toBe(false);
    expect(result.findings).toContainEqual(
      expect.objectContaining({
        rule: 'NO_SCAN_IN_APPLICATION_ROLE',
        severity: 'error',
      }),
    );
  });

  it('passes when provider application role has no Scan', () => {
    const template = makeTemplate({
      provider: {
        iam: {
          role: {
            statements: [
              {
                Effect: 'Allow',
                Action: ['dynamodb:PutItem', 'dynamodb:Query', 'dynamodb:GetItem'],
                Resource: 'arn:aws:dynamodb:*:*:table/MobileShop*',
              },
            ],
          },
        },
      },
    });

    const result = validateIamPolicies(template);

    const scanFindings = result.findings.filter(f => f.rule === 'NO_SCAN_IN_APPLICATION_ROLE');
    expect(scanFindings).toHaveLength(0);
  });

  it('does not warn about migration role when a dedicated migration role exists', () => {
    const template = makeTemplate({
      Resources: {
        MobileShopApplicationRole: {
          Type: 'AWS::IAM::Role',
          Properties: {
            RoleName: 'mobile-shop-app-role',
            Policies: [{
              PolicyName: 'app-policy',
              PolicyDocument: {
                Statement: [{
                  Effect: 'Allow' as const,
                  Action: ['dynamodb:PutItem', 'dynamodb:Query'],
                  Resource: 'arn:aws:dynamodb:*:*:table/MobileShop*',
                }],
              },
            }],
          },
        },
        MobileShopMigrationRole: {
          Type: 'AWS::IAM::Role',
          Properties: {
            RoleName: 'mobile-shop-migration-role',
            Policies: [{
              PolicyName: 'migration-policy',
              PolicyDocument: {
                Statement: [{
                  Effect: 'Allow' as const,
                  Action: ['dynamodb:Scan', 'dynamodb:PutItem', 'dynamodb:Query'],
                  Resource: 'arn:aws:dynamodb:*:*:table/MobileShop*',
                }],
              },
            }],
          },
        },
      },
    });

    const result = validateIamPolicies(template);

    const migrationWarnings = result.findings.filter(f => f.rule === 'MIGRATION_ROLE_SEPARATE');
    expect(migrationWarnings).toHaveLength(0);
  });

  it('warns when no dedicated migration role is found', () => {
    const template = makeTemplate({
      Resources: {
        MobileShopApplicationRole: {
          Type: 'AWS::IAM::Role',
          Properties: {
            RoleName: 'mobile-shop-app-role',
            Policies: [{
              PolicyName: 'app-policy',
              PolicyDocument: {
                Statement: [{
                  Effect: 'Allow' as const,
                  Action: ['dynamodb:PutItem', 'dynamodb:Query'],
                  Resource: 'arn:aws:dynamodb:*:*:table/MobileShop*',
                }],
              },
            }],
          },
        },
      },
    });

    const result = validateIamPolicies(template);

    expect(result.findings).toContainEqual(
      expect.objectContaining({
        rule: 'MIGRATION_ROLE_SEPARATE',
        severity: 'warning',
      }),
    );
  });

  it('reports error when dynamodb:* wildcard is used in provider statements', () => {
    const template = makeTemplate({
      provider: {
        iam: {
          role: {
            statements: [
              {
                Effect: 'Allow',
                Action: 'dynamodb:*',
                Resource: 'arn:aws:dynamodb:*:*:table/MobileShop*',
              },
            ],
          },
        },
      },
    });

    const result = validateIamPolicies(template);

    expect(result.valid).toBe(false);
    expect(result.findings).toContainEqual(
      expect.objectContaining({
        rule: 'NO_DYNAMODB_WILDCARD',
        severity: 'error',
      }),
    );
  });

  it('reports error when dynamodb:* wildcard is used in a role resource', () => {
    const template = makeTemplate({
      Resources: {
        SomeRole: {
          Type: 'AWS::IAM::Role',
          Properties: {
            RoleName: 'some-role',
            Policies: [{
              PolicyName: 'bad-policy',
              PolicyDocument: {
                Statement: [{
                  Effect: 'Allow' as const,
                  Action: 'dynamodb:*',
                  Resource: 'arn:aws:dynamodb:*:*:table/MobileShop*',
                }],
              },
            }],
          },
        },
      },
    });

    const result = validateIamPolicies(template);

    expect(result.valid).toBe(false);
    expect(result.findings).toContainEqual(
      expect.objectContaining({
        rule: 'NO_DYNAMODB_WILDCARD',
        severity: 'error',
      }),
    );
  });

  it('reports error when DynamoDB actions are on a client-facing resource', () => {
    const template = makeTemplate({
      Resources: {
        UserPoolClient: {
          Type: 'AWS::Cognito::UserPoolClient',
          Properties: {
            ClientName: 'mobile-app',
            InlinePolicy: {
              Statement: [{
                Effect: 'Allow',
                Action: 'dynamodb:GetItem',
                Resource: '*',
              }],
            },
          },
        },
      },
    });

    const result = validateIamPolicies(template);

    expect(result.findings).toContainEqual(
      expect.objectContaining({
        rule: 'NO_DYNAMODB_ON_CLIENT_RESOURCES',
        severity: 'error',
      }),
    );
  });

  it('passes with clean template (no errors)', () => {
    const template = makeTemplate({
      provider: {
        iam: {
          role: {
            statements: [
              {
                Effect: 'Allow',
                Action: ['dynamodb:PutItem', 'dynamodb:GetItem', 'dynamodb:Query'],
                Resource: 'arn:aws:dynamodb:*:*:table/MobileShop*',
              },
            ],
          },
        },
      },
      Resources: {
        MobileShopMigrationRole: {
          Type: 'AWS::IAM::Role',
          Properties: {
            RoleName: 'migration-role',
            Policies: [{
              PolicyName: 'migration',
              PolicyDocument: {
                Statement: [{
                  Effect: 'Allow' as const,
                  Action: ['dynamodb:Scan', 'dynamodb:PutItem'],
                  Resource: 'arn:aws:dynamodb:*:*:table/MobileShop*',
                }],
              },
            }],
          },
        },
      },
    });

    const result = validateIamPolicies(template);

    expect(result.valid).toBe(true);
    const errors = result.findings.filter(f => f.severity === 'error');
    expect(errors).toHaveLength(0);
  });
});
