import { z } from 'zod';

// ============================================
// 1. Petrol Pump Schemas
// ============================================

export const pumpReadingSchema = z.object({
    readings: z.array(z.object({
        nozzleId: z.string().uuid(),
        dispenserId: z.string().uuid(),
        tankId: z.string().uuid(),
        readingType: z.enum(['opening', 'closing', 'testing']),
        readingValue: z.number().positive(),
        testingAmount: z.number().nonnegative().optional(), // For 5L tests
        notes: z.string().max(255).optional()
    })).min(1).max(50),
    shiftId: z.string().uuid(),
});

// BUG-PP-002 FIX: Discriminated union — udhar requires customerId to prevent ghost debt
const pumpSaleBase = z.object({
    nozzleId: z.string().uuid(),
    fuelType: z.enum(['petrol', 'diesel', 'cng', 'other']),
    volumeLiters: z.number().positive(),
    pricePerLiterCents: z.number().int().positive(),
    totalAmountCents: z.number().int().positive(),
    vehicleNumber: z.string().max(20).optional(),
    shiftId: z.string().uuid(),
});

const pumpSaleNonUdhar = pumpSaleBase.extend({
    paymentMode: z.enum(['cash', 'upi', 'card', 'petro_card', 'fleet_card', 'cheque', 'neft', 'bank_transfer', 'wallet']),
    customerId: z.string().uuid().optional(),
    paymentReference: z.string().max(100).optional(),
});

const pumpSaleUdhar = pumpSaleBase.extend({
    paymentMode: z.literal('udhar'),
    customerId: z.string().uuid(), // STRICTLY REQUIRED for udhar
    paymentReference: z.string().max(100).optional(),
});

export const pumpSaleSchema = z.discriminatedUnion('paymentMode', [
    pumpSaleNonUdhar,
    pumpSaleUdhar,
]);


export const cashDropSchema = z.object({
    amountCents: z.number().int().positive(),
    denominations: z.record(z.string(), z.number().int().nonnegative()).optional(),
    notes: z.string().max(255).optional(),
    shiftId: z.string().uuid()
});

// ============================================
// 1c. Shift Lifecycle Schemas (BUG-PP-004 FIX)
// ============================================

export const shiftOpenSchema = z.object({
    shiftLabel: z.string().max(50).optional(),          // e.g. "Morning", "Evening"
    nozzleAssignments: z.array(z.object({
        nozzleId: z.string().uuid(),
        openingReading: z.number().nonnegative(),
    })).min(1).max(20),
    notes: z.string().max(255).optional(),
});

export const shiftCloseSchema = z.object({
    shiftId: z.string().uuid(),
    nozzleReadings: z.array(z.object({
        nozzleId: z.string().uuid(),
        closingReading: z.number().nonnegative(),
        testingAmount: z.number().nonnegative().optional(),
    })).min(1).max(20),
    notes: z.string().max(255).optional(),
    // Digital handover sign-off (BUG-PP-HANDOVER FIX)
    cashierSignatureUrl: z.string().url().max(2000).optional(),
    cashierAcknowledgedAt: z.string().datetime().optional(),
    handoverNotes: z.string().max(1000).optional(),
});

export const shiftHandoverAckSchema = z.object({
    shiftId: z.string().uuid(),
    receiverStaffId: z.string().uuid(),
    receiverSignatureUrl: z.string().url().max(2000),
    accepted: z.boolean(),
    discrepancyNotes: z.string().max(1000).optional(),
});

export const shiftDsrApproveSchema = z.object({
    shiftId: z.string().uuid(),
    approvalNotes: z.string().max(1000).optional(),
});

// ============================================
// 1d. Vehicle Master Schema (BUG-PP-009 FIX)
// ============================================

export const vehicleUpsertSchema = z.object({
    vehicleNumber: z.string().min(4).max(20),           // Raw input — normalized server-side
    customerId: z.string().uuid().optional(),            // Link to fleet customer
    vehicleType: z.enum(['two_wheeler', 'car', 'auto', 'bus', 'truck', 'tractor', 'other']).optional(),
    fuelType: z.enum(['petrol', 'diesel', 'cng', 'other']).optional(),
    notes: z.string().max(255).optional(),
});



