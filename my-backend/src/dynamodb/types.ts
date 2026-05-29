// ============================================================================
// DynamoDB Multi-Tenant Types — Ported from sls/app-backend
// ============================================================================
// SECURITY INVARIANT: tenant_id and business_id are ALWAYS extracted from
// the verified JWT (Cognito) token. They NEVER come from request body.
// ============================================================================

// ---- Roles ----

export type UserRole =
  | 'owner'
  | 'admin'
  | 'superadmin'
  | 'manager'
  | 'cashier'
  | 'accountant'
  | 'staff'
  | 'viewer';

export const OWNER_ROLES: ReadonlySet<UserRole> = new Set<UserRole>([
  'owner',
  'admin',
  'superadmin',
]);

export const BUSINESS_SCOPED_ROLES: ReadonlySet<UserRole> = new Set<UserRole>([
  'manager',
  'cashier',
  'accountant',
  'staff',
  'viewer',
]);

// ---- Business Types ----

export type BusinessType =
  | 'grocery'
  | 'pharmacy'
  | 'hardware'
  | 'petrol_pump';

// ---- Tenant Context ----

export interface TenantContext {
  readonly userId: string;
  readonly tenantId: string;
  readonly businessId: string;
  readonly role: UserRole;
  readonly email: string;
  readonly groups: readonly string[];
  readonly isOwner: boolean;
  readonly hasCrossBusinessAccess: boolean;
}

// ---- Business Context ----

export interface BusinessContext {
  readonly businessId: string;
  readonly tenantId: string;
  readonly name: string;
  readonly businessType: BusinessType;
  readonly gstin: string;
  readonly address: string;
  readonly phone: string;
  readonly email: string;
  readonly isActive: boolean;
  readonly subscriptionPlan: string;
  readonly subscriptionValidUntil: string | null;
  readonly settings: Record<string, unknown>;
  readonly createdAt: string;
  readonly updatedAt: string;
}

// ---- Entity Interfaces ----

export interface BaseEntity {
  readonly PK: string;
  readonly SK: string;
  readonly tenant_id: string;
  readonly business_id: string;
  readonly entity_type: string;
  readonly created_at: string;
  readonly updated_at: string;
  readonly version: number;
  readonly is_deleted: boolean;
  readonly created_by: string;
  readonly updated_by: string;
  readonly GSI1PK?: string;
  readonly GSI1SK?: string;
  readonly GSI2PK?: string;
  readonly GSI2SK?: string;
  readonly GSI3PK?: string;
  readonly GSI3SK?: string;
}

// ---- Bill ----

export interface DynamoDBBillItem {
  readonly productId: string;
  readonly productName: string;
  readonly qty: number;
  readonly price: number;
  readonly total: number;
  readonly unit: string;
  readonly hsn: string;
  readonly gstRate: number;
  readonly discount: number;
  readonly cgst: number;
  readonly sgst: number;
  readonly igst: number;
  readonly batchId?: string;
  readonly batchNo?: string;
  readonly expiryDate?: string;
  readonly doctorName?: string;
  readonly serialNo?: string;
  readonly warrantyMonths?: number;
  readonly costPrice?: number;
  readonly billingUnit?: string;
  readonly conversionFactor?: number;
  readonly nozzleId?: string;
  readonly dispenserId?: string;
  readonly vehicleNumber?: string;
}

export interface DynamoDBBill extends BaseEntity {
  readonly entity_type: 'BILL';
  readonly bill_id: string;
  readonly invoiceNumber: string;
  readonly customerId: string;
  readonly customerName: string;
  readonly customerPhone: string;
  readonly customerAddress: string;
  readonly customerGst: string;
  readonly customerEmail?: string;
  readonly date: string;
  readonly items: DynamoDBBillItem[];
  readonly subtotalPaise: number;
  readonly totalTaxPaise: number;
  readonly grandTotalPaise: number;
  readonly paidAmountPaise: number;
  readonly cashPaidPaise: number;
  readonly onlinePaidPaise: number;
  readonly discountAppliedPaise: number;
  readonly status: 'Draft' | 'Unpaid' | 'Partial' | 'Paid';
  readonly paymentType: 'Cash' | 'UPI' | 'Card' | 'Credit' | 'Online' | 'Mixed';
  readonly businessType: BusinessType;
  readonly shopName: string;
  readonly shopAddress: string;
  readonly shopGst: string;
  readonly shopContact: string;
  readonly source: 'MANUAL' | 'VOICE' | 'POS' | 'API';
  readonly printCount: number;
  readonly shiftId?: string;
  readonly prescriptionId?: string;
  readonly vehicleNumber?: string;
  readonly fuelType?: string;
  readonly tableNumber?: string;
  readonly waiterId?: string;
  readonly attendantId?: string;
  readonly nozzleId?: string;
  readonly dispenserId?: string;
  readonly paymentSplit?: {
    cashPaise: number;
    upiPaise: number;
    cardPaise: number;
    creditPaise: number;
  };
}

// ---- Product ----

export interface DynamoDBProduct extends BaseEntity {
  readonly entity_type: 'PRODUCT';
  readonly product_id: string;
  readonly name: string;
  readonly sku: string;
  readonly price: number;
  readonly stockQty: number;
  readonly unit: string;
  readonly hsn: string;
  readonly gstRate: number;
  readonly category: string;
  readonly businessType: BusinessType;
  readonly batchNo?: string;
  readonly expiryDate?: string;
  readonly drugSchedule?: string;
  readonly manufacturer?: string;
  readonly costPrice?: number;
  readonly minStockLevel?: number;
}

// ---- Customer ----

export interface DynamoDBCustomer extends BaseEntity {
  readonly entity_type: 'CUSTOMER';
  readonly customer_id: string;
  readonly name: string;
  readonly phone: string;
  readonly email?: string;
  readonly address?: string;
  readonly gstin?: string;
  readonly balancePaise: number;
  readonly isBlacklisted: boolean;
  readonly blacklistReason?: string;
  readonly blacklistDate?: string;
  readonly totalDuesPaise: number;
  readonly creditLimitPaise: number;
}

// ---- Staff ----

export interface DynamoDBStaff extends BaseEntity {
  readonly entity_type: 'STAFF';
  readonly staff_id: string;
  readonly cognitoSub: string;
  readonly name: string;
  readonly phone: string;
  readonly email?: string;
  readonly role: UserRole;
  readonly permissions: string[];
  readonly isActive: boolean;
}

// ---- Audit Entry ----

export interface AuditEntry extends BaseEntity {
  readonly entity_type: 'AUDIT';
  readonly audit_id: string;
  readonly action:
    | 'CREATE'
    | 'UPDATE'
    | 'DELETE'
    | 'SOFT_DELETE'
    | 'RESTORE'
    | 'PAYMENT'
    | 'REFUND'
    | 'GST_FILING'
    | 'CREDIT_NOTE'
    | 'STOCK_ADJUST'
    | 'PRICE_CHANGE'
    | 'LOGIN'
    | 'PERMISSION_CHANGE';
  readonly targetEntityType: string;
  readonly targetEntityId: string;
  readonly oldValue: Record<string, unknown> | null;
  readonly newValue: Record<string, unknown> | null;
  readonly isGstRelated: boolean;
  readonly ipAddress: string;
  readonly userAgent: string;
  readonly metadata?: Record<string, unknown>;
}
