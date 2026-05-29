// @ts-nocheck
import { InventoryService } from '../services/inventory.service';

const mockGetItem = jest.fn();
const mockPutItem = jest.fn();
const mockQueryItems = jest.fn();
const mockQueryAllItems = jest.fn();
const mockUpdateItem = jest.fn();
const mockRecordRevision = jest.fn().mockResolvedValue(undefined);

jest.mock('../config/dynamodb.config', () => ({
    Keys: {
        tenantPK: (id: string) => `TENANT#${id}`,
        productSK: (id: string) => `PRODUCT#${id}`,
        barcodeGSI3PK: (id: string) => `TENANT#${id}`,
        barcodeGSI3SK: (b: string) => `BARCODE#${b}`,
        skuGSI1SK: (s: string) => `SKU#${s}`,
    },
    getItem: (...args: any[]) => mockGetItem(...args),
    putItem: (...args: any[]) => mockPutItem(...args),
    queryItems: (...args: any[]) => mockQueryItems(...args),
    queryAllItems: (...args: any[]) => mockQueryAllItems(...args),
    updateItem: (...args: any[]) => mockUpdateItem(...args),
}));

jest.mock('../services/revision-history.service', () => ({
    recordRevision: (...args: any[]) => mockRecordRevision(...args),
}));

describe('inventory service revision hooks', () => {
    const service = new InventoryService();

    beforeEach(() => {
        jest.clearAllMocks();
        mockQueryItems.mockResolvedValue({ items: [], lastKey: undefined });
    });

    test('createItem writes create revision', async () => {
        mockPutItem.mockResolvedValueOnce(undefined);

        await service.createItem('t1', {
            name: 'Item A',
            sku: 'SKU1',
            category: 'general',
            salePriceCents: 1000,
            currentStock: 12,
        }, 'user-1');

        expect(mockRecordRevision).toHaveBeenCalledWith(
            't1',
            'inventory',
            expect.any(String),
            'create',
            'user-1',
            null,
            expect.objectContaining({ name: 'Item A', currentStock: 12 }),
            expect.objectContaining({ source: 'inventory.createItem' }),
        );
    });

    test('updateItem writes update revision', async () => {
        mockGetItem.mockResolvedValueOnce({
            id: 'p1',
            name: 'Item A',
            category: 'general',
            salePriceCents: 1000,
            currentStock: 12,
            isActive: true,
            isDeleted: false,
        });
        mockUpdateItem.mockResolvedValueOnce({
            id: 'p1',
            name: 'Item B',
            category: 'general',
            salePriceCents: 1200,
            currentStock: 10,
            isActive: true,
        });

        await service.updateItem('t1', 'p1', { name: 'Item B', salePriceCents: 1200 }, 'user-2');

        expect(mockRecordRevision).toHaveBeenCalledWith(
            't1',
            'inventory',
            'p1',
            'update',
            'user-2',
            expect.objectContaining({ name: 'Item A', currentStock: 12 }),
            expect.objectContaining({ name: 'Item B', currentStock: 10 }),
            expect.objectContaining({ source: 'inventory.updateItem' }),
        );
    });
});
