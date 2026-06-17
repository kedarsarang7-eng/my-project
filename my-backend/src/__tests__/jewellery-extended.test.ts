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
import { mockEvent as originalMockEvent, mockContext, mockAuth } from './utils/mock-lambda';
import { Keys } from '../config/dynamodb.config';

const dbStore = new Map<string, any>();

jest.mock('../config/dynamodb.config', () => {
  const original = jest.requireActual('../config/dynamodb.config');
  return {
    ...original,
    putItem: jest.fn().mockImplementation(async (item: any) => {
      const pk = item.PK;
      const sk = item.SK;
      dbStore.set(`${pk}:::${sk}`, item);
      return item;
    }),
    getItem: jest.fn().mockImplementation(async (pk: string, sk: string) => {
      return dbStore.get(`${pk}:::${sk}`) || null;
    }),
    updateItem: jest.fn().mockImplementation(async (pk: string, sk: string, updates: any) => {
      const key = `${pk}:::${sk}`;
      const existing = dbStore.get(key) || {};
      
      if (updates && typeof updates === 'object' && 'updateExpression' in updates) {
        const values = updates.expressionAttributeValues || {};
        const names = updates.expressionAttributeNames || {};
        const expr = updates.updateExpression;
        if (expr && expr.startsWith('SET ')) {
          const parts = expr.substring(4).split(',');
          for (const part of parts) {
            const [left, right] = part.split('=').map((s: string) => s.trim());
            const cleanLeft = left.startsWith('#') ? names[left] || left.substring(1) : left;
            const cleanRight = right.startsWith(':') ? values[right] : right;
            existing[cleanLeft] = cleanRight;
          }
        }
      } else if (updates && typeof updates === 'object') {
        Object.assign(existing, updates);
      }
      
      dbStore.set(key, existing);
      return existing;
    }),
    deleteItem: jest.fn().mockImplementation(async (pk: string, sk: string) => {
      dbStore.delete(`${pk}:::${sk}`);
      return {};
    }),
    queryItems: jest.fn().mockImplementation(async (pk: string, skPrefix: string) => {
      const items: any[] = [];
      dbStore.forEach((value, key) => {
        if (key.startsWith(`${pk}:::`)) {
          const sk = key.split(':::')[1];
          if (sk.startsWith(skPrefix)) {
            items.push(value);
          }
        }
      });
      return { items };
    }),
  };
});

jest.mock('../middleware/cognito-auth', () => {
  const { AuthError } = require('../utils/errors');
  return {
    verifyAuth: jest.fn().mockImplementation(async (event) => {
      const authHeader = event.headers?.authorization || event.headers?.Authorization;
      if (!authHeader) {
        throw new AuthError('Missing Authorization header', 401);
      }
      if (authHeader.startsWith('Bearer base64:')) {
        const token = authHeader.replace(/^Bearer base64:/, '');
        try {
          return JSON.parse(Buffer.from(token, 'base64').toString('utf8'));
        } catch (e) {
          // fallback
        }
      }
      return {
        sub: 'test-user-456',
        email: 'test@example.com',
        tenantId: 'test-tenant-123',
        businessId: 'test-tenant-123',
        role: 'owner',
        businessType: 'jewellery',
      };
    }),
  };
});

jest.mock('../middleware/plan-guard', () => ({
  validateFeatureAccess: jest.fn().mockResolvedValue(undefined),
  enforceLimits: jest.fn().mockResolvedValue(undefined),
}));

jest.mock('../middleware/software-lock', () => ({
  checkSoftwareLock: jest.fn().mockResolvedValue({ allowed: true, lockLevel: 'none', userMessage: '' }),
  LockLevel: {
    NONE: 'none',
    WARNING: 'warning',
    PARTIAL: 'partial',
    FULL: 'full',
  },
}));

function mockEvent(options: any = {}, auth?: any, method?: string) {
  const event = originalMockEvent(options, auth);
  if (auth) {
    const base64Auth = Buffer.from(JSON.stringify(auth)).toString('base64');
    event.headers = {
      ...event.headers,
      authorization: `Bearer base64:${base64Auth}`,
    };
  }
  const finalMethod = method || (options.body ? 'POST' : 'GET');
  if (event.requestContext?.http) {
    event.requestContext.http.method = finalMethod;
  }
  return event;
}

