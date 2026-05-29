// ============================================================
// Marketplace Delivery Handler
// Routes:
//   GET /v1/businesses/{businessId}/delivery-partners - List partners
//   POST /v1/businesses/{businessId}/delivery-partners - Create partner
//   POST /v1/businesses/{businessId}/delivery-partners/{partnerId}/location - Update location
//   GET /v1/businesses/{businessId}/orders/{orderId}/tracking - Track order
// ============================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Handler } from 'aws-lambda';
import { z } from 'zod';
import { 
  DeliveryPartner,
  Order,
  PK, 
  SK, 
} from '../../shared/types';
import { authorizeBusiness } from '../../shared/auth';
import { Errors } from '../../shared/errors';
import { success, error, getPaginationParams, createMeta } from '../../shared/response';
import { 
  getItem, 
  putItem, 
  updateItem,
  queryByPKSKPrefix,
} from '../../shared/dynamodb';

// ---------- VALIDATION SCHEMAS ----------

const createPartnerSchema = z.object({
  name: z.string().min(1).max(100),
  phone: z.string().regex(/^[0-9]{10}$/),
  email: z.string().email().optional(),
  vehicleType: z.enum(['BIKE', 'SCOOTER', 'VAN']),
  vehicleNumber: z.string().optional(),
});

const updateLocationSchema = z.object({
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
});

// ---------- ROUTE HANDLERS ----------

export const handler: Handler<APIGatewayProxyEventV2, APIGatewayProxyResultV2> = async (event) => {
  try {
    const method = event.requestContext.http.method;
    const path = event.rawPath || '';

    // List delivery partners
    if (method === 'GET' && path.includes('/delivery-partners') && !path.includes('location')) {
      return handleListPartners(event);
    }

    // Create delivery partner
    if (method === 'POST' && path.endsWith('/delivery-partners')) {
      return handleCreatePartner(event);
    }

    // Update location
    if (method === 'POST' && path.endsWith('/location')) {
      return handleUpdateLocation(event);
    }

    // Track order
    if (method === 'GET' && path.endsWith('/tracking')) {
      return handleTrackOrder(event);
    }

    return error(Errors.notFound('Route', `${method} ${path}`));
  } catch (err) {
    console.error('Delivery handler error:', err);
    return error(err instanceof Error ? err : String(err));
  }
};

// ---------- LIST DELIVERY PARTNERS ----------

async function handleListPartners(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  const claims = authorizeBusiness(event);
  const businessId = claims.businessId;

  const pagination = getPaginationParams(event);
  const isActive = event.queryStringParameters?.isActive;

  const result = await queryByPKSKPrefix<DeliveryPartner>(
    PK.business(businessId),
    'DELIVERY#PARTNER#',
    { limit: pagination.limit }
  );

  let partners = result.items;

  if (isActive !== undefined) {
    const active = isActive === 'true';
    partners = partners.filter(p => p.isActive === active);
  }

  const total = partners.length;
  const paginated = partners.slice(pagination.offset, pagination.offset + pagination.limit);

  return success({
    partners: paginated.map(p => ({
      partnerId: p.partnerId,
      name: p.name,
      phone: p.phone,
      email: p.email,
      vehicleType: p.vehicleType,
      vehicleNumber: p.vehicleNumber,
      isActive: p.isActive,
      currentLocation: p.currentLocation,
      totalDeliveries: p.totalDeliveries,
      rating: p.rating,
    })),
  }, createMeta(pagination, total));
}

// ---------- CREATE DELIVERY PARTNER ----------

async function handleCreatePartner(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  const claims = authorizeBusiness(event);
  const businessId = claims.businessId;

  const body = JSON.parse(event.body || '{}');
  const validated = createPartnerSchema.parse(body);

  const partnerId = `DP${Date.now().toString(36).toUpperCase()}`;
  const now = new Date().toISOString();

  const partner: DeliveryPartner = {
    PK: PK.business(businessId),
    SK: SK.deliveryPartner(partnerId),
    businessId,
    partnerId,
    name: validated.name,
    phone: validated.phone,
    email: validated.email,
    vehicleType: validated.vehicleType,
    vehicleNumber: validated.vehicleNumber,
    isActive: true,
    assignedOrders: [],
    totalDeliveries: 0,
    rating: 0,
    createdAt: now,
    updatedAt: now,
  };

  await putItem(partner as unknown as Record<string, unknown>);

  return success({
    partnerId,
    message: 'Delivery partner created successfully',
  }, undefined, 201);
}

// ---------- UPDATE LOCATION ----------

async function handleUpdateLocation(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  // This endpoint can be called by the delivery partner app
  // It uses a special API key or the partner's JWT
  const businessId = event.pathParameters?.businessId;
  const partnerId = event.pathParameters?.partnerId;

  if (!businessId || !partnerId) {
    throw Errors.validation('Business ID and Partner ID are required');
  }

  const body = JSON.parse(event.body || '{}');
  const { lat, lng } = updateLocationSchema.parse(body);

  const now = new Date().toISOString();

  await updateItem(
    PK.business(businessId),
    SK.deliveryPartner(partnerId),
    {
      set: {
        currentLocation: { lat, lng, updatedAt: now },
        updatedAt: now,
      },
    }
  );

  // Broadcast location update to customer via WebSocket
  // This would trigger a notification to connected customers

  return success({ message: 'Location updated' });
}

// ---------- TRACK ORDER ----------

async function handleTrackOrder(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  const businessId = event.pathParameters?.businessId;
  const orderId = event.pathParameters?.orderId;

  if (!businessId || !orderId) {
    throw Errors.validation('Business ID and Order ID are required');
  }

  // Get order
  const orders = await queryByPKSKPrefix<Order>(
    PK.business(businessId),
    'ORDER#',
    { limit: 100 }
  );
  const order = orders.items.find(o => o.orderId === orderId);

  if (!order) {
    throw Errors.notFound('Order', orderId);
  }

  // Get delivery partner info if assigned
  let partner = null;
  if (order.assignedDeliveryPartnerId) {
    partner = await getItem<DeliveryPartner>(
      PK.business(businessId),
      SK.deliveryPartner(order.assignedDeliveryPartnerId)
    );
  }

  return success({
    orderId: order.orderId,
    status: order.status,
    estimatedDeliveryTime: order.estimatedDeliveryTime,
    timeline: order.timeline,
    deliveryPartner: partner ? {
      name: partner.name,
      phone: partner.phone,
      currentLocation: partner.currentLocation,
      vehicleType: partner.vehicleType,
      vehicleNumber: partner.vehicleNumber,
    } : null,
  });
}
