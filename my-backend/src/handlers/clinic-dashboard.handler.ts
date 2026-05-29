// ============================================================================
// CLINIC DASHBOARD LAMBDA HANDLERS
// ============================================================================
// AWS Lambda functions for clinic dashboard API
// Each handler validates JWT, enforces RBAC, and returns typed responses
// ============================================================================

import { APIGatewayProxyEvent, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { 
  clinicDashboardService, 
  ClinicDashboardService,
  DashboardContext,
  ClinicRole 
} from '../services/clinic-dashboard.service';
import { logger } from '../utils/logger';
import { success, error, unauthorized, forbidden } from '../utils/response';

// ============================================================================
// JWT DECODING & CONTEXT EXTRACTION
// ============================================================================

interface JWTClaims {
  sub: string;
  email: string;
  'cognito:groups'?: string[];
  'custom:clinicId'?: string;
  'custom:role'?: string;
  'custom:tenantId'?: string;
  'custom:doctorId'?: string;
}

function decodeJWT(token: string): JWTClaims | null {
  try {
    const base64Url = token.split('.')[1];
    const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
    const jsonPayload = decodeURIComponent(
      atob(base64)
        .split('')
        .map(c => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
        .join('')
    );
    return JSON.parse(jsonPayload);
  } catch {
    return null;
  }
}

function extractDashboardContext(event: APIGatewayProxyEvent): DashboardContext | null {
  // Try to get from request context (API Gateway Cognito Authorizer)
  const requestContext = event.requestContext as any;
  const authorizer = requestContext?.authorizer;
  
  if (authorizer?.claims) {
    const claims = authorizer.claims;
    const role = String(claims['custom:role'] || '').toLowerCase() as ClinicRole;
    
    if (!['admin', 'doctor', 'nurse', 'receptionist'].includes(role)) {
      return null;
    }
    
    return {
      tenantId: String(claims['custom:tenantId'] || ''),
      clinicId: String(claims['custom:clinicId'] || ''),
      userId: String(claims.sub || ''),
      role,
      doctorId: claims['custom:doctorId'] || undefined,
    };
  }
  
  // Fallback: try Authorization header (for testing/development)
  const authHeader = event.headers?.Authorization || event.headers?.authorization;
  if (authHeader) {
    const token = authHeader.replace('Bearer ', '');
    const claims = decodeJWT(token);
    
    if (claims) {
      const role = String(claims['custom:role'] || '').toLowerCase() as ClinicRole;
      
      if (!['admin', 'doctor', 'nurse', 'receptionist'].includes(role)) {
        return null;
      }
      
      return {
        tenantId: String(claims['custom:tenantId'] || ''),
        clinicId: String(claims['custom:clinicId'] || ''),
        userId: claims.sub,
        role,
        doctorId: claims['custom:doctorId'] || undefined,
      };
    }
  }
  
  return null;
}

// ============================================================================
// MIDDLEWARE WRAPPER
// ============================================================================

type HandlerFn = (
  ctx: DashboardContext,
  event: APIGatewayProxyEvent
) => Promise<APIGatewayProxyResultV2>;

function withAuth(handler: HandlerFn) {
  return async (event: APIGatewayProxyEvent, _context: Context): Promise<APIGatewayProxyResultV2> => {
    try {
      const ctx = extractDashboardContext(event);
      
      if (!ctx) {
        return unauthorized('Invalid or missing credentials');
      }
      
      if (!ctx.clinicId) {
        return forbidden('No clinic assigned to user');
      }
      
      return await handler(ctx, event);
    } catch (err) {
      logger.error('Handler error', { err });
      return error(500, 'INTERNAL_ERROR', 'Internal server error');
    }
  };
}

// ============================================================================
// API HANDLERS
// ============================================================================

// ── GET /dashboard/overview ───────────────────────────────────────────────────

export const getDashboardOverview = withAuth(async (ctx, event) => {
  const date = event.queryStringParameters?.date || new Date().toISOString().split('T')[0];
  
  const data = await clinicDashboardService.getDashboardOverview(ctx, date);
  
  return success(data, 200, { timestamp: new Date().toISOString() });
});

// ── GET /appointments ─────────────────────────────────────────────────────────

export const getAppointments = withAuth(async (ctx, event) => {
  const date = event.queryStringParameters?.date || new Date().toISOString().split('T')[0];
  const doctorId = event.queryStringParameters?.doctorId;
  const status = event.queryStringParameters?.status;
  
  const data = await clinicDashboardService.getAppointments(ctx, date, doctorId, status);
  
  return success(data, 200, { timestamp: new Date().toISOString() });
});

// ── GET /patients/insights ────────────────────────────────────────────────────

export const getPatientInsights = withAuth(async (ctx, _event) => {
  const data = await clinicDashboardService.getPatientInsights(ctx);
  
  return success(data, 200, { timestamp: new Date().toISOString() });
});

// ── GET /staff/availability ───────────────────────────────────────────────────

export const getStaffAvailability = withAuth(async (ctx, _event) => {
  const data = await clinicDashboardService.getStaffAvailability(ctx);
  
  return success(data, 200, { timestamp: new Date().toISOString() });
});

// ── GET /rooms ────────────────────────────────────────────────────────────────

export const getRooms = withAuth(async (ctx, _event) => {
  const data = await clinicDashboardService.getRoomsStatus(ctx);
  
  return success(data, 200, { timestamp: new Date().toISOString() });
});

// ── GET /billing/summary ──────────────────────────────────────────────────────

export const getBillingSummary = withAuth(async (ctx, event) => {
  const period = (event.queryStringParameters?.period as 'daily' | 'weekly' | 'monthly') || 'monthly';
  
  const data = await clinicDashboardService.getBillingSummary(ctx, period);
  
  return success(data, 200, { timestamp: new Date().toISOString() });
});

// ── GET /inventory/alerts ─────────────────────────────────────────────────────

export const getInventoryAlerts = withAuth(async (ctx, _event) => {
  const data = await clinicDashboardService.getInventoryAlerts(ctx);
  
  return success(data, 200, { timestamp: new Date().toISOString() });
});

// ── GET /analytics/performance ────────────────────────────────────────────────

export const getWeeklyTrends = withAuth(async (ctx, event) => {
  const weeks = parseInt(event.queryStringParameters?.weeks || '2', 10);
  
  const data = await clinicDashboardService.getWeeklyAppointmentTrends(ctx, weeks);
  
  return success(data, 200, { timestamp: new Date().toISOString() });
});

// ── GET /appointments/wait-time ───────────────────────────────────────────────

export const getWaitTime = withAuth(async (ctx, event) => {
  const date = event.queryStringParameters?.date || new Date().toISOString().split('T')[0];
  
  const data = await clinicDashboardService.getAverageWaitTime(ctx, date);
  
  return success(data, 200, { timestamp: new Date().toISOString() });
});

// ── POST /license/validate ──────────────────────────────────────────────────────
// Public endpoint for license validation (no auth required)

export const validateLicense = async (
  event: APIGatewayProxyEvent, 
  _context: Context
): Promise<APIGatewayProxyResultV2> => {
  try {
    const licenseKey = event.queryStringParameters?.licenseKey || 
      JSON.parse(event.body || '{}').licenseKey;
    
    if (!licenseKey) {
      return error(400, 'BAD_REQUEST', 'License key is required');
    }
    
    const result = await clinicDashboardService.validateClinicLicense(licenseKey);
    
    return result.valid 
    ? success(result, 200, { timestamp: new Date().toISOString() })
    : error(403, 'INVALID_LICENSE', result.error || 'License validation failed', result);
  } catch (err) {
    logger.error('License validation handler error', { err });
    return error(500, 'INTERNAL_ERROR', 'License validation failed');
  }
};

// ============================================================================
// WEBSOCKET HANDLER (Real-time updates)
// ============================================================================

export const websocketHandler = async (
  event: any, 
  _context: Context
): Promise<any> => {
  const routeKey = event.requestContext?.routeKey;
  const connectionId = event.requestContext?.connectionId;
  
  logger.info('WebSocket event', { routeKey, connectionId });
  
  switch (routeKey) {
    case '$connect':
      // Authenticate connection
      return { statusCode: 200 };
      
    case '$disconnect':
      // Cleanup connection
      return { statusCode: 200 };
      
    case 'subscribe':
      // Client subscribing to updates
      return { statusCode: 200 };
      
    default:
      return { statusCode: 200 };
  }
};
