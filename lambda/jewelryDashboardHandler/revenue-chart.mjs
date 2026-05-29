import { success, error, verifyToken, queryItems, logAuditEvent } from '../shared/utils.mjs';

const TABLE_NAME = process.env.DYNAMODB_TABLE_MAIN;

// Helper function to get date range based on period
function getDateRange(period) {
  const now = new Date();
  const istOffset = 5.5 * 60 * 60 * 1000; // IST offset
  const istNow = new Date(now.getTime() + istOffset);
  
  let startDate, endDate;
  
  switch (period) {
    case '7D':
      startDate = new Date(istNow);
      startDate.setDate(startDate.getDate() - 6);
      endDate = istNow;
      break;
    case 'MTD':
      startDate = new Date(istNow.getFullYear(), istNow.getMonth(), 1);
      endDate = istNow;
      break;
    case '30D':
      startDate = new Date(istNow);
      startDate.setDate(startDate.getDate() - 29);
      endDate = istNow;
      break;
    default:
      startDate = new Date(istNow);
      startDate.setDate(startDate.getDate() - 6);
      endDate = istNow;
  }
  
  return {
    startDate: startDate.toISOString().split('T')[0],
    endDate: endDate.toISOString().split('T')[0],
  };
}

// Helper function to generate date array for the period
function generateDateArray(startDate, endDate) {
  const dates = [];
  const start = new Date(startDate);
  const end = new Date(endDate);
  
  while (start <= end) {
    dates.push(new Date(start).toISOString().split('T')[0]);
    start.setDate(start.getDate() + 1);
  }
  
  return dates;
}

// Get revenue data for the specified period
async function getRevenueData(tenantId, branchId, role, period) {
  try {
    const { startDate, endDate } = getDateRange(period);
    const dates = generateDateArray(startDate, endDate);
    
    // Query invoices for each date in the period
    const revenuePromises = dates.map(async (date) => {
      try {
        const invoices = await queryItems(
          TABLE_NAME,
          'tenantId = :tenantId AND businessDate = :businessDate',
          {
            ':tenantId': tenantId,
            ':businessDate': date,
            ':entityType': 'INVOICE',
            ':status1': 'PAID',
            ':status2': 'PARTIAL',
          },
          'entityType = :entityType AND status IN (:status1, :status2)'
        );

        let totalRevenue = 0;
        let transactionCount = 0;

        for (const invoice of invoices) {
          if (invoice.branchId === branchId || role === 'owner') {
            totalRevenue += (invoice.grandTotal || 0);
            transactionCount++;
          }
        }

        return {
          date: date,
          amount: totalRevenue,
          transactionCount: transactionCount,
        };
      } catch (error) {
        console.error(`Error fetching revenue for date ${date}:`, error);
        return {
          date: date,
          amount: 0,
          transactionCount: 0,
        };
      }
    });

    const results = await Promise.all(revenuePromises);
    
    // Calculate totals and averages
    const totalRevenue = results.reduce((sum, day) => sum + day.amount, 0);
    const totalTransactions = results.reduce((sum, day) => sum + day.transactionCount, 0);
    const averageRevenue = results.length > 0 ? totalRevenue / results.length : 0;

    return {
      dataPoints: results,
      totalRevenue,
      averageRevenue,
      totalTransactions,
    };
  } catch (error) {
    console.error('Error in getRevenueData:', error);
    return {
      dataPoints: [],
      totalRevenue: 0,
      averageRevenue: 0,
      totalTransactions: 0,
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

    // Extract branchId from JWT claims or headers
    const branchId = event.headers?.['X-Branch-Id'] || 
                    event.queryStringParameters?.branchId ||
                    user.branchId;

    if (!branchId && user.role !== 'owner') {
      return error('Branch ID required for non-owner roles', 400, requestId);
    }

    // Validate period parameter
    const period = event.queryStringParameters?.period || '7D';
    const validPeriods = ['7D', 'MTD', '30D'];
    if (!validPeriods.includes(period)) {
      return error('Invalid period. Must be one of: 7D, MTD, 30D', 400, requestId);
    }

    // Log audit event
    await logAuditEvent(
      user.tenantId,
      user.sub,
      'READ',
      'JEWELRY_DASHBOARD_REVENUE_CHART',
      undefined,
      { period },
      event.requestContext?.identity?.sourceIp,
      event.headers?.['User-Agent']
    );

    // Fetch revenue data
    const revenueData = await getRevenueData(user.tenantId, branchId, user.role, period);

    const response = {
      ...revenueData,
      period: period,
      lastUpdated: new Date().toISOString(),
    };

    // Log performance metrics
    const duration = Date.now() - startTime;
    console.log(`Revenue chart request completed in ${duration}ms for tenant ${user.tenantId}, period ${period}`);

    return success(response, 200);

  } catch (err) {
    console.error('Jewelry Revenue Chart Error:', err);
    
    if (err.message === 'Invalid token') {
      return error('Unauthorized: Invalid token', 401, requestId);
    }
    
    if (err.message === 'FORBIDDEN') {
      return error('Access forbidden', 403, requestId);
    }

    return error('Internal server error', 500, requestId);
  }
};
