// ============================================================
// Marketplace Orders Handler
// Routes:
//   POST /v1/businesses/{businessId}/orders - Place order (customer)
//   GET /v1/businesses/{businessId}/orders - List orders (business owner)
//   GET /v1/businesses/{businessId}/orders/{orderId} - Get order details
//   PATCH /v1/businesses/{businessId}/orders/{orderId}/status - Update status (business)
//   POST /v1/businesses/{businessId}/orders/{orderId}/cancel - Cancel order (customer)
//   GET /v1/customers/me/orders - Customer order history
// ============================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Handler } from 'aws-lambda';
import { z } from 'zod';
import { 
  Order, 
  OrderStatus, 
  OrderTimelineEvent,
  CustomerCart,
  CartItem,
  MarketplaceProduct,
  CustomerConnection,
  PaymentMethod,
  PK, 
  SK, 
  GSI1PK, 
  GSI1SK,
  GSI2PK,
  GSI2SK,
  orderStatusTransitions,
} from '../../shared/types';
import { 
  authorizeCustomerForBusiness, 
  authorizeBusiness,
  validateBusinessCategory 
} from '../../shared/auth';
import { Errors } from '../../shared/errors';
import { success, error, getPaginationParams, createMeta } from '../../shared/response';
import { 
  getItem, 
  putItem, 
  updateItem,
  queryByPK,
  queryByPKSKPrefix,
  queryByGSI1,
  queryByGSI2,
  transactWrite,
  isCustomerConnected,
} from '../../shared/dynamodb';

// ---------- VALIDATION SCHEMAS ----------

const placeOrderSchema = z.object({
  addressId: z.string().min(1),
  paymentMethod: z.enum(['COD', 'ONLINE', 'WALLET']),
  scheduledFor: z.string().datetime().optional(),
  isExpress: z.boolean().default(false),
  notes: z.string().max(500).optional(),
});

const updateStatusSchema = z.object({
  status: z.enum([
    'PLACED', 'ACCEPTED', 'REJECTED', 'PREPARING', 
    'READY_FOR_DISPATCH', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED'
  ]),
  note: z.string().max(200).optional(),
  assignedDeliveryPartnerId: z.string().optional(),
});

// ---------- ROUTE HANDLERS ----------

export const handler: Handler<APIGatewayProxyEventV2, APIGatewayProxyResultV2> = async (event) => {
  try {
    const method = event.requestContext.http.method;
    const path = event.rawPath || '';

    // Place order (customer)
    if (method === 'POST' && path.endsWith('/orders') && !path.includes('/cancel')) {
      return handlePlaceOrder(event);
    }

    // List orders for business
    if (method === 'GET' && path.match(/\/businesses\/[^/]+\/orders$/) && !path.includes('/customers')) {
      return handleListBusinessOrders(event);
    }

    // Get order details
    if (method === 'GET' && path.match(/\/orders\/[^/]+$/)) {
      return handleGetOrder(event);
    }

    // Update order status
    if (method === 'PATCH' && path.endsWith('/status')) {
      return handleUpdateStatus(event);
    }

    // Cancel order
    if (method === 'POST' && path.endsWith('/cancel')) {
      return handleCancelOrder(event);
    }

    // Customer order history
    if (method === 'GET' && path.includes('/customers/me/orders')) {
      return handleCustomerOrderHistory(event);
    }

    return error(Errors.notFound('Route', `${method} ${path}`));
  } catch (err) {
    console.error('Orders handler error:', err);
    return error(err instanceof Error ? err : String(err));
  }
};

// ---------- PLACE ORDER ----------

