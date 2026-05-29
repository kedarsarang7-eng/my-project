// ============================================================================
// ROLES & PERMISSIONS CONSTANTS
// ============================================================================

import { StaffPermissions, StaffRole } from '../types/staff';

export const VALID_ROLES: StaffRole[] = [
  'pump_operator',
  'cashier',
  'supervisor',
  'manager',
  'admin'
];

export const ROLE_DISPLAY_NAMES: Record<StaffRole, string> = {
  pump_operator: 'Pump Operator',
  cashier: 'Cashier',
  supervisor: 'Supervisor',
  manager: 'Manager',
  admin: 'Admin'
};

export const ROLE_COLORS: Record<StaffRole, string> = {
  pump_operator: '#F59E0B', // amber/orange
  cashier: '#10B981', // green
  supervisor: '#8B5CF6', // purple
  manager: '#3B82F6', // blue
  admin: '#EF4444' // red
};

// Default permissions by role
export const DEFAULT_PERMISSIONS: Record<StaffRole, StaffPermissions> = {
  pump_operator: {
    canDispenseFuel: true,
    canEditFuelLogs: false,
    canViewSalesReport: false,
    canProcessPayments: false,
    canApplyDiscounts: false,
    canViewCashDrawer: false,
    canCloseDayShift: false,
    canViewInventory: false,
    canUpdateInventory: false,
    canOrderStock: false,
    canViewOtherStaff: false,
    canManageAttendance: false,
    canExportReports: false,
    canViewAllShiftReports: false,
    canViewOwnShiftReport: true
  },
  
  cashier: {
    canDispenseFuel: false,
    canEditFuelLogs: false,
    canViewSalesReport: true,
    canProcessPayments: true,
    canApplyDiscounts: true,
    canViewCashDrawer: true,
    canCloseDayShift: false,
    canViewInventory: true,
    canUpdateInventory: false,
    canOrderStock: false,
    canViewOtherStaff: false,
    canManageAttendance: false,
    canExportReports: false,
    canViewAllShiftReports: false,
    canViewOwnShiftReport: true
  },
  
  supervisor: {
    canDispenseFuel: true,
    canEditFuelLogs: true,
    canViewSalesReport: true,
    canProcessPayments: true,
    canApplyDiscounts: true,
    canViewCashDrawer: true,
    canCloseDayShift: false,
    canViewInventory: true,
    canUpdateInventory: true,
    canOrderStock: false,
    canViewOtherStaff: true,
    canManageAttendance: true,
    canExportReports: false,
    canViewAllShiftReports: true,
    canViewOwnShiftReport: true
  },
  
  manager: {
    canDispenseFuel: true,
    canEditFuelLogs: true,
    canViewSalesReport: true,
    canProcessPayments: true,
    canApplyDiscounts: true,
    canViewCashDrawer: true,
    canCloseDayShift: true,
    canViewInventory: true,
    canUpdateInventory: true,
    canOrderStock: true,
    canViewOtherStaff: true,
    canManageAttendance: true,
    canExportReports: true,
    canViewAllShiftReports: true,
    canViewOwnShiftReport: true
  },
  
  admin: {
    canDispenseFuel: true,
    canEditFuelLogs: true,
    canViewSalesReport: true,
    canProcessPayments: true,
    canApplyDiscounts: true,
    canViewCashDrawer: true,
    canCloseDayShift: true,
    canViewInventory: true,
    canUpdateInventory: true,
    canOrderStock: true,
    canViewOtherStaff: true,
    canManageAttendance: true,
    canExportReports: true,
    canViewAllShiftReports: true,
    canViewOwnShiftReport: true
  }
};

// Cognito Groups
export const COGNITO_GROUPS = {
  OWNER: 'Owner',
  MANAGER: 'Manager',
  CASHIER: 'Cashier',
  ATTENDANT: 'Attendant',
  SUPERVISOR: 'Supervisor'
} as const;
