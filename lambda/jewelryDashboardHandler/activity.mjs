import { success, error, verifyToken, queryItems, logAuditEvent } from '../shared/utils.mjs';

const TABLE_NAME = process.env.DYNAMODB_TABLE_MAIN;

// Get today's business date in IST
function getBusinessDate() {
  const now = new Date();
  const istOffset = 5.5 * 60 * 60 * 1000;
  const istTime = new Date(now.getTime() + istOffset);
  return istTime.toISOString().split('T')[0];
}

// Get top selling jewelry items
async function getTopSellingItems(tenantId, branchId, role, limit = 5) {
  try {
    const businessDate = getBusinessDate();
    
    // Query invoices for the last 30 days to find top sellers
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    const startDate = thirtyDaysAgo.toISOString().split('T')[0];
    
    // Get all invoices in the date range
    const invoices = await queryItems(
      TABLE_NAME,
      'tenantId = :tenantId AND SK BETWEEN :skStart AND :skEnd',
      {
        ':tenantId': tenantId,
        ':skStart': `INVOICE#${startDate}`,
        ':skEnd': `INVOICE#${businessDate}#`,
        ':entityType': 'INVOICE',
        ':status1': 'PAID',
        ':status2': 'PARTIAL',
      },
      'entityType = :entityType AND status IN (:status1, :status2)'
    );

    // Filter by branch if not owner
    const filteredInvoices = role === 'owner' 
      ? invoices 
      : invoices.filter(invoice => invoice.branchId === branchId);

    // Aggregate sales by item
    const itemSales = {};
    
    for (const invoice of filteredInvoices) {
      if (invoice.items && Array.isArray(invoice.items)) {
        for (const item of invoice.items) {
          const itemId = item.itemId || item.id;
          const itemName = item.itemName || item.name || 'Unknown Item';
          const category = item.ornamentCategory || item.category || 'Other';
          const karat = item.karat || '';
          const imageUrl = item.imageUrl || '';
          const quantity = item.quantity || 1;
          const price = item.price || 0;
          
          if (!itemSales[itemId]) {
            itemSales[itemId] = {
              id: itemId,
              name: itemName,
              category,
              karat,
              imageUrl,
              unitsSold: 0,
              revenue: 0,
              lastSold: invoice.createdAt,
            };
          }
          
          itemSales[itemId].unitsSold += quantity;
          itemSales[itemId].revenue += price * quantity;
          
          // Update last sold date if more recent
          if (new Date(invoice.createdAt) > new Date(itemSales[itemId].lastSold)) {
            itemSales[itemId].lastSold = invoice.createdAt;
          }
        }
      }
    }

    // Convert to array and sort by units sold (revenue as tie-breaker)
    const topItems = Object.values(itemSales)
      .map(item => ({
        ...item,
        avgPrice: item.unitsSold > 0 ? item.revenue / item.unitsSold : 0,
      }))
      .sort((a, b) => {
        if (b.unitsSold !== a.unitsSold) {
          return b.unitsSold - a.unitsSold;
        }
        return b.revenue - a.revenue;
      })
      .slice(0, limit);

    return topItems;
  } catch (error) {
    console.error('Error in getTopSellingItems:', error);
    return [];
  }
}