async function handlePlaceOrder(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  const { customerClaims, businessId } = authorizeCustomerForBusiness(event);
  const customerId = customerClaims.sub;

  // Validate customer is connected
  const connected = await isCustomerConnected(businessId, customerId);
  if (!connected) {
    throw Errors.customerNotConnected(customerId, businessId);
  }

  // Parse and validate request
  const body = JSON.parse(event.body || '{}');
  const validated = placeOrderSchema.parse(body);

  // Get cart
  const cart = await getItem<CustomerCart>(
    PK.business(businessId),
    SK.cart(customerId)
  );

  if (!cart || cart.items.length === 0) {
    throw Errors.validation('Cart is empty');
  }

  // Get customer details
  const connection = await getItem<CustomerConnection>(
    PK.business(businessId),
    SK.connection(customerId)
  );

  if (!connection) {
    throw Errors.customerNotConnected(customerId, businessId);
  }

  // Get address
  const address = await getItem(
    PK.business(businessId),
    SK.address(customerId, validated.addressId)
  );

  if (!address) {
    throw Errors.notFound('Address', validated.addressId);
  }

  // Validate stock and prescription requirements for pharmacy
  const stockValidation = await validateOrderItems(businessId, cart.items);
  if (!stockValidation.valid) {
    throw Errors.outOfStock(
      stockValidation.productId!,
      stockValidation.requested!,
      stockValidation.available!
    );
  }

  // Check prescription requirement for pharmacy
  const requiresPrescription = cart.items.some(item => 
    item.prescriptionUrl && item.prescriptionUrl.length > 0
  );
  // In a real implementation, check if any product requires prescription

  // Generate order ID
  const orderId = generateOrderId();
  const now = new Date().toISOString();

  // Calculate delivery time estimate
  const estimatedDelivery = calculateDeliveryEstimate(
    validated.isExpress, 
    validated.scheduledFor
  );

  // Create order
  const order: Order = {
    PK: PK.business(businessId),
    SK: SK.order(orderId, customerId),
    businessId,
    orderId,
    customerId,
    customerName: connection.customerName,
    customerPhone: connection.customerPhone,
    status: 'PLACED',
    items: cart.items.map(item => ({ ...item })),
    paymentMethod: validated.paymentMethod,
    paymentStatus: validated.paymentMethod === 'COD' ? 'PENDING' : 'PENDING',
    couponCode: cart.couponCode,
    discountAmount: cart.discountAmount,
    subtotal: cart.subtotal,
    taxAmount: cart.taxAmount,
    deliveryCharge: cart.deliveryCharge,
    total: cart.total,
    deliveryAddress: address as Order['deliveryAddress'],
    scheduledFor: validated.scheduledFor,
    isExpress: validated.isExpress,
    prescriptionUrl: requiresPrescription ? cart.items.find(i => i.prescriptionUrl)?.prescriptionUrl : undefined,
    notes: validated.notes,
    timeline: [{
      status: 'PLACED',
      timestamp: now,
      updatedBy: customerId,
    }],
    estimatedDeliveryTime: estimatedDelivery,
    GSI1PK: GSI1PK.orderStatus('PLACED'),
    GSI1SK: GSI1SK.order(businessId, now),
    GSI2PK: GSI2PK.customer(customerId),
    GSI2SK: GSI2SK.review(orderId), // Using review pattern for customer orders
    createdAt: now,
    updatedAt: now,
  };

  // Atomically create order and decrement stock
  try {
    const transactItems = [
      {
        Put: {
          TableName: process.env.TABLE_NAME || 'DukanMarketplace',
          Item: order as unknown as Record<string, unknown>,
          ConditionExpression: 'attribute_not_exists(PK) AND attribute_not_exists(SK)',
        },
      },
      // Decrement stock for each item
      ...cart.items.map(item => ({
        Update: {
          TableName: process.env.TABLE_NAME || 'DukanMarketplace',
          Key: {
            PK: PK.business(businessId),
            SK: SK.product(item.productId),
          },
          UpdateExpression: 'SET stockQuantity = stockQuantity - :qty, updatedAt = :now',
          ConditionExpression: 'stockQuantity >= :qty',
          ExpressionAttributeValues: {
            ':qty': item.quantity,
            ':now': now,
          },
        },
      })),
    ];

    await transactWrite(transactItems);

    // Clear cart after successful order
    await deleteCart(businessId, customerId);

    // Update customer stats
    await updateCustomerStats(businessId, customerId, order.total);

    return success({
      orderId: order.orderId,
      status: order.status,
      total: order.total,
      estimatedDeliveryTime: order.estimatedDeliveryTime,
      message: 'Order placed successfully',
    }, undefined, 201);

  } catch (err) {
    // Check if it's a condition check failure (out of stock)
    if (err instanceof Error && err.message.includes('ConditionalCheckFailed')) {
      throw Errors.outOfStock('unknown', 0, 0);
    }
    throw err;
  }
}

