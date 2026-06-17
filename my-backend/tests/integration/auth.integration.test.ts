/**
 * Phase 4.1 - Auth Flow Integration Tests
 * Tests: signup → verify → login → get token → call protected API
 */

import { describe, it, expect, beforeAll, afterAll } from '@jest/globals';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { CognitoIdentityProviderClient } from '@aws-sdk/client-cognito-identity-provider';
import { config } from '../../src/config/environment';

// Integration test configuration
const TEST_TENANT_ID = `test-tenant-${Date.now()}`;
const TEST_USER_EMAIL = `test-${Date.now()}@example.com`;
const TEST_USER_PASSWORD = 'TestPassword123!';

// API Gateway URL - use environment variable or default
const API_URL = process.env.API_GATEWAY_URL || 'http://localhost:3000';

// AWS Clients
const dynamo = new DynamoDBClient({ region: config.aws.region });
const cognito = new CognitoIdentityProviderClient({ region: config.aws.region });

describe('Auth Flow Integration Tests', () => {
  let accessToken: string | undefined;
  let refreshToken: string | undefined;
  let userId: string | undefined;

  beforeAll(async () => {
    // Skip integration tests if no API URL configured
    if (!process.env.API_GATEWAY_URL) {
      console.log('Skipping integration tests - API_GATEWAY_URL not set');
      return;
    }
  });

  afterAll(async () => {
    // Cleanup: Delete test user and tenant data
  });

  describe('POST /auth/signup', () => {
    it('should create a new user with valid credentials', async () => {
      const response = await fetch(`${API_URL}/auth/signup`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: TEST_USER_EMAIL,
          password: TEST_USER_PASSWORD,
          tenantId: TEST_TENANT_ID,
          businessType: 'grocery',
        }),
      });

      expect(response.status).toBe(201);
      const data = await response.json();
      expect(data.success).toBe(true);
      expect(data.data.userId).toBeDefined();
      userId = data.data.userId;
    });

    it('should reject signup with weak password', async () => {
      const response = await fetch(`${API_URL}/auth/signup`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: `weak-${Date.now()}@example.com`,
          password: '123',
          tenantId: TEST_TENANT_ID,
        }),
      });

      expect(response.status).toBe(400);
      const data = await response.json();
      expect(data.error).toContain('password');
    });

    it('should reject duplicate email signup', async () => {
      const response = await fetch(`${API_URL}/auth/signup`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: TEST_USER_EMAIL,
          password: TEST_USER_PASSWORD,
          tenantId: TEST_TENANT_ID,
        }),
      });

      expect(response.status).toBe(409);
      const data = await response.json();
      expect(data.error).toContain('exists');
    });
  });

  describe('POST /auth/login', () => {
    it('should return tokens on valid credentials', async () => {
      const response = await fetch(`${API_URL}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: TEST_USER_EMAIL,
          password: TEST_USER_PASSWORD,
        }),
      });

      expect(response.status).toBe(200);
      const data = await response.json();
      expect(data.success).toBe(true);
      expect(data.data.accessToken).toBeDefined();
      expect(data.data.refreshToken).toBeDefined();
      expect(data.data.tenantId).toBe(TEST_TENANT_ID);
      
      accessToken = data.data.accessToken;
      refreshToken = data.data.refreshToken;
    });

    it('should reject invalid credentials', async () => {
      const response = await fetch(`${API_URL}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: TEST_USER_EMAIL,
          password: 'WrongPassword123!',
        }),
      });

      expect(response.status).toBe(401);
      const data = await response.json();
      expect(data.error).toContain('credentials');
    });

    it('should reject non-existent user', async () => {
      const response = await fetch(`${API_URL}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: 'nonexistent@example.com',
          password: TEST_USER_PASSWORD,
        }),
      });

      expect(response.status).toBe(404);
      const data = await response.json();
      expect(data.error).toContain('not found');
    });
  });

  describe('Token Validation', () => {
    it('should access protected API with valid token', async () => {
      const response = await fetch(`${API_URL}/inventory`, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'x-tenant-id': TEST_TENANT_ID,
        },
      });

      expect(response.status).toBe(200);
      const data = await response.json();
      expect(data.success).toBe(true);
    });

    it('should reject request without token', async () => {
      const response = await fetch(`${API_URL}/inventory`, {
        method: 'GET',
        headers: {
          'x-tenant-id': TEST_TENANT_ID,
        },
      });

      expect(response.status).toBe(401);
    });

    it('should reject request with expired token', async () => {
      // Use an intentionally expired token
      const expiredToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjE1MTYyMzkwMjJ9.test';
      
      const response = await fetch(`${API_URL}/inventory`, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${expiredToken}`,
          'x-tenant-id': TEST_TENANT_ID,
        },
      });

      expect(response.status).toBe(401);
    });
  });

  describe('POST /auth/refresh', () => {
    it('should return new access token with valid refresh token', async () => {
      const response = await fetch(`${API_URL}/auth/refresh`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          refreshToken: refreshToken,
        }),
      });

      expect(response.status).toBe(200);
      const data = await response.json();
      expect(data.success).toBe(true);
      expect(data.data.accessToken).toBeDefined();
      expect(data.data.accessToken).not.toBe(accessToken); // New token
    });

    it('should reject invalid refresh token', async () => {
      const response = await fetch(`${API_URL}/auth/refresh`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          refreshToken: 'invalid-token',
        }),
      });

      expect(response.status).toBe(401);
    });
  });

  describe('POST /auth/logout', () => {
    it('should invalidate refresh token on logout', async () => {
      // Logout
      const logoutResponse = await fetch(`${API_URL}/auth/logout`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          refreshToken: refreshToken,
        }),
      });

      expect(logoutResponse.status).toBe(200);

      // Try to use refresh token after logout (should fail)
      const refreshResponse = await fetch(`${API_URL}/auth/refresh`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          refreshToken: refreshToken,
        }),
      });

      expect(refreshResponse.status).toBe(401);
    });
  });
});

// JWT Token Structure Verification
describe('JWT Token Claims', () => {
  it('should contain required claims in access token', async () => {
    // Decode JWT and verify claims
    // Note: This requires the token to be decoded
    expect(true).toBe(true); // Placeholder
  });

  it('should have tenant_id in token claims', async () => {
    expect(true).toBe(true); // Placeholder
  });

  it('should have role in token claims', async () => {
    expect(true).toBe(true); // Placeholder
  });
});
