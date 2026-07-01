// ============================================================================
// Offline_Auth_Service — local authentication (RS256 12h JWT + bcrypt(12))
// ============================================================================
// The local equivalent of Cognito (Req 4.1). It authenticates a user against
// the Local_Store and, on success, issues a local JWT signed with RS256 that
// expires 12 hours after issuance (Req 9.1). Passwords are verified with
// bcrypt at work factor 12 (Req 9.2 / 17.4 / 17.5). Credentials that do not
// match a stored user are denied with NO token and an invalid-credentials
// indication (Req 9.9).
//
// Task 9.2 adds the per-account login gate (rate limiting + lockout) in front
// of authentication: failed attempts are tracked per account, and the gate is
// consulted before each attempt (Req 9.7 / 9.8). RBAC enforcement and
// role-change session invalidation (task 9.3) remain SEPARATE tasks and are
// intentionally NOT implemented here.
//
// Design seams honoured:
//   • Reuse, don't rebuild — the RS256 12h JWT mirrors my-backend's
//     `signLocalAuthToken` (license-token.service.ts). The same claim set,
//     algorithm, TTL, issuer, and subject are used here.
//   • Keys never hardcoded — the signing key is loaded at call time from the
//     OS keychain via the environment (config/signing-keys.ts).
//   • The Local_Store access layer (SQLCipher) lives on the Flutter side and
//     is not yet exposed to this Node process, so user lookup is an INJECTABLE
//     repository seam (`UserLookup`). Any concrete implementation MUST use
//     parameterized SQL only (Req 17.9).
// ============================================================================

import * as jwt from 'jsonwebtoken';
import { localAuthPrivateKey, localAuthPublicKey } from '../config/signing-keys';
import { verifyPassword } from './password.service';
import { LoginThrottle } from './login-throttle';
import { SessionRegistry } from './session-registry';
import { logger } from '../utils/logger';

// -- Constants (mirror my-backend/license-token.service.ts) ------------------

/** Local-auth JWT time-to-live in seconds: 12 hours (Req 9.1). */
export const LOCAL_AUTH_TTL_SECONDS = 12 * 60 * 60;

/** RS256 is the only algorithm this service signs/verifies with (Req 17.5). */
const SIGNING_ALGORITHM: jwt.Algorithm = 'RS256';

/** Issuer claim — matches the AWS signing layer's local-auth issuer. */
const LOCAL_AUTH_ISSUER = 'dukanx-offline-auth';

// -- Types -------------------------------------------------------------------

/**
 * A stored user as needed for authentication. This is the minimal projection
 * the Offline_Auth_Service reads from the Local_Store `users` table; concrete
 * lookups MUST select these via parameterized SQL.
 */
export interface StoredUser {
    /** Primary key (UUID) of the user row. */
    id: string;
    /** Tenant the user belongs to. */
    tenantId: string;
    /** Login identifier (username or email), already normalised by the lookup. */
    identifier: string;
    /** bcrypt password hash (cost 12). */
    passwordHash: string;
    /** RBAC role carried into the token for downstream enforcement (task 9.3). */
    role: string;
    /** Whether the account is active; inactive users cannot authenticate. */
    isActive?: boolean;
}

/**
 * Injectable user-lookup seam. Resolves a stored user by login identifier
 * (username OR email). Returns null when no such user exists. Implementations
 * MUST use parameterized SQL only (Req 17.9) and SHOULD normalise the
 * identifier (e.g. lower-casing an email) consistently with `StoredUser.identifier`.
 */
export type UserLookup = (identifier: string) => Promise<StoredUser | null>;

/** Claims embedded in an issued local-auth JWT (input side). */
export interface LocalAuthClaims {
    /** The authenticated user id. */
    userId: string;
    /** The tenant the user belongs to. */
    tenantId: string;
    /** The user's RBAC role. */
    role: string;
    /** Optional session id, used by task 9.3 for targeted session invalidation. */
    sessionId?: string;
}

/** The verified claim set of a local-auth JWT (output of verify). */
export interface VerifiedLocalAuthClaims extends LocalAuthClaims {
    sub: string;
    iat: number;
    exp: number;
    iss?: string;
}

