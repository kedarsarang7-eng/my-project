// ============================================================================
// Security Audit Regression Tests (DynamoDB-era)
// ============================================================================
// Older SQL/postgres assertions removed after migration. These checks validate
// equivalent controls in current source files.
// ============================================================================

import * as fs from 'fs';
import * as path from 'path';

describe('Timing-Safe Signature Verification', () => {
    test('C-2: Razorpay gateway uses timingSafeEqual, not string equality', () => {
        const razorpaySource = fs.readFileSync(
            path.resolve(__dirname, '../services/gateway/razorpay.gateway.ts'),
            'utf-8'
        );
        expect(razorpaySource).toContain('timingSafeEqual');
        expect(razorpaySource).not.toMatch(/signature\s*!==\s*expectedSignature/);
    });

    test('M-2: PhonePe gateway uses timingSafeEqual, not string equality', () => {
        const phonePeSource = fs.readFileSync(
            path.resolve(__dirname, '../services/gateway/phonepe.gateway.ts'),
            'utf-8'
        );
        expect(phonePeSource).toContain('timingSafeEqual');
        expect(phonePeSource).not.toMatch(/xVerify\s*!==\s*expectedChecksum/);
    });

    test('H-1: Internal auth uses timingSafeEqual path', () => {
        const internalAuthSource = fs.readFileSync(
            path.resolve(__dirname, '../middleware/internal-auth.ts'),
            'utf-8'
        );
        expect(internalAuthSource).toContain('timingSafeEqual');
        expect(internalAuthSource).toContain('isTimingSafeEqual');
    });
});

describe('H-2: Internal secret fail-fast', () => {
    test('internal-auth.ts documents FATAL missing INTERNAL_API_SECRET', () => {
        const source = fs.readFileSync(
            path.resolve(__dirname, '../middleware/internal-auth.ts'),
            'utf-8'
        );
        expect(source).toContain('FATAL');
        expect(source).not.toContain('dev_secret_dukanx_m2m');
    });
});

describe('Payment order service (DynamoDB)', () => {
    test('reconcilePendingOrders exists and uses DynamoDB updates', () => {
        const source = fs.readFileSync(
            path.resolve(__dirname, '../services/payment-order.service.ts'),
            'utf-8'
        );
        expect(source).toContain('export async function reconcilePendingOrders');
        expect(source).toContain('queryItems');
        expect(source).toContain('updateItem');
    });

    test('payment-order service writes revision history for order/invoice status transitions', () => {
        const source = fs.readFileSync(
            path.resolve(__dirname, '../services/payment-order.service.ts'),
            'utf-8'
        );
        expect(source).toContain('recordRevision');
        expect(source).toContain('payment-order.handleWebhook');
        expect(source).toContain('payment-order.reconcilePendingOrders');
        expect(source).toContain("'payment_orders'");
        expect(source).toContain("'transactions'");
    });

    test('handleWebhook skips applying payment when invoice is voided', () => {
        const source = fs.readFileSync(
            path.resolve(__dirname, '../services/payment-order.service.ts'),
            'utf-8'
        );
        expect(source).toContain('inv.status !== \'voided\'');
    });
});

describe('Staff sale QR revision trail', () => {
    test('generateSaleQr writes revision on transaction link and payment-order attach', () => {
        const source = fs.readFileSync(
            path.resolve(__dirname, '../handlers/staff-sale.ts'),
            'utf-8'
        );
        expect(source).toContain("source: 'staff-sale.generateSaleQr.linkTransaction'");
        expect(source).toContain("source: 'staff-sale.generateSaleQr.attachPaymentOrder'");
        expect(source).toContain("'staff_sales_details'");
    });
});

