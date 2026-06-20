// ============================================================
// Marketplace Cart Handler
// Routes:
//   GET /v1/businesses/{businessId}/cart - Get customer cart
//   POST /v1/businesses/{businessId}/cart/items - Add item to cart
//   PATCH /v1/businesses/{businessId}/cart/items/{itemId} - Update item quantity
//   DELETE /v1/businesses/{businessId}/cart/items/{itemId} - Remove item
//   POST /v1/businesses/{businessId}/cart/coupon - Apply coupon
//   DELETE /v1/businesses/{businessId}/cart/coupon - Remove coupon
//   DELETE /v1/businesses/{businessId}/cart - Clear cart
// ============================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, Handler } from 'aws-lambda';
import { z } from 'zod';
import { 
  CustomerCart, 
  CartItem, 
  MarketplaceProduct,
  Coupon,
  PK, 
  SK,
} from '../../shared/types';
import { authorizeCustomerForBusiness } from '../../shared/auth';
import { isCustomerConnected } from '../../shared/dynamodb';
import { Errors } from '../../shared/errors';
import { success, error } from '../../shared/response';
import { 
  getItem, 
  putItem, 
  deleteItem,
  transactWrite,
} from '../../shared/dynamodb';

// ---------- VALIDATION SCHEMAS ----------

const addItemSchema = z.object({
  productId: z.string().min(1),
  quantity: z.number().int().min(1).max(100),
  // Industry-specific
  prescriptionUrl: z.string().url().optional(),
  cookingInstructions: z.string().max(500).optional(),
  warrantyRequired: z.boolean().optional(),
});

const updateItemSchema = z.object({
  quantity: z.number().int().min(0).max(100),
});

const applyCouponSchema = z.object({
  couponCode: z.string().min(1).max(20),
});

// ---------- ROUTE HANDLERS ----------

export const handler: Handler<APIGatewayProxyEventV2, APIGatewayProxyResultV2> = async (event) => {
  try {
    const method = event.requestContext.http.method;
    const path = event.rawPath || '';

    // Get cart
    if (method === 'GET' && path.endsWith('/cart')) {
      return handleGetCart(event);
    }

    // Add item
    if (method === 'POST' && path.endsWith('/items')) {
      return handleAddItem(event);
    }

    // Update item quantity
    if (method === 'PATCH' && path.includes('/items/') && !path.includes('coupon')) {
      return handleUpdateItem(event);
    }

    // Remove item
    if (method === 'DELETE' && path.includes('/items/') && !path.includes('coupon')) {
      return handleRemoveItem(event);
    }

    // Apply coupon
    if (method === 'POST' && path.endsWith('/coupon')) {
      return handleApplyCoupon(event);
    }

    // Remove coupon
    if (method === 'DELETE' && path.endsWith('/coupon')) {
      return handleRemoveCoupon(event);
    }

    // Clear cart
    if (method === 'DELETE' && path.endsWith('/cart')) {
      return handleClearCart(event);
    }

    return error(Errors.notFound('Route', `${method} ${path}`));
  } catch (err) {
    console.error('Cart handler error:', err);
    return error(err instanceof Error ? err : String(err));
  }
};

// ---------- GET CART ----------

async function handleGetCart(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  const { customerClaims, businessId } = await authorizeCustomerForBusiness(event);
  const customerId = customerClaims.sub;

  // Validate customer is connected to this business
  const connected = await isCustomerConnected(businessId, customerId);
  if (!connected) {
    throw Errors.customerNotConnected(customerId, businessId);
  }

  const cart = await getItem<CustomerCart>(
    PK.business(businessId),
    SK.cart(customerId)
  );

  if (!cart) {
    return success({
      items: [],
      couponCode: null,
      discountAmount: 0,
      subtotal: 0,
      taxAmount: 0,
      deliveryCharge: 0,
      total: 0,
      itemCount: 0,
    });
  }

  // Validate stock availability for each item
  const validatedItems = await validateCartItems(businessId, cart.items);

  return success({
    ...formatCartResponse(cart),
    items: validatedItems.map(formatValidatedItem),
    stockWarnings: validatedItems
      .filter(i => i.stockChanged)
      .map(i => ({
        productId: i.productId,
        name: i.name,
        requested: i.requestedQuantity,
        available: i.stockQuantity,
      })),
  });
}

