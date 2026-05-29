// ============================================================================
// STAFF TYPES - TypeScript Type Definitions
// ============================================================================

export type StaffRole = 'pump_operator' | 'cashier' | 'supervisor' | 'manager' | 'admin';

export interface StaffPermissions {
  // Fuel Operations
  canDispenseFuel: boolean;
  canEditFuelLogs: boolean;
  
  // Financial
  canViewSalesReport: boolean;
  canProcessPayments: boolean;
  canApplyDiscounts: boolean;
  canViewCashDrawer: boolean;
  canCloseDayShift: boolean;
  
  // Inventory
  canViewInventory: boolean;
  canUpdateInventory: boolean;
  canOrderStock: boolean;
  
  // Staff (for managers)
  canViewOtherStaff: boolean;
  canManageAttendance: boolean;
  
  // Reports
  canExportReports: boolean;
  canViewAllShiftReports: boolean;
  canViewOwnShiftReport: boolean;
}

export interface ShiftTiming {
  start: string; // "06:00"
  end: string; // "14:00"
  days: string[]; // ["MON", "TUE", "WED", "THU", "FRI"]
}

export interface EmergencyContact {
  name: string;
  phone: string;
  relation: string;
}

export interface StaffDocument {
  type: 'AADHAR' | 'PAN' | 'DRIVING_LICENSE' | 'OTHER';
  s3Key: string;
  uploadedAt: string;
}

export interface StaffProfile {
  // Primary Keys
  staffId: string; // Format: "PP-{YEAR}-{4-digit-seq}" e.g., "PP-2024-0042"
  SK: string; // "PROFILE"
  
  // Cognito
  cognitoUserId: string;
  
  // Personal Info
  fullName: string;
  phoneNumber: string;
  email?: string;
  profilePhotoUrl?: string;
  
  // Role & Permissions
  role: StaffRole;
  permissions: StaffPermissions;
  
  // Work Details
  shiftTiming: ShiftTiming;
  joiningDate: string; // ISO 8601
  
  // Status
  isActive: boolean;
  
  // Metadata
  petrolPumpId: string;
  createdBy: string; // owner's cognitoUserId
  createdAt: string;
  updatedAt: string;
  lastLoginAt?: string;
  
  // Additional
  emergencyContact?: EmergencyContact;
  documents?: StaffDocument[];
}

export interface StaffListItem {
  staffId: string;
  fullName: string;
  role: StaffRole;
  phoneNumber: string;
  email?: string;
  isActive: boolean;
  profilePhotoUrl?: string;
  joiningDate: string;
  lastLoginAt?: string;
}

export interface CreateStaffInput {
  fullName: string;
  phoneNumber: string;
  email?: string;
  role: StaffRole;
  shiftTiming: ShiftTiming;
  permissions?: Partial<StaffPermissions>; // Will use role defaults if not provided
  petrolPumpId: string;
  emergencyContact?: EmergencyContact;
}

export interface UpdateStaffInput {
  fullName?: string;
  phoneNumber?: string;
  email?: string;
  role?: StaffRole;
  shiftTiming?: ShiftTiming;
  permissions?: Partial<StaffPermissions>;
  isActive?: boolean;
  emergencyContact?: EmergencyContact;
}

export interface StaffStats {
  totalStaff: number;
  activeStaff: number;
  inactiveStaff: number;
  staffByRole: Record<StaffRole, number>;
  recentJoins: number; // Last 30 days
}

export interface ActivityLogEntry {
  staffId: string;
  timestamp: string;
  eventType: 'LOGIN' | 'LOGOUT' | 'PASSWORD_RESET' | 'ROLE_CHANGE' | 'DEACTIVATED' | 'REACTIVATED' | 'CREATED' | 'UPDATED';
  performedBy: string;
  ipAddress?: string;
  deviceInfo?: string;
  notes?: string;
}

export interface CreateStaffResponse {
  staffId: string;
  temporaryPassword: string;
  cognitoUserId: string;
}

export interface StaffListResponse {
  staff: StaffListItem[];
  pagination: {
    limit: number;
    lastKey?: string;
    hasMore: boolean;
  };
}

export interface ResetPasswordResponse {
  staffId: string;
  temporaryPassword: string;
  message: string;
}

// GSI Keys for DynamoDB
export interface StaffProfileGSI1 {
  GSI1PK: string; // "PUMP#{petrolPumpId}"
  GSI1SK: string; // "ROLE#{role}#STAFF#{staffId}"
}

export interface StaffProfileGSI2 {
  GSI2PK: string; // "PUMP#{petrolPumpId}"
  GSI2SK: string; // "ACTIVE#{isActive}#DATE#{createdAt}"
}
