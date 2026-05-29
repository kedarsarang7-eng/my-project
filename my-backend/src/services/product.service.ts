/**
 * Product Service - CRUD and query operations
 * Handles product management, search, and image coordination
 */

import { DynamoDBClient, QueryCommand, PutItemCommand, UpdateItemCommand, DeleteItemCommand, GetItemCommand, ScanCommand } from '@aws-sdk/client-dynamodb';
import { marshall, unmarshall } from '@aws-sdk/util-dynamodb';
import {
  Product,
  CreateProductDTO,
  UpdateProductDTO,
  ProductFilters,
  ProductListResponse,
  ProductResponse,
} from '../types/product.types';
import { ProductKeys, createProductItem, mapDynamoProductToEntity } from '../schemas/product.schema';
import { StorageService } from './storage.service';
import { v4 as uuidv4 } from 'uuid';
import { config } from '../config/environment';

const TABLE_NAME = config.dynamodb.tableName;
const client = new DynamoDBClient({ region: config.aws.region });
const storageService = new StorageService();

export class ProductService {
  /**
   * Create a new product with S3 image coordination
   */
  static async createProduct(
    tenantId: string,
    businessType: string,
    userId: string,
    dto: CreateProductDTO
  ): Promise<Product> {
    const productId = uuidv4();
    const now = Date.now();
    
    const productItem = createProductItem(tenantId, businessType, {
      id: productId,
      ...dto,
      createdAt: now,
      updatedAt: now,
      createdBy: userId,
      updatedBy: userId,
    });
    
    const command = new PutItemCommand({
      TableName: TABLE_NAME,
      Item: marshall(productItem),
      ConditionExpression: 'attribute_not_exists(PK)', // Ensure no duplicate
    });
    
    try {
      await client.send(command);
      return mapDynamoProductToEntity(productItem);
    } catch (error: any) {
      console.error('Error creating product:', error);
      throw new Error(`Failed to create product: ${error.message}`);
    }
  }

  /**
   * Get product by ID with presigned image URLs
   */
  static async getProduct(
    tenantId: string,
    businessType: string,
    productId: string
  ): Promise<ProductResponse | null> {
    const command = new GetItemCommand({
      TableName: TABLE_NAME,
      Key: marshall({
        PK: ProductKeys.pk(tenantId, businessType, productId),
        SK: '', // SK will be queried, but GetCommand requires exact SK
      }),
    });
    
    // Since we don't have exact SK, we query instead
    return this.queryProductById(tenantId, businessType, productId);
  }

  /**
   * Query product by ID (finds via GSI1)
   */
  static async queryProductById(
    tenantId: string,
    businessType: string,
    productId: string
  ): Promise<ProductResponse | null> {
    const command = new QueryCommand({
      TableName: TABLE_NAME,
      IndexName: 'GSI1', // Query by business type + product name
      KeyConditionExpression: 'GSI1PK = :gsi1pk AND begins_with(GSI1SK, :productId)',
      ExpressionAttributeValues: marshall({
        ':gsi1pk': ProductKeys.gsi1pk(tenantId, businessType),
        ':productId': productId,
      }),
      Limit: 1,
    });
    
    try {
      const result = await client.send(command);
      if (!result.Items || result.Items.length === 0) {
        return null;
      }
      
      const product = mapDynamoProductToEntity(unmarshall(result.Items[0]));
      return await this.enrichProductWithPresignedUrls(product);
    } catch (error: any) {
      console.error('Error querying product:', error);
      throw new Error(`Failed to query product: ${error.message}`);
    }
  }