// ---------- LIST BUSINESS ORDERS ----------

async function handleListBusinessOrders(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  const claims = authorizeBusiness(event);
  const businessId = claims.businessId;

  const pagination = getPaginationParams(event);
  const status = event.queryStringParameters?.status as OrderStatus | undefined;
  const dateFrom = event.queryStringParameters?.dateFrom;
  const dateTo = event.queryStringParameters?.dateTo;

  let orders: Order[] = [];

  if (status) {
    // Query by status using GSI1
    const result = await queryByGSI1<Order>(
      GSI1PK.orderStatus(status),
      { 
        limit: pagination.limit,
        gsi1skPrefix: GSI1SK.order(businessId, ''),
      }
    );
    orders = result.items;
  } else {
    // Query all orders for business
    const result = await queryByPKSKPrefix<Order>(
      PK.business(businessId),
      'ORDER#',
      { limit: pagination.limit }
    );
    orders = result.items;
  }

  // Filter by date if provided
  if (dateFrom || dateTo) {
    orders = orders.filter(order => {
      const orderDate = new Date(order.createdAt);
      if (dateFrom && orderDate < new Date(dateFrom)) return false;
      if (dateTo && orderDate > new Date(dateTo)) return false;
      return true;
    });
  }

  // Sort by created date DESC
  orders.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

  const total = orders.length;
  const paginatedOrders = orders.slice(pagination.offset, pagination.offset + pagination.limit);

  return success({
    orders: paginatedOrders.map(formatOrderSummary),
  }, createMeta(pagination, total));
}

// ---------- GET ORDER DETAILS ----------

async function handleGetOrder(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  const businessId = event.pathParameters?.businessId;
  const orderId = event.pathParameters?.orderId;

  if (!businessId || !orderId) {
    throw Errors.validation('Business ID and Order ID are required');
  }

  // Try customer auth first
  let customerId: string | undefined;
  try {
    const { customerClaims } = authorizeCustomerForBusiness(event);
    customerId = customerClaims.sub;
  } catch {
    // Try business auth
    try {
      const claims = authorizeBusiness(event);
      if (claims.businessId !== businessId) {
        throw Errors.businessMismatch(claims.businessId, businessId);
      }
    } catch {
      throw Errors.unauthorized();
    }
  }

  // If customer, find order by querying GSI2
  let order: Order | null = null;
  
  if (customerId) {
    const result = await queryByGSI2<Order>(
      GSI2PK.customer(customerId),
      { gsi2skPrefix: `ORDER#${orderId}` }
    );
    order = result.items.find(o => o.PK === PK.business(businessId)) || null;
  } else {
    // Business owner - direct query
    const allOrders = await queryByPKSKPrefix<Order>(
      PK.business(businessId),
      'ORDER#',
      { limit: 100 }
    );
    order = allOrders.items.find(o => o.orderId === orderId) || null;
  }

  if (!order) {
    throw Errors.notFound('Order', orderId);
  }

  // Verify customer owns this order
  if (customerId && order.customerId !== customerId) {
    throw Errors.forbidden('You do not have access to this order');
  }

  return success({ order: formatOrderDetail(order) });
}

// ---------- UPDATE ORDER STATUS ----------

