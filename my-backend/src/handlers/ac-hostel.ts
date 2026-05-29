// ============================================================================
// ACADEMIC COACHING — HOSTEL MANAGEMENT MODULE
// ============================================================================
// Rooms, beds, student allocation, fees, attendance
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

const AC_HOSTEL_OPTS = {
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
// HOSTELS
// ============================================================================

/**
 * GET /ac/hostels
 * List hostels
 */
export const listHostels = authorizedHandler(
  [],
  async (_event, _ctx, auth) => {
    const pk = Keys.tenantPK(auth.tenantId);
    const hostels = await queryAllItems(pk, 'AC_HOSTEL#');
    return response.success(hostels);
  },
  AC_HOSTEL_OPTS,
);

/**
 * POST /ac/hostels
 * Create hostel
 */
export const createHostel = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { name, address, wardenId, contactPhone, totalRooms, totalBeds } = body;

    const id = uid();
    const pk = Keys.tenantPK(auth.tenantId);
    const ts = now();

    const hostel = {
      PK: pk,
      SK: `AC_HOSTEL#${id}`,
      id,
      name,
      address,
      wardenId,
      contactPhone,
      totalRooms: totalRooms || 0,
      totalBeds: totalBeds || 0,
      occupiedBeds: 0,
      availableBeds: totalBeds || 0,
      isActive: true,
      createdAt: ts,
      updatedAt: ts,
    };

    await putItem(hostel);
    return response.success(hostel, 201);
  },
  AC_HOSTEL_OPTS,
);

/**
 * PUT /ac/hostels/{id}
 * Update hostel
 */
export const updateHostel = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Hostel ID required');

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const pk = Keys.tenantPK(auth.tenantId);

    const ts = now();
    await updateItem(pk, `AC_HOSTEL#${id}`, {
      updateExpression: 'SET #updates = :updates, #updatedAt = :updatedAt',
      expressionAttributeNames: { '#updates': 'updates', '#updatedAt': 'updatedAt' },
      expressionAttributeValues: { ':updates': body, ':updatedAt': ts },
    });

    return response.success({ id, ...body, updatedAt: ts });
  },
  AC_HOSTEL_OPTS,
);

// ============================================================================
// ROOMS
// ============================================================================

/**
 * GET /ac/hostels/rooms
 * List rooms
 */
export const listRooms = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);

    let rooms = await queryAllItems(pk, 'AC_ROOM#');

    if (p.hostelId) rooms = rooms.filter((r: any) => r.hostelId === p.hostelId);
    if (p.roomType) rooms = rooms.filter((r: any) => r.roomType === p.roomType);
    if (p.available === 'true') rooms = rooms.filter((r: any) => r.availableBeds > 0);

    return response.success(rooms);
  },
  AC_HOSTEL_OPTS,
);

/**
 * POST /ac/hostels/rooms
 * Create room
 */
export const createRoom = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { hostelId, roomNumber, roomType, floor, totalBeds, amenities, feePaisa } = body;

    const pk = Keys.tenantPK(auth.tenantId);
    const id = uid();
    const ts = now();

    const room = {
      PK: pk,
      SK: `AC_ROOM#${id}`,
      GSI1PK: `AC_ROOM_BY_HOSTEL#${auth.tenantId}#${hostelId}`,
      GSI1SK: roomNumber,
      id,
      hostelId,
      roomNumber,
      roomType: roomType || 'standard',
      floor: floor || 1,
      totalBeds: totalBeds || 2,
      occupiedBeds: 0,
      availableBeds: totalBeds || 2,
      amenities: amenities || [],
      feePaisa: feePaisa || 0,
      isActive: true,
      createdAt: ts,
      updatedAt: ts,
    };

    await putItem(room);

    // Update hostel bed count
    await updateItem(pk, `AC_HOSTEL#${hostelId}`, {
      updateExpression: 'SET #totalBeds = if_not_exists(#totalBeds, :zero) + :beds, #availableBeds = if_not_exists(#availableBeds, :zero) + :beds',
      expressionAttributeNames: { '#totalBeds': 'totalBeds', '#availableBeds': 'availableBeds' },
      expressionAttributeValues: { ':beds': totalBeds || 2, ':zero': 0 },
    });

    return response.success(room, 201);
  },
  AC_HOSTEL_OPTS,
);

// ============================================================================
// ALLOCATION
// ============================================================================

/**
 * POST /ac/hostels/allocate
 * Allocate student to room
 */
