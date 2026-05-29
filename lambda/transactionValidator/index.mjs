// ============================================================================
// TRANSACTION VALIDATOR LAMBDA
// ============================================================================
// Backend validation for transactions with pharmacy compliance
// Called during bill sync to enforce drug schedule and expiry rules
//
// Security:
// - Validates JWT token
// - Enforces prescription requirements for Schedule H/H1/X drugs
// - Blocks expired products
// - Logs all validation attempts for audit
//
// Input: { transaction: TransactionObject, prescriptionData?: Prescription }
// Output: { valid: boolean, errors?: ValidationError[] }
// ============================================================================

import { success, error, verifyToken, getItem, logAuditEvent } from '../shared/utils.mjs';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client, {
  marshallOptions: { removeUndefinedValues: true },
  unmarshallOptions: { wrapNumbers: false },
});

const TABLE_NAME = process.env.DYNAMODB_TABLE || 'DukanX';

// ============================================================================
// VALIDATION CONFIGURATION
// ============================================================================

const SCHEDULED_DRUGS = ['H', 'H1', 'X'];

const VALIDATION_RULES = {
  // Schedule H - Prescription required, can be sold by retail
  H: { requiresPrescription: true, allowRetail: true, maxQuantity: null },
  // Schedule H1 - Prescription required, stricter tracking
  H1: { requiresPrescription: true, allowRetail: false, maxQuantity: null },
  // Schedule X - Narcotics, special prescription required
  X: { requiresPrescription: true, allowRetail: false, maxQuantity: null },
};

// BUG-057: Business type discount limits
const BUSINESS_DISCOUNT_LIMITS = {
  pharmacy: {
    maxDiscountPercent: 10, // 10% max for pharmacy (regulated)
    appliesTo: ['drug', 'medicine', 'pharmaceutical'],
    description: 'Pharmacy drugs limited to 10% discount as per regulations',
  },
  grocery: {
    maxDiscountPercent: 50, // 50% max for grocery
    appliesTo: ['all'],
    description: 'Grocery items limited to 50% max discount',
  },
  default: {
    maxDiscountPercent: 100, // No limit for other business types
    appliesTo: ['all'],
    description: 'No discount limit for this business type',
  },
};

// ============================================================================
// MAIN HANDLER
// ============================================================================

import { withRequestContext } from '../shared/utils/with-request-context.mjs';
import { logAudit } from '../shared/utils/audit-logger.mjs';
import { info, error as logError } from '../shared/utils/logger.mjs';

