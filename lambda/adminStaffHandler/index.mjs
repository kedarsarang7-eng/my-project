// ============================================================================
// PETROL STAFF CONNECT - Admin Staff Management Handler
// ============================================================================
// AWS Lambda (Node.js 20.x) for admin to create/manage staff accounts
// 
// Endpoints:
// POST /admin/staff          - Create new staff account (Cognito + DynamoDB)
// GET  /admin/staff          - List all staff at a station
// PUT  /admin/staff/{id}     - Update staff details
// DELETE /admin/staff/{id}   - Deactivate staff account
// POST /admin/staff/{id}/reset-password - Reset staff password
//
// Protected by: Cognito Authorizer + Admin role claim
// ============================================================================

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { 
  PutCommand, 
  GetCommand,
  UpdateCommand,
  QueryCommand,
  ScanCommand
} from "@aws-sdk/lib-dynamodb";
import { 
  CognitoIdentityProviderClient,
  AdminCreateUserCommand,
  AdminDisableUserCommand,
  AdminEnableUserCommand,
  AdminAddUserToGroupCommand,
  AdminSetUserPasswordCommand
} from "@aws-sdk/client-cognito-identity-provider";
import { randomBytes } from "crypto";

const dynamo = new DynamoDBClient({ region: process.env.AWS_REGION || 'ap-south-1' });
const cognito = new CognitoIdentityProviderClient({ region: process.env.AWS_REGION || 'ap-south-1' });

const STAFF_TABLE = process.env.STAFF_TABLE || 'PetrolStaff';
const AUDIT_TABLE = process.env.AUDIT_TABLE || 'PetrolAuditLog';
const USER_POOL_ID = process.env.USER_POOL_ID;

export const handler = async (event) => {
  console.log('Event:', JSON.stringify(event));
  
  const { httpMethod, path, pathParameters, body, requestContext } = event;
  const claims = requestContext?.authorizer?.claims || {};
  
  // Verify caller is admin/manager
  const callerRole = claims['custom:role'];
  if (!['admin', 'manager', 'owner'].includes(callerRole)) {
    return response(403, { error: 'Forbidden: Only admin can manage staff' });
  }
  
  const callerStaffId = claims['custom:staff_id'];
  const callerStationId = claims['custom:pump_station_id'];
  
  try {
    // Route requests
    if (httpMethod === 'POST' && path === '/admin/staff') {
      return await createStaff(
        JSON.parse(body), 
        callerStaffId, 
        callerStationId
      );
    }
    
    if (httpMethod === 'GET' && path === '/admin/staff') {
      return await listStaff(callerStationId, event.queryStringParameters);
    }
    
    if (httpMethod === 'GET' && pathParameters?.staffId) {
      return await getStaffDetails(pathParameters.staffId, callerStationId);
    }
    
    if (httpMethod === 'PUT' && pathParameters?.staffId) {
      return await updateStaff(
        pathParameters.staffId, 
        JSON.parse(body),
        callerStationId
      );
    }
    
    if (httpMethod === 'DELETE' && pathParameters?.staffId) {
      return await deactivateStaff(
        pathParameters.staffId, 
        callerStationId,
        callerStaffId
      );
    }
    
    if (httpMethod === 'POST' && path.match(/\/admin\/staff\/.*\/reset-password/)) {
      return await resetStaffPassword(pathParameters?.staffId, callerStationId);
    }
    
    return response(404, { error: 'Route not found' });
    
  } catch (error) {
    console.error('Error:', error);
    return response(500, { 
      error: 'Internal server error',
      message: error.message 
    });
  }
};

