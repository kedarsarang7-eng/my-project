// ============================================================================
// Customer Handler — Lambda handler for customer-facing operations
// ============================================================================
// Provides API endpoints for customers to view shop info, products, and orders

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Context } from 'aws-lambda';
import { authorizedHandler } from '../middleware/cognito-auth';
import { response, errorResponse } from '../utils/response';
import { logger } from '../utils/logger';
import * as customerService from '../services/customer.service';
import { AppError } from '../utils/errors';

// ---- Shop Operations ----

/**
 * GET /api/v1/customer/shop/{shopCode}
 * Verify and get shop public info
 */
export const verifyShop = authorizedHandler(
    async (event: APIGatewayProxyEventV2, context: Context): Promise<APIGatewayProxyResultV2> => {
        try {
            const shopCode = event.pathParameters?.shopCode;
            if (!shopCode) {
                throw new AppError('MISSING_SHOP_CODE', 'Shop code is required');
            }

            const shop = await customerService.verifyShop(shopCode);
            if (!shop) {
                return response(404, {
                    success: false,
                    error: 'SHOP_NOT_FOUND',
                    message: 'Shop not found or inactive',
                });
            }

            return response(200, {
                success: true,
                data: shop,
            });
        } catch (error: any) {
            logger.error('Verify shop failed', { error: error.message });
            return errorResponse(error);
        }
    },
    { requireAuth: false } // Public endpoint
);

// ---- Product Operations ----

/**
 * GET /api/v1/customer/shop/{shopId}/products
 * Get products for a shop
 */
export const getProducts = authorizedHandler(
    async (event: APIGatewayProxyEventV2, context: Context): Promise<APIGatewayProxyResultV2> => {
        try {
            const shopId = event.pathParameters?.shopId;
            if (!shopId) {
                throw new AppError('MISSING_SHOP_ID', 'Shop ID is required');
            }

            const query = event.queryStringParameters || {};

            const result = await customerService.getProducts(shopId, {
                category: query.category,
                search: query.search,
                page: query.page ? parseInt(query.page) : 1,
                limit: query.limit ? parseInt(query.limit) : 50,
            });

            return response(200, {
                success: true,
                data: result.products,
                pagination: {
                    page: query.page ? parseInt(query.page) : 1,
                    limit: query.limit ? parseInt(query.limit) : 50,
                    total: result.total,
                },
            });
        } catch (error: any) {
            logger.error('Get products failed', { error: error.message });
            return errorResponse(error);
        }
    },
    { requireAuth: false } // Public endpoint
);

/**
 * GET /api/v1/customer/shop/{shopId}/products/{productId}
 * Get product details
 */
export const getProductDetail = authorizedHandler(
    async (event: APIGatewayProxyEventV2, context: Context): Promise<APIGatewayProxyResultV2> => {
        try {
            const shopId = event.pathParameters?.shopId;
            const productId = event.pathParameters?.productId;
            
            if (!shopId || !productId) {
                throw new AppError('MISSING_PARAMS', 'Shop ID and Product ID are required');
            }

            const product = await customerService.getProductDetail(shopId, productId);
            if (!product) {
                return response(404, {
                    success: false,
                    error: 'PRODUCT_NOT_FOUND',
                    message: 'Product not found',
                });
            }

            return response(200, {
                success: true,
                data: product,
            });
        } catch (error: any) {
            logger.error('Get product detail failed', { error: error.message });
            return errorResponse(error);
        }
    },
    { requireAuth: false } // Public endpoint
);

// ---- Order Operations ----

/**
 * GET /api/v1/customer/shop/{shopId}/orders
 * Get customer orders for a shop
 */
