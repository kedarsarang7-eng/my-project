import { Keys } from '../config/dynamodb.config';
import { PHASE12_API_CONTRACT, PHASE12_PERMISSION_MATRIX } from '../contracts/hardware-phase12.contracts';

describe('hardware phase1+2 contracts', () => {
    test('permission matrix defines purchase create access', () => {
        const row = PHASE12_PERMISSION_MATRIX.find((r) => r.module === 'purchase' && r.action === 'create');
        expect(row).toBeDefined();
        expect(row?.allowedRoles).toContain('manager');
    });

    test('api contracts expose party ledger endpoints', () => {
        expect(PHASE12_API_CONTRACT.partyCredit.getLedger.path).toBe('/hardware/parties/{id}/ledger');
        expect(PHASE12_API_CONTRACT.partyCredit.postLedger.method).toBe('POST');
    });

    test('dynamodb keys include phase2 entities', () => {
        expect(Keys.purchaseOrderSK('1')).toBe('PO#1');
        expect(Keys.grnSK('1')).toBe('GRN#1');
        expect(Keys.purchaseBillSK('1')).toBe('PBILL#1');
        expect(Keys.partyLedgerSK('1')).toBe('PLEDGER#1');
    });
});