describe('Invoice service — tax fields & guards (DynamoDB)', () => {
    test('create flow persists cgst/sgst/igst style fields on items', () => {
        const source = fs.readFileSync(
            path.resolve(__dirname, '../services/invoice.service.ts'),
            'utf-8'
        );
        expect(source).toMatch(/cgstCents|cgst_cents/);
        expect(source).toMatch(/sgstCents|sgst_cents/);
        expect(source).toMatch(/igstCents|igst_cents/);
    });

    test('sendInvoice uses Dynamo updateItem (not Postgres pool)', () => {
        const source = fs.readFileSync(
            path.resolve(__dirname, '../services/invoice.service.ts'),
            'utf-8'
        );
        const fn = source.substring(source.indexOf('export async function sendInvoice'));
        expect(fn).toContain('updateItem');
        expect(fn).toContain("source: 'invoice.sendInvoice'");
        expect(fn).toContain('recordRevision');
        expect(fn).not.toContain('getPool(');
    });

    test('finalizeInvoice rejects zero line items via Dynamo query', () => {
        const source = fs.readFileSync(
            path.resolve(__dirname, '../services/invoice.service.ts'),
            'utf-8'
        );
        const finalize = source.substring(
            source.indexOf('export async function finalizeInvoice'),
            source.indexOf('export async function voidInvoice'),
        );
        expect(finalize).toContain('LINEITEM#');
        expect(finalize).toContain('Cannot finalize invoice with zero line items');
    });

    test('voidInvoice blocks when paidCents already collected', () => {
        const source = fs.readFileSync(
            path.resolve(__dirname, '../services/invoice.service.ts'),
            'utf-8'
        );
        const voidFn = source.substring(
            source.indexOf('export async function voidInvoice'),
            source.indexOf('export async function sendInvoice'),
        );
        expect(voidFn).toContain('paidCents');
        expect(voidFn).toContain('Cannot void invoice');
    });

    test('createReturn and updateInvoice write revision history', () => {
        const source = fs.readFileSync(
            path.resolve(__dirname, '../services/invoice.service.ts'),
            'utf-8'
        );
        const createReturnFn = source.substring(
            source.indexOf('export async function createReturn'),
            source.indexOf('export async function updateInvoice'),
        );
        const updateInvoiceFn = source.substring(
            source.indexOf('export async function updateInvoice'),
            source.indexOf('// ---- Errors ----'),
        );
        expect(createReturnFn).toContain("source: 'invoice.createReturn'");
        expect(createReturnFn).toContain("'credit_notes'");
        expect(createReturnFn).toContain("'transactions'");
        expect(updateInvoiceFn).toContain("source: 'invoice.updateInvoice'");
        expect(updateInvoiceFn).toContain('recordRevision');
    });
});

describe('M-3: Dead tenant-context removal', () => {
    test('tenant-context.ts is absent', () => {
        expect(fs.existsSync(path.resolve(__dirname, '../middleware/tenant-context.ts'))).toBe(false);
    });
});

describe('Sync service — delete path', () => {
    test('reject unknown table names via SYNCABLE_TABLES', () => {
        const source = fs.readFileSync(
            path.resolve(__dirname, '../services/sync.service.ts'),
            'utf-8'
        );
        expect(source).toContain('SYNCABLE_TABLES.has');
    });

    test('delete uses soft-delete updateItem', () => {
        const source = fs.readFileSync(
            path.resolve(__dirname, '../services/sync.service.ts'),
            'utf-8'
        );
        expect(source).toContain('sync_soft_delete');
        expect(source).toContain('isDeleted');
    });
});

describe('Dashboard / strategies — exclude deleted', () => {
    test('dashboard filters isDeleted', () => {
        const source = fs.readFileSync(
            path.resolve(__dirname, '../services/dashboard-v2.service.ts'),
            'utf-8'
        );
        expect(source).toContain('isDeleted');
    });

    test('restaurant strategy queries Dynamo RESTO/KOT prefixes', () => {
        const source = fs.readFileSync(
            path.resolve(__dirname, '../services/business/restaurant.strategy.ts'),
            'utf-8'
        );
        expect(source).toContain('RESTOTABLE#');
        expect(source).toContain('RESTOBILL#');
        expect(source).toContain('KOT#');
    });
});

describe('IAM — SNS publish scoped (serverless)', () => {
    test('sns:Publish is not bare Resource: * in lambda role', () => {
        const yml = fs.readFileSync(path.resolve(__dirname, '../../serverless.yml'), 'utf-8');
        const publishIdx = yml.indexOf('sns:Publish');
        expect(publishIdx).toBeGreaterThan(-1);
        const section = yml.substring(publishIdx, publishIdx + 400);
        expect(section).not.toMatch(/Publish\r?\n\s+Resource:\s*['"]?\*['"]?/);
    });
});

describe('Fraud detection — duplicate velocity', () => {
    test('checkDuplicatePayment uses 60s window and duplicate_payment rule', () => {
        const source = fs.readFileSync(
            path.resolve(__dirname, '../services/fraud-detection.service.ts'),
            'utf-8'
        );
        expect(source).toContain('checkDuplicatePayment');
        expect(source).toContain('duplicate_payment');
        expect(source).toContain('60 * 1000');
    });
});