// ---------- ADD ITEM TO CART ----------

async function handleAddItem(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  const { customerClaims, businessId } = await authorizeCustomerForBusiness(event);
  const customerId = customerClaims.sub;

  // Validate connection
  const connected = await isCustomerConnected(businessId, customerId);
  if (!connected) {
    throw Errors.customerNotConnected(customerId, businessId);
  }

  // Parse and validate
  const body = JSON.parse(event.body || '{}');
  const validated = addItemSchema.parse(body);

  // Get product details and validate stock
  const product = await getItem<MarketplaceProduct>(
    PK.business(businessId),
    SK.product(validated.productId)
  );

  if (!product || !product.isActive || !product.isAvailableForOnline) {
    throw Errors.notFound('Product', validated.productId);
  }

  if (product.stockQuantity < validated.quantity) {
    throw Errors.outOfStock(validated.productId, validated.quantity, product.stockQuantity);
  }

  // Get or create cart
  let cart = await getItem<CustomerCart>(
    PK.business(businessId),
    SK.cart(customerId)
  );

  const now = new Date().toISOString();

  if (!cart) {
    // Create new cart
    cart = {
      PK: PK.business(businessId),
      SK: SK.cart(customerId),
      businessId,
      customerId,
      items: [],
      discountAmount: 0,
      subtotal: 0,
      taxAmount: 0,
      deliveryCharge: 0,
      total: 0,
      lastUpdatedAt: now,
      createdAt: now,
      updatedAt: now,
    };
  }

  // Check if item already exists
  const existingItemIndex = cart.items.findIndex(i => i.productId === validated.productId);

  const itemTotal = product.sellingPrice * validated.quantity;
  const itemGst = Math.round(itemTotal * (product.gstPercent / 100) * 100) / 100;

  const newItem: CartItem = {
    productId: product.productId,
    name: product.name,
    image: product.images[0],
    quantity: validated.quantity,
    unit: product.unit,
    mrp: product.mrp,
    sellingPrice: product.sellingPrice,
    discountPercent: product.discountPercent,
    gstPercent: product.gstPercent,
    itemTotal: itemTotal + itemGst,
    // Industry-specific
    prescriptionUrl: validated.prescriptionUrl,
    cookingInstructions: validated.cookingInstructions,
    warrantyRequired: validated.warrantyRequired,
  };

  if (existingItemIndex >= 0) {
    // Update existing item quantity
    const existing = cart.items[existingItemIndex];
    const newQuantity = existing.quantity + validated.quantity;
    
    if (product.stockQuantity < newQuantity) {
      throw Errors.outOfStock(validated.productId, newQuantity, product.stockQuantity);
    }

    const updatedItemTotal = product.sellingPrice * newQuantity;
    const updatedGst = Math.round(updatedItemTotal * (product.gstPercent / 100) * 100) / 100;

    cart.items[existingItemIndex] = {
      ...existing,
      quantity: newQuantity,
      itemTotal: updatedItemTotal + updatedGst,
      prescriptionUrl: validated.prescriptionUrl || existing.prescriptionUrl,
      cookingInstructions: validated.cookingInstructions || existing.cookingInstructions,
    };
  } else {
    cart.items.push(newItem);
  }

  // Recalculate totals
  recalculateCartTotals(cart);
  cart.lastUpdatedAt = now;
  cart.updatedAt = now;

  await putItem(cart as unknown as Record<string, unknown>);

  return success(formatCartResponse(cart), undefined, 201);
}

// ---------- UPDATE ITEM QUANTITY ----------