// ============================================
// 1b. Staff Sale Entry Schemas (Petrol Pump)
// ============================================

export const staffSaleSchema = z.object({
    productType: z.enum(['petrol', 'diesel', 'lub_oil', 'cng', 'other']),
    amountCents: z.number().int().positive(),
    paymentMode: z.enum(['cash', 'online', 'upi', 'card', 'petro_card', 'fleet_card', 'cheque', 'neft', 'bank_transfer', 'wallet', 'udhar']),
    volumeLiters: z.number().positive().optional(),     // Needed for price validation
    vehicleNumber: z.string().max(20).optional(),
    customerName: z.string().max(100).optional(),
    customerId: z.string().uuid().optional(),
    nozzleId: z.string().uuid().optional(),
    shiftId: z.string().uuid(),
    paymentReference: z.string().max(100).optional(),
    notes: z.string().max(255).optional(),
}).refine(
    (data) => data.paymentMode !== 'udhar' || !!data.customerId,
    { message: 'customerId is required for udhar (credit) sales', path: ['customerId'] }
);

export const staffSaleQrSchema = z.object({
    productType: z.enum(['petrol', 'diesel', 'lub_oil', 'cng', 'other']),
    amountCents: z.number().int().positive(),
    vehicleNumber: z.string().max(20).optional(),
    customerName: z.string().max(100).optional(),
});

export const staffSaleHistoryQuerySchema = z.object({
    staffId: z.string().uuid().optional(),
    dateFrom: z.string().optional(),
    dateTo: z.string().optional(),
    productType: z.enum(['petrol', 'diesel', 'lub_oil', 'cng', 'other']).optional(),
    paymentMode: z.enum(['cash', 'online', 'udhar']).optional(),
    limit: z.coerce.number().int().min(1).max(100).default(50),
    offset: z.coerce.number().int().min(0).default(0),
});

// ============================================
// 2. Restaurant KOT Schemas
// ============================================

export const kotItemSchema = z.object({
    menuItemId: z.string().uuid(),
    quantity: z.number().positive().int(),
    notes: z.string().max(255).optional(),
    addons: z.array(z.string().uuid()).optional(),
    itemDiscountCents: z.number().int().min(0).optional(),
    itemDiscountPercent: z.number().min(0).max(100).optional(),
    managerOverride: z.object({
        managerUserId: z.string().min(1).max(100),
        managerPin: z.string().min(1).max(20),
        reason: z.string().max(300).optional(),
    }).optional(),
});

// RESTO-003/004: Supports dine_in, takeaway, and delivery order types
export const createKotSchema = z.object({
    orderType: z.enum(['dine_in', 'takeaway', 'delivery']).default('dine_in'),
    tableId: z.string().uuid().optional(),
    waiterId: z.string().uuid().optional(),
    items: z.array(kotItemSchema).min(1),
    customerCount: z.number().int().positive().optional(),
    notes: z.string().max(255).optional(),
    // Aggregator / Delivery fields
    orderSource: z.enum(['direct', 'zomato', 'swiggy', 'other']).default('direct'),
    aggregatorOrderId: z.string().max(100).optional(),
    packagingChargeCents: z.number().int().min(0).default(0),
    deliveryAddress: z.string().max(500).optional(),
    customerName: z.string().max(100).optional(),
    customerPhone: z.string().max(20).optional(),
}).refine(
    (data) => data.orderType !== 'dine_in' || !!data.tableId,
    { message: 'tableId is required for dine-in orders', path: ['tableId'] }
);

// RESTO-016/019: KOT item status update
export const updateKotItemStatusSchema = z.object({
    itemStatus: z.enum(['preparing', 'ready', 'served']),
});

// RESTO-016: KOT item cancellation with reason
export const cancelKotItemSchema = z.object({
    reason: z.string().min(1).max(500).trim(),
});

