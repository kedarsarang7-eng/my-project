/**
 * Product API Handler — Complete product management for all business types
 * Endpoints:
 *   GET /products — List products with filters & pagination
 *   POST /products — Create new product
 *   GET /products/{id} — Get product by ID
 *   PUT /products/{id} — Update product
 *   DELETE /products/{id} — Delete product
 *   GET /products/search/barcode — Search by barcode (pharmacy)
 *   GET /products/top-selling — Top-selling products
 *   GET /products/low-stock — Low-stock alerts
 *   POST /products/{id}/image-upload-url — Get presigned S3 URL
 */

import { APIGatewayProxyHandler } from 'aws-lambda';
import { CognitoJwtVerifier } from 'aws-jwt-verify';
import { ProductService } from '../services/product.service';
import { StorageService } from '../services/storage.service';
import { CreateProductDTO, UpdateProductDTO, ProductFilters, ImageUploadRequest } from '../types/product.types';
import { config } from '../config/environment';

const verifier = CognitoJwtVerifier.create({
  userPoolId: config.cognito.userPoolId,
  tokenUse: 'access',
  clientId: config.cognito.clientId,
});

const storageService = new StorageService();

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Content-Type': 'application/json',
};

/**
 * GET /products — List products with filters
 */
export const listProducts: APIGatewayProxyHandler = async (event, context) => {
  try {
    const token = event.headers.Authorization?.replace('Bearer ', '');
    if (!token) {
      return { statusCode: 401, body: JSON.stringify({ error: 'Unauthorized' }), headers: corsHeaders };
    }

    const payload = await verifier.verify(token);
    const tenantId = (payload as any)['custom:tenant_id'];

    const businessType = event.queryStringParameters?.businessType || 'pharmacy';
    const page = parseInt(event.queryStringParameters?.page || '1');
    const limit = parseInt(event.queryStringParameters?.limit || '20');

    const filters: ProductFilters = {
      category: event.queryStringParameters?.category,
      searchTerm: event.queryStringParameters?.searchTerm,
      minPrice: event.queryStringParameters?.minPrice ? parseFloat(event.queryStringParameters.minPrice) : undefined,
      maxPrice: event.queryStringParameters?.maxPrice ? parseFloat(event.queryStringParameters.maxPrice) : undefined,
      inStock: event.queryStringParameters?.inStock === 'true',
    };

    const result = await ProductService.listProducts(tenantId, businessType, filters, page, limit);

    return {
      statusCode: 200,
      body: JSON.stringify(result),
      headers: corsHeaders,
    };
  } catch (error: any) {
    console.error('Error in listProducts:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: error.message }),
      headers: corsHeaders,
    };
  }
};

/**
 * POST /products — Create new product
 */
export const createProduct: APIGatewayProxyHandler = async (event, context) => {
  try {
    const token = event.headers.Authorization?.replace('Bearer ', '');
    if (!token) {
      return { statusCode: 401, body: JSON.stringify({ error: 'Unauthorized' }), headers: corsHeaders };
    }

    const payload = await verifier.verify(token);
    const tenantId = (payload as any)['custom:tenant_id'];
    const userId = payload.sub;

    const businessType = event.queryStringParameters?.businessType || 'pharmacy';
    const dto: CreateProductDTO = JSON.parse(event.body || '{}');

    if (!dto.name || dto.price === undefined || dto.stock === undefined) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Missing required fields: name, price, stock' }),
        headers: corsHeaders,
      };
    }

    const product = await ProductService.createProduct(tenantId, businessType, userId, dto);

    return {
      statusCode: 201,
      body: JSON.stringify(product),
      headers: corsHeaders,
    };
  } catch (error: any) {
    console.error('Error in createProduct:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: error.message }),
      headers: corsHeaders,
    };
  }
};

/**
 * GET /products/{id} — Get product by ID
 */