// ============================================================================
// CREATE STAFF: Create Cognito user + DynamoDB profile
// ============================================================================
async function createStaff(body, createdBy, defaultStationId) {
  const { 
    fullName, 
    role = 'pump_operator', 
    pumpStationId = defaultStationId,
    phoneNumber,
    email
  } = body;
  
  // Validate required fields
  if (!fullName || !role) {
    return response(400, { error: 'Full name and role are required' });
  }
  
  // Validate role
  const validRoles = ['pump_operator', 'cashier', 'supervisor', 'manager'];
  if (!validRoles.includes(role)) {
    return response(400, { error: `Role must be one of: ${validRoles.join(', ')}` });
  }
  
  try {
    // Generate unique Staff ID
    const staffId = await generateUniqueStaffId(pumpStationId);
    
    // Generate temporary password
    const tempPassword = generateTempPassword();
    
    // Get permissions based on role
    const permissions = getRolePermissions(role);
    
    // Step 1: Create Cognito user
    const createUserCommand = new AdminCreateUserCommand({
      UserPoolId: USER_POOL_ID,
      Username: staffId,
      TemporaryPassword: tempPassword,
      UserAttributes: [
        { Name: 'custom:staff_id', Value: staffId },
        { Name: 'custom:role', Value: role },
        { Name: 'custom:pump_station_id', Value: pumpStationId },
        { Name: 'custom:permissions', Value: JSON.stringify(permissions) },
        { Name: 'custom:created_by', Value: createdBy },
        { Name: 'name', Value: fullName },
        ...(phoneNumber ? [{ Name: 'phone_number', Value: phoneNumber }] : []),
        ...(email ? [{ Name: 'email', Value: email }] : [])
      ],
      MessageAction: 'SUPPRESS', // We'll handle notification ourselves
      DesiredDeliveryMediums: []
    });
    
    await cognito.send(createUserCommand);
    
    // Step 2: Add user to Cognito group (for role-based auth)
    const addToGroupCommand = new AdminAddUserToGroupCommand({
      UserPoolId: USER_POOL_ID,
      Username: staffId,
      GroupName: role
    });
    
    await cognito.send(addToGroupCommand);
    
    // Step 3: Create DynamoDB profile
    const now = new Date().toISOString();
    const staffProfile = {
      staff_id: staffId,
      cognito_sub: '', // Will be updated on first login
      full_name: fullName,
      role: role,
      pump_station_id: pumpStationId,
      permissions: permissions,
      is_active: true,
      phone_number: phoneNumber || '',
      email: email || '',
      profile_image_url: '',
      created_at: now,
      created_by: createdBy,
      last_login: '',
      login_count: 0,
      device_ids: [],
      shift_status: 'off_shift'
    };
    
    const putCommand = new PutCommand({
      TableName: STAFF_TABLE,
      Item: staffProfile
    });
    
    await dynamo.send(putCommand);
    
    // Step 4: Log admin action
    await logAuditEvent(createdBy, 'ADMIN_CREATE_STAFF', { 
      targetStaffId: staffId, 
      role,
      pumpStationId 
    });
    
    // Step 5: Return credentials (these should be shared securely with staff)
    return response(201, {
      message: 'Staff account created successfully',
      staff: {
        staffId: staffId,
        fullName: fullName,
        role: role,
        pumpStationId: pumpStationId,
        permissions: permissions,
        createdAt: now
      },
      credentials: {
        staffId: staffId,
        tempPassword: tempPassword,
        message: 'Share these credentials securely with the staff member. They will be forced to change password on first login.'
      }
    });
    
  } catch (error) {
    console.error('Create staff error:', error);
    
    if (error.name === 'UsernameExistsException') {
      return response(409, { error: 'A staff member with this information already exists' });
    }
    
    throw error;
  }
}

// ============================================================================
// LIST STAFF: Get all staff at a station
// ============================================================================
async function listStaff(stationId, queryParams = {}) {
  const { role, isActive, limit = 50 } = queryParams;
  
  try {
    // Query by station using GSI
    const queryCommand = new QueryCommand({
      TableName: STAFF_TABLE,
      IndexName: 'station-role-index',
      KeyConditionExpression: 'pump_station_id = :stationId',
      FilterExpression: role ? '#role = :role' : undefined,
      ExpressionAttributeNames: role ? { '#role': 'role' } : undefined,
      ExpressionAttributeValues: {
        ':stationId': stationId,
        ...(role ? { ':role': role } : {})
      },
      Limit: parseInt(limit)
    });
    
    const result = await dynamo.send(queryCommand);
    
    // Filter by active status if requested
    let staff = result.Items || [];
    if (isActive !== undefined) {
      const activeBool = isActive === 'true';
      staff = staff.filter(s => s.is_active === activeBool);
    }
    
    // Sanitize sensitive data
    const sanitizedStaff = staff.map(s => ({
      staffId: s.staff_id,
      fullName: s.full_name,
      role: s.role,
      isActive: s.is_active,
      lastLogin: s.last_login,
      loginCount: s.login_count,
      shiftStatus: s.shift_status,
      profileImageUrl: s.profile_image_url
    }));
    
    return response(200, {
      staff: sanitizedStaff,
      count: sanitizedStaff.length,
      stationId: stationId
    });
    
  } catch (error) {
    console.error('List staff error:', error);
    throw error;
  }
}

