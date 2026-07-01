// ============================================================================
// RBAC_Engine + Permission_Matrix — role-based access control (offline, local)
// ============================================================================
// Requirements 9.3 / 9.4:
//   • 9.3 — provide the Default_Role values owner, manager, cashier, viewer.
//   • 9.4 — enforce the Permission_Matrix for each module action based on the
//           authenticated user's role, and DENY any action not permitted for
//           that role with an indication that the action is "not permitted".
//
// The engine is a PURE, deterministic mapping (role → set of allowed module
// actions). It performs no I/O and holds no per-request state, so it is trivial
// to inject and to property-test (Property 21, task 9.7). The Permission_Matrix
// is built CUMULATIVELY so the design invariant always holds:
//
//     viewer ⊆ cashier ⊆ manager ⊆ owner
//
// i.e. owner ⊇ manager ⊇ cashier ⊇ viewer for shared actions, with owner/manager
// holding management actions that cashier/viewer lack (design "RBAC
// Permission_Matrix"). Building each role from the one below GUARANTEES the
// superset relation rather than relying on hand-maintained duplicate lists.
//
// Failure-closed: an unknown role, or an action not present in a role's allowed
// set, is denied with the "not permitted" indication.
// ============================================================================

// -- Roles (Req 9.3) ---------------------------------------------------------

/** The four Default_Role values (Req 9.3). */
export type Role = 'owner' | 'manager' | 'cashier' | 'viewer';

/**
 * The Default_Role set, ordered from least to most privileged. The order is
 * meaningful: the Permission_Matrix is layered in this sequence so each role
 * inherits every action of the role before it.
 */
export const DEFAULT_ROLES: readonly Role[] = ['viewer', 'cashier', 'manager', 'owner'] as const;

const ROLE_LOOKUP: ReadonlySet<string> = new Set<string>(DEFAULT_ROLES);

/** Type guard: is `value` one of the four Default_Role values? */
export function isRole(value: unknown): value is Role {
    return typeof value === 'string' && ROLE_LOOKUP.has(value);
}

// -- Module actions ----------------------------------------------------------
// Each action is a stable `module:action` string mirroring the Local_Backend
// REST surface (api.routes.ts) and the AWS handler authorization sets. Actions
// are typed as plain strings so the engine can deny UNKNOWN actions fail-closed
// rather than failing to compile; the documented catalogue is `ModuleActions`.

/** Catalogue of known module actions enforced by the Permission_Matrix. */
export const ModuleActions = {
    // Dashboard
    DashboardView: 'dashboard:view',
    // Inventory
    InventoryView: 'inventory:view',
    InventoryCreate: 'inventory:create',
    InventoryUpdate: 'inventory:update',
    InventoryDelete: 'inventory:delete',
    // Stock
    StockLookup: 'stock:lookup',
    StockAdd: 'stock:add',
    // Invoices / bills
    InvoicesView: 'invoices:view',
    InvoicesCreate: 'invoices:create',
    InvoicesFinalize: 'invoices:finalize',
    InvoicesSend: 'invoices:send',
    InvoicesVoid: 'invoices:void',
    // Payments
    PaymentsView: 'payments:view',
    PaymentsRecord: 'payments:record',
    // Customers
    CustomersView: 'customers:view',
    CustomersViewLedger: 'customers:view_ledger',
    CustomersManage: 'customers:manage',
    // Products
    ProductsView: 'products:view',
    ProductsManage: 'products:manage',
    // Reports
    ReportsView: 'reports:view',
    // Settings
    SettingsView: 'settings:view',
    SettingsManage: 'settings:manage',
    // Storage (S3 equivalent)
    StorageRead: 'storage:read',
    // Users / roles (role management is owner-only — see Req 9.5)
    UsersView: 'users:view',
    UsersManage: 'users:manage',
} as const;

/** A module action string (a value of `ModuleActions`, or any other string). */
export type ModuleAction = (typeof ModuleActions)[keyof typeof ModuleActions] | string;

// -- Cumulative action layers ------------------------------------------------

