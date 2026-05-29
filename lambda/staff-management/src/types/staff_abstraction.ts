// ============================================================================
// STAFF MANAGEMENT ABSTRACTION LAYER (BUG-030 FIX)
// ============================================================================
// Replaces hardcoded petrolPumpId with generic businessId/businessType
// Enables staff management for ALL business types

/**
 * Generic staff entity that works across all business types
 * Replaces petrolPumpId with businessId + businessType
 */
export interface StaffMember {
  id: string;
  businessId: string;        // Generic: was petrolPumpId
  businessType: BusinessType; // NEW: identifies the business type
  tenantId: string;           // Cognito tenant for multi-tenancy
  
  // Personal info
  fullName: string;
  phoneNumber: string;
  email?: string;
  address?: string;
  
  // Employment
  role: StaffRole;
  department?: string;
  joinDate: string;
  employeeId?: string;
  
  // Status
  isActive: boolean;
  isDeleted: boolean;
  deletedAt?: string;
  
  // Business-type specific config
  config: StaffConfig;
  
  // Metadata
  createdAt: string;
  updatedAt: string;
  createdBy: string;
}

/**
 * Business types supported by staff management
 */
export enum BusinessType {
  PETROL_PUMP = 'petrol_pump',
  RESTAURANT = 'restaurant',
  CLINIC = 'clinic',
  PHARMACY = 'pharmacy',
  GROCERY = 'grocery',
  HARDWARE = 'hardware',
  MOBILE_SHOP = 'mobile_shop',
  COMPUTER_SHOP = 'computer_shop',
  CLOTHING = 'clothing',
  JEWELRY = 'jewelry',
  BOOKSTORE = 'bookstore',
  SERVICE = 'service',
  VEGETABLE_BROKER = 'vegetable_broker',
  OTHER = 'other'
}

/**
 * Staff roles (generic across business types)
 */
export enum StaffRole {
  OWNER = 'owner',
  MANAGER = 'manager',
  CASHIER = 'cashier',
  SALES_ASSISTANT = 'sales_assistant',
  PHARMACIST = 'pharmacist',
  DOCTOR = 'doctor',
  NURSE = 'nurse',
  CHEF = 'chef',
  WAITER = 'waiter',
  ATTENDANT = 'attendant',
  TECHNICIAN = 'technician',
  DELIVERY = 'delivery',
  SECURITY = 'security',
  CLEANER = 'cleaner',
  OTHER = 'other'
}

/**
 * Business-type specific staff configuration
 */
export interface StaffConfig {
  // Petrol Pump specific
  pumpAssignment?: PumpAssignment;
  shiftPreference?: ShiftType;
  
  // Restaurant specific
  sectionAssignment?: string;
  
  // Clinic specific
  specialization?: string;
  licenseNumber?: string;
  
  // Pharmacy specific
  drugLicenseNumber?: string;
  
  // Generic
  maxDiscountPercent?: number;
  canApproveReturns?: boolean;
  canEditPrices?: boolean;
  canViewReports?: boolean;
}

/**
 * Pump assignment for petrol pump staff
 */
export interface PumpAssignment {
  pumpNumbers: number[];
  dispenserIds: string[];
}

/**
 * Shift types
 */
export enum ShiftType {
  DAY = 'day',
  NIGHT = 'night',
  ROTATING = 'rotating',
  FLEXIBLE = 'flexible'
}

/**
 * Staff attendance record (generic)
 */
export interface StaffAttendance {
  id: string;
  staffId: string;
  businessId: string;
  tenantId: string;
  
  date: string;
  checkIn?: string;
  checkOut?: string;
  
  status: AttendanceStatus;
  shiftType?: ShiftType;
  
  // Location tracking
  checkInLocation?: GeoLocation;
  checkOutLocation?: GeoLocation;
  
  // For petrol pump
  meterReadings?: MeterReading[];
  
  notes?: string;
  
  createdAt: string;
  updatedAt: string;
}

/**
 * Attendance status
 */
export enum AttendanceStatus {
  PRESENT = 'present',
  ABSENT = 'absent',
  LATE = 'late',
  HALF_DAY = 'half_day',
  ON_LEAVE = 'on_leave',
  HOLIDAY = 'holiday'
}

/**
 * Geographic location
 */
export interface GeoLocation {
  latitude: number;
  longitude: number;
  accuracy?: number;
}

