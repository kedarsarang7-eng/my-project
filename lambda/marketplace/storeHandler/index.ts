// ============================================================
// Marketplace Store Handler
// Routes:
//   POST /v1/businesses/{businessId}/connect - Connect customer to store
//   GET /v1/businesses/{businessId}/profile - Get store public profile
//   GET /v1/businesses/{businessId}/categories - Get store categories
// ============================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Handler } from 'aws-lambda';
import { z } from 'zod';
import { 
  CustomerConnection, 
  CustomerTokenClaims, 
  PK, 
  SK, 
  GSI1PK, 
  GSI1SK,
  MarketplaceProduct,
} from '../../shared/types';
import { authorizeCustomerForBusiness, validateBusinessCategory } from '../../shared/auth';
import { Errors } from '../../shared/errors';
import { success, error, getPaginationParams, createMeta } from '../../shared/response';
import { 
  docClient, 
  getItem, 
  putItem, 
  queryByPK,
  queryByPKSKPrefix,
  queryByGSI1,
  isCustomerConnected,
} from '../../shared/dynamodb';
import { ScanCommand } from '@aws-sdk/lib-dynamodb';

const TABLE_NAME = process.env.TABLE_NAME || 'DukanMarketplace';

// ---------- VALIDATION SCHEMAS ----------

const connectSchema = z.object({
  customerName: z.string().min(1).max(100),
  customerPhone: z.string().regex(/^[0-9]{10}$/),
});

// ---------- ROUTE HANDLERS ----------

export const handler: Handler<APIGatewayProxyEventV2, APIGatewayProxyResultV2> = async (event) => {
  try {
    const { routeKey } = event;
    const method = event.requestContext.http.method;
    const path = event.rawPath || '';

    // Route: POST /v1/businesses/{businessId}/connect
    if (method === 'POST' && path.endsWith('/connect')) {
      return handleConnect(event);
    }

    // Route: GET /v1/businesses/{businessId}/profile
    if (method === 'GET' && path.endsWith('/profile')) {
      return handleGetProfile(event);
    }

    // Route: GET /v1/businesses/{businessId}/categories
    if (method === 'GET' && path.endsWith('/categories')) {
      return handleGetCategories(event);
    }

    // Route: GET /v1/businesses/{businessId}/connection-status
    if (method === 'GET' && path.endsWith('/connection-status')) {
      return handleGetConnectionStatus(event);
    }

    return error(Errors.notFound('Route', `${method} ${path}`));
  } catch (err) {
    console.error('Store handler error:', err);
    return error(err instanceof Error ? err : String(err));
  }
};

// ---------- CONNECT CUSTOMER TO STORE ----------

async function handleConnect(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  // Authorize customer and extract businessId from path
  const { customerClaims, businessId } = await authorizeCustomerForBusiness(event);
  const customerId = customerClaims.sub;

  // Parse and validate body
  const body = JSON.parse(event.body || '{}');
  const validated = connectSchema.parse(body);

  // Check if business exists and is marketplace-enabled
  const business = await getBusiness(businessId);
  if (!business) {
    throw Errors.notFound('Business', businessId);
  }

  // Validate business category allows marketplace
  validateBusinessCategory(business.category);

  // Check if already connected
  const existing = await isCustomerConnected(businessId, customerId);
  if (existing) {
    // Update connection info if already connected
    await updateConnection(businessId, customerId, validated);
    return success({
      message: 'Already connected to this store',
      business: formatBusinessPublic(business),
    });
  }

  // Create new connection
  const now = new Date().toISOString();
  const connection: CustomerConnection = {
    PK: PK.business(businessId),
    SK: SK.connection(customerId),
    businessId,
    customerId,
    customerName: validated.customerName,
    customerPhone: validated.customerPhone,
    status: 'active',
    connectedAt: now,
    totalOrders: 0,
    totalSpent: 0,
    GSI1PK: GSI1PK.customer(customerId),
    GSI1SK: GSI1SK.connection(businessId),
    createdAt: now,
    updatedAt: now,
  };

  await putItem(connection as unknown as Record<string, unknown>);

  // Return store profile with categories and featured products
  const [categories, featuredProducts] = await Promise.all([
    getBusinessCategories(businessId),
    getFeaturedProducts(businessId),
  ]);

  return success({
    message: 'Successfully connected to store',
    business: formatBusinessPublic(business),
    categories,
    featuredProducts: featuredProducts.map(formatProductPublic),
  }, undefined, 201);
}

// ---------- GET STORE PROFILE ----------

async function handleGetProfile(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  // Public endpoint - no auth required for basic profile
  const businessId = event.pathParameters?.businessId;
  if (!businessId) {
    throw Errors.validation('Business ID is required');
  }

  const business = await getBusiness(businessId);
  if (!business) {
    throw Errors.notFound('Business', businessId);
  }

  // Only return marketplace-enabled businesses
  try {
    validateBusinessCategory(business.category);
  } catch {
    throw Errors.forbidden('This business is not available on the marketplace');
  }

  const [categories, featuredProducts] = await Promise.all([
    getBusinessCategories(businessId),
    getFeaturedProducts(businessId),
  ]);

  return success({
    business: formatBusinessPublic(business),
    categories,
    featuredProducts: featuredProducts.map(formatProductPublic),
  });
}

