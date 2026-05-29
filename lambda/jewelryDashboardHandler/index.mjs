import { success, error, verifyToken, queryItems, logAuditEvent } from '../shared/utils.mjs';

// DynamoDB table names from environment variables
const TABLE_NAME = process.env.DYNAMODB_TABLE_MAIN;

// KPI response structure
const createKpiResponse = (data) => ({
  totalSalesToday: {
    amount: data.totalSalesToday || 0,
    deltaPercentage: data.salesDeltaPercentage || null,
    isPositiveTrend: data.salesIsPositiveTrend !== false,
  },
  transactionsToday: {
    count: data.transactionsToday || 0,
  },
  lowStockItems: {
    count: data.lowStockItems || 0,
  },
  pendingInvoices: {
    count: data.pendingInvoicesCount || 0,
    amount: data.pendingInvoicesAmount || 0,
  },
  lastUpdated: new Date().toISOString(),
});

// Calculate today's business date in IST
function getBusinessDate() {
  const now = new Date();
  // Convert to IST (UTC+5:30)
  const istOffset = 5.5 * 60 * 60 * 1000;
  const istTime = new Date(now.getTime() + istOffset);
  return istTime.toISOString().split('T')[0]; // YYYY-MM-DD format
}

// Get total sales for today from invoices
async function getTotalSalesToday(tenantId, branchId, role) {
  try {
    const businessDate = getBusinessDate();
    
    // Query invoices by tenant and business date using GSI
    const invoices = await queryItems(
      TABLE_NAME,
      'tenantId = :tenantId AND businessDate = :businessDate',
      {
        ':tenantId': tenantId,
        ':businessDate': businessDate,
      },
      'entityType = :entityType AND status IN (:status1, :status2)'
    );

    const expressionValues = {
      ':entityType': 'INVOICE',
      ':status1': 'PAID',
      ':status2': 'PARTIAL',
    };

    // Re-query with proper filter expression
    const filteredInvoices = await queryItems(
      TABLE_NAME,
      'tenantId = :tenantId AND businessDate = :businessDate',
      {
        ':tenantId': tenantId,
        ':businessDate': businessDate,
        ':entityType': 'INVOICE',
        ':status1': 'PAID',
        ':status2': 'PARTIAL',
      },
      'entityType = :entityType AND status IN (:status1, :status2)'
    );

    let totalSales = 0;
    let yesterdaySales = 0;

    // Calculate today's sales
    for (const invoice of filteredInvoices) {
      if (invoice.branchId === branchId || role === 'owner') {
        totalSales += (invoice.grandTotal || 0);
      }
    }

    // Get yesterday's sales for delta calculation
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const yesterdayDate = yesterday.toISOString().split('T')[0];

    try {
      const yesterdayInvoices = await queryItems(
        TABLE_NAME,
        'tenantId = :tenantId AND businessDate = :businessDate',
        {
          ':tenantId': tenantId,
          ':businessDate': yesterdayDate,
          ':entityType': 'INVOICE',
          ':status1': 'PAID',
          ':status2': 'PARTIAL',
        },
        'entityType = :entityType AND status IN (:status1, :status2)'
      );

      for (const invoice of yesterdayInvoices) {
        if (invoice.branchId === branchId || role === 'owner') {
          yesterdaySales += (invoice.grandTotal || 0);
        }
      }
    } catch (error) {
      console.log('Error fetching yesterday sales:', error);
    }

    // Calculate delta percentage
    let deltaPercentage = null;
    let isPositiveTrend = true;

    if (yesterdaySales > 0) {
      deltaPercentage = ((totalSales - yesterdaySales) / yesterdaySales) * 100;
      isPositiveTrend = deltaPercentage >= 0;
    }

    return {
      totalSalesToday: totalSales,
      salesDeltaPercentage: deltaPercentage ? Math.round(deltaPercentage * 10) / 10 : null,
      salesIsPositiveTrend: isPositiveTrend,
    };
  } catch (error) {
    console.error('Error calculating total sales:', error);
    return {
      totalSalesToday: 0,
      salesDeltaPercentage: null,
      salesIsPositiveTrend: true,
    };
  }
}

// Get transaction count for today
async function getTransactionsToday(tenantId, branchId, role) {
  try {
    const businessDate = getBusinessDate();
    
    const transactions = await queryItems(
      TABLE_NAME,
      'tenantId = :tenantId AND businessDate = :businessDate',
      {
        ':tenantId': tenantId,
        ':businessDate': businessDate,
        ':entityType': 'INVOICE',
        ':status1': 'PAID',
        ':status2': 'PARTIAL',
      },
      'entityType = :entityType AND status IN (:status1, :status2)'
    );

    let count = 0;
    for (const transaction of transactions) {
      if (transaction.branchId === branchId || role === 'owner') {
        count++;
      }
    }

    return { transactionsToday: count };
  } catch (error) {
    console.error('Error counting transactions:', error);
    return { transactionsToday: 0 };
  }
}

