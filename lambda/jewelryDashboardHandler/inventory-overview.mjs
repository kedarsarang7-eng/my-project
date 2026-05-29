import { success, error, verifyToken, queryItems, logAuditEvent } from '../shared/utils.mjs';

const TABLE_NAME = process.env.DYNAMODB_TABLE_MAIN;

// Get inventory overview for a specific metal type
async function getInventoryOverview(tenantId, branchId, metalType) {
  try {
    // Query inventory items for the tenant
    const inventoryItems = await queryItems(
      TABLE_NAME,
      'tenantId = :tenantId AND begins_with(SK, :skPrefix)',
      {
        ':tenantId': tenantId,
        ':skPrefix': 'INVENTORY#',
      }
    );

    // Filter by branch if not owner
    const filteredItems = inventoryItems.filter(item => item.branchId === branchId);

    // Group by metal type
    const metalGroups = {
      'Gold': [],
      'Silver': [],
      'Platinum': []
    };

    // Categorize items by metal type
    for (const item of filteredItems) {
      const metal = determineMetalType(item);
      if (metalGroups[metal]) {
        metalGroups[metal].push(item);
      }
    }

    // Build summaries for each metal type
    const metalSummaries = {};
    
    for (const [metal, items] of Object.entries(metalGroups)) {
      const summary = await buildMetalSummary(metal, items);
      metalSummaries[metal] = summary;
    }

    return metalSummaries;
  } catch (error) {
    console.error('Error in getInventoryOverview:', error);
    return {
      'Gold': createEmptyMetalSummary('Gold'),
      'Silver': createEmptyMetalSummary('Silver'),
      'Platinum': createEmptyMetalSummary('Platinum'),
    };
  }
}

// Determine metal type based on item properties
function determineMetalType(item) {
  const karat = (item.karat || '').toLowerCase();
  const category = (item.category || '').toLowerCase();
  const name = (item.itemName || item.name || '').toLowerCase();
  
  // Check for gold indicators
  if (karat.includes('22k') || karat.includes('18k') || karat.includes('14k') || 
      karat.includes('916') || karat.includes('750') || karat.includes('585') ||
      category.includes('gold') || name.includes('gold')) {
    return 'Gold';
  }
  
  // Check for silver indicators
  if (karat.includes('925') || karat.includes('999') || karat.includes('sterling') ||
      category.includes('silver') || name.includes('silver')) {
    return 'Silver';
  }
  
  // Check for platinum indicators
  if (karat.includes('950') || karat.includes('900') || karat.includes('pt') ||
      category.includes('platinum') || name.includes('platinum')) {
    return 'Platinum';
  }
  
  // Default to gold for jewelry items
  return 'Gold';
}

// Build summary for a specific metal type
async function buildMetalSummary(metalType, items) {
  let totalItems = items.length;
  let lowStockCount = 0;
  let criticalStockCount = 0;
  let totalWeight = 0;
  let availableWeight = 0;
  let totalMakingCharges = 0;
  const lowStockItems = [];

  for (const item of items) {
    const currentQty = item.currentQty || 0;
    const reorderLevel = item.reorderLevel || 0;
    const rawStock = item.rawStock || 0;
    const finishedGoods = item.finishedGoods || 0;
    const wip = item.wip || 0;
    const reserved = item.reserved || 0;
    const makingCharges = item.makingChargesPerGram || 0;
    
    totalWeight += currentQty;
    availableWeight += Math.max(0, rawStock + finishedGoods - wip - reserved);
    totalMakingCharges += makingCharges;
    
    // Check stock status
    if (currentQty <= 0) {
      criticalStockCount++;
      lowStockItems.push(formatInventoryItem(item, 'critical'));
    } else if (currentQty < reorderLevel) {
      lowStockCount++;
      lowStockItems.push(formatInventoryItem(item, 'low'));
    }
  }

  const avgMakingCharges = totalItems > 0 ? totalMakingCharges / totalItems : 0;

  return {
    metalType,
    totalItems,
    lowStockCount,
    criticalStockCount,
    totalWeight,
    availableWeight,
    avgMakingCharges: Math.round(avgMakingCharges * 100) / 100,
    lowStockItems: lowStockItems.slice(0, 10), // Limit to 10 items for dashboard
  };
}

// Format inventory item for response
function formatInventoryItem(item, stockStatus) {
  return {
    id: item.SK,
    name: item.itemName || item.name || 'Unknown Item',
    category: item.ornamentCategory || item.category || 'Other',
    karat: item.karat || '',
    purity: item.purity || '',
    currentQty: item.currentQty || 0,
    reorderLevel: item.reorderLevel || 0,
    rawStock: item.rawStock || 0,
    finishedGoods: item.finishedGoods || 0,
    wip: item.wip || 0,
    reserved: item.reserved || 0,
    makingChargesPerGram: item.makingChargesPerGram || 0,
    lastUpdated: item.updatedAt || item.createdAt || new Date().toISOString(),
    stockStatus,
  };
}

// Create empty metal summary
function createEmptyMetalSummary(metalType) {
  return {
    metalType,
    totalItems: 0,
    lowStockCount: 0,
    criticalStockCount: 0,
    totalWeight: 0,
    availableWeight: 0,
    avgMakingCharges: 0,
    lowStockItems: [],
  };
}

