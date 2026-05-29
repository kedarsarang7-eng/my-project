// ============================================================================
// CLINIC DATA DYNAMODB SCHEMA — Single-Table Design
// ============================================================================
// Table: ClinicData
// Pattern: PK + SK composite keys with GSIs for query flexibility
// Business Type: clinic (enforced via license validation)
// Data Isolation: tenantId + clinicId composite ensures complete isolation
// ============================================================================

export const ClinicDataTableConfig = {
  TableName: 'ClinicData',
  BillingMode: 'PAY_PER_REQUEST',
  
  // Primary Key Structure
  KeySchema: [
    { AttributeName: 'PK', KeyType: 'HASH' },
    { AttributeName: 'SK', KeyType: 'RANGE' },
  ],
  
  // Global Secondary Indexes
  GlobalSecondaryIndexes: [
    {
      IndexName: 'GSI1',
      KeySchema: [
        { AttributeName: 'GSI1PK', KeyType: 'HASH' },
        { AttributeName: 'GSI1SK', KeyType: 'RANGE' },
      ],
      Projection: { ProjectionType: 'ALL' },
    },
    {
      IndexName: 'GSI2',
      KeySchema: [
        { AttributeName: 'GSI2PK', KeyType: 'HASH' },
        { AttributeName: 'GSI2SK', KeyType: 'RANGE' },
      ],
      Projection: { ProjectionType: 'ALL' },
    },
    {
      IndexName: 'GSI3',
      KeySchema: [
        { AttributeName: 'GSI3PK', KeyType: 'HASH' },
        { AttributeName: 'GSI3SK', KeyType: 'RANGE' },
      ],
      Projection: { ProjectionType: 'ALL' },
    },
  ],
  
  // Attribute Definitions
  AttributeDefinitions: [
    { AttributeName: 'PK', AttributeType: 'S' },
    { AttributeName: 'SK', AttributeType: 'S' },
    { AttributeName: 'GSI1PK', AttributeType: 'S' },
    { AttributeName: 'GSI1SK', AttributeType: 'S' },
    { AttributeName: 'GSI2PK', AttributeType: 'S' },
    { AttributeName: 'GSI2SK', AttributeType: 'S' },
    { AttributeName: 'GSI3PK', AttributeType: 'S' },
    { AttributeName: 'GSI3SK', AttributeType: 'S' },
  ],
  
  // SSE with AWS KMS
  SSESpecification: {
    Enabled: true,
    SSEType: 'KMS',
  },
  
  // Point-in-time recovery
  PointInTimeRecoverySpecification: {
    PointInTimeRecoveryEnabled: true,
  },
};

// ============================================================================
// ENTITY KEY PATTERNS
// ============================================================================

export const ClinicKeys = {
  // Primary Keys
  clinicPK: (clinicId: string) => `CLINIC#${clinicId}`,
  patientSK: (patientId: string) => `PATIENT#${patientId}`,
  appointmentSK: (date: string, appointmentId: string) => `APPT#${date}#${appointmentId}`,
  staffSK: (role: string, userId: string) => `STAFF#${role}#${userId}`,
  doctorSK: (userId: string) => `STAFF#DOCTOR#${userId}`,
  billSK: (date: string, billId: string) => `BILL#${date}#${billId}`,
  inventorySK: (itemId: string) => `INVENTORY#${itemId}`,
  roomSK: (roomId: string) => `ROOM#${roomId}`,
  
  // GSI Keys
  gsi1DoctorDate: (doctorId: string, date: string) => `DOC#${doctorId}#${date}`,
  gsi2Date: (date: string) => `DATE#${date}`,
  gsi3Department: (dept: string) => `DEPT#${dept}`,
};

// ============================================================================
// ENTITY INTERFACES (TypeScript strict types)
// ============================================================================

export interface ClinicPatient {
  PK: string;                    // CLINIC#{clinicId}
  SK: string;                    // PATIENT#{patientId}
  GSI1PK?: string;               // For department lookups
  GSI1SK?: string;
  entityType: 'PATIENT';
  clinicId: string;
  tenantId: string;
  patientId: string;
  name: string;
  dob: string;                   // ISO 8601
  gender: 'male' | 'female' | 'other';
  phone: string;
  email?: string;
  bloodGroup?: string;
  address?: string;
  emergencyContact?: {
    name: string;
    phone: string;
    relation: string;
  };
  lastVisit: string;             // ISO 8601
  totalVisits: number;
  status: 'new' | 'returning' | 'inactive';
  department?: string;
  allergies?: string[];
  medicalHistory?: string[];
  createdAt: string;
  updatedAt: string;
}

export interface ClinicAppointment {
  PK: string;                    // CLINIC#{clinicId}
  SK: string;                    // APPT#{date}#{appointmentId}
  GSI1PK: string;                // DOC#{doctorId}
  GSI1SK: string;                // {date}#{startTime}
  GSI2PK: string;                // DATE#{date}
  GSI2SK: string;                // {startTime}#{appointmentId}
  entityType: 'APPOINTMENT';
  clinicId: string;
  tenantId: string;
  appointmentId: string;
  patientId: string;
  patientName: string;
  doctorId: string;
  doctorName: string;
  type: 'consultation' | 'follow-up' | 'procedure' | 'emergency' | 'checkup';
  status: 'scheduled' | 'completed' | 'cancelled' | 'no-show' | 'in-progress';
  startTime: string;             // ISO 8601
  endTime: string;               // ISO 8601
  date: string;                  // YYYY-MM-DD
  reason: string;
  notes?: string;
  roomId?: string;
  checkedInAt?: string;
  completedAt?: string;
  createdAt: string;
  updatedAt: string;
}

