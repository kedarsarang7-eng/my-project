// ============================================================================
// ACADEMIC COACHING — TRANSPORT MANAGEMENT MODULE
// ============================================================================
// Routes, vehicles, drivers, student assignment, notifications
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
  deleteItem,
  queryAllItems,
} from '../config/dynamodb.config';
import { z } from 'zod';
import {
  CreateRouteSchema,
  CreateVehicleSchema,
  AssignStudentToRouteSchema,
  CreateDriverSchema,
} from '../schemas/academic-coaching.schema';

const AC_TRANSPORT_OPTS = {
  requiredBusinessType: BusinessType.SCHOOL_ERP,
  requiredFeature: FeatureKey.AC_STUDENT_MANAGEMENT,
};

function uid(): string {
  return Math.random().toString(36).substring(2, 18).toUpperCase();
}

function now(): string {
  return new Date().toISOString();
}

// ============================================================================
// ROUTES
// ============================================================================

/**
 * GET /ac/transport/routes
 * List all routes
 */
export const listRoutes = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);

    let routes = await queryAllItems(pk, 'AC_ROUTE#');

    if (p.isActive) {
      routes = routes.filter((r: any) => r.isActive === (p.isActive === 'true'));
    }

    // Sort by name
    routes.sort((a: any, b: any) => (a.name || '').localeCompare(b.name || ''));

    return response.success(routes);
  },
  AC_TRANSPORT_OPTS,
);

/**
 * GET /ac/transport/routes/{id}
 * Get route with stops and assigned students
 */
export const getRoute = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Route ID required');

    const pk = Keys.tenantPK(auth.tenantId);
    const route = await getItem(pk, `AC_ROUTE#${id}`);
    
    if (!route) return response.notFound('Route not found');

    // Get assigned students
    const assignments = await queryAllItems(pk, 'AC_ROUTE_ASSIGNMENT#', {
      filterExpression: 'routeId = :routeId AND #status = :status',
      expressionAttributeNames: { '#status': 'status' },
      expressionAttributeValues: { ':routeId': id, ':status': 'active' },
    });

    return response.success({ ...route, assignments: assignments.length });
  },
  AC_TRANSPORT_OPTS,
);

/**
 * POST /ac/transport/routes
 * Create route
 */
export const createRoute = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const validated = CreateRouteSchema.parse(body);

    const id = uid();
    const pk = Keys.tenantPK(auth.tenantId);
    const ts = now();

    const route = {
      PK: pk,
      SK: `AC_ROUTE#${id}`,
      id,
      ...validated,
      createdAt: ts,
      updatedAt: ts,
    };

    await putItem(route);

    logger.info('Route created', { tenantId: auth.tenantId, routeId: id });

    return response.success(route, 201);
  },
  AC_TRANSPORT_OPTS,
);

/**
 * PUT /ac/transport/routes/{id}
 * Update route
 */
export const updateRoute = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Route ID required');

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const updates = body;

    const pk = Keys.tenantPK(auth.tenantId);
    const existing = await getItem<any>(pk, `AC_ROUTE#${id}`);
    
    if (!existing) return response.notFound('Route not found');

    const ts = now();

    await updateItem(pk, `AC_ROUTE#${id}`, {
      updateExpression: 'SET #updates = :updates, #updatedAt = :updatedAt',
      expressionAttributeNames: { '#updates': 'updates', '#updatedAt': 'updatedAt' },
      expressionAttributeValues: { ':updates': updates, ':updatedAt': ts },
    });

    return response.success({ id, ...updates, updatedAt: ts });
  },
  AC_TRANSPORT_OPTS,
);

/**
 * DELETE /ac/transport/routes/{id}
 * Delete route
 */
