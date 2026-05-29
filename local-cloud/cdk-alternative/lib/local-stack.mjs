// =============================================================================
// CDK Alternative — LocalStack Deployment (Optional)
// =============================================================================
// Use this if you prefer CDK over Terraform:
//   npx cdklocal bootstrap
//   npx cdklocal deploy
//
// Requires: npm install -g aws-cdk-local aws-cdk
// =============================================================================

import * as cdk from 'aws-cdk-lib';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as sqs from 'aws-cdk-lib/aws-sqs';
import * as sns from 'aws-cdk-lib/aws-sns';
import * as events from 'aws-cdk-lib/aws-events';
import * as targets from 'aws-cdk-lib/aws-events-targets';
import * as cognito from 'aws-cdk-lib/aws-cognito';
import * as secretsmanager from 'aws-cdk-lib/aws-secretsmanager';
import * as ssm from 'aws-cdk-lib/aws-ssm';
import { Construct } from 'constructs';

class DukanLocalStack extends cdk.Stack {
  constructor(scope, id, props) {
    super(scope, id, props);

    const stackName = 'dukan-saas-dev';

    // ─── DynamoDB ──────────────────────────────────────────────────

    const tenantsTable = new dynamodb.Table(this, 'Tenants', {
      tableName: `${stackName}-tenants`,
      partitionKey: { name: 'tenantId', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      stream: dynamodb.StreamViewType.NEW_AND_OLD_IMAGES,
      pointInTimeRecovery: true,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });
    tenantsTable.addGlobalSecondaryIndex({
      indexName: 'GSI_Slug',
      partitionKey: { name: 'slug', type: dynamodb.AttributeType.STRING },
    });

    const usersTable = new dynamodb.Table(this, 'Users', {
      tableName: `${stackName}-users`,
      partitionKey: { name: 'tenantId#userId', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      stream: dynamodb.StreamViewType.NEW_AND_OLD_IMAGES,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });
    usersTable.addGlobalSecondaryIndex({
      indexName: 'GSI_Email',
      partitionKey: { name: 'email', type: dynamodb.AttributeType.STRING },
    });

    const billingTable = new dynamodb.Table(this, 'Billing', {
      tableName: `${stackName}-billing`,
      partitionKey: { name: 'tenantId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'SK', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    // ─── S3 ──────────────────────────────────────────────────────

    new s3.Bucket(this, 'Uploads', {
      bucketName: `${stackName}-uploads`,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
    });

    // ─── SQS ─────────────────────────────────────────────────────

    const emailDLQ = new sqs.Queue(this, 'EmailDLQ', {
      queueName: `${stackName}-email-notifications-dlq`,
      retentionPeriod: cdk.Duration.days(14),
    });

    new sqs.Queue(this, 'EmailQueue', {
      queueName: `${stackName}-email-notifications`,
      visibilityTimeout: cdk.Duration.seconds(60),
      deadLetterQueue: { queue: emailDLQ, maxReceiveCount: 3 },
    });

    // ─── SNS ─────────────────────────────────────────────────────

    new sns.Topic(this, 'TenantEvents', { topicName: `${stackName}-tenant-events` });
    new sns.Topic(this, 'BillingEvents', { topicName: `${stackName}-billing-events` });

    // ─── EventBridge ─────────────────────────────────────────────

    const bus = new events.EventBus(this, 'MainBus', { eventBusName: `${stackName}-main-bus` });

    new events.Rule(this, 'SubscriptionRule', {
      eventBus: bus,
      eventPattern: {
        source: ['dukan.billing'],
        detailType: ['SubscriptionCreated', 'SubscriptionCancelled'],
      },
    });

    // ─── Cognito ─────────────────────────────────────────────────

    const userPool = new cognito.UserPool(this, 'UserPool', {
      userPoolName: `${stackName}-user-pool`,
      selfSignUpEnabled: true,
      signInAliases: { email: true },
      autoVerify: { email: true },
      passwordPolicy: {
        minLength: 8,
        requireUppercase: true,
        requireLowercase: true,
        requireDigits: true,
        requireSymbols: true,
      },
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    userPool.addClient('AppClient', {
      userPoolClientName: `${stackName}-app-client`,
      authFlows: { userPassword: true },
    });

    // ─── Secrets / SSM ───────────────────────────────────────────

    new secretsmanager.Secret(this, 'JwtSecret', {
      secretName: `${stackName}/jwt-signing-key`,
      generateSecretString: { secretStringTemplate: '{"key":"local-dev"}', generateStringKey: 'salt' },
    });

    new ssm.StringParameter(this, 'EnvParam', {
      parameterName: `/${stackName}/environment`,
      stringValue: 'dev',
    });

    // ─── Outputs ─────────────────────────────────────────────────

    new cdk.CfnOutput(this, 'UserPoolId', { value: userPool.userPoolId });
    new cdk.CfnOutput(this, 'TenantsTableName', { value: tenantsTable.tableName });
  }
}

const app = new cdk.App();
new DukanLocalStack(app, 'DukanLocalStack', {
  env: { region: 'ap-south-1' },
});
