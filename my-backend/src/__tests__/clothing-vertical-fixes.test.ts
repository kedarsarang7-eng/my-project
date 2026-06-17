// ============================================================================
// CLOTHING VERTICAL FIXES COMPREHENSIVE TESTS
// ============================================================================
// Tests for all critical fixes applied to clothing vertical:
// 1. Variant-aware stock deduction
// 2. Tailoring notes API endpoints
// 3. Variant barcode mapping
// 4. Enhanced barcode scanner integration
// ============================================================================

import { findClothingVariant } from '../services/invoice.service';
import { 
    createTailoringNoteSchema, 
    updateTailoringStatusSchema, 
    assignBarcodeToVariantSchema 
} from '../schemas';
import { 
    createTailoringNote,
    getTailoringNote,
    updateTailoringStatus,
    assignBarcodeToVariant,
    getVariantByBarcode
} from '../handlers/clothing';
import { Keys, getItem, putItem, updateItem, queryItems } from '../config/dynamodb.config';
import { BusinessType, UserRole } from '../types/tenant.types';

// Mock dependencies
jest.mock('../config/dynamodb.config');
jest.mock('../services/revision-history.service');
jest.mock('../middleware/cognito-auth', () => ({
    verifyAuth: jest.fn().mockResolvedValue({
        sub: 'user-123',
        email: 'admin@clothing.com',
        tenantId: 'test-tenant-123',
        role: 'admin',
        businessType: 'clothing',
        planTier: 'enterprise',
    }),
    requireRole: jest.fn(),
    AuthError: class AuthError extends Error {
        statusCode: number;
        constructor(msg: string, code = 401) { super(msg); this.statusCode = code; this.name = 'AuthError'; }
    },
}));

const mockInvoiceId = 'f81d4fae-7dec-11d0-a765-00a0c91e6bf6';
const mockCustomerId = 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22';
const mockProductId = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
const mockVariantId = 'd5b4e6ae-88af-4afb-baad-30c73cb7fc2f';
const mockTailoringId = 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33';

