// ============================================================================
// Role_Change_Service — local role changes + targeted session invalidation
// ============================================================================
// Requirements 9.5 / 9.6:
//   • 9.5 — when a Super_Admin or owner changes a user's role, apply the new
//           role WITHOUT requiring internet access (purely local).
//   • 9.6 — when a user's role changes, invalidate EXACTLY that user's active
//           sessions and require that user to re-authenticate before any
//           further action.
//
// This service composes the RBAC_Engine (valid target roles), an injectable
// RoleStore (the local SQLCipher `users` table write — no network), and the
// Session_Registry (per-user, surgical session invalidation). It performs NO
// network I/O of any kind: the role write is a local store update and the
// session revocation is in-process, so role changes work fully offline (Req 9.5).
//
// Authorization (Req 9.5): only a Super_Admin or an `owner` may change a role.
// Anyone else is denied with a "not permitted" indication and no change is made.
// ============================================================================

import { isRole, Role } from './rbac-engine';
import { SessionRegistry } from './session-registry';

/**
 * Injectable seam for the LOCAL persistence of a user's role. A concrete
 * implementation updates the SQLCipher Local_Store `users` table using
 * parameterized SQL ONLY (Req 17.9) and performs NO network call (Req 9.5).
 * Returns false when the target user does not exist.
 */
export interface RoleStore {
    /** Persist `role` for `userId` locally. Returns true if a row was updated. */
    updateUserRole(userId: string, role: Role): Promise<boolean>;
}

/** The actor requesting the role change (used for the authorization gate). */
export interface RoleChangeActor {
    /** The actor's user id (informational/auditing). */
    userId: string;
    /** The actor's role. */
    role: string;
    /** True when the actor carries the Super_Admin override (Req 9.5). */
    isSuperAdmin?: boolean;
}

/** Discriminated result of a role-change attempt. */
export type RoleChangeResult =
    | {
          ok: true;
          /** The user whose role changed. */
          userId: string;
          /** The newly applied role. */
          role: Role;
          /** Count of the target user's sessions invalidated (Req 9.6). */
          sessionsInvalidated: number;
      }
    | {
          ok: false;
          /**
           * Stable reason code:
           *   • `not_permitted`    — actor is neither Super_Admin nor owner (Req 9.5)
           *   • `invalid_role`     — requested role is not a Default_Role
           *   • `user_not_found`   — target user does not exist in the Local_Store
           */
          reason: 'not_permitted' | 'invalid_role' | 'user_not_found';
          message: string;
      };

/**
 * Role_Change_Service — applies a role change locally and invalidates exactly
 * the affected user's sessions. Injectable for testing (Property 19, task 9.6).
 */
export class RoleChangeService {
    constructor(
        private readonly roleStore: RoleStore,
        private readonly sessions: SessionRegistry,
    ) {}

    /**
     * Change `targetUserId`'s role to `newRole`, requested by `actor`.
     *
     * Order of operations:
     *   1. Authorize the actor (Super_Admin or owner) — else `not_permitted`.
     *   2. Validate `newRole` is a Default_Role — else `invalid_role`.
     *   3. Persist the new role LOCALLY (no internet) — else `user_not_found`.
     *   4. Invalidate EXACTLY the target user's sessions (Req 9.6).
     *
     * The store write precedes session invalidation so that a failed write
     * leaves both the role AND the user's sessions untouched.
     */
    async changeRole(
        actor: RoleChangeActor,
        targetUserId: string,
        newRole: string,
    ): Promise<RoleChangeResult> {
        // (1) Authorization — only Super_Admin or owner (Req 9.5).
        const authorized = actor.isSuperAdmin === true || actor.role === 'owner';
        if (!authorized) {
            return {
                ok: false,
                reason: 'not_permitted',
                message: 'Only a Super_Admin or owner may change a user role.',
            };
        }

        // (2) Validate the requested role is one of the Default_Role values.
        if (!isRole(newRole)) {
            return {
                ok: false,
                reason: 'invalid_role',
                message: `'${newRole}' is not a valid role. Expected one of: owner, manager, cashier, viewer.`,
            };
        }

        if (typeof targetUserId !== 'string' || targetUserId.trim().length === 0) {
            return {
                ok: false,
                reason: 'user_not_found',
                message: 'A target user id is required.',
            };
        }

        // (3) Apply the role change LOCALLY — purely a Local_Store write, no
        //     network access of any kind (Req 9.5).
        const updated = await this.roleStore.updateUserRole(targetUserId, newRole);
        if (!updated) {
            return {
                ok: false,
                reason: 'user_not_found',
                message: `No user with id '${targetUserId}' exists in the Local_Store.`,
            };
        }

        // (4) Invalidate EXACTLY this user's sessions so the new role takes
        //     effect only after re-authentication (Req 9.6). No other user's
        //     sessions are touched.
        const sessionsInvalidated = this.sessions.invalidateUserSessions(targetUserId);

        return { ok: true, userId: targetUserId, role: newRole, sessionsInvalidated };
    }
}
