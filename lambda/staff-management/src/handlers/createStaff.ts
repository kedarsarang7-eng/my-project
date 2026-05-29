// ============================================================================
// CREATE STAFF HANDLER - POST /staff
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { withErrorHandler, success, error, optionsResponse } from '../middleware/errorHandler';
import { validateBody } from '../middleware/validator';
import { createStaffSchema, CreateStaffInput } from '../middleware/validator';
import { assertOwnerOrAdmin, extractPetrolPumpId, AuthContext } from '../utils/auth';
import { generateStaffId, generateTemporaryPassword } from '../utils/idGenerator';
import { putItem } from '../utils/dynamodb';
import { adminCreateUser, adminAddUserToGroup } from '../utils/cognito';
import { TABLES } from '../constants/tables';
import { DEFAULT_PERMISSIONS } from '../constants/roles';
import { StaffProfile, CreateStaffResponse } from '../types/staff';
import { logActivity } from './activityLog';

export const handler = withErrorHandler(async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  // Handle CORS preflight
  if (event.httpMethod === 'OPTIONS') {
    return optionsResponse();
  }

  // Verify authorization - only owners/admins can create staff
  const authContext = assertOwnerOrAdmin(event);

  // Validate request body
  const input = validateBody<CreateStaffInput>(createStaffSchema, event.body);

  // Generate staff ID
  const pumpId = input.petrolPumpId || extractPetrolPumpId(event) || 'default';
  const staffId = await generateStaffId(pumpId);

  // Generate temporary password
  const tempPassword = generateTemporaryPassword();

  // Get permissions based on role
  const permissions = input.permissions 
    ? { ...DEFAULT_PERMISSIONS[input.role], ...input.permissions }
    : DEFAULT_PERMISSIONS[input.role];

  // Create Cognito user
  const cognitoUser = await adminCreateUser({
    username: staffId,
    temporaryPassword: tempPassword,
    userAttributes: [
      { Name: 'custom:staff_id', Value: staffId },
      { Name: 'custom:role', Value: input.role },
      { Name: 'custom:petrol_pump_id', Value: pumpId },
      { Name: 'custom:isActive', Value: 'true' },
      { Name: 'custom:permissions', Value: JSON.stringify(permissions) },
      { Name: 'custom:created_by', Value: authContext.userId },
      { Name: 'name', Value: input.fullName },
      ...(input.phoneNumber ? [{ Name: 'phone_number', Value: input.phoneNumber }] : []),
      ...(input.email ? [{ Name: 'email', Value: input.email }] : [])
    ],
    messageAction: 'SUPPRESS'
  });

  // Add to Cognito group
  const groupName = input.role === 'admin' ? 'Owner' : 
                    input.role === 'manager' ? 'Manager' :
                    input.role === 'supervisor' ? 'Supervisor' :
                    input.role === 'cashier' ? 'Cashier' : 'Attendant';
  
  await adminAddUserToGroup(staffId, groupName);

  // Create staff profile in DynamoDB
  const now = new Date().toISOString();
  const staffProfile: StaffProfile = {
    staffId,
    SK: 'PROFILE',
    cognitoUserId: cognitoUser.userSub,
    fullName: input.fullName,
    phoneNumber: input.phoneNumber,
    email: input.email,
    role: input.role,
    permissions,
    shiftTiming: {
      start: input.shiftTiming?.start || '09:00',
      end: input.shiftTiming?.end || '17:00',
      days: input.shiftTiming?.days || ['MON', 'TUE', 'WED', 'THU', 'FRI']
    },
    joiningDate: now,
    isActive: true,
    petrolPumpId: pumpId,
    createdBy: authContext.userId,
    createdAt: now,
    updatedAt: now,
    emergencyContact: input.emergencyContact ? {
      name: input.emergencyContact.name || '',
      phone: input.emergencyContact.phone || '',
      relation: input.emergencyContact.relation || ''
    } : undefined,
    documents: []
  };

  // Add GSI keys for efficient querying
  (staffProfile as any).GSI1PK = `PUMP#${pumpId}`;
  (staffProfile as any).GSI1SK = `ROLE#${input.role}#STAFF#${staffId}`;
  (staffProfile as any).GSI2PK = `PUMP#${pumpId}`;
  (staffProfile as any).GSI2SK = `ACTIVE#true#DATE#${now}`;

  await putItem<StaffProfile>(TABLES.STAFF_PROFILES, staffProfile);

  // Log activity
  await logActivity({
    staffId,
    eventType: 'CREATED',
    performedBy: authContext.userId,
    notes: `Staff created with role ${input.role}`
  });

  // Return success with credentials
  const response: CreateStaffResponse = {
    staffId,
    temporaryPassword: tempPassword,
    cognitoUserId: cognitoUser.userSub
  };

  return success(response, 201);
});
