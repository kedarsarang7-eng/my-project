/**
 * Scaffold smoke test.
 *
 * Confirms the package builds and the Jest + ts-jest toolchain is wired
 * correctly. Replaced/expanded by stage-specific tests as implementation
 * progresses.
 */
import * as auditPackage from '../src';

describe('api-audit scaffold', () => {
    it('loads the package entry point', () => {
        expect(auditPackage).toBeDefined();
    });
});