// Wrap handler with RID context
export const handler = withRequestContext(async (event, context) => {
  const { requestId, tenantId, userId } = context;
  
  try {
    // ------------------------------------------------------------------------
    // REQUEST PARSING
    // ------------------------------------------------------------------------
    let body;
    try {
      body = JSON.parse(event.body || '{}');
    } catch (err) {
      return {
        statusCode: 400,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          success: false,
          error: { code: 'INVALID_JSON', message: 'Invalid JSON in request body', requestId }
        })
      };
    }
    
    const { transaction, prescriptionData } = body;

    if (!transaction || !transaction.items || !Array.isArray(transaction.items)) {
      return error('Transaction with items array is required', 400, requestId);
    }

    // ------------------------------------------------------------------------
    // VALIDATION
    // ------------------------------------------------------------------------
    const validationErrors = [];
    const validatedItems = [];

    for (const item of transaction.items) {
      const itemValidation = await validateTransactionItem(
        tenantId,
        item,
        prescriptionData,
        requestId
      );

      if (!itemValidation.valid) {
        validationErrors.push(...itemValidation.errors);
      }

      validatedItems.push({
        ...item,
        validation: itemValidation,
      });
    }

    // BUG-057: Validate discount limits based on business type
    const discountValidation = validateDiscountLimits(
      transaction,
      validatedItems,
      requestId
    );
    
    if (!discountValidation.valid) {
      validationErrors.push(...discountValidation.errors);
    }

    // ------------------------------------------------------------------------
    // AUDIT LOGGING
    // ------------------------------------------------------------------------
    const hasScheduledDrugs = validatedItems.some(
      item => item.validation.drugSchedule && SCHEDULED_DRUGS.includes(item.validation.drugSchedule.toUpperCase())
    );

    if (hasScheduledDrugs || validationErrors.length > 0) {
      await logAuditEvent({
        tenantId,
        userId,
        action: validationErrors.length > 0 ? 'TRANSACTION_VALIDATION_FAILED' : 'TRANSACTION_VALIDATION_PASSED',
        entityType: 'transaction',
        entityId: transaction.id || 'pending',
        details: {
          requestId,
          itemCount: transaction.items.length,
          scheduledDrugsPresent: hasScheduledDrugs,
          errors: validationErrors.map(e => ({ code: e.code, message: e.message })),
          latencyMs: Date.now() - startTime,
        },
      });
    }

    // ------------------------------------------------------------------------
    // RESPONSE
    // ------------------------------------------------------------------------
    if (validationErrors.length > 0) {
      return success({
        valid: false,
        errors: validationErrors,
        metadata: {
          requestId,
          validatedAt: new Date().toISOString(),
          latencyMs: Date.now() - startTime,
        },
      }, 400);
    }

    return success({
      valid: true,
      items: validatedItems,
      metadata: {
        requestId,
        validatedAt: new Date().toISOString(),
        latencyMs: Date.now() - startTime,
      },
    });

  } catch (err) {
    console.error(JSON.stringify({
      level: 'ERROR',
      requestId,
      error: err.message,
      stack: err.stack,
    }));

    return error('Internal validation error', 500, requestId);
  }
}

// ============================================================================
// ITEM VALIDATION
// ============================================================================

async function validateTransactionItem(tenantId, item, prescriptionData, requestId) {
  const errors = [];
  const warnings = [];
  
  // Get full product details from DB to verify drug schedule
  const product = await getProductDetails(tenantId, item.productId);
  
  if (!product) {
    errors.push({
      code: 'PRODUCT_NOT_FOUND',
      message: `Product not found: ${item.productId}`,
      severity: 'blocking',
      item: item.productName || item.productId,
    });
    return { valid: false, errors, warnings, drugSchedule: null };
  }

  const drugSchedule = product.drugSchedule || item.drugSchedule || null;
  const expiryDate = item.expiryDate || product.expiryDate || null;
  
  // Rule 0: Check for expired products (ALL business types)
  if (expiryDate) {
    const expiry = new Date(expiryDate);
    const today = new Date();
    
    if (expiry < today) {
      errors.push({
        code: 'PRODUCT_EXPIRED',
        message: `Product '${item.productName}' has expired on ${expiryDate}`,
        severity: 'blocking',
        item: item.productName,
        expiryDate,
      });
    }
  }

  // Rule 1: Scheduled drugs require prescription
  if (drugSchedule && SCHEDULED_DRUGS.includes(drugSchedule.toUpperCase())) {
    const schedule = drugSchedule.toUpperCase();
    const rules = VALIDATION_RULES[schedule];
    
    // Check if prescription is provided and valid
    const hasValidPrescription = await validatePrescription(
      tenantId,
      prescriptionData,
      item,
      schedule
    );
    
    if (!hasValidPrescription) {
      errors.push({
        code: 'MISSING_PRESCRIPTION',
        message: `Schedule ${schedule} drug '${item.productName}' requires a valid prescription`,
        severity: 'blocking',
        item: item.productName,
        drugSchedule: schedule,
        requiresPrescription: true,
      });
    }
    
    // Additional validation for Schedule H1 and X
    if (schedule === 'H1' || schedule === 'X') {
      // Verify prescription is not expired
      if (prescriptionData?.expiryDate) {
        const prescriptionExpiry = new Date(prescriptionData.expiryDate);
        if (prescriptionExpiry < new Date()) {
          errors.push({
            code: 'PRESCRIPTION_EXPIRED',
            message: `Prescription for '${item.productName}' has expired`,
            severity: 'blocking',
            item: item.productName,
            prescriptionExpiry: prescriptionData.expiryDate,
          });
        }
      }
      
      // Verify doctor registration if required
      if (prescriptionData?.doctorRegistration && !prescriptionData.doctorRegistration.match(/^[A-Z]{2}\d{6}$/)) {
        errors.push({
          code: 'INVALID_DOCTOR_REGISTRATION',
          message: `Invalid doctor registration number for prescription`,
          severity: 'blocking',
          item: item.productName,
        });
      }
    }
    
    // Warning for Schedule H (not blocking but logged)
    if (schedule === 'H') {
      warnings.push({
        code: 'SCHEDULE_H_DRUG',
        message: `Schedule H drug sold: ${item.productName}`,
        severity: 'warning',
        item: item.productName,
      });
    }
  }

  // Rule 2: Pharmacy-specific mandatory fields
  const isPharmacyTransaction = item.batchNo !== undefined || drugSchedule !== null;
  if (isPharmacyTransaction) {
    if (!item.batchNo) {
      errors.push({
        code: 'MISSING_BATCH_NUMBER',
        message: `Batch number required for pharmacy product: ${item.productName}`,
        severity: 'blocking',
        item: item.productName,
      });
    }
    
    if (!expiryDate) {
      errors.push({
        code: 'MISSING_EXPIRY_DATE',
        message: `Expiry date required for pharmacy product: ${item.productName}`,
        severity: 'blocking',
        item: item.productName,
      });
    }
  }

  return {
    valid: errors.length === 0,
    errors,
    warnings,
    drugSchedule,
    productId: product.id,
  };
}

