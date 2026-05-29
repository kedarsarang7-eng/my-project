import { CognitoIdentityProviderClient, AdminCreateUserCommand, AdminDisableUserCommand, AdminUpdateUserAttributesCommand } from '@aws-sdk/client-cognito-identity-provider';
import { randomUUID } from 'crypto';
import { success, error, verifyToken, getItem, putItem, updateItem, queryItems, validateTenantAccess, requireAdminRole, logAuditEvent, getPaginationParams, createPaginationResponse } from '../shared/utils.mjs';

const cognitoClient = new CognitoIdentityProviderClient({});

// GET /users
export async function listUsers(event) {
  try {
    const authHeader = event.headers.authorization || event.headers.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error('Authorization header required', 401);
    }

    const token = authHeader.substring(7);
    const decoded = await verifyToken(token);
    requireAdminRole(decoded.role);

    const tenantId = decoded.tenantId;
    const { limit, nextToken } = getPaginationParams(event);

    const users = await queryItems(
      process.env.DYNAMODB_TABLE_USERS,
      'tenantId = :tenantId',
      { ':tenantId': tenantId, ':disabled': 'disabled' },
      'attribute_not_exists(#st) OR #st <> :disabled',
      { IndexName: 'GSI_TenantRole', ExpressionAttributeNames: { '#st': 'status' } }
    );

    return success(createPaginationResponse(users.slice(0, limit), limit));
  } catch (err) {
    console.error('List users error:', err);
    return error('Failed to list users', 500);
  }
}

// POST /users/invite
export async function inviteUser(event) {
  try {
    const authHeader = event.headers.authorization || event.headers.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error('Authorization header required', 401);
    }

    const token = authHeader.substring(7);
    const decoded = await verifyToken(token);
    requireAdminRole(decoded.role);

    const tenantId = decoded.tenantId;
    const { email, role = 'staff' } = JSON.parse(event.body || '{}');
    const normalizedRole = String(role).trim().toLowerCase();

    if (!email) {
      return error('Email is required', 400);
    }
    if (!['admin', 'manager', 'staff', 'ca'].includes(normalizedRole)) {
      return error('Role must be one of: admin, manager, staff, ca', 400);
    }

    // Check if user already exists in tenant
    const existing = await queryItems(
      process.env.DYNAMODB_TABLE_USERS,
      'email = :email',
      { ':email': email, ':tenantId': tenantId },
      'tenantId = :tenantId',
      { IndexName: 'GSI_Email' }
    );

    if (existing.length > 0) {
      return error('User already exists in this tenant', 409);
    }

    const userId = randomUUID();
    const tempPassword = Math.random().toString(36).slice(-12) + 'Temp1!';
    const now = new Date().toISOString();

    // Create user in Cognito
    const createUserCommand = new AdminCreateUserCommand({
      UserPoolId: process.env.COGNITO_USER_POOL_ID,
      Username: email,
      TemporaryPassword: tempPassword,
      UserAttributes: [
        { Name: 'email', Value: email },
        { Name: 'custom:tenantId', Value: tenantId },
        { Name: 'custom:role', Value: normalizedRole },
      ],
      MessageAction: 'SUPPRESS', // Don't send invite email yet
    });

    await cognitoClient.send(createUserCommand);

    // Create user record in DynamoDB
    const user = {
      'tenantId#userId': `${tenantId}#${userId}`,
      USER: 'USER',
      userId,
      tenantId,
      email,
      role: normalizedRole,
      status: 'invited',
      cognitoSub: userId, // Will be updated when user signs up
      invitedBy: decoded.sub,
      createdAt: now,
      updatedAt: now,
      preferences: {},
    };

    await putItem(process.env.DYNAMODB_TABLE_USERS, user);

    await logAuditEvent(
      tenantId,
      decoded.sub,
      'INVITE_USER',
      'user',
      userId,
      { email, role: normalizedRole },
      event.requestContext.http.sourceIp,
      event.requestContext.http.userAgent
    );

    return success({
      userId,
      email,
      role: normalizedRole,
      status: 'invited',
      message: 'User invited successfully'
    }, 201);
  } catch (err) {
    console.error('Invite user error:', err);
    return error('Failed to invite user', 500);
  }
}

