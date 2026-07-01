// ============================================================================
// Unit tests — Login_Throttle + Offline_Auth_Service rate limiting & lockout
// ============================================================================
// Spec: offline-license-activation — Task 9.2
//   "Implement rate limiting and lockout: 5 failures in 15min → 60s rate limit;
//    10 failures in 30min → 30min lock; resume after windows."
//   Requirements: 9.7, 9.8
//
// These are example-based unit tests (the property test for the login gate is
// the separate task 9.5 / Property 20). They drive the throttle and the auth
// service through an injectable clock so the 15-min / 60-sec / 30-min windows
// are exercised deterministically without real waiting.
//
// Gate semantics exercised here (and required by Req 9.7/9.8): the throttle is
// consulted BEFORE the credential check, so an attempt rejected as
// rate_limited/locked is NOT a new "failed login attempt" and does not advance
// the counters. Reaching the 10-failure lock therefore requires spacing real
// credential failures across the 60-second cooldown windows.
// ============================================================================

import { generateKeyPairSync } from 'crypto';
import {
    LoginThrottle,
    RATE_LIMIT_THRESHOLD,
    RATE_LIMIT_WINDOW_MS,
    RATE_LIMIT_COOLDOWN_MS,
    LOCK_THRESHOLD,
    LOCK_DURATION_MS,
} from '../services/login-throttle';
import { OfflineAuthService, StoredUser } from '../services/offline-auth.service';
import { hashPassword } from '../services/password.service';

const ACCOUNT = 'cashier@example.com';
const MINUTE = 60 * 1000;

// ── RS256 key for token issuance on the success paths ───────────────────────
// The Offline_Auth_Service signs a local JWT on success (Req 9.1). The signing
// key is normally provisioned by the Backend_Supervisor from the OS keychain;
// for tests we generate an ephemeral RSA key pair and expose it via the env
// seam the signing-keys loader reads.
beforeAll(() => {
    const { privateKey } = generateKeyPairSync('rsa', {
        modulusLength: 2048,
        publicKeyEncoding: { type: 'spki', format: 'pem' },
        privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
    });
    process.env.LOCAL_AUTH_PRIVATE_KEY = privateKey;
});

afterAll(() => {
    delete process.env.LOCAL_AUTH_PRIVATE_KEY;
});

describe('LoginThrottle — rate limiting (Req 9.7)', () => {
    test('allows attempts before the 5th failure', () => {
        const throttle = new LoginThrottle();
        let t = 0;
        for (let i = 0; i < RATE_LIMIT_THRESHOLD - 1; i++) {
            throttle.recordFailure(ACCOUNT, t);
            t += 1000;
        }
        expect(throttle.check(ACCOUNT, t).state).toBe('allowed');
    });

    test('5 failures within 15 minutes → rate limited for 60 seconds', () => {
        const throttle = new LoginThrottle();
        let lastFailure = 0;
        for (let i = 0; i < RATE_LIMIT_THRESHOLD; i++) {
            lastFailure = i * MINUTE; // 5 failures across 4 minutes (< 15 min window)
            throttle.recordFailure(ACCOUNT, lastFailure);
        }

        const decision = throttle.check(ACCOUNT, lastFailure);
        expect(decision.state).toBe('rate_limited');
        if (decision.state === 'rate_limited') {
            expect(decision.retryAfterSeconds).toBeGreaterThan(0);
            expect(decision.retryAfterSeconds).toBeLessThanOrEqual(RATE_LIMIT_COOLDOWN_MS / 1000);
        }
    });

    test('attempts resume after the 60-second cooldown elapses', () => {
        const throttle = new LoginThrottle();
        let lastFailure = 0;
        for (let i = 0; i < RATE_LIMIT_THRESHOLD; i++) {
            lastFailure = i * 1000;
            throttle.recordFailure(ACCOUNT, lastFailure);
        }
        // Still limited just before the cooldown ends.
        expect(throttle.check(ACCOUNT, lastFailure + RATE_LIMIT_COOLDOWN_MS - 1000).state).toBe(
            'rate_limited',
        );
        // Allowed once the 60s cooldown has fully elapsed.
        expect(throttle.check(ACCOUNT, lastFailure + RATE_LIMIT_COOLDOWN_MS).state).toBe('allowed');
    });

    test('4 failures spread beyond the 15-minute window never rate limit', () => {
        const throttle = new LoginThrottle();
        let t = 0;
        // One failure every 16 minutes → never 5 within any 15-min window.
        for (let i = 0; i < 8; i++) {
            throttle.recordFailure(ACCOUNT, t);
            expect(throttle.check(ACCOUNT, t).state).toBe('allowed');
            t += RATE_LIMIT_WINDOW_MS + MINUTE;
        }
    });
});

