// ============================================================================
// p28(a) Staff Check-In Idempotency Tests
// ============================================================================

import { APIGatewayProxyEvent } from 'aws-lambda';

// ---------------------------------------------------------------------------
// Mock all DynamoDB helpers BEFORE importing the handler so the module
// resolves to mocked versions from the start.
// ---------------------------------------------------------------------------
jest.mock('../utils/dynamodb', () => ({
  getItem: jest.fn(),
  putItem: jest.fn(),
  queryItems: jest.fn(),
  updateItem: jest.fn(),
  transactWriteItems: jest.fn(),
}));

jest.mock('../utils/ulid', () => ({
  generateULID: jest.fn(() => 'SHIFT-ULID-001'),
  getCurrentTimestamp: jest.fn(() => '2026-05-17T08:00:00.000Z'),
  getCurrentDate: jest.fn(() => '2026-05-17'),
  calculateTimeDifferenceMinutes: jest.fn(() => 0),
  calculateHoursBetween: jest.fn(() => 8),
}));

import { handler } from '../handlers/staffCheckIn';
import * as db from '../utils/dynamodb';

// ---------------------------------------------------------------------------
// Typed mock references
// ---------------------------------------------------------------------------
const mockGetItem = db.getItem as jest.MockedFunction<typeof db.getItem>;
const mockQueryItems = db.queryItems as jest.MockedFunction<typeof db.queryItems>;
const mockPutItem = db.putItem as jest.MockedFunction<typeof db.putItem>;
const mockTransactWriteItems = db.transactWriteItems as jest.MockedFunction<typeof db.transactWriteItems>;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
const STAFF_ID = 'STAFF001';
const STATION_ID = 'PUMP01';
const CLIENT_REQUEST_ID = '550e8400-e29b-41d4-a716-446655440000';

function makeEvent(
  body: object,
  staffId = STAFF_ID,
  claimsOverride?: Record<string, string> | null,
): APIGatewayProxyEvent {
  // Default: the caller IS the staff member (self). RBAC gate passes.
  const defaultClaims = {
    sub: 'uuid-test-op',
    'custom:staffId': staffId,
    'custom:role': 'pump_operator',
  };
  const claims = claimsOverride === null ? undefined : (claimsOverride ?? defaultClaims);
  return {
    httpMethod: 'POST',
    pathParameters: { staffId },
    headers: {},
    body: JSON.stringify(body),
    requestContext: {
      authorizer: claims ? { claims } : undefined,
    },
  } as unknown as APIGatewayProxyEvent;
}

const activeStaffProfile = {
  staffId: STAFF_ID,
  SK: 'PROFILE',
  fullName: 'Ravi Kumar',
  phoneNumber: '9999999999',
  role: 'ATTENDANT',
  isActive: true,
  shiftTiming: { start: '09:00', end: '17:00', days: ['MON', 'TUE', 'WED', 'THU', 'FRI'] },
  petrolPumpId: STATION_ID,
  createdAt: '2026-01-01T00:00:00.000Z',
  updatedAt: '2026-01-01T00:00:00.000Z',
};

