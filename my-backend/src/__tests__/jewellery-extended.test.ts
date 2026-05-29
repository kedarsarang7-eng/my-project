// ============================================================================
// Integration Tests — Jewellery Extended Features
// ============================================================================
// Covers: Gold Rate Alerts, Making Charges, Repair Jobs, Gold Schemes
// Total: 28 API endpoints
// ============================================================================

import {
  createGoldRateAlert,
  listGoldRateAlerts,
  updateGoldRateAlert,
  deleteGoldRateAlert,
  createMakingChargesConfig,
  listMakingChargesConfigs,
  updateMakingChargesConfig,
  deleteMakingChargesConfig,
  createRepairJob,
  listRepairJobs,
  getRepairJob,
  updateRepairJob,
  deleteRepairJob,
  updateRepairStatus,
  getRepairStatistics,
  createGoldScheme,
  listGoldSchemes,
  getGoldScheme,
  updateGoldScheme,
  recordSchemePayment,
  redeemGoldScheme,
} from '../handlers/jewellery-extended';
import { UserRole, BusinessType } from '../types/tenant.types';
import { mockEvent, mockContext, mockAuth } from './utils/mock-lambda';

describe('Jewellery Extended Features', () => {
    const tenantId = 'test-tenant-123';
    const userId = 'test-user-456';
    const auth = mockAuth({ tenantId, sub: userId, role: 'OWNER' });

    // ═══════════════════════════════════════════════════════════════════════
    // GOLD RATE ALERTS (4 endpoints)
    // ═══════════════════════════════════════════════════════════════════════
    
    describe('POST /jewellery/gold-rate-alerts', () => {
        it('should create a gold rate alert', async () => {
            const event = mockEvent({
                body: JSON.stringify({
                    metalType: 'GOLD_22K',
                    thresholdRatePaisaPerGram: 650000,
                    direction: 'above',
                    method: 'push',
                    note: 'Alert when 22K crosses ₹6500/g',
                }),
            }, auth);

            const result = await createGoldRateAlert(event, mockContext, () => {});
            
            expect(result.statusCode).toBe(201);
            const body = JSON.parse(result.body);
            expect(body.id).toBeDefined();
            expect(body.message).toBe('Alert created successfully');
        });

        it('should reject invalid metal type', async () => {
            const event = mockEvent({
                body: JSON.stringify({
                    metalType: 'INVALID_METAL',
                    thresholdRatePaisaPerGram: 650000,
                    direction: 'above',
                    method: 'push',
                }),
            }, auth);

            const result = await createGoldRateAlert(event, mockContext, () => {});
            expect(result.statusCode).toBe(400);
        });

        it('should reject negative rate', async () => {
            const event = mockEvent({
                body: JSON.stringify({
                    metalType: 'GOLD_22K',
                    thresholdRatePaisaPerGram: -100,
                    direction: 'above',
                    method: 'push',
                }),
            }, auth);

            const result = await createGoldRateAlert(event, mockContext, () => {});
            expect(result.statusCode).toBe(400);
        });
    });

    describe('GET /jewellery/gold-rate-alerts', () => {
        it('should list user alerts', async () => {
            const event = mockEvent({}, auth);
            const result = await listGoldRateAlerts(event, mockContext, () => {});
            
            expect(result.statusCode).toBe(200);
            const body = JSON.parse(result.body);
            expect(Array.isArray(body.data)).toBe(true);
        });

        it('should filter by status', async () => {
            const event = mockEvent({
                queryStringParameters: { status: 'active' },
            }, auth);
            
            const result = await listGoldRateAlerts(event, mockContext, () => {});
            expect(result.statusCode).toBe(200);
        });
    });

    // ═══════════════════════════════════════════════════════════════════════
    // MAKING CHARGES CONFIGS (4 endpoints)
    // ═══════════════════════════════════════════════════════════════════════

    describe('POST /jewellery/making-charges-configs', () => {
        it('should create per-gram config', async () => {
            const event = mockEvent({
                body: JSON.stringify({
                    name: 'Simple Chain Per Gram',
                    type: 'perGram',
                    ratePaisaPerGram: 50000,
                    minimumChargePaisa: 20000,
                }),
            }, auth);

            const result = await createMakingChargesConfig(event, mockContext, () => {});
            
            expect(result.statusCode).toBe(201);
            const body = JSON.parse(result.body);
            expect(body.id).toBeDefined();
        });

        it('should create tiered config', async () => {
            const event = mockEvent({
                body: JSON.stringify({
                    name: 'Tiered Light Weight',
                    type: 'tiered',
                    tieredRates: [
                        { minWeightGrams: 0, maxWeightGrams: 2, ratePaisaPerGram: 100000 },
                        { minWeightGrams: 2, maxWeightGrams: 5, ratePaisaPerGram: 80000 },
                        { minWeightGrams: 5, maxWeightGrams: 999999, ratePaisaPerGram: 50000 },
                    ],
                }),
            }, auth);

            const result = await createMakingChargesConfig(event, mockContext, () => {});
            expect(result.statusCode).toBe(201);
        });

        it('should reject invalid charge type', async () => {
            const event = mockEvent({
                body: JSON.stringify({
                    name: 'Invalid Config',
                    type: 'invalid_type',
                }),
            }, auth);

            const result = await createMakingChargesConfig(event, mockContext, () => {});
            expect(result.statusCode).toBe(400);
        });
    });

    describe('GET /jewellery/making-charges-configs', () => {
        it('should list all configs for tenant', async () => {
            const event = mockEvent({}, auth);
            const result = await listMakingChargesConfigs(event, mockContext, () => {});
            
            expect(result.statusCode).toBe(200);
            const body = JSON.parse(result.body);
            expect(Array.isArray(body.data)).toBe(true);
        });
    });

    // ═══════════════════════════════════════════════════════════════════════
    // REPAIR JOBS (7 endpoints)
    // ═══════════════════════════════════════════════════════════════════════

    describe('POST /jewellery/repairs', () => {
        it('should create repair job', async () => {
            const event = mockEvent({
                body: JSON.stringify({
                    customerId: 'cust-123',
                    customerName: 'Rajesh Kumar',
                    customerPhone: '+91-98765-43210',
                    itemDescription: '22K Gold Ring - Stone Loose',
                    itemCategory: 'Ring',
                    metalType: 'GOLD_22K',
                    weightGrams: 8.5,
                    priority: 'high',
                    promisedDate: '2024-01-20T00:00:00Z',
                    estimatedDays: 5,
                    estimatedCostPaisa: 50000,
                }),
            }, auth);

            const result = await createRepairJob(event, mockContext, () => {});
            
            expect(result.statusCode).toBe(201);
            const body = JSON.parse(result.body);
            expect(body.id).toBeDefined();
            expect(body.jobNumber).toMatch(/^JOB-\d{4}-\d{4}$/);
        });

        it('should reject missing customer name', async () => {
            const event = mockEvent({
                body: JSON.stringify({
                    customerId: 'cust-123',
                    itemDescription: 'Test item',
                }),
            }, auth);

            const result = await createRepairJob(event, mockContext, () => {});
            expect(result.statusCode).toBe(400);
        });

        it('should validate priority enum', async () => {
            const event = mockEvent({
                body: JSON.stringify({
                    customerId: 'cust-123',
                    customerName: 'Test',
                    itemDescription: 'Test item',
                    priority: 'invalid_priority',
                }),
            }, auth);

            const result = await createRepairJob(event, mockContext, () => {});
            expect(result.statusCode).toBe(400);
        });
    });

    describe('GET /jewellery/repairs', () => {
        it('should list all repair jobs', async () => {
            const event = mockEvent({}, auth);
            const result = await listRepairJobs(event, mockContext, () => {});
            
            expect(result.statusCode).toBe(200);
            const body = JSON.parse(result.body);
            expect(Array.isArray(body.data)).toBe(true);
        });

        it('should filter by status', async () => {
            const event = mockEvent({
                queryStringParameters: { status: 'pending' },
            }, auth);
            
            const result = await listRepairJobs(event, mockContext, () => {});
            expect(result.statusCode).toBe(200);
        });

        it('should filter by customer', async () => {
            const event = mockEvent({
                queryStringParameters: { customerId: 'cust-123' },
            }, auth);
            
            const result = await listRepairJobs(event, mockContext, () => {});
            expect(result.statusCode).toBe(200);
        });
    });

    describe('POST /jewellery/repairs/{id}/status', () => {
        it('should update repair status', async () => {
            // First create a job
            const createEvent = mockEvent({
                body: JSON.stringify({
                    customerId: 'cust-123',
                    customerName: 'Test Customer',
                    itemDescription: 'Test item',
                }),
            }, auth);
            const createResult = await createRepairJob(createEvent, mockContext, () => {});
            const { id } = JSON.parse(createResult.body);

            // Update status
            const updateEvent = mockEvent({
                pathParameters: { id },
                body: JSON.stringify({
                    status: 'inProgress',
                    notes: 'Started work',
                }),
            }, auth);

            const result = await updateRepairStatus(updateEvent, mockContext, () => {});
            
            expect(result.statusCode).toBe(200);
            const body = JSON.parse(result.body);
            expect(body.message).toContain('inProgress');
        });

        it('should reject invalid status transition', async () => {
            const event = mockEvent({
                pathParameters: { id: 'invalid-id' },
                body: JSON.stringify({
                    status: 'invalid_status',
                }),
            }, auth);

            const result = await updateRepairStatus(event, mockContext, () => {});
            expect(result.statusCode).toBe(400);
        });
    });

    // ═══════════════════════════════════════════════════════════════════════
    // GOLD SCHEMES (5 endpoints)
    // ═══════════════════════════════════════════════════════════════════════

    describe('POST /jewellery/gold-schemes', () => {
        it('should create 11+1 scheme', async () => {
            const event = mockEvent({
                body: JSON.stringify({
                    customerId: 'cust-123',
                    customerName: 'Priya Sharma',
                    customerPhone: '+91-98765-43210',
                    schemeName: 'Monthly Gold Savings',
                    installmentAmountPaisa: 500000,
                    totalInstallments: 12,
                    frequency: 'monthly',
                    bonusPercentage: 9.09,
                    plannedRedemptionType: 'goldJewellery',
                }),
            }, auth);

            const result = await createGoldScheme(event, mockContext, () => {});
            
            expect(result.statusCode).toBe(201);
            const body = JSON.parse(result.body);
            expect(body.id).toBeDefined();
            expect(body.schemeNumber).toMatch(/^GS-\d{4}-\d{4}$/);
        });

        it('should create gold-linked scheme', async () => {
            const event = mockEvent({
                body: JSON.stringify({
                    customerId: 'cust-456',
                    customerName: 'Amit Patel',
                    installmentAmountPaisa: 1000000,
                    totalInstallments: 12,
                    frequency: 'monthly',
                    isGoldLinked: true,
                    linkedMetalType: 'GOLD_22K',
                    minimumInstallmentsForRedemption: 6,
                }),
            }, auth);

            const result = await createGoldScheme(event, mockContext, () => {});
            expect(result.statusCode).toBe(201);
        });

        it('should reject invalid installment amount', async () => {
            const event = mockEvent({
                body: JSON.stringify({
                    customerId: 'cust-123',
                    customerName: 'Test',
                    installmentAmountPaisa: 500, // Below minimum
                    totalInstallments: 12,
                }),
            }, auth);

            const result = await createGoldScheme(event, mockContext, () => {});
            expect(result.statusCode).toBe(400);
        });

        it('should reject too many installments', async () => {
            const event = mockEvent({
                body: JSON.stringify({
                    customerId: 'cust-123',
                    customerName: 'Test',
                    installmentAmountPaisa: 500000,
                    totalInstallments: 100, // Above max
                }),
            }, auth);

            const result = await createGoldScheme(event, mockContext, () => {});
            expect(result.statusCode).toBe(400);
        });
    });

    describe('GET /jewellery/gold-schemes', () => {
        it('should list all schemes', async () => {
            const event = mockEvent({}, auth);
            const result = await listGoldSchemes(event, mockContext, () => {});
            
            expect(result.statusCode).toBe(200);
            const body = JSON.parse(result.body);
            expect(Array.isArray(body.data)).toBe(true);
        });

        it('should filter by status', async () => {
            const event = mockEvent({
                queryStringParameters: { status: 'active' },
            }, auth);
            
            const result = await listGoldSchemes(event, mockContext, () => {});
            expect(result.statusCode).toBe(200);
        });
    });

    describe('POST /jewellery/gold-schemes/{id}/payments', () => {
        it('should record installment payment', async () => {
            // Create scheme first
            const createEvent = mockEvent({
                body: JSON.stringify({
                    customerId: 'cust-123',
                    customerName: 'Test Customer',
                    installmentAmountPaisa: 500000,
                    totalInstallments: 12,
                }),
            }, auth);
            const createResult = await createGoldScheme(createEvent, mockContext, () => {});
            const { id } = JSON.parse(createResult.body);

            // Record payment
            const paymentEvent = mockEvent({
                pathParameters: { id },
                body: JSON.stringify({
                    installmentNumber: 1,
                    paidAmountPaisa: 500000,
                    paymentMode: 'Cash',
                }),
            }, auth);

            const result = await recordSchemePayment(paymentEvent, mockContext, () => {});
            
            expect(result.statusCode).toBe(200);
        });

        it('should reject invalid installment number', async () => {
            const event = mockEvent({
                pathParameters: { id: 'scheme-123' },
                body: JSON.stringify({
                    installmentNumber: 0, // Invalid
                    paidAmountPaisa: 500000,
                }),
            }, auth);

            const result = await recordSchemePayment(event, mockContext, () => {});
            expect(result.statusCode).toBe(400);
        });
    });

    describe('POST /jewellery/gold-schemes/{id}/redeem', () => {
        it('should redeem scheme for jewellery', async () => {
            // Create and complete scheme
            const createEvent = mockEvent({
                body: JSON.stringify({
                    customerId: 'cust-123',
                    customerName: 'Test',
                    installmentAmountPaisa: 500000,
                    totalInstallments: 3, // Small for testing
                }),
            }, auth);
            const createResult = await createGoldScheme(createEvent, mockContext, () => {});
            const { id } = JSON.parse(createResult.body);

            // Pay all installments
            for (let i = 1; i <= 3; i++) {
                const paymentEvent = mockEvent({
                    pathParameters: { id },
                    body: JSON.stringify({
                        installmentNumber: i,
                        paidAmountPaisa: 500000,
                    }),
                }, auth);
                await recordSchemePayment(paymentEvent, mockContext, () => {});
            }

            // Redeem
            const redeemEvent = mockEvent({
                pathParameters: { id },
                body: JSON.stringify({
                    redemptionType: 'goldJewellery',
                    productName: '22K Gold Chain',
                }),
            }, auth);

            const result = await redeemGoldScheme(redeemEvent, mockContext, () => {});
            
            expect(result.statusCode).toBe(200);
            const body = JSON.parse(result.body);
            expect(body.redemptionId).toBeDefined();
        });

        it('should reject redemption of incomplete scheme', async () => {
            const event = mockEvent({
                pathParameters: { id: 'incomplete-scheme' },
                body: JSON.stringify({
                    redemptionType: 'goldJewellery',
                }),
            }, auth);

            const result = await redeemGoldScheme(event, mockContext, () => {});
            expect(result.statusCode).toBe(400);
        });
    });

    // ═══════════════════════════════════════════════════════════════════════
    // AUTHORIZATION TESTS
    // ═══════════════════════════════════════════════════════════════════════

    describe('Authorization', () => {
        it('should reject unauthenticated requests', async () => {
            const event = mockEvent({}); // No auth
            const result = await listGoldRateAlerts(event, mockContext, () => {});
            expect(result.statusCode).toBe(401);
        });

        it('should reject non-jewellery business types', async () => {
            const groceryAuth = mockAuth({ 
                tenantId, 
                sub: userId, 
                role: 'OWNER',
                businessType: 'GROCERY'
            });
            const event = mockEvent({}, groceryAuth);
            const result = await createGoldRateAlert(event, mockContext, () => {});
            expect(result.statusCode).toBe(403);
        });

        it('should allow VIEWER to list but not create', async () => {
            const viewerAuth = mockAuth({ tenantId, sub: userId, role: 'VIEWER' });
            
            // Should allow list
            const listEvent = mockEvent({}, viewerAuth);
            const listResult = await listGoldRateAlerts(listEvent, mockContext, () => {});
            expect(listResult.statusCode).toBe(200);

            // Should reject create
            const createEvent = mockEvent({
                body: JSON.stringify({
                    metalType: 'GOLD_22K',
                    thresholdRatePaisaPerGram: 650000,
                    direction: 'above',
                    method: 'push',
                }),
            }, viewerAuth);
            const createResult = await createGoldRateAlert(createEvent, mockContext, () => {});
            expect(createResult.statusCode).toBe(403);
        });
    });
});