export const getProductById: APIGatewayProxyHandler = async (event, context) => {
  try {
    const token = event.headers.Authorization?.replace('Bearer ', '');
    if (!token) {
      return { statusCode: 401, body: JSON.stringify({ error: 'Unauthorized' }), headers: corsHeaders };
    }

    const payload = await verifier.verify(token);
    const tenantId = (payload as any)['custom:tenant_id'];

    const productId = event.pathParameters?.id;
    const businessType = event.queryStringParameters?.businessType || 'pharmacy';

    if (!productId) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Missing product ID' }),
        headers: corsHeaders,
      };
    }

    const product = await ProductService.queryProductById(tenantId, businessType, productId);

    if (!product) {
      return {
        statusCode: 404,
        body: JSON.stringify({ error: 'Product not found' }),
        headers: corsHeaders,
      };
    }

    return {
      statusCode: 200,
      body: JSON.stringify(product),
      headers: corsHeaders,
    };
  } catch (error: any) {
    console.error('Error in getProductById:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: error.message }),
      headers: corsHeaders,
    };
  }
};

/**
 * PUT /products/{id} — Update product
 */
export const updateProduct: APIGatewayProxyHandler = async (event, context) => {
  try {
    const token = event.headers.Authorization?.replace('Bearer ', '');
    if (!token) {
      return { statusCode: 401, body: JSON.stringify({ error: 'Unauthorized' }), headers: corsHeaders };
    }

    const payload = await verifier.verify(token);
    const tenantId = (payload as any)['custom:tenant_id'];
    const userId = payload.sub;

    const productId = event.pathParameters?.id;
    const businessType = event.queryStringParameters?.businessType || 'pharmacy';
    const dto: UpdateProductDTO = JSON.parse(event.body || '{}');

    if (!productId) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Missing product ID' }),
        headers: corsHeaders,
      };
    }

    const product = await ProductService.updateProduct(tenantId, businessType, productId, userId, dto);

    return {
      statusCode: 200,
      body: JSON.stringify(product),
      headers: corsHeaders,
    };
  } catch (error: any) {
    console.error('Error in updateProduct:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: error.message }),
      headers: corsHeaders,
    };
  }
};

/**
 * DELETE /products/{id} — Delete product
 */
export const deleteProduct: APIGatewayProxyHandler = async (event, context) => {
  try {
    const token = event.headers.Authorization?.replace('Bearer ', '');
    if (!token) {
      return { statusCode: 401, body: JSON.stringify({ error: 'Unauthorized' }), headers: corsHeaders };
    }

    const payload = await verifier.verify(token);
    const tenantId = (payload as any)['custom:tenant_id'];

    const productId = event.pathParameters?.id;
    const businessType = event.queryStringParameters?.businessType || 'pharmacy';

    if (!productId) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Missing product ID' }),
        headers: corsHeaders,
      };
    }

    await ProductService.deleteProduct(tenantId, businessType, productId);

    return {
      statusCode: 204,
      body: '',
      headers: corsHeaders,
    };
  } catch (error: any) {
    console.error('Error in deleteProduct:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: error.message }),
      headers: corsHeaders,
    };
  }
};

/**
 * GET /products/search/barcode — Search by barcode
 */
export const searchByBarcode: APIGatewayProxyHandler = async (event, context) => {
  try {
    const token = event.headers.Authorization?.replace('Bearer ', '');
    if (!token) {
      return { statusCode: 401, body: JSON.stringify({ error: 'Unauthorized' }), headers: corsHeaders };
    }

    const payload = await verifier.verify(token);
    const tenantId = (payload as any)['custom:tenant_id'];

    const barcode = event.queryStringParameters?.barcode;
    if (!barcode) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Missing barcode parameter' }),
        headers: corsHeaders,
      };
    }

    const product = await ProductService.searchByBarcode(tenantId, barcode);

    if (!product) {
      return {
        statusCode: 404,
        body: JSON.stringify({ error: 'Product not found' }),
        headers: corsHeaders,
      };
    }

    return {
      statusCode: 200,
      body: JSON.stringify(product),
      headers: corsHeaders,
    };
  } catch (error: any) {
    console.error('Error in searchByBarcode:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: error.message }),
      headers: corsHeaders,
    };
  }
};