const openShiftResult = { items: [], lastKey: undefined };

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('staffCheckIn handler', () => {

  // ── p28(a)-01: Fresh check-in with clientRequestId uses TransactWriteItems ──
  it('p28(a)-01: fresh check-in with clientRequestId writes atomically', async () => {
    mockGetItem
      .mockResolvedValueOnce(activeStaffProfile)  // staff profile
      .mockResolvedValueOnce(null);               // idempotency sentinel — not found
    mockQueryItems.mockResolvedValueOnce(openShiftResult);
    mockTransactWriteItems.mockResolvedValueOnce(undefined);

    const event = makeEvent({
      stationId: STATION_ID,
      scanTimestamp: '2026-05-17T08:00:00.000Z',
      deviceInfo: { model: 'Pixel 7', osVersion: '14', appVersion: '1.2.0' },
      clientRequestId: CLIENT_REQUEST_ID,
    });

    const res = await handler(event);

    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.body);
    expect(body.shiftId).toBe('SHIFT-ULID-001');
    expect(body.idempotentReplay).toBeUndefined();

    // Must use transaction, NOT individual putItem
    expect(mockTransactWriteItems).toHaveBeenCalledTimes(1);
    expect(mockPutItem).not.toHaveBeenCalled();

    // Transaction must include 3 items: sentinel, shift, attendance
    const txInput = mockTransactWriteItems.mock.calls[0][0];
    expect(txInput.TransactItems).toHaveLength(3);

    // First item must be the idempotency sentinel with condition
    const sentinel = txInput.TransactItems![0].Put!;
    expect(sentinel.ConditionExpression).toBe('attribute_not_exists(PK)');
    expect((sentinel.Item as Record<string, unknown>)['SK']).toBe(`IDEMP#${CLIENT_REQUEST_ID}`);
    expect((sentinel.Item as Record<string, unknown>)['recordType']).toBe('SHIFT_CHECKIN_IDEMP');
  });

  // ── p28(a)-02: Idempotency sentinel found → returns 200 replay immediately ──
  it('p28(a)-02: existing sentinel returns 200 idempotent replay without writing', async () => {
    mockGetItem
      .mockResolvedValueOnce(activeStaffProfile)  // staff profile
      .mockResolvedValueOnce({                    // idempotency sentinel FOUND
        PK: `STAFF#${STAFF_ID}`,
        SK: `IDEMP#${CLIENT_REQUEST_ID}`,
        recordType: 'SHIFT_CHECKIN_IDEMP',
        clientRequestId: CLIENT_REQUEST_ID,
        shiftId: 'SHIFT-EXISTING-001',
        stationId: STATION_ID,
        createdAt: '2026-05-17T08:00:00.000Z',
        ttl: 9999999999,
      })
      .mockResolvedValueOnce({                    // replay shift row
        PK: `STAFF#${STAFF_ID}`,
        SK: 'SHIFT#SHIFT-EXISTING-001',
        shiftId: 'SHIFT-EXISTING-001',
        checkInTime: '2026-05-17T07:55:00.000Z',
        isLate: false,
        lateMinutes: 0,
        scheduledEnd: '17:00',
        status: 'OPEN',
      });

    const event = makeEvent({
      stationId: STATION_ID,
      scanTimestamp: '2026-05-17T08:05:00.000Z',
      deviceInfo: { model: 'Pixel 7', osVersion: '14', appVersion: '1.2.0' },
      clientRequestId: CLIENT_REQUEST_ID,
    });

    const res = await handler(event);

    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.body);
    expect(body.shiftId).toBe('SHIFT-EXISTING-001');
    expect(body.idempotentReplay).toBe(true);

    // No write operations — purely a read + replay
    expect(mockTransactWriteItems).not.toHaveBeenCalled();
    expect(mockPutItem).not.toHaveBeenCalled();
    // Only called the GSI open-shift query once to look for existing sentinel,
    // so queryItems should NOT have been called (sentinel short-circuits it)
    expect(mockQueryItems).not.toHaveBeenCalled();
  });

  // ── p28(a)-03: Concurrent race — TransactionCanceledException → replay ──
  it('p28(a)-03: concurrent race TransactionCanceledException returns 200 replay', async () => {
    const cancelErr = new Error('Transaction cancelled');
    cancelErr.name = 'TransactionCanceledException';

    mockGetItem
      .mockResolvedValueOnce(activeStaffProfile)  // staff profile
      .mockResolvedValueOnce(null)                // sentinel not found (yet)
      .mockResolvedValueOnce({                    // sentinel found on post-cancel re-read
        PK: `STAFF#${STAFF_ID}`,
        SK: `IDEMP#${CLIENT_REQUEST_ID}`,
        recordType: 'SHIFT_CHECKIN_IDEMP',
        clientRequestId: CLIENT_REQUEST_ID,
        shiftId: 'SHIFT-CONCURRENT-001',
        stationId: STATION_ID,
        createdAt: '2026-05-17T08:00:00.000Z',
        ttl: 9999999999,
      })
      .mockResolvedValueOnce({                    // shift row for replay
        PK: `STAFF#${STAFF_ID}`,
        SK: 'SHIFT#SHIFT-CONCURRENT-001',
        shiftId: 'SHIFT-CONCURRENT-001',
        checkInTime: '2026-05-17T08:00:01.000Z',
        isLate: false,
        lateMinutes: 0,
        scheduledEnd: '17:00',
        status: 'OPEN',
      });

    mockQueryItems.mockResolvedValueOnce(openShiftResult);
    mockTransactWriteItems.mockRejectedValueOnce(cancelErr);

    const event = makeEvent({
      stationId: STATION_ID,
      scanTimestamp: '2026-05-17T08:00:02.000Z',
      deviceInfo: { model: 'Pixel 7', osVersion: '14', appVersion: '1.2.0' },
      clientRequestId: CLIENT_REQUEST_ID,
    });

    const res = await handler(event);

    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.body);
    expect(body.shiftId).toBe('SHIFT-CONCURRENT-001');
    expect(body.idempotentReplay).toBe(true);
  });

  // ── p28(a)-04: Legacy client (no clientRequestId) uses individual puts ──
  it('p28(a)-04: legacy client without clientRequestId uses individual putItem calls', async () => {
    mockGetItem.mockResolvedValueOnce(activeStaffProfile);
    mockQueryItems.mockResolvedValueOnce(openShiftResult);
    mockPutItem.mockResolvedValue(undefined);

    const event = makeEvent({
      stationId: STATION_ID,
      scanTimestamp: '2026-05-17T08:00:00.000Z',
      deviceInfo: { model: 'OldPhone', osVersion: '10', appVersion: '0.9.0' },
      // clientRequestId intentionally omitted
    });

    const res = await handler(event);

    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.body);
    expect(body.shiftId).toBe('SHIFT-ULID-001');

    // Legacy path: individual puts, no transaction
    expect(mockTransactWriteItems).not.toHaveBeenCalled();
    expect(mockPutItem).toHaveBeenCalledTimes(2); // shift + attendance
  });

  // ── p28(a)-05: Existing open shift returns 409 for legacy clients ──
  it('p28(a)-05: existing open shift returns 409 for legacy client', async () => {
    mockGetItem.mockResolvedValueOnce(activeStaffProfile);
    mockQueryItems.mockResolvedValueOnce({
      items: [{
        staffId: STAFF_ID,
        shiftId: 'SHIFT-LEGACY-OPEN',
        checkInTime: '2026-05-17T07:00:00.000Z',
        status: 'OPEN',
      }],
    });

    const event = makeEvent({
      stationId: STATION_ID,
      scanTimestamp: '2026-05-17T08:00:00.000Z',
      deviceInfo: { model: 'OldPhone', osVersion: '10', appVersion: '0.9.0' },
    });

    const res = await handler(event);

    expect(res.statusCode).toBe(409);
    const body = JSON.parse(res.body);
    expect(body.error).toBe('Shift already active');
    expect(body.shiftId).toBe('SHIFT-LEGACY-OPEN');
  });

  // ── p28(a)-06: Staff not found → 404 ──
  it('p28(a)-06: unknown staffId returns 404', async () => {
    mockGetItem.mockResolvedValueOnce(null);

    const event = makeEvent({
      stationId: STATION_ID,
      scanTimestamp: '2026-05-17T08:00:00.000Z',
      deviceInfo: { model: 'Pixel 7', osVersion: '14', appVersion: '1.2.0' },
      clientRequestId: CLIENT_REQUEST_ID,
    }, 'UNKNOWN_STAFF');

    const res = await handler(event);

    expect(res.statusCode).toBe(404);
    expect(JSON.parse(res.body).error).toBe('Staff not found');
  });

  // ── p28(a)-07: Inactive staff → 403 ──
  it('p28(a)-07: inactive staff returns 403', async () => {
    mockGetItem.mockResolvedValueOnce({ ...activeStaffProfile, isActive: false });

    const event = makeEvent({
      stationId: STATION_ID,
      scanTimestamp: '2026-05-17T08:00:00.000Z',
      deviceInfo: { model: 'Pixel 7', osVersion: '14', appVersion: '1.2.0' },
    });

    const res = await handler(event);

    expect(res.statusCode).toBe(403);
  });

  // ── p28(a)-08: Invalid body → 400 Zod validation ──
  it('p28(a)-08: missing required fields returns 400', async () => {
    const event = makeEvent({ stationId: '' }); // empty stationId fails z.string().min(1)

    const res = await handler(event);

    expect(res.statusCode).toBe(400);
    const body = JSON.parse(res.body);
    expect(body.error).toBe('Validation failed');
  });

  // ── p28(a)-09: Non-TransactionCanceled error is re-thrown as 500 ──
  it('p28(a)-09: unexpected transact error surfaces as 500', async () => {
    const dbErr = new Error('ProvisionedThroughputExceededException');
    dbErr.name = 'ProvisionedThroughputExceededException';

    mockGetItem
      .mockResolvedValueOnce(activeStaffProfile)
      .mockResolvedValueOnce(null);
    mockQueryItems.mockResolvedValueOnce(openShiftResult);
    mockTransactWriteItems.mockRejectedValueOnce(dbErr);

    const event = makeEvent({
      stationId: STATION_ID,
      scanTimestamp: '2026-05-17T08:00:00.000Z',
      deviceInfo: { model: 'Pixel 7', osVersion: '14', appVersion: '1.2.0' },
      clientRequestId: CLIENT_REQUEST_ID,
    });

    const res = await handler(event);

    expect(res.statusCode).toBe(500);
  });

  // ── p28(a)-10: clientRequestId UUID format enforced ──
  it('p28(a)-10: invalid UUID clientRequestId returns 400', async () => {
    const event = makeEvent({
      stationId: STATION_ID,
      scanTimestamp: '2026-05-17T08:00:00.000Z',
      deviceInfo: { model: 'Pixel 7', osVersion: '14', appVersion: '1.2.0' },
      clientRequestId: 'not-a-uuid',
    });

    const res = await handler(event);

    expect(res.statusCode).toBe(400);
    expect(JSON.parse(res.body).error).toBe('Validation failed');
  });
});
