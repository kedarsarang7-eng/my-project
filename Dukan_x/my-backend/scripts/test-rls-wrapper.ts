import * as dotenv from 'dotenv';
dotenv.config();

import { authorizedHandler } from '../src/middleware/handler-wrapper';
import { UserRole } from '../src/types/tenant.types';
import { getPool } from '../src/config/db.config';
import { APIGatewayProxyEventV2, Context } from 'aws-lambda';

// Mock dependencies
const mockEvent = {
    headers: {
        authorization: 'Bearer mock-token'
    },
    requestContext: {
        http: { method: 'GET', path: '/test' }
    }
} as any as APIGatewayProxyEventV2;

const mockContext = {} as Context;

// Mock verifyAuth to avoid real Cognito calls
import * as auth from '../src/middleware/cognito-auth';
// @ts-ignore
auth.verifyAuth = async () => ({
    tenantId: '11111111-1111-1111-1111-111111111111',
    userId: 'user-1',
    email: 'test@example.com',
    role: UserRole.OWNER,
    businessType: 'general'
});

async function main() {
    console.log('Starting RLS Wrapper Verification...');

    const handler = authorizedHandler([], async (event, context, auth) => {
        console.log('Handler executed. Tenant ID:', auth.tenantId);

        const db = getPool();
        const res = await db.query("SELECT current_setting('app.current_tenant', true) as tenant");

        console.log('DB Query Result:', res.rows[0]);
        return { statusCode: 200, body: JSON.stringify(res.rows[0]) };
    });

    const result = await handler(mockEvent, mockContext);
    console.log('Handler Result:', result);

    const body = (result as any).body;
    if (JSON.parse(body as string).tenant === '11111111-1111-1111-1111-111111111111') {
        console.log('SUCCESS: Tenant context was correctly set!');
    } else {
        console.error('FAILURE: Tenant context mismatch or missing.');
    }
}

main().catch(console.error);