async function handleUpdateItem(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  const { customerClaims, businessId } = await authorizeCustomerForBusiness(event);
  const customerId = customerClaims.sub;
  const productId = event.pathParameters?.itemId;

  if (!productId) {
    throw Errors.validation('Item ID (productId) is required');
  }

  const body = JSON.parse(event.body || '{}');
  const { quantity } = updateItemSchema.parse(body);

  const cart = await getItem<CustomerCart>(
    PK.business(businessId),
    SK.cart(customerId)
  );

  if (!cart) {
    throw Errors.notFound('Cart', customerId);
  }

  const itemIndex = cart.items.findIndex(i => i.productId === productId);
  if (itemIndex === -1) {
    throw Errors.notFound('Cart item', productId);
  }

  if (quantity === 0) {
    // Remove item
    cart.items.splice(itemIndex, 1);
  } else {
    // Validate stock
    const product = await getItem<MarketplaceProduct>(
      PK.business(businessId),
      SK.product(productId)
    );

    if (!product || product.stockQuantity < quantity) {
      throw Errors.outOfStock(productId, quantity, product?.stockQuantity || 0);
    }

    // Update quantity
    const item = cart.items[itemIndex];
    const itemTotal = product.sellingPrice * quantity;
    const itemGst = Math.round(itemTotal * (product.gstPercent / 100) * 100) / 100;

    cart.items[itemIndex] = {
      ...item,
      quantity,
      itemTotal: itemTotal + itemGst,
    };
  }

  recalculateCartTotals(cart);
  cart.lastUpdatedAt = new Date().toISOString();
  cart.updatedAt = new Date().toISOString();

  await putItem(cart as unknown as Record<string, unknown>);

  return success(formatCartResponse(cart));
}

// ---------- REMOVE ITEM ----------

async function handleRemoveItem(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  const { customerClaims, businessId } = await authorizeCustomerForBusiness(event);
  const customerId = customerClaims.sub;
  const productId = event.pathParameters?.itemId;

  if (!productId) {
    throw Errors.validation('Item ID is required');
  }

  const cart = await getItem<CustomerCart>(
    PK.business(businessId),
    SK.cart(customerId)
  );

  if (!cart) {
    throw Errors.notFound('Cart', customerId);
  }

  const itemIndex = cart.items.findIndex(i => i.productId === productId);
  if (itemIndex === -1) {
    throw Errors.notFound('Cart item', productId);
  }

  cart.items.splice(itemIndex, 1);

  recalculateCartTotals(cart);
  cart.lastUpdatedAt = new Date().toISOString();
  cart.updatedAt = new Date().toISOString();

  await putItem(cart as unknown as Record<string, unknown>);

  return success(formatCartResponse(cart));
}

// ---------- APPLY COUPON ----------

async function handleApplyCoupon(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  const { customerClaims, businessId } = await authorizeCustomerForBusiness(event);
  const customerId = customerClaims.sub;

  const body = JSON.parse(event.body || '{}');
  const { couponCode } = applyCouponSchema.parse(body);

  const cart = await getItem<CustomerCart>(
    PK.business(businessId),
    SK.cart(customerId)
  );

  if (!cart || cart.items.length === 0) {
    throw Errors.validation('Cart is empty');
  }

  // Validate coupon
  const coupon = await getItem<Coupon>(
    PK.business(businessId),
    SK.coupon(couponCode.toUpperCase())
  );

  if (!coupon || !coupon.isActive) {
    throw Errors.couponInvalid(couponCode);
  }

  const now = new Date().toISOString();
  if (now < coupon.validFrom || now > coupon.validUntil) {
    throw Errors.couponExpired(couponCode);
  }

  if (coupon.usageCount >= coupon.usageLimit) {
    throw Errors.couponInvalid(couponCode);
  }

  if (cart.subtotal < coupon.minOrderValue) {
    throw Errors.minOrderNotMet(coupon.minOrderValue, cart.subtotal);
  }

  // Calculate discount
  let discountAmount = 0;
  if (coupon.type === 'PERCENTAGE') {
    discountAmount = Math.round(cart.subtotal * (coupon.value / 100) * 100) / 100;
    if (coupon.maxDiscount && discountAmount > coupon.maxDiscount) {
      discountAmount = coupon.maxDiscount;
    }
  } else if (coupon.type === 'FIXED') {
    discountAmount = coupon.value;
  }

  // Apply to cart
  cart.couponCode = couponCode.toUpperCase();
  cart.discountAmount = discountAmount;
  recalculateCartTotals(cart);
  cart.updatedAt = now;

  await putItem(cart as unknown as Record<string, unknown>);

  return success(formatCartResponse(cart));
}

// ---------- REMOVE COUPON ----------