describe('Clothing Vertical Fixes', () => {
    const mockTenantId = 'test-tenant-123';
    const mockAuth = {
        tenantId: mockTenantId,
        sub: 'user-123',
        businessType: BusinessType.CLOTHING,
        role: UserRole.ADMIN
    };

    beforeEach(() => {
        jest.clearAllMocks();
        (queryItems as jest.Mock).mockResolvedValue({ items: [] });
    });

    // ============================================================================
    // TEST 1: Variant-Aware Stock Deduction
    // ============================================================================

    describe('Variant-Aware Stock Deduction', () => {
        test('should find clothing variant by size and color', async () => {
            const mockVariant = {
                id: mockVariantId,
                productId: mockProductId,
                size: 'M',
                color: 'Blue',
                stock: 10,
                priceCents: 2500
            };

            (queryItems as jest.Mock).mockResolvedValue({ items: [mockVariant] });

            const result = await findClothingVariant(
                mockTenantId,
                mockProductId,
                'M',
                'Blue'
            );

            expect(result).toEqual(mockVariant);
            expect(queryItems).toHaveBeenCalledWith(
                Keys.tenantPK(mockTenantId),
                `VARIANT#${mockProductId}#`,
                expect.any(Object)
            );
        });

        test('should find clothing variant by variant ID', async () => {
            const mockVariant = {
                id: mockVariantId,
                productId: mockProductId,
                size: 'L',
                color: 'Red',
                stock: 5,
                priceCents: 3000
            };

            (getItem as jest.Mock).mockResolvedValue(mockVariant);

            const result = await findClothingVariant(
                mockTenantId,
                mockProductId,
                undefined,
                undefined,
                mockVariantId
            );

            expect(result).toEqual(mockVariant);
            expect(getItem).toHaveBeenCalledWith(
                Keys.tenantPK(mockTenantId),
                `VARIANT#${mockProductId}#${mockVariantId}`
            );
        });

        test('should return null for non-existent variant', async () => {
            (queryItems as jest.Mock).mockResolvedValue({ items: [] });

            const result = await findClothingVariant(
                mockTenantId,
                mockProductId,
                'XL',
                'Green'
            );

            expect(result).toBeNull();
        });

        test('should return null when no search criteria provided', async () => {
            const result = await findClothingVariant(
                mockTenantId,
                mockProductId
            );

            expect(result).toBeNull();
        });
    });

    // ============================================================================
    // TEST 2: Tailoring Notes Schema Validation
    // ============================================================================

    describe('Tailoring Notes Schema', () => {
        test('should validate correct tailoring note creation', () => {
            const validInput = {
                invoiceId: mockInvoiceId,
                customerId: mockCustomerId,
                measurements: {
                    chest: 40,
                    waist: 32,
                    hips: 42,
                    length: 30,
                    sleeve: 25,
                    shoulder: 18,
                    neck: 15,
                    inseam: 32,
                    customNotes: 'Extra room in shoulders'
                },
                deliveryDate: '2024-12-15',
                priority: 'normal',
                notes: 'Customer wants slim fit'
            };

            const result = createTailoringNoteSchema.parse(validInput);
            expect(result).toEqual(validInput);
        });

        test('should validate tailoring status update', () => {
            const validInput = {
                status: 'stitching',
                notes: 'In progress',
                estimatedCompletion: '2024-12-10'
            };

            const result = updateTailoringStatusSchema.parse(validInput);
            expect(result).toEqual(validInput);
        });

        test('should reject invalid delivery date format', () => {
            const invalidInput = {
                invoiceId: mockInvoiceId,
                measurements: { chest: 40 },
                deliveryDate: '15-12-2024', // Wrong format
                priority: 'normal'
            };

            expect(() => createTailoringNoteSchema.parse(invalidInput)).toThrow();
        });

        test('should reject invalid priority', () => {
            const invalidInput = {
                invoiceId: mockInvoiceId,
                measurements: { chest: 40 },
                deliveryDate: '2024-12-15',
                priority: 'super_fast' // Invalid priority
            };

            expect(() => createTailoringNoteSchema.parse(invalidInput)).toThrow();
        });
    });

    // ============================================================================
    // TEST 3: Variant Barcode Mapping
    // ============================================================================

    describe('Variant Barcode Mapping', () => {
        test('should validate correct barcode assignment', () => {
            const validInput = {
                productId: mockProductId,
                variantId: mockVariantId,
                barcode: '1234567890123'
            };

            const result = assignBarcodeToVariantSchema.parse(validInput);
            expect(result).toEqual(validInput);
        });

        test('should reject barcode that is too long', () => {
            const invalidInput = {
                productId: mockProductId,
                variantId: mockVariantId,
                barcode: 'a'.repeat(51) // Too long
            };

            expect(() => assignBarcodeToVariantSchema.parse(invalidInput)).toThrow();
        });

        test('should assign barcode to variant successfully', async () => {
            const mockEvent = {
                pathParameters: { variantId: mockVariantId },
                body: JSON.stringify({
                    productId: mockProductId,
                    barcode: '1234567890123'
                })
            };

            const mockVariant = {
                id: mockVariantId,
                productId: mockProductId,
                size: 'M',
                color: 'Blue',
                stock: 10,
                tenantId: mockTenantId
            };

            (getItem as jest.Mock).mockResolvedValue(mockVariant); // Check variant exists
            (queryItems as jest.Mock).mockResolvedValue({ items: [] }); // Check barcode not already used
            (updateItem as jest.Mock).mockResolvedValue({});

            const result = await assignBarcodeToVariant(mockEvent as any, {} as any) as any;

            expect(result.statusCode).toBe(200);
            expect(JSON.parse(result.body).data).toEqual({
                message: 'Barcode assigned successfully'
            });
        });

        test('should reject duplicate barcode assignment', async () => {
            const mockEvent = {
                pathParameters: { variantId: mockVariantId },
                body: JSON.stringify({
                    productId: mockProductId,
                    barcode: '1234567890123'
                })
            };

            const mockVariant = {
                id: mockVariantId,
                productId: mockProductId,
                size: 'M',
                color: 'Blue',
                tenantId: mockTenantId
            };

            (getItem as jest.Mock).mockResolvedValue(mockVariant);

            // Mock queryItems to return existing barcode
            (queryItems as jest.Mock).mockResolvedValue({
                items: [{ id: 'other-variant', barcode: '1234567890123' }]
            });

            const result = await assignBarcodeToVariant(mockEvent as any, {} as any) as any;

            expect(result.statusCode).toBe(400);
            expect(JSON.parse(result.body).message).toBe('Barcode already assigned to another variant');
        });
    });

    // ============================================================================
    // TEST 4: Tailoring Notes API Endpoints
    // ============================================================================

    describe('Tailoring Notes API', () => {
        test('should create tailoring note successfully', async () => {
            const mockEvent = {
                body: JSON.stringify({
                    invoiceId: mockInvoiceId,
                    customerId: mockCustomerId,
                    measurements: {
                        chest: 40,
                        waist: 32,
                        hips: 42
                    },
                    deliveryDate: '2024-12-15',
                    priority: 'normal',
                    notes: 'Standard measurements'
                })
            };

            const mockInvoice = {
                id: mockInvoiceId,
                tenantId: mockTenantId
            };

            (getItem as jest.Mock).mockResolvedValue(mockInvoice);
            (putItem as jest.Mock).mockResolvedValue({});
            (updateItem as jest.Mock).mockResolvedValue({});

            const result = await createTailoringNote(mockEvent as any, {} as any) as any;

            expect(result.statusCode).toBe(201);
            const responseBody = JSON.parse(result.body);
            expect(responseBody.data.id).toBeDefined();
            expect(responseBody.data.message).toBe('Tailoring note created successfully');
        });

        test('should update tailoring status successfully', async () => {
            const mockEvent = {
                pathParameters: { tailoringId: mockTailoringId },
                body: JSON.stringify({
                    status: 'stitching',
                    notes: 'Started stitching process'
                })
            };

            const mockTailoringNote = {
                id: mockTailoringId,
                tenantId: mockTenantId,
                status: 'measurement_taken'
            };

            (getItem as jest.Mock).mockResolvedValue(mockTailoringNote);
            (updateItem as jest.Mock).mockResolvedValue({});

            const result = await updateTailoringStatus(mockEvent as any, {} as any) as any;

            expect(result.statusCode).toBe(200);
            expect(JSON.parse(result.body).data).toEqual({
                message: 'Tailoring status updated successfully'
            });
        });

        test('should return 404 for non-existent tailoring note', async () => {
            const mockEvent = {
                pathParameters: { tailoringId: 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a44' },
                body: JSON.stringify({
                    status: 'stitching'
                })
            };

            (getItem as jest.Mock).mockResolvedValue(null);

            const result = await updateTailoringStatus(mockEvent as any, {} as any) as any;

            expect(result.statusCode).toBe(404);
            expect(JSON.parse(result.body).message).toContain('Tailoring note not found');
        });
    });

    // ============================================================================
    // TEST 5: Integration Tests
    // ============================================================================

    describe('Integration Tests', () => {
        test('should handle complete variant workflow', async () => {
            // 1. Create product with variants
            const productId = mockProductId;
            const variantId = mockVariantId;
            const barcode = '1234567890123';

            // 2. Assign barcode to variant
            const assignEvent = {
                pathParameters: { variantId },
                body: JSON.stringify({ productId, barcode })
            };

            const mockVariant = { id: variantId, productId, size: 'M', color: 'Blue', tenantId: mockTenantId };
            (getItem as jest.Mock).mockResolvedValue(mockVariant);
            (queryItems as jest.Mock).mockResolvedValue({ items: [] });
            (updateItem as jest.Mock).mockResolvedValue({});

            const assignResult = await assignBarcodeToVariant(assignEvent as any, {} as any) as any;
            expect(assignResult.statusCode).toBe(200);

            // 3. Lookup variant by barcode
            const lookupEvent = {
                pathParameters: { barcode }
            };

            (queryItems as jest.Mock).mockResolvedValue({
                items: [mockVariant]
            });

            const lookupResult = await getVariantByBarcode(lookupEvent as any, {} as any) as any;
            expect(lookupResult.statusCode).toBe(200);
            expect(JSON.parse(lookupResult.body).data).toEqual(expect.objectContaining({
                id: variantId,
                size: 'M',
                color: 'Blue'
            }));
        });

        test('should handle tailoring workflow from invoice to delivery', async () => {
            const invoiceId = mockInvoiceId;
            const tailoringId = mockTailoringId;

            // 1. Create tailoring note
            const createEvent = {
                body: JSON.stringify({
                    invoiceId,
                    measurements: { chest: 40, waist: 32 },
                    deliveryDate: '2024-12-15',
                    priority: 'normal'
                })
            };

            const mockInvoice = { id: invoiceId, tenantId: mockTenantId };
            (getItem as jest.Mock).mockResolvedValue(mockInvoice);
            (putItem as jest.Mock).mockResolvedValue({});
            (updateItem as jest.Mock).mockResolvedValue({});

            const createResult = await createTailoringNote(createEvent as any, {} as any) as any;
            expect(createResult.statusCode).toBe(201);

            // 2. Update status through workflow
            const statuses = ['cutting', 'stitching', 'finishing', 'ready_for_delivery'];
            
            for (const status of statuses) {
                const updateEvent = {
                    pathParameters: { tailoringId },
                    body: JSON.stringify({ status })
                };

                const mockTailoringNote = { id: tailoringId, tenantId: mockTenantId };
                (getItem as jest.Mock).mockResolvedValue(mockTailoringNote);

                const updateResult = await updateTailoringStatus(updateEvent as any, {} as any) as any;
                expect(updateResult.statusCode).toBe(200);
            }
        });
    });

    // ============================================================================
    // TEST 6: Error Handling and Edge Cases
    // ============================================================================

    describe('Error Handling', () => {
        test('should handle database errors gracefully', async () => {
            const mockEvent = {
                pathParameters: { variantId: mockVariantId },
                body: JSON.stringify({
                    productId: mockProductId,
                    barcode: '1234567890123'
                })
            };

            (getItem as jest.Mock).mockRejectedValue(new Error('Database connection failed'));

            const result = await assignBarcodeToVariant(mockEvent as any, {} as any) as any;

            expect(result.statusCode).toBe(500);
        });

        test('should validate UUID formats', () => {
            const invalidInput = {
                productId: 'invalid-uuid',
                variantId: 'invalid-uuid',
                barcode: '1234567890123'
            };

            expect(() => assignBarcodeToVariantSchema.parse(invalidInput)).toThrow();
        });

        test('should handle empty measurements array', () => {
            const invalidInput = {
                invoiceId: mockInvoiceId,
                measurements: {},
                deliveryDate: '2024-12-15',
                priority: 'normal'
            };

            // Should still validate as measurements are optional
            expect(() => createTailoringNoteSchema.parse(invalidInput)).not.toThrow();
        });
    });
});



