/** @type {import('ts-jest').JestConfigWithTsJest} */
module.exports = {
    testEnvironment: 'node',
    rootDir: 'G:/desktop app genuine/my-backend',
    roots: [
        '<rootDir>',
        'G:/desktop app genuine/Dukan_x/test/integration/tenant_isolation',
    ],
    transform: {
        '^.+\\.(tsx?|mjs)$': ['ts-jest', {
            tsconfig: 'G:/desktop app genuine/Dukan_x/test/integration/tenant_isolation/tsconfig.json',
        }],
    },
    testMatch: [
        'G:/desktop app genuine/Dukan_x/test/integration/tenant_isolation/tests/**/*.test.ts',
    ],
    moduleFileExtensions: ['ts', 'tsx', 'js', 'jsx', 'mjs', 'json'],
    moduleDirectories: [
        'node_modules',
        'G:/desktop app genuine/my-backend/node_modules',
    ],
    setupFiles: ['<rootDir>/jest.setup.js'],
    verbose: true,
};
