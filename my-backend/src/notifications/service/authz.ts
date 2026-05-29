// ============================================================================
// Notification_Service — Authorization
// ============================================================================
// Two distinct authorization paths (REQ 4.10, 4.11, 12.1):
//
//   1. Caller authorization on `createNotification` — verifies that the
//      caller is allowed to emit on behalf of the supplied `actor_id`.
//      A failed check rejects the call WITHOUT persisting anything.
//
//   2. Per-recipient authorization on `dispatch` — for every prospective
//      recipient R, evaluates `(event_name, target_id)` against R's RBAC.
//      Recipients that fail are SILENTLY OMITTED from the dispatch.
//
// We expose interfaces here rather than concrete RBAC code so this module
// stays decoupled from HTTP / Cognito / permission-matrix concerns. The
// production wiring (task 14.1) injects the real implementations; tests
// inject stubs.
// ============================================================================

import type { CreateNotificationCaller, CreateNotificationInput } from './types';
import { AuthorizationError } from './errors';
import { logger } from '../../utils/logger';

// ---- Per-recipient authorizer --------------------------------------------

/**
 * Predicate used by `Notification_Service.dispatch` to decide whether each
 * prospective recipient is allowed to receive a delivery for a given
 * `(event_name, target_id)` pair.
 *
 * Implementations:
 *   - MUST be pure with respect to their inputs (no side effects).
 *   - SHOULD be cheap enough to call once per recipient per dispatch
 *     (the property test in task 6.3 generates large recipient lists).
 *   - MUST return `false` (rather than throwing) for routine deny decisions.
 *     Throwing is reserved for unexpected failures (e.g. RBAC store
 *     unavailable); the dispatcher logs and treats those as a deny.
 */
export interface RecipientAuthorizer {
    canReceive(args: CanReceiveArgs): Promise<boolean>;
}

export interface CanReceiveArgs {
    readonly user_id: string;
    readonly role: string;
    readonly event_name: string;
    readonly target_id: string | null;
}

/**
 * Default authorizer that ALLOWS every recipient.
 *
 * Why: the authorizer is wired in by the API layer (task 14.1) once the
 * full RBAC plumbing — JWT context, permission-matrix lookups, customer-vs-
 * internal pool resolution — is connected. Until then, the service stays
 * functional in unit tests and in the staging harness without a half-
 * implemented RBAC mock that could mask real authorization failures.
 *
 * The corresponding TODO is tracked by task 14.1 ("Migrate ... wire every
 * remaining Trigger_Point to a `createNotification` call"); migrating to
 * the real authorizer is a single import-swap once that task lands.
 */
export class AllowAllRecipientAuthorizer implements RecipientAuthorizer {
    public async canReceive(_args: CanReceiveArgs): Promise<boolean> {
        return true;
    }
}

/**
 * Convenience authorizer backed by an in-memory predicate. Used by tests
 * and by simple seeding workflows so callers do not have to subclass.
 */
export class PredicateRecipientAuthorizer implements RecipientAuthorizer {
    constructor(
        private readonly predicate: (args: CanReceiveArgs) => boolean | Promise<boolean>,
    ) {}

    public async canReceive(args: CanReceiveArgs): Promise<boolean> {
        try {
            return await Promise.resolve(this.predicate(args));
        } catch (err) {
            logger.warn(
                'Recipient authorizer predicate threw; treating as deny.',
                {
                    user_id: args.user_id,
                    event_name: args.event_name,
                    error: err instanceof Error ? err.message : String(err),
                },
            );
            return false;
        }
    }
}

// ---- Caller authorizer ---------------------------------------------------

/**
 * Verifies that `caller` is allowed to emit on behalf of `input.actor_id`
 * (REQ 4.10). Throws `AuthorizationError` on failure so the service
 * layer can propagate a 403 without having to inspect a return value.
 *
 * Default policy (used when no override is supplied): the caller may emit
 * if any of these holds:
 *   - `caller.user_id === input.actor_id`
 *   - `input.actor_id` is in `caller.allowed_actor_ids`
 *   - `caller.role` is one of the privileged emit roles
 *     (`super_admin`, `admin`, `system`)
 *
 * The default rules deliberately stay simple — the long tail of producer
 * roles is handled by the registry-driven authorizer wired in task 14.1.
 */
export interface CallerAuthorizer {
    assertCanCreate(args: AssertCanCreateArgs): Promise<void> | void;
}

export interface AssertCanCreateArgs {
    readonly caller: CreateNotificationCaller;
    readonly input: CreateNotificationInput;
}

/** Roles that may emit on behalf of any `actor_id` under the default policy. */
const PRIVILEGED_EMIT_ROLES = new Set<string>([
    'super_admin',
    'admin',
    'system',
]);

/**
 * Default caller authorizer. Sufficient for unit tests and for the early
 * service rollout; replaced by the RBAC-backed authorizer in task 14.1.
 */
export class DefaultCallerAuthorizer implements CallerAuthorizer {
    public assertCanCreate(args: AssertCanCreateArgs): void {
        const { caller, input } = args;

        if (!caller.user_id || caller.user_id.trim() === '') {
            throw new AuthorizationError(
                'createNotification requires an authenticated caller.',
                { caller_id: caller.user_id, actor_id: input.actor_id },
            );
        }
        if (!input.actor_id || input.actor_id.trim() === '') {
            throw new AuthorizationError(
                'createNotification requires a non-empty actor_id.',
                { caller_id: caller.user_id, actor_id: input.actor_id },
            );
        }

        if (caller.user_id === input.actor_id) return;
        if (PRIVILEGED_EMIT_ROLES.has(caller.role)) return;
        if (
            caller.allowed_actor_ids &&
            caller.allowed_actor_ids.includes(input.actor_id)
        ) {
            return;
        }

        throw new AuthorizationError(
            `Caller '${caller.user_id}' is not authorized to emit on behalf ` +
                `of actor '${input.actor_id}'.`,
            {
                caller_id: caller.user_id,
                actor_id: input.actor_id,
                reason: 'caller_not_owner_of_actor',
            },
        );
    }
}
