// ============================================
// Cognito User Pool Setup Utility
// ============================================
// Run this script once to configure the Cognito User Pool with:
//   1. SMS MFA via Amazon SNS
//   2. Custom attributes (role, tenant_id, staff_id, etc.)
//   3. MFA settings (optional for pool, required per-user for owners)
//
// Usage:
//   npx ts-node src/utils/cognitoSetup.ts
//
// Prerequisites:
//   - AWS credentials configured (env vars or ~/.aws/credentials)
//   - SNS permissions for sending SMS (IAM role)
//   - COGNITO_USER_POOL_ID env var set
// ============================================

import {
    CognitoIdentityProviderClient,
    UpdateUserPoolCommand,
    SetUserPoolMfaConfigCommand,
    DescribeUserPoolCommand,
    AddCustomAttributesCommand,
} from '@aws-sdk/client-cognito-identity-provider';
import dotenv from 'dotenv';

dotenv.config();

const region = process.env.AWS_REGION || 'ap-south-1';
const userPoolId = process.env.COGNITO_USER_POOL_ID;

if (!userPoolId) {
    console.error('ERROR: COGNITO_USER_POOL_ID environment variable is required');
    process.exit(1);
}

const client = new CognitoIdentityProviderClient({ region });

// ============================================
// 1. Add Custom Attributes
// ============================================
async function addCustomAttributes() {
    console.log('\n📋 Step 1: Adding custom attributes...');

    const attributes = [
        { Name: 'role', AttributeDataType: 'String' as const, Mutable: true, StringAttributeConstraints: { MinLength: '1', MaxLength: '50' } },
        { Name: 'tenant_id', AttributeDataType: 'String' as const, Mutable: true, StringAttributeConstraints: { MinLength: '1', MaxLength: '128' } },
        { Name: 'staff_id', AttributeDataType: 'String' as const, Mutable: true, StringAttributeConstraints: { MinLength: '0', MaxLength: '128' } },
        { Name: 'business_type', AttributeDataType: 'String' as const, Mutable: true, StringAttributeConstraints: { MinLength: '1', MaxLength: '50' } },
        { Name: 'permissions', AttributeDataType: 'String' as const, Mutable: true, StringAttributeConstraints: { MinLength: '0', MaxLength: '2048' } },
        { Name: 'license_status', AttributeDataType: 'String' as const, Mutable: true, StringAttributeConstraints: { MinLength: '0', MaxLength: '50' } },
        { Name: 'firebase_uid', AttributeDataType: 'String' as const, Mutable: true, StringAttributeConstraints: { MinLength: '0', MaxLength: '128' } },
        { Name: 'login_portal', AttributeDataType: 'String' as const, Mutable: true, StringAttributeConstraints: { MinLength: '0', MaxLength: '20' } },
    ];

    try {
        await client.send(new AddCustomAttributesCommand({
            UserPoolId: userPoolId,
            CustomAttributes: attributes,
        }));
        console.log('  ✅ Custom attributes added successfully');
    } catch (error: any) {
        if (error.message?.includes('already exists')) {
            console.log('  ℹ️  Custom attributes already exist (skipping)');
        } else {
            console.error('  ❌ Failed to add custom attributes:', error.message);
        }
    }
}

// ============================================
// 2. Configure MFA (SMS + TOTP)
// ============================================
async function configureMfa() {
    console.log('\n🔐 Step 2: Configuring MFA settings...');

    try {
        // Set MFA to OPTIONAL at pool level (enforced per-user for owners)
        await client.send(new SetUserPoolMfaConfigCommand({
            UserPoolId: userPoolId,
            MfaConfiguration: 'OPTIONAL',
            SmsMfaConfiguration: {
                SmsAuthenticationMessage: 'Your DukanX verification code is {####}',
                SmsConfiguration: {
                    SnsCallerArn: process.env.COGNITO_SNS_ROLE_ARN || '',
                    ExternalId: process.env.COGNITO_SNS_EXTERNAL_ID || 'dukanx-mfa',
                    SnsRegion: region,
                },
            },
            SoftwareTokenMfaConfiguration: {
                Enabled: true,
            },
        }));
        console.log('  ✅ MFA configured: OPTIONAL (SMS + TOTP enabled)');
        console.log('  ℹ️  SMS MFA will be enforced per-user for owner accounts');
    } catch (error: any) {
        console.error('  ❌ Failed to configure MFA:', error.message);
        console.log('  💡 Tip: Ensure COGNITO_SNS_ROLE_ARN is set and has SNS:Publish permission');
    }
}

