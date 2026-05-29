// ============================================================================
// V1 Bills Lambda Handler — Ported from sls/app-backend
// ============================================================================
// Serves: /api/v1/bills (GET, POST, PUT, DELETE)
// Preserves exact paise↔rupees conversion for Dart client compatibility.
// ============================================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { verifyAuth } from '../middleware/cognito-auth';
import { buildTenantContext } from '../dynamodb/tenant-guard';
import {
  createBill,
  getBill,
  listBills,
  updateBill,
  deleteBill,
  listBillsCrossBusiness,
} from '../dynamodb/bill-service';
import { logger } from '../utils/logger';
import * as response from '../utils/response';

// ---- Helpers ----

function extractBusinessId(event: APIGatewayProxyEventV2): string {
  return (
    event.headers?.['x-active-business'] ||
    event.headers?.['x-business-id'] ||
    event.headers?.['x-shop-id'] ||
    ''
  );
}

function toPaise(rupees: number): number {
  return Math.round(rupees * 100);
}

function paiseToRupees(bill: any): any {
  return {
    ...bill,
    subtotal: (bill.subtotalPaise ?? 0) / 100,
    totalTax: (bill.totalTaxPaise ?? 0) / 100,
    grandTotal: (bill.grandTotalPaise ?? 0) / 100,
    paidAmount: (bill.paidAmountPaise ?? 0) / 100,
    cashPaid: (bill.cashPaidPaise ?? 0) / 100,
    onlinePaid: (bill.onlinePaidPaise ?? 0) / 100,
    discountApplied: (bill.discountAppliedPaise ?? 0) / 100,
    id: bill.bill_id,
    ownerId: bill.tenant_id,
    businessId: bill.business_id,
    vehicleNumber: bill.vehicleNumber ?? null,
    fuelType: bill.fuelType ?? null,
    shiftId: bill.shiftId ?? null,
    attendantId: bill.attendantId ?? null,
    nozzleId: bill.nozzleId ?? null,
    dispenserId: bill.dispenserId ?? null,
    paymentSplit: bill.paymentSplit
      ? {
          cash: (bill.paymentSplit.cashPaise ?? 0) / 100,
          upi: (bill.paymentSplit.upiPaise ?? 0) / 100,
          card: (bill.paymentSplit.cardPaise ?? 0) / 100,
          credit: (bill.paymentSplit.creditPaise ?? 0) / 100,
        }
      : null,
  };
}

// ---- LIST BILLS ----
export async function listBillsHandler(
  event: APIGatewayProxyEventV2,
): Promise<APIGatewayProxyResultV2> {
  try {
    const auth = await verifyAuth(event);
    const businessId = extractBusinessId(event);
    const { tenantContext } = await buildTenantContext(auth, businessId);

    const result = await listBills(tenantContext, {
      startDate: event.queryStringParameters?.startDate,
      endDate: event.queryStringParameters?.endDate,
      status: event.queryStringParameters?.status,
      customerId: event.queryStringParameters?.customerId,
      limit: event.queryStringParameters?.limit
        ? parseInt(event.queryStringParameters.limit, 10)
        : undefined,
    });

    const bills = result.bills.map(paiseToRupees);
    return response.success({
      items: bills,
      lastKey: result.lastKey,
      count: bills.length,
    });
  } catch (err: any) {
    logger.error('List bills error', { error: err.message });
    if (err.message?.includes('TENANT') || err.message?.includes('BUSINESS')) {
      return response.error(403, 'ACCESS_DENIED', err.message);
    }
    return response.internalError();
  }
}