/**
 * GET /products/top-selling — Top-selling products
 */
export const getTopSelling: APIGatewayProxyHandler = async (event, context) => {
  try {
    const token = event.headers.Authorization?.replace('Bearer ', '');
    if (!token) {
      return { statusCode: 401, body: JSON.stringify({ error: 'Unauthorized' }), headers: corsHeaders };
    }

    const payload = await verifier.verify(token);
    const tenantId = (payload as any)['custom:tenant_id'];

    const businessType = event.queryStringParameters?.businessType || 'pharmacy';
    const limit = parseInt(event.queryStringParameters?.limit || '10');

    const products = await ProductService.getTopSellingProducts(tenantId, businessType, limit);

    return {
      statusCode: 200,
      body: JSON.stringify({ items: products, total: products.length }),
      headers: corsHeaders,
    };
  } catch (error: any) {
    console.error('Error in getTopSelling:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: error.message }),
      headers: corsHeaders,
    };
  }
};

/**
 * GET /products/low-stock — Low-stock alerts
 */
export const getLowStock: APIGatewayProxyHandler = async (event, context) => {
  try {
    const token = event.headers.Authorization?.replace('Bearer ', '');
    if (!token) {
      return { statusCode: 401, body: JSON.stringify({ error: 'Unauthorized' }), headers: corsHeaders };
    }

    const payload = await verifier.verify(token);
    const tenantId = (payload as any)['custom:tenant_id'];

    const businessType = event.queryStringParameters?.businessType || 'pharmacy';
    const limit = parseInt(event.queryStringParameters?.limit || '20');

    const products = await ProductService.getLowStockProducts(tenantId, businessType, limit);

    return {
      statusCode: 200,
      body: JSON.stringify({ items: products, total: products.length }),
      headers: corsHeaders,
    };
  } catch (error: any) {
    console.error('Error in getLowStock:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: error.message }),
      headers: corsHeaders,
    };
  }
};

/**
 * POST /products/{id}/image-upload-url — Get presigned S3 URL for product image
 */
export const getImageUploadUrl: APIGatewayProxyHandler = async (event, context) => {
  try {
    const token = event.headers.Authorization?.replace('Bearer ', '');
    if (!token) {
      return { statusCode: 401, body: JSON.stringify({ error: 'Unauthorized' }), headers: corsHeaders };
    }

    const payload = await verifier.verify(token);
    const tenantId = (payload as any)['custom:tenant_id'];

    const productId = event.pathParameters?.id;
    const businessType = event.queryStringParameters?.businessType || 'pharmacy';
    const req: ImageUploadRequest = JSON.parse(event.body || '{}');

    if (!productId || !req.originalFileName || !req.fileType) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Missing required fields' }),
        headers: corsHeaders,
      };
    }

    // Generate S3 keys for product images
    const timestamp = Date.now();
    const s3Key = `products/${businessType}/${productId}/${timestamp}-original.jpg`;
    const s3ThumbnailKey = `products/${businessType}/${productId}/${timestamp}-thumb.jpg`;

    // Get presigned upload URL
    const uploadUrl = await storageService.getUploadUrl(s3Key, req.fileType);

    return {
      statusCode: 200,
      body: JSON.stringify({
        uploadUrl,
        s3Key,
        s3ThumbnailKey,
        expiresIn: 300, // 5 minutes
      }),
      headers: corsHeaders,
    };
  } catch (error: any) {
    console.error('Error in getImageUploadUrl:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: error.message }),
      headers: corsHeaders,
    };
  }
};

/**
 * OPTIONS — CORS preflight
 */
export const options: APIGatewayProxyHandler = async (event, context) => {
  return {
    statusCode: 200,
    body: '',
    headers: corsHeaders,
  };
};