// ============================================
// 3. Update User Pool Settings
// ============================================
async function updatePoolSettings() {
    console.log('\n⚙️  Step 3: Updating user pool settings...');

    try {
        // First describe current pool to preserve existing settings
        const describeResult = await client.send(new DescribeUserPoolCommand({
            UserPoolId: userPoolId,
        }));

        const pool = describeResult.UserPool;

        await client.send(new UpdateUserPoolCommand({
            UserPoolId: userPoolId,
            // Preserve existing auto-verified attributes
            AutoVerifiedAttributes: pool?.AutoVerifiedAttributes || ['email'],
            // SMS verification message
            SmsVerificationMessage: 'Your DukanX verification code is {####}',
            // SMS authentication message
            SmsAuthenticationMessage: 'Your DukanX login code is {####}',
            // Account recovery
            AccountRecoverySetting: {
                RecoveryMechanisms: [
                    { Name: 'verified_email', Priority: 1 },
                    { Name: 'verified_phone_number', Priority: 2 },
                ],
            },
            // Preserve existing policies
            Policies: pool?.Policies,
        }));

        console.log('  ✅ User pool settings updated');
    } catch (error: any) {
        console.error('  ❌ Failed to update pool settings:', error.message);
    }
}

// ============================================
// 4. Verify Configuration
// ============================================
async function verifySetup() {
    console.log('\n🔍 Step 4: Verifying configuration...');

    try {
        const describeResult = await client.send(new DescribeUserPoolCommand({
            UserPoolId: userPoolId,
        }));

        const pool = describeResult.UserPool;

        console.log(`  Pool Name:    ${pool?.Name}`);
        console.log(`  Pool ID:      ${pool?.Id}`);
        console.log(`  MFA Config:   ${pool?.MfaConfiguration}`);
        console.log(`  SMS Config:   ${pool?.SmsConfiguration ? 'Configured' : 'Not configured'}`);
        console.log(`  Auto Verify:  ${pool?.AutoVerifiedAttributes?.join(', ')}`);

        // Check custom attributes
        const customAttrs = pool?.SchemaAttributes?.filter(a => a.Name?.startsWith('custom:')) || [];
        console.log(`  Custom Attrs: ${customAttrs.map(a => a.Name).join(', ')}`);

        console.log('\n✅ Cognito User Pool setup verification complete!');
    } catch (error: any) {
        console.error('  ❌ Verification failed:', error.message);
    }
}

// ============================================
// Main
// ============================================
async function main() {
    console.log('═══════════════════════════════════════════');
    console.log('  DukanX — Cognito User Pool Setup');
    console.log(`  Region: ${region}`);
    console.log(`  Pool:   ${userPoolId}`);
    console.log('═══════════════════════════════════════════');

    await addCustomAttributes();
    await configureMfa();
    await updatePoolSettings();
    await verifySetup();

    console.log('\n🎉 Setup complete!\n');
    console.log('Next steps:');
    console.log('  1. Create an IAM role for Cognito → SNS (if not already done)');
    console.log('  2. Set COGNITO_SNS_ROLE_ARN in your .env file');
    console.log('  3. For each Owner user, call POST /api/cognito-auth/owner/setup-sms-mfa');
    console.log('  4. Test the dual-portal login flow');
}

main().catch(console.error);
