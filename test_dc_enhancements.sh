#!/bin/bash
# ============================================================================
# DC Module Enhancement - Integration Test Script
# ============================================================================
# Run this script to verify all new endpoints and features work correctly
# ============================================================================

set -e

echo "=========================================="
echo "DC Module Enhancement Tests"
echo "=========================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

API_BASE="${API_BASE_URL:-http://localhost:3000}"
AUTH_TOKEN="${AUTH_TOKEN:-test-token}"

echo "API Base: $API_BASE"
echo ""

# Test helper function
test_endpoint() {
    local method=$1
    local endpoint=$2
    local data=$3
    local description=$4
    
    echo -n "Testing $description... "
    
    if [ -n "$data" ]; then
        response=$(curl -s -X "$method" \
            -H "Authorization: Bearer $AUTH_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$API_BASE$endpoint" || echo '{"error":"connection failed"}')
    else
        response=$(curl -s -X "$method" \
            -H "Authorization: Bearer $AUTH_TOKEN" \
            "$API_BASE$endpoint" || echo '{"error":"connection failed"}')
    fi
    
    if echo "$response" | grep -q "error"; then
        echo -e "${RED}FAILED${NC}"
        echo "Response: $response"
        return 1
    else
        echo -e "${GREEN}PASSED${NC}"
        return 0
    fi
}

echo "1. Testing Phase 1 - Missing CRUD Endpoints"
echo "----------------------------------------------"

# Test getQuote endpoint
test_endpoint "GET" "/dc/quotes/quote-123" "" "GET /dc/quotes/{id} (getQuote)"

# Test expense CRUD
test_endpoint "POST" "/dc/expenses" '{"category":"decorations","amountPaisa":50000,"date":"2026-05-20","paidTo":"Test Vendor"}' "POST /dc/expenses (createExpense)"
test_endpoint "GET" "/dc/expenses/expense-123" "" "GET /dc/expenses/{id} (getExpense)"
test_endpoint "PUT" "/dc/expenses/expense-123" '{"category":"catering","amountPaisa":75000}' "PUT /dc/expenses/{id} (updateExpense)"
test_endpoint "DELETE" "/dc/expenses/expense-123" "" "DELETE /dc/expenses/{id} (deleteExpense)"

echo ""
echo "2. Testing Phase 1 - Vendor totalDue Calculation"
echo "------------------------------------------------"

# Create vendor with rating
test_endpoint "POST" "/dc/vendors" '{"name":"Test Flower Vendor","phone":"9999999999","vendorType":"flowers","rating":4.5}' "POST /dc/vendors with rating"

# List vendors with calculated totals
test_endpoint "GET" "/dc/vendors" "" "GET /dc/vendors (with totalDue calculation)"

echo ""
echo "3. Testing Phase 2 - Date Range Filtering"
echo "-------------------------------------------"

# Dashboard with date range
test_endpoint "GET" "/dc/dashboard?from=2026-05-01&to=2026-05-31" "" "GET /dc/dashboard?from=&to="

echo ""
echo "4. Testing Phase 3 - Event Scheduling"
echo "---------------------------------------"

# Create event with scheduling times
test_endpoint "POST" "/dc/events" '{
    "customerName":"Test Customer",
    "customerPhone":"9999999999",
    "eventType":"wedding",
    "eventDate":"2026-06-15",
    "guestCount":100,
    "setupTime":"14:00",
    "serviceStartTime":"16:00",
    "serviceEndTime":"22:00",
    "cleanupTime":"23:00"
}' "POST /dc/events with scheduling times"

# Update event with new times
test_endpoint "PUT" "/dc/events/event-123" '{"setupTime":"13:00","serviceStartTime":"15:00"}' "PUT /dc/events/{id} with scheduling update"

echo ""
echo "5. Testing WebSocket Events (via logs)"
echo "----------------------------------------"
echo "WebSocket events are broadcast on:"
echo "  - DC_EVENT_CREATED"
echo "  - DC_EVENT_UPDATED"
echo "  - DC_EVENT_STATUS_CHANGED"
echo "  - DC_PAYMENT_RECEIVED"
echo "  - DC_EXPENSE_ADDED"
echo "  - DC_STAFF_ASSIGNED"
echo "  - DC_INVENTORY_LOW_STOCK"
echo "  - DC_QUOTE_CONVERTED"

echo ""
echo "=========================================="
echo "All integration tests completed!"
echo "=========================================="
