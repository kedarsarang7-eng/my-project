// ============================================================================
// p28(c) RBAC tests — unit tests for rbac.ts helpers + handler gate checks
// ============================================================================

import type { APIGatewayProxyEvent } from 'aws-lambda';
import {
  extractClaims,
  hasMinimumRole,
  isSelfOrManager,
  ROLES,
} from '../utils/rbac';

// ── helpers ──────────────────────────────────────────────────────────────────

function makeEvent(claims: Record<string, string> | null): APIGatewayProxyEvent {
  return {
    requestContext: {
      authorizer: claims ? { claims } : undefined,
    },
  } as unknown as APIGatewayProxyEvent;
}

// ── extractClaims ─────────────────────────────────────────────────────────────

describe('extractClaims', () => {
  it('RBAC-01: returns null when authorizer is absent', () => {
    expect(extractClaims(makeEvent(null))).toBeNull();
  });

  it('RBAC-02: returns null when sub is missing', () => {
    expect(extractClaims(makeEvent({ 'custom:role': 'manager' }))).toBeNull();
  });

  it('RBAC-03: extracts sub, staffId, role correctly', () => {
    const claims = extractClaims(makeEvent({
      sub: 'uuid-001',
      'custom:staffId': 'STAFF001',
      'custom:role': 'manager',
    }));
    expect(claims).toEqual({ sub: 'uuid-001', staffId: 'STAFF001', role: 'manager' });
  });

  it('RBAC-04: defaults unknown role to pump_operator', () => {
    const claims = extractClaims(makeEvent({ sub: 'uuid-002', 'custom:role': 'UNKNOWN_ROLE' }));
    expect(claims?.role).toBe(ROLES.PUMP_OPERATOR);
  });

  it('RBAC-05: falls back to pump_operator when custom:role absent', () => {
    const claims = extractClaims(makeEvent({ sub: 'uuid-003' }));
    expect(claims?.role).toBe(ROLES.PUMP_OPERATOR);
  });

  it('RBAC-06: accepts role from plain "role" claim when custom:role absent', () => {
    const claims = extractClaims(makeEvent({ sub: 'uuid-004', role: 'cashier' }));
    expect(claims?.role).toBe(ROLES.CASHIER);
  });

  it('RBAC-07: is case-insensitive for role value', () => {
    const claims = extractClaims(makeEvent({ sub: 'u', 'custom:role': 'MANAGER' }));
    expect(claims?.role).toBe(ROLES.MANAGER);
  });
});

// ── hasMinimumRole ────────────────────────────────────────────────────────────

describe('hasMinimumRole', () => {
  const makeClaims = (role: string) => ({ sub: 'x', staffId: 'S1', role: role as never });

  it('RBAC-08: pump_operator fails manager requirement', () => {
    expect(hasMinimumRole(makeClaims('pump_operator'), ROLES.MANAGER)).toBe(false);
  });

  it('RBAC-09: manager passes manager requirement', () => {
    expect(hasMinimumRole(makeClaims('manager'), ROLES.MANAGER)).toBe(true);
  });

  it('RBAC-10: admin passes manager requirement', () => {
    expect(hasMinimumRole(makeClaims('admin'), ROLES.MANAGER)).toBe(true);
  });

  it('RBAC-11: cashier fails supervisor requirement', () => {
    expect(hasMinimumRole(makeClaims('cashier'), ROLES.SUPERVISOR)).toBe(false);
  });

  it('RBAC-12: supervisor passes supervisor requirement', () => {
    expect(hasMinimumRole(makeClaims('supervisor'), ROLES.SUPERVISOR)).toBe(true);
  });

  it('RBAC-13: pump_operator passes pump_operator requirement (lowest)', () => {
    expect(hasMinimumRole(makeClaims('pump_operator'), ROLES.PUMP_OPERATOR)).toBe(true);
  });
});

// ── isSelfOrManager ───────────────────────────────────────────────────────────