describe('Jewellery Extended Features', () => {
    const tenantId = 'test-tenant-123';
    const userId = 'test-user-456';
    const customerId1 = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
    const customerId2 = 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22';
    const auth = mockAuth({ tenantId, sub: userId, role: UserRole.OWNER });

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

            const result = await createGoldRateAlert(event, mockContext) as any;
            
            expect(result.statusCode).toBe(201);
            const body = JSON.parse(result.body);
            expect(body.data.id).toBeDefined();
            expect(body.data.message).toBe('Alert created successfully');
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

            const result = await createGoldRateAlert(event, mockContext) as any;
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

            const result = await createGoldRateAlert(event, mockContext) as any;
            expect(result.statusCode).toBe(400);
        });
    });

    describe('GET /jewellery/gold-rate-alerts', () => {
        it('should list user alerts', async () => {
            const event = mockEvent({}, auth);
            const result = await listGoldRateAlerts(event, mockContext) as any;
            
            expect(result.statusCode).toBe(200);
            const body = JSON.parse(result.body);
            expect(Array.isArray(body.data.data)).toBe(true);
        });

        it('should filter by status', async () => {
            const event = mockEvent({
                queryStringParameters: { status: 'active' },
            }, auth);
            
            const result = await listGoldRateAlerts(event, mockContext) as any;
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

            const result = await createMakingChargesConfig(event, mockContext) as any;
            
            expect(result.statusCode).toBe(201);
            const body = JSON.parse(result.body);
            expect(body.data.id).toBeDefined();
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

            const result = await createMakingChargesConfig(event, mockContext) as any;
            expect(result.statusCode).toBe(201);
        });

        it('should reject invalid charge type', async () => {
            const event = mockEvent({
                body: JSON.stringify({
                    name: 'Invalid Config',
                    type: 'invalid_type',
                }),
            }, auth);

            const result = await createMakingChargesConfig(event, mockContext) as any;
            expect(result.statusCode).toBe(400);
        });
    });

    describe('GET /jewellery/making-charges-configs', () => {
        it('should list all configs for tenant', async () => {
            const event = mockEvent({}, auth);
            const result = await listMakingChargesConfigs(event, mockContext) as any;
            
            expect(result.statusCode).toBe(200);
            const body = JSON.parse(result.body);
            expect(Array.isArray(body.data.data)).toBe(true);
        });
    });

    // ═══════════════════════════════════════════════════════════════════════
    // REPAIR JOBS (7 endpoints)
    // ═══════════════════════════════════════════════════════════════════════

    describe('POST /jewellery/repairs', () => {
        it('should create repair job', async () => {
            const event = mockEvent({
                body: JSON.stringify({
                    customerId: customerId1,
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

            const result = await createRepairJob(event, mockContext) as any;
            
            expect(result.statusCode).toBe(201);
            const body = JSON.parse(result.body);
            expect(body.data.id).toBeDefined();
            expect(body.data.jobNumber).toMatch(/^JOB-\d{4}-\d{4}$/);
        });

        it('should reject missing customer name', async () => {
            const event = mockEvent({
                body: JSON.stringify({
                    customerId: customerId1,
                    itemDescription: 'Test item',
                }),
            }, auth);

            const result = await createRepairJob(event, mockContext) as any;
            expect(result.statusCode).toBe(400);
        });

        it('should validate priority enum', async () => {
            const event = mockEvent({
                body: JSON.stringify({
                    customerId: customerId1,
                    customerName: 'Test',
                    itemDescription: 'Test item',
                    priority: 'invalid_priority',
                }),
            }, auth);

            const result = await createRepairJob(event, mockContext) as any;
            expect(result.statusCode).toBe(400);
        });
    });

    describe('GET /jewellery/repairs', () => {
        it('should list all repair jobs', async () => {
            const event = mockEvent({}, auth);
            const result = await listRepairJobs(event, mockContext) as any;
            
            expect(result.statusCode).toBe(200);
            const body = JSON.parse(result.body);
            expect(Array.isArray(body.data.data)).toBe(true);
        });

        it('should filter by status', async () => {
            const event = mockEvent({
                queryStringParameters: { status: 'pending' },
            }, auth);
            
            const result = await listRepairJobs(event, mockContext) as any;
            expect(result.statusCode).toBe(200);
        });

        it('should filter by customer', async () => {
            const event = mockEvent({
                queryStringParameters: { customerId: customerId1 },
            }, auth);
            
            const result = await listRepairJobs(event, mockContext) as any;
            expect(result.statusCode).toBe(200);
        });
    });

    describe('POST /jewellery/repairs/{id}/status', () => {
        it('should update repair status', async () => {
            // First create a job
            const createEvent = mockEvent({
                body: JSON.stringify({
                    customerId: customerId1,
                    customerName: 'Test Customer',
                    itemDescription: 'Test item',
                }),
            }, auth);
            const createResult = await createRepairJob(createEvent, mockContext) as any;
            const { id } = JSON.parse(createResult.body).data;

            // Update status
            const updateEvent = mockEvent({
                pathParameters: { id },
                body: JSON.stringify({
                    status: 'inProgress',
                    notes: 'Started work',
                }),
            }, auth);

            const result = await updateRepairStatus(updateEvent, mockContext) as any;
            
            expect(result.statusCode).toBe(200);
            const body = JSON.parse(result.body);
            expect(body.data.message).toContain('inProgress');
        });

        it('should reject invalid status transition', async () => {
            const event = mockEvent({
                pathParameters: { id: 'invalid-id' },
                body: JSON.stringify({
                    status: 'invalid_status',
                }),
            }, auth);

            const result = await updateRepairStatus(event, mockContext) as any;
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
                    customerId: customerId1,
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

            const result = await createGoldScheme(event, mockContext) as any;
            
            expect(result.statusCode).toBe(201);
            const body = JSON.parse(result.body);
            expect(body.data.id).toBeDefined();
            expect(body.data.schemeNumber).toMatch(/^GS-\d{4}-\d{4}$/);
        });

        it('should create gold-linked scheme', async () => {
            const event = mockEvent({
                body: JSON.stringify({
                    customerId: customerId2,
                    customerName: 'Amit Patel',
                    installmentAmountPaisa: 1000000,
                    totalInstallments: 12,
                    frequency: 'monthly',
                    isGoldLinked: true,
                    linkedMetalType: 'GOLD_22K',
                    minimumInstallmentsForRedemption: 6,
                }),
            }, auth);

            const result = await createGoldScheme(event, mockContext) as any;
            expect(result.statusCode).toBe(201);
        });

        it('should reject invalid installment amount', async () => {
            const event = mockEvent({
                body: JSON.stringify({
                    customerId: customerId1,
                    customerName: 'Test',
                    installmentAmountPaisa: 500, // Below minimum
                    totalInstallments: 12,
                }),
            }, auth);

            const result = await createGoldScheme(event, mockContext) as any;
            expect(result.statusCode).toBe(400);
        });

        it('should reject too many installments', async () => {
            const event = mockEvent({
                body: JSON.stringify({
                    customerId: customerId1,
                    customerName: 'Test',
                    installmentAmountPaisa: 500000,
                    totalInstallments: 100, // Above max
                }),
            }, auth);

            const result = await createGoldScheme(event, mockContext) as any;
            expect(result.statusCode).toBe(400);
        });
    });

    describe('POST /jewellery/gold-schemes/{id}/payments', () => {
        it('should record installment payment', async () => {
            // Create scheme first
            const createEvent = mockEvent({
                body: JSON.stringify({
                    customerId: customerId1,
                    customerName: 'Test Customer',
                    installmentAmountPaisa: 500000,
                    totalInstallments: 12,
                }),
            }, auth);
            const createResult = await createGoldScheme(createEvent, mockContext) as any;
            const { id } = JSON.parse(createResult.body).data;

            // Record payment
            const paymentEvent = mockEvent({
                pathParameters: { id },
                body: JSON.stringify({
                    installmentNumber: 1,
                    paidAmountPaisa: 500000,
                    paymentMode: 'Cash',
                }),
            }, auth);

            const result = await recordSchemePayment(paymentEvent, mockContext) as any;
            
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

            const result = await recordSchemePayment(event, mockContext) as any;
            expect(result.statusCode).toBe(400);
        });
    });

    describe('POST /jewellery/gold-schemes/{id}/redeem', () => {
        it('should redeem scheme for jewellery', async () => {
            // Create and complete scheme
            const createEvent = mockEvent({
                body: JSON.stringify({
                    customerId: customerId1,
                    customerName: 'Test',
                    installmentAmountPaisa: 500000,
                    totalInstallments: 3, // Small for testing
                }),
            }, auth);
            const createResult = await createGoldScheme(createEvent, mockContext) as any;
            const { id } = JSON.parse(createResult.body).data;

            // Pay all installments
            for (let i = 1; i <= 3; i++) {
                const paymentEvent = mockEvent({
                    pathParameters: { id },
                    body: JSON.stringify({
                        installmentNumber: i,
                        paidAmountPaisa: 500000,
                    }),
                }, auth);
                await recordSchemePayment(paymentEvent, mockContext) as any;
            }

            // Redeem
            const redeemEvent = mockEvent({
                pathParameters: { id },
                body: JSON.stringify({
                    redemptionType: 'goldJewellery',
                    productName: '22K Gold Chain',
                }),
            }, auth);

            const result = await redeemGoldScheme(redeemEvent, mockContext) as any;
            
            expect(result.statusCode).toBe(200);
            const body = JSON.parse(result.body);
            expect(body.data.redemptionId).toBeDefined();
        });

        it('should reject redemption of incomplete scheme', async () => {
            // Create an incomplete scheme in database
            const incompleteId = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a99';
            const timestamp = new Date().toISOString();
            const payments = [
                {
                    id: 'payment-1',
                    installmentNumber: 1,
                    amountPaisa: 500000,
                    dueDate: timestamp,
                    isPaid: false,
                    isLate: false,
                }
            ];
            const incompleteScheme = {
                PK: Keys.tenantPK(tenantId),
                SK: Keys.goldSchemeSK(incompleteId),
                entityType: 'GOLD_SCHEME',
                id: incompleteId,
                tenantId,
                status: 'active',
                payments,
                completedInstallments: 0, // Incomplete!
                totalInstallments: 1,
                totalPaidPaisa: 0,
            };
            dbStore.set(`${Keys.tenantPK(tenantId)}:::${Keys.goldSchemeSK(incompleteId)}`, incompleteScheme);

            const event = mockEvent({
                pathParameters: { id: incompleteId },
                body: JSON.stringify({
                    redemptionType: 'goldJewellery',
                }),
            }, auth);

            const result = await redeemGoldScheme(event, mockContext) as any;
            expect(result.statusCode).toBe(400);
        });
    });

    // ═══════════════════════════════════════════════════════════════════════
    // AUTHORIZATION TESTS
    // ═══════════════════════════════════════════════════════════════════════

    describe('Authorization', () => {
        it('should reject unauthenticated requests', async () => {
            const event = mockEvent({}); // No auth
            const result = await listGoldRateAlerts(event, mockContext) as any;
            expect(result.statusCode).toBe(401);
        });

        it('should reject non-jewellery business types', async () => {
            const groceryAuth = mockAuth({ 
                tenantId, 
                sub: userId, 
                role: UserRole.OWNER,
                businessType: BusinessType.GROCERY
            });
            const event = mockEvent({}, groceryAuth);
            const result = await createGoldRateAlert(event, mockContext) as any;
            expect(result.statusCode).toBe(403);
        });

        it('should allow VIEWER to list but not create', async () => {
            const viewerAuth = mockAuth({ tenantId, sub: userId, role: UserRole.VIEWER });
            
            // Should allow list
            const listEvent = mockEvent({}, viewerAuth);
            const listResult = await listGoldRateAlerts(listEvent, mockContext) as any;
            console.log("VIEWER LIST RESULT IS:", JSON.stringify(listResult, null, 2));
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
            const createResult = await createGoldRateAlert(createEvent, mockContext) as any;
            expect(createResult.statusCode).toBe(403);
        });
    });
});