export const getOrders = authorizedHandler(
    async (event: APIGatewayProxyEventV2, context: Context): Promise<APIGatewayProxyResultV2> => {
        try {
            const shopId = event.pathParameters?.shopId;
            if (!shopId) {
                throw new AppError('MISSING_SHOP_ID', 'Shop ID is required');
            }

            const auth = (event as any).requestContext?.authorizer?.jwt?.claims;
            const customerId = auth?.sub;
            
            if (!customerId) {
                throw new AppError('UNAUTHORIZED', 'Customer authentication required');
            }

            const query = event.queryStringParameters || {};

            const result = await customerService.getOrders(shopId, customerId, {
                status: query.status,
                page: query.page ? parseInt(query.page) : 1,
                limit: query.limit ? parseInt(query.limit) : 20,
            });

            return response(200, {
                success: true,
                data: result.orders,
                pagination: {
                    page: query.page ? parseInt(query.page) : 1,
                    limit: query.limit ? parseInt(query.limit) : 20,
                    total: result.total,
                },
            });
        } catch (error: any) {
            logger.error('Get orders failed', { error: error.message });
            return errorResponse(error);
        }
    },
    { requireRoles: ['customer'] }
);

/**
 * GET /api/v1/customer/shop/{shopId}/orders/{orderId}
 * Get order details
 */
export const getOrderDetail = authorizedHandler(
    async (event: APIGatewayProxyEventV2, context: Context): Promise<APIGatewayProxyResultV2> => {
        try {
            const shopId = event.pathParameters?.shopId;
            const orderId = event.pathParameters?.orderId;
            
            if (!shopId || !orderId) {
                throw new AppError('MISSING_PARAMS', 'Shop ID and Order ID are required');
            }

            const auth = (event as any).requestContext?.authorizer?.jwt?.claims;
            const customerId = auth?.sub;
            
            if (!customerId) {
                throw new AppError('UNAUTHORIZED', 'Customer authentication required');
            }

            const order = await customerService.getOrderDetail(shopId, customerId, orderId);
            if (!order) {
                return response(404, {
                    success: false,
                    error: 'ORDER_NOT_FOUND',
                    message: 'Order not found',
                });
            }

            return response(200, {
                success: true,
                data: order,
            });
        } catch (error: any) {
            logger.error('Get order detail failed', { error: error.message });
            return errorResponse(error);
        }
    },
    { requireRoles: ['customer'] }
);

// ---- Dashboard ----

/**
 * GET /api/v1/customer/shop/{shopId}/dashboard
 * Get customer dashboard for a shop
 */
export const getDashboard = authorizedHandler(
    async (event: APIGatewayProxyEventV2, context: Context): Promise<APIGatewayProxyResultV2> => {
        try {
            const shopId = event.pathParameters?.shopId;
            if (!shopId) {
                throw new AppError('MISSING_SHOP_ID', 'Shop ID is required');
            }

            const auth = (event as any).requestContext?.authorizer?.jwt?.claims;
            const customerId = auth?.sub;
            
            if (!customerId) {
                throw new AppError('UNAUTHORIZED', 'Customer authentication required');
            }

            // Check if customer is linked to shop
            const isLinked = await customerService.isCustomerLinkedToShop(shopId, customerId);
            if (!isLinked) {
                return response(403, {
                    success: false,
                    error: 'NOT_LINKED',
                    message: 'Customer is not linked to this shop',
                });
            }

            const dashboard = await customerService.getDashboard(shopId, customerId);
            if (!dashboard) {
                return response(404, {
                    success: false,
                    error: 'DASHBOARD_NOT_FOUND',
                    message: 'Dashboard data not available',
                });
            }

            return response(200, {
                success: true,
                data: dashboard,
            });
        } catch (error: any) {
            logger.error('Get dashboard failed', { error: error.message });
            return errorResponse(error);
        }
    },
    { requireRoles: ['customer'] }
);

// ---- Customer-Shop Linking ----

/**
 * POST /api/v1/customer/shop/{shopId}/link
 * Link customer to shop
 */