/** viewer — read-only across every module; no mutations whatsoever. */
const VIEWER_ACTIONS: readonly string[] = [
    ModuleActions.DashboardView,
    ModuleActions.InventoryView,
    ModuleActions.StockLookup,
    ModuleActions.InvoicesView,
    ModuleActions.PaymentsView,
    ModuleActions.CustomersView,
    ModuleActions.CustomersViewLedger,
    ModuleActions.ProductsView,
    ModuleActions.ReportsView,
    ModuleActions.SettingsView,
    ModuleActions.StorageRead,
];

/** cashier — viewer + point-of-sale operations (mirrors AWS CASHIER handlers). */
const CASHIER_ACTIONS: readonly string[] = [
    ...VIEWER_ACTIONS,
    ModuleActions.InvoicesCreate,
    ModuleActions.InvoicesFinalize,
    ModuleActions.InvoicesSend,
    ModuleActions.PaymentsRecord,
];

/** manager — cashier + catalogue/inventory management actions. */
const MANAGER_ACTIONS: readonly string[] = [
    ...CASHIER_ACTIONS,
    ModuleActions.InventoryCreate,
    ModuleActions.InventoryUpdate,
    ModuleActions.InventoryDelete,
    ModuleActions.StockAdd,
    ModuleActions.ProductsManage,
    ModuleActions.CustomersManage,
    ModuleActions.InvoicesVoid,
];

/** owner — manager + owner-only administration (settings, users/roles). */
const OWNER_ACTIONS: readonly string[] = [
    ...MANAGER_ACTIONS,
    ModuleActions.SettingsManage,
    ModuleActions.UsersView,
    ModuleActions.UsersManage,
];

/**
 * The Permission_Matrix (Req 9.4): each Default_Role mapped to its complete set
 * of allowed module actions. Frozen sets so callers cannot mutate the matrix at
 * runtime. Built from the cumulative layers above, guaranteeing the
 * viewer ⊆ cashier ⊆ manager ⊆ owner superset invariant.
 */
export const PERMISSION_MATRIX: Readonly<Record<Role, ReadonlySet<string>>> = Object.freeze({
    viewer: new Set(VIEWER_ACTIONS),
    cashier: new Set(CASHIER_ACTIONS),
    manager: new Set(MANAGER_ACTIONS),
    owner: new Set(OWNER_ACTIONS),
});

// -- Decision type -----------------------------------------------------------

/**
 * The outcome of a permission check. On denial it carries the stable
 * `not_permitted` reason and a human-readable message for the API envelope
 * (Req 9.4 — "an indication that the action is not permitted").
 */
export type PermissionDecision =
    | { allowed: true }
    | { allowed: false; reason: 'not_permitted'; message: string };

// -- Engine ------------------------------------------------------------------

/**
 * RBAC_Engine — resolves whether a role may perform a module action against the
 * Permission_Matrix. Stateless and side-effect free.
 *
 * Injectable/testable: the matrix can be overridden via the constructor (for
 * tests or future configuration); it defaults to the canonical PERMISSION_MATRIX.
 */
export class RbacEngine {
    private readonly matrix: Readonly<Record<Role, ReadonlySet<string>>>;

    constructor(matrix: Readonly<Record<Role, ReadonlySet<string>>> = PERMISSION_MATRIX) {
        this.matrix = matrix;
    }

    /** The Default_Role values this engine recognises (Req 9.3). */
    roles(): readonly Role[] {
        return DEFAULT_ROLES;
    }

    /**
     * The complete set of actions a role may perform. Returns an empty set for
     * an unrecognised role (fail-closed).
     */
    allowedActions(role: string): ReadonlySet<string> {
        return isRole(role) ? this.matrix[role] : new Set<string>();
    }

    /**
     * Decide whether `role` may perform `action` (Req 9.4).
     *
     * Returns `{ allowed: true }` when the action is in the role's allowed set;
     * otherwise returns a `not_permitted` denial — including for an unknown role
     * or an unknown action (fail-closed).
     */
    isAllowed(role: string, action: string): PermissionDecision {
        if (!isRole(role)) {
            return {
                allowed: false,
                reason: 'not_permitted',
                message: `Role '${role}' is not a recognised role; the action is not permitted.`,
            };
        }
        if (typeof action === 'string' && this.matrix[role].has(action)) {
            return { allowed: true };
        }
        return {
            allowed: false,
            reason: 'not_permitted',
            message: `Role '${role}' is not permitted to perform '${action}'.`,
        };
    }
}
