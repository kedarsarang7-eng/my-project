// ============================================================================
// Jest configuration — packaged Local_Backend tests
// ============================================================================
// Uses ts-jest so the TypeScript integration tests (task 2.4) run directly
// against the source in src/ without a separate build step. Tests live under
// src/__tests__ and run in a Node environment (the backend is server-side).
// ============================================================================

/** @type {import('ts-jest').JestConfigWithTsJest} */
module.exports = {
    preset: 'ts-jest',
    testEnvironment: 'node',
    roots: ['<rootDir>/src'],
    testMatch: ['**/__tests__/**/*.test.ts'],
    // Integration tests start/stop a real loopback server; give them room and
    // run serially (see the --runInBand test script) to avoid port contention.
    testTimeout: 20000,
    clearMocks: true,
};
