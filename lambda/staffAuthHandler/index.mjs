// ============================================================================
// PETROL STAFF CONNECT - Authentication Handler
// ============================================================================
// AWS Lambda (Node.js 20.x) for staff authentication and profile management
// 
// Endpoints:
// POST /auth/login           - Authenticate staff (Cognito + DynamoDB)
// GET  /staff/profile        - Get staff profile from DynamoDB
// POST /auth/biometric       - Biometric login verification
// POST /auth/logout          - Logout and clear session
// POST /auth/forgot-password - Trigger password reset
//
// DynamoDB Tables:
// - PetrolStaff: Staff profiles, roles, permissions
// - PetrolAuditLog: Login/logout audit trail
// ============================================================================

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { 
  GetCommand, 
  PutCommand, 
  UpdateCommand,
  QueryCommand 
} from "@aws-sdk/lib-dynamodb";
import { 
  CognitoIdentityProviderClient,
  InitiateAuthCommand,
  GetUserCommand,
  GlobalSignOutCommand,
  ForgotPasswordCommand
} from "@aws-sdk/client-cognito-identity-provider";

const dynamo = new DynamoDBClient({ region: process.env.AWS_REGION || 'ap-south-1' });
const cognito = new CognitoIdentityProviderClient({ region: process.env.AWS_REGION || 'ap-south-1' });

const STAFF_TABLE = process.env.STAFF_TABLE || 'PetrolStaff';
const AUDIT_TABLE = process.env.AUDIT_TABLE || 'PetrolAuditLog';
const USER_POOL_ID = process.env.USER_POOL_ID;
const CLIENT_ID = process.env.COGNITO_CLIENT_ID;

