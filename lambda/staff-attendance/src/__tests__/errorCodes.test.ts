// ============================================================================
// p28(d) Error-code contract tests
// Verifies every non-200 handler response carries a machine-readable errorCode
// that matches the ErrorCodes constants — so the Flutter client can branch on
// it rather than matching English error strings.
// ============================================================================

import type { APIGatewayProxyEvent } from 'aws-lambda';
import { ErrorCodes } from '../constants/errorCodes';
import { isRetryable } from '../constants/errorCodes';

jest.mock('../utils/dynamodb', () => ({
  getItem: jest.fn(),
  putItem: jest.fn(),
  queryItems: jest.fn(),
  updateItem: jest.fn(),
  transactWriteItems: jest.fn(),
}));

jest.mock('../utils/ulid', () => ({
  generateULID: jest.fn(() => 'ULID-EC-001'),
  getCurrentTimestamp: jest.fn(() => '2026-05-17T10:00:00.000Z'),
  getCurrentDate: jest.fn(() => '2026-05-17'),
  calculateTimeDifferenceMinutes: jest.fn(() => 0),
  calculateHoursBetween: jest.fn(() => 8),
}));

import { handler as checkInHandler } from '../handlers/staffCheckIn';
import { handler as checkOutHandler } from '../handlers/staffCheckOut';
import { handler as submitLeaveHandler } from '../handlers/submitLeaveRequest';
import { handler as processLeaveHandler } from '../handlers/processLeaveRequest';
import * as db from '../utils/dynamodb';

const mockGetItem = db.getItem as jest.MockedFunction<typeof db.getItem>;
const mockQueryItems = db.queryItems as jest.MockedFunction<typeof db.queryItems>;
const mockTransact = db.transactWriteItems as jest.MockedFunction<typeof db.transactWriteItems>;

function makeEvent(
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
    },
  } as unknown as APIGatewayProxyEvent;
}

const selfClaims = (staffId: string) => ({
  sub: 'uuid-' + staffId,
  'custom:staffId': staffId,
  'custom:role': 'pump_operator',
});
const managerClaims = { sub: 'uuid-mgr', 'custom:staffId': 'MGR001', 'custom:role': 'manager' };

// Helper to parse body and assert errorCode
function assertErrorCode(body: string, expected: string) {
  const parsed = JSON.parse(body);
  expect(parsed).toHaveProperty('errorCode', expected);
  expect(parsed).toHaveProperty('error'); // human message always present
}

// ── isRetryable utility ───────────────────────────────────────────────────────

describe('isRetryable utility', () => {
  it('EC-01: INTERNAL_ERROR is retryable', () => {
    expect(isRetryable(ErrorCodes.INTERNAL_ERROR)).toBe(true);
  });

  it('EC-02: DB_TRANSACTION_FAILED is retryable', () => {
    expect(isRetryable(ErrorCodes.DB_TRANSACTION_FAILED)).toBe(true);
  });

  it('EC-03: VALIDATION_FAILED is not retryable', () => {
    expect(isRetryable(ErrorCodes.VALIDATION_FAILED)).toBe(false);
  });

  it('EC-04: SHIFT_ALREADY_ACTIVE is not retryable (use idempotency)', () => {
    expect(isRetryable(ErrorCodes.SHIFT_ALREADY_ACTIVE)).toBe(false);
  });

  it('EC-05: FORBIDDEN_ROLE is not retryable', () => {
    expect(isRetryable(ErrorCodes.FORBIDDEN_ROLE)).toBe(false);
  });
});

// ── staffCheckIn error codes ──────────────────────────────────────────────────