// Restock item handler
async function restockItem(tenantId, branchId, itemId) {
  try {
    // This would typically trigger a restock workflow
    // For now, we'll just log the action
    console.log(`Restock requested for item ${itemId} in tenant ${tenantId}, branch ${branchId}`);
    
    // In a real implementation, this would:
    // 1. Create a restock order
    // 2. Notify procurement
    // 3. Update inventory status
    
    return { success: true, message: 'Restock request created' };
  } catch (error) {
    console.error('Error in restockItem:', error);
    throw new Error('Failed to create restock request');
  }
}

// Update reorder level handler
async function updateReorderLevel(tenantId, branchId, itemId, newLevel) {
  try {
    // Update the reorder level in DynamoDB
    const updateParams = {
      TableName: TABLE_NAME,
      Key: {
        PK: `TENANT#${tenantId}`,
        SK: itemId,
      },
      UpdateExpression: 'SET reorderLevel = :reorderLevel, updatedAt = :updatedAt',
      ExpressionAttributeValues: {
        ':reorderLevel': newLevel,
        ':updatedAt': new Date().toISOString(),
      },
      ReturnValues: 'ALL_NEW',
    };

    // Use the updateItem function from utils
    const { updateItem } = await import('../shared/utils.mjs');
    const result = await updateItem(TABLE_NAME, 
      { PK: `TENANT#${tenantId}`, SK: itemId },
      { 
        reorderLevel: newLevel,
        updatedAt: new Date().toISOString(),
      }
    );

    return { success: true, message: 'Reorder level updated' };
  } catch (error) {
    console.error('Error in updateReorderLevel:', error);
    throw new Error('Failed to update reorder level');
  }
}

// Main handler function
export const handler = async (event) => {
  const requestId = event.headers?.['X-Request-Id'] || 'unknown';
  const startTime = Date.now();

  try {
    // Verify JWT token
    const authHeader = event.headers?.Authorization || event.headers?.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return error('Missing or invalid authorization header', 401, requestId);
    }

    const token = authHeader.substring(7);
    const user = await verifyToken(token);

    // Extract branchId from JWT claims or headers
    const branchId = event.headers?.['X-Branch-Id'] || 
                    event.queryStringParameters?.branchId ||
                    user.branchId;

    if (!branchId && user.role !== 'owner') {
      return error('Branch ID required for non-owner roles', 400, requestId);
    }

    // Handle different HTTP methods
    const httpMethod = event.requestContext?.http?.method || event.httpMethod;
    
    if (httpMethod === 'GET') {
      // Get inventory overview
      const metalType = event.queryStringParameters?.metalType || 'Gold';
      
      // Log audit event
      await logAuditEvent(
        user.tenantId,
        user.sub,
        'READ',
        'JEWELRY_DASHBOARD_INVENTORY_OVERVIEW',
        undefined,
        { metalType },
        event.requestContext?.identity?.sourceIp,
        event.headers?.['User-Agent']
      );

      const metalSummaries = await getInventoryOverview(user.tenantId, branchId, metalType);

      const response = {
        metalSummaries,
        lastUpdated: new Date().toISOString(),
      };

      // Log performance metrics
      const duration = Date.now() - startTime;
      console.log(`Inventory overview request completed in ${duration}ms for tenant ${user.tenantId}`);

      return success(response, 200);
      
    } else if (httpMethod === 'POST') {
      // Restock item
      const body = JSON.parse(event.body || '{}');
      const { itemId } = body;
      
      if (!itemId) {
        return error('itemId is required', 400, requestId);
      }

      await logAuditEvent(
        user.tenantId,
        user.sub,
        'CREATE',
        'JEWELRY_INVENTORY_RESTOCK',
        itemId,
        { branchId },
        event.requestContext?.identity?.sourceIp,
        event.headers?.['User-Agent']
      );

      const result = await restockItem(user.tenantId, branchId, itemId);
      return success(result, 200);
      
    } else if (httpMethod === 'PATCH') {
      // Update reorder level
      const body = JSON.parse(event.body || '{}');
      const { itemId, reorderLevel } = body;
      
      if (!itemId || reorderLevel === undefined) {
        return error('itemId and reorderLevel are required', 400, requestId);
      }

      await logAuditEvent(
        user.tenantId,
        user.sub,
        'UPDATE',
        'JEWELRY_INVENTORY_REORDER_LEVEL',
        itemId,
        { reorderLevel, branchId },
        event.requestContext?.identity?.sourceIp,
        event.headers?.['User-Agent']
      );

      const result = await updateReorderLevel(user.tenantId, branchId, itemId, reorderLevel);
      return success(result, 200);
      
    } else {
      return error('Method not allowed', 405, requestId);
    }

  } catch (err) {
    console.error('Jewelry Inventory Overview Error:', err);
    
    if (err.message === 'Invalid token') {
      return error('Unauthorized: Invalid token', 401, requestId);
    }
    
    if (err.message === 'FORBIDDEN') {
      return error('Access forbidden', 403, requestId);
    }

    return error('Internal server error', 500, requestId);
  }
};
