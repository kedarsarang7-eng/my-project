// ============================================================
// Dukan Marketplace - Shared Types
// Strict TypeScript types for all marketplace entities
// ============================================================

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';

// ---------- BASE TYPES ----------

export type BusinessCategory = 
  | 'grocery' 
  | 'hardware' 
  | 'pharmacy' 
  | 'restaurant' 
  | 'mobile_shop' 
  | 'computer_shop';

export type OrderStatus = 
  | 'PLACED'
  | 'ACCEPTED'
  | 'REJECTED'
  | 'PREPARING'
  | 'READY_FOR_DISPATCH'
  | 'OUT_FOR_DELIVERY'
  | 'DELIVERED'
  | 'CANCELLED';

export type PaymentMethod = 'COD' | 'ONLINE' | 'WALLET';
export type PaymentStatus = 'PENDING' | 'COMPLETED' | 'FAILED' | 'REFUNDED';

// ---------- DYNAMODB KEY DESIGN ----------
// PK = BUSINESS#<businessId>
// SK patterns documented below

export interface BaseEntity {
  PK: string; // BUSINESS#<businessId>
  SK: string;
  createdAt: string;
  updatedAt: string;
  GSI1PK?: string;
  GSI1SK?: string;
  GSI2PK?: string;
  GSI2SK?: string;
}

// Customer-Business Connection
// PK: BUSINESS#<bizId>, SK: CONNECTION#<custId>
export interface CustomerConnection extends BaseEntity {
  businessId: string;
  customerId: string;
  customerName: string;
  customerPhone: string;
  status: 'active' | 'blocked';
  connectedAt: string;
  lastOrderAt?: string;
  totalOrders: number;
  totalSpent: number;
  GSI1PK: string; // CUSTOMER#<custId>
  GSI1SK: string; // CONNECTION#<bizId>
}

// Product Catalog (mirrors billing software product)
// PK: BUSINESS#<bizId>, SK: PRODUCT#<productId>
export interface MarketplaceProduct extends BaseEntity {
  businessId: string;
  productId: string;
  name: string;
  description?: string;
  category: string;
  subcategory?: string;
  brand?: string;
  mrp: number;
  sellingPrice: number;
  discountPercent: number;
  stockQuantity: number;
  unit: string;
  images: string[]; // S3 keys
  isActive: boolean;
  isAvailableForOnline: boolean;
  barcode?: string;
  hsnCode?: string;
  gstPercent: number;
  // Industry-specific
  expiryDate?: string; // Pharmacy
  drugSchedule?: string; // Pharmacy
  comboProducts?: string[]; // Restaurant
  specAttributes?: Record<string, string>; // Hardware
  warrantyMonths?: number; // Electronics
  GSI1PK: string; // CATEGORY#<category>
  GSI1SK: string; // PRODUCT#<productId>
  GSI2PK?: string; // BRAND#<brand>
  GSI2SK?: string; // PRODUCT#<productId>
}

// Customer Cart
// PK: BUSINESS#<bizId>, SK: CART#<custId>
export interface CustomerCart extends BaseEntity {
  businessId: string;
  customerId: string;
  items: CartItem[];
  couponCode?: string;
  discountAmount: number;
  subtotal: number;
  taxAmount: number;
  deliveryCharge: number;
  total: number;
  lastUpdatedAt: string;
}

export interface CartItem {
  productId: string;
  name: string;
  image?: string;
  quantity: number;
  unit: string;
  mrp: number;
  sellingPrice: number;
  discountPercent: number;
  gstPercent: number;
  itemTotal: number;
  // Industry-specific
  prescriptionUrl?: string; // Pharmacy
  cookingInstructions?: string; // Restaurant
  warrantyRequired?: boolean; // Electronics
}