// Restaurant Bill Settlement — resolves KOT items → invoice
export const settleBillSchema = z.object({
    paymentMode: z.enum(['cash', 'upi', 'card', 'bank_transfer', 'credit', 'wallet', 'split', 'unpaid']).default('cash'),
    customerName: z.string().max(100).optional(),
    customerPhone: z.string().max(20).optional(),
    customerGstin: z.string().max(15).optional(),
    isInterState: z.boolean().default(false),
    discountCents: z.number().int().min(0).default(0),
    serviceChargeCents: z.number().int().min(0).default(0),
    splitPayments: z.array(z.object({
        method: z.enum(['cash', 'upi', 'card', 'bank_transfer', 'credit', 'wallet']),
        amountCents: z.number().int().positive()
    })).optional(),
    managerOverride: z.object({
        managerUserId: z.string().min(1).max(100),
        managerPin: z.string().min(1).max(20),
        reason: z.string().max(300).optional(),
    }).optional(),
    notes: z.string().max(1000).optional(),
    metadata: z.record(z.string(), z.unknown()).default({}),
});

export const createRestoTableSchema = z.object({
    name: z.string().min(1).max(80).trim(),
    floorId: z.string().uuid().optional(),
    seatingCapacity: z.number().int().min(1).max(50),
    shape: z.enum(['square', 'round', 'rectangle', 'booth']).default('square'),
    section: z.string().max(80).optional(),
    displayOrder: z.number().int().min(0).default(0),
});

export const updateRestoTableSchema = z.object({
    name: z.string().min(1).max(80).trim().optional(),
    floorId: z.string().uuid().nullable().optional(),
    seatingCapacity: z.number().int().min(1).max(50).optional(),
    shape: z.enum(['square', 'round', 'rectangle', 'booth']).optional(),
    section: z.string().max(80).nullable().optional(),
    status: z.enum(['available', 'occupied', 'reserved', 'cleaning']).optional(),
    displayOrder: z.number().int().min(0).optional(),
    isActive: z.boolean().optional(),
});

export const createRestoMenuItemSchema = z.object({
    name: z.string().min(1).max(120).trim(),
    categoryId: z.string().uuid(),
    salePriceCents: z.number().int().positive(),
    productId: z.string().uuid().optional(),
    description: z.string().max(500).optional(),
    isVeg: z.boolean().default(false),
    isOutOfStock: z.boolean().default(false),
    prepTimeMinutes: z.number().int().min(0).max(240).optional(),
    displayOrder: z.number().int().min(0).default(0),
    imageUrl: z.string().url().max(2000).optional(),
});

export const updateRestoMenuItemSchema = z.object({
    name: z.string().min(1).max(120).trim().optional(),
    categoryId: z.string().uuid().optional(),
    salePriceCents: z.number().int().positive().optional(),
    productId: z.string().uuid().nullable().optional(),
    description: z.string().max(500).nullable().optional(),
    isVeg: z.boolean().optional(),
    isOutOfStock: z.boolean().optional(),
    prepTimeMinutes: z.number().int().min(0).max(240).nullable().optional(),
    displayOrder: z.number().int().min(0).optional(),
    imageUrl: z.string().url().max(2000).nullable().optional(),
    isActive: z.boolean().optional(),
});

export const assignDeliveryRiderSchema = z.object({
    riderId: z.string().min(1).max(100).trim(),
    riderName: z.string().min(1).max(120).trim(),
    riderPhone: z.string().max(20).optional(),
    etaMinutes: z.number().int().min(1).max(240).optional(),
});

export const updateDeliveryStatusSchema = z.object({
    status: z.enum(['assigned', 'picked_up', 'out_for_delivery', 'delivered', 'failed', 'cancelled']),
    note: z.string().max(500).optional(),
    proofOfDelivery: z.string().url().max(2000).optional(),
});

