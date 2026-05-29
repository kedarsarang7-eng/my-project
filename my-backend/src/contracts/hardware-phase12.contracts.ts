export type ModuleKey =
    | 'pos'
    | 'inventory'
    | 'purchase'
    | 'suppliers'
    | 'party_credit'
    | 'gst'
    | 'reports'
    | 'settings';

export type ActionKey = 'view' | 'create' | 'edit' | 'delete' | 'approve' | 'print' | 'export';

export type RoleKey = 'owner' | 'admin' | 'manager' | 'accountant' | 'cashier' | 'staff' | 'delivery';

export interface PermissionRule {
    module: ModuleKey;
    action: ActionKey;
    allowedRoles: RoleKey[];
}

export const PHASE12_PERMISSION_MATRIX: PermissionRule[] = [
    { module: 'pos', action: 'view', allowedRoles: ['owner', 'admin', 'manager', 'cashier', 'staff'] },
    { module: 'pos', action: 'create', allowedRoles: ['owner', 'admin', 'manager', 'cashier'] },
    { module: 'pos', action: 'edit', allowedRoles: ['owner', 'admin', 'manager'] },
    { module: 'pos', action: 'delete', allowedRoles: ['owner', 'admin'] },
    { module: 'pos', action: 'print', allowedRoles: ['owner', 'admin', 'manager', 'cashier'] },
    { module: 'inventory', action: 'view', allowedRoles: ['owner', 'admin', 'manager', 'cashier', 'staff'] },
    { module: 'inventory', action: 'create', allowedRoles: ['owner', 'admin', 'manager'] },
    { module: 'inventory', action: 'edit', allowedRoles: ['owner', 'admin', 'manager'] },
    { module: 'inventory', action: 'delete', allowedRoles: ['owner', 'admin'] },
    { module: 'purchase', action: 'view', allowedRoles: ['owner', 'admin', 'manager', 'accountant'] },
    { module: 'purchase', action: 'create', allowedRoles: ['owner', 'admin', 'manager', 'accountant'] },
    { module: 'purchase', action: 'approve', allowedRoles: ['owner', 'admin', 'manager'] },
    { module: 'suppliers', action: 'view', allowedRoles: ['owner', 'admin', 'manager', 'accountant'] },
    { module: 'suppliers', action: 'create', allowedRoles: ['owner', 'admin', 'manager', 'accountant'] },
    { module: 'party_credit', action: 'view', allowedRoles: ['owner', 'admin', 'manager', 'accountant'] },
    { module: 'party_credit', action: 'create', allowedRoles: ['owner', 'admin', 'manager', 'cashier', 'accountant'] },
    { module: 'gst', action: 'view', allowedRoles: ['owner', 'admin', 'accountant'] },
    { module: 'gst', action: 'export', allowedRoles: ['owner', 'admin', 'accountant'] },
    { module: 'reports', action: 'view', allowedRoles: ['owner', 'admin', 'manager', 'accountant'] },
    { module: 'reports', action: 'export', allowedRoles: ['owner', 'admin', 'accountant'] },
    { module: 'settings', action: 'view', allowedRoles: ['owner', 'admin'] },
    { module: 'settings', action: 'edit', allowedRoles: ['owner', 'admin'] },
];

export const PHASE12_API_CONTRACT = {
    purchaseOrder: {
        create: { path: '/hardware/purchase-orders', method: 'POST' },
        list: { path: '/hardware/purchase-orders', method: 'GET' },
        updateStatus: { path: '/hardware/purchase-orders/{id}/status', method: 'POST' },
    },
    grn: {
        create: { path: '/hardware/grn', method: 'POST' },
        list: { path: '/hardware/grn', method: 'GET' },
    },
    purchaseBill: {
        create: { path: '/hardware/purchase-bills', method: 'POST' },
        list: { path: '/hardware/purchase-bills', method: 'GET' },
        return: { path: '/hardware/purchase-bills/{id}/return', method: 'POST' },
    },
    partyCredit: {
        createParty: { path: '/hardware/parties', method: 'POST' },
        listParties: { path: '/hardware/parties', method: 'GET' },
        postLedger: { path: '/hardware/parties/{id}/ledger', method: 'POST' },
        getLedger: { path: '/hardware/parties/{id}/ledger', method: 'GET' },
        getAging: { path: '/hardware/parties-aging', method: 'GET' },
    },
} as const;