// Order
// PK: BUSINESS#<bizId>, SK: ORDER#<orderId>#CUSTOMER#<custId>
export interface Order extends BaseEntity {
  businessId: string;
  orderId: string;
  customerId: string;
  customerName: string;
  customerPhone: string;
  status: OrderStatus;
  items: OrderItem[];
  paymentMethod: PaymentMethod;
  paymentStatus: PaymentStatus;
  couponCode?: string;
  discountAmount: number;
  subtotal: number;
  taxAmount: number;
  deliveryCharge: number;
  total: number;
  deliveryAddress: DeliveryAddress;
  scheduledFor?: string; // Scheduled delivery
  isExpress: boolean;
  prescriptionUrl?: string; // Pharmacy orders
  notes?: string;
  timeline: OrderTimelineEvent[];
  assignedDeliveryPartnerId?: string;
  estimatedDeliveryTime?: string;
  GSI1PK: string; // ORDER#STATUS#<status>
  GSI1SK: string; // BUSINESS#<bizId>#TIME#<timestamp>
  GSI2PK: string; // CUSTOMER#<custId>
  GSI2SK: string; // ORDER#<orderId>
}

export interface OrderItem extends CartItem {
  deliveredQuantity?: number;
  returnReason?: string;
}

export interface DeliveryAddress {
  id: string;
  label: string; // Home, Work, etc.
  addressLine1: string;
  addressLine2?: string;
  landmark?: string;
  city: string;
  state: string;
  pincode: string;
  contactName: string;
  contactPhone: string;
  location?: { lat: number; lng: number };
}

export interface OrderTimelineEvent {
  status: OrderStatus;
  timestamp: string;
  note?: string;
  updatedBy: string; // userId or 'system'
}

// Customer Address Book
// PK: BUSINESS#<bizId>, SK: ADDRESS#<custId>#<addressId>
export interface CustomerAddress extends BaseEntity {
  businessId: string;
  customerId: string;
  addressId: string;
  label: string;
  isDefault: boolean;
  addressLine1: string;
  addressLine2?: string;
  landmark?: string;
  city: string;
  state: string;
  pincode: string;
  contactName: string;
  contactPhone: string;
  location?: { lat: number; lng: number };
  GSI1PK: string; // CUSTOMER#<custId>
  GSI1SK: string; // ADDRESS#<addressId>
}

// Loyalty Points
// PK: BUSINESS#<bizId>, SK: LOYALTY#<custId>
export interface LoyaltyAccount extends BaseEntity {
  businessId: string;
  customerId: string;
  totalPoints: number;
  redeemedPoints: number;
  availablePoints: number;
  tier: 'BRONZE' | 'SILVER' | 'GOLD' | 'PLATINUM';
  transactions: LoyaltyTransaction[];
  membershipExpiry?: string;
}

export interface LoyaltyTransaction {
  id: string;
  type: 'EARNED' | 'REDEEMED' | 'BONUS' | 'EXPIRED';
  points: number;
  orderId?: string;
  description: string;
  timestamp: string;
}

// Coupon/Discount
// PK: BUSINESS#<bizId>, SK: COUPON#<couponCode>
export interface Coupon extends BaseEntity {
  businessId: string;
  couponCode: string;
  type: 'PERCENTAGE' | 'FIXED' | 'CASHBACK';
  value: number;
  minOrderValue: number;
  maxDiscount?: number;
  usageLimit: number;
  usageCount: number;
  validFrom: string;
  validUntil: string;
  applicableCategories?: string[];
  applicableProducts?: string[];
  isActive: boolean;
  GSI1PK?: string; // COUPON#ACTIVE or COUPON#EXPIRED
  GSI1SK?: string; // BUSINESS#<bizId>
}

