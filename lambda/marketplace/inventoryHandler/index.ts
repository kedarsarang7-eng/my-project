// ============================================================
// Marketplace Inventory Handler
// Routes:
//   GET /v1/businesses/{businessId}/products - List products
//   GET /v1/businesses/{businessId}/products/{productId} - Get product details
//   GET /v1/businesses/{businessId}/products/search - Search products
//   POST /v1/businesses/{businessId}/inventory/sync - Sync from billing (business only)
// ============================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Handler } from 'aws-lambda';
import { z } from 'zod';
import { 
  MarketplaceProduct, 
  PK, 
  SK, 
  GSI1PK, 
  GSI1SK,
  GSI2PK,
  GSI2SK,
} from '../../shared/types';
import { authorizeCustomerForBusiness, authorizeBusiness, validateBusinessCategory } from '../../shared/auth';
import { Errors } from '../../shared/errors';
import { success, error, getPaginationParams, createMeta } from '../../shared/response';
import { 
  getItem, 
  putItem, 
  queryByPK,
  queryByPKSKPrefix,
  queryByGSI1,
  queryByGSI2,
} from '../../shared/dynamodb';

// ---------- VALIDATION SCHEMAS ----------

const productSyncSchema = z.object({
  productId: z.string().min(1),
  name: z.string().min(1).max(200),
  description: z.string().max(1000).optional(),
  category: z.string().min(1),
  subcategory: z.string().optional(),
  brand: z.string().optional(),
  mrp: z.number().positive(),
  sellingPrice: z.number().positive(),
  stockQuantity: z.number().int().min(0),
  unit: z.string().min(1),
  images: z.array(z.string()).default([]),
  isActive: z.boolean().default(true),
  isAvailableForOnline: z.boolean().default(true),
  barcode: z.string().optional(),
  hsnCode: z.string().optional(),
  gstPercent: z.number().min(0).max(100).default(0),
  // Industry-specific
  expiryDate: z.string().datetime().optional(),
  drugSchedule: z.string().optional(),
  comboProducts: z.array(z.string()).optional(),
  specAttributes: z.record(z.string()).optional(),
  warrantyMonths: z.number().int().optional(),
});

// ---------- ROUTE HANDLERS ----------

export const handler: Handler<APIGatewayProxyEventV2, APIGatewayProxyResultV2> = async (event) => {
  try {
    const method = event.requestContext.http.method;
    const path = event.rawPath || '';

    // List products
    if (method === 'GET' && path.match(/\/businesses\/[^/]+\/products$/) && !path.includes('search')) {
      return handleListProducts(event);
    }

    // Search products
    if (method === 'GET' && path.endsWith('/search')) {
      return handleSearchProducts(event);
    }

    // Get single product
    if (method === 'GET' && path.match(/\/businesses\/[^/]+\/products\/[^/]+$/)) {
      return handleGetProduct(event);
    }

    // Sync inventory (business only)
    if (method === 'POST' && path.endsWith('/sync')) {
      return handleSyncInventory(event);
    }

    return error(Errors.notFound('Route', `${method} ${path}`));
  } catch (err) {
    console.error('Inventory handler error:', err);
    return error(err instanceof Error ? err : String(err));
  }
};

// ---------- LIST PRODUCTS ----------