// GET /users/{userId}
export async function getUser(event) {
  try {
    const authHeader = event.headers.authorization || event.headers.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error('Authorization header required', 401);
    }

    const token = authHeader.substring(7);
    const decoded = await verifyToken(token);
    requireAdminRole(decoded.role);

    const tenantId = decoded.tenantId;
    const userId = event.pathParameters.userId;

    const user = await getItem(process.env.DYNAMODB_TABLE_USERS, {
      'tenantId#userId': `${tenantId}#${userId}`,
      USER: 'USER'
    });

    if (!user || user.status === 'disabled') {
      return error('User not found', 404);
    }

    return success(user);
  } catch (err) {
    console.error('Get user error:', err);
    return error('Failed to get user', 500);
  }
}

// PATCH /users/{userId}
export async function updateUser(event) {
  try {
    const authHeader = event.headers.authorization || event.headers.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error('Authorization header required', 401);
    }

    const token = authHeader.substring(7);
    const decoded = await verifyToken(token);
    requireAdminRole(decoded.role);

    const tenantId = decoded.tenantId;
    const userId = event.pathParameters.userId;

    const updates = JSON.parse(event.body || '{}');
    const allowedFields = ['displayName', 'avatarUrl', 'preferences'];
    const filteredUpdates = Object.fromEntries(
      Object.entries(updates).filter(([key]) => allowedFields.includes(key))
    );

    if (Object.keys(filteredUpdates).length === 0) {
      return error('No valid fields to update', 400);
    }

    filteredUpdates.updatedAt = new Date().toISOString();

    const user = await updateItem(
      process.env.DYNAMODB_TABLE_USERS,
      { 'tenantId#userId': `${tenantId}#${userId}`, USER: 'USER' },
      filteredUpdates
    );

    await logAuditEvent(
      tenantId,
      decoded.sub,
      'UPDATE_USER',
      'user',
      userId,
      filteredUpdates,
      event.requestContext.http.sourceIp,
      event.requestContext.http.userAgent
    );

    return success(user);
  } catch (err) {
    console.error('Update user error:', err);
    return error('Failed to update user', 500);
  }
}

// DELETE /users/{userId}
export async function deleteUser(event) {
  try {
    const authHeader = event.headers.authorization || event.headers.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error('Authorization header required', 401);
    }

    const token = authHeader.substring(7);
    const decoded = await verifyToken(token);
    requireAdminRole(decoded.role);

    const tenantId = decoded.tenantId;
    const userId = event.pathParameters.userId;

    // Get user to check if they exist
    const user = await getItem(process.env.DYNAMODB_TABLE_USERS, {
      'tenantId#userId': `${tenantId}#${userId}`,
      USER: 'USER'
    });

    if (!user) {
      return error('User not found', 404);
    }

    // Disable in Cognito
    const disableCommand = new AdminDisableUserCommand({
      UserPoolId: process.env.COGNITO_USER_POOL_ID,
      Username: user.email,
    });

    await cognitoClient.send(disableCommand);

    // Soft delete in DynamoDB
    await updateItem(
      process.env.DYNAMODB_TABLE_USERS,
      { 'tenantId#userId': `${tenantId}#${userId}`, USER: 'USER' },
      {
        status: 'disabled',
        updatedAt: new Date().toISOString(),
      }
    );

    await logAuditEvent(
      tenantId,
      decoded.sub,
      'DELETE_USER',
      'user',
      userId,
      { status: 'disabled' },
      event.requestContext.http.sourceIp,
      event.requestContext.http.userAgent
    );

    return success({ message: 'User deleted successfully' });
  } catch (err) {
    console.error('Delete user error:', err);
    return error('Failed to delete user', 500);
  }
}