describe('staffCheckIn errorCode contract', () => {
  it('EC-06: missing staffId → MISSING_PARAM', async () => {
    const event = makeEvent(null, {});
    const res = await checkInHandler(event);
    expect(res.statusCode).toBe(400);
    assertErrorCode(res.body, ErrorCodes.MISSING_PARAM);
  });

  it('EC-07: unknown staffId → STAFF_NOT_FOUND', async () => {
    mockGetItem.mockResolvedValueOnce(null);
    const event = makeEvent(selfClaims('STAFF001'), { staffId: 'STAFF001' }, {
      stationId: 'PUMP01',
      scanTimestamp: '2026-05-17T08:00:00.000Z',
      deviceInfo: { model: 'X', osVersion: '14', appVersion: '1.0' },
    });
    const res = await checkInHandler(event);
    expect(res.statusCode).toBe(404);
    assertErrorCode(res.body, ErrorCodes.STAFF_NOT_FOUND);
  });

  it('EC-08: inactive staff → ACCOUNT_INACTIVE', async () => {
    mockGetItem.mockResolvedValueOnce({
      staffId: 'STAFF001', isActive: false,
      shiftTiming: { start: '09:00', end: '17:00', days: [] },
      petrolPumpId: 'PUMP01', createdAt: '', updatedAt: '',
    });
    const event = makeEvent(selfClaims('STAFF001'), { staffId: 'STAFF001' }, {
      stationId: 'PUMP01',
      scanTimestamp: '2026-05-17T08:00:00.000Z',
      deviceInfo: { model: 'X', osVersion: '14', appVersion: '1.0' },
    });
    const res = await checkInHandler(event);
    expect(res.statusCode).toBe(403);
    assertErrorCode(res.body, ErrorCodes.ACCOUNT_INACTIVE);
  });

  it('EC-09: existing open shift (legacy path) → SHIFT_ALREADY_ACTIVE', async () => {
    mockGetItem.mockResolvedValueOnce({
      staffId: 'STAFF001', isActive: true,
      shiftTiming: { start: '09:00', end: '17:00', days: [] },
      petrolPumpId: 'PUMP01', createdAt: '', updatedAt: '',
    });
    mockQueryItems.mockResolvedValueOnce({
      items: [{ staffId: 'STAFF001', shiftId: 'OPEN-SHIFT', status: 'OPEN', checkInTime: '2026-05-17T07:00:00.000Z' }],
    });
    const event = makeEvent(selfClaims('STAFF001'), { staffId: 'STAFF001' }, {
      stationId: 'PUMP01',
      scanTimestamp: '2026-05-17T08:00:00.000Z',
      deviceInfo: { model: 'X', osVersion: '14', appVersion: '1.0' },
    });
    const res = await checkInHandler(event);
    expect(res.statusCode).toBe(409);
    assertErrorCode(res.body, ErrorCodes.SHIFT_ALREADY_ACTIVE);
    expect(JSON.parse(res.body)).toHaveProperty('shiftId', 'OPEN-SHIFT');
  });

  it('EC-10: Zod validation failure → VALIDATION_FAILED', async () => {
    const event = makeEvent(selfClaims('STAFF001'), { staffId: 'STAFF001' }, {
      stationId: 'PUMP01',
      // scanTimestamp intentionally missing
    });
    const res = await checkInHandler(event);
    expect(res.statusCode).toBe(400);
    assertErrorCode(res.body, ErrorCodes.VALIDATION_FAILED);
    expect(JSON.parse(res.body)).toHaveProperty('details');
  });

  it('EC-11: unexpected server error → INTERNAL_ERROR', async () => {
    mockGetItem.mockRejectedValueOnce(new Error('DynamoDB timeout'));
    const event = makeEvent(selfClaims('STAFF001'), { staffId: 'STAFF001' }, {
      stationId: 'PUMP01',
      scanTimestamp: '2026-05-17T08:00:00.000Z',
      deviceInfo: { model: 'X', osVersion: '14', appVersion: '1.0' },
    });
    const res = await checkInHandler(event);
    expect(res.statusCode).toBe(500);
    assertErrorCode(res.body, ErrorCodes.INTERNAL_ERROR);
    expect(isRetryable(ErrorCodes.INTERNAL_ERROR)).toBe(true);
  });
});

// ── staffCheckOut error codes ─────────────────────────────────────────────────

describe('staffCheckOut errorCode contract', () => {
  it('EC-12: missing staffId → MISSING_PARAM', async () => {
    const event = makeEvent(null, {});
    const res = await checkOutHandler(event);
    expect(res.statusCode).toBe(400);
    assertErrorCode(res.body, ErrorCodes.MISSING_PARAM);
  });

  it('EC-13: shift not found → SHIFT_NOT_FOUND', async () => {
    mockGetItem.mockResolvedValueOnce(null);
    const event = makeEvent(selfClaims('STAFF001'), { staffId: 'STAFF001' }, {
      shiftId: 'GHOST', stationId: 'PUMP01',
    });
    const res = await checkOutHandler(event);
    expect(res.statusCode).toBe(404);
    assertErrorCode(res.body, ErrorCodes.SHIFT_NOT_FOUND);
  });

  it('EC-14: shift already closed → SHIFT_ALREADY_CLOSED', async () => {
    mockGetItem.mockResolvedValueOnce({
      staffId: 'STAFF001', shiftId: 'SH001', status: 'CLOSED', checkOutTime: '2026-05-17T16:00:00.000Z',
    });
    const event = makeEvent(selfClaims('STAFF001'), { staffId: 'STAFF001' }, {
      shiftId: 'SH001', stationId: 'PUMP01',
    });
    const res = await checkOutHandler(event);
    expect(res.statusCode).toBe(409);
    assertErrorCode(res.body, ErrorCodes.SHIFT_ALREADY_CLOSED);
    expect(JSON.parse(res.body)).toHaveProperty('checkOutTime');
  });
});