// Product Review
// PK: BUSINESS#<bizId>, SK: REVIEW#<productId>#<reviewId>
export interface ProductReview extends BaseEntity {
  businessId: string;
  productId: string;
  reviewId: string;
  customerId: string;
  customerName: string;
  orderId: string;
  rating: number; // 1-5
  title?: string;
  comment?: string;
  images?: string[];
  isVerifiedPurchase: boolean;
  helpfulCount: number;
  response?: {
    message: string;
    respondedAt: string;
    respondedBy: string;
  };
  GSI1PK: string; // PRODUCT#<productId>
  GSI1SK: string; // REVIEW#<timestamp>
  GSI2PK: string; // CUSTOMER#<custId>
  GSI2SK: string; // REVIEW#<reviewId>
}

// WebSocket Connection
// PK: CONNECTION#<connectionId>, SK: METADATA
export interface WebSocketConnection extends BaseEntity {
  connectionId: string;
  businessId: string;
  userId: string;
  userType: 'business' | 'customer';
  customerId?: string;
  connectedAt: string;
  lastPingAt: string;
  GSI1PK: string; // BUSINESS#<bizId>
  GSI1SK: string; // CONNECTION#<connectionId>
}

// Delivery Partner
// PK: BUSINESS#<bizId>, SK: DELIVERY#PARTNER#<partnerId>
export interface DeliveryPartner extends BaseEntity {
  businessId: string;
  partnerId: string;
  name: string;
  phone: string;
  email?: string;
  vehicleType: 'BIKE' | 'SCOOTER' | 'VAN';
  vehicleNumber?: string;
  isActive: boolean;
  currentLocation?: { lat: number; lng: number; updatedAt: string };
  assignedOrders: string[];
  totalDeliveries: number;
  rating: number;
  GSI1PK?: string; // DELIVERY#ACTIVE or DELIVERY#INACTIVE
  GSI1SK?: string; // BUSINESS#<bizId>
}

// ---------- API RESPONSE TYPES ----------

export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  error?: {
    code: string;
    message: string;
    details?: unknown;
  };
  meta?: {
    page?: number;
    limit?: number;
    total?: number;
    hasMore?: boolean;
  };
}

export type LambdaHandler = (
  event: APIGatewayProxyEventV2
) => Promise<APIGatewayProxyResultV2>;

// ---------- JWT CLAIMS ----------

export interface BusinessTokenClaims {
  sub: string; // userId
  businessId: string;
  email: string;
  'cognito:groups': string[];
  userType: 'business';
}

export interface CustomerTokenClaims {
  sub: string; // customerId
  phone: string;
  email?: string;
  userType: 'customer';
}

export type TokenClaims = BusinessTokenClaims | CustomerTokenClaims;

// ---------- WEBSOCKET EVENT TYPES ----------

export type WebSocketEventType = 
  | 'ORDER_UPDATE'
  | 'INVENTORY_SYNC'
  | 'STOCK_LOW'
  | 'DELIVERY_TRACKING'
  | 'PROMOTION'
  | 'SYSTEM';

export interface WebSocketMessage {
  type: WebSocketEventType;
  timestamp: string;
  businessId: string;
  targetRoom: string;
  payload: unknown;
}

export interface OrderUpdatePayload {
  orderId: string;
  customerId: string;
  status: OrderStatus;
  previousStatus: OrderStatus;
  message: string;
  estimatedTime?: string;
  timestamp: string;
}

export interface InventorySyncPayload {
  productId: string;
  stockQuantity: number;
  sellingPrice?: number;
  isAvailable?: boolean;
  updatedAt: string;
}

// ---------- VALIDATION SCHEMAS (Zod) ----------

export const orderStatusTransitions: Record<OrderStatus, OrderStatus[]> = {
  PLACED: ['ACCEPTED', 'REJECTED', 'CANCELLED'],
  ACCEPTED: ['PREPARING', 'CANCELLED'],
  REJECTED: [],
  PREPARING: ['READY_FOR_DISPATCH', 'CANCELLED'],
  READY_FOR_DISPATCH: ['OUT_FOR_DELIVERY'],
  OUT_FOR_DELIVERY: ['DELIVERED', 'CANCELLED'],
  DELIVERED: [],
  CANCELLED: [],
};

