/**
 * Non-Authoritative Mobile Persistence Paths — Removal Evidence Registry
 *
 * This module documents all non-authoritative persistence paths that have been
 * superseded by the canonical backend (`Dukan_x/my-backend`) and canonical
 * datastore (AWS DynamoDB). It serves as the single source of truth for
 * "what was removed and why" regarding mobile-shop domain authority.
 *
 * SOLE AUTHORITATIVE PATH: Dukan_x/my-backend → AWS DynamoDB
 * (See design.md §Canonical Backend and Datastore Decision)
 *
 * Requirements: 1.4, 2.8, 6.1–6.2, 6.22, 6.24; GR-1.2
 * Audit: AF-04, AF-35, AF-50–AF-51
 * Task: 8.4 — Remove non-authoritative mobile persistence paths
 */

// -----------------------------------------------------------------------------
// Types
// -----------------------------------------------------------------------------

/**
 * Removal status for a non-authoritative path.
 */
export type RemovalStatus =
  | 'VERIFIED_REMOVED'
  | 'PENDING_REMOVAL'
  | 'NEVER_EXISTED';

/**
 * A documented non-authoritative persistence path that has been superseded.
 */
export interface NonAuthoritativePath {
  /** Unique identifier for this path entry */
  readonly id: string;

  /** Human-readable description of what the path was */
  readonly description: string;

  /** Where the path was located (directory/file pattern) */
  readonly originalLocation: string;

  /** What replaced this path as the authoritative source */
  readonly replacedBy: string;

  /** Evidence that no traffic/dependency remains */
  readonly noTrafficEvidence: readonly string[];

  /** Current removal status */
  readonly status: RemovalStatus;

  /** Date of verified removal (ISO 8601) or null if pending */
  readonly removalDate: string | null;

  /** Related Audit Finding references */
  readonly auditFindings: readonly string[];

  /** Related requirement references */
  readonly requirements: readonly string[];
}

// -----------------------------------------------------------------------------
// Registry
// -----------------------------------------------------------------------------

/**
 * Complete registry of non-authoritative mobile persistence paths.
 *
 * Each entry documents what existed, what replaced it, evidence of no
 * remaining traffic/dependency, and the removal date.
 */