// ---- LIST BILLS CROSS-BUSINESS ----
export async function listBillsCrossBusinessHandler(
  event: APIGatewayProxyEventV2,
): Promise<APIGatewayProxyResultV2> {
  try {
    const auth = await verifyAuth(event);
    const businessId = extractBusinessId(event);
    const { tenantContext } = await buildTenantContext(auth, businessId);

    const result = await listBillsCrossBusiness(tenantContext, {
      startDate: event.queryStringParameters?.startDate,
      endDate: event.queryStringParameters?.endDate,
      limit: event.queryStringParameters?.limit
        ? parseInt(event.queryStringParameters.limit, 10)
        : undefined,
    });

    const bills = result.bills.map(paiseToRupees);
    return response.success({
      items: bills,
      lastKey: result.lastKey,
      count: bills.length,
    });
  } catch (err: any) {
    logger.error('Cross-business bills error', { error: err.message });
    return response.internalError();
  }
}

// ---- GET BILL ----
export async function getBillHandler(
  event: APIGatewayProxyEventV2,
): Promise<APIGatewayProxyResultV2> {
  try {
    const auth = await verifyAuth(event);
    const businessId = extractBusinessId(event);
    const { tenantContext } = await buildTenantContext(auth, businessId);

    const billId = event.pathParameters?.id;
    if (!billId) return response.error(400, 'MISSING_ID', 'Bill ID required');

    const bill = await getBill(tenantContext, billId);
    if (!bill) return response.error(404, 'NOT_FOUND', 'Bill not found');

    return response.success(paiseToRupees(bill));
  } catch (err: any) {
    logger.error('Get bill error', { error: err.message });
    return response.internalError();
  }
}

// ---- CREATE BILL ----
export async function createBillHandler(
  event: APIGatewayProxyEventV2,
): Promise<APIGatewayProxyResultV2> {
  try {
    const auth = await verifyAuth(event);
    const businessId = extractBusinessId(event);
    const { tenantContext, businessContext } = await buildTenantContext(auth, businessId);

    const body = JSON.parse(event.body || '{}');

    if (!body.billId || !body.customerId || !body.items?.length) {
      return response.error(400, 'VALIDATION_ERROR', 'billId, customerId, and items required');
    }

    const bill = await createBill(tenantContext, {
      billId: body.billId,
      invoiceNumber: body.invoiceNumber || '',
      customerId: body.customerId,
      customerName: body.customerName || '',
      customerPhone: body.customerPhone || '',
      customerAddress: body.customerAddress || '',
      customerGst: body.customerGst || '',
      customerEmail: body.customerEmail,
      date: body.date || new Date().toISOString(),
      items: body.items,
      subtotalPaise: toPaise(body.subtotal || 0),
      totalTaxPaise: toPaise(body.totalTax || 0),
      grandTotalPaise: toPaise(body.grandTotal || body.subtotal || 0),
      paidAmountPaise: toPaise(body.paidAmount || 0),
      cashPaidPaise: toPaise(body.cashPaid || 0),
      onlinePaidPaise: toPaise(body.onlinePaid || 0),
      discountAppliedPaise: toPaise(body.discountApplied || 0),
      status: body.status || 'Unpaid',
      paymentType: body.paymentType || 'Cash',
      businessType: (businessContext as any)?.businessType || 'grocery',
      shopName: (businessContext as any)?.name || '',
      shopAddress: (businessContext as any)?.address || '',
      shopGst: (businessContext as any)?.gstin || '',
      shopContact: (businessContext as any)?.phone || '',
      source: body.source || 'MANUAL',
      shiftId: body.shiftId,
      prescriptionId: body.prescriptionId,
      vehicleNumber: body.vehicleNumber,
      fuelType: body.fuelType,
      tableNumber: body.tableNumber,
      waiterId: body.waiterId,
    });

    return response.success(
      { status: 'success', bill_id: bill.bill_id, bill: paiseToRupees(bill) },
      201,
    );
  } catch (err: any) {
    if (err.name === 'ConditionalCheckFailedException') {
      return response.error(409, 'BILL_DUPLICATE', 'Bill with this ID already exists');
    }
    logger.error('Create bill error', { error: err.message });
    return response.internalError();
  }
}

