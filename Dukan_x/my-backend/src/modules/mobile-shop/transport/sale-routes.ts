/**
 * Sale Routes — MobileShop Transport Layer (Lambda API Handlers)
 *
 * Exposes versioned sale, cancellation, return, and reconciliation APIs.
 * Every route uses `mobileShopHandler()` for auth middleware:
 *   1. Validates authentication + tenant context + permissions
 *   2. Parses sanitized body (strips client ownership fields)
 *   3. Delegates to application service
 *   4. Maps SaleOutcome → HTTP response via response-mapper
 *
 * Routes:
 *   POST /api/v1/mobile-shop/sales/finalize   → finalize a device sale
 *   POST /api/v1/mobile-shop/sales/cancel     → cancel a sale/invoice
 *   POST /api/v1/mobile-shop/returns          → process a device return
 *   GET  /api/v1/mobile-shop/reconciliation/{id} → query reconciliation status
 *
 * Requirements: 3.3–3.11, 6.3–6.13, 6.42, 12.7–12.10
 */

import type { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import {
  mobileShopHandler,
  parseSanitizedBody,
} from '../middleware/auth-middleware';
import { MOBILE_SHOP_PERMISSIONS } from '../permissions/mobile-shop-permissions';
import type { TenantContext } from '../middleware/tenant-context';
import { CORRELATION_HEADER } from '../middleware/correlation';
import { AtomicSaleHandler } from '../application/atomic-sale-handler';
import type { MobileSaleCommand } from '../application/transaction-planner';
import type { DeterministicOutcome } from '../application/error-mapper';
import type { SaleOutcome } from '../application/sale-outcome';
import {
  mapSaleOutcomeToResponse,
  mapDeterministicOutcomeToResponse,
} from './response-mapper';
import type { Money } from '../schemas/common.schema';

// ─── Type Aliases for Route Bodies ───────────────────────────────────────────

/** Wire money format — integer minor units + currency */
interface MoneyWire {
  amountMinorUnits: number;
  currency: string;
}

/** Body shape for POST /sales/finalize */
interface FinalizeSaleBody {
  operationId: string;
  mutationFingerprint: string;
  dataModelVersion: number;
  invoiceId: string;
  invoiceNumber: string;
  customerId: string;
  customerName?: string;
  invoiceDate: string;
  totalAmount: MoneyWire;
  taxAmount: MoneyWire;
  discountAmount: MoneyWire;
  netAmount: MoneyWire;
  paymentMethod?: string;
  paymentReference?: string;
  dueDate?: string;
  notes?: string;
  deviceLines: Array<{
    lineId: string;
    imei: string;
    unitId: string;
    description?: string;
    brand?: string;
    model?: string;
    quantity: number;
    unitPrice: MoneyWire;
    lineTax: MoneyWire;
    lineDiscount: MoneyWire;
    lineTotal: MoneyWire;
    hsnCode?: string;
    taxRateBasisPoints?: number;
    warrantyMonths?: number;
    warrantyStartDate?: string;
    warrantyEndDate?: string;
  }>;
  expectedImeiVersions: Record<string, number>;
}

/** Body shape for POST /sales/cancel */
interface CancelSaleBody {
  operationId: string;
  mutationFingerprint: string;
  dataModelVersion: number;
  invoiceId: string;
  expectedVersion: number;
  reason: string;
}

/** Body shape for POST /returns */
interface DeviceReturnBody {
  operationId: string;
  mutationFingerprint: string;
  dataModelVersion: number;
  invoiceId: string;
  unitId: string;
  imei: string;
  expectedVersion: number;
  condition: string;
  disposition: string;
  targetState: string;
  reason?: string;
}

// ─── Handler Factory ─────────────────────────────────────────────────────────

/**
 * Creates a configured AtomicSaleHandler using environment variables.
 * Lazily initialized on first request (warm Lambda container reuse).
 */
let saleHandlerInstance: AtomicSaleHandler | null = null;

function getSaleHandler(): AtomicSaleHandler {
  if (!saleHandlerInstance) {
    // Dynamic import-free: rely on environment variables set by serverless.yml
    const tableName = process.env.MOBILE_SHOP_TABLE_NAME;
    if (!tableName) {
      throw new Error('MOBILE_SHOP_TABLE_NAME environment variable is required');
    }

    // DynamoDB client is created lazily via the @aws-sdk pattern
    const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
    const { DynamoDBDocumentClient } = require('@aws-sdk/lib-dynamodb');

    const rawClient = new DynamoDBClient({});
    const client = DynamoDBDocumentClient.from(rawClient, {
      marshallOptions: { removeUndefinedValues: true },
    });

    // AcceptedPendingHandler imported lazily to avoid circular dependency issues
    const { AcceptedPendingHandlerImpl } = require('../application/accepted-pending-handler');
    const acceptedPendingHandler = new AcceptedPendingHandlerImpl(tableName);

    saleHandlerInstance = new AtomicSaleHandler(client, tableName, acceptedPendingHandler);
  }

  return saleHandlerInstance;
}

// ─── Route: POST /api/v1/mobile-shop/sales/finalize ──────────────────────────

/**
 * Finalize a mobile device sale.
 *
 * Permission: IMEI_MANAGE
 * Body: FinalizeSaleBody (operation, fingerprint, invoice, device lines, versions)
 * Response: SaleOutcome mapped to HTTP (200/202/400/409/422/503)
 */
export const finalizeSaleHandler = mobileShopHandler(
  { requiredPermissions: [MOBILE_SHOP_PERMISSIONS.IMEI_MANAGE] },
  async (
    event: APIGatewayProxyEventV2,
    _lambdaContext: Context,
    tenantContext: TenantContext,
  ): Promise<APIGatewayProxyResultV2> => {
    const body = parseSanitizedBody<FinalizeSaleBody>(event);

    // Validate body presence
    if (!body) {
      return mapDeterministicOutcomeToResponse(
        buildValidationOutcome('SCHEMA_INVALID', ['body'], tenantContext.correlationId),
        tenantContext.correlationId,
      );
    }

    // Validate required fields
    const validationError = validateFinalizeSaleBody(body, tenantContext.correlationId);
    if (validationError) {
      return mapDeterministicOutcomeToResponse(validationError, tenantContext.correlationId);
    }

    // Build MobileSaleCommand from sanitized body
    const command: MobileSaleCommand = {
      operationId: body.operationId,
      mutationFingerprint: body.mutationFingerprint,
      dataModelVersion: body.dataModelVersion,
      invoiceId: body.invoiceId,
      invoiceNumber: body.invoiceNumber,
      customerId: body.customerId,
      customerName: body.customerName ?? '',
      invoiceDate: body.invoiceDate,
      totalAmount: toMoney(body.totalAmount),
      taxAmount: toMoney(body.taxAmount),
      discountAmount: toMoney(body.discountAmount),
      netAmount: toMoney(body.netAmount),
      paymentMethod: body.paymentMethod,
      paymentReference: body.paymentReference,
      dueDate: body.dueDate,
      notes: body.notes,
      deviceLines: body.deviceLines.map((line) => ({
        lineId: line.lineId,
        imei: line.imei,
        unitId: line.unitId,
        description: line.description ?? '',
        brand: line.brand,
        model: line.model,
        quantity: line.quantity,
        unitPrice: toMoney(line.unitPrice),
        lineTax: toMoney(line.lineTax),
        lineDiscount: toMoney(line.lineDiscount),
        lineTotal: toMoney(line.lineTotal),
        hsnCode: line.hsnCode,
        taxRateBasisPoints: line.taxRateBasisPoints,
        warrantyMonths: line.warrantyMonths,
        warrantyStartDate: line.warrantyStartDate,
        warrantyEndDate: line.warrantyEndDate,
      })),
      expectedImeiVersions: body.expectedImeiVersions,
    };

    // Delegate to AtomicSaleHandler
    const handler = getSaleHandler();
    const tenantContextWire = toTenantContextWire(tenantContext);
    const outcome: SaleOutcome = await handler.handleSale(tenantContextWire, command);

    return mapSaleOutcomeToResponse(outcome, tenantContext.correlationId);
  },
);

// ─── Route: POST /api/v1/mobile-shop/sales/cancel ────────────────────────────

/**
 * Cancel a sale/invoice and revert associated IMEI states.
 *
 * Permission: IMEI_MANAGE
 * Body: CancelSaleBody (operation, fingerprint, invoice, expected version, reason)
 * Response: SaleOutcome mapped to HTTP
 */
export const cancelSaleHandler = mobileShopHandler(
  { requiredPermissions: [MOBILE_SHOP_PERMISSIONS.IMEI_MANAGE] },
  async (
    event: APIGatewayProxyEventV2,
    _lambdaContext: Context,
    tenantContext: TenantContext,
  ): Promise<APIGatewayProxyResultV2> => {
    const body = parseSanitizedBody<CancelSaleBody>(event);

    if (!body) {
      return mapDeterministicOutcomeToResponse(
        buildValidationOutcome('SCHEMA_INVALID', ['body'], tenantContext.correlationId),
        tenantContext.correlationId,
      );
    }

    // Validate required fields for cancellation
    const validationError = validateCancelSaleBody(body, tenantContext.correlationId);
    if (validationError) {
      return mapDeterministicOutcomeToResponse(validationError, tenantContext.correlationId);
    }

    // Cancellation is handled through the same AtomicSaleHandler pattern:
    // The command is validated, planned, and executed atomically.
    // For now, construct a cancellation-specific outcome.
    // The actual cancellation logic uses lifecycle transitions (task 5.2 / 7.1)
    // and follows the same idempotency + conditional-write pattern.

    // Delegate to the sale handler with a cancellation command envelope
    const handler = getSaleHandler();
    const tenantContextWire = toTenantContextWire(tenantContext);

    // Build a cancellation command — the AtomicSaleHandler recognizes this
    // as a lifecycle operation (SOLD → CANCELLED reversal)
    const zeroMoney = { amountMinorUnits: 0, currency: 'INR' };
    const cancelCommand: MobileSaleCommand = {
      operationId: body.operationId,
      mutationFingerprint: body.mutationFingerprint,
      dataModelVersion: body.dataModelVersion,
      invoiceId: body.invoiceId,
      invoiceNumber: '', // Not needed for cancellation
      customerId: '',    // Not needed for cancellation
      customerName: '',
      invoiceDate: '',
      totalAmount: zeroMoney,
      taxAmount: zeroMoney,
      discountAmount: zeroMoney,
      netAmount: zeroMoney,
      deviceLines: [],   // Cancellation reverses all associated lines
      expectedImeiVersions: {},
      // Cancellation metadata carried via special fields
      cancellation: {
        expectedVersion: body.expectedVersion,
        reason: body.reason,
      },
    } as MobileSaleCommand & { cancellation: unknown };

    const outcome = await handler.handleSale(tenantContextWire, cancelCommand);
    return mapSaleOutcomeToResponse(outcome, tenantContext.correlationId);
  },
);

// ─── Route: POST /api/v1/mobile-shop/returns ─────────────────────────────────

/**
 * Process a device return (IMEI lifecycle transition + audit).
 *
 * Permission: IMEI_MANAGE
 * Body: DeviceReturnBody (operation, fingerprint, unit, condition, disposition)
 * Response: SaleOutcome mapped to HTTP
 */
export const deviceReturnHandler = mobileShopHandler(
  { requiredPermissions: [MOBILE_SHOP_PERMISSIONS.IMEI_MANAGE] },
  async (
    event: APIGatewayProxyEventV2,
    _lambdaContext: Context,
    tenantContext: TenantContext,
  ): Promise<APIGatewayProxyResultV2> => {
    const body = parseSanitizedBody<DeviceReturnBody>(event);

    if (!body) {
      return mapDeterministicOutcomeToResponse(
        buildValidationOutcome('SCHEMA_INVALID', ['body'], tenantContext.correlationId),
        tenantContext.correlationId,
      );
    }

    // Validate required return fields
    const validationError = validateDeviceReturnBody(body, tenantContext.correlationId);
    if (validationError) {
      return mapDeterministicOutcomeToResponse(validationError, tenantContext.correlationId);
    }

    // Build a return command through the sale handler (same consistency path)
    const handler = getSaleHandler();
    const tenantContextWire = toTenantContextWire(tenantContext);

    // Return uses the same atomic pattern with lifecycle transition (SOLD → RETURNED)
    const zeroMoney = { amountMinorUnits: 0, currency: 'INR' };
    const returnCommand: MobileSaleCommand = {
      operationId: body.operationId,
      mutationFingerprint: body.mutationFingerprint,
      dataModelVersion: body.dataModelVersion,
      invoiceId: body.invoiceId,
      invoiceNumber: '',
      customerId: '',
      customerName: '',
      invoiceDate: '',
      totalAmount: zeroMoney,
      taxAmount: zeroMoney,
      discountAmount: zeroMoney,
      netAmount: zeroMoney,
      deviceLines: [{
        lineId: body.unitId,
        imei: body.imei,
        unitId: body.unitId,
        description: '',
        brand: undefined,
        model: undefined,
        quantity: 1,
        unitPrice: zeroMoney,
        lineTax: zeroMoney,
        lineDiscount: zeroMoney,
        lineTotal: zeroMoney,
      }],
      expectedImeiVersions: { [body.imei]: body.expectedVersion },
      // Return metadata
      deviceReturn: {
        condition: body.condition,
        disposition: body.disposition,
        targetState: body.targetState,
        reason: body.reason,
      },
    } as MobileSaleCommand & { deviceReturn: unknown };

    const outcome = await handler.handleSale(tenantContextWire, returnCommand);
    return mapSaleOutcomeToResponse(outcome, tenantContext.correlationId);
  },
);

// ─── Route: GET /api/v1/mobile-shop/reconciliation/{id} ──────────────────────

/**
 * Query reconciliation status for an operation.
 *
 * Permission: IMEI_VIEW (read-only query)
 * Path param: id (reconciliation ID)
 * Response: 200 with reconciliation status or 404 (non-disclosing)
 */
export const getReconciliationStatusHandler = mobileShopHandler(
  { requiredPermissions: [MOBILE_SHOP_PERMISSIONS.IMEI_VIEW] },
  async (
    event: APIGatewayProxyEventV2,
    _lambdaContext: Context,
    tenantContext: TenantContext,
  ): Promise<APIGatewayProxyResultV2> => {
    // Extract reconciliation ID from path parameters
    const reconciliationId = event.pathParameters?.id;

    if (!reconciliationId || reconciliationId.trim().length === 0) {
      return mapDeterministicOutcomeToResponse(
        buildValidationOutcome('SCHEMA_INVALID', ['id'], tenantContext.correlationId),
        tenantContext.correlationId,
      );
    }

    // Query DynamoDB for the reconciliation record (AP-12 style)
    const tableName = process.env.MOBILE_SHOP_TABLE_NAME;
    if (!tableName) {
      return buildErrorResponse(500, 'INTERNAL_ERROR', tenantContext.correlationId);
    }

    const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
    const { DynamoDBDocumentClient, GetCommand } = require('@aws-sdk/lib-dynamodb');
    const { encodePK, encodeMetaSK } = require('../persistence/key-codec');

    const rawClient = new DynamoDBClient({});
    const client = DynamoDBDocumentClient.from(rawClient, {
      marshallOptions: { removeUndefinedValues: true },
    });

    const pk = encodePK(tenantContext.tenantId, 'RECON', reconciliationId);
    const sk = encodeMetaSK('RECON');

    try {
      const result = await client.send(
        new GetCommand({
          TableName: tableName,
          Key: { PK: pk, SK: sk },
          ConsistentRead: true,
        }),
      );

      if (!result.Item) {
        // Non-disclosing: don't reveal whether the ID exists for another tenant
        return buildErrorResponse(404, 'NOT_FOUND', tenantContext.correlationId);
      }

      // Verify tenant ownership
      if (result.Item.tenantId !== tenantContext.tenantId) {
        // Security: cross-tenant attempt — return same 404
        return buildErrorResponse(404, 'NOT_FOUND', tenantContext.correlationId);
      }

      // Return reconciliation status (no AuthoritativeConfirmation — this is a read)
      return {
        statusCode: 200,
        headers: buildResponseHeaders(tenantContext.correlationId),
        body: JSON.stringify({
          reconciliationId: result.Item.reconciliationId,
          operationId: result.Item.operationId,
          invoiceId: result.Item.invoiceId,
          status: result.Item.status,
          completedSteps: result.Item.completedSteps?.length ?? 0,
          totalSteps: result.Item.plan?.length ?? 0,
          attempts: result.Item.attempts ?? 0,
          lastError: result.Item.lastError ?? null,
          createdAt: result.Item.createdAt,
          updatedAt: result.Item.updatedAt,
        }),
      };
    } catch {
      return buildErrorResponse(500, 'INTERNAL_ERROR', tenantContext.correlationId);
    }
  },
);

// ─── Validation Helpers ──────────────────────────────────────────────────────

function validateFinalizeSaleBody(
  body: FinalizeSaleBody,
  correlationId: string,
): DeterministicOutcome | null {
  if (!body.operationId || body.operationId.trim().length === 0) {
    return buildValidationOutcome('OPERATION_ID_MISSING', ['operationId'], correlationId);
  }
  if (!body.mutationFingerprint || body.mutationFingerprint.trim().length === 0) {
    return buildValidationOutcome('FINGERPRINT_MISSING', ['mutationFingerprint'], correlationId);
  }
  if (!body.invoiceId || body.invoiceId.trim().length === 0) {
    return buildValidationOutcome('SCHEMA_INVALID', ['invoiceId'], correlationId);
  }
  if (!body.invoiceNumber || body.invoiceNumber.trim().length === 0) {
    return buildValidationOutcome('SCHEMA_INVALID', ['invoiceNumber'], correlationId);
  }
  if (!body.customerId || body.customerId.trim().length === 0) {
    return buildValidationOutcome('SCHEMA_INVALID', ['customerId'], correlationId);
  }
  if (!body.deviceLines || !Array.isArray(body.deviceLines) || body.deviceLines.length === 0) {
    return buildValidationOutcome('SCHEMA_INVALID', ['deviceLines'], correlationId);
  }
  if (!body.expectedImeiVersions || typeof body.expectedImeiVersions !== 'object') {
    return buildValidationOutcome('SCHEMA_INVALID', ['expectedImeiVersions'], correlationId);
  }
  if (typeof body.dataModelVersion !== 'number' || body.dataModelVersion < 1) {
    return buildValidationOutcome('SCHEMA_INVALID', ['dataModelVersion'], correlationId);
  }
  return null;
}

function validateCancelSaleBody(
  body: CancelSaleBody,
  correlationId: string,
): DeterministicOutcome | null {
  if (!body.operationId || body.operationId.trim().length === 0) {
    return buildValidationOutcome('OPERATION_ID_MISSING', ['operationId'], correlationId);
  }
  if (!body.mutationFingerprint || body.mutationFingerprint.trim().length === 0) {
    return buildValidationOutcome('FINGERPRINT_MISSING', ['mutationFingerprint'], correlationId);
  }
  if (!body.invoiceId || body.invoiceId.trim().length === 0) {
    return buildValidationOutcome('SCHEMA_INVALID', ['invoiceId'], correlationId);
  }
  if (typeof body.expectedVersion !== 'number' || body.expectedVersion < 1) {
    return buildValidationOutcome('SCHEMA_INVALID', ['expectedVersion'], correlationId);
  }
  if (!body.reason || body.reason.trim().length === 0) {
    return buildValidationOutcome('SCHEMA_INVALID', ['reason'], correlationId);
  }
  if (typeof body.dataModelVersion !== 'number' || body.dataModelVersion < 1) {
    return buildValidationOutcome('SCHEMA_INVALID', ['dataModelVersion'], correlationId);
  }
  return null;
}

function validateDeviceReturnBody(
  body: DeviceReturnBody,
  correlationId: string,
): DeterministicOutcome | null {
  if (!body.operationId || body.operationId.trim().length === 0) {
    return buildValidationOutcome('OPERATION_ID_MISSING', ['operationId'], correlationId);
  }
  if (!body.mutationFingerprint || body.mutationFingerprint.trim().length === 0) {
    return buildValidationOutcome('FINGERPRINT_MISSING', ['mutationFingerprint'], correlationId);
  }
  if (!body.invoiceId || body.invoiceId.trim().length === 0) {
    return buildValidationOutcome('SCHEMA_INVALID', ['invoiceId'], correlationId);
  }
  if (!body.unitId || body.unitId.trim().length === 0) {
    return buildValidationOutcome('SCHEMA_INVALID', ['unitId'], correlationId);
  }
  if (!body.imei || body.imei.trim().length === 0) {
    return buildValidationOutcome('SCHEMA_INVALID', ['imei'], correlationId);
  }
  if (typeof body.expectedVersion !== 'number' || body.expectedVersion < 1) {
    return buildValidationOutcome('SCHEMA_INVALID', ['expectedVersion'], correlationId);
  }
  if (!body.condition || body.condition.trim().length === 0) {
    return buildValidationOutcome('SCHEMA_INVALID', ['condition'], correlationId);
  }
  if (!body.disposition || body.disposition.trim().length === 0) {
    return buildValidationOutcome('SCHEMA_INVALID', ['disposition'], correlationId);
  }
  if (!body.targetState || body.targetState.trim().length === 0) {
    return buildValidationOutcome('SCHEMA_INVALID', ['targetState'], correlationId);
  }
  if (typeof body.dataModelVersion !== 'number' || body.dataModelVersion < 1) {
    return buildValidationOutcome('SCHEMA_INVALID', ['dataModelVersion'], correlationId);
  }
  return null;
}

// ─── Utility Helpers ─────────────────────────────────────────────────────────

/**
 * Converts a wire money object to the domain Money type.
 * Falls back to a zero-value INR money if the input is invalid.
 */
function toMoney(wire: MoneyWire | undefined): Money {
  if (!wire || typeof wire.amountMinorUnits !== 'number') {
    return { amountMinorUnits: 0, currency: 'INR' };
  }
  return {
    amountMinorUnits: wire.amountMinorUnits,
    currency: wire.currency || 'INR',
  };
}

/**
 * Builds a DeterministicOutcome for validation errors at the transport level.
 */
function buildValidationOutcome(
  code: string,
  fields: string[],
  correlationId: string,
): DeterministicOutcome {
  return {
    code,
    category: 'validation',
    retryable: false,
    statePreserved: true,
    fields,
    httpStatus: 400,
    correlationId,
  };
}

/**
 * Converts TenantContext (middleware) to TenantContextWire (application layer).
 */
function toTenantContextWire(ctx: TenantContext): import('../schemas/common.schema').TenantContextWire {
  return {
    tenantId: ctx.tenantId,
    businessId: ctx.businessId,
    subjectId: ctx.subjectId,
    businessType: ctx.businessType,
    permissions: Array.from(ctx.permissions),
    correlationId: ctx.correlationId,
  };
}

/**
 * Builds a simple error response with correlation header.
 */
function buildErrorResponse(
  statusCode: number,
  code: string,
  correlationId: string,
): APIGatewayProxyResultV2 {
  return {
    statusCode,
    headers: buildResponseHeaders(correlationId),
    body: JSON.stringify({
      error: code,
      correlationId,
    }),
  };
}

/**
 * Builds standard response headers.
 */
function buildResponseHeaders(correlationId: string): Record<string, string> {
  return {
    'Content-Type': 'application/json',
    [CORRELATION_HEADER]: correlationId,
  };
}