export const linkCustomerToShop = authorizedHandler(
    async (event: APIGatewayProxyEventV2, context: Context): Promise<APIGatewayProxyResultV2> => {
        try {
            const shopId = event.pathParameters?.shopId;
            if (!shopId) {
                throw new AppError('MISSING_SHOP_ID', 'Shop ID is required');
            }

            const auth = (event as any).requestContext?.authorizer?.jwt?.claims;
            const customerId = auth?.sub;
            
            if (!customerId) {
                throw new AppError('UNAUTHORIZED', 'Customer authentication required');
            }

            const body = JSON.parse(event.body || '{}');

            const success = await customerService.linkCustomerToShop(
                shopId,
                customerId,
                body.metadata
            );

            if (!success) {
                return response(500, {
                    success: false,
                    error: 'LINK_FAILED',
                    message: 'Failed to link customer to shop',
                });
            }

            return response(200, {
                success: true,
                message: 'Customer linked to shop successfully',
            });
        } catch (error: any) {
            logger.error('Link customer to shop failed', { error: error.message });
            return errorResponse(error);
        }
    },
    { requireRoles: ['customer'] }
);

/**
 * DELETE /api/v1/customer/shop/{shopId}/link
 * Unlink customer from shop
 */
export const unlinkCustomerFromShop = authorizedHandler(
    async (event: APIGatewayProxyEventV2, context: Context): Promise<APIGatewayProxyResultV2> => {
        try {
            const shopId = event.pathParameters?.shopId;
            if (!shopId) {
                throw new AppError('MISSING_SHOP_ID', 'Shop ID is required');
            }

            const auth = (event as any).requestContext?.authorizer?.jwt?.claims;
            const customerId = auth?.sub;
            
            if (!customerId) {
                throw new AppError('UNAUTHORIZED', 'Customer authentication required');
            }

            const success = await customerService.unlinkCustomerFromShop(shopId, customerId);

            if (!success) {
                return response(500, {
                    success: false,
                    error: 'UNLINK_FAILED',
                    message: 'Failed to unlink customer from shop',
                });
            }

            return response(200, {
                success: true,
                message: 'Customer unlinked from shop successfully',
            });
        } catch (error: any) {
            logger.error('Unlink customer from shop failed', { error: error.message });
            return errorResponse(error);
        }
    },
    { requireRoles: ['customer'] }
);

// ---- Main Router Handler ----

/**
 * Main customer handler - routes to specific functions
 */
export const handler = authorizedHandler(
    async (event: APIGatewayProxyEventV2, context: Context): Promise<APIGatewayProxyResultV2> => {
        const path = event.rawPath || event.path || '';
        const method = event.requestContext?.http?.method || event.httpMethod || 'GET';

        logger.debug('Customer handler called', { path, method });

        // Route to specific handlers
        if (path.match(/\/shop\/[^/]+$/) && method === 'GET' && !path.includes('/products') && !path.includes('/orders') && !path.includes('/dashboard')) {
            return verifyShop(event, context);
        }
        if (path.includes('/products') && !path.includes('/products/') && method === 'GET') {
            return getProducts(event, context);
        }
        if (path.includes('/products/') && method === 'GET') {
            return getProductDetail(event, context);
        }
        if (path.includes('/orders') && !path.includes('/orders/') && method === 'GET') {
            return getOrders(event, context);
        }
        if (path.includes('/orders/') && method === 'GET') {
            return getOrderDetail(event, context);
        }
        if (path.includes('/dashboard') && method === 'GET') {
            return getDashboard(event, context);
        }
        if (path.includes('/link') && method === 'POST') {
            return linkCustomerToShop(event, context);
        }
        if (path.includes('/link') && method === 'DELETE') {
            return unlinkCustomerFromShop(event, context);
        }

        return response(404, {
            success: false,
            error: 'NOT_FOUND',
            message: 'Customer endpoint not found',
        });
    }
);

// ---- Default Export ----

export default {
    handler,
    verifyShop,
    getProducts,
    getProductDetail,
    getOrders,
    getOrderDetail,
    getDashboard,
    linkCustomerToShop,
    unlinkCustomerFromShop,
};
