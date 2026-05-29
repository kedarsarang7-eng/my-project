// ============================================================================
// ACADEMIC COACHING — BIOMETRIC INTEGRATION MODULE
// ============================================================================
// Webhook handlers for biometric devices (fingerprint/face recognition)
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole, BusinessType } from '../types/tenant.types';
import { FeatureKey } from '../config/plan-feature-registry';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import {
  Keys,
  putItem,
  getItem,
  updateItem,
  queryAllItems,
} from '../config/dynamodb.config';
import { broadcastToClientType } from '../services/websocket.service';
import { WSEventName, ClientType } from '../types/websocket.types';

const AC_BIOMETRIC_OPTS = {
  requiredBusinessType: BusinessType.SCHOOL_ERP,
  requiredFeature: FeatureKey.AC_ATTENDANCE_MANAGEMENT,
};

function uid(): string {
  return Math.random().toString(36).substring(2, 18).toUpperCase();
}

function now(): string {
  return new Date().toISOString();
}

// ============================================================================
// DEVICE MANAGEMENT
// ============================================================================

/**
 * GET /ac/biometric/devices
 * List registered biometric devices
 */
export const listDevices = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (_event, _ctx, auth) => {
    const pk = Keys.tenantPK(auth.tenantId);
    const devices = await queryAllItems(pk, 'AC_BIOMETRIC_DEVICE#');
    return response.success(devices);
  },
  AC_BIOMETRIC_OPTS,
);

/**
 * POST /ac/biometric/devices
 * Register a new biometric device
 */
export const registerDevice = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { deviceId, deviceName, deviceType, location, ipAddress } = body;

    const pk = Keys.tenantPK(auth.tenantId);
    const ts = now();

    const device = {
      PK: pk,
      SK: `AC_BIOMETRIC_DEVICE#${deviceId}`,
      deviceId,
      deviceName,
      deviceType: deviceType || 'fingerprint', // fingerprint, face, card
      location,
      ipAddress,
      isActive: true,
      lastSeenAt: ts,
      registeredAt: ts,
      apiKey: uid(), // For device authentication
    };

    await putItem(device);
    logger.info('Biometric device registered', { tenantId: auth.tenantId, deviceId });

    return response.success({ ...device, apiKey: '[HIDDEN]' }, 201);
  },
  AC_BIOMETRIC_OPTS,
);

/**
 * POST /ac/biometric/devices/{id}/enroll
 * Enroll student/faculty in biometric device
 */
export const enrollUser = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const deviceId = event.pathParameters?.id;
    if (!deviceId) return response.badRequest('Device ID required');

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { personType, personId, biometricId, templateData } = body;

    const pk = Keys.tenantPK(auth.tenantId);

    // Verify device exists
    const device = await getItem(pk, `AC_BIOMETRIC_DEVICE#${deviceId}`);
    if (!device) return response.notFound('Device not found');

    // Verify person exists
    const personKey = personType === 'student' 
      ? Keys.acStudentSK(personId)
      : `AC_FACULTY#${personId}`;
    const person = await getItem(pk, personKey);
    if (!person) return response.notFound(`${personType} not found`);

    const id = uid();
    const ts = now();

    const enrollment = {
      PK: pk,
      SK: `AC_BIOMETRIC_ENROLLMENT#${id}`,
      GSI1PK: `AC_ENROLLMENT_BY_PERSON#${auth.tenantId}#${personType}#${personId}`,
      GSI1SK: deviceId,
      id,
      deviceId,
      personType,
      personId,
      biometricId, // ID assigned by device
      templateHash: templateData ? hashTemplate(templateData) : null, // Store hash only
      enrolledAt: ts,
      enrolledBy: auth.sub,
      isActive: true,
    };

    await putItem(enrollment);

    // Update person record with biometric flag
    await updateItem(pk, personKey, {
      updateExpression: 'SET #biometricEnrolled = :enrolled, #updatedAt = :updatedAt',
      expressionAttributeNames: { '#biometricEnrolled': 'biometricEnrolled', '#updatedAt': 'updatedAt' },
      expressionAttributeValues: { ':enrolled': true, ':updatedAt': ts },
    });

    logger.info('Biometric enrollment completed', { tenantId: auth.tenantId, deviceId, personId });

    return response.success(enrollment, 201);
  },
  AC_BIOMETRIC_OPTS,
);

// ============================================================================
// WEBHOOK HANDLERS (Called by biometric devices)
// ============================================================================

/**
 * POST /ac/biometric/webhook/attendance
 * Webhook for attendance punches from biometric device
 */
