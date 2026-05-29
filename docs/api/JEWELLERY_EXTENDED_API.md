# Jewellery Extended Features — API Documentation

**Version:** 1.0.0  
**Date:** May 25, 2026  
**Base URL:** `https://api.dukanx.com/v1`  
**Business Type:** JEWELLERY

---

## Table of Contents

1. [Gold Rate Alerts](#gold-rate-alerts)
2. [Making Charges Configs](#making-charges-configs)
3. [Repair Jobs](#repair-jobs)
4. [Gold Schemes](#gold-schemes)
5. [Common Response Format](#common-response-format)
6. [Error Codes](#error-codes)
7. [Authorization](#authorization)

---

## Authorization

All endpoints require a valid Cognito JWT token in the `Authorization` header:

```
Authorization: Bearer {cognito_access_token}
```

### Required Cognito Claims
- `custom:tenant_id` - Tenant identifier
- `custom:role` - User role (OWNER, ADMIN, MANAGER, STAFF, VIEWER)
- `custom:business_type` - Must be `jewellery`

---

## Gold Rate Alerts

Monitor gold rates and receive notifications when thresholds are crossed.

### Create Gold Rate Alert
```
POST /jewellery/gold-rate-alerts
```

**Request Body:**
```json
{
  "metalType": "GOLD_22K",
  "thresholdRatePaisaPerGram": 650000,
  "direction": "above",
  "method": "push",
  "note": "Alert when 22K gold goes above ₹6500/g",
  "isRecurring": false,
  "expiryDate": "2024-12-31T00:00:00Z"
}
```

**Response (201 Created):**
```json
{
  "id": "alert-uuid",
  "status": "active",
  "createdAt": "2024-01-15T10:00:00Z"
}
```

### List Gold Rate Alerts
```
GET /jewellery/gold-rate-alerts
GET /jewellery/gold-rate-alerts?status=active
```

**Response (200 OK):**
```json
{
  "data": [
    {
      "id": "alert-uuid",
      "metalType": "GOLD_22K",
      "thresholdRatePaisaPerGram": 650000,
      "direction": "above",
      "method": "push",
      "status": "active",
      "triggerCount": 0,
      "createdAt": "2024-01-15T10:00:00Z"
    }
  ]
}
```

### Update Gold Rate Alert
```
PUT /jewellery/gold-rate-alerts/{id}
```

**Request Body:** (any subset of create fields)
```json
{
  "thresholdRatePaisaPerGram": 660000,
  "status": "paused"
}
```

### Delete Gold Rate Alert
```
DELETE /jewellery/gold-rate-alerts/{id}
```

**Response (200 OK):**
```json
{
  "message": "Alert deleted"
}
```

---

## Making Charges Configs

Configure flexible making charges calculation methods.

### Create Making Charges Config
```
POST /jewellery/making-charges-configs
```

**Request Body - Per Gram:**
```json
{
  "name": "Simple Chain",
  "description": "For plain gold chains",
  "type": "perGram",
  "ratePaisaPerGram": 50000,
  "minimumChargePaisa": 20000,
  "applyOnWastage": false
}
```

**Request Body - Tiered:**
```json
{
  "name": "Light Weight Tiered",
  "type": "tiered",
  "tieredRates": [
    {"minWeightGrams": 0, "maxWeightGrams": 2, "ratePaisaPerGram": 100000},
    {"minWeightGrams": 2, "maxWeightGrams": 5, "ratePaisaPerGram": 80000},
    {"minWeightGrams": 5, "maxWeightGrams": 999999, "ratePaisaPerGram": 50000}
  ]
}
```

**Request Body - Complexity:**
```json
{
  "name": "Bridal Complexity",
  "type": "complexity",
  "complexityRates": [
    {"complexity": "simple", "ratePaisaPerGram": 50000},
    {"complexity": "medium", "ratePaisaPerGram": 100000},
    {"complexity": "intricate", "ratePaisaPerGram": 150000},
    {"complexity": "veryIntricate", "ratePaisaPerGram": 250000}
  ]
}
```

**Charge Types:**
| Type | Description |
|------|-------------|
| `perGram` | Fixed rate per gram of metal |
| `percentage` | Percentage of metal value |
| `fixed` | Flat amount regardless of weight |
| `tiered` | Different rates for weight ranges |
| `complexity` | Based on design complexity |
| `combination` | Base + percentage |

### List Making Charges Configs
```
GET /jewellery/making-charges-configs
```

### Update Making Charges Config
```
PUT /jewellery/making-charges-configs/{id}
```

### Delete Making Charges Config
```
DELETE /jewellery/making-charges-configs/{id}
```

---

## Repair Jobs

Track jewellery repair and service jobs.

### Create Repair Job
```
POST /jewellery/repairs
```

**Request Body:**
```json
{
  "customerId": "customer-uuid",
  "customerName": "Rajesh Kumar",
  "customerPhone": "+91-98765-43210",
  "itemDescription": "22K Gold Ring - Stone Loose",
  "itemCategory": "Ring",
  "metalType": "GOLD_22K",
  "weightGrams": 8.5,
  "workItems": [
    {
      "id": "work-uuid",
      "type": "stoneSetting",
      "description": "Reset main diamond",
      "estimatedCostPaisa": 50000
    }
  ],
  "customerComplaint": "Stone is loose and moves",
  "priority": "high",
  "promisedDate": "2024-01-20T00:00:00Z",
  "estimatedDays": 5,
  "estimatedCostPaisa": 50000
}
```

**Repair Types:**
| Type | Description |
|------|-------------|
| `polishing` | General polishing |
| `cleaning` | Deep cleaning |
| `resizing` | Ring band resizing |
| `soldering` | Repair broken parts |
| `stoneSetting` | Setting stones |
| `stoneReplacement` | Replace missing stones |
| `chainRepair` | Chain/link repair |
| `claspReplacement` | Clasp/hook replacement |
| `plating` | Rhodium/gold plating |
| `engraving` | Add/remove engravings |
| `restoration` | Antique restoration |
| `customWork` | Custom modifications |

**Priority Levels:** `low`, `normal`, `high`, `urgent`

### List Repair Jobs
```
GET /jewellery/repairs
GET /jewellery/repairs?status=pending
GET /jewellery/repairs?customerId={id}
```

**Status Values:**
- `pending` - Job received
- `assessed` - Damage evaluated
- `approved` - Customer approved quote
- `inProgress` - Work ongoing
- `qualityCheck` - QC before delivery
- `ready` - Ready for pickup
- `delivered` - Delivered to customer
- `cancelled` - Cancelled
- `returned` - Returned for re-work

### Get Repair Job
```
GET /jewellery/repairs/{id}
```

### Update Repair Job
```
PUT /jewellery/repairs/{id}
```

### Update Repair Status
```
POST /jewellery/repairs/{id}/status
```

**Request Body:**
```json
{
  "status": "inProgress",
  "notes": "Started stone setting work"
}
```

### Get Repair Statistics
```
GET /jewellery/repairs/statistics
```

**Response:**
```json
{
  "data": {
    "totalJobs": 150,
    "pendingJobs": 25,
    "inProgressJobs": 40,
    "completedJobs": 80,
    "overdueJobs": 5,
    "totalRevenuePaisa": 12500000,
    "totalMaterialCostPaisa": 3000000,
    "totalLaborCostPaisa": 5000000
  }
}
```

---

## Gold Schemes

Gold savings plans and chit fund management.

### Create Gold Scheme
```
POST /jewellery/gold-schemes
```

**Request Body - Standard 11+1:**
```json
{
  "customerId": "customer-uuid",
  "customerName": "Priya Sharma",
  "customerPhone": "+91-98765-43210",
  "schemeName": "Monthly Gold Savings",
  "installmentAmountPaisa": 500000,
  "totalInstallments": 12,
  "frequency": "monthly",
  "bonusPercentage": 9.09,
  "bonusDescription": "Pay for 11 months, get 12th free",
  "plannedRedemptionType": "goldJewellery"
}
```

**Request Body - Gold Linked:**
```json
{
  "customerId": "customer-uuid",
  "customerName": "Amit Patel",
  "installmentAmountPaisa": 1000000,
  "totalInstallments": 12,
  "frequency": "monthly",
  "isGoldLinked": true,
  "linkedMetalType": "GOLD_22K",
  "minimumInstallmentsForRedemption": 6
}
```

**Frequencies:** `monthly`, `weekly`, `daily`

**Redemption Types:**
- `goldJewellery` - Buy jewellery
- `goldCoin` - Gold coins/bars
- `cashPayout` - Cash withdrawal
- `bankTransfer` - Bank transfer

### List Gold Schemes
```
GET /jewellery/gold-schemes
GET /jewellery/gold-schemes?status=active
GET /jewellery/gold-schemes?customerId={id}
```

### Get Gold Scheme
```
GET /jewellery/gold-schemes/{id}
```

### Update Gold Scheme
```
PUT /jewellery/gold-schemes/{id}
```

### Record Payment
```
POST /jewellery/gold-schemes/{id}/payments
```

**Request Body:**
```json
{
  "installmentNumber": 5,
  "paidAmountPaisa": 500000,
  "paymentMode": "Cash",
  "transactionId": "TXN123456",
  "notes": "Paid on time"
}
```

### Redeem Gold Scheme
```
POST /jewellery/gold-schemes/{id}/redeem
```

**Request Body - Jewellery:**
```json
{
  "redemptionType": "goldJewellery",
  "productId": "product-uuid",
  "productName": "22K Gold Necklace",
  "notes": "Customer selected from ready stock"
}
```

**Request Body - Cash:**
```json
{
  "redemptionType": "cashPayout",
  "bankAccountNumber": "1234567890",
  "bankIfsc": "HDFC0001234",
  "notes": "Payout to savings account"
}
```

---

## Common Response Format

### Success Response (200-299)
```json
{
  "status": "success",
  "code": 200,
  "message": "Operation successful",
  "success": true,
  "data": { ... },
  "meta": {
    "timestamp": "2024-01-15T10:00:00Z"
  }
}
```

### Error Response (400-599)
```json
{
  "status": "error",
  "code": 400,
  "message": "Validation failed",
  "success": false,
  "error": {
    "code": "BAD_REQUEST",
    "message": "Invalid input",
    "details": { ... }
  },
  "meta": {
    "timestamp": "2024-01-15T10:00:00Z"
  }
}
```

---

## Error Codes

| Code | HTTP | Description |
|------|------|-------------|
| `BAD_REQUEST` | 400 | Invalid request parameters |
| `UNAUTHORIZED` | 401 | Authentication required |
| `FORBIDDEN` | 403 | Insufficient permissions |
| `NOT_FOUND` | 404 | Resource not found |
| `CONFLICT` | 409 | Resource already exists |
| `INTERNAL_ERROR` | 500 | Server error |
| `SERVICE_UNAVAILABLE` | 503 | Service temporarily unavailable |
| `TOO_MANY_REQUESTS` | 429 | Rate limit exceeded |

---

## Data Types

### Monetary Values
All monetary values are in **paisa** (1 rupee = 100 paisa) as integers.

```json
{
  "amountPaisa": 50000,        // ₹500.00
  "ratePaisaPerGram": 650000   // ₹6,500/g
}
```

### Dates
All dates use ISO 8601 format in UTC.

```json
{
  "createdAt": "2024-01-15T10:00:00Z",
  "promisedDate": "2024-01-20T00:00:00Z"
}
```

### Enums
String values are case-sensitive. Use exact values from documentation.

---

## Rate Limiting

- Default: 500 requests/second per tenant
- Burst: 1000 requests
- Exceeding limits returns `429 Too Many Requests`

---

## WebSocket Events (Future)

Real-time updates for:
- `GOLD_RATE_ALERT_TRIGGERED` - When alert threshold crossed
- `REPAIR_STATUS_CHANGED` - When repair job status updates
- `SCHEME_PAYMENT_DUE` - When installment payment approaching

---

## SDK Example (Flutter)

```dart
// Create gold rate alert
final response = await apiClient.post(
  '/jewellery/gold-rate-alerts',
  body: {
    'metalType': 'GOLD_22K',
    'thresholdRatePaisaPerGram': 650000,
    'direction': 'above',
    'method': 'push',
  },
);

// Record scheme payment
final response = await apiClient.post(
  '/jewellery/gold-schemes/${schemeId}/payments',
  body: {
    'installmentNumber': 5,
    'paidAmountPaisa': 500000,
    'paymentMode': 'Cash',
  },
);
```

---

## Changelog

### v1.0.0 (2024-05-25)
- Initial release
- Gold Rate Alerts
- Making Charges Configs
- Repair Jobs
- Gold Schemes

---

**Support:** api-support@dukanx.com  
**Status Page:** status.dukanx.com