/** Discriminated result of an authentication attempt. */
export type AuthResult =
    | {
          ok: true;
          /** RS256-signed local JWT, expires 12h after issuance (Req 9.1). */
          token: string;
          /** Echoed identity, convenient for the caller (no secrets). */
          user: { id: string; tenantId: string; role: string };
          /** Token expiry, seconds since epoch. */
          expiresAt: number;
      }
    | {
          ok: false;
          /** Stable reason code. `invalid_credentials` for any auth miss (Req 9.9). */
          reason: 'invalid_credentials';
          /** Human-readable message for the API envelope. */
          message: string;
      }
    | {
          ok: false;
          /** The account is temporarily rate limited (Req 9.7). No token issued. */
          reason: 'rate_limited';
          /** Human-readable message for the API envelope. */
          message: string;
          /** Seconds until login attempts are accepted again. */
          retryAfterSeconds: number;
      }
    | {
          ok: false;
          /** The account is locked (Req 9.8). No token issued. */
          reason: 'account_locked';
          /** Human-readable message for the API envelope. */
          message: string;
          /** Seconds until the lock window elapses. */
          retryAfterSeconds: number;
      };

// -- Service -----------------------------------------------------------------

/**
 * Offline_Auth_Service — authenticates against the Local_Store and issues the
 * local-auth JWT. Construct it with a `UserLookup` bound to the SQLCipher store.
 *
 * Optionally accepts a per-account {@link LoginThrottle}, a {@link SessionRegistry}
 * (for targeted session invalidation on role change, Req 9.6), and an injectable
 * clock (`now`) so the rate-limit/lockout windows (Req 9.7 / 9.8) are
 * deterministic and testable. All default sensibly, so existing construction
 * sites (`new OfflineAuthService(lookup)`) keep working unchanged.
 */
export class OfflineAuthService {
    private readonly throttle: LoginThrottle;
    private readonly sessions?: SessionRegistry;
    private readonly now: () => number;

    constructor(
        private readonly lookupUser: UserLookup,
        options: { throttle?: LoginThrottle; sessions?: SessionRegistry; now?: () => number } = {},
    ) {
        this.throttle = options.throttle ?? new LoginThrottle();
        this.sessions = options.sessions;
        this.now = options.now ?? (() => Date.now());
    }

    /**
     * Authenticate a user by identifier (username or email) + password.
     *
     * Before verifying credentials, the per-account login gate (Req 9.7 / 9.8)
     * is consulted: a locked account is rejected with `account_locked`, and a
     * rate-limited account is rejected with `rate_limited`; in both cases NO
     * token is issued and no credential check runs.
     *
     * On success: verifies the bcrypt(12) hash, clears the account's failure
     * history, and returns a freshly signed RS256 local JWT (12h TTL) plus the
     * user's identity.
     *
     * On any failure to match a stored user OR a wrong password: records the
     * failure for the account and returns `{ ok: false, reason:
     * 'invalid_credentials' }` with NO token (Req 9.9). The same result is
     * returned whether the user is missing or the password is wrong, so the
     * response does not reveal which users exist.
     *
     * @param identifier The login username or email.
     * @param password   The plaintext password to verify.
     */
    async authenticate(identifier: string, password: string): Promise<AuthResult> {
        const invalid: AuthResult = {
            ok: false,
            reason: 'invalid_credentials',
            message: 'The credentials provided are invalid.',
        };

        // Reject obviously malformed input without a store round-trip. Malformed
        // input is not counted as an account failure (there is no real account).
        if (
            typeof identifier !== 'string' ||
            identifier.trim().length === 0 ||
            typeof password !== 'string' ||
            password.length === 0
        ) {
            return invalid;
        }

        const account = identifier.trim();
        const nowMs = this.now();

        // ── Login gate (Req 9.7 / 9.8) ──────────────────────────────────────
        // Consult the per-account throttle BEFORE any credential check. A locked
        // account (Req 9.8) takes precedence over a rate-limited one (Req 9.7).
        const decision = this.throttle.check(account, nowMs);
        if (decision.state === 'locked') {
            logger.warn('Offline auth rejected: account locked', {
                retryAfterSeconds: decision.retryAfterSeconds,
            });
            return {
                ok: false,
                reason: 'account_locked',
                message: 'This account is locked due to too many failed login attempts.',
                retryAfterSeconds: decision.retryAfterSeconds,
            };
        }
        if (decision.state === 'rate_limited') {
            logger.warn('Offline auth rejected: rate limited', {
                retryAfterSeconds: decision.retryAfterSeconds,
            });
            return {
                ok: false,
                reason: 'rate_limited',
                message: 'Too many failed login attempts. Login is temporarily rate limited.',
                retryAfterSeconds: decision.retryAfterSeconds,
            };
        }

        const user = await this.lookupUser(account);

        // No matching user → deny, issue no token (Req 9.9). Still run a bcrypt
        // comparison against a throwaway hash to keep timing uniform and avoid
        // signalling user existence via response latency.
        if (!user) {
            await verifyPassword(password, DUMMY_HASH);
            this.throttle.recordFailure(account, nowMs);
            return invalid;
        }

        if (user.isActive === false) {
            // Treat a disabled account like an auth miss — no token, same code.
            await verifyPassword(password, DUMMY_HASH);
            this.throttle.recordFailure(account, nowMs);
            return invalid;
        }

        const passwordMatches = await verifyPassword(password, user.passwordHash);
        if (!passwordMatches) {
            this.throttle.recordFailure(account, nowMs);
            return invalid;
        }

        // Successful login clears the account's failure history and any cooldown.
        this.throttle.reset(account);

        // Register an active session so a later role change can invalidate
        // EXACTLY this user's sessions (Req 9.6). The session id is embedded in
        // the token; the verify path honours the token only while its session
        // remains registered. When no registry is wired, behaviour is unchanged.
        const sessionId = this.sessions?.createSession(user.id, user.tenantId, user.role).sessionId;

        const token = this.issueToken({
            userId: user.id,
            tenantId: user.tenantId,
            role: user.role,
            sessionId,
        });

        logger.info('Offline auth succeeded', {
            tenantId: user.tenantId,
            role: user.role,
        });

        return {
            ok: true,
            token,
            user: { id: user.id, tenantId: user.tenantId, role: user.role },
            expiresAt: nowSeconds() + LOCAL_AUTH_TTL_SECONDS,
        };
    }