describe('isSelfOrManager', () => {
  it('RBAC-14: pump_operator acting on own staffId is allowed', () => {
    const claims = { sub: 'u', staffId: 'STAFF001', role: ROLES.PUMP_OPERATOR };
    expect(isSelfOrManager(claims, 'STAFF001')).toBe(true);
  });

  it('RBAC-15: pump_operator acting on different staffId is denied', () => {
    const claims = { sub: 'u', staffId: 'STAFF001', role: ROLES.PUMP_OPERATOR };
    expect(isSelfOrManager(claims, 'STAFF999')).toBe(false);
  });

  it('RBAC-16: manager acting on any staffId is allowed', () => {
    const claims = { sub: 'u', staffId: 'STAFF001', role: ROLES.MANAGER };
    expect(isSelfOrManager(claims, 'STAFF999')).toBe(true);
  });

  it('RBAC-17: admin acting on any staffId is allowed', () => {
    const claims = { sub: 'u', staffId: 'STAFF001', role: ROLES.ADMIN };
    expect(isSelfOrManager(claims, 'COMPLETELY_DIFFERENT')).toBe(true);
  });

  it('RBAC-18: supervisor acting on different staffId is denied (below manager threshold)', () => {
    const claims = { sub: 'u', staffId: 'STAFF001', role: ROLES.SUPERVISOR };
    expect(isSelfOrManager(claims, 'STAFF999')).toBe(false);
  });
});

// ── Handler gate integration: processLeaveRequest ────────────────────────────

jest.mock('../utils/dynamodb', () => ({
  getItem: jest.fn(),
  putItem: jest.fn(),
  queryItems: jest.fn(),
  updateItem: jest.fn(),
  transactWriteItems: jest.fn(),
}));

jest.mock('../utils/ulid', () => ({
  generateULID: jest.fn(() => 'ULID-001'),
  getCurrentTimestamp: jest.fn(() => '2026-05-17T09:00:00.000Z'),
  getCurrentDate: jest.fn(() => '2026-05-17'),
  calculateTimeDifferenceMinutes: jest.fn(() => 0),
  calculateHoursBetween: jest.fn(() => 8),
}));

import { handler as processLeaveHandler } from '../handlers/processLeaveRequest';
import { handler as submitLeaveHandler } from '../handlers/submitLeaveRequest';
import { handler as checkInHandler } from '../handlers/staffCheckIn';
import { handler as checkOutHandler } from '../handlers/staffCheckOut';
import { handler as dashboardHandler } from '../handlers/getStaffDashboard';
import { handler as wsConnectHandler } from '../handlers/websocketConnect';
import * as db from '../utils/dynamodb';

const mockGetItem = db.getItem as jest.MockedFunction<typeof db.getItem>;
const mockQueryItems = db.queryItems as jest.MockedFunction<typeof db.queryItems>;

function makeHandlerEvent(
  claims: Record<string, string> | null,
  pathParams: Record<string, string> = {},
  body: object = {},
  queryParams: Record<string, string> = {},
): APIGatewayProxyEvent {
  return {
    httpMethod: 'POST',
    pathParameters: pathParams,
    queryStringParameters: queryParams,
    headers: {},
    body: JSON.stringify(body),
    requestContext: {
      authorizer: claims ? { claims } : undefined,
      connectionId: 'conn-001',
    },
  } as unknown as APIGatewayProxyEvent;
}

const pumpOperatorClaims = { sub: 'uuid-op', 'custom:staffId': 'STAFF001', 'custom:role': 'pump_operator' };
const managerClaims = { sub: 'uuid-mgr', 'custom:staffId': 'MGR001', 'custom:role': 'manager' };
const otherStaffClaims = { sub: 'uuid-other', 'custom:staffId': 'STAFF999', 'custom:role': 'pump_operator' };

// processLeaveRequest —————————————————————————————————————————————————————————

