/**
 * Product DynamoDB schema helpers
 * Single-table design with GSI for product queries
 */

import { Product } from '../types/product.types';
import { v4 as uuidv4 } from 'uuid';

/**
 * DynamoDB key structure for products:
 * PK: TENANT#{tenantId}#PRODUCT#{businessType}#{productId}
 * SK: PRODUCT#{createdAt}#{productId}
 * 
 * GSI (for queries):
 * GSI1PK: TENANT#{tenantId}#PRODUCT#{businessType}
 * GSI1SK: NAME#{name}#{productId}
 * 
 * GSI2 (for barcode lookup):
 * GSI2PK: TENANT#{tenantId}#BARCODE
 * GSI2SK: BARCODE#{barcode}#{productId}
 * 
 * GSI3 (for product search):
 * GSI3PK: TENANT#{tenantId}#PRODUCT#{businessType}#{category}
 * GSI3SK: UPDATED#{updatedAt}#{productId}
 */

export const ProductKeys = {
  pk: (tenantId: string, businessType: string, productId: string) =>
    `TENANT#${tenantId}#PRODUCT#${businessType}#${productId}`,
  
  sk: (createdAt: number, productId: string) =>
    `PRODUCT#${createdAt}#${productId}`,
  
  // GSI1: List all products for a business type
  gsi1pk: (tenantId: string, businessType: string) =>
    `TENANT#${tenantId}#PRODUCT#${businessType}`,
  
  gsi1sk: (name: string, productId: string) =>
    `NAME#${name}#${productId}`,
  
  // GSI2: Barcode lookup
  gsi2pk: (tenantId: string) =>
    `TENANT#${tenantId}#BARCODE`,
  
  gsi2sk: (barcode: string, productId: string) =>
    `BARCODE#${barcode}#${productId}`,
  
  // GSI3: Category/date sorting
  gsi3pk: (tenantId: string, businessType: string, category: string) =>
    `TENANT#${tenantId}#PRODUCT#${businessType}#${category || 'UNCATEGORIZED'}`,
  
  gsi3sk: (updatedAt: number, productId: string) =>
    `UPDATED#${updatedAt}#${productId}`,
};

export const createProductItem = (
  tenantId: string,
  businessType: string,
  product: Partial<Product>
): any => {
  const productId = product.id || uuidv4();
  const now = Date.now();
  
  return {
    PK: ProductKeys.pk(tenantId, businessType, productId),
    SK: ProductKeys.sk(now, productId),
    
    // GSI keys
    GSI1PK: ProductKeys.gsi1pk(tenantId, businessType),
    GSI1SK: ProductKeys.gsi1sk(product.name || 'UNNAMED', productId),
    
    GSI2PK: product.barcode ? ProductKeys.gsi2pk(tenantId) : undefined,
    GSI2SK: product.barcode ? ProductKeys.gsi2sk(product.barcode, productId) : undefined,
    
    GSI3PK: ProductKeys.gsi3pk(tenantId, businessType, product.category || ''),
    GSI3SK: ProductKeys.gsi3sk(now, productId),
    
    // Entity type
    entityType: 'PRODUCT',
    
    // Product data
    productId,
    tenantId,
    businessType,
    name: product.name,
    description: product.description,
    category: product.category,
    brand: product.brand,
    
    // Pricing
    price: product.price,
    mrp: product.mrp,
    cost: product.cost,
    gstRate: product.gstRate || 0,
    hsn: product.hsn,
    
    // Identifiers
    barcode: product.barcode,
    sku: product.sku,
    
    // Pharmacy-specific
    batchNo: product.batchNo,
    expiryDate: product.expiryDate,
    drugSchedule: product.drugSchedule,
    strength: product.strength,
    formulation: product.formulation,
    manufacturer: product.manufacturer,
    
    // Stock
    stock: product.stock || 0,
    reorderLevel: product.reorderLevel,
    maxStock: product.maxStock,
    unit: product.unit,
    
    // Images
    mainImage: product.mainImage,
    images: product.images,
    
    // Variants
    variants: product.variants,
    
    // Flags
    isActive: product.isActive !== false,
    synced: false,
    
    // Timestamps
    createdAt: product.createdAt || now,
    updatedAt: product.updatedAt || now,
    createdBy: product.createdBy,
    updatedBy: product.updatedBy,
    
    // Versioning
    version: 1,
    
    // TTL (optional: auto-delete old synced items after 90 days)
    expiresAt: Math.floor(now / 1000) + 7776000, // 90 days
  };
};

export const mapDynamoProductToEntity = (item: any): Product => {
  return {
    id: item.productId,
    tenantId: item.tenantId,
    businessType: item.businessType,
    name: item.name,
    description: item.description,
    category: item.category,
    brand: item.brand,
    price: item.price,
    mrp: item.mrp,
    cost: item.cost,
    gstRate: item.gstRate,
    hsn: item.hsn,
    barcode: item.barcode,
    sku: item.sku,
    batchNo: item.batchNo,
    expiryDate: item.expiryDate,
    drugSchedule: item.drugSchedule,
    strength: item.strength,
    formulation: item.formulation,
    manufacturer: item.manufacturer,
    stock: item.stock,
    reorderLevel: item.reorderLevel,
    maxStock: item.maxStock,
    unit: item.unit,
    mainImage: item.mainImage,
    images: item.images,
    variants: item.variants,
    isActive: item.isActive,
    createdAt: item.createdAt,
    updatedAt: item.updatedAt,
    createdBy: item.createdBy,
    updatedBy: item.updatedBy,
    synced: item.synced,
    version: item.version,
  };
};