    /**
     * Sign a local-auth JWT (RS256, 12h TTL) for an already-authenticated user.
     * Mirrors my-backend's `signLocalAuthToken`. Exposed so the route layer and
     * task 9.3 (session re-issue on role change) can reuse the exact pattern.
     */
    issueToken(claims: LocalAuthClaims): string {
        if (!claims.userId || !claims.tenantId) {
            throw new Error('userId and tenantId are required to issue a local-auth token.');
        }
        return jwt.sign(
            { tenantId: claims.tenantId, role: claims.role, ...(claims.sessionId ? { sessionId: claims.sessionId } : {}) },
            localAuthPrivateKey(),
            {
                algorithm: SIGNING_ALGORITHM,
                expiresIn: LOCAL_AUTH_TTL_SECONDS,
                issuer: LOCAL_AUTH_ISSUER,
                subject: claims.userId,
            },
        );
    }

    /**
     * Verify a local-auth JWT against the RS256 public key. Throws on any
     * tampering, expiry, wrong issuer, or signature mismatch. The returned
     * `sub` carries the user id; `userId` is normalised onto it for callers.
     *
     * When a {@link SessionRegistry} is wired, the token is additionally
     * rejected (as if invalid) unless its (userId, sessionId) session is still
     * active. A role change invalidates exactly that user's sessions, so any
     * token minted before the change stops verifying and the user must
     * re-authenticate before any further action (Req 9.6).
     */
    verifyToken(token: string): VerifiedLocalAuthClaims {
        const decoded = jwt.verify(token, localAuthPublicKey(), {
            algorithms: [SIGNING_ALGORITHM],
            issuer: LOCAL_AUTH_ISSUER,
        }) as jwt.JwtPayload;

        const claims: VerifiedLocalAuthClaims = {
            ...(decoded as object),
            sub: decoded.sub as string,
            userId: decoded.sub as string,
            tenantId: decoded.tenantId as string,
            role: decoded.role as string,
            sessionId: decoded.sessionId as string | undefined,
            iat: decoded.iat as number,
            exp: decoded.exp as number,
            iss: decoded.iss as string | undefined,
        };

        if (this.sessions && !this.sessions.isSessionActive(claims.userId, claims.sessionId)) {
            throw new jwt.JsonWebTokenError('session has been invalidated');
        }

        return claims;
    }
}

// -- Internals ---------------------------------------------------------------

/** Current time in whole seconds since the epoch. */
function nowSeconds(): number {
    return Math.floor(Date.now() / 1000);
}

/**
 * A fixed bcrypt(12) hash of a random throwaway string, compared against when
 * no user is found so that the "user missing" and "wrong password" paths take
 * comparable time. This value is NOT a credential and grants no access.
 */
const DUMMY_HASH = '$2a$12$nf8.8UP1nF0MbLMt40yzs.EeagcBpGo/z4m.fYkSponFtKip/wCb2';
