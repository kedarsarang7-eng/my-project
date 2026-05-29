/**
 * Product types and interfaces for Pharmacy and other business types
 * Supports S3-based image storage with presigned URLs
 */

export interface ProductImage {
  s3Key: string; // e.g., products/pharmacy/UUID-original.jpg
  s3ThumbnailKey: string; // e.g., products/pharmacy/UUID-thumb.jpg
  uploadedAt: number; // Unix timestamp
  fileSize: number; // bytes
}

export interface ProductVariant {
  id: string; // UUID
  name: string; // e.g., "500mg", "100ml"
  sku?: string;
  price: number;
  stock?: number;
  strength?: string; // For medicines: "500mg", "10%", etc.
}

export interface Product {
  // Core identifiers
  id: string; // UUID
  tenantId: string;
  businessType: string; // "pharmacy", "restaurant", etc.
  
  // Product metadata
  name: string;
  description?: string;
  category?: string; // e.g., "Antibiotics", "Pain Relief"
  brand?: string;
  
  // Image data (S3-backed)
  mainImage?: ProductImage;
  images?: ProductImage[]; // Additional images
  
  // Product specifications
  price: number;
  mrp?: number; // Maximum Retail Price (pharmacy)
  cost?: number; // Cost price (internal)
  gstRate: number; // GST %
  hsn?: string; // HSN code
  
  // Barcode / identifiers
  barcode?: string; // EAN/UPC/barcode
  sku?: string; // Stock Keeping Unit
  
  // Pharmacy-specific fields
  batchNo?: string;
  expiryDate?: number; // Unix timestamp
  drugSchedule?: string; // "H", "X", "L", etc.
  strength?: string; // e.g., "500mg"
  formulation?: string; // e.g., "Tablet", "Syrup", "Injectable"
  manufacturer?: string;
  
  // Stock & variants
  stock: number;
  reorderLevel?: number; // Alert when stock falls below
  maxStock?: number;
  unit?: string; // "pcs", "strip", "ml", "box"
  variants?: ProductVariant[]; // Different strengths/sizes
  
  // Metadata
  isActive: boolean;
  createdAt: number; // Unix timestamp
  updatedAt: number;
  createdBy: string; // User ID
  updatedBy: string;
  
  // Sync tracking
  synced?: boolean;
  lastSyncedAt?: number;
  version?: number;
}

export interface CreateProductDTO {
  name: string;
  description?: string;
  category?: string;
  brand?: string;
  price: number;
  mrp?: number;
  cost?: number;
  gstRate: number;
  hsn?: string;
  barcode?: string;
  sku?: string;
  batchNo?: string;
  expiryDate?: number;
  drugSchedule?: string;
  strength?: string;
  formulation?: string;
  manufacturer?: string;
  stock: number;
  reorderLevel?: number;
  maxStock?: number;
  unit?: string;
  variants?: ProductVariant[];
}

export interface UpdateProductDTO {
  name?: string;
  description?: string;
  category?: string;
  brand?: string;
  price?: number;
  mrp?: number;
  cost?: number;
  gstRate?: number;
  hsn?: string;
  barcode?: string;
  sku?: string;
  batchNo?: string;
  expiryDate?: number;
  drugSchedule?: string;
  strength?: string;
  formulation?: string;
  manufacturer?: string;
  stock?: number;
  reorderLevel?: number;
  maxStock?: number;
  unit?: string;
  variants?: ProductVariant[];
  isActive?: boolean;
}

export interface ProductFilters {
  category?: string;
  brand?: string;
  minPrice?: number;
  maxPrice?: number;
  inStock?: boolean;
  searchTerm?: string;
  barcode?: string;
  drugSchedule?: string; // Pharmacy filter
  expiringSoon?: boolean; // Pharmacy: within 3 months
}

export interface ProductQuery {
  page?: number;
  limit?: number;
  sortBy?: 'name' | 'price' | 'stock' | 'createdAt' | 'updatedAt';
  sortOrder?: 'asc' | 'desc';
  filters?: ProductFilters;
}

export interface ProductResponse {
  product: Product;
  presignedImageUrl?: string; // Short-lived signed URL for main image
  presignedThumbUrl?: string; // Short-lived signed URL for thumbnail
}

export interface ProductListResponse {
  items: ProductResponse[];
  total: number;
  page: number;
  limit: number;
  hasMore: boolean;
}

export interface ImageUploadRequest {
  originalFileName: string;
  fileType: string; // mime type: image/jpeg, image/png
  fileSize: number;
}

export interface ImageUploadResponse {
  uploadUrl: string; // Presigned URL for PUT
  s3Key: string;
  s3ThumbnailKey: string;
  expiresIn: number; // seconds
}