async function handleRemoveCoupon(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  const { customerClaims, businessId } = await authorizeCustomerForBusiness(event);
  const customerId = customerClaims.sub;

  const cart = await getItem<CustomerCart>(
    PK.business(businessId),
    SK.cart(customerId)
  );

  if (!cart) {
    throw Errors.notFound('Cart', customerId);
  }

  delete cart.couponCode;
  cart.discountAmount = 0;
  recalculateCartTotals(cart);
  cart.updatedAt = new Date().toISOString();

  await putItem(cart as unknown as Record<string, unknown>);

  return success(formatCartResponse(cart));
}

// ---------- CLEAR CART ----------

async function handleClearCart(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  const { customerClaims, businessId } = await authorizeCustomerForBusiness(event);
  const customerId = customerClaims.sub;

  await deleteItem(
    PK.business(businessId),
    SK.cart(customerId)
  );

  return success({ message: 'Cart cleared successfully' });
}

// ---------- HELPER FUNCTIONS ----------

async function validateCartItems(businessId: string, items: CartItem[]) {
  const validatedItems = [];

  for (const item of items) {
    const product = await getItem<MarketplaceProduct>(
      PK.business(businessId),
      SK.product(item.productId)
    );

    validatedItems.push({
      ...item,
      stockQuantity: product?.stockQuantity || 0,
      stockChanged: product ? product.stockQuantity < item.quantity : true,
      isAvailable: !!(product?.isActive && product?.isAvailableForOnline && product?.stockQuantity > 0),
      requestedQuantity: item.quantity,
    });
  }

  return validatedItems;
}

function recalculateCartTotals(cart: CustomerCart): void {
  // Subtotal = sum of item totals without GST
  cart.subtotal = cart.items.reduce((sum, item) => {
    const itemBasePrice = item.sellingPrice * item.quantity;
    return sum + itemBasePrice;
  }, 0);

  // Tax amount
  cart.taxAmount = cart.items.reduce((sum, item) => {
    const itemBasePrice = item.sellingPrice * item.quantity;
    const itemGst = itemBasePrice * (item.gstPercent / 100);
    return sum + itemGst;
  }, 0);

  // Delivery charge (could be based on business config)
  // For now, free above ₹500, else ₹40
  cart.deliveryCharge = cart.subtotal >= 500 ? 0 : 40;

  // Total
  cart.total = cart.subtotal + cart.taxAmount - cart.discountAmount + cart.deliveryCharge;
}

interface ValidatedCartItem extends CartItem {
  stockQuantity: number;
  stockChanged: boolean;
  isAvailable: boolean;
  requestedQuantity: number;
}

function formatValidatedItem(item: ValidatedCartItem) {
  return {
    productId: item.productId,
    name: item.name,
    image: item.image,
    quantity: item.quantity,
    unit: item.unit,
    mrp: item.mrp,
    sellingPrice: item.sellingPrice,
    discountPercent: item.discountPercent,
    gstPercent: item.gstPercent,
    itemTotal: item.itemTotal,
    isAvailable: item.isAvailable,
    stockQuantity: item.stockQuantity,
    // Industry-specific
    prescriptionUrl: item.prescriptionUrl,
    cookingInstructions: item.cookingInstructions,
    warrantyRequired: item.warrantyRequired,
  };
}

function formatCartResponse(cart: CustomerCart, validatedItems?: ValidatedCartItem[]) {
  const items = validatedItems 
    ? validatedItems.map(formatValidatedItem)
    : cart.items.map(item => ({
        productId: item.productId,
        name: item.name,
        image: item.image,
        quantity: item.quantity,
        unit: item.unit,
        mrp: item.mrp,
        sellingPrice: item.sellingPrice,
        discountPercent: item.discountPercent,
        gstPercent: item.gstPercent,
        itemTotal: item.itemTotal,
        isAvailable: true,
        stockQuantity: null as unknown as number,
        prescriptionUrl: item.prescriptionUrl,
        cookingInstructions: item.cookingInstructions,
        warrantyRequired: item.warrantyRequired,
      }));

  return {
    items,
    couponCode: cart.couponCode,
    discountAmount: cart.discountAmount,
    subtotal: cart.subtotal,
    taxAmount: cart.taxAmount,
    deliveryCharge: cart.deliveryCharge,
    total: cart.total,
    itemCount: cart.items.reduce((sum, i) => sum + i.quantity, 0),
    lastUpdatedAt: cart.lastUpdatedAt,
  };
}
