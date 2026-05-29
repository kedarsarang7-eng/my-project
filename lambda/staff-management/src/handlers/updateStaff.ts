// ============================================================================
// UPDATE STAFF HANDLER - PUT /staff/{staffId}
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { withErrorHandler, success, optionsResponse } from '../middleware/errorHandler';
import { validateParams, validateBody, staffIdParamSchema, updateStaffSchema, UpdateStaffInput } from '../middleware/validator';
import { assertOwnerOrAdmin, assertPumpAccess } from '../utils/auth';
import { getItem, updateItem } from '../utils/dynamodb';
import { adminUpdateUserAttributes, adminRemoveUserFromGroup, adminAddUserToGroup } from '../utils/cognito';
import { TABLES } from '../constants/tables';
import { DEFAULT_PERMISSIONS } from '../constants/roles';
import { StaffProfile } from '../types/staff';
import { NotFoundError, ConflictError } from '../middleware/errorHandler';
import { logActivity } from './activityLog';

export const handler = withErrorHandler(async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  // Handle CORS preflight
  if (event.httpMethod === 'OPTIONS') {
    return optionsResponse();
  }

  // Verify authorization - only owners/admins can update staff
  const authContext = assertOwnerOrAdmin(event);

  // Validate path and body
  const params = validateParams(staffIdParamSchema, event.pathParameters || {});
  const input = validateBody<UpdateStaffInput>(updateStaffSchema, event.body);

  // Get existing staff
  const existingStaff = await getItem<StaffProfile>(
    TABLES.STAFF_PROFILES,
    { staffId: params.staffId, SK: 'PROFILE' }
  );

  if (!existingStaff) {
    throw new NotFoundError(`Staff with ID ${params.staffId} not found`);
  }

  // Verify pump access
  assertPumpAccess(event, existingStaff.petrolPumpId);

  // Build update
  const updates: Record<string, any> = {
    updatedAt: new Date().toISOString()
  };

  const cognitoUpdates: Array<{ Name: string; Value: string }> = [];

  if (input.fullName !== undefined) {
    updates.fullName = input.fullName;
    cognitoUpdates.push({ Name: 'name', Value: input.fullName });
  }

  if (input.phoneNumber !== undefined) {
    updates.phoneNumber = input.phoneNumber;
    cognitoUpdates.push({ Name: 'phone_number', Value: input.phoneNumber });
  }

  if (input.email !== undefined) {
    updates.email = input.email;
    cognitoUpdates.push({ Name: 'email', Value: input.email });
  }

  // Handle role change
  if (input.role !== undefined && input.role !== existingStaff.role) {
    updates.role = input.role;
    updates.permissions = input.permissions 
      ? { ...DEFAULT_PERMISSIONS[input.role], ...input.permissions }
      : DEFAULT_PERMISSIONS[input.role];
    
    cognitoUpdates.push({ 
      Name: 'custom:role', 
      Value: input.role 
    });
    cognitoUpdates.push({
      Name: 'custom:permissions',
      Value: JSON.stringify(updates.permissions)
    });

    // Update Cognito groups
    const oldGroup = existingStaff.role === 'admin' ? 'Owner' : 
                     existingStaff.role === 'manager' ? 'Manager' :
                     existingStaff.role === 'supervisor' ? 'Supervisor' :
                     existingStaff.role === 'cashier' ? 'Cashier' : 'Attendant';
    
    const newGroup = input.role === 'admin' ? 'Owner' : 
                     input.role === 'manager' ? 'Manager' :
                     input.role === 'supervisor' ? 'Supervisor' :
                     input.role === 'cashier' ? 'Cashier' : 'Attendant';

    await adminRemoveUserFromGroup(params.staffId, oldGroup);
    await adminAddUserToGroup(params.staffId, newGroup);

    // Update GSI sort key for role change
    updates.GSI1SK = `ROLE#${input.role}#STAFF#${params.staffId}`;
  } else if (input.permissions !== undefined) {
    // Update permissions without role change
    updates.permissions = { ...existingStaff.permissions, ...input.permissions };
    cognitoUpdates.push({
      Name: 'custom:permissions',
      Value: JSON.stringify(updates.permissions)
    });
  }

  if (input.shiftTiming !== undefined) {
    updates.shiftTiming = input.shiftTiming;
  }

  if (input.isActive !== undefined) {
    updates.isActive = input.isActive;
    updates.GSI2SK = `ACTIVE#${input.isActive}#DATE#${existingStaff.createdAt}`;
    cognitoUpdates.push({ 
      Name: 'custom:isActive', 
      Value: input.isActive.toString() 
    });
  }

  if (input.emergencyContact !== undefined) {
    updates.emergencyContact = input.emergencyContact;
  }

  // Update DynamoDB
  const updatedStaff = await updateItem<StaffProfile>(
    TABLES.STAFF_PROFILES,
    { staffId: params.staffId, SK: 'PROFILE' },
    updates,
    { expressionAttributeNames: input.role ? { '#role': 'role' } : undefined }
  );

  // Update Cognito if needed
  if (cognitoUpdates.length > 0) {
    await adminUpdateUserAttributes(params.staffId, cognitoUpdates);
  }

  // Log activity
  await logActivity({
    staffId: params.staffId,
    eventType: 'UPDATED',
    performedBy: authContext.userId,
    notes: `Updated fields: ${Object.keys(updates).filter(k => k !== 'updatedAt').join(', ')}`
  });

  // Sanitize and return
  const { SK, GSI1PK, GSI1SK, GSI2PK, GSI2SK, cognitoUserId, ...safeStaff } = updatedStaff as any;

  return success(safeStaff);
});