// ============================================================================
// GET STAFF DETAILS: Full profile for a specific staff
// ============================================================================
async function getStaffDetails(staffId, adminStationId) {
  try {
    const staff = await getStaffFromDynamoDB(staffId);
    
    if (!staff) {
      return response(404, { error: 'Staff not found' });
    }
    
    // Verify admin manages this station
    if (staff.pump_station_id !== adminStationId) {
      return response(403, { error: 'Cannot access staff from different station' });
    }
    
    return response(200, {
      staff: {
        staffId: staff.staff_id,
        fullName: staff.full_name,
        role: staff.role,
        pumpStationId: staff.pump_station_id,
        permissions: staff.permissions,
        isActive: staff.is_active,
        phoneNumber: staff.phone_number,
        email: staff.email,
        profileImageUrl: staff.profile_image_url,
        createdAt: staff.created_at,
        lastLogin: staff.last_login,
        loginCount: staff.login_count,
        shiftStatus: staff.shift_status,
        deviceIds: staff.device_ids
      }
    });
    
  } catch (error) {
    console.error('Get staff details error:', error);
    throw error;
  }
}

// ============================================================================
// UPDATE STAFF: Modify staff details
// ============================================================================
async function updateStaff(staffId, body, adminStationId) {
  const { fullName, role, phoneNumber, email, isActive } = body;
  
  try {
    // Get current staff
    const staff = await getStaffFromDynamoDB(staffId);
    
    if (!staff) {
      return response(404, { error: 'Staff not found' });
    }
    
    if (staff.pump_station_id !== adminStationId) {
      return response(403, { error: 'Cannot modify staff from different station' });
    }
    
    // Build update expression
    const updates = [];
    const values = {};
    
    if (fullName) {
      updates.push('full_name = :fullName');
      values[':fullName'] = fullName;
    }
    
    if (role) {
      updates.push('#role = :role');
      values[':role'] = role;
      // Also update permissions
      updates.push('permissions = :permissions');
      values[':permissions'] = getRolePermissions(role);
    }
    
    if (phoneNumber !== undefined) {
      updates.push('phone_number = :phoneNumber');
      values[':phoneNumber'] = phoneNumber;
    }
    
    if (email !== undefined) {
      updates.push('email = :email');
      values[':email'] = email;
    }
    
    if (isActive !== undefined) {
      updates.push('is_active = :isActive');
      values[':isActive'] = isActive;
      
      // Also update Cognito user status
      if (isActive === false) {
        await cognito.send(new AdminDisableUserCommand({
          UserPoolId: USER_POOL_ID,
          Username: staffId
        }));
      } else {
        await cognito.send(new AdminEnableUserCommand({
          UserPoolId: USER_POOL_ID,
          Username: staffId
        }));
      }
    }
    
    updates.push('updated_at = :updatedAt');
    values[':updatedAt'] = new Date().toISOString();
    
    const updateCommand = new UpdateCommand({
      TableName: STAFF_TABLE,
      Key: { staff_id: staffId },
      UpdateExpression: `SET ${updates.join(', ')}`,
      ExpressionAttributeNames: role ? { '#role': 'role' } : undefined,
      ExpressionAttributeValues: values,
      ReturnValues: 'ALL_NEW'
    });
    
    const result = await dynamo.send(updateCommand);
    
    return response(200, {
      message: 'Staff updated successfully',
      staff: {
        staffId: result.Attributes.staff_id,
        fullName: result.Attributes.full_name,
        role: result.Attributes.role,
        isActive: result.Attributes.is_active
      }
    });
    
  } catch (error) {
    console.error('Update staff error:', error);
    throw error;
  }
}

// ============================================================================
// DEACTIVATE STAFF: Soft delete (disable account)
// ============================================================================
async function deactivateStaff(staffId, adminStationId, deactivatedBy) {
  try {
    const staff = await getStaffFromDynamoDB(staffId);
    
    if (!staff) {
      return response(404, { error: 'Staff not found' });
    }
    
    if (staff.pump_station_id !== adminStationId) {
      return response(403, { error: 'Cannot deactivate staff from different station' });
    }
    
    // Disable in Cognito
    await cognito.send(new AdminDisableUserCommand({
      UserPoolId: USER_POOL_ID,
      Username: staffId
    }));
    
    // Mark inactive in DynamoDB
    const updateCommand = new UpdateCommand({
      TableName: STAFF_TABLE,
      Key: { staff_id: staffId },
      UpdateExpression: 'SET is_active = :isActive, deactivated_at = :deactivatedAt, deactivated_by = :deactivatedBy',
      ExpressionAttributeValues: {
        ':isActive': false,
        ':deactivatedAt': new Date().toISOString(),
        ':deactivatedBy': deactivatedBy
      }
    });
    
    await dynamo.send(updateCommand);
    
    // Log action
    await logAuditEvent(deactivatedBy, 'ADMIN_DEACTIVATE_STAFF', { targetStaffId: staffId });
    
    return response(200, {
      message: 'Staff account deactivated successfully',
      staffId: staffId
    });
    
  } catch (error) {
    console.error('Deactivate staff error:', error);
    throw error;
  }
}