// Get recent activities
async function getRecentActivities(tenantId, branchId, role, limit = 10) {
  try {
    const activities = [];
    
    // Get recent invoices (sales activities)
    const recentInvoices = await queryItems(
      TABLE_NAME,
      'tenantId = :tenantId AND begins_with(SK, :skPrefix)',
      {
        ':tenantId': tenantId,
        ':skPrefix': 'INVOICE#',
      }
    );

    // Filter by branch if not owner
    const filteredInvoices = role === 'owner' 
      ? recentInvoices 
      : recentInvoices.filter(invoice => invoice.branchId === branchId);

    // Convert invoices to activities
    for (const invoice of filteredInvoices.slice(0, limit)) {
      activities.push({
        id: invoice.SK,
        type: 'Sale',
        description: `Sold ${invoice.ornamentCategory || 'jewelry'} for ₹${(invoice.grandTotal || 0).toLocaleString('en-IN')}`,
        userId: invoice.createdBy || invoice.userId || 'system',
        userName: invoice.createdByName || invoice.userName || 'Staff',
        userAvatar: invoice.createdByAvatar || '',
        timestamp: invoice.createdAt,
        relatedEntityId: invoice.SK,
        relatedEntityType: 'INVOICE',
        metadata: {
          customerName: invoice.customerName,
          amount: invoice.grandTotal,
        },
      });
    }

    // Get recent inventory adjustments
    const recentInventory = await queryItems(
      TABLE_NAME,
      'tenantId = :tenantId AND begins_with(SK, :skPrefix)',
      {
        ':tenantId': tenantId,
        ':skPrefix': 'INVENTORY#',
      }
    );

    const filteredInventory = role === 'owner' 
      ? recentInventory 
      : recentInventory.filter(item => item.branchId === branchId);

    // Add low stock alerts
    for (const item of filteredInventory) {
      const currentQty = item.currentQty || 0;
      const reorderLevel = item.reorderLevel || 0;
      
      if (currentQty < reorderLevel && currentQty > 0) {
        activities.push({
          id: `LOWSTOCK#${item.SK}`,
          type: 'Low Stock',
          description: `${item.itemName || item.name} is running low (${currentQty}g remaining)`,
          userId: 'system',
          userName: 'System',
          userAvatar: '',
          timestamp: item.updatedAt || item.createdAt,
          relatedEntityId: item.SK,
          relatedEntityType: 'INVENTORY',
          metadata: {
            currentQty,
            reorderLevel,
          },
        });
      }
    }

    // Sort by timestamp (most recent first)
    activities.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

    return activities.slice(0, limit);
  } catch (error) {
    console.error('Error in getRecentActivities:', error);
    return [];
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

    // Handle different endpoints based on path
    const path = event.pathParameters?.proxy || event.path || '';
    
    if (path.endsWith('/activity')) {
      // Combined activity data
      await logAuditEvent(
        user.tenantId,
        user.sub,
        'READ',
        'JEWELRY_DASHBOARD_ACTIVITY',
        undefined,
        {},
        event.requestContext?.identity?.sourceIp,
        event.headers?.['User-Agent']
      );

      const [topSellingItems, recentActivities] = await Promise.all([
        getTopSellingItems(user.tenantId, branchId, user.role, 5),
        getRecentActivities(user.tenantId, branchId, user.role, 10),
      ]);

      const response = {
        topSellingItems,
        recentActivities,
        lastUpdated: new Date().toISOString(),
      };

      const duration = Date.now() - startTime;
      console.log(`Activity request completed in ${duration}ms for tenant ${user.tenantId}`);

      return success(response, 200);
      
    } else if (path.endsWith('/top-sellers')) {
      // Top selling items only
      await logAuditEvent(
        user.tenantId,
        user.sub,
        'READ',
        'JEWELRY_DASHBOARD_TOP_SELLERS',
        undefined,
        {},
        event.requestContext?.identity?.sourceIp,
        event.headers?.['User-Agent']
      );

      const topSellingItems = await getTopSellingItems(user.tenantId, branchId, user.role);

      const response = {
        items: topSellingItems,
        lastUpdated: new Date().toISOString(),
      };

      return success(response, 200);
      
    } else if (path.endsWith('/recent-activity')) {
      // Recent activities only
      await logAuditEvent(
        user.tenantId,
        user.sub,
        'READ',
        'JEWELRY_DASHBOARD_RECENT_ACTIVITY',
        undefined,
        {},
        event.requestContext?.identity?.sourceIp,
        event.headers?.['User-Agent']
      );

      const recentActivities = await getRecentActivities(user.tenantId, branchId, user.role);

      const response = {
        activities: recentActivities,
        lastUpdated: new Date().toISOString(),
      };

      return success(response, 200);
      
    } else {
      return error('Endpoint not found', 404, requestId);
    }

  } catch (err) {
    console.error('Jewelry Activity Error:', err);
    
    if (err.message === 'Invalid token') {
      return error('Unauthorized: Invalid token', 401, requestId);
    }
    
    if (err.message === 'FORBIDDEN') {
      return error('Access forbidden', 403, requestId);
    }

    return error('Internal server error', 500, requestId);
  }
};