describe('LoginThrottle — lockout (Req 9.8)', () => {
    test('10 failures within 30 minutes → locked for 30 minutes', () => {
        const throttle = new LoginThrottle();
        let lastFailure = 0;
        for (let i = 0; i < LOCK_THRESHOLD; i++) {
            lastFailure = i * 2 * MINUTE; // 10 failures across 18 minutes (< 30 min window)
            throttle.recordFailure(ACCOUNT, lastFailure);
        }

        const decision = throttle.check(ACCOUNT, lastFailure);
        expect(decision.state).toBe('locked');
        if (decision.state === 'locked') {
            expect(decision.retryAfterSeconds).toBeGreaterThan(0);
            expect(decision.retryAfterSeconds).toBeLessThanOrEqual(LOCK_DURATION_MS / 1000);
        }
    });

    test('lock persists for the full 30 minutes, then attempts resume', () => {
        const throttle = new LoginThrottle();
        let lastFailure = 0;
        for (let i = 0; i < LOCK_THRESHOLD; i++) {
            lastFailure = i * MINUTE;
            throttle.recordFailure(ACCOUNT, lastFailure);
        }
        // Locked one minute before the lock window elapses.
        expect(throttle.check(ACCOUNT, lastFailure + LOCK_DURATION_MS - MINUTE).state).toBe('locked');
        // Permitted again once the 30-minute lock window elapses (Req 9.8).
        expect(throttle.check(ACCOUNT, lastFailure + LOCK_DURATION_MS).state).toBe('allowed');
    });

    test('lock (Req 9.8) takes precedence over rate limit (Req 9.7)', () => {
        const throttle = new LoginThrottle();
        let lastFailure = 0;
        for (let i = 0; i < LOCK_THRESHOLD; i++) {
            lastFailure = i * 1000;
            throttle.recordFailure(ACCOUNT, lastFailure);
        }
        // Both windows are active simultaneously; the caller is told it's locked.
        expect(throttle.check(ACCOUNT, lastFailure).state).toBe('locked');
    });

    test('failures aging out of the 30-minute window do not lock', () => {
        const throttle = new LoginThrottle();
        let t = 0;
        // 9 failures, each 4 minutes apart (36 min span); never 10 within 30 min.
        for (let i = 0; i < 9; i++) {
            throttle.recordFailure(ACCOUNT, t);
            t += 4 * MINUTE;
        }
        expect(throttle.check(ACCOUNT, t).state).not.toBe('locked');
    });
});

describe('LoginThrottle — reset on success', () => {
    test('reset clears failure history and any active cooldown/lock', () => {
        const throttle = new LoginThrottle();
        let lastFailure = 0;
        for (let i = 0; i < RATE_LIMIT_THRESHOLD; i++) {
            lastFailure = i * 1000;
            throttle.recordFailure(ACCOUNT, lastFailure);
        }
        expect(throttle.check(ACCOUNT, lastFailure).state).toBe('rate_limited');

        throttle.reset(ACCOUNT);
        expect(throttle.check(ACCOUNT, lastFailure).state).toBe('allowed');
    });

    test('windows are tracked independently per account', () => {
        const throttle = new LoginThrottle();
        let lastFailure = 0;
        for (let i = 0; i < RATE_LIMIT_THRESHOLD; i++) {
            lastFailure = i * 1000;
            throttle.recordFailure('alice', lastFailure);
        }
        expect(throttle.check('alice', lastFailure).state).toBe('rate_limited');
        expect(throttle.check('bob', lastFailure).state).toBe('allowed');
    });
});