// ---------- ERROR CODES ----------

export const ErrorCodes = {
  // Auth
  UNAUTHORIZED: 'UNAUTHORIZED',
  FORBIDDEN: 'FORBIDDEN',
  TOKEN_EXPIRED: 'TOKEN_EXPIRED',
  
  // Data Isolation
  BUSINESS_MISMATCH: 'BUSINESS_MISMATCH',
  CUSTOMER_NOT_CONNECTED: 'CUSTOMER_NOT_CONNECTED',
  
  // Business Logic
  INVALID_STATUS_TRANSITION: 'INVALID_STATUS_TRANSITION',
  OUT_OF_STOCK: 'OUT_OF_STOCK',
  PAYMENT_REQUIRED: 'PAYMENT_REQUIRED',
  PRESCRIPTION_REQUIRED: 'PRESCRIPTION_REQUIRED',
  COUPON_INVALID: 'COUPON_INVALID',
  COUPON_EXPIRED: 'COUPON_EXPIRED',
  MIN_ORDER_NOT_MET: 'MIN_ORDER_NOT_MET',
  
  // Resources
  NOT_FOUND: 'NOT_FOUND',
  ALREADY_EXISTS: 'ALREADY_EXISTS',
  
  // System
  VALIDATION_ERROR: 'VALIDATION_ERROR',
  INTERNAL_ERROR: 'INTERNAL_ERROR',
} as const;

// ---------- UTILITIES ----------

export const PK = {
  business: (businessId: string) => `BUSINESS#${businessId}`,
  connection: (connectionId: string) => `CONNECTION#${connectionId}`,
};

export const SK = {
  connection: (customerId: string) => `CONNECTION#${customerId}`,
  product: (productId: string) => `PRODUCT#${productId}`,
  cart: (customerId: string) => `CART#${customerId}`,
  order: (orderId: string, customerId: string) => `ORDER#${orderId}#CUSTOMER#${customerId}`,
  address: (customerId: string, addressId: string) => `ADDRESS#${customerId}#${addressId}`,
  loyalty: (customerId: string) => `LOYALTY#${customerId}`,
  coupon: (couponCode: string) => `COUPON#${couponCode}`,
  review: (productId: string, reviewId: string) => `REVIEW#${productId}#${reviewId}`,
  deliveryPartner: (partnerId: string) => `DELIVERY#PARTNER#${partnerId}`,
  metadata: () => 'METADATA',
};

export const GSI1PK = {
  customer: (customerId: string) => `CUSTOMER#${customerId}`,
  category: (category: string) => `CATEGORY#${category}`,
  orderStatus: (status: OrderStatus) => `ORDER#STATUS#${status}`,
  product: (productId: string) => `PRODUCT#${productId}`,
  couponActive: () => 'COUPON#ACTIVE',
  couponExpired: () => 'COUPON#EXPIRED',
  deliveryActive: () => 'DELIVERY#ACTIVE',
  deliveryInactive: () => 'DELIVERY#INACTIVE',
};

export const GSI1SK = {
  connection: (businessId: string) => `CONNECTION#${businessId}`,
  product: (productId: string) => `PRODUCT#${productId}`,
  order: (businessId: string, timestamp: string) => `BUSINESS#${businessId}#TIME#${timestamp}`,
  address: (addressId: string) => `ADDRESS#${addressId}`,
  review: (timestamp: string) => `REVIEW#${timestamp}`,
  business: (businessId: string) => `BUSINESS#${businessId}`,
};

export const GSI2PK = {
  brand: (brand: string) => `BRAND#${brand}`,
  customer: (customerId: string) => `CUSTOMER#${customerId}`,
};

export const GSI2SK = {
  product: (productId: string) => `PRODUCT#${productId}`,
  review: (reviewId: string) => `REVIEW#${reviewId}`,
};