  /**
   * Update product by ID
   */
  static async updateProduct(
    tenantId: string,
    businessType: string,
    productId: string,
    userId: string,
    dto: UpdateProductDTO
  ): Promise<Product> {
    const now = Date.now();
    const updateExpressions: string[] = [];
    const expressionAttributeValues: Record<string, any> = {
      ':now': now,
      ':userId': userId,
      ':version': 1, // Will increment from current
    };
    
    // Build dynamic update expression
    if (dto.name !== undefined) {
      updateExpressions.push('#name = :name');
      expressionAttributeValues[':name'] = dto.name;
    }
    if (dto.price !== undefined) {
      updateExpressions.push('price = :price');
      expressionAttributeValues[':price'] = dto.price;
    }
    if (dto.stock !== undefined) {
      updateExpressions.push('stock = :stock');
      expressionAttributeValues[':stock'] = dto.stock;
    }
    if (dto.description !== undefined) {
      updateExpressions.push('description = :description');
      expressionAttributeValues[':description'] = dto.description;
    }
    if (dto.category !== undefined) {
      updateExpressions.push('category = :category');
      expressionAttributeValues[':category'] = dto.category;
    }
    if (dto.batchNo !== undefined) {
      updateExpressions.push('batchNo = :batchNo');
      expressionAttributeValues[':batchNo'] = dto.batchNo;
    }
    if (dto.expiryDate !== undefined) {
      updateExpressions.push('expiryDate = :expiryDate');
      expressionAttributeValues[':expiryDate'] = dto.expiryDate;
    }
    if (dto.barcode !== undefined) {
      updateExpressions.push('barcode = :barcode');
      expressionAttributeValues[':barcode'] = dto.barcode;
    }
    
    // Always update metadata
    updateExpressions.push('updatedAt = :now', 'updatedBy = :userId', 'version = version + :version');
    
    // Build actual PK/SK from product
    let pk = '';
    let sk = '';
    
    // Query to get existing item for exact SK
    const queryCmd = new QueryCommand({
      TableName: TABLE_NAME,
      KeyConditionExpression: 'begins_with(PK, :pkPrefix)',
      ExpressionAttributeValues: marshall({
        ':pkPrefix': `TENANT#${tenantId}#PRODUCT#${businessType}#${productId}`,
      }),
      Limit: 1,
      ProjectionExpression: 'PK, SK',
    });
    
    try {
      const queryResult = await client.send(queryCmd);
      if (!queryResult.Items || queryResult.Items.length === 0) {
        throw new Error('Product not found');
      }
      
      const item = unmarshall(queryResult.Items[0]);
      pk = item.PK;
      sk = item.SK;
      
      // Now update
      const updateCmd = new UpdateItemCommand({
        TableName: TABLE_NAME,
        Key: marshall({ PK: pk, SK: sk }),
        UpdateExpression: `SET ${updateExpressions.join(', ')}`,
        ExpressionAttributeNames: {
          '#name': 'name', // Escape reserved word
        },
        ExpressionAttributeValues: marshall(expressionAttributeValues),
        ReturnValues: 'ALL_NEW',
      });
      
      const result = await client.send(updateCmd);
      return mapDynamoProductToEntity(unmarshall((result.Attributes as any) || {}));
    } catch (error: any) {
      console.error('Error updating product:', error);
      throw new Error(`Failed to update product: ${error.message}`);
    }
  }

  /**
   * Delete product by ID
   */
  static async deleteProduct(
    tenantId: string,
    businessType: string,
    productId: string
  ): Promise<void> {
    try {
      // Query to get exact SK
      const queryCmd = new QueryCommand({
        TableName: TABLE_NAME,
        KeyConditionExpression: 'begins_with(PK, :pkPrefix)',
        ExpressionAttributeValues: marshall({
          ':pkPrefix': `TENANT#${tenantId}#PRODUCT#${businessType}#${productId}`,
        }),
        Limit: 1,
        ProjectionExpression: 'PK, SK',
      });
      
      const queryResult = await client.send(queryCmd);
      if (!queryResult.Items || queryResult.Items.length === 0) {
        throw new Error('Product not found');
      }
      
      const item = unmarshall(queryResult.Items[0]);
      
      // Delete
      const deleteCmd = new DeleteItemCommand({
        TableName: TABLE_NAME,
        Key: marshall({ PK: item.PK, SK: item.SK }),
      });
      
      await client.send(deleteCmd);
    } catch (error: any) {
      console.error('Error deleting product:', error);
      throw new Error(`Failed to delete product: ${error.message}`);
    }
  }

  /**
   * List products with filtering and pagination
   */
  static async listProducts(
    tenantId: string,
    businessType: string,
    filters?: ProductFilters,
    page: number = 1,
    limit: number = 20
  ): Promise<ProductListResponse> {
    const offset = (page - 1) * limit;
    
    // Query GSI1 for business type + category
    const keyConditionExpression = 'GSI1PK = :gsi1pk';
    const expressionAttributeValues: Record<string, any> = {
      ':gsi1pk': ProductKeys.gsi1pk(tenantId, businessType),
    };
    
    let filterExpression = '';
    
    if (filters?.category) {
      filterExpression = 'category = :category';
      expressionAttributeValues[':category'] = filters.category;
    }
    
    if (filters?.searchTerm) {
      filterExpression += (filterExpression ? ' AND ' : '') + 'contains(#name, :searchTerm)';
      expressionAttributeValues[':searchTerm'] = filters.searchTerm.toLowerCase();
    }
    
    if (filters?.minPrice !== undefined || filters?.maxPrice !== undefined) {
      if (filters.minPrice !== undefined) {
        filterExpression += (filterExpression ? ' AND ' : '') + 'price >= :minPrice';
        expressionAttributeValues[':minPrice'] = filters.minPrice;
      }
      if (filters.maxPrice !== undefined) {
        filterExpression += (filterExpression ? ' AND ' : '') + 'price <= :maxPrice';
        expressionAttributeValues[':maxPrice'] = filters.maxPrice;
      }
    }
    
    if (filters?.inStock) {
      filterExpression += (filterExpression ? ' AND ' : '') + 'stock > :zero';
      expressionAttributeValues[':zero'] = 0;
    }
    
    try {
      const command = new QueryCommand({
        TableName: TABLE_NAME,
        IndexName: 'GSI1',
        KeyConditionExpression: keyConditionExpression,
        FilterExpression: filterExpression || undefined,
        ExpressionAttributeNames: {
          '#name': 'name',
        },
        ExpressionAttributeValues: marshall(expressionAttributeValues),
        ScanIndexForward: false, // Most recent first
        Limit: limit * 2, // Over-fetch to handle filters
      });
      
      const result = await client.send(command);
      const items = result.Items || [];
      
      const products = await Promise.all(
        items
          .slice(offset, offset + limit)
          .map((item) => this.enrichProductWithPresignedUrls(
            mapDynamoProductToEntity(unmarshall(item))
          ))
      );
      
      return {
        items: products,
        total: items.length,
        page,
        limit,
        hasMore: items.length > offset + limit,
      };
    } catch (error: any) {
      console.error('Error listing products:', error);
      throw new Error(`Failed to list products: ${error.message}`);
    }
  }