// ---- UPDATE BILL ----
export async function updateBillHandler(
  event: APIGatewayProxyEventV2,
): Promise<APIGatewayProxyResultV2> {
  try {
    const auth = await verifyAuth(event);
    const businessId = extractBusinessId(event);
    const { tenantContext } = await buildTenantContext(auth, businessId);

    const billId = event.pathParameters?.id;
    if (!billId) return response.error(400, 'MISSING_ID', 'Bill ID required');

    const body = JSON.parse(event.body || '{}');

    if (!body.expectedVersion && body.expectedVersion !== 0) {
      return response.error(400, 'VERSION_REQUIRED', 'expectedVersion required');
    }

    const updated = await updateBill(
      tenantContext,
      {
        billId,
        expectedVersion: body.expectedVersion,
        paidAmountPaise: body.paidAmount !== undefined ? toPaise(body.paidAmount) : undefined,
        cashPaidPaise: body.cashPaid !== undefined ? toPaise(body.cashPaid) : undefined,
        onlinePaidPaise: body.onlinePaid !== undefined ? toPaise(body.onlinePaid) : undefined,
        status: body.status,
        paymentType: body.paymentType,
        items: body.items,
        subtotalPaise: body.subtotal !== undefined ? toPaise(body.subtotal) : undefined,
        totalTaxPaise: body.totalTax !== undefined ? toPaise(body.totalTax) : undefined,
        grandTotalPaise: body.grandTotal !== undefined ? toPaise(body.grandTotal) : undefined,
        discountAppliedPaise: body.discountApplied !== undefined ? toPaise(body.discountApplied) : undefined,
      },
      {
        ipAddress: event.requestContext?.http?.sourceIp || '',
        userAgent: event.headers?.['user-agent'] || '',
      },
    );

    if (!updated) return response.error(404, 'NOT_FOUND', 'Bill not found');

    return response.success({ status: 'success', bill: paiseToRupees(updated) });
  } catch (err: any) {
    if (err.name === 'ConditionalCheckFailedException') {
      return response.error(409, 'VERSION_CONFLICT', 'Bill modified by another request');
    }
    logger.error('Update bill error', { error: err.message });
    return response.internalError();
  }
}

// ---- DELETE BILL (soft) ----
export async function deleteBillHandler(
  event: APIGatewayProxyEventV2,
): Promise<APIGatewayProxyResultV2> {
  try {
    const auth = await verifyAuth(event);
    const businessId = extractBusinessId(event);
    const { tenantContext } = await buildTenantContext(auth, businessId);

    const billId = event.pathParameters?.id;
    if (!billId) return response.error(400, 'MISSING_ID', 'Bill ID required');

    const body = JSON.parse(event.body || '{}');
    if (!body.expectedVersion && body.expectedVersion !== 0) {
      return response.error(400, 'VERSION_REQUIRED', 'expectedVersion required');
    }

    await deleteBill(tenantContext, billId, body.expectedVersion, {
      ipAddress: event.requestContext?.http?.sourceIp || '',
      userAgent: event.headers?.['user-agent'] || '',
    });

    return response.success({ status: 'success', message: 'Bill deleted' });
  } catch (err: any) {
    if (err.name === 'ConditionalCheckFailedException') {
      return response.error(409, 'VERSION_CONFLICT', 'Bill modified by another request');
    }
    logger.error('Delete bill error', { error: err.message });
    return response.internalError();
  }
}

// ---- BILL COUNT ----
export async function billCountHandler(
  event: APIGatewayProxyEventV2,
): Promise<APIGatewayProxyResultV2> {
  try {
    const auth = await verifyAuth(event);
    const businessId = extractBusinessId(event);
    const { tenantContext } = await buildTenantContext(auth, businessId);

    const result = await listBills(tenantContext, {
      startDate: event.queryStringParameters?.startDate,
      endDate: event.queryStringParameters?.endDate,
    });

    return response.success({ count: result.bills.length });
  } catch (err: any) {
    logger.error('Bill count error', { error: err.message });
    return response.internalError();
  }
}