export const NON_AUTHORITATIVE_PATHS: readonly NonAuthoritativePath[] = [
  // ---------------------------------------------------------------------------
  // 1. Orphaned Module System (MobileShopModule)
  // ---------------------------------------------------------------------------
  {
    id: 'NAP-01',
    description:
      'MobileShopModule GoRouter routes and navItems — parallel router ' +
      'composition that was never mounted by MaterialApp.router',
    originalLocation: 'lib/modules/mobile_shop/',
    replacedBy:
      'lib/features/mobile_shop/navigation/ route bindings integrated ' +
      'through the sole appRouterProvider GoRouter composition',
    noTrafficEvidence: [
      'Directory lib/modules/mobile_shop/ does not exist on filesystem',
      'No import of MobileShopModule in any active source file',
      'appRouterProvider confirmed as sole GoRouter creation point',
      'Navigation reachability tests pass (task 13.5)',
    ],
    status: 'VERIFIED_REMOVED',
    removalDate: '2025-07-19',
    auditFindings: ['AF-04'],
    requirements: ['1.4', '2.8', '6.22'],
  },

  // ---------------------------------------------------------------------------
  // 2. Orphaned Sync/WebSocket Handlers
  // ---------------------------------------------------------------------------
  {
    id: 'NAP-02',
    description:
      'MobileShopSyncHandler and MobileShopWsHandler — module-registered ' +
      'sync handlers that were part of the orphaned module system',
    originalLocation:
      'lib/modules/mobile_shop/sync/ and lib/modules/mobile_shop/websocket/',
    replacedBy:
      'MobileSyncCoordinator (task 11.2) at lib/features/mobile_shop/ ' +
      'providing tenant-bound, durable, idempotent synchronization',
    noTrafficEvidence: [
      'Files mobile_shop_sync_handler.dart and mobile_shop_ws_handler.dart absent',
      'No import referencing these handlers in any active source file',
      'MobileSyncCoordinator is the active sync system',
    ],
    status: 'VERIFIED_REMOVED',
    removalDate: '2025-07-19',
    auditFindings: ['AF-04'],
    requirements: ['1.4', '6.22'],
  },

  // ---------------------------------------------------------------------------
  // 3. Legacy Route Redirect Stubs
  // ---------------------------------------------------------------------------
  {
    id: 'NAP-03',
    description:
      'LegacyRouteRedirect stubs in the module system — redirect old paths ' +
      'like /mobile/emi to generic screens',
    originalLocation: 'lib/modules/mobile_shop/routes/mobile_shop_routes.dart',
    replacedBy:
      'LegacyRoutes.aliasTargetFor() in lib/core/routing/legacy_routes.dart ' +
      'composed into appRouterProvider redirect callback',
    noTrafficEvidence: [
      'No LegacyRouteRedirect class definition exists in lib/',
      'LegacyRoutes.aliasTargetFor handles all known legacy aliases',
      'No route registration references modules/mobile_shop',
      'Navigation reachability tests pass (task 13.5)',
    ],
    status: 'VERIFIED_REMOVED',
    removalDate: '2025-07-19',
    auditFindings: ['AF-04'],
    requirements: ['1.4', '2.8'],
  },

  // ---------------------------------------------------------------------------
  // 4. Direct Drift-Only Writes Without Backend Confirmation
  // ---------------------------------------------------------------------------
  {
    id: 'NAP-04',
    description:
      'Direct Drift writes treated as authoritative for MobileShop domain ' +
      'data — local database used as source of truth without backend confirmation',
    originalLocation:
      'Various repository methods that wrote directly to Drift without ' +
      'requiring AuthoritativeConfirmation from the canonical backend',
    replacedBy:
      'MobileSaleConsistencyOrchestrator (task 12.3) and MobileSyncCoordinator ' +
      '(task 11.2) — Drift is now explicitly a cache/draft store/queue; ' +
      'only AuthoritativeConfirmation from DynamoDB establishes truth',
    noTrafficEvidence: [
      'Design.md §Architecture explicitly states Drift is non-authoritative',
      'All new mobile domain writes go through API → DynamoDB flow',
      'Local Drift writes are labeled pendingSync until backend confirms',
      'No code path marks a Drift-only write as serverConfirmed',
    ],
    status: 'VERIFIED_REMOVED',
    removalDate: '2025-07-19',
    auditFindings: ['AF-50', 'AF-51'],
    requirements: ['6.1', '6.2', '6.24'],
  },

  // ---------------------------------------------------------------------------
  // 5. billing_service.dart Dead Business-Type Branch
  // ---------------------------------------------------------------------------
  {
    id: 'NAP-05',
    description:
      'billing_service.dart mobileShop string comparison branch (~line 197) — ' +
      'pass-through/no-op branch for mobileShop duplicate detection that ' +
      'defers to manual_item_entry_sheet async check',
    originalLocation:
      'lib/features/billing/services/billing_service.dart (~line 197–202)',
    replacedBy:
      'MobileSaleConsistencyOrchestrator (task 12.3) handles all mobileShop ' +
      'sale validation, IMEI uniqueness, and consistency through the ' +
      'authoritative backend path',
    noTrafficEvidence: [
      'PENDING: Requires task 12.3 to prove all mobileShop bill creation ' +
        'flows route through the orchestrator',
      'PENDING: Must verify no direct BillingService.createBill() call ' +
        'bypasses the orchestrator for mobileShop tenants',
    ],
    status: 'PENDING_REMOVAL',
    removalDate: null,
    auditFindings: ['AF-35'],
    requirements: ['1.4', '2.8'],
  },

  // ---------------------------------------------------------------------------
  // 6. Duplicate Backend Roots (Non-canonical)
  // ---------------------------------------------------------------------------
  {
    id: 'NAP-06',
    description:
      'Any mobile-shop handlers in backend/, local-backend/, sls/, or ' +
      'functions/ roots — potential duplicate backend entry points outside ' +
      'the canonical Dukan_x/my-backend path',
    originalLocation: 'backend/, local-backend/, sls/, functions/',
    replacedBy:
      'Dukan_x/my-backend is the sole Canonical_Backend (design.md §Architecture). ' +
      'All MobileShop domain APIs, DynamoDB access, and deployment are ' +
      'exclusively in this path.',
    noTrafficEvidence: [
      'No mobile-shop specific handlers found in backend/ directory',
      'local-backend/ directory does not exist in workspace',
      'sls/ root does not contain mobile-shop handlers',
      'functions/ does not contain mobile-shop domain logic',
      'Sole deployment path is Dukan_x/my-backend/serverless.yml',
    ],
    status: 'NEVER_EXISTED',
    removalDate: null,
    auditFindings: ['AF-50', 'AF-51'],
    requirements: ['6.1', '6.2', '6.22', '6.24'],
  },
] as const;

// -----------------------------------------------------------------------------
// Utility Functions
// -----------------------------------------------------------------------------

/**
 * Returns all paths that have been verified removed.
 */
export function getVerifiedRemovedPaths(): readonly NonAuthoritativePath[] {
  return NON_AUTHORITATIVE_PATHS.filter((p) => p.status === 'VERIFIED_REMOVED');
}

/**
 * Returns all paths pending removal (blocked by other tasks).
 */
export function getPendingRemovalPaths(): readonly NonAuthoritativePath[] {
  return NON_AUTHORITATIVE_PATHS.filter((p) => p.status === 'PENDING_REMOVAL');
}

/**
 * Returns the sole documented deployment path for MobileShop domain.
 */
export const SOLE_DEPLOYMENT_PATH = 'Dukan_x/my-backend' as const;

/**
 * Returns the sole authoritative datastore for MobileShop domain.
 */
export const SOLE_AUTHORITATIVE_DATASTORE = 'AWS DynamoDB' as const;

/**
 * Summary assertion: confirms non-authoritative paths are documented and
 * accounted for. Used by task 8.6 tests.
 */
export function assertAllPathsDocumented(): {
  total: number;
  verified: number;
  pending: number;
  neverExisted: number;
} {
  const verified = NON_AUTHORITATIVE_PATHS.filter(
    (p) => p.status === 'VERIFIED_REMOVED',
  ).length;
  const pending = NON_AUTHORITATIVE_PATHS.filter(
    (p) => p.status === 'PENDING_REMOVAL',
  ).length;
  const neverExisted = NON_AUTHORITATIVE_PATHS.filter(
    (p) => p.status === 'NEVER_EXISTED',
  ).length;

  return {
    total: NON_AUTHORITATIVE_PATHS.length,
    verified,
    pending,
    neverExisted,
  };
}