export const attendanceWebhook = async (event: any, _context: any): Promise<any> => {
  try {
    // Verify device API key
    const apiKey = event.headers?.['x-device-api-key'];
    const deviceId = event.headers?.['x-device-id'];
    
    if (!apiKey || !deviceId) {
      return { statusCode: 401, body: 'Unauthorized' };
    }

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { biometricId, timestamp, punchType } = body; // punchType: 'in' or 'out'

    // Find enrollment by biometricId
    // Note: This requires a scan or GSI - in production, use GSI on biometricId
    const pk = Keys.tenantPK(getTenantIdFromApiKey(apiKey));
    
    const enrollments = await queryAllItems(pk, 'AC_BIOMETRIC_ENROLLMENT#', {
      filterExpression: 'biometricId = :biometricId AND isActive = :isActive',
      expressionAttributeValues: { ':biometricId': biometricId, ':isActive': true },
    });

    if (enrollments.length === 0) {
      logger.error('Biometric ID not found', { biometricId, deviceId });
      return { statusCode: 404, body: 'Enrollment not found' };
    }

    const enrollment = enrollments[0] as any;
    const ts = now();

    // Record attendance punch
    const punchId = uid();
    const punch = {
      PK: pk,
      SK: `AC_BIOMETRIC_PUNCH#${ts}#${punchId}`,
      GSI1PK: `AC_PUNCHES_BY_PERSON#${enrollment.personType}#${enrollment.personId}`,
      GSI1SK: ts,
      id: punchId,
      deviceId,
      biometricId,
      personType: enrollment.personType,
      personId: enrollment.personId,
      punchType, // 'in' or 'out'
      punchTime: timestamp || ts,
      processed: false,
      createdAt: ts,
    };

    await putItem(punch);

    // Broadcast to WebSocket for real-time updates
    broadcastToClientType(
      getTenantIdFromApiKey(apiKey),
      ClientType.DESKTOP_APP,
      WSEventName.AC_ATTENDANCE_MARKED,
      {
        personType: enrollment.personType,
        personId: enrollment.personId,
        punchType,
        timestamp: punch.punchTime,
        deviceId,
      }
    ).catch(() => { /* non-critical */ });

    logger.info('Biometric punch recorded', { 
      tenantId: getTenantIdFromApiKey(apiKey),
      deviceId, 
      personId: enrollment.personId,
      punchType 
    });

    return { statusCode: 200, body: JSON.stringify({ success: true, punchId }) };
  } catch (error) {
    logger.error('Biometric webhook error', { error });
    return { statusCode: 500, body: 'Internal error' };
  }
};

/**
 * POST /ac/biometric/process-punches
 * Process pending punches into attendance records (scheduled job)
 */
export const processPunches = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN],
  async (_event, _ctx, auth) => {
    const pk = Keys.tenantPK(auth.tenantId);

    // Get unprocessed punches from today
    const today = new Date().toISOString().split('T')[0];
    const punches = await queryAllItems(pk, 'AC_BIOMETRIC_PUNCH#', {
      filterExpression: 'begins_with(punchTime, :today) AND processed = :processed',
      expressionAttributeValues: { ':today': today, ':processed': false },
    });

    const processed = [];

    // Group punches by person
    const byPerson: Record<string, any[]> = {};
    for (const punch of punches as any[]) {
      if (!byPerson[punch.personId]) byPerson[punch.personId] = [];
      byPerson[punch.personId].push(punch);
    }

    // Process each person
    for (const [personId, personPunches] of Object.entries(byPerson)) {
      // Sort by time
      personPunches.sort((a: any, b: any) => a.punchTime.localeCompare(b.punchTime));

      // Get first 'in' and last 'out'
      const firstIn = personPunches.find((p: any) => p.punchType === 'in');
      const lastOut = [...personPunches].reverse().find((p: any) => p.punchType === 'out');

      if (firstIn) {
        // Create or update attendance record
        const attendanceId = uid();
        const attendance = {
          PK: pk,
          SK: `AC_ATTENDANCE#${today}#${firstIn.batchId || 'general'}`,
          GSI1PK: `AC_ATTENDANCE_BY_STUDENT#${auth.tenantId}#${personId}`,
          GSI1SK: today,
          id: attendanceId,
          personId,
          personType: firstIn.personType,
          date: today,
          status: 'present',
          checkIn: firstIn.punchTime,
          checkOut: lastOut?.punchTime || null,
          method: 'biometric',
          deviceId: firstIn.deviceId,
          createdAt: now(),
        };

        await putItem(attendance);
        processed.push(attendance);
      }

      // Mark punches as processed
      for (const punch of personPunches) {
        await updateItem(pk, punch.SK, {
          updateExpression: 'SET processed = :processed',
          expressionAttributeValues: { ':processed': true },
        });
      }
    }

    return response.success({
      processed: processed.length,
      totalPunches: punches.length,
      date: today,
    });
  },
  AC_BIOMETRIC_OPTS,
);

/**
 * GET /ac/biometric/punches
 * List biometric punches
 */
export const listPunches = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);

    let punches = await queryAllItems(pk, 'AC_BIOMETRIC_PUNCH#');

    if (p.personId) punches = punches.filter((punch: any) => punch.personId === p.personId);
    if (p.deviceId) punches = punches.filter((punch: any) => punch.deviceId === p.deviceId);
    if (p.date) punches = punches.filter((punch: any) => punch.punchTime.startsWith(p.date));

    // Sort by time desc
    punches.sort((a: any, b: any) => (b.punchTime || '').localeCompare(a.punchTime || ''));

    return response.success(punches);
  },
  AC_BIOMETRIC_OPTS,
);

// ============================================================================
// UTILITIES
// ============================================================================

function hashTemplate(templateData: string): string {
  // In production, use proper hashing (e.g., bcrypt or SHA-256)
  // This is a simplified version - store only hash, never raw biometric data
  return require('crypto').createHash('sha256').update(templateData).digest('hex').substring(0, 32);
}

function getTenantIdFromApiKey(apiKey: string): string {
  // In production, lookup API key in DynamoDB to get tenantId
  // This is a placeholder - implement proper API key validation
  return 'TENANT_ID_FROM_API_KEY'; // Replace with actual lookup
}
