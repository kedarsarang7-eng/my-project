import { APIGatewayProxyEventV2, Context } from 'aws-lambda';
import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole } from '../types/tenant.types';
import * as cognitoAuth from '../middleware/cognito-auth';

// Mock the verifyAuth function to simulate a logged-in user (Tenant A)
jest.mock('../middleware/cognito-auth', () => ({
    verifyAuth: jest.fn().mockResolvedValue({
        sub: 'user-a-123',
        tenantId: 'tenant-a-uuid',
        role: 'admin',
        email: 'admin@tenanta.com',
        businessType: 'other'
    })
}));

describe('Cross-Tenant Data Leakage & Isolation Tests', () => {

    // Create a dummy handler protected by our wrapper
    const dummyLogic = jest.fn().mockResolvedValue({
        statusCode: 200,
        body: JSON.stringify({ data: 'Sensitive Tenant A Data' })
    });

    const handler = authorizedHandler([UserRole.ADMIN], dummyLogic);

    beforeEach(() => {
        dummyLogic.mockClear();
    });

    it('should allow request when tenant_id in body matches JWT tenant_id', async () => {
        const event = {
            requestContext: { http: { method: 'POST' } },
            rawPath: '/api/data',
            headers: {
                'x-tenant-id': 'tenant-a-uuid',
                'authorization': 'Bearer valid-jwt'
            },
            body: JSON.stringify({ tenant_id: 'tenant-a-uuid', name: 'Product' })
        } as unknown as APIGatewayProxyEventV2;

        const res = await handler(event, {} as Context) as any;
        expect(res.statusCode).toBe(200);
        expect(dummyLogic).toHaveBeenCalled();
    });

    it('SECURITY TEST: should BLOCKED cross-tenant attack via Request Body', async () => {
        const event = {
            requestContext: { http: { method: 'POST' } },
            rawPath: '/api/data',
            headers: {
                'x-tenant-id': 'tenant-a-uuid',
                'authorization': 'Bearer valid-jwt'
            },
            body: JSON.stringify({ tenant_id: 'tenant-HACKER-uuid', name: 'Product' })
        } as unknown as APIGatewayProxyEventV2;

        const res = await handler(event, {} as Context) as unknown as any;
        expect(res.statusCode).toBe(401); // AuthError uses 401
        const body = JSON.parse(res.body as string);
        expect(body.message).toContain('Cross-tenant access denied');
        expect(dummyLogic).not.toHaveBeenCalled();
    });

    it('SECURITY TEST: should BLOCK cross-tenant attack via HTTP Headers', async () => {
        const event = {
            requestContext: { http: { method: 'GET' } },
            rawPath: '/api/data',
            headers: {
                'x-tenant-id': 'tenant-B-uuid', // Attemping to access Tenant B
                'authorization': 'Bearer valid-jwt'
            }
        } as unknown as APIGatewayProxyEventV2;

        const res = await handler(event, {} as Context) as unknown as any;
        expect(res.statusCode).toBe(401);
        const body = JSON.parse(res.body as string);
        expect(body.message).toContain('Cross-tenant access denied');
        expect(dummyLogic).not.toHaveBeenCalled();
    });

});