export const deleteRoute = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Route ID required');

    const pk = Keys.tenantPK(auth.tenantId);
    const existing = await getItem<any>(pk, `AC_ROUTE#${id}`);
    
    if (!existing) return response.notFound('Route not found');

    // Check if students assigned
    const assignments = await queryAllItems(pk, 'AC_ROUTE_ASSIGNMENT#', {
      filterExpression: 'routeId = :routeId AND #status = :status',
      expressionAttributeNames: { '#status': 'status' },
      expressionAttributeValues: { ':routeId': id, ':status': 'active' },
    });

    if (assignments.length > 0) {
      return response.error(400, 'ROUTE_IN_USE', 'Cannot delete route with assigned students');
    }

    await deleteItem(pk, `AC_ROUTE#${id}`);

    return response.success({ id, deleted: true });
  },
  AC_TRANSPORT_OPTS,
);

// ============================================================================
// VEHICLES
// ============================================================================

/**
 * GET /ac/transport/vehicles
 * List vehicles
 */
export const listVehicles = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);

    let vehicles = await queryAllItems(pk, 'AC_VEHICLE#');

    if (p.isActive) {
      vehicles = vehicles.filter((v: any) => v.isActive === (p.isActive === 'true'));
    }
    if (p.vehicleType) {
      vehicles = vehicles.filter((v: any) => v.vehicleType === p.vehicleType);
    }

    return response.success(vehicles);
  },
  AC_TRANSPORT_OPTS,
);

/**
 * POST /ac/transport/vehicles
 * Create vehicle
 */
export const createVehicle = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const validated = CreateVehicleSchema.parse(body);

    const id = uid();
    const pk = Keys.tenantPK(auth.tenantId);
    const ts = now();

    const vehicle = {
      PK: pk,
      SK: `AC_VEHICLE#${id}`,
      id,
      ...validated,
      assignedRouteId: null,
      createdAt: ts,
      updatedAt: ts,
    };

    await putItem(vehicle);

    return response.success(vehicle, 201);
  },
  AC_TRANSPORT_OPTS,
);

/**
 * PUT /ac/transport/vehicles/{id}
 * Update vehicle
 */
export const updateVehicle = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Vehicle ID required');

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const updates = body;

    const pk = Keys.tenantPK(auth.tenantId);
    const existing = await getItem<any>(pk, `AC_VEHICLE#${id}`);
    
    if (!existing) return response.notFound('Vehicle not found');

    const ts = now();

    await updateItem(pk, `AC_VEHICLE#${id}`, {
      updateExpression: 'SET #updates = :updates, #updatedAt = :updatedAt',
      expressionAttributeNames: { '#updates': 'updates', '#updatedAt': 'updatedAt' },
      expressionAttributeValues: { ':updates': updates, ':updatedAt': ts },
    });

    return response.success({ id, ...updates, updatedAt: ts });
  },
  AC_TRANSPORT_OPTS,
);

/**
 * DELETE /ac/transport/vehicles/{id}
 * Delete vehicle
 */
export const deleteVehicle = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Vehicle ID required');

    const pk = Keys.tenantPK(auth.tenantId);
    const existing = await getItem<any>(pk, `AC_VEHICLE#${id}`);
    
    if (!existing) return response.notFound('Vehicle not found');

    await deleteItem(pk, `AC_VEHICLE#${id}`);

    return response.success({ id, deleted: true });
  },
  AC_TRANSPORT_OPTS,
);

// ============================================================================
// DRIVERS
// ============================================================================

/**
 * GET /ac/transport/drivers
 * List drivers
 */
export const listDrivers = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);

    let drivers = await queryAllItems(pk, 'AC_DRIVER#');

    if (p.isActive) {
      drivers = drivers.filter((d: any) => d.isActive === (p.isActive === 'true'));
    }

    return response.success(drivers);
  },
  AC_TRANSPORT_OPTS,
);

/**
 * POST /ac/transport/drivers
 * Create driver
 */