  /**
   * Search products by barcode (pharmacy use case)
   */
  static async searchByBarcode(
    tenantId: string,
    barcode: string
  ): Promise<ProductResponse | null> {
    try {
      const command = new QueryCommand({
        TableName: TABLE_NAME,
        IndexName: 'GSI2', // Barcode index
        KeyConditionExpression: 'GSI2PK = :gsi2pk AND begins_with(GSI2SK, :barcode)',
        ExpressionAttributeValues: marshall({
          ':gsi2pk': ProductKeys.gsi2pk(tenantId),
          ':barcode': `BARCODE#${barcode}`,
        }),
        Limit: 1,
      });
      
      const result = await client.send(command);
      if (!result.Items || result.Items.length === 0) {
        return null;
      }
      
      const product = mapDynamoProductToEntity(unmarshall(result.Items[0]));
      return await this.enrichProductWithPresignedUrls(product);
    } catch (error: any) {
      console.error('Error searching by barcode:', error);
      return null;
    }
  }

  /**
   * Get top-selling products (based on sales metadata)
   * Requires sales events to be tracked separately
   */
  static async getTopSellingProducts(
    tenantId: string,
    businessType: string,
    limit: number = 10
  ): Promise<ProductResponse[]> {
    try {
      const command = new QueryCommand({
        TableName: TABLE_NAME,
        IndexName: 'GSI1',
        KeyConditionExpression: 'GSI1PK = :gsi1pk',
        ExpressionAttributeValues: marshall({
          ':gsi1pk': ProductKeys.gsi1pk(tenantId, businessType),
        }),
        ScanIndexForward: false,
        Limit: limit,
      });
      
      const result = await client.send(command);
      const items = result.Items || [];
      
      return Promise.all(
        items.map((item) => this.enrichProductWithPresignedUrls(
          mapDynamoProductToEntity(unmarshall(item))
        ))
      );
    } catch (error: any) {
      console.error('Error getting top-selling products:', error);
      return [];
    }
  }

  /**
   * Get low-stock products (alerts for reordering)
   */
  static async getLowStockProducts(
    tenantId: string,
    businessType: string,
    limit: number = 20
  ): Promise<ProductResponse[]> {
    try {
      const command = new QueryCommand({
        TableName: TABLE_NAME,
        IndexName: 'GSI1',
        KeyConditionExpression: 'GSI1PK = :gsi1pk',
        FilterExpression: 'stock <= reorderLevel',
        ExpressionAttributeValues: marshall({
          ':gsi1pk': ProductKeys.gsi1pk(tenantId, businessType),
        }),
        ScanIndexForward: true,
        Limit: limit,
      });
      
      const result = await client.send(command);
      const items = result.Items || [];
      
      return Promise.all(
        items.map((item) => this.enrichProductWithPresignedUrls(
          mapDynamoProductToEntity(unmarshall(item))
        ))
      );
    } catch (error: any) {
      console.error('Error getting low-stock products:', error);
      return [];
    }
  }

  /**
   * Attach presigned URLs to product for immediate use in UI
   */
  private static async enrichProductWithPresignedUrls(
    product: Product
  ): Promise<ProductResponse> {
    let presignedImageUrl: string | undefined;
    let presignedThumbUrl: string | undefined;
    
    if (product.mainImage?.s3Key) {
      presignedImageUrl = await storageService.getDownloadUrl(product.mainImage.s3Key);
    }
    
    if (product.mainImage?.s3ThumbnailKey) {
      presignedThumbUrl = await storageService.getDownloadUrl(product.mainImage.s3ThumbnailKey);
    }
    
    return {
      product,
      presignedImageUrl,
      presignedThumbUrl,
    };
  }
}
