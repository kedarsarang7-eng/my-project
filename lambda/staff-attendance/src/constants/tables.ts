// ============================================================================
// DYNAMODB TABLE CONSTANTS - Staff Attendance System
// ============================================================================

export const TABLES = {
  STAFF_SHIFTS: process.env.STAFF_SHIFTS_TABLE || 'PetrolStaffShifts',
  STAFF_ATTENDANCE: process.env.STAFF_ATTENDANCE_TABLE || 'PetrolStaffAttendance',
  STAFF_LEAVE: process.env.STAFF_LEAVE_TABLE || 'PetrolStaffLeave',
  STAFF_ALERTS: process.env.STAFF_ALERTS_TABLE || 'PetrolStaffAlerts',
  WEBSOCKET_CONNECTIONS: process.env.WEBSOCKET_CONNECTIONS_TABLE || 'PetrolWebSocketConnections',
  ID_CARD_SCANS: process.env.ID_CARD_SCANS_TABLE || 'PetrolIDCardScans',
  STAFF_PROFILES: process.env.STAFF_PROFILES_TABLE || 'PetrolStaffProfiles',
  TRANSACTIONS: process.env.TRANSACTIONS_TABLE || 'FuelPOS_Transactions',
} as const;

export const INDEXES = {
  GSI1: 'GSI1',
  GSI2: 'GSI2',
} as const;

export const S3_BUCKETS = {
  ID_CARD_SCANS: process.env.ID_CARD_SCANS_BUCKET || 'petrol-staff-id-scans',
} as const;

export const SCHEDULED_HOURS = 8; // Standard shift hours
export const GRACE_PERIOD_MINUTES = 15; // Late threshold
export const OVERTIME_THRESHOLD_HOURS = 9; // Overtime alert threshold