// ============================================================================
// RESET PASSWORD: Generate new temp password for staff
// ============================================================================
async function resetStaffPassword(staffId, adminStationId) {
  try {
    const staff = await getStaffFromDynamoDB(staffId);
    
    if (!staff) {
      return response(404, { error: 'Staff not found' });
    }
    
    if (staff.pump_station_id !== adminStationId) {
      return response(403, { error: 'Cannot reset password for staff from different station' });
    }
    
    const tempPassword = generateTempPassword();
    
    // Set permanent password (forces change on next login)
    await cognito.send(new AdminSetUserPasswordCommand({
      UserPoolId: USER_POOL_ID,
      Username: staffId,
      Password: tempPassword,
      Permanent: false // Forces password change
    }));
    
    return response(200, {
      message: 'Password reset successfully',
      staffId: staffId,
      tempPassword: tempPassword,
      note: 'Staff will be required to set a new password on next login'
    });
    
  } catch (error) {
    console.error('Reset password error:', error);
    throw error;
  }
}

// ============================================================================
// HELPERS
// ============================================================================

async function getStaffFromDynamoDB(staffId) {
  const command = new GetCommand({
    TableName: STAFF_TABLE,
    Key: { staff_id: staffId }
  });
  
  const result = await dynamo.send(command);
  return result.Item;
}

async function generateUniqueStaffId(stationId) {
  // Format: PSC-{STATION_CODE}-{SEQUENCE}
  // Example: PSC-PUNE01-042
  
  const stationCode = stationId.replace(/[^A-Z0-9]/gi, '').toUpperCase().slice(0, 5);
  const timestamp = Date.now().toString().slice(-3);
  const random = Math.floor(Math.random() * 90) + 10; // 10-99
  
  return `PSC-${stationCode}-${timestamp}${random}`;
}

function generateTempPassword() {
  const chars = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
  let password = '';
  
  // Generate 10 random characters
  for (let i = 0; i < 10; i++) {
    password += chars[Math.floor(Math.random() * chars.length)];
  }
  
  // Ensure complexity: uppercase, lowercase, number
  password = 'P@' + password;
  
  return password;
}

function getRolePermissions(role) {
  const permissions = {
    pump_operator: [
      'view_own_shifts',
      'start_shift',
      'end_shift',
      'record_fuel_sale',
      'view_own_transactions'
    ],
    cashier: [
      'view_own_shifts',
      'start_shift',
      'end_shift',
      'process_payment',
      'view_daily_sales',
      'generate_receipt',
      'view_own_transactions'
    ],
    supervisor: [
      'view_all_shifts',
      'manage_staff_shifts',
      'view_station_reports',
      'approve_transactions',
      'view_all_transactions',
      'manage_pump_operations'
    ],
    manager: [
      'view_all_data',
      'manage_staff',
      'full_reports',
      'approve_transactions',
      'manage_inventory',
      'configure_station',
      'view_analytics'
    ]
  };
  
  return permissions[role] || permissions.pump_operator;
}

async function logAuditEvent(staffId, action, details) {
  const logEntry = {
    log_id: `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
    timestamp: new Date().toISOString(),
    staff_id: staffId,
    action: action,
    details: details,
    ttl: Math.floor(Date.now() / 1000) + (90 * 24 * 60 * 60) // 90 days TTL
  };
  
  const command = new PutCommand({
    TableName: AUDIT_TABLE,
    Item: logEntry
  });
  
  try {
    await dynamo.send(command);
  } catch (error) {
    console.error('Failed to log audit event:', error);
  }
}

function response(statusCode, body) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type,Authorization',
      'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
      'X-Content-Type-Options': 'nosniff'
    },
    body: JSON.stringify(body)
  };
}
