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
import { Keys, getItem, putItem, updateItem } from '../config/dynamodb.config';
import { BusinessType, UserRole } from '../types/tenant.types';

// Mock dependencies
jest.mock('../config/dynamodb.config');
jest.mock('../services/revision-history.service');

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
    });

    // ============================================================================
    // TEST 1: Variant-Aware Stock Deduction
    // ============================================================================

    describe('Variant-Aware Stock Deduction', () => {
        test('should find clothing variant by size and color', async () => {
            const mockVariant = {
                id: 'variant-123',
                productId: 'product-123',
                size: 'M',
                color: 'Blue',
                stock: 10,
                priceCents: 2500
            };

            (getItem as jest.Mock).mockResolvedValue({ Item: mockVariant });

            const result = await findClothingVariant(
                mockTenantId,
                'product-123',
                'M',
                'Blue'
            );

            expect(result).toEqual(mockVariant);
            expect(getItem).toHaveBeenCalledWith(
                Keys.tenantPK(mockTenantId),
                expect.stringContaining('VARIANT#product-123#')
            );
        });

        test('should find clothing variant by variant ID', async () => {
            const mockVariant = {
                id: 'variant-123',
                productId: 'product-123',
                size: 'L',
                color: 'Red',
                stock: 5,
                priceCents: 3000
            };

            (getItem as jest.Mock).mockResolvedValue({ Item: mockVariant });

            const result = await findClothingVariant(
                mockTenantId,
                'product-123',
                null,
                null,
                'variant-123'
            );

            expect(result).toEqual(mockVariant);
            expect(getItem).toHaveBeenCalledWith(
                Keys.tenantPK(mockTenantId),
                'VARIANT#product-123#variant-123'
            );
        });

        test('should return null for non-existent variant', async () => {
            (getItem as jest.Mock).mockResolvedValue({ Item: null });

            const result = await findClothingVariant(
                mockTenantId,
                'product-123',
                'XL',
                'Green'
            );

            expect(result).toBeNull();
        });

        test('should return null when no search criteria provided', async () => {
            const result = await findClothingVariant(
                mockTenantId,
                'product-123'
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
                invoiceId: 'invoice-123',
                customerId: 'customer-123',
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
                invoiceId: 'invoice-123',
                measurements: { chest: 40 },
                deliveryDate: '15-12-2024', // Wrong format
                priority: 'normal'
            };

            expect(() => createTailoringNoteSchema.parse(invalidInput)).toThrow();
        });

        test('should reject invalid priority', () => {
            const invalidInput = {
                invoiceId: 'invoice-123',
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
                productId: 'product-123',
                variantId: 'variant-123',
                barcode: '1234567890123'
            };

            const result = assignBarcodeToVariantSchema.parse(validInput);
            expect(result).toEqual(validInput);
        });

        test('should reject barcode that is too long', () => {
            const invalidInput = {
                productId: 'product-123',
                variantId: 'variant-123',
                barcode: '12345678901234567890' // Too long
            };

            expect(() => assignBarcodeToVariantSchema.parse(invalidInput)).toThrow();
        });

        test('should assign barcode to variant successfully', async () => {
            const mockEvent = {
                pathParameters: { variantId: 'variant-123' },
                body: JSON.stringify({
                    productId: 'product-123',
                    barcode: '1234567890123'
                })
            };

            const mockVariant = {
                id: 'variant-123',
                productId: 'product-123',
                size: 'M',
                color: 'Blue',
                stock: 10
            };

            (getItem as jest.Mock)
                .mockResolvedValueOnce({ Item: mockVariant }) // Check variant exists
                .mockResolvedValueOnce({ items: [] }); // Check barcode not already used

            (updateItem as jest.Mock).mockResolvedValue({});

            const result = await assignBarcodeToVariant(mockEvent, {}, mockAuth);

            expect(result.statusCode).toBe(200);
            expect(JSON.parse(result.body)).toEqual({
                message: 'Barcode assigned successfully'
            });
        });

        test('should reject duplicate barcode assignment', async () => {
            const mockEvent = {
                pathParameters: { variantId: 'variant-123' },
                body: JSON.stringify({
                    productId: 'product-123',
                    barcode: '1234567890123'
                })
            };

            const mockVariant = {
                id: 'variant-123',
                productId: 'product-123',
                size: 'M',
                color: 'Blue'
            };

            (getItem as jest.Mock).mockResolvedValue({ Item: mockVariant });

            // Mock queryItems to return existing barcode
            const mockQueryItems = jest.fn().mockResolvedValue({
                items: [{ id: 'other-variant', barcode: '1234567890123' }]
            });

            // Replace the queryItems import
            jest.doMock('../config/dynamodb.config', () => ({
                ...jest.requireActual('../config/dynamodb.config'),
                queryItems: mockQueryItems
            }));

            const result = await assignBarcodeToVariant(mockEvent, {}, mockAuth);

            expect(result.statusCode).toBe(400);
            expect(JSON.parse(result.body)).toEqual({
                message: 'Barcode already assigned to another variant'
            });
        });
    });

    // ============================================================================
    // TEST 4: Tailoring Notes API Endpoints
    // ============================================================================

    describe('Tailoring Notes API', () => {
        test('should create tailoring note successfully', async () => {
            const mockEvent = {
                body: JSON.stringify({
                    invoiceId: 'invoice-123',
                    customerId: 'customer-123',
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
                id: 'invoice-123',
                tenantId: mockTenantId
            };

            (getItem as jest.Mock).mockResolvedValue({ Item: mockInvoice });
            (putItem as jest.Mock).mockResolvedValue({});
            (updateItem as jest.Mock).mockResolvedValue({});

            const result = await createTailoringNote(mockEvent, {}, mockAuth);

            expect(result.statusCode).toBe(201);
            const responseBody = JSON.parse(result.body);
            expect(responseBody.id).toBeDefined();
            expect(responseBody.message).toBe('Tailoring note created successfully');
        });

        test('should update tailoring status successfully', async () => {
            const mockEvent = {
                pathParameters: { tailoringId: 'tailoring-123' },
                body: JSON.stringify({
                    status: 'stitching',
                    notes: 'Started stitching process'
                })
            };

            const mockTailoringNote = {
                id: 'tailoring-123',
                tenantId: mockTenantId,
                status: 'measurement_taken'
            };

            (getItem as jest.Mock).mockResolvedValue({ Item: mockTailoringNote });
            (updateItem as jest.Mock).mockResolvedValue({});

            const result = await updateTailoringStatus(mockEvent, {}, mockAuth);

            expect(result.statusCode).toBe(200);
            expect(JSON.parse(result.body)).toEqual({
                message: 'Tailoring status updated successfully'
            });
        });

        test('should return 404 for non-existent tailoring note', async () => {
            const mockEvent = {
                pathParameters: { tailoringId: 'non-existent' },
                body: JSON.stringify({
                    status: 'stitching'
                })
            };

            (getItem as jest.Mock).mockResolvedValue({ Item: null });

            const result = await updateTailoringStatus(mockEvent, {}, mockAuth);

            expect(result.statusCode).toBe(404);
            expect(JSON.parse(result.body)).toEqual({
                message: 'Tailoring note not found'
            });
        });
    });

    // ============================================================================
    // TEST 5: Integration Tests
    // ============================================================================

    describe('Integration Tests', () => {
        test('should handle complete variant workflow', async () => {
            // 1. Create product with variants
            const productId = 'product-123';
            const variantId = 'variant-123';
            const barcode = '1234567890123';

            // 2. Assign barcode to variant
            const assignEvent = {
                pathParameters: { variantId },
                body: JSON.stringify({ productId, barcode })
            };

            const mockVariant = { id: variantId, productId, size: 'M', color: 'Blue' };
            (getItem as jest.Mock).mockResolvedValue({ Item: mockVariant });
            (updateItem as jest.Mock).mockResolvedValue({});

            const assignResult = await assignBarcodeToVariant(assignEvent, {}, mockAuth);
            expect(assignResult.statusCode).toBe(200);

            // 3. Lookup variant by barcode
            const lookupEvent = {
                pathParameters: { barcode }
            };

            const mockQueryItems = jest.fn().mockResolvedValue({
                items: [mockVariant]
            });

            jest.doMock('../config/dynamodb.config', () => ({
                ...jest.requireActual('../config/dynamodb.config'),
                queryItems: mockQueryItems
            }));

            const lookupResult = await getVariantByBarcode(lookupEvent, {}, mockAuth);
            expect(lookupResult.statusCode).toBe(200);
            expect(JSON.parse(lookupResult.body)).toEqual(expect.objectContaining({
                id: variantId,
                size: 'M',
                color: 'Blue'
            }));
        });

        test('should handle tailoring workflow from invoice to delivery', async () => {
            const invoiceId = 'invoice-123';
            const tailoringId = 'tailoring-123';

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
            (getItem as jest.Mock).mockResolvedValue({ Item: mockInvoice });
            (putItem as jest.Mock).mockResolvedValue({});
            (updateItem as jest.Mock).mockResolvedValue({});

            const createResult = await createTailoringNote(createEvent, {}, mockAuth);
            expect(createResult.statusCode).toBe(201);

            // 2. Update status through workflow
            const statuses = ['cutting', 'stitching', 'finishing', 'ready_for_delivery'];
            
            for (const status of statuses) {
                const updateEvent = {
                    pathParameters: { tailoringId },
                    body: JSON.stringify({ status })
                };

                const mockTailoringNote = { id: tailoringId, tenantId: mockTenantId };
                (getItem as jest.Mock).mockResolvedValue({ Item: mockTailoringNote });

                const updateResult = await updateTailoringStatus(updateEvent, {}, mockAuth);
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
                pathParameters: { variantId: 'variant-123' },
                body: JSON.stringify({
                    productId: 'product-123',
                    barcode: '1234567890123'
                })
            };

            (getItem as jest.Mock).mockRejectedValue(new Error('Database connection failed'));

            const result = await assignBarcodeToVariant(mockEvent, {}, mockAuth);

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
                invoiceId: 'invoice-123',
                measurements: {},
                deliveryDate: '2024-12-15',
                priority: 'normal'
            };

            // Should still validate as measurements are optional
            expect(() => createTailoringNoteSchema.parse(invalidInput)).not.toThrow();
        });
    });
});