export const splitBillSchema = z.object({
    mode: z.enum(['equal', 'by_item', 'custom_amount', 'percentage']),
    peopleCount: z.number().int().min(2).max(50).optional(),
    assignments: z.array(z.object({
        personId: z.string().min(1).max(50),
        itemId: z.string().uuid().optional(),
        amountCents: z.number().int().min(0).optional(),
        percent: z.number().min(0).max(100).optional(),
    })).optional(),
}).superRefine((data, ctx) => {
    if (data.mode === 'equal' && !data.peopleCount) {
        ctx.addIssue({ code: z.ZodIssueCode.custom, message: 'peopleCount is required for equal split', path: ['peopleCount'] });
    }
    if ((data.mode === 'by_item' || data.mode === 'custom_amount' || data.mode === 'percentage') &&
        (!data.assignments || data.assignments.length === 0)) {
        ctx.addIssue({ code: z.ZodIssueCode.custom, message: 'assignments are required for selected split mode', path: ['assignments'] });
    }
});

export const comboItemRuleSchema = z.object({
    menuItemId: z.string().uuid(),
    quantity: z.number().int().min(1).max(20),
});

export const createComboSchema = z.object({
    name: z.string().min(1).max(120).trim(),
    bundlePriceCents: z.number().int().positive(),
    items: z.array(comboItemRuleSchema).min(2).max(20),
    description: z.string().max(500).optional(),
    isActive: z.boolean().default(true),
    validFrom: z.string().datetime().optional(),
    validTo: z.string().datetime().optional(),
});

export const updateComboSchema = z.object({
    name: z.string().min(1).max(120).trim().optional(),
    bundlePriceCents: z.number().int().positive().optional(),
    items: z.array(comboItemRuleSchema).min(2).max(20).optional(),
    description: z.string().max(500).nullable().optional(),
    isActive: z.boolean().optional(),
    validFrom: z.string().datetime().nullable().optional(),
    validTo: z.string().datetime().nullable().optional(),
});

export const createHappyHourSchema = z.object({
    name: z.string().min(1).max(120).trim(),
    discountType: z.enum(['percentage', 'flat']),
    discountValue: z.number().positive(),
    menuItemIds: z.array(z.string().uuid()).min(1).max(200),
    daysOfWeek: z.array(z.number().int().min(0).max(6)).min(1).max(7),
    startTime: z.string().regex(/^\d{2}:\d{2}$/),
    endTime: z.string().regex(/^\d{2}:\d{2}$/),
    validFrom: z.string().datetime().optional(),
    validTo: z.string().datetime().optional(),
    isActive: z.boolean().default(true),
});

export const updateHappyHourSchema = z.object({
    name: z.string().min(1).max(120).trim().optional(),
    discountType: z.enum(['percentage', 'flat']).optional(),
    discountValue: z.number().positive().optional(),
    menuItemIds: z.array(z.string().uuid()).min(1).max(200).optional(),
    daysOfWeek: z.array(z.number().int().min(0).max(6)).min(1).max(7).optional(),
    startTime: z.string().regex(/^\d{2}:\d{2}$/).optional(),
    endTime: z.string().regex(/^\d{2}:\d{2}$/).optional(),
    validFrom: z.string().datetime().nullable().optional(),
    validTo: z.string().datetime().nullable().optional(),
    isActive: z.boolean().optional(),
});

export const createReservationSchema = z.object({
    customerName: z.string().min(1).max(120).trim(),
    customerPhone: z.string().min(5).max(20).trim(),
    reservationDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    reservationTime: z.string().regex(/^\d{2}:\d{2}$/),
    covers: z.number().int().min(1).max(50),
    tableId: z.string().uuid().optional(),
    notes: z.string().max(500).optional(),
});

export const updateReservationStatusSchema = z.object({
    status: z.enum(['confirmed', 'cancelled', 'seated', 'no_show']),
    reason: z.string().max(300).optional(),
});

export const createWaitlistSchema = z.object({
    customerName: z.string().min(1).max(120).trim(),
    customerPhone: z.string().min(5).max(20).trim(),
    covers: z.number().int().min(1).max(50),
    notes: z.string().max(500).optional(),
});