export interface ClinicStaff {
  PK: string;                    // CLINIC#{clinicId}
  SK: string;                    // STAFF#{role}#{userId} or STAFF#DOCTOR#{userId}
  GSI1PK?: string;               // For availability queries
  GSI1SK?: string;               // STATUS#{status}
  entityType: 'STAFF';
  clinicId: string;
  tenantId: string;
  userId: string;
  name: string;
  email: string;
  phone?: string;
  role: 'admin' | 'doctor' | 'nurse' | 'receptionist' | 'lab_tech' | 'pharmacist';
  specialization?: string;       // For doctors
  department?: string;
  status: 'on-duty' | 'off-duty' | 'on-leave' | 'busy';
  isOnDuty: boolean;
  shiftStart?: string;           // ISO 8601
  shiftEnd?: string;             // ISO 8601
  roomAssigned?: string;
  checkInTime?: string;
  checkOutTime?: string;
  totalAppointmentsToday: number;
  licenseNumber?: string;        // For doctors
  createdAt: string;
  updatedAt: string;
}

export interface ClinicBilling {
  PK: string;                    // CLINIC#{clinicId}
  SK: string;                    // BILL#{date}#{billId}
  GSI1PK: string;                // DATE#{date}
  GSI1SK: string;                // {createdAt}#{billId}
  GSI2PK?: string;               // PATIENT#{patientId}
  GSI2SK?: string;               // {date}#{billId}
  entityType: 'BILLING';
  clinicId: string;
  tenantId: string;
  billId: string;
  patientId: string;
  patientName: string;
  appointmentId?: string;
  items: Array<{
    description: string;
    code?: string;
    quantity: number;
    unitPriceCents: number;
    totalCents: number;
  }>;
  subtotalCents: number;
  taxCents: number;
  discountCents: number;
  totalCents: number;
  amountPaidCents: number;
  balanceCents: number;
  status: 'paid' | 'pending' | 'overdue' | 'partial' | 'cancelled';
  paymentMethod?: 'cash' | 'card' | 'upi' | 'insurance' | 'netbanking';
  insuranceProvider?: string;
  date: string;                  // YYYY-MM-DD
  dueDate?: string;
  paidAt?: string;
  createdAt: string;
  updatedAt: string;
}

export interface ClinicInventory {
  PK: string;                    // CLINIC#{clinicId}
  SK: string;                    // INVENTORY#{itemId}
  GSI1PK?: string;               // CATEGORY#{category}
  GSI1SK?: string;               // {quantity}#{itemName}
  entityType: 'INVENTORY';
  clinicId: string;
  tenantId: string;
  itemId: string;
  itemName: string;
  category: 'medicine' | 'equipment' | 'consumable' | 'vaccine' | 'surgical';
  subCategory?: string;
  quantity: number;
  unit: string;
  minThreshold: number;
  reorderPoint: number;
  reorderQty: number;
  location?: string;
  supplier?: string;
  costPerUnitCents: number;
  lastRestocked?: string;
  expiryDate?: string;
  batchNumber?: string;
  status: 'in-stock' | 'low-stock' | 'out-of-stock' | 'expired';
  createdAt: string;
  updatedAt: string;
}

export interface ClinicRoom {
  PK: string;                    // CLINIC#{clinicId}
  SK: string;                    // ROOM#{roomId}
  GSI1PK?: string;               // STATUS#{status}
  GSI1SK?: string;               // {roomNumber}
  entityType: 'ROOM';
  clinicId: string;
  tenantId: string;
  roomId: string;
  roomNumber: string;
  type: 'consultation' | 'procedure' | 'ward' | 'emergency' | 'lab' | 'pharmacy';
  status: 'available' | 'occupied' | 'cleaning' | 'maintenance';
  floor?: string;
  capacity?: number;
  currentPatientId?: string;
  currentPatientName?: string;
  assignedDoctorId?: string;
  assignedDoctorName?: string;
  appointmentId?: string;
  nextAvailableAt?: string;
  equipment?: string[];
  createdAt: string;
  updatedAt: string;
}

export interface ClinicLicense {
  PK: string;                    // LICENSE#{licenseKey}
  SK: string;                    // META
  entityType: 'LICENSE';
  licenseKey: string;
  tenantId: string;
  businessType: string;          // Must be "clinic"
  tier: 'basic' | 'standard' | 'premium' | 'enterprise';
  clinicId: string;
  features: string[];
  maxUsers: number;
  maxPatients: number;
  isActive: boolean;
  issuedAt: string;
  expiresAt: string;
  renewedAt?: string;
  createdAt: string;
  updatedAt: string;
}

// ============================================================================
// TYPE GUARDS
// ============================================================================

export function isClinicPatient(item: unknown): item is ClinicPatient {
  const p = item as ClinicPatient;
  return p?.entityType === 'PATIENT' && typeof p.patientId === 'string';
}

export function isClinicAppointment(item: unknown): item is ClinicAppointment {
  const a = item as ClinicAppointment;
  return a?.entityType === 'APPOINTMENT' && typeof a.appointmentId === 'string';
}

export function isClinicStaff(item: unknown): item is ClinicStaff {
  const s = item as ClinicStaff;
  return s?.entityType === 'STAFF' && typeof s.userId === 'string';
}

export function isClinicBilling(item: unknown): item is ClinicBilling {
  const b = item as ClinicBilling;
  return b?.entityType === 'BILLING' && typeof b.billId === 'string';
}

export function isClinicInventory(item: unknown): item is ClinicInventory {
  const i = item as ClinicInventory;
  return i?.entityType === 'INVENTORY' && typeof i.itemId === 'string';
}

export function isClinicRoom(item: unknown): item is ClinicRoom {
  const r = item as ClinicRoom;
  return r?.entityType === 'ROOM' && typeof r.roomId === 'string';
}