async function handleUpdateStatus(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  const claims = authorizeBusiness(event);
  const businessId = claims.businessId;
  const orderId = event.pathParameters?.orderId;

  if (!orderId) {
    throw Errors.validation('Order ID is required');
  }

  const body = JSON.parse(event.body || '{}');
  const validated = updateStatusSchema.parse(body);

  // Find order
  const allOrders = await queryByPKSKPrefix<Order>(
    PK.business(businessId),
    'ORDER#',
    { limit: 100 }
  );
  const order = allOrders.items.find(o => o.orderId === orderId);

  if (!order) {
    throw Errors.notFound('Order', orderId);
  }

  // Validate status transition
  const allowedTransitions = orderStatusTransitions[order.status];
  if (!allowedTransitions.includes(validated.status)) {
    throw Errors.invalidStatusTransition(order.status, validated.status);
  }

  const now = new Date().toISOString();

  // Build update
  const timelineEntry: OrderTimelineEvent = {
    status: validated.status,
    timestamp: now,
    note: validated.note,
    updatedBy: claims.sub,
  };

  const updates: Parameters<typeof updateItem>[2] = {
    set: {
      status: validated.status,
      updatedAt: now,
      'timeline': [...order.timeline, timelineEntry],
    },
  };

  // Update GSI keys if status changed
  if (validated.status !== order.status) {
    updates.set!.GSI1PK = GSI1PK.orderStatus(validated.status);
    updates.set!.GSI1SK = GSI1SK.order(businessId, now);
  }

  // Assign delivery partner
  if (validated.assignedDeliveryPartnerId) {
    updates.set!.assignedDeliveryPartnerId = validated.assignedDeliveryPartnerId;
  }

  // Handle rejection/cancellation - restore stock
  if (validated.status === 'REJECTED' || validated.status === 'CANCELLED') {
    // Restore stock for each item
    for (const item of order.items) {
      await updateItem(
        PK.business(businessId),
        SK.product(item.productId),
        {
          set: { updatedAt: now },
          add: { stockQuantity: item.quantity },
        }
      );
    }

    // Initiate refund if payment was completed
    if (order.paymentStatus === 'COMPLETED') {
      updates.set!.paymentStatus = 'REFUNDED';
    }
  }

  // Handle delivery - set delivered timestamp
  if (validated.status === 'DELIVERED') {
    // Could add deliveredAt field
  }

  await updateItem(
    PK.business(businessId),
    SK.order(orderId, order.customerId),
    updates
  );

  // Send WebSocket notification to customer
  // This would call the notification handler

  return success({
    orderId,
    status: validated.status,
    message: `Order status updated to ${validated.status}`,
  });
}

// ---------- CANCEL ORDER ----------

async function handleCancelOrder(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  const { customerClaims, businessId } = authorizeCustomerForBusiness(event);
  const customerId = customerClaims.sub;
  const orderId = event.pathParameters?.orderId;

  if (!orderId) {
    throw Errors.validation('Order ID is required');
  }

  // Find order via GSI2
  const result = await queryByGSI2<Order>(
    GSI2PK.customer(customerId),
    { gsi2skPrefix: `ORDER#${orderId}` }
  );
  const order = result.items.find(o => o.PK === PK.business(businessId));

  if (!order) {
    throw Errors.notFound('Order', orderId);
  }

  // Can only cancel if status allows
  const cancellableStatuses: OrderStatus[] = ['PLACED', 'ACCEPTED', 'PREPARING'];
  if (!cancellableStatuses.includes(order.status)) {
    throw Errors.invalidStatusTransition(order.status, 'CANCELLED');
  }

  const now = new Date().toISOString();

  // Restore stock
  for (const item of order.items) {
    await updateItem(
      PK.business(businessId),
      SK.product(item.productId),
      {
        set: { updatedAt: now },
        add: { stockQuantity: item.quantity },
      }
    );
  }

  // Update order
  await updateItem(
    PK.business(businessId),
    SK.order(orderId, customerId),
    {
      set: {
        status: 'CANCELLED',
        updatedAt: now,
        paymentStatus: order.paymentStatus === 'COMPLETED' ? 'REFUNDED' : 'FAILED',
        GSI1PK: GSI1PK.orderStatus('CANCELLED'),
        GSI1SK: GSI1SK.order(businessId, now),
      },
    }
  );

  return success({
    orderId,
    status: 'CANCELLED',
    message: 'Order cancelled successfully',
  });
}

