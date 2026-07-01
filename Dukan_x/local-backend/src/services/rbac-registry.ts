// ============================================================================
// RBAC Registry — injectable seams for the RBAC subsystem (task 9.3)
// ============================================================================
// Mirrors auth-service-registry.ts: the route/middleware layers resolve the
// shared RBAC singletons here rather than constructing them inline, so wiring
// (Local_Store-backed RoleStore, the process-wide Session_Registry) is supplied
// once at startup and the request path stays free of construction concerns.
//
//   • RbacEngine        — stateless Permission_Matrix evaluator (Req 9.4). A
//                         canonical default instance is always available.
//   • SessionRegistry   — process-wide active-session tracker (Req 9.6).
//   • RoleChangeService — applies local role changes + targeted invalidation
//                         (Req 9.5 / 9.6); registered once its RoleStore (the
//                         SQLCipher users-table writer) is wired at startup.
// ============================================================================

import { RbacEngine } from './rbac-engine';
import { SessionRegistry } from './session-registry';
import { RoleChangeService } from './role-change.service';

// -- RBAC_Engine -------------------------------------------------------------
// The engine is pure and configuration-free, so a single canonical instance is
// shared by default. A custom engine can still be injected (e.g. for tests).

let engineInstance: RbacEngine = new RbacEngine();

/** Override the shared RBAC_Engine (rarely needed; primarily for tests). */
export function setRbacEngine(engine: RbacEngine): void {
    engineInstance = engine;
}

/** Resolve the shared RBAC_Engine (always available). */
export function getRbacEngine(): RbacEngine {
    return engineInstance;
}

// -- Session_Registry --------------------------------------------------------
// One registry per backend process so role-change invalidation reaches the same
// sessions the Offline_Auth_Service registers at login.

let sessionRegistryInstance: SessionRegistry = new SessionRegistry();

/** Override the process-wide Session_Registry (primarily for tests). */
export function setSessionRegistry(registry: SessionRegistry): void {
    sessionRegistryInstance = registry;
}

/** Resolve the process-wide Session_Registry (always available). */
export function getSessionRegistry(): SessionRegistry {
    return sessionRegistryInstance;
}

// -- Role_Change_Service -----------------------------------------------------
// Requires a Local_Store-backed RoleStore, wired at startup. Until then the
// role-change route reports the feature unavailable rather than guessing.

let roleChangeInstance: RoleChangeService | null = null;

/** Register the live Role_Change_Service (called by startup/store wiring). */
export function setRoleChangeService(service: RoleChangeService | null): void {
    roleChangeInstance = service;
}

/** Resolve the registered Role_Change_Service, or null if not yet wired. */
export function getRoleChangeService(): RoleChangeService | null {
    return roleChangeInstance;
}
