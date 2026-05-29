// ============================================================================
// ATTENDANCE SYSTEM TYPES - TypeScript Type Definitions
// ============================================================================

export type ShiftStatus = 'OPEN' | 'CLOSED' | 'AUTO_CLOSED';
export type AttendanceStatus = 'PRESENT' | 'ABSENT' | 'LATE' | 'HALF_DAY' | 'LEAVE' | 'NOT_MARKED';
export type LeaveType = 'CASUAL' | 'SICK' | 'EARNED' | 'EMERGENCY';
export type LeaveStatus = 'PENDING' | 'APPROVED' | 'REJECTED';
export type AlertType = 'LATE_CHECKIN' | 'OVERTIME' | 'NO_SHOW' | 'EARLY_CHECKOUT';
export type AlertSeverity = 'LOW' | 'MEDIUM' | 'HIGH';

// ============================================================================
// StaffProfile (from existing PetrolStaffProfiles table)
// ============================================================================
export interface StaffProfile {
  staffId: string;
  SK: string;
  fullName: string;
  phoneNumber: string;
  email?: string;
  profilePhotoUrl?: string;
  role: string;
  isActive: boolean;
  shiftTiming?: {
    start: string;
    end: string;
    days: string[];
  };
  petrolPumpId: string;
  latestIdCardUrl?: string;
  latestIdCardS3Key?: string;
  idCardUpdatedAt?: string;
  createdAt: string;
  updatedAt: string;
}

// ============================================================================
// StaffShifts Table
// ============================================================================
export interface StaffShift {
  PK: string; // STAFF#{staffId}
  SK: string; // SHIFT#{shiftId}
  GSI1PK: string; // STATION#{stationId}
  GSI1SK: string; // DATE#{date}#START#{startTime}
  GSI2PK: string; // STATION#{stationId}
  GSI2SK: string; // STATUS#{status}#DATE#{date}
  
  shiftId: string;
  staffId: string;
  stationId: string;
  status: ShiftStatus;
  
  checkInTime: string; // ISO 8601
  checkOutTime?: string; // ISO 8601
  scheduledStart: string; // HH:MM
  scheduledEnd: string; // HH:MM
  
  scanImageS3Key?: string;
  
  totalHours: number;
  overtimeHours: number;
  isLate: boolean;
  lateMinutes: number;
  isOvertime: boolean;
  
  totalPetrolLitres: number;
  totalDieselLitres: number;
  totalSalesAmount: number;
  transactionCount: number;
  
  // p28(a) idempotency: client-generated UUID that proves a retry is a retry
  // of the same logical operation. Optional for backward compatibility with
  // older clients that pre-date the idempotency contract.
  clientRequestId?: string;
  
  createdAt: string;
  updatedAt: string;
  ttl?: number;
}

// ============================================================================
// StaffShifts idempotency record (p28(a))
// ----------------------------------------------------------------------------
// Stored in the SAME StaffShifts table to keep the atomic TransactWriteItems
// simple. SK pattern (`IDEMP#{clientRequestId}`) guarantees no clash with
// real shift rows (`SHIFT#{shiftId}`). Records auto-expire after 24h via TTL
// so the table does not grow unbounded with retried requests.
// ============================================================================
export interface ShiftIdempotencyRecord {
  PK: string; // STAFF#{staffId}
  SK: string; // IDEMP#{clientRequestId}
  recordType: 'SHIFT_CHECKIN_IDEMP';
  clientRequestId: string;
  shiftId: string; // points to the StaffShift row created in the same transaction
  stationId: string;
  createdAt: string;
  ttl: number; // epoch seconds; 24h after creation
}

// ============================================================================
// StaffAttendance Table
// ============================================================================
export interface StaffAttendance {
  PK: string; // STAFF#{staffId}
  SK: string; // DATE#{YYYY-MM-DD}
  GSI1PK: string; // STATION#{stationId}
  GSI1SK: string; // DATE#{YYYY-MM-DD}#STATUS#{status}
  
  staffId: string;
  stationId: string;
  date: string; // YYYY-MM-DD
  status: AttendanceStatus;
  
  checkInTime?: string;
  checkOutTime?: string;
  shiftId?: string;
  
  hoursWorked: number;
  overtimeHours: number;
  isLate: boolean;
  lateMinutes: number;
  
  scheduledStart: string;
  scheduledEnd: string;
  
  markedBy: string; // SYSTEM or userId
  notes?: string;
  
  createdAt: string;
  updatedAt: string;
}

// ============================================================================
// StaffLeave Table
// ============================================================================
export interface StaffLeave {
  PK: string; // STAFF#{staffId}
  SK: string; // LEAVE#{leaveId}
  GSI1PK: string; // STATION#{stationId}
  GSI1SK: string; // STATUS#{status}#DATE#{fromDate}
  
  leaveId: string;
  staffId: string;
  stationId: string;
  
  leaveType: LeaveType;
  fromDate: string; // YYYY-MM-DD
  toDate: string; // YYYY-MM-DD
  days: number;
  reason: string;
  
  status: LeaveStatus;
  approvedBy?: string;
  approvedAt?: string;
  rejectionReason?: string;
  
  appliedAt: string;
  updatedAt: string;
}

// ============================================================================
// StaffAlerts Table
// ============================================================================
export interface StaffAlert {
  PK: string; // STAFF#{staffId}
  SK: string; // ALERT#{timestamp}#{alertId}
  GSI1PK: string; // STATION#{stationId}
  GSI1SK: string; // TYPE#{type}#DATE#{date}
  