async function handleListProducts(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  const businessId = event.pathParameters?.businessId;
  if (!businessId) {
    throw Errors.validation('Business ID is required');
  }

  const pagination = getPaginationParams(event);
  const category = event.queryStringParameters?.category;
  const brand = event.queryStringParameters?.brand;
  const inStock = event.queryStringParameters?.inStock === 'true';
  const sortBy = event.queryStringParameters?.sortBy || 'newest'; // newest, priceAsc, priceDesc, popularity

  // Build query based on filters
  let products: MarketplaceProduct[] = [];

  if (category) {
    // Query by category using GSI1
    const result = await queryByGSI1<MarketplaceProduct>(
      GSI1PK.category(category),
      { 
        limit: pagination.limit,
        gsi1skPrefix: GSI1SK.product(''),
      }
    );
    products = result.items.filter(p => p.PK === PK.business(businessId));
  } else if (brand) {
    // Query by brand using GSI2
    const result = await queryByGSI2<MarketplaceProduct>(
      GSI2PK.brand(brand),
      { 
        limit: pagination.limit,
        gsi2skPrefix: GSI2SK.product(''),
      }
    );
    products = result.items.filter(p => p.PK === PK.business(businessId));
  } else {
    // Query all products for business
    const result = await queryByPKSKPrefix<MarketplaceProduct>(
      PK.business(businessId),
      SK.product(''),
      { limit: pagination.limit }
    );
    products = result.items;
  }

  // Apply filters
  if (inStock) {
    products = products.filter(p => p.stockQuantity > 0);
  }

  // Only return active and online-available products for customers
  products = products.filter(p => p.isActive && p.isAvailableForOnline);

  // Sort
  products = sortProducts(products, sortBy);

  // Paginate manually since we're filtering
  const total = products.length;
  const paginatedProducts = products.slice(pagination.offset, pagination.offset + pagination.limit);

  return success({
    products: paginatedProducts.map(formatProductPublic),
    filters: {
      category,
      brand,
      inStock,
      sortBy,
    },
  }, createMeta(pagination, total));
}

// ---------- GET SINGLE PRODUCT ----------

async function handleGetProduct(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  const businessId = event.pathParameters?.businessId;
  const productId = event.pathParameters?.productId;

  if (!businessId || !productId) {
    throw Errors.validation('Business ID and Product ID are required');
  }

  const product = await getItem<MarketplaceProduct>(
    PK.business(businessId),
    SK.product(productId)
  );

  if (!product) {
    throw Errors.notFound('Product', productId);
  }

  if (!product.isActive || !product.isAvailableForOnline) {
    throw Errors.notFound('Product', productId);
  }

  // Get related products (same category)
  const relatedResult = await queryByGSI1<MarketplaceProduct>(
    GSI1PK.category(product.category),
    { limit: 6 }
  );
  
  const relatedProducts = relatedResult.items
    .filter(p => p.PK === PK.business(businessId) && p.productId !== productId)
    .slice(0, 5)
    .map(formatProductPublic);

  return success({
    product: formatProductDetail(product),
    relatedProducts,
  });
}

// ---------- SEARCH PRODUCTS ----------

async function handleSearchProducts(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  const businessId = event.pathParameters?.businessId;
  if (!businessId) {
    throw Errors.validation('Business ID is required');
  }

  const query = event.queryStringParameters?.q?.toLowerCase().trim();
  const barcode = event.queryStringParameters?.barcode;

  if (!query && !barcode) {
    throw Errors.validation('Search query (q) or barcode is required');
  }

  const pagination = getPaginationParams(event);

  // Get all products for this business (limit to reasonable number for search)
  const result = await queryByPKSKPrefix<MarketplaceProduct>(
    PK.business(businessId),
    SK.product(''),
    { limit: 500 }
  );

  let products = result.items.filter(p => p.isActive && p.isAvailableForOnline);

  if (barcode) {
    // Exact match on barcode
    products = products.filter(p => p.barcode === barcode);
  } else if (query) {
    // Fuzzy search on name, description, brand
    const searchTerms = query.split(' ').filter(t => t.length > 0);
    
    products = products.filter(p => {
      const searchText = `${p.name} ${p.description || ''} ${p.brand || ''} ${p.category}`.toLowerCase();
      return searchTerms.every(term => searchText.includes(term));
    });

    // Sort by relevance (exact name match first)
    products.sort((a, b) => {
      const aExact = a.name.toLowerCase() === query;
      const bExact = b.name.toLowerCase() === query;
      if (aExact && !bExact) return -1;
      if (!aExact && bExact) return 1;
      
      const aStartsWith = a.name.toLowerCase().startsWith(query);
      const bStartsWith = b.name.toLowerCase().startsWith(query);
      if (aStartsWith && !bStartsWith) return -1;
      if (!aStartsWith && bStartsWith) return 1;
      
      return 0;
    });
  }

  const total = products.length;
  const paginatedProducts = products.slice(pagination.offset, pagination.offset + pagination.limit);

  return success({
    products: paginatedProducts.map(formatProductPublic),
    query: query || barcode,
  }, createMeta(pagination, total));
}

// ---------- SYNC INVENTORY (Business Only) ----------