// ---------- CUSTOMER ORDER HISTORY ----------

async function handleCustomerOrderHistory(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  // Extract customer token from Authorization header
  const authHeader = event.headers?.authorization || event.headers?.Authorization;
  if (!authHeader) {
    throw Errors.unauthorized();
  }

  const token = authHeader.split(' ')[1];
  const payload = JSON.parse(Buffer.from(token.split('.')[1], 'base64').toString());
  const customerId = payload.sub;

  const pagination = getPaginationParams(event);
  const status = event.queryStringParameters?.status as OrderStatus | undefined;

  // Query all orders for customer via GSI2
  const result = await queryByGSI2<Order>(
    GSI2PK.customer(customerId),
    { limit: pagination.limit * 2 } // Get more to filter by status if needed
  );

  let orders = result.items;

  // Filter by status if provided
  if (status) {
    orders = orders.filter(o => o.status === status);
  }

  // Sort by date DESC
  orders.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

  const total = orders.length;
  const paginatedOrders = orders.slice(pagination.offset, pagination.offset + pagination.limit);

  return success({
    orders: paginatedOrders.map(formatOrderSummary),
  }, createMeta(pagination, total));
}

// ---------- HELPER FUNCTIONS ----------

async function validateOrderItems(
  businessId: string, 
  items: CartItem[]
): Promise<{ valid: boolean; productId?: string; requested?: number; available?: number }> {
  for (const item of items) {
    const product = await getItem<MarketplaceProduct>(
      PK.business(businessId),
      SK.product(item.productId)
    );

    if (!product || product.stockQuantity < item.quantity) {
      return {
        valid: false,
        productId: item.productId,
        requested: item.quantity,
        available: product?.stockQuantity || 0,
      };
    }
  }

  return { valid: true };
}

async function deleteCart(businessId: string, customerId: string): Promise<void> {
  await deleteCart(businessId, customerId);
}

async function updateCustomerStats(businessId: string, customerId: string, orderTotal: number): Promise<void> {
  const now = new Date().toISOString();
  
  await updateItem(
    PK.business(businessId),
    SK.connection(customerId),
    {
      set: { 
        lastOrderAt: now,
        updatedAt: now,
      },
      add: { 
        totalOrders: 1,
        totalSpent: orderTotal,
      },
    }
  );
}

function generateOrderId(): string {
  const timestamp = Date.now().toString(36).toUpperCase();
  const random = Math.random().toString(36).substring(2, 6).toUpperCase();
  return `ORD${timestamp}${random}`;
}

function calculateDeliveryEstimate(isExpress: boolean, scheduledFor?: string): string {
  const now = new Date();
  
  if (scheduledFor) {
    return scheduledFor;
  }

  if (isExpress) {
    // Express: 30-60 minutes
    now.setMinutes(now.getMinutes() + 45);
  } else {
    // Standard: 2-4 hours
    now.setHours(now.getHours() + 3);
  }

  return now.toISOString();
}

function formatOrderSummary(order: Order) {
  return {
    orderId: order.orderId,
    status: order.status,
    customerName: order.customerName,
    customerPhone: order.customerPhone,
    itemCount: order.items.reduce((sum, i) => sum + i.quantity, 0),
    total: order.total,
    paymentMethod: order.paymentMethod,
    paymentStatus: order.paymentStatus,
    isExpress: order.isExpress,
    scheduledFor: order.scheduledFor,
    estimatedDeliveryTime: order.estimatedDeliveryTime,
    createdAt: order.createdAt,
  };
}

function formatOrderDetail(order: Order) {
  return {
    ...formatOrderSummary(order),
    items: order.items,
    deliveryAddress: order.deliveryAddress,
    subtotal: order.subtotal,
    taxAmount: order.taxAmount,
    deliveryCharge: order.deliveryCharge,
    discountAmount: order.discountAmount,
    couponCode: order.couponCode,
    timeline: order.timeline,
    notes: order.notes,
    prescriptionUrl: order.prescriptionUrl,
    assignedDeliveryPartnerId: order.assignedDeliveryPartnerId,
  };
}