describe('processLeaveRequest RBAC gate', () => {
  it('RBAC-19: pump_operator gets 403', async () => {
    const event = makeHandlerEvent(
      pumpOperatorClaims,
      { leaveId: 'LEAVE001' },
      { action: 'APPROVE' },
      { staffId: 'STAFF001' },
    );
    const res = await processLeaveHandler(event);
    expect(res.statusCode).toBe(403);
  });

  it('RBAC-20: no claims gets 401', async () => {
    const event = makeHandlerEvent(null, { leaveId: 'LEAVE001' }, { action: 'APPROVE' }, { staffId: 'STAFF001' });
    const res = await processLeaveHandler(event);
    expect(res.statusCode).toBe(401);
  });

  it('RBAC-21: manager is allowed through the gate (proceeds to DB lookup)', async () => {
    mockGetItem.mockResolvedValueOnce(null); // leave not found — that's fine, gate passed
    const event = makeHandlerEvent(
      managerClaims,
      { leaveId: 'LEAVE001' },
      { action: 'APPROVE' },
      { staffId: 'STAFF001' },
    );
    const res = await processLeaveHandler(event);
    expect(res.statusCode).toBe(404); // past the RBAC gate, hits DB 404
  });
});

// submitLeaveRequest ——————————————————————————————————————————————————————————

describe('submitLeaveRequest RBAC gate', () => {
  it('RBAC-22: staff cannot submit leave for a different staffId', async () => {
    const event = makeHandlerEvent(
      pumpOperatorClaims, // staffId in claims = STAFF001
      { staffId: 'STAFF999' }, // path param = different staff
      { leaveType: 'CASUAL', fromDate: '2026-06-01', toDate: '2026-06-02', reason: 'test' },
    );
    const res = await submitLeaveHandler(event);
    expect(res.statusCode).toBe(403);
  });

  it('RBAC-23: staff can submit leave for themselves', async () => {
    mockGetItem.mockResolvedValueOnce({
      staffId: 'STAFF001', fullName: 'Ravi', isActive: true, petrolPumpId: 'PUMP01',
    });
    mockQueryItems.mockResolvedValue({ items: [] });
    const futureFrom = new Date();
    futureFrom.setDate(futureFrom.getDate() + 5);
    const futureTo = new Date(futureFrom);
    futureTo.setDate(futureTo.getDate() + 1);
    const fmt = (d: Date) => d.toISOString().split('T')[0];
    const event = makeHandlerEvent(
      pumpOperatorClaims,
      { staffId: 'STAFF001' },
      { leaveType: 'CASUAL', fromDate: fmt(futureFrom), toDate: fmt(futureTo), reason: 'need rest' },
    );
    const res = await submitLeaveHandler(event);
    expect(res.statusCode).toBe(201);
  });

  it('RBAC-24: manager can submit leave on behalf of any staff', async () => {
    mockGetItem.mockResolvedValueOnce({
      staffId: 'STAFF999', fullName: 'Dev', isActive: true, petrolPumpId: 'PUMP01',
    });
    mockQueryItems.mockResolvedValue({ items: [] });
    const futureFrom = new Date();
    futureFrom.setDate(futureFrom.getDate() + 3);
    const futureTo = new Date(futureFrom);
    futureTo.setDate(futureTo.getDate() + 1);
    const fmt = (d: Date) => d.toISOString().split('T')[0];
    const event = makeHandlerEvent(
      managerClaims,
      { staffId: 'STAFF999' },
      { leaveType: 'SICK', fromDate: fmt(futureFrom), toDate: fmt(futureTo), reason: 'ill' },
    );
    const res = await submitLeaveHandler(event);
    expect(res.statusCode).toBe(201);
  });
});

// staffCheckIn RBAC ———————————————————————————————————————————————————————————