async function handleSyncInventory(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  // Authorize business owner
  const claims = await authorizeBusiness(event);
  const businessId = claims.businessId;

  // Validate business category
  const businessCategory = await getBusinessCategory(businessId);
  validateBusinessCategory(businessCategory);

  // Parse and validate body
  const body = JSON.parse(event.body || '{}');
  const products = z.array(productSyncSchema).parse(body.products || [body]);

  const now = new Date().toISOString();
  const results = { created: 0, updated: 0, errors: [] as string[] };

  for (const productData of products) {
    try {
      const existing = await getItem<MarketplaceProduct>(
        PK.business(businessId),
        SK.product(productData.productId)
      );

      const discountPercent = Math.round(
        ((productData.mrp - productData.sellingPrice) / productData.mrp) * 100
      );

      const product: MarketplaceProduct = {
        PK: PK.business(businessId),
        SK: SK.product(productData.productId),
        businessId,
        productId: productData.productId,
        name: productData.name,
        description: productData.description,
        category: productData.category,
        subcategory: productData.subcategory,
        brand: productData.brand,
        mrp: productData.mrp,
        sellingPrice: productData.sellingPrice,
        discountPercent,
        stockQuantity: productData.stockQuantity,
        unit: productData.unit,
        images: productData.images,
        isActive: productData.isActive,
        isAvailableForOnline: productData.isAvailableForOnline,
        barcode: productData.barcode,
        hsnCode: productData.hsnCode,
        gstPercent: productData.gstPercent,
        // Industry-specific
        expiryDate: productData.expiryDate,
        drugSchedule: productData.drugSchedule,
        comboProducts: productData.comboProducts,
        specAttributes: productData.specAttributes,
        warrantyMonths: productData.warrantyMonths,
        GSI1PK: GSI1PK.category(productData.category),
        GSI1SK: GSI1SK.product(productData.productId),
        GSI2PK: productData.brand ? GSI2PK.brand(productData.brand) : undefined,
        GSI2SK: productData.brand ? GSI2SK.product(productData.productId) : undefined,
        createdAt: existing?.createdAt || now,
        updatedAt: now,
      };

      await putItem(product as unknown as Record<string, unknown>);

      if (existing) {
        results.updated++;
      } else {
        results.created++;
      }
    } catch (err) {
      results.errors.push(`Product ${productData.productId}: ${err instanceof Error ? err.message : String(err)}`);
    }
  }

  return success(results);
}

// ---------- HELPER FUNCTIONS ----------

async function getBusinessCategory(businessId: string): Promise<string> {
  // This would query the core business table
  // For now, return a default
  return 'grocery';
}

function sortProducts(products: MarketplaceProduct[], sortBy: string): MarketplaceProduct[] {
  switch (sortBy) {
    case 'priceAsc':
      return products.sort((a, b) => a.sellingPrice - b.sellingPrice);
    case 'priceDesc':
      return products.sort((a, b) => b.sellingPrice - a.sellingPrice);
    case 'popularity':
      // Would use sales data - for now sort by stock (higher stock = more popular assumption)
      return products.sort((a, b) => b.stockQuantity - a.stockQuantity);
    case 'newest':
    default:
      return products.sort((a, b) => 
        new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
      );
  }
}

function formatProductPublic(product: MarketplaceProduct) {
  return {
    id: product.productId,
    name: product.name,
    description: product.description,
    category: product.category,
    subcategory: product.subcategory,
    brand: product.brand,
    mrp: product.mrp,
    sellingPrice: product.sellingPrice,
    discountPercent: product.discountPercent,
    stockQuantity: product.stockQuantity,
    unit: product.unit,
    images: product.images,
    isAvailable: product.stockQuantity > 0,
    gstPercent: product.gstPercent,
    // Industry-specific badges
    expiryDate: product.expiryDate,
    drugSchedule: product.drugSchedule,
    warrantyMonths: product.warrantyMonths,
  };
}

function formatProductDetail(product: MarketplaceProduct) {
  return {
    ...formatProductPublic(product),
    // Additional detail fields
    barcode: product.barcode,
    hsnCode: product.hsnCode,
    specAttributes: product.specAttributes,
    comboProducts: product.comboProducts,
    createdAt: product.createdAt,
  };
}
