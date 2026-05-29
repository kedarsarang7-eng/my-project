import { success, error, verifyToken, queryItems, logAuditEvent } from '../shared/utils.mjs';

const TABLE_NAME = process.env.DYNAMODB_TABLE_MAIN;

// Get today's business date in IST
function getBusinessDate() {
  const now = new Date();
  const istOffset = 5.5 * 60 * 60 * 1000;
  const istTime = new Date(now.getTime() + istOffset);
  return istTime.toISOString().split('T')[0];
}

// Standard jewelry categories
const JEWELRY_CATEGORIES = [
  'Rings',
  'Earrings', 
  'Necklaces',
  'Bracelets',
  'Bangels',
  'Chains',
  'Pendants',
  'Watches',
  'Coins'
];

// Get sales data by category for today
async function getCategorySalesData(tenantId, branchId, role) {
  try {
    const businessDate = getBusinessDate();
    
    // Query invoices for today
    const invoices = await queryItems(
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

    // Initialize category totals
    const categoryTotals = {};
    const categoryCounts = {};
    
    JEWELRY_CATEGORIES.forEach(category => {
      categoryTotals[category] = 0;
      categoryCounts[category] = 0;
    });

    let totalSales = 0;

    // Aggregate sales by category
    for (const invoice of invoices) {
      if (invoice.branchId === branchId || role === 'owner') {
        const invoiceTotal = invoice.grandTotal || 0;
        const category = invoice.ornamentCategory || 'Other';
        
        // Handle category mapping
        const normalizedCategory = normalizeCategory(category);
        
        if (categoryTotals.hasOwnProperty(normalizedCategory)) {
          categoryTotals[normalizedCategory] += invoiceTotal;
          categoryCounts[normalizedCategory]++;
        } else {
          // Create "Other" category for unrecognized categories
          if (!categoryTotals['Other']) {
            categoryTotals['Other'] = 0;
            categoryCounts['Other'] = 0;
          }
          categoryTotals['Other'] += invoiceTotal;
          categoryCounts['Other']++;
        }
        
        totalSales += invoiceTotal;
      }
    }

    // Build category data with percentages
    const categories = [];
    for (const [category, amount] of Object.entries(categoryTotals)) {
      if (amount > 0) { // Only include categories with sales
        const percentage = totalSales > 0 ? (amount / totalSales) * 100 : 0;
        categories.push({
          category,
          amount,
          itemCount: categoryCounts[category] || 0,
          percentage: Math.round(percentage * 10) / 10, // Round to 1 decimal place
        });
      }
    }

    // Sort by amount descending
    categories.sort((a, b) => b.amount - a.amount);

    return {
      categories,
      totalSales,
    };
  } catch (error) {
    console.error('Error in getCategorySalesData:', error);
    return {
      categories: [],
      totalSales: 0,
    };
  }
}

// Normalize category names to match standard categories
function normalizeCategory(category) {
  if (!category) return 'Other';
  
  const normalized = category.toLowerCase().trim();
  
  // Map common variations to standard categories
  const categoryMap = {
    'ring': 'Rings',
    'rings': 'Rings',
    'earring': 'Earrings',
    'earrings': 'Earrings',
    'ear ring': 'Earrings',
    'ear rings': 'Earrings',
    'necklace': 'Necklaces',
    'necklaces': 'Necklaces',
    'chain': 'Chains',
    'chains': 'Chains',
    'neck chain': 'Chains',
    'bangle': 'Bangels',
    'bangels': 'Bangels',
    'bangles': 'Bangels',
    'bracelet': 'Bracelets',
    'bracelets': 'Bracelets',
    'pendant': 'Pendants',
    'pendants': 'Pendants',
    'locket': 'Pendants',
    'watch': 'Watches',
    'watches': 'Watches',
    'coin': 'Coins',
    'coins': 'Coins',
    'gold coin': 'Coins',
    'silver coin': 'Coins',
  };
  
  return categoryMap[normalized] || 'Other';
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
      'JEWELRY_DASHBOARD_CATEGORY_SPLIT',
      undefined,
      { date: requestedDate },
      event.requestContext?.identity?.sourceIp,
      event.headers?.['User-Agent']
    );

    // Fetch category sales data
    const categoryData = await getCategorySalesData(user.tenantId, branchId, user.role);

    const response = {
      ...categoryData,
      lastUpdated: new Date().toISOString(),
    };

    // Log performance metrics
    const duration = Date.now() - startTime;
    console.log(`Category split request completed in ${duration}ms for tenant ${user.tenantId}`);

    return success(response, 200);

  } catch (err) {
    console.error('Jewelry Category Split Error:', err);
    
    if (err.message === 'Invalid token') {
      return error('Unauthorized: Invalid token', 401, requestId);
    }
    
    if (err.message === 'FORBIDDEN') {
      return error('Access forbidden', 403, requestId);
    }

    return error('Internal server error', 500, requestId);
  }
};