export const seatWaitlistSchema = z.object({
    waitlistId: z.string().uuid(),
    tableId: z.string().uuid().optional(),
});

export const transferTableSchema = z.object({
    fromTableId: z.string().uuid(),
    toTableId: z.string().uuid(),
    reason: z.string().max(300).optional(),
});

export const mergeTablesSchema = z.object({
    primaryTableId: z.string().uuid(),
    secondaryTableId: z.string().uuid(),
    reason: z.string().max(300).optional(),
});

export const splitTableSchema = z.object({
    sourceTableId: z.string().uuid(),
    targetTableId: z.string().uuid(),
    amountCents: z.number().int().positive().optional(),
    reason: z.string().max(300).optional(),
});

export const kdsAnalyticsQuerySchema = z.object({
    from: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
    to: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
    slaMinutes: z.coerce.number().int().min(1).max(240).default(20),
    station: z.string().max(80).optional(),
});

export const ingestAggregatorOrderSchema = z.object({
    source: z.enum(['zomato', 'swiggy', 'ondc', 'other']),
    aggregatorOrderId: z.string().min(1).max(120),
    customerName: z.string().max(120).optional(),
    customerPhone: z.string().max(20).optional(),
    deliveryAddress: z.string().max(500).optional(),
    items: z.array(z.object({
        menuItemId: z.string().uuid(),
        quantity: z.number().int().min(1).max(50),
        notes: z.string().max(255).optional(),
    })).min(1).max(100),
    notes: z.string().max(500).optional(),
});

export const updateAggregatorStatusSchema = z.object({
    status: z.enum(['imported', 'accepted', 'preparing', 'ready_for_pickup', 'picked_up', 'delivered', 'cancelled', 'failed']),
    reason: z.string().max(300).optional(),
});

export const sendReceiptSchema = z.object({
    channel: z.enum(['email', 'sms', 'whatsapp']),
    to: z.string().min(3).max(200).optional(),
    language: z.string().max(20).optional(),
});

// ============================================
// 3. Customer Udhar Schemas
// ============================================

export const customerOrderSchema = z.object({
    items: z.array(z.object({
        inventoryId: z.string().uuid(),
        quantity: z.number().positive()
    })).min(1),
    deliveryAddress: z.string().max(500).optional(),
    orderNotes: z.string().max(255).optional(),
    expectedDeliveryTime: z.string().datetime().optional()
});

// ============================================
// 4. Service Tech Schemas
// ============================================

export const serviceJobStatusSchema = z.object({
    status: z.enum(['pending', 'in_progress', 'awaiting_parts', 'completed', 'delivered']),
    techNotes: z.string().max(1000).optional(),
    estimatedCompletion: z.string().datetime().optional()
});

export const serviceJobPartsSchema = z.object({
    parts: z.array(z.object({
        inventoryId: z.string().uuid(),
        quantity: z.number().positive(),
        priceCents: z.number().int().positive()
    })).min(1)
});

// ============================================
// 5. Clinic Doctor Schemas
// ============================================

export const clinicVisitSchema = z.object({
    patientId: z.string().uuid(),
    appointmentId: z.string().uuid().optional(),
    symptoms: z.string().max(1000),
    diagnosis: z.string().max(1000).optional(),
    vitals: z.object({
        bpParams: z.string().max(20).optional(),
        pulse: z.number().int().positive().optional(),
        temperature: z.number().positive().optional(),
        weight: z.number().positive().optional(),
        spO2: z.number().int().min(0).max(100).optional(),
    }).optional(),
    notes: z.string().max(2000).optional()
});

export const prescriptionSchema = z.object({
    visitId: z.string().uuid(),
    patientId: z.string().uuid(),
    medicines: z.array(z.object({
        medicineName: z.string().min(1).max(200),
        inventoryId: z.string().uuid().optional(), // Link to internal pharmacy if exists
        dosage: z.string().max(100),
        duration: z.string().max(50),
        instructions: z.string().max(255).optional()
    })).min(1),
    nextVisitDate: z.string().datetime().optional()
});