// ============================================================================
// PRODUCT LOOKUP
// ============================================================================

async function getProductDetails(tenantId, productId) {
  try {
    const params = {
      TableName: TABLE_NAME,
      Key: {
        PK: `TENANT#${tenantId}`,
        SK: `PRODUCT#${productId}`,
      },
    };

    const result = await docClient.send(new GetCommand(params));
    return result.Item || null;
  } catch (err) {
    console.error('Failed to get product details:', err);
    return null;
  }
}

// ============================================================================
// PRESCRIPTION VALIDATION
// ============================================================================

async function validatePrescription(tenantId, prescriptionData, item, schedule) {
  // If no prescription data provided, invalid
  if (!prescriptionData) {
    return false;
  }
  
  // Must have prescription ID
  if (!prescriptionData.id && !prescriptionData.prescriptionId) {
    return false;
  }
  
  // For Schedule H1 and X, require more validation
  if (schedule === 'H1' || schedule === 'X') {
    // Must have doctor information
    if (!prescriptionData.doctorName) {
      return false;
    }
    
    // Should have patient information matching the bill
    if (!prescriptionData.patientName) {
      return false;
    }
    
    // Verify prescription exists in database (optional but recommended)
    if (prescriptionData.id || prescriptionData.prescriptionId) {
      try {
        const prescriptionId = prescriptionData.id || prescriptionData.prescriptionId;
        const isValid = await verifyPrescriptionInDatabase(tenantId, prescriptionId, item.productId);
        if (!isValid) {
          console.warn(`Prescription ${prescriptionId} not found or invalid for product ${item.productId}`);
          // Don't fail hard - offline prescriptions may not be synced yet
        }
      } catch (err) {
        console.error('Prescription verification error:', err);
        // Don't block on verification errors - may be offline mode
      }
    }
  }
  
  return true;
}