// Get low stock items count
async function getLowStockItems(tenantId, branchId) {
  try {
    const inventory = await queryItems(
      TABLE_NAME,
      'tenantId = :tenantId AND begins_with(SK, :skPrefix)',
      {
        ':tenantId': tenantId,
        ':skPrefix': 'INVENTORY#',
      }
    );

    let lowStockCount = 0;
    for (const item of inventory) {
      if (item.branchId === branchId) {
        const currentQty = item.currentQty || 0;
        const reorderLevel = item.reorderLevel || 0;
        
        if (currentQty < reorderLevel) {
          lowStockCount++;
        }
      }
    }

    return { lowStockItems: lowStockCount };
  } catch (error) {
    console.error('Error counting low stock items:', error);
    return { lowStockItems: 0 };
  }
}

// Get pending invoices amount and count
async function getPendingInvoices(tenantId, branchId, role) {
  try {
    const invoices = await queryItems(
      TABLE_NAME,
      'tenantId = :tenantId AND begins_with(SK, :skPrefix)',
      {
        ':tenantId': tenantId,
        ':skPrefix': 'INVOICE#',
      },
      'paymentStatus IN (:status1, :status2)'
    );

    const expressionValues = {
      ':status1': 'UNPAID',
      ':status2': 'PARTIAL',
    };

    // Re-query with proper filter
    const filteredInvoices = await queryItems(
      TABLE_NAME,
      'tenantId = :tenantId AND begins_with(SK, :skPrefix)',
      {
        ':tenantId': tenantId,
        ':skPrefix': 'INVOICE#',
        ':status1': 'UNPAID',
        ':status2': 'PARTIAL',
      },
      'paymentStatus IN (:status1, :status2)'
    );

    let totalPendingAmount = 0;
    let pendingCount = 0;

    for (const invoice of filteredInvoices) {
      if (invoice.branchId === branchId || role === 'owner') {
        const grandTotal = invoice.grandTotal || 0;
        const amountPaid = invoice.amountPaid || 0;
        const pendingAmount = grandTotal - amountPaid;
        
        if (pendingAmount > 0) {
          totalPendingAmount += pendingAmount;
          pendingCount++;
        }
      }
    }

    return {
      pendingInvoicesAmount: totalPendingAmount,
      pendingInvoicesCount: pendingCount,
    };
  } catch (error) {
    console.error('Error calculating pending invoices:', error);
    return {
      pendingInvoicesAmount: 0,
      pendingInvoicesCount: 0,
    };
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

    // Verify business type is JEWELRY
    // Note: This should be in JWT claims as custom:businessType
    // For now, we'll proceed assuming the routing handles this

    // Extract branchId from JWT claims or query params
    const branchId = event.headers?.['X-Branch-Id'] || 
                    event.queryStringParameters?.branchId ||
                    user.branchId;

    if (!branchId && user.role !== 'owner') {
      return error('Branch ID required for non-owner roles', 400, requestId);
    }

    // Validate date parameter (default to today)
    const requestedDate = event.queryStringParameters?.date || 'today';
    if (requestedDate !== 'today') {
      return error('Only "today" date parameter is supported', 400, requestId);
    }

    // Log audit event
    await logAuditEvent(
      user.tenantId,
      user.sub,
      'READ',
      'JEWELRY_DASHBOARD_KPI',
      undefined,
      undefined,
      event.requestContext?.identity?.sourceIp,
      event.headers?.['User-Agent']
    );

    // Fetch all KPI data in parallel for better performance
    const [
      salesData,
      transactionsData,
      lowStockData,
      pendingInvoicesData,
    ] = await Promise.all([
      getTotalSalesToday(user.tenantId, branchId, user.role),
      getTransactionsToday(user.tenantId, branchId, user.role),
      getLowStockItems(user.tenantId, branchId),
      getPendingInvoices(user.tenantId, branchId, user.role),
    ]);

    // Combine all KPI data
    const kpiData = {
      ...salesData,
      ...transactionsData,
      ...lowStockData,
      ...pendingInvoicesData,
    };

    // Log performance metrics
    const duration = Date.now() - startTime;
    console.log(`KPI Dashboard request completed in ${duration}ms for tenant ${user.tenantId}`);

    return success(createKpiResponse(kpiData), 200);

  } catch (err) {
    console.error('Jewelry Dashboard KPI Error:', err);
    
    if (err.message === 'Invalid token') {
      return error('Unauthorized: Invalid token', 401, requestId);
    }
    
    if (err.message === 'FORBIDDEN') {
      return error('Access forbidden', 403, requestId);
    }

    return error('Internal server error', 500, requestId);
  }
};
