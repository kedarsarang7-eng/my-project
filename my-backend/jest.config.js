/** @type {import('ts-jest').JestConfigWithTsJest} */
module.exports = {
    testEnvironment: 'node',
    setupFiles: ['<rootDir>/jest.setup.js'],
    transform: {
        '^.+\\.tsx?$': ['ts-jest', { tsconfig: '<rootDir>/tsconfig.jest.json' }],
    },
    testMatch: ['<rootDir>/src/**/__tests__/**/*.test.ts', '<rootDir>/src/**/*.test.ts'],
};