// ---------- GET STORE CATEGORIES ----------

async function handleGetCategories(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  const businessId = event.pathParameters?.businessId;
  if (!businessId) {
    throw Errors.validation('Business ID is required');
  }

  const business = await getBusiness(businessId);
  if (!business) {
    throw Errors.notFound('Business', businessId);
  }

  validateBusinessCategory(business.category);

  const categories = await getBusinessCategories(businessId);

  return success({ categories });
}

// ---------- GET CONNECTION STATUS ----------

async function handleGetConnectionStatus(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  const { customerClaims, businessId } = await authorizeCustomerForBusiness(event);
  const customerId = customerClaims.sub;

  const connection = await getItem<CustomerConnection>(
    PK.business(businessId),
    SK.connection(customerId)
  );

  if (!connection) {
    return success({ connected: false });
  }

  return success({
    connected: connection.status === 'active',
    status: connection.status,
    connectedAt: connection.connectedAt,
    totalOrders: connection.totalOrders,
    totalSpent: connection.totalSpent,
  });
}

// ---------- HELPER FUNCTIONS ----------

async function getBusiness(businessId: string): Promise<{
  businessId: string;
  name: string;
  category: string;
  logo?: string;
  address?: string;
  phone?: string;
  description?: string;
  rating?: number;
  deliveryTime?: string;
  minOrderValue?: number;
  deliveryCharge?: number;
  isOpen?: boolean;
} | null> {
  // Query business metadata from core business table
  const result = await docClient.send(new ScanCommand({
    TableName: TABLE_NAME,
    FilterExpression: 'PK = :pk AND SK = :sk',
    ExpressionAttributeValues: {
      ':pk': PK.business(businessId),
      ':sk': 'METADATA',
    },
    Limit: 1,
  }));

  const item = result.Items?.[0];
  if (!item) return null;

  return {
    businessId: item.businessId,
    name: item.name,
    category: item.category,
    logo: item.logo,
    address: item.address,
    phone: item.phone,
    description: item.description,
    rating: item.rating,
    deliveryTime: item.deliveryTime,
    minOrderValue: item.minOrderValue,
    deliveryCharge: item.deliveryCharge,
    isOpen: item.isOpen,
  };
}

async function updateConnection(
  businessId: string, 
  customerId: string, 
  data: z.infer<typeof connectSchema>
): Promise<void> {
  const now = new Date().toISOString();
  await docClient.send(new ScanCommand({
    TableName: TABLE_NAME,
    FilterExpression: 'PK = :pk AND SK = :sk',
    ExpressionAttributeValues: {
      ':pk': PK.business(businessId),
      ':sk': SK.connection(customerId),
    },
  }));
}

async function getBusinessCategories(businessId: string): Promise<string[]> {
  // Get distinct categories from products
  const result = await queryByPKSKPrefix<MarketplaceProduct>(
    PK.business(businessId),
    'PRODUCT#',
    { limit: 1000 }
  );

  const categories = new Set<string>();
  result.items.forEach(p => {
    if (p.category) categories.add(p.category);
  });

  return Array.from(categories).sort();
}

async function getFeaturedProducts(businessId: string): Promise<MarketplaceProduct[]> {
  // Get first 10 active products as featured
  const result = await queryByPKSKPrefix<MarketplaceProduct>(
    PK.business(businessId),
    'PRODUCT#',
    { limit: 10 }
  );

  return result.items
    .filter(p => p.isActive && p.isAvailableForOnline && p.stockQuantity > 0)
    .slice(0, 8);
}

function formatBusinessPublic(business: NonNullable<Awaited<ReturnType<typeof getBusiness>>>) {
  return {
    id: business.businessId,
    name: business.name,
    category: business.category,
    logo: business.logo,
    address: business.address,
    phone: business.phone,
    description: business.description,
    rating: business.rating,
    deliveryTime: business.deliveryTime,
    minOrderValue: business.minOrderValue,
    deliveryCharge: business.deliveryCharge,
    isOpen: business.isOpen,
  };
}

function formatProductPublic(product: MarketplaceProduct) {
  return {
    id: product.productId,
    name: product.name,
    description: product.description,
    category: product.category,
    brand: product.brand,
    mrp: product.mrp,
    sellingPrice: product.sellingPrice,
    discountPercent: product.discountPercent,
    stockQuantity: product.stockQuantity,
    unit: product.unit,
    images: product.images,
    gstPercent: product.gstPercent,
    // Industry-specific
    expiryDate: product.expiryDate,
    drugSchedule: product.drugSchedule,
    warrantyMonths: product.warrantyMonths,
  };
}