export const handler = async (event) => {
  console.log('Event:', JSON.stringify(event));
  
  const { httpMethod, path, body, requestContext } = event;
  const claims = requestContext?.authorizer?.claims || {};
  
  try {
    // Route requests
    if (httpMethod === 'POST' && path === '/auth/login') {
      return await handleLogin(JSON.parse(body));
    }
    
    if (httpMethod === 'GET' && path === '/staff/profile') {
      return await getStaffProfile(claims);
    }
    
    if (httpMethod === 'POST' && path === '/auth/biometric') {
      return await handleBiometricLogin(claims, JSON.parse(body));
    }
    
    if (httpMethod === 'POST' && path === '/auth/logout') {
      return await handleLogout(claims);
    }
    
    if (httpMethod === 'POST' && path === '/auth/forgot-password') {
      return await handleForgotPassword(JSON.parse(body));
    }
    
    if (httpMethod === 'POST' && path === '/auth/refresh') {
      return await handleTokenRefresh(JSON.parse(body));
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
// LOGIN: Authenticate with Cognito + Fetch staff profile from DynamoDB
// ============================================================================
async function handleLogin(body) {
  const { staffId, password, deviceId, devicePlatform } = body;
  
  if (!staffId || !password) {
    return response(400, { error: 'Staff ID and password are required' });
  }
  
  try {
    // Step 1: Authenticate with Cognito
    const authCommand = new InitiateAuthCommand({
      AuthFlow: 'USER_PASSWORD_AUTH',
      ClientId: CLIENT_ID,
      AuthParameters: {
        USERNAME: staffId,
        PASSWORD: password
      }
    });
    
    const authResult = await cognito.send(authCommand);
    
    if (!authResult.AuthenticationResult) {
      return response(401, { error: 'Invalid credentials' });
    }
    
    // Step 2: Get staff profile from DynamoDB
    const staffProfile = await getStaffFromDynamoDB(staffId);
    
    if (!staffProfile) {
      return response(404, { error: 'Staff profile not found' });
    }
    
    // Step 3: Check if account is active
    if (!staffProfile.is_active) {
      await logAuditEvent(staffId, 'LOGIN_FAILED_ACCOUNT_DISABLED', { deviceId });
      return response(403, { 
        error: 'ACCOUNT_DEACTIVATED',
        message: 'Your account has been deactivated. Contact Admin.'
      });
    }
    
    // Step 4: Update last login timestamp
    await updateLastLogin(staffId);
    
    // Step 5: Log successful login
    await logAuditEvent(staffId, 'LOGIN_SUCCESS', { 
      deviceId, 
      devicePlatform,
      ipAddress: 'unknown' // Get from event.requestContext
    });
    
    // Step 6: Return tokens + staff profile
    return response(200, {
      message: 'Login successful',
      tokens: {
        accessToken: authResult.AuthenticationResult.AccessToken,
        idToken: authResult.AuthenticationResult.IdToken,
        refreshToken: authResult.AuthenticationResult.RefreshToken,
        expiresIn: authResult.AuthenticationResult.ExpiresIn
      },
      staff: {
        staffId: staffProfile.staff_id,
        fullName: staffProfile.full_name,
        role: staffProfile.role,
        pumpStationId: staffProfile.pump_station_id,
        permissions: staffProfile.permissions,
        isFirstLogin: staffProfile.login_count === 0,
        profileImageUrl: staffProfile.profile_image_url,
        shiftStatus: staffProfile.shift_status
      }
    });
    
  } catch (error) {
    console.error('Login error:', error);
    
    if (error.name === 'NotAuthorizedException') {
      await logAuditEvent(staffId, 'LOGIN_FAILED_INVALID_CREDENTIALS', { deviceId });
      return response(401, { error: 'Invalid Staff ID or Password' });
    }
    
    if (error.name === 'UserNotFoundException') {
      return response(401, { error: 'Invalid Staff ID or Password' });
    }
    
    if (error.name === 'NewPasswordRequiredException') {
      return response(403, { 
        error: 'NEW_PASSWORD_REQUIRED',
        message: 'You must change your password before logging in.'
      });
    }
    
    throw error;
  }
}

// ============================================================================
// GET STAFF PROFILE: Fetch from DynamoDB by staffId
// ============================================================================
async function getStaffProfile(claims) {
  const staffId = claims['custom:staff_id'];
  
  if (!staffId) {
    return response(401, { error: 'Unauthorized: Missing staff_id in token' });
  }
  
  try {
    const profile = await getStaffFromDynamoDB(staffId);
    
    if (!profile) {
      return response(404, { error: 'Staff profile not found' });
    }
    
    if (!profile.is_active) {
      return response(403, { 
        error: 'ACCOUNT_DEACTIVATED',
        message: 'Your account has been deactivated.'
      });
    }
    
    return response(200, {
      staff: {
        staffId: profile.staff_id,
        fullName: profile.full_name,
        role: profile.role,
        pumpStationId: profile.pump_station_id,
        permissions: profile.permissions,
        profileImageUrl: profile.profile_image_url,
        shiftStatus: profile.shift_status,
        lastLogin: profile.last_login,
        loginCount: profile.login_count
      }
    });
    
  } catch (error) {
    console.error('Get profile error:', error);
    throw error;
  }
}

// ============================================================================
// BIOMETRIC LOGIN: Verify biometric + return stored tokens
// ============================================================================
async function handleBiometricLogin(claims, body) {
  const { biometricToken, deviceId } = body;
  const staffId = claims['custom:staff_id'];
  
  if (!staffId) {
    return response(401, { error: 'Unauthorized' });
  }
  
  try {
    // Get staff profile
    const profile = await getStaffFromDynamoDB(staffId);
    
    if (!profile || !profile.is_active) {
      return response(403, { error: 'Account deactivated or not found' });
    }
    
    // Check if device is registered for biometric
    const deviceRegistered = profile.device_ids?.includes(deviceId);
    
    if (!deviceRegistered) {
      return response(403, { 
        error: 'BIOMETRIC_NOT_REGISTERED',
        message: 'This device is not registered for biometric login. Please login with credentials first.'
      });
    }
    
    // Log biometric login
    await logAuditEvent(staffId, 'LOGIN_BIOMETRIC_SUCCESS', { deviceId });
    
    return response(200, {
      message: 'Biometric login successful',
      staff: {
        staffId: profile.staff_id,
        fullName: profile.full_name,
        role: profile.role,
        pumpStationId: profile.pump_station_id,
        permissions: profile.permissions,
        shiftStatus: profile.shift_status
      }
    });
    
  } catch (error) {
    console.error('Biometric login error:', error);
    throw error;
  }
}

// ============================================================================
// LOGOUT: Sign out from Cognito + log audit event
// ============================================================================
async function handleLogout(claims) {
  const staffId = claims['custom:staff_id'];
  const accessToken = claims['access_token']; // Would need to pass this from client
  
  try {
    // Sign out from Cognito (global signout)
    if (accessToken) {
      const signOutCommand = new GlobalSignOutCommand({
        AccessToken: accessToken
      });
      await cognito.send(signOutCommand);
    }
    
    // Log logout event
    if (staffId) {
      await logAuditEvent(staffId, 'LOGOUT', {});
    }
    
    return response(200, { message: 'Logout successful' });
    
  } catch (error) {
    console.error('Logout error:', error);
    // Still return success even if Cognito signout fails
    return response(200, { message: 'Logout successful' });
  }
}

// ============================================================================
// FORGOT PASSWORD: Trigger Cognito password reset
// ============================================================================
async function handleForgotPassword(body) {
  const { staffId } = body;
  
  if (!staffId) {
    return response(400, { error: 'Staff ID is required' });
  }
  
  try {
    const forgotCommand = new ForgotPasswordCommand({
      ClientId: CLIENT_ID,
      Username: staffId
    });
    
    await cognito.send(forgotCommand);
    
    // Notify admin (optional - could send SNS notification)
    
    return response(200, { 
      message: 'Password reset instructions sent to registered phone/email'
    });
    
  } catch (error) {
    console.error('Forgot password error:', error);
    
    // Don't reveal if user exists or not for security
    return response(200, { 
      message: 'If a staff account exists with this ID, password reset instructions will be sent.'
    });
  }
}

// ============================================================================
// TOKEN REFRESH: Get new access token using refresh token
// ============================================================================
async function handleTokenRefresh(body) {
  const { refreshToken } = body;
  
  if (!refreshToken) {
    return response(400, { error: 'Refresh token is required' });
  }
  
  try {
    const refreshCommand = new InitiateAuthCommand({
      AuthFlow: 'REFRESH_TOKEN_AUTH',
      ClientId: CLIENT_ID,
      AuthParameters: {
        REFRESH_TOKEN: refreshToken
      }
    });
    
    const result = await cognito.send(refreshCommand);
    
    return response(200, {
      tokens: {
        accessToken: result.AuthenticationResult.AccessToken,
        idToken: result.AuthenticationResult.IdToken,
        expiresIn: result.AuthenticationResult.ExpiresIn
      }
    });
    
  } catch (error) {
    console.error('Token refresh error:', error);
    return response(401, { error: 'Invalid or expired refresh token' });
  }
}

// ============================================================================
// HELPER: Get staff from DynamoDB
// ============================================================================
async function getStaffFromDynamoDB(staffId) {
  const command = new GetCommand({
    TableName: STAFF_TABLE,
    Key: {
      staff_id: staffId
    }
  });
  
  const result = await dynamo.send(command);
  return result.Item;
}

// ============================================================================
// HELPER: Update last login timestamp
// ============================================================================
async function updateLastLogin(staffId) {
  const command = new UpdateCommand({
    TableName: STAFF_TABLE,
    Key: {
      staff_id: staffId
    },
    UpdateExpression: 'SET last_login = :now, login_count = if_not_exists(login_count, :zero) + :one',
    ExpressionAttributeValues: {
      ':now': new Date().toISOString(),
      ':zero': 0,
      ':one': 1
    }
  });
  
  await dynamo.send(command);
}

// ============================================================================
// HELPER: Log audit event to DynamoDB
// ============================================================================
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
    // Don't fail the main operation if audit logging fails
  }
}

// ============================================================================
// HELPER: Response formatter
// ============================================================================
function response(statusCode, body) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type,Authorization',
      'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
      'X-Content-Type-Options': 'nosniff',
      'X-Frame-Options': 'DENY'
    },
    body: JSON.stringify(body)
  };
}
