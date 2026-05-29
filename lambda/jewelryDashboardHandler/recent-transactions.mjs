import { success, error, verifyToken, queryItems, logAuditEvent, getPaginationParams, createPaginationResponse } from '../shared/utils.mjs';

const TABLE_NAME = process.env.DYNAMODB_TABLE_MAIN;

// Get recent transactions with pagination and search
async function getRecentTransactions(tenantId, branchId, role, page, limit, searchQuery, sortBy, sortOrder) {
  try {
    const offset = (page - 1) * limit;
    
    // Query invoices from DynamoDB
    let transactions = [];
    
    if (searchQuery) {
      // For search, we'll need to scan with filter (less efficient but necessary for search)
      transactions = await queryItems(
        TABLE_NAME,
        'tenantId = :tenantId AND begins_with(SK, :skPrefix)',
        {
          ':tenantId': tenantId,
          ':skPrefix': 'INVOICE#',
        },
        'contains(customerName, :searchQuery) OR contains(orderNumber, :searchQuery) OR contains(customerPhone, :searchQuery)',
        {
          ':searchQuery': searchQuery.toLowerCase(),
        }
      );
    } else {
      // For non-search, use direct query
      transactions = await queryItems(
        TABLE_NAME,
        'tenantId = :tenantId AND begins_with(SK, :skPrefix)',
        {
          ':tenantId': tenantId,
          ':skPrefix': 'INVOICE#',
        }
      );
    }

    // Filter by branch if not owner
    if (role !== 'owner') {
      transactions = transactions.filter(transaction => transaction.branchId === branchId);
    }

    // Sort transactions
    transactions = sortTransactions(transactions, sortBy, sortOrder);

    // Get total count before pagination
    const totalCount = transactions.length;

    // Apply pagination
    const paginatedTransactions = transactions.slice(offset, offset + limit);

    // Transform to response format
    const responseTransactions = paginatedTransactions.map(transaction => ({
      id: transaction.SK,
      orderNumber: transaction.orderNumber || transaction.invoiceNumber || 'INV-' + transaction.SK.split('#')[1],
      customerName: transaction.customerName || 'Unknown Customer',
      customerPhone: transaction.customerPhone || '',
      date: transaction.createdAt || transaction.invoiceDate,
      amount: transaction.grandTotal || 0,
      amountPaid: transaction.amountPaid || 0,
      status: transaction.status || 'DRAFT',
      paymentStatus: transaction.paymentStatus || 'UNPAID',
      ornamentCategory: transaction.ornamentCategory || 'Other',
      karat: transaction.karat || '',
      weight: transaction.totalWeight || 0,
      branchId: transaction.branchId,
    }));

    return {
      transactions: responseTransactions,
      totalCount,
    };
  } catch (error) {
    console.error('Error in getRecentTransactions:', error);
    return {
      transactions: [],
      totalCount: 0,
    };
  }
}

// Sort transactions based on criteria
function sortTransactions(transactions, sortBy, sortOrder) {
  const ascending = sortOrder === 'asc';
  
  return transactions.sort((a, b) => {
    let comparison = 0;
    
    switch (sortBy) {
      case 'date':
      case 'createdAt':
        comparison = new Date(a.createdAt || a.date) - new Date(b.createdAt || b.date);
        break;
      case 'amount':
      case 'grandTotal':
        comparison = (a.grandTotal || 0) - (b.grandTotal || 0);
        break;
      case 'customerName':
        comparison = (a.customerName || '').localeCompare(b.customerName || '');
        break;
      case 'orderNumber':
      case 'invoiceNumber':
        comparison = (a.orderNumber || a.invoiceNumber || '').localeCompare(b.orderNumber || b.invoiceNumber || '');
        break;
      default:
        // Default sort by date (newest first)
        comparison = new Date(b.createdAt || b.date) - new Date(a.createdAt || a.date);
        ascending = false; // Reverse for newest first
    }
    
    return ascending ? comparison : -comparison;
  });
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

    // Get pagination parameters
    const { limit, nextToken } = getPaginationParams(event);
    let page = parseInt(event.queryStringParameters?.page || '1');
    
    // Handle nextToken for pagination
    if (nextToken) {
      try {
        const tokenData = JSON.parse(Buffer.from(nextToken, 'base64').toString());
        page = tokenData.page || page;
      } catch (error) {
        console.log('Invalid nextToken, using default page');
      }
    }

    // Get other query parameters
    const searchQuery = event.queryStringParameters?.search || '';
    const sortBy = event.queryStringParameters?.sortBy || 'date';
    const sortOrder = event.queryStringParameters?.sortOrder || 'desc';

    // Validate sort field
    const validSortFields = ['date', 'amount', 'customerName', 'orderNumber'];
    if (!validSortFields.includes(sortBy)) {
      return error(`Invalid sort field. Must be one of: ${validSortFields.join(', ')}`, 400, requestId);
    }

    // Log audit event
    await logAuditEvent(
      user.tenantId,
      user.sub,
      'READ',
      'JEWELRY_DASHBOARD_RECENT_TRANSACTIONS',
      undefined,
      { 
        page, 
        limit, 
        searchQuery, 
        sortBy, 
        sortOrder 
      },
      event.requestContext?.identity?.sourceIp,
      event.headers?.['User-Agent']
    );

    // Fetch transactions
    const transactionData = await getRecentTransactions(
      user.tenantId,
      branchId,
      user.role,
      page,
      limit,
      searchQuery,
      sortBy,
      sortOrder
    );

    const response = {
      ...transactionData,
      lastUpdated: new Date().toISOString(),
    };

    // Add pagination info if needed
    const totalPages = Math.ceil(transactionData.totalCount / limit);
    if (page < totalPages) {
      const nextTokenData = { page: page + 1 };
      response.nextToken = Buffer.from(JSON.stringify(nextTokenData)).toString('base64');
    }

    // Log performance metrics
    const duration = Date.now() - startTime;
    console.log(`Recent transactions request completed in ${duration}ms for tenant ${user.tenantId}, page ${page}`);

    return success(response, 200);

  } catch (err) {
    console.error('Jewelry Recent Transactions Error:', err);
    
    if (err.message === 'Invalid token') {
      return error('Unauthorized: Invalid token', 401, requestId);
    }
    
    if (err.message === 'FORBIDDEN') {
      return error('Access forbidden', 403, requestId);
    }

    return error('Internal server error', 500, requestId);
  }
};