describe('OfflineAuthService — login gate integration (Req 9.7 / 9.8)', () => {
    const PASSWORD = 'correct-horse-battery-staple';

    async function buildService() {
        const passwordHash = await hashPassword(PASSWORD);
        const user: StoredUser = {
            id: 'u-1',
            tenantId: 't-1',
            identifier: ACCOUNT,
            passwordHash,
            role: 'cashier',
            isActive: true,
        };
        const lookup = async (identifier: string): Promise<StoredUser | null> =>
            identifier === ACCOUNT ? user : null;

        // Injectable clock the test advances explicitly.
        let now = 0;
        const service = new OfflineAuthService(lookup, { now: () => now });
        return {
            service,
            setNow: (ms: number) => {
                now = ms;
            },
        };
    }

    test('after 5 failed logins the next attempt is rate_limited, with no token', async () => {
        const { service, setNow } = await buildService();
        for (let i = 0; i < RATE_LIMIT_THRESHOLD; i++) {
            setNow(i * 1000);
            const r = await service.authenticate(ACCOUNT, 'wrong-password');
            expect(r.ok).toBe(false);
        }

        setNow(RATE_LIMIT_THRESHOLD * 1000);
        // Even the CORRECT password is refused while rate limited, and no token.
        const blocked = await service.authenticate(ACCOUNT, PASSWORD);
        expect(blocked.ok).toBe(false);
        if (!blocked.ok) {
            expect(blocked.reason).toBe('rate_limited');
            if (blocked.reason === 'rate_limited') {
                expect(blocked.retryAfterSeconds).toBeGreaterThan(0);
            }
            expect(blocked).not.toHaveProperty('token');
        }
    });

    test('login succeeds again after the 60-second cooldown elapses', async () => {
        const { service, setNow } = await buildService();
        let lastFailure = 0;
        for (let i = 0; i < RATE_LIMIT_THRESHOLD; i++) {
            lastFailure = i * 1000;
            setNow(lastFailure);
            await service.authenticate(ACCOUNT, 'wrong-password');
        }

        setNow(lastFailure + RATE_LIMIT_COOLDOWN_MS);
        const ok = await service.authenticate(ACCOUNT, PASSWORD);
        expect(ok.ok).toBe(true);
        if (ok.ok) expect(typeof ok.token).toBe('string');
    });

    test('10 spaced failures lock the account, with no token (Req 9.8)', async () => {
        const { service, setNow } = await buildService();
        // Space attempts just past each 60s cooldown so each one is a real,
        // recorded credential failure (rate-limited rejections don't count).
        const spacing = RATE_LIMIT_COOLDOWN_MS + 1000;
        let t = 0;
        for (let i = 0; i < LOCK_THRESHOLD; i++) {
            setNow(t);
            const r = await service.authenticate(ACCOUNT, 'wrong-password');
            expect(r.ok).toBe(false);
            t += spacing;
        }

        setNow(t);
        const blocked = await service.authenticate(ACCOUNT, PASSWORD);
        expect(blocked.ok).toBe(false);
        if (!blocked.ok) {
            expect(blocked.reason).toBe('account_locked');
            expect(blocked).not.toHaveProperty('token');
        }
    });

    test('a locked account is permitted to log in after the 30-minute window', async () => {
        const { service, setNow } = await buildService();
        const spacing = RATE_LIMIT_COOLDOWN_MS + 1000;
        let t = 0;
        for (let i = 0; i < LOCK_THRESHOLD; i++) {
            setNow(t);
            await service.authenticate(ACCOUNT, 'wrong-password');
            t += spacing;
        }
        const lastFailure = t - spacing;

        setNow(lastFailure + LOCK_DURATION_MS);
        const ok = await service.authenticate(ACCOUNT, PASSWORD);
        expect(ok.ok).toBe(true);
    });

    test('a successful login resets the failure counter', async () => {
        const { service, setNow } = await buildService();
        let t = 0;
        // 4 failures (below the rate-limit threshold).
        for (let i = 0; i < RATE_LIMIT_THRESHOLD - 1; i++) {
            setNow(t);
            await service.authenticate(ACCOUNT, 'wrong-password');
            t += 1000;
        }
        // A correct login clears the history.
        setNow(t);
        expect((await service.authenticate(ACCOUNT, PASSWORD)).ok).toBe(true);
        t += 1000;

        // 4 more failures still should not rate limit (counter was reset).
        for (let i = 0; i < RATE_LIMIT_THRESHOLD - 1; i++) {
            setNow(t);
            const r = await service.authenticate(ACCOUNT, 'wrong-password');
            expect(r.ok).toBe(false);
            if (!r.ok) expect(r.reason).toBe('invalid_credentials');
            t += 1000;
        }
    });
});