export const createDriver = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const validated = CreateDriverSchema.parse(body);

    const id = uid();
    const pk = Keys.tenantPK(auth.tenantId);
    const ts = now();

    const driver = {
      PK: pk,
      SK: `AC_DRIVER#${id}`,
      id,
      ...validated,
      assignedVehicleId: null,
      createdAt: ts,
      updatedAt: ts,
    };

    await putItem(driver);

    return response.success(driver, 201);
  },
  AC_TRANSPORT_OPTS,
);

/**
 * PUT /ac/transport/drivers/{id}
 * Update driver
 */
export const updateDriver = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Driver ID required');

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const updates = body;

    const pk = Keys.tenantPK(auth.tenantId);
    const existing = await getItem<any>(pk, `AC_DRIVER#${id}`);
    
    if (!existing) return response.notFound('Driver not found');

    const ts = now();

    await updateItem(pk, `AC_DRIVER#${id}`, {
      updateExpression: 'SET #updates = :updates, #updatedAt = :updatedAt',
      expressionAttributeNames: { '#updates': 'updates', '#updatedAt': 'updatedAt' },
      expressionAttributeValues: { ':updates': updates, ':updatedAt': ts },
    });

    return response.success({ id, ...updates, updatedAt: ts });
  },
  AC_TRANSPORT_OPTS,
);

/**
 * DELETE /ac/transport/drivers/{id}
 * Delete driver
 */
export const deleteDriver = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Driver ID required');

    const pk = Keys.tenantPK(auth.tenantId);
    const existing = await getItem<any>(pk, `AC_DRIVER#${id}`);
    
    if (!existing) return response.notFound('Driver not found');

    await deleteItem(pk, `AC_DRIVER#${id}`);

    return response.success({ id, deleted: true });
  },
  AC_TRANSPORT_OPTS,
);

// ============================================================================
// STUDENT ASSIGNMENT
// ============================================================================

/**
 * POST /ac/transport/assignments
 * Assign student to route
 */
export const assignStudent = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const validated = AssignStudentToRouteSchema.parse(body);

    const pk = Keys.tenantPK(auth.tenantId);

    // Verify student exists
    const student = await getItem(pk, Keys.acStudentSK(validated.studentId));
    if (!student) return response.notFound('Student not found');

    // Verify route exists
    const route = await getItem(pk, `AC_ROUTE#${validated.routeId}`);
    if (!route) return response.notFound('Route not found');

    // Check if stop exists in route
    const stopExists = (route as any).stops?.some((s: any) => s.id === validated.stopId);
    if (!stopExists) return response.error(400, 'INVALID_STOP', 'Stop not found in route');

    // Check for existing assignment
    const existing = await queryAllItems(pk, 'AC_ROUTE_ASSIGNMENT#', {
      filterExpression: 'studentId = :studentId AND #status = :status',
      expressionAttributeNames: { '#status': 'status' },
      expressionAttributeValues: { ':studentId': validated.studentId, ':status': 'active' },
    });

    if (existing.length > 0) {
      // Update existing assignment
      const assignmentId = (existing[0] as any).id;
      await updateItem(pk, `AC_ROUTE_ASSIGNMENT#${assignmentId}`, {
        updateExpression: 'SET #routeId = :routeId, #stopId = :stopId, #pickup = :pickup, #drop = :drop, #updatedAt = :updatedAt',
        expressionAttributeNames: {
          '#routeId': 'routeId',
          '#stopId': 'stopId',
          '#pickup': 'pickup',
          '#drop': 'drop',
          '#updatedAt': 'updatedAt',
        },
        expressionAttributeValues: {
          ':routeId': validated.routeId,
          ':stopId': validated.stopId,
          ':pickup': validated.pickup,
          ':drop': validated.drop,
          ':updatedAt': now(),
        },
      });
      return response.success({ id: assignmentId, updated: true });
    }

    // Create new assignment
    const id = uid();
    const ts = now();

    const assignment = {
      PK: pk,
      SK: `AC_ROUTE_ASSIGNMENT#${id}`,
      GSI1PK: `AC_ASSIGNMENT_BY_ROUTE#${auth.tenantId}#${validated.routeId}`,
      GSI1SK: ts,
      id,
      ...validated,
      status: 'active',
      createdAt: ts,
      updatedAt: ts,
    };

    await putItem(assignment);

    logger.info('Student assigned to route', { tenantId: auth.tenantId, studentId: validated.studentId, routeId: validated.routeId });

    return response.success(assignment, 201);
  },
  AC_TRANSPORT_OPTS,
);