  alertId: string;
  staffId: string;
  stationId: string;
  
  type: AlertType;
  severity: AlertSeverity;
  message: string;
  shiftId?: string;
  date: string; // YYYY-MM-DD
  
  isRead: boolean;
  readAt?: string;
  notifiedVia: string[];
  
  createdAt: string;
  ttl?: number;
}

// ============================================================================
// WebSocketConnections Table
// ============================================================================
export interface WebSocketConnection {
  connectionId: string; // PK
  userId: string;
  staffId?: string;
  stationId: string;
  role: string;
  connectedAt: string;
  lastPingAt: string;
  ttl: number;
}

// ============================================================================
// IDCardScans Table
// ============================================================================
export interface IDCardScan {
  PK: string; // STAFF#{staffId}
  SK: string; // SCAN#{timestamp}#{scanId}
  
  scanId: string;
  staffId: string;
  stationId: string;
  shiftId?: string;
  
  s3Key: string;
  ocrConfidence: number;
  extractedId: string;
  matchedId: string;
  isMatch: boolean;
  
  deviceInfo: {
    model: string;
    osVersion: string;
    appVersion: string;
  };
  ipAddress: string;
  
  createdAt: string;
  ttl?: number;
}

// ============================================================================
// API Input/Output Types
// ============================================================================
export interface CheckInInput {
  staffId: string;
  stationId: string;
  scanImageBase64?: string;
  scanTimestamp: string;
  deviceInfo: {
    model: string;
    osVersion: string;
    appVersion: string;
  };
  idCardNumber?: string; // Fallback if scan fails
}

export interface CheckInOutput {
  shiftId: string;
  checkInTime: string;
  isLate: boolean;
  lateByMinutes: number;
  message: string;
  status: 'OPEN';
}

export interface CheckOutInput {
  staffId: string;
  shiftId: string;
  stationId: string;
}

export interface CheckOutOutput {
  shiftId: string;
  checkOutTime: string;
  totalHours: number;
  overtimeHours: number;
  shiftSummary: {
    totalPetrolLitres: number;
    totalDieselLitres: number;
    totalSalesAmount: number;
    transactionCount: number;
  };
}

export interface StaffDashboardOutput {
  staff: {
    staffId: string;
    fullName: string;
    role: string;
    profilePhotoUrl?: string;
  };
  attendanceSummary: {
    presentDays: number;
    absentDays: number;
    lateDays: number;
    halfDays: number;
    onLeaveDays: number;
  };
  shiftSummary: {
    totalShifts: number;
    totalHoursWorked: number;
    totalOvertimeHours: number;
    avgCheckInTime: string;
    avgCheckOutTime: string;
  };
  salesSummary: {
    totalPetrolLitres: number;
    totalDieselLitres: number;
    totalPetrolAmount: number;
    totalDieselAmount: number;
    totalTransactions: number;
    paymentMethodBreakdown: {
      cash: number;
      card: number;
      upi: number;
    };
  };
  performanceScore: {
    overall: number;
    punctualityScore: number;
    attendanceScore: number;
    salesScore: number;
  };
  weeklyHoursTrend: Array<{
    week: string;
    hours: number;
  }>;
  recentAlerts: StaffAlert[];
  leaveBalance: {
    casual: { used: number; total: number };
    sick: { used: number; total: number };
    earned: { used: number; total: number };
  };
}

export interface CalendarDay {
  date: string;
  dayOfWeek: number;
  status: AttendanceStatus;
  checkInTime?: string;
  checkOutTime?: string;
  hoursWorked?: number;
  isLate: boolean;
  lateMinutes: number;
  shiftId?: string;
  transactionCount: number;
  isWeekend: boolean;
  isHoliday: boolean;
}

export interface AttendanceCalendarOutput {
  month: string;
  year: number;
  days: CalendarDay[];
}

export interface SubmitLeaveInput {
  staffId: string;
  leaveType: LeaveType;
  fromDate: string;
  toDate: string;
  reason: string;
}

export interface ProcessLeaveInput {
  leaveId: string;
  action: 'APPROVE' | 'REJECT';
  remarks?: string;
}

export interface StaffListItem {
  staffId: string;
  fullName: string;
  role: string;
  profilePhotoUrl?: string;
  isActive: boolean;
  todayAttendance: AttendanceStatus;
  currentlyOnDuty: boolean;
  lastCheckIn?: string;
  hoursWorkedToday: number;
  todaySalesAmount: number;
  pendingLeaveRequests: number;
}

// ============================================================================
// ID Card Metadata Table
// ============================================================================
export interface IDCardMetadata {
  PK: string; // STAFF#{staffId}
  SK: string; // IDCARD#{cardId}
  cardId: string;
  staffId: string;
  stationId: string;
  s3Key: string;
  format: 'PNG' | 'PDF';
  template: string;
  uploadedAt: string;
  uploadedBy: string;
  size: number;
  url: string;
}

// ============================================================================
// WebSocket Event Types
// ============================================================================
export interface WebSocketEvent {
  eventType: 'STAFF_CHECKED_IN' | 'STAFF_CHECKED_OUT' | 'TRANSACTION_RECORDED' | 'OVERTIME_ALERT' | 'LEAVE_REQUESTED' | 'LEAVE_PROCESSED';
  stationId: string;
  staffId: string;
  timestamp: string;
  payload: Record<string, unknown>;
  version: '1.0';
}