describe('staffCheckIn RBAC gate', () => {
  it('RBAC-25: staff checking in for someone else gets 403', async () => {
    mockGetItem.mockResolvedValueOnce({
      staffId: 'STAFF999', fullName: 'X', isActive: true,
      shiftTiming: { start: '09:00', end: '17:00', days: ['MON'] },
      petrolPumpId: 'PUMP01', createdAt: '', updatedAt: '',
    });
    const event = makeHandlerEvent(
      otherStaffClaims, // claims.staffId = STAFF999
      { staffId: 'STAFF001' }, // path = different person
      { stationId: 'PUMP01', scanTimestamp: '2026-05-17T08:00:00.000Z', deviceInfo: { model: 'X', osVersion: '14', appVersion: '1.0' } },
    );
    const res = await checkInHandler(event);
    expect(res.statusCode).toBe(403);
  });

  it('RBAC-26: no claims returns 401 on checkIn', async () => {
    mockGetItem.mockResolvedValueOnce({ staffId: 'STAFF001', isActive: true });
    const event = makeHandlerEvent(
      null,
      { staffId: 'STAFF001' },
      { stationId: 'PUMP01', scanTimestamp: '2026-05-17T08:00:00.000Z', deviceInfo: { model: 'X', osVersion: '14', appVersion: '1.0' } },
    );
    const res = await checkInHandler(event);
    expect(res.statusCode).toBe(401);
  });
});

// staffCheckOut RBAC ——————————————————————————————————————————————————————————

describe('staffCheckOut RBAC gate', () => {
  it('RBAC-27: staff checking out for someone else gets 403', async () => {
    const event = makeHandlerEvent(
      otherStaffClaims, // STAFF999 trying to check out STAFF001
      { staffId: 'STAFF001' },
      { shiftId: 'SHIFT001', stationId: 'PUMP01' },
    );
    const res = await checkOutHandler(event);
    expect(res.statusCode).toBe(403);
  });

  it('RBAC-28: no claims returns 401 on checkOut', async () => {
    const event = makeHandlerEvent(null, { staffId: 'STAFF001' }, { shiftId: 'SHIFT001', stationId: 'PUMP01' });
    const res = await checkOutHandler(event);
    expect(res.statusCode).toBe(401);
  });
});

// getStaffDashboard RBAC ——————————————————————————————————————————————————————

describe('getStaffDashboard RBAC gate', () => {
  it('RBAC-29: staff viewing another staff\'s dashboard gets 403', async () => {
    const event = makeHandlerEvent(
      otherStaffClaims,
      { staffId: 'STAFF001' },
      {},
    );
    const res = await dashboardHandler(event);
    expect(res.statusCode).toBe(403);
  });

  it('RBAC-30: manager viewing any staff dashboard is allowed (proceeds to DB)', async () => {
    mockGetItem.mockResolvedValueOnce(null); // staff not found — gate passed
    const event = makeHandlerEvent(managerClaims, { staffId: 'STAFF001' });
    const res = await dashboardHandler(event);
    expect(res.statusCode).toBe(404); // past RBAC, hits DB
  });
});

// websocketConnect RBAC ———————————————————————————————————————————————————————

describe('websocketConnect RBAC gate', () => {
  it('RBAC-31: no claims returns 401', async () => {
    const event = makeHandlerEvent(null, {}, {}, { stationId: 'PUMP01', role: 'admin' });
    const res = await wsConnectHandler(event);
    expect(res.statusCode).toBe(401);
  });

  it('RBAC-32: role from query string is ignored — uses JWT claims role', async () => {
    const event = makeHandlerEvent(
      { sub: 'uuid-op', 'custom:staffId': 'STAFF001', 'custom:role': 'pump_operator' },
      {},
      {},
      { stationId: 'PUMP01', role: 'admin' }, // query string tries to claim admin
    );
    (db.putItem as jest.MockedFunction<typeof db.putItem>).mockResolvedValueOnce(undefined);
    const res = await wsConnectHandler(event);
    expect(res.statusCode).toBe(200);
    // Verify the stored role came from claims, not query string
    const storedRecord = (db.putItem as jest.MockedFunction<typeof db.putItem>).mock.calls[0][1];
    expect((storedRecord as Record<string, unknown>)['role']).toBe('pump_operator');
  });
});