/**
 * DELETE /ac/transport/assignments/{id}
 * Remove student from route
 */
export const removeAssignment = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Assignment ID required');

    const pk = Keys.tenantPK(auth.tenantId);
    const existing = await getItem<any>(pk, `AC_ROUTE_ASSIGNMENT#${id}`);
    
    if (!existing) return response.notFound('Assignment not found');

    await updateItem(pk, `AC_ROUTE_ASSIGNMENT#${id}`, {
      updateExpression: 'SET #status = :status, #updatedAt = :updatedAt',
      expressionAttributeNames: { '#status': 'status', '#updatedAt': 'updatedAt' },
      expressionAttributeValues: { ':status': 'inactive', ':updatedAt': now() },
    });

    return response.success({ id, removed: true });
  },
  AC_TRANSPORT_OPTS,
);

/**
 * GET /ac/transport/student/{studentId}
 * Get student transport details
 */
export const getStudentTransport = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const studentId = event.pathParameters?.studentId;
    if (!studentId) return response.badRequest('Student ID required');

    const pk = Keys.tenantPK(auth.tenantId);

    const assignments = await queryAllItems(pk, 'AC_ROUTE_ASSIGNMENT#', {
      filterExpression: 'studentId = :studentId AND #status = :status',
      expressionAttributeNames: { '#status': 'status' },
      expressionAttributeValues: { ':studentId': studentId, ':status': 'active' },
    });

    if (assignments.length === 0) {
      return response.success({ assigned: false });
    }

    const assignment = assignments[0];
    const route = await getItem(pk, `AC_ROUTE#${(assignment as any).routeId}`);
    const stop = (route as any)?.stops?.find((s: any) => s.id === (assignment as any).stopId);

    return response.success({
      assigned: true,
      assignment,
      route: route ? { id: (route as any).id, name: (route as any).name, stops: (route as any).stops } : null,
      stop,
    });
  },
  AC_TRANSPORT_OPTS,
);

/**
 * GET /ac/transport/dashboard
 * Transport dashboard
 */
export const getTransportDashboard = authorizedHandler(
  [],
  async (_event, _ctx, auth) => {
    const pk = Keys.tenantPK(auth.tenantId);

    const [routes, vehicles, drivers, assignments] = await Promise.all([
      queryAllItems(pk, 'AC_ROUTE#'),
      queryAllItems(pk, 'AC_VEHICLE#'),
      queryAllItems(pk, 'AC_DRIVER#'),
      queryAllItems(pk, 'AC_ROUTE_ASSIGNMENT#'),
    ]);

    const stats = {
      totalRoutes: routes.length,
      activeRoutes: routes.filter((r: any) => r.isActive).length,
      totalVehicles: vehicles.length,
      activeVehicles: vehicles.filter((v: any) => v.isActive).length,
      totalDrivers: drivers.length,
      activeDrivers: drivers.filter((d: any) => d.isActive).length,
      totalAssignments: assignments.filter((a: any) => a.status === 'active').length,
      vehiclesNeedingRenewal: vehicles.filter((v: any) => {
        if (!v.insuranceExpiry) return false;
        const daysUntil = Math.ceil((new Date(v.insuranceExpiry).getTime() - Date.now()) / (1000 * 60 * 60 * 24));
        return daysUntil <= 30;
      }).length,
    };

    return response.success(stats);
  },
  AC_TRANSPORT_OPTS,
);