// PATCH /users/{userId}/role
export async function updateRole(event) {
  try {
    const authHeader = event.headers.authorization || event.headers.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error('Authorization header required', 401);
    }

    const token = authHeader.substring(7);
    const decoded = await verifyToken(token);
    requireAdminRole(decoded.role);

    const tenantId = decoded.tenantId;
    const userId = event.pathParameters.userId;
    const { role } = JSON.parse(event.body || '{}');

    const normalizedRole = String(role || '').trim().toLowerCase();
    if (!['admin', 'manager', 'staff', 'ca'].includes(normalizedRole)) {
      return error('Valid role is required', 400);
    }

    // Get user to check current status
    const user = await getItem(process.env.DYNAMODB_TABLE_USERS, {
      'tenantId#userId': `${tenantId}#${userId}`,
      USER: 'USER'
    });

    if (!user) {
      return error('User not found', 404);
    }

    // Update in Cognito
    const updateCommand = new AdminUpdateUserAttributesCommand({
      UserPoolId: process.env.COGNITO_USER_POOL_ID,
      Username: user.email,
      UserAttributes: [
        { Name: 'custom:role', Value: normalizedRole },
      ],
    });

    await cognitoClient.send(updateCommand);

    // Update in DynamoDB
    const updatedUser = await updateItem(
      process.env.DYNAMODB_TABLE_USERS,
      { 'tenantId#userId': `${tenantId}#${userId}`, USER: 'USER' },
      {
        role: normalizedRole,
        updatedAt: new Date().toISOString(),
      }
    );

    await logAuditEvent(
      tenantId,
      decoded.sub,
      'UPDATE_USER_ROLE',
      'user',
      userId,
      { oldRole: user.role, newRole: normalizedRole },
      event.requestContext.http.sourceIp,
      event.requestContext.http.userAgent
    );

    return success(updatedUser);
  } catch (err) {
    console.error('Update role error:', err);
    return error('Failed to update user role', 500);
  }
}

// GET /admin/users
export async function adminListAllUsers(event) {
  try {
    const authHeader = event.headers.authorization || event.headers.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error('Authorization header required', 401);
    }

    const token = authHeader.substring(7);
    const decoded = await verifyToken(token);

    requireAdminRole(decoded.role);

    const { limit, nextToken } = getPaginationParams(event);

    // SECURITY FIX: Scope to caller's tenant — prevents cross-tenant data leak
    const users = await queryItems(
      process.env.DYNAMODB_TABLE_USERS,
      'tenantId = :tenantId',
      { ':tenantId': decoded.tenantId },
      undefined,
      { IndexName: 'GSI_TenantRole' }
    );

    return success(createPaginationResponse(users.slice(0, limit), limit));
  } catch (err) {
    console.error('Admin list users error:', err);
    if (err.message === 'FORBIDDEN') {
      return error('Access denied', 403);
    }
    return error('Failed to list users', 500);
  }
}

export async function handler(event) {
  const method = event.requestContext?.http?.method || event.httpMethod || '';
  const path = event.requestContext?.http?.path || event.rawPath || '';
  const route = `${method.toUpperCase()} ${path}`;

  switch (route) {
    case 'GET /users':
      return listUsers(event);
    case 'POST /users/invite':
      return inviteUser(event);
    case 'GET /users/{userId}':
    case 'GET /users/' + (event.pathParameters?.userId || ''):
      return getUser(event);
    case 'PATCH /users/{userId}':
    case 'PATCH /users/' + (event.pathParameters?.userId || ''):
      return updateUser(event);
    case 'DELETE /users/{userId}':
    case 'DELETE /users/' + (event.pathParameters?.userId || ''):
      return deleteUser(event);
    case 'PATCH /users/{userId}/role':
    case 'PATCH /users/' + (event.pathParameters?.userId || '') + '/role':
      return updateRole(event);
    case 'GET /admin/users':
      return adminListAllUsers(event);
    default:
      return error(`Unsupported user route: ${route}`, 404);
  }
}