// ── submitLeaveRequest error codes ────────────────────────────────────────────

describe('submitLeaveRequest errorCode contract', () => {
  it('EC-15: overlapping leave → LEAVE_OVERLAP', async () => {
    mockGetItem.mockResolvedValueOnce({
      staffId: 'STAFF001', fullName: 'R', isActive: true, petrolPumpId: 'PUMP01',
    });
    // future dates so date validation passes
    const futureFrom = new Date();
    futureFrom.setDate(futureFrom.getDate() + 5);
    const futureTo = new Date(futureFrom);
    futureTo.setDate(futureTo.getDate() + 2);
    const fmt = (d: Date) => d.toISOString().split('T')[0];
    // First queryItems call = overlapping approved leaves
    mockQueryItems.mockResolvedValueOnce({
      items: [{ leaveId: 'L001', staffId: 'STAFF001', fromDate: fmt(futureFrom), toDate: fmt(futureTo) }],
    });
    const event = makeEvent(
      selfClaims('STAFF001'),
      { staffId: 'STAFF001' },
      { leaveType: 'CASUAL', fromDate: fmt(futureFrom), toDate: fmt(futureTo), reason: 'test' },
    );
    const res = await submitLeaveHandler(event);
    expect(res.statusCode).toBe(409);
    assertErrorCode(res.body, ErrorCodes.LEAVE_OVERLAP);
  });

  it('EC-16: duplicate pending → LEAVE_DUPLICATE_PENDING', async () => {
    mockGetItem.mockResolvedValueOnce({
      staffId: 'STAFF001', fullName: 'R', isActive: true, petrolPumpId: 'PUMP01',
    });
    const futureFrom = new Date();
    futureFrom.setDate(futureFrom.getDate() + 7);
    const futureTo = new Date(futureFrom);
    futureTo.setDate(futureTo.getDate() + 1);
    const fmt = (d: Date) => d.toISOString().split('T')[0];
    // No overlapping approved; one pending duplicate
    mockQueryItems
      .mockResolvedValueOnce({ items: [] })              // approved check
      .mockResolvedValueOnce({ items: [{ leaveId: 'PENDING001' }] }); // pending check
    const event = makeEvent(
      selfClaims('STAFF001'),
      { staffId: 'STAFF001' },
      { leaveType: 'SICK', fromDate: fmt(futureFrom), toDate: fmt(futureTo), reason: 'flu' },
    );
    const res = await submitLeaveHandler(event);
    expect(res.statusCode).toBe(409);
    assertErrorCode(res.body, ErrorCodes.LEAVE_DUPLICATE_PENDING);
    expect(JSON.parse(res.body)).toHaveProperty('leaveId', 'PENDING001');
  });
});

// ── processLeaveRequest error codes ──────────────────────────────────────────

describe('processLeaveRequest errorCode contract', () => {
  it('EC-17: leave not found → LEAVE_NOT_FOUND', async () => {
    mockGetItem.mockResolvedValueOnce(null);
    const event = makeEvent(
      managerClaims,
      { leaveId: 'LEAVE-GHOST' },
      { action: 'APPROVE' },
      { staffId: 'STAFF001' },
    );
    const res = await processLeaveHandler(event);
    expect(res.statusCode).toBe(404);
    assertErrorCode(res.body, ErrorCodes.LEAVE_NOT_FOUND);
  });

  it('EC-18: leave already processed → LEAVE_ALREADY_PROCESSED', async () => {
    mockGetItem.mockResolvedValueOnce({
      leaveId: 'L002', staffId: 'STAFF001', status: 'APPROVED',
      fromDate: '2026-06-01', toDate: '2026-06-02', days: 2, stationId: 'PUMP01',
    });
    const event = makeEvent(
      managerClaims,
      { leaveId: 'L002' },
      { action: 'REJECT' },
      { staffId: 'STAFF001' },
    );
    const res = await processLeaveHandler(event);
    expect(res.statusCode).toBe(409);
    assertErrorCode(res.body, ErrorCodes.LEAVE_ALREADY_PROCESSED);
    expect(JSON.parse(res.body)).toHaveProperty('currentStatus', 'APPROVED');
  });
});