export const allocateStudent = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { studentId, roomId, bedNumber, fromDate, toDate, feePaisa } = body;

    const pk = Keys.tenantPK(auth.tenantId);

    // Check student
    const student = await getItem(pk, Keys.acStudentSK(studentId));
    if (!student) return response.notFound('Student not found');

    // Check room
    const room = await getItem<any>(pk, `AC_ROOM#${roomId}`);
    if (!room) return response.notFound('Room not found');
    if (room.availableBeds <= 0) return response.error(400, 'ROOM_FULL', 'No beds available');

    // Check existing allocation
    const existing = await queryAllItems(pk, 'AC_HOSTEL_ALLOCATION#', {
      filterExpression: 'studentId = :studentId AND #status = :status',
      expressionAttributeNames: { '#status': 'status' },
      expressionAttributeValues: { ':studentId': studentId, ':status': 'active' },
    });

    if (existing.length > 0) {
      return response.error(400, 'ALREADY_ALLOCATED', 'Student already has an active allocation');
    }

    const id = uid();
    const ts = now();

    const allocation = {
      PK: pk,
      SK: `AC_HOSTEL_ALLOCATION#${id}`,
      GSI1PK: `AC_ALLOCATION_BY_ROOM#${auth.tenantId}#${roomId}`,
      GSI1SK: ts,
      id,
      studentId,
      roomId,
      hostelId: room.hostelId,
      bedNumber,
      fromDate,
      toDate,
      feePaisa: feePaisa || room.feePaisa,
      status: 'active',
      createdAt: ts,
      updatedAt: ts,
    };

    await putItem(allocation);

    // Update room occupancy
    await updateItem(pk, `AC_ROOM#${roomId}`, {
      updateExpression: 'SET #occupiedBeds = #occupiedBeds + :one, #availableBeds = #availableBeds - :one',
      expressionAttributeNames: { '#occupiedBeds': 'occupiedBeds', '#availableBeds': 'availableBeds' },
      expressionAttributeValues: { ':one': 1 },
    });

    // Update hostel occupancy
    await updateItem(pk, `AC_HOSTEL#${room.hostelId}`, {
      updateExpression: 'SET #occupiedBeds = if_not_exists(#occupiedBeds, :zero) + :one, #availableBeds = #availableBeds - :one',
      expressionAttributeNames: { '#occupiedBeds': 'occupiedBeds', '#availableBeds': 'availableBeds' },
      expressionAttributeValues: { ':one': 1, ':zero': 0 },
    });

    return response.success(allocation, 201);
  },
  AC_HOSTEL_OPTS,
);

/**
 * POST /ac/hostels/deallocate/{allocationId}
 * Deallocate student
 */
export const deallocateStudent = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const allocationId = event.pathParameters?.id;
    if (!allocationId) return response.badRequest('Allocation ID required');

    const pk = Keys.tenantPK(auth.tenantId);
    const allocation = await getItem<any>(pk, `AC_HOSTEL_ALLOCATION#${allocationId}`);
    
    if (!allocation) return response.notFound('Allocation not found');

    const ts = now();

    await updateItem(pk, `AC_HOSTEL_ALLOCATION#${allocationId}`, {
      updateExpression: 'SET #status = :status, #deallocatedAt = :deallocatedAt, #updatedAt = :updatedAt',
      expressionAttributeNames: { '#status': 'status', '#deallocatedAt': 'deallocatedAt', '#updatedAt': 'updatedAt' },
      expressionAttributeValues: { ':status': 'inactive', ':deallocatedAt': ts, ':updatedAt': ts },
    });

    // Update room
    await updateItem(pk, `AC_ROOM#${allocation.roomId}`, {
      updateExpression: 'SET #occupiedBeds = #occupiedBeds - :one, #availableBeds = #availableBeds + :one',
      expressionAttributeNames: { '#occupiedBeds': 'occupiedBeds', '#availableBeds': 'availableBeds' },
      expressionAttributeValues: { ':one': 1 },
    });

    // Update hostel
    await updateItem(pk, `AC_HOSTEL#${allocation.hostelId}`, {
      updateExpression: 'SET #occupiedBeds = #occupiedBeds - :one, #availableBeds = #availableBeds + :one',
      expressionAttributeNames: { '#occupiedBeds': 'occupiedBeds', '#availableBeds': 'availableBeds' },
      expressionAttributeValues: { ':one': 1 },
    });

    return response.success({ id: allocationId, deallocated: true });
  },
  AC_HOSTEL_OPTS,
);

/**
 * GET /ac/hostels/allocations
 * List allocations
 */
export const listAllocations = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);

    let allocations = await queryAllItems(pk, 'AC_HOSTEL_ALLOCATION#');

    if (p.hostelId) allocations = allocations.filter((a: any) => a.hostelId === p.hostelId);
    if (p.roomId) allocations = allocations.filter((a: any) => a.roomId === p.roomId);
    if (p.studentId) allocations = allocations.filter((a: any) => a.studentId === p.studentId);
    if (p.status) allocations = allocations.filter((a: any) => a.status === p.status);

    return response.success(allocations);
  },
  AC_HOSTEL_OPTS,
);

/**
 * GET /ac/hostels/dashboard
 * Hostel dashboard
 */
export const getHostelDashboard = authorizedHandler(
  [],
  async (_event, _ctx, auth) => {
    const pk = Keys.tenantPK(auth.tenantId);

    const [hostels, rooms, allocations] = await Promise.all([
      queryAllItems(pk, 'AC_HOSTEL#'),
      queryAllItems(pk, 'AC_ROOM#'),
      queryAllItems(pk, 'AC_HOSTEL_ALLOCATION#'),
    ]);

    const stats = {
      totalHostels: hostels.length,
      totalRooms: rooms.length,
      totalBeds: rooms.reduce((sum: number, r: any) => sum + (r.totalBeds || 0), 0),
      occupiedBeds: rooms.reduce((sum: number, r: any) => sum + (r.occupiedBeds || 0), 0),
      availableBeds: rooms.reduce((sum: number, r: any) => sum + (r.availableBeds || 0), 0),
      activeAllocations: allocations.filter((a: any) => a.status === 'active').length,
      occupancyRate: 0,
    };

    stats.occupancyRate = stats.totalBeds > 0 
      ? Math.round((stats.occupiedBeds / stats.totalBeds) * 100) 
      : 0;

    return response.success(stats);
  },
  AC_HOSTEL_OPTS,
);