export const clinicFollowUpSchema = z.object({
    patientId: z.string().uuid(),
    appointmentId: z.string().uuid().optional(),
    followUpDate: z.string().datetime(),
    reason: z.string().min(1).max(1000),
    notes: z.string().max(2000).optional(),
    vitals: z.object({
        bpParams: z.string().max(20).optional(),
        pulse: z.number().int().positive().optional(),
        temperature: z.number().positive().optional(),
        weight: z.number().positive().optional()
    }).optional(),
});

export const soapNoteSchema = z.object({
    patientId: z.string().uuid(),
    appointmentId: z.string().uuid().optional(),
    subjective: z.string().min(1).max(2000),
    objective: z.string().min(1).max(2000),
    assessment: z.string().min(1).max(2000),
    plan: z.string().min(1).max(2000),
    notes: z.string().max(4000).optional(),
    vitals: z.object({
        bpParams: z.string().max(20).optional(),
        pulse: z.number().int().positive().optional(),
        temperature: z.number().positive().optional(),
        weight: z.number().positive().optional(),
        spO2: z.number().int().min(0).max(100).optional(),
    }).optional(),
});

export const clinicLabOrderSchema = z.object({
    patientId: z.string().uuid(),
    appointmentId: z.string().uuid().optional(),
    tests: z.array(z.object({
        testName: z.string().min(1).max(200),
        testCode: z.string().max(50).optional(),
        instructions: z.string().max(500).optional(),
    })).min(1),
    priority: z.enum(['routine', 'urgent', 'stat']).default('routine'),
    notes: z.string().max(2000).optional(),
});

export const clinicLabResultSchema = z.object({
    resultSummary: z.string().min(1).max(4000),
    attachments: z.array(z.string().url().max(1000)).max(20).optional(),
    notes: z.string().max(2000).optional(),
    reportedAt: z.string().datetime().optional(),
});

export const updateQueueStatusSchema = z.object({
    status: z.enum(['scheduled', 'waiting', 'in-consultation', 'completed', 'cancelled']),
});

// ============================================
// 5b. Clinic Patient Schemas
// ============================================