/**
 * Meter reading for petrol pump staff
 */
export interface MeterReading {
  dispenserId: string;
  fuelType: string;
  startReading: number;
  endReading: number;
}

/**
 * Staff shift definition
 */
export interface StaffShift {
  id: string;
  businessId: string;
  tenantId: string;
  
  name: string;
  startTime: string;  // HH:mm format
  endTime: string;    // HH:mm format
  
  applicableDays: DayOfWeek[];
  
  gracePeriodMinutes: number;
  
  createdAt: string;
  updatedAt: string;
}

/**
 * Days of week
 */
export enum DayOfWeek {
  MONDAY = 'monday',
  TUESDAY = 'tuesday',
  WEDNESDAY = 'wednesday',
  THURSDAY = 'thursday',
  FRIDAY = 'friday',
  SATURDAY = 'saturday',
  SUNDAY = 'sunday'
}

/**
 * ID card template
 */
export interface IDCardTemplate {
  id: string;
  businessId: string;
  tenantId: string;
  
  name: string;
  design: IDCardDesign;
  
  isDefault: boolean;
  
  createdAt: string;
  updatedAt: string;
}

/**
 * ID card design configuration
 */
export interface IDCardDesign {
  frontTemplate: string;
  backTemplate?: string;
  
  logoUrl?: string;
  primaryColor: string;
  secondaryColor?: string;
  
  fields: IDCardField[];
}

/**
 * ID card field definition
 */
export interface IDCardField {
  name: string;
  label: string;
  position: { x: number; y: number };
  fontSize: number;
  isVisible: boolean;
}

/**
 * Database table names (generic, not petrol-pump specific)
 */
export const TableNames = {
  STAFF: 'StaffMembers',
  STAFF_ATTENDANCE: 'StaffAttendance',
  STAFF_SHIFTS: 'StaffShifts',
  ID_CARD_TEMPLATES: 'IDCardTemplates',
  STAFF_ACTIVITY_LOG: 'StaffActivityLog'
} as const;

/**
 * Migration helper to convert from old schema
 */
export function migrateFromPetrolPumpSchema(oldRecord: any): StaffMember {
  return {
    id: oldRecord.id,
    businessId: oldRecord.petrolPumpId || oldRecord.businessId,
    businessType: oldRecord.businessType || BusinessType.PETROL_PUMP,
    tenantId: oldRecord.tenantId || oldRecord.cognitoSub || 'unknown',
    
    fullName: oldRecord.fullName || oldRecord.name,
    phoneNumber: oldRecord.phoneNumber || oldRecord.phone,
    email: oldRecord.email,
    address: oldRecord.address,
    
    role: oldRecord.role || StaffRole.ATTENDANT,
    department: oldRecord.department,
    joinDate: oldRecord.joinDate || new Date().toISOString(),
    employeeId: oldRecord.employeeId,
    
    isActive: oldRecord.isActive ?? true,
    isDeleted: oldRecord.isDeleted ?? false,
    deletedAt: oldRecord.deletedAt,
    
    config: {
      pumpAssignment: oldRecord.pumpAssignment,
      shiftPreference: oldRecord.shiftPreference,
      maxDiscountPercent: oldRecord.maxDiscountPercent,
      canApproveReturns: oldRecord.canApproveReturns,
      canEditPrices: oldRecord.canEditPrices,
      canViewReports: oldRecord.canViewReports
    },
    
    createdAt: oldRecord.createdAt || new Date().toISOString(),
    updatedAt: oldRecord.updatedAt || new Date().toISOString(),
    createdBy: oldRecord.createdBy || 'system'
  };
}

/**
 * Create partition key for DynamoDB (generic, not petrol-pump specific)
 */
export function createPartitionKey(businessId: string, staffId: string): string {
  return `BUSINESS#${businessId}#STAFF#${staffId}`;
}

/**
 * Create sort key for DynamoDB
 */
export function createSortKey(entityType: string, entityId: string): string {
  return `${entityType}#${entityId}`;
}

/**
 * Parse partition key to extract business and staff IDs
 */
export function parsePartitionKey(partitionKey: string): { businessId: string; staffId: string } {
  const parts = partitionKey.split('#');
  return {
    businessId: parts[1] || '',
    staffId: parts[3] || ''
  };
}