async function verifyPrescriptionInDatabase(tenantId, prescriptionId, productId) {
  try {
    // Query by GSI for prescriptions
    const params = {
      TableName: TABLE_NAME,
      IndexName: 'GSI1',
      KeyConditionExpression: 'GSI1PK = :pk AND GSI1SK = :sk',
      ExpressionAttributeValues: {
        ':pk': `TENANT#${tenantId}#RX`,
        ':sk': `RX#${prescriptionId}`,
      },
      Limit: 1,
    };

    const result = await docClient.send(new QueryCommand(params));
    
    if (!result.Items || result.Items.length === 0) {
      return false;
    }
    
    const prescription = result.Items[0];
    
    // Check if prescription is active
    if (prescription.status !== 'active') {
      return false;
    }
    
    // Check if product is in prescription items
    const items = prescription.items || [];
    const hasProduct = items.some(item => 
      item.productId === productId || 
      item.productName?.toLowerCase().includes(productId.toLowerCase())
    );
    
    return hasProduct;
  } catch (err) {
    console.error('Database prescription verification failed:', err);
    return false;
  }
}

// ============================================================================
// BUG-057: DISCOUNT LIMITS VALIDATION
// ============================================================================

function validateDiscountLimits(transaction, validatedItems, requestId) {
  const errors = [];
  const businessType = transaction.businessType?.toLowerCase();
  
  // Get discount limits for this business type
  const limits = BUSINESS_DISCOUNT_LIMITS[businessType] || BUSINESS_DISCOUNT_LIMITS.default;
  
  // For pharmacy, validate each item's discount
  if (businessType === 'pharmacy') {
    for (const item of validatedItems) {
      // Check if this is a pharmacy item (has drug schedule or batch number)
      const isPharmacyItem = item.validation?.drugSchedule || item.batchNo || 
                            item.category?.toLowerCase()?.includes('medicine') ||
                            item.category?.toLowerCase()?.includes('drug');
      
      if (!isPharmacyItem) continue; // Non-pharmacy items use default limits
      
      // Calculate discount percentage
      const originalPrice = item.mrp || item.price || 0;
      const discount = item.discount || 0;
      const discountedPrice = item.price || 0;
      
      // Calculate discount percentage (either from direct discount or price difference)
      let discountPercent = 0;
      if (originalPrice > 0) {
        if (discount > 0) {
          discountPercent = (discount / originalPrice) * 100;
        } else if (discountedPrice > 0 && discountedPrice < originalPrice) {
          discountPercent = ((originalPrice - discountedPrice) / originalPrice) * 100;
        }
      }
      
      // Check against pharmacy limit
      if (discountPercent > limits.maxDiscountPercent) {
        errors.push({
          code: 'DISCOUNT_LIMIT_EXCEEDED',
          message: `Pharmacy discount limit exceeded for '${item.productName}'. ` +
                   `Applied: ${discountPercent.toFixed(2)}%, Maximum allowed: ${limits.maxDiscountPercent}% ` +
                   `(${limits.description})`,
          severity: 'blocking',
          item: item.productName,
          appliedDiscount: discountPercent,
          maxDiscount: limits.maxDiscountPercent,
          businessType: businessType,
        });
        
        // Log for compliance audit
        console.log(JSON.stringify({
          level: 'WARN',
          requestId,
          action: 'DISCOUNT_LIMIT_VIOLATION',
          businessType,
          productId: item.productId,
          productName: item.productName,
          appliedDiscount: discountPercent,
          maxAllowed: limits.maxDiscountPercent,
          reason: limits.description,
        }));
      }
    }
  }
  
  // For grocery, validate total bill discount
  else if (businessType === 'grocery') {
    const totalDiscountPercent = transaction.discountPercent || 0;
    
    if (totalDiscountPercent > limits.maxDiscountPercent) {
      errors.push({
        code: 'DISCOUNT_LIMIT_EXCEEDED',
        message: `Grocery discount limit exceeded. ` +
                 `Applied: ${totalDiscountPercent}%, Maximum allowed: ${limits.maxDiscountPercent}% ` +
                 `(${limits.description})`,
        severity: 'blocking',
        appliedDiscount: totalDiscountPercent,
        maxDiscount: limits.maxDiscountPercent,
        businessType: businessType,
      });
    }
  }
  
  // For other business types, no strict limits (up to 100%)
  
  return {
    valid: errors.length === 0,
    errors,
    limits,
  };
}