export const clinicPatientSchema = z.object({
    name: z.string().min(1).max(200),
    phone: z.string().max(20).optional(),
    age: z.number().int().min(0).max(150).optional(),
    gender: z.enum(['male', 'female', 'other', 'unknown']).optional(),
    bloodGroup: z.enum(['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'unknown']).optional(),
    address: z.string().max(500).optional(),
    email: z.string().email().max(200).optional(),
    emergencyContactName: z.string().max(200).optional(),
    emergencyContactPhone: z.string().max(20).optional(),
    allergies: z.string().max(1000).optional(),
    chronicConditions: z.string().max(1000).optional(),
    insuranceProvider: z.string().max(200).optional(),
    insurancePolicyNumber: z.string().max(100).optional(),
});

export const clinicPatientUpdateSchema = clinicPatientSchema.partial();

// ============================================
// 5c. Clinic Appointment Schemas
// ============================================

export const clinicAppointmentSchema = z.object({
    patientId: z.string().uuid(),
    doctorId: z.string().uuid().optional(),
    scheduledDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    scheduledTime: z.string().regex(/^\d{2}:\d{2}$/),
    duration: z.number().int().min(5).max(240).default(15),
    purpose: z.string().max(500).optional(),
    notes: z.string().max(2000).optional(),
    appointmentType: z.enum(['walk_in', 'scheduled', 'follow_up', 'emergency']).default('scheduled'),
});

export const clinicAppointmentUpdateSchema = z.object({
    scheduledDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
    scheduledTime: z.string().regex(/^\d{2}:\d{2}$/).optional(),
    duration: z.number().int().min(5).max(240).optional(),
    purpose: z.string().max(500).optional(),
    notes: z.string().max(2000).optional(),
    status: z.enum(['scheduled', 'waiting', 'in-consultation', 'completed', 'cancelled', 'no-show']).optional(),
});

// ============================================
// 5d. Clinic Doctor Profile Schemas
// ============================================

export const clinicDoctorSchema = z.object({
    name: z.string().min(1).max(200),
    specialization: z.string().max(200).optional(),
    qualification: z.string().max(500).optional(),
    registrationNumber: z.string().max(100).optional(),
    consultationFee: z.number().min(0).max(100000).default(500),
    phone: z.string().max(20).optional(),
    email: z.string().email().max(200).optional(),
    availableSlots: z.array(z.object({
        day: z.enum(['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']),
        startTime: z.string().regex(/^\d{2}:\d{2}$/),
        endTime: z.string().regex(/^\d{2}:\d{2}$/),
    })).optional(),
});

export const clinicDoctorUpdateSchema = clinicDoctorSchema.partial();

// ============================================
// 5e. Clinic Visit Update Schema
// ============================================

export const clinicVisitUpdateSchema = z.object({
    symptoms: z.string().max(1000).optional(),
    diagnosis: z.string().max(1000).optional(),
    notes: z.string().max(2000).optional(),
    vitals: z.object({
        bpParams: z.string().max(20).optional(),
        pulse: z.number().int().positive().optional(),
        temperature: z.number().positive().optional(),
        weight: z.number().positive().optional(),
        spO2: z.number().int().min(0).max(100).optional(),
    }).optional(),
    status: z.enum(['queued', 'in_progress', 'completed', 'cancelled']).optional(),
    consultationStartTime: z.string().datetime().optional(),
    consultationEndTime: z.string().datetime().optional(),
});

// ============================================
// 5f. Clinic Prescription Update Schema
// ============================================

export const clinicPrescriptionUpdateSchema = z.object({
    medicines: z.array(z.object({
        medicineName: z.string().min(1).max(200),
        inventoryId: z.string().uuid().optional(),
        dosage: z.string().max(100),
        duration: z.string().max(50),
        instructions: z.string().max(255).optional(),
    })).min(1).optional(),
    nextVisitDate: z.string().datetime().optional(),
    advice: z.string().max(2000).optional(),
});

// ============================================
// 5g. Clinic Billing Schema
// ============================================

export const clinicBillingSchema = z.object({
    patientId: z.string().uuid(),
    visitId: z.string().uuid().optional(),
    prescriptionId: z.string().uuid().optional(),
    items: z.array(z.object({
        serviceCode: z.string().min(1).max(50),
        serviceName: z.string().min(1).max(200),
        quantity: z.number().int().positive().default(1),
        unitPrice: z.number().min(0),
        discount: z.number().min(0).max(100).default(0),
    })).min(1),
    paymentMode: z.enum(['cash', 'upi', 'card', 'insurance', 'credit']).default('cash'),
    notes: z.string().max(500).optional(),
});

// ============================================
// 5h. ICD-10 & Drug Search Schemas
// ============================================

export const icd10SearchSchema = z.object({
    query: z.string().min(2).max(100),
    limit: z.number().int().min(1).max(50).default(10),
});

export const drugSearchSchema = z.object({
    query: z.string().min(2).max(100),
    limit: z.number().int().min(1).max(50).default(10),
});

// ============================================
// 5i. Refill Queue Schema
// ============================================

export const clinicRefillRequestSchema = z.object({
    prescriptionId: z.string().uuid(),
    patientId: z.string().uuid(),
    medicines: z.array(z.object({
        medicineName: z.string().min(1).max(200),
        dosage: z.string().max(100),
    })).min(1),
    notes: z.string().max(500).optional(),
});

export const fulfillSchoolOrderSchema = z.object({
    sets: z.number().int().positive(),
});

export const settleConsignmentSimpleSchema = z.object({
    amount: z.number().positive(),
});

// ============================================
// 6. Restaurant Type Exports
// ============================================

export type ManagerOverrideInput = {
    managerUserId: string;
    managerPin: string;
    reason?: string;
};
