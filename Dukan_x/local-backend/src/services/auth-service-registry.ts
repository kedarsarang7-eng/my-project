// ============================================================================
// Auth Service Registry — injectable seam for the Offline_Auth_Service
// ============================================================================
// The Offline_Auth_Service needs a `UserLookup` bound to the SQLCipher
// Local_Store. That store's Node-side access layer is provisioned by later
// store tasks (and the Backend_Supervisor at startup), so the concrete service
// is REGISTERED here at runtime rather than constructed inside the route layer.
//
// This keeps the route handlers free of any store/key wiring (a clean seam):
//   • startup wiring calls `setOfflineAuthService(new OfflineAuthService(lookup))`
//   • the /auth/login route resolves it via `getOfflineAuthService()`
//   • until a service is registered, the route reports the feature unavailable
//     instead of guessing at credentials.
// ============================================================================

import { OfflineAuthService } from './offline-auth.service';

let instance: OfflineAuthService | null = null;

/** Register the live Offline_Auth_Service (called by startup/store wiring). */
export function setOfflineAuthService(service: OfflineAuthService | null): void {
    instance = service;
}

/** Resolve the registered Offline_Auth_Service, or null if not yet wired. */
export function getOfflineAuthService(): OfflineAuthService | null {
    return instance;
}
