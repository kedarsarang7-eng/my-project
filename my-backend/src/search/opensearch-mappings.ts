/**
 * OpenSearch Index Mappings for DukanX Multi-Tenant Search
 * 
 * Each business entity gets its own index with tenant-isolated search.
 * Fields are mapped for partial match, fuzzy match, and exact filtering.
 * 
 * @author DukanX Engineering
 * @version 1.0.0
 */

import { IndicesCreateRequest } from '@opensearch-project/opensearch/api/types';

// ============================================================================
// COMMON ANALYZERS & SETTINGS
// ============================================================================

const commonSettings = {
  index: {
    number_of_shards: 1,
    number_of_replicas: 0, // Adjust based on production needs
    refresh_interval: '5s', // Near real-time search
    max_result_window: 100000,
  },
  analysis: {
    analyzer: {
      // Standard analyzer for general text
      dukanx_standard: {
        type: 'custom',
        tokenizer: 'standard',
        filter: ['lowercase', 'asciifolding', 'trim'],
      },
      // Keyword analyzer for exact matches
      dukanx_keyword: {
        type: 'custom',
        tokenizer: 'keyword',
        filter: ['lowercase', 'trim'],
      },
      // N-gram analyzer for partial/prefix matches
      dukanx_ngram: {
        type: 'custom',
        tokenizer: 'dukanx_ngram_tokenizer',
        filter: ['lowercase', 'asciifolding'],
      },
      // Edge n-gram for autocomplete
      dukanx_edge_ngram: {
        type: 'custom',
        tokenizer: 'dukanx_edge_tokenizer',
        filter: ['lowercase', 'asciifolding'],
      },
    },
    tokenizer: {
      dukanx_ngram_tokenizer: {
        type: 'ngram',
        min_gram: 2,
        max_gram: 10,
        token_chars: ['letter', 'digit'],
      },
      dukanx_edge_tokenizer: {
        type: 'edge_ngram',
        min_gram: 1,
        max_gram: 20,
        token_chars: ['letter', 'digit'],
      },
    },
    filter: {
      // Fuzzy match filter for typo tolerance
      dukanx_fuzzy: {
        type: 'phonetic',
        encoder: 'double_metaphone',
        replace: false,
      },
    },
  },
};

// Common field mappings
const tenantIdField = {
  type: 'keyword' as const,
  index: true,
  store: true,
};

const businessIdField = {
  type: 'keyword' as const,
  index: true,
};

const businessTypeField = {
  type: 'keyword' as const,
  index: true,
};

const createdAtField = {
  type: 'date' as const,
  format: 'strict_date_optional_time||epoch_millis',
  index: true,
};

const updatedAtField = {
  type: 'date' as const,
  format: 'strict_date_optional_time||epoch_millis',
  index: true,
};

const searchableTextField = {
  type: 'text' as const,
  analyzer: 'dukanx_standard',
  fields: {
    keyword: {
      type: 'keyword',
      ignore_above: 256,
    },
    ngram: {
      type: 'text',
      analyzer: 'dukanx_ngram',
      search_analyzer: 'dukanx_standard',
    },
    edge: {
      type: 'text',
      analyzer: 'dukanx_edge_ngram',
      search_analyzer: 'dukanx_standard',
    },
  },
};

// ============================================================================
// ENTITY-SPECIFIC INDEX MAPPINGS
// ============================================================================

/**
 * Bills/Invoices Index Mapping
 * Search fields: customerName, invoiceNumber, status, date, amount
 */
export const billsIndexMapping: IndicesCreateRequest = {
  index: 'dukanx-bills',
  body: {
    settings: commonSettings,
    mappings: {
      dynamic: 'strict',
      properties: {
        // Tenant isolation (REQUIRED for all queries)
        tenantId: tenantIdField,
        businessId: businessIdField,
        businessType: businessTypeField,
        
        // Core bill fields
        billId: { type: 'keyword', index: true },
        invoiceNumber: {
          type: 'text',
          analyzer: 'dukanx_standard',
          fields: {
            keyword: { type: 'keyword' },
            edge: { type: 'text', analyzer: 'dukanx_edge_ngram' },
          },
        },
        customerId: { type: 'keyword', index: true },
        customerName: searchableTextField,
        customerPhone: {
          type: 'keyword',
          fields: {
            text: { type: 'text', analyzer: 'dukanx_standard' },
          },
        },
        customerGstin: { type: 'keyword', index: true },
        
        // Amount fields for range queries
        subtotal: { type: 'scaled_float', scaling_factor: 100 },
        taxAmount: { type: 'scaled_float', scaling_factor: 100 },
        discountAmount: { type: 'scaled_float', scaling_factor: 100 },
        grandTotal: { type: 'scaled_float', scaling_factor: 100 },
        paidAmount: { type: 'scaled_float', scaling_factor: 100 },
        
        // Status and dates
        status: { type: 'keyword', index: true },
        paymentMode: { type: 'keyword', index: true },
        billDate: createdAtField,
        dueDate: { type: 'date', format: 'strict_date_optional_time||epoch_millis' },
        
        // Business-specific fields
        tableNumber: { type: 'keyword', index: true },
        vehicleNumber: {
          type: 'text',
          analyzer: 'dukanx_standard',
          fields: { keyword: { type: 'keyword' } },
        },
        prescriptionId: { type: 'keyword', index: true },
        shiftId: { type: 'keyword', index: true },
        kotId: { type: 'keyword', index: true },
        
        // Items summary for search
        itemNames: { type: 'text', analyzer: 'dukanx_standard' },
        itemSkus: { type: 'keyword', index: true },
        
        // Timestamps
        createdAt: createdAtField,
        updatedAt: updatedAtField,
        deletedAt: { type: 'date', format: 'strict_date_optional_time||epoch_millis' },
        
        // Source tracking
        source: { type: 'keyword', index: true },
        isEInvoice: { type: 'boolean' },
        irn: { type: 'keyword', index: true },
      },
    },
  },
};

/**
 * Customers Index Mapping
 * Search fields: name, phone, email, address, gstin
 */
export const customersIndexMapping: IndicesCreateRequest = {
  index: 'dukanx-customers',
  body: {
    settings: commonSettings,
    mappings: {
      dynamic: 'strict',
      properties: {
        tenantId: tenantIdField,
        businessId: businessIdField,
        businessType: businessTypeField,
        
        customerId: { type: 'keyword', index: true },
        name: searchableTextField,
        phone: {
          type: 'keyword',
          fields: {
            text: { type: 'text', analyzer: 'dukanx_standard' },
            edge: { type: 'text', analyzer: 'dukanx_edge_ngram' },
          },
        },
        email: {
          type: 'keyword',
          fields: {
            text: { type: 'text', analyzer: 'dukanx_standard' },
          },
        },
        address: searchableTextField,
        gstin: {
          type: 'keyword',
          fields: {
            text: { type: 'text', analyzer: 'dukanx_standard' },
          },
        },
        stateCode: { type: 'keyword', index: true },
        
        // Financial summary (for quick reference)
        totalDues: { type: 'scaled_float', scaling_factor: 100 },
        totalBilled: { type: 'scaled_float', scaling_factor: 100 },
        totalPaid: { type: 'scaled_float', scaling_factor: 100 },
        creditLimit: { type: 'scaled_float', scaling_factor: 100 },
        
        // Status
        isActive: { type: 'boolean' },
        isBlacklisted: { type: 'boolean' },
        isBlocked: { type: 'boolean' },
        
        // Petrol pump specific
        vehicleNumber: {
          type: 'text',
          analyzer: 'dukanx_standard',
          fields: { keyword: { type: 'keyword' } },
        },
        
        // Book store
        loyaltyPoints: { type: 'integer' },
        
        // Linking
        linkStatus: { type: 'keyword', index: true },
        
        createdAt: createdAtField,
        updatedAt: updatedAtField,
        lastTransactionDate: { type: 'date', format: 'strict_date_optional_time||epoch_millis' },
      },
    },
  },
};

/**
 * Products/Inventory Index Mapping
 * Search fields: name, sku, barcode, category, brand
 */
export const productsIndexMapping: IndicesCreateRequest = {
  index: 'dukanx-products',
  body: {
    settings: commonSettings,
    mappings: {
      dynamic: 'strict',
      properties: {
        tenantId: tenantIdField,
        businessId: businessIdField,
        businessType: businessTypeField,
        
        productId: { type: 'keyword', index: true },
        name: searchableTextField,
        sku: {
          type: 'keyword',
          fields: {
            text: { type: 'text', analyzer: 'dukanx_edge_ngram' },
          },
        },
        barcode: {
          type: 'keyword',
          fields: {
            text: { type: 'text', analyzer: 'dukanx_standard' },
          },
        },
        altBarcodes: { type: 'keyword', index: true },
        
        // Classification
        category: { type: 'keyword', index: true },
        subCategory: { type: 'keyword', index: true },
        brand: {
          type: 'text',
          analyzer: 'dukanx_standard',
          fields: { keyword: { type: 'keyword' } },
        },
        type: { type: 'keyword', index: true }, // goods, service
        
        // Pricing
        sellingPrice: { type: 'scaled_float', scaling_factor: 100 },
        costPrice: { type: 'scaled_float', scaling_factor: 100 },
        mrp: { type: 'scaled_float', scaling_factor: 100 },
        
        // GST
        hsnCode: { type: 'keyword', index: true },
        gstRate: { type: 'float' },
        
        // Stock
        stockQuantity: { type: 'float' },
        lowStockThreshold: { type: 'float' },
        unit: { type: 'keyword', index: true },
        baseUnit: { type: 'keyword', index: true },
        
        // Clothing specific
        size: { type: 'keyword', index: true },
        color: { type: 'keyword', index: true },
        groupId: { type: 'keyword', index: true },
        
        // Medical specific
        drugSchedule: { type: 'keyword', index: true },
        
        // Book store
        isbn: {
          type: 'keyword',
          fields: {
            text: { type: 'text', analyzer: 'dukanx_standard' },
          },
        },
        author: searchableTextField,
        publisher: searchableTextField,
        
        // Jewellery
        purity: { type: 'keyword', index: true },
        metalWeight: { type: 'float' },
        makingCharges: { type: 'scaled_float', scaling_factor: 100 },
        hallmark: { type: 'keyword', index: true },
        
        // Electronics
        imei: { type: 'keyword', index: true },
        serialNumber: { type: 'keyword', index: true },
        warrantyMonths: { type: 'integer' },
        
        // Status
        isActive: { type: 'boolean' },
        isLowStock: { type: 'boolean' },
        
        // Variant linking
        variantAttributes: { type: 'object', enabled: false },
        
        createdAt: createdAtField,
        updatedAt: updatedAtField,
      },
    },
  },
};

/**
 * Product Batches Index Mapping (Pharmacy, Wholesale)
 * Search fields: batchNumber, productName, expiryDate
 */
export const productBatchesIndexMapping: IndicesCreateRequest = {
  index: 'dukanx-product-batches',
  body: {
    settings: commonSettings,
    mappings: {
      dynamic: 'strict',
      properties: {
        tenantId: tenantIdField,
        businessId: businessIdField,
        
        batchId: { type: 'keyword', index: true },
        productId: { type: 'keyword', index: true },
        productName: searchableTextField,
        
        batchNumber: {
          type: 'text',
          analyzer: 'dukanx_standard',
          fields: {
            keyword: { type: 'keyword' },
            edge: { type: 'text', analyzer: 'dukanx_edge_ngram' },
          },
        },
        
        // Dates
        manufactureDate: { type: 'date', format: 'strict_date_optional_time||epoch_millis' },
        expiryDate: { type: 'date', format: 'strict_date_optional_time||epoch_millis' },
        
        // Stock
        quantity: { type: 'float' },
        availableQuantity: { type: 'float' },
        unit: { type: 'keyword', index: true },
        
        // Pricing
        purchasePrice: { type: 'scaled_float', scaling_factor: 100 },
        sellingPrice: { type: 'scaled_float', scaling_factor: 100 },
        
        // Medical
        drugSchedule: { type: 'keyword', index: true },
        
        // Status
        isExpired: { type: 'boolean' },
        isNearExpiry: { type: 'boolean' },
        isActive: { type: 'boolean' },
        
        // FEFO priority (for pharmacy)
        fefoPriority: { type: 'integer' },
        
        createdAt: createdAtField,
        updatedAt: updatedAtField,
      },
    },
  },
};

/**
 * Suppliers/Vendors Index Mapping
 * Search fields: name, phone, email, gstin
 */
export const suppliersIndexMapping: IndicesCreateRequest = {
  index: 'dukanx-suppliers',
  body: {
    settings: commonSettings,
    mappings: {
      dynamic: 'strict',
      properties: {
        tenantId: tenantIdField,
        businessId: businessIdField,
        
        supplierId: { type: 'keyword', index: true },
        name: searchableTextField,
        phone: {
          type: 'keyword',
          fields: {
            text: { type: 'text', analyzer: 'dukanx_standard' },
          },
        },
        email: {
          type: 'keyword',
          fields: {
            text: { type: 'text', analyzer: 'dukanx_standard' },
          },
        },
        address: searchableTextField,
        gstin: {
          type: 'keyword',
          fields: {
            text: { type: 'text', analyzer: 'dukanx_standard' },
          },
        },
        pan: { type: 'keyword', index: true },
        
        // Bank details
        bankName: { type: 'keyword', index: true },
        accountNumber: { type: 'keyword', index: true },
        ifscCode: { type: 'keyword', index: true },
        upiId: { type: 'keyword', index: true },
        
        // Financial
        totalPurchased: { type: 'scaled_float', scaling_factor: 100 },
        totalPaid: { type: 'scaled_float', scaling_factor: 100 },
        totalOutstanding: { type: 'scaled_float', scaling_factor: 100 },
        creditDays: { type: 'integer' },
        creditLimit: { type: 'scaled_float', scaling_factor: 100 },
        
        // Status
        isActive: { type: 'boolean' },
        
        createdAt: createdAtField,
        updatedAt: updatedAtField,
      },
    },
  },
};

/**
 * Purchase Bills Index Mapping
 * Search fields: billNumber, supplierName, date, amount
 */
export const purchaseBillsIndexMapping: IndicesCreateRequest = {
  index: 'dukanx-purchase-bills',
  body: {
    settings: commonSettings,
    mappings: {
      dynamic: 'strict',
      properties: {
        tenantId: tenantIdField,
        businessId: businessIdField,
        
        purchaseBillId: { type: 'keyword', index: true },
        billNumber: {
          type: 'text',
          analyzer: 'dukanx_standard',
          fields: {
            keyword: { type: 'keyword' },
            edge: { type: 'text', analyzer: 'dukanx_edge_ngram' },
          },
        },
        
        supplierId: { type: 'keyword', index: true },
        supplierName: searchableTextField,
        supplierPhone: { type: 'keyword', index: true },
        supplierGstin: { type: 'keyword', index: true },
        
        // Amounts
        subtotal: { type: 'scaled_float', scaling_factor: 100 },
        totalTax: { type: 'scaled_float', scaling_factor: 100 },
        grandTotal: { type: 'scaled_float', scaling_factor: 100 },
        paidAmount: { type: 'scaled_float', scaling_factor: 100 },
        pendingAmount: { type: 'scaled_float', scaling_factor: 100 },
        
        // Status
        status: { type: 'keyword', index: true },
        paymentMode: { type: 'keyword', index: true },
        
        // Dates
        date: createdAtField,
        dueDate: { type: 'date', format: 'strict_date_optional_time||epoch_millis' },
        
        // Items summary
        itemNames: { type: 'text', analyzer: 'dukanx_standard' },
        itemIds: { type: 'keyword', index: true },
        
        createdAt: createdAtField,
        updatedAt: updatedAtField,
      },
    },
  },
};

/**
 * Patients Index Mapping (Clinic, Pharmacy)
 * Search fields: name, phone, emergency contact
 */
export const patientsIndexMapping: IndicesCreateRequest = {
  index: 'dukanx-patients',
  body: {
    settings: commonSettings,
    mappings: {
      dynamic: 'strict',
      properties: {
        tenantId: tenantIdField,
        businessId: businessIdField,
        
        patientId: { type: 'keyword', index: true },
        customerId: { type: 'keyword', index: true },
        name: searchableTextField,
        phone: {
          type: 'keyword',
          fields: {
            text: { type: 'text', analyzer: 'dukanx_standard' },
          },
        },
        
        // Demographics
        age: { type: 'integer' },
        gender: { type: 'keyword', index: true },
        bloodGroup: { type: 'keyword', index: true },
        
        // Medical
        allergies: { type: 'text', analyzer: 'dukanx_standard' },
        chronicConditions: { type: 'text', analyzer: 'dukanx_standard' },
        
        // Emergency contact
        emergencyContactName: searchableTextField,
        emergencyContactPhone: { type: 'keyword', index: true },
        
        // Links
        lastVisitId: { type: 'keyword', index: true },
        lastVisitDate: { type: 'date', format: 'strict_date_optional_time||epoch_millis' },
        
        createdAt: createdAtField,
        updatedAt: updatedAtField,
      },
    },
  },
};

/**
 * Visits Index Mapping (Clinic)
 * Search fields: chiefComplaint, diagnosis, symptoms, patient name
 */
export const visitsIndexMapping: IndicesCreateRequest = {
  index: 'dukanx-visits',
  body: {
    settings: commonSettings,
    mappings: {
      dynamic: 'strict',
      properties: {
        tenantId: tenantIdField,
        businessId: businessIdField,
        
        visitId: { type: 'keyword', index: true },
        patientId: { type: 'keyword', index: true },
        patientName: searchableTextField,
        doctorId: { type: 'keyword', index: true },
        doctorName: searchableTextField,
        
        // Clinical data
        chiefComplaint: searchableTextField,
        diagnosis: searchableTextField,
        symptoms: { type: 'text', analyzer: 'dukanx_standard' },
        notes: { type: 'text', analyzer: 'dukanx_standard' },
        
        // Vitals
        bp: { type: 'keyword', index: true },
        temperature: { type: 'float' },
        weight: { type: 'float' },
        pulse: { type: 'integer' },
        spO2: { type: 'integer' },
        
        // Links
        prescriptionId: { type: 'keyword', index: true },
        billId: { type: 'keyword', index: true },
        
        // Status
        status: { type: 'keyword', index: true },
        
        // Dates
        visitDate: createdAtField,
        
        createdAt: createdAtField,
        updatedAt: updatedAtField,
      },
    },
  },
};

/**
 * Prescriptions Index Mapping
 * Search fields: patient name, medicines, doctor
 */
export const prescriptionsIndexMapping: IndicesCreateRequest = {
  index: 'dukanx-prescriptions',
  body: {
    settings: commonSettings,
    mappings: {
      dynamic: 'strict',
      properties: {
        tenantId: tenantIdField,
        businessId: businessIdField,
        
        prescriptionId: { type: 'keyword', index: true },
        visitId: { type: 'keyword', index: true },
        patientId: { type: 'keyword', index: true },
        patientName: searchableTextField,
        doctorId: { type: 'keyword', index: true },
        doctorName: searchableTextField,
        
        // Medicines
        medicines: { type: 'text', analyzer: 'dukanx_standard' },
        medicineNames: { type: 'text', analyzer: 'dukanx_standard' },
        
        // Advice
        advice: { type: 'text', analyzer: 'dukanx_standard' },
        nextVisitDate: { type: 'date', format: 'strict_date_optional_time||epoch_millis' },
        
        // Date
        date: createdAtField,
        
        createdAt: createdAtField,
        updatedAt: updatedAtField,
      },
    },
  },
};

/**
 * KOTs Index Mapping (Restaurant)
 * Search fields: table number, status, items
 */
export const kotsIndexMapping: IndicesCreateRequest = {
  index: 'dukanx-kots',
  body: {
    settings: commonSettings,
    mappings: {
      dynamic: 'strict',
      properties: {
        tenantId: tenantIdField,
        businessId: businessIdField,
        
        kotId: { type: 'keyword', index: true },
        billId: { type: 'keyword', index: true },
        
        // Table info
        tableNumber: {
          type: 'text',
          analyzer: 'dukanx_standard',
          fields: { keyword: { type: 'keyword' } },
        },
        section: { type: 'keyword', index: true },
        
        // Order details
        itemNames: { type: 'text', analyzer: 'dukanx_standard' },
        itemCount: { type: 'integer' },
        totalAmount: { type: 'scaled_float', scaling_factor: 100 },
        
        // Status
        status: { type: 'keyword', index: true },
        priority: { type: 'keyword', index: true },
        
        // Staff
        waiterId: { type: 'keyword', index: true },
        waiterName: searchableTextField,
        
        // Timestamps
        orderTime: createdAtField,
        preparationTime: { type: 'date', format: 'strict_date_optional_time||epoch_millis' },
        completionTime: { type: 'date', format: 'strict_date_optional_time||epoch_millis' },
        
        createdAt: createdAtField,
        updatedAt: updatedAtField,
      },
    },
  },
};

/**
 * Menu Items Index Mapping (Restaurant)
 * Search fields: name, category, description
 */
export const menuItemsIndexMapping: IndicesCreateRequest = {
  index: 'dukanx-menu-items',
  body: {
    settings: commonSettings,
    mappings: {
      dynamic: 'strict',
      properties: {
        tenantId: tenantIdField,
        businessId: businessIdField,
        
        menuItemId: { type: 'keyword', index: true },
        name: searchableTextField,
        description: searchableTextField,
        
        // Classification
        category: { type: 'keyword', index: true },
        subCategory: { type: 'keyword', index: true },
        cuisine: { type: 'keyword', index: true },
        
        // Pricing
        price: { type: 'scaled_float', scaling_factor: 100 },
        discountedPrice: { type: 'scaled_float', scaling_factor: 100 },
        
        // Dietary
        isVeg: { type: 'boolean' },
        isVegan: { type: 'boolean' },
        isGlutenFree: { type: 'boolean' },
        spiceLevel: { type: 'keyword', index: true },
        
        // Availability
        isAvailable: { type: 'boolean' },
        isActive: { type: 'boolean' },
        
        // Ingredients (for allergen search)
        ingredients: { type: 'text', analyzer: 'dukanx_standard' },
        allergens: { type: 'keyword', index: true },
        
        createdAt: createdAtField,
        updatedAt: updatedAtField,
      },
    },
  },
};

/**
 * Ledger Entries Index Mapping
 * Search fields: account name, description, reference
 */
export const ledgerEntriesIndexMapping: IndicesCreateRequest = {
  index: 'dukanx-ledger-entries',
  body: {
    settings: commonSettings,
    mappings: {
      dynamic: 'strict',
      properties: {
        tenantId: tenantIdField,
        businessId: businessIdField,
        
        entryId: { type: 'keyword', index: true },
        ledgerId: { type: 'keyword', index: true },
        ledgerName: searchableTextField,
        ledgerType: { type: 'keyword', index: true },
        ledgerGroup: { type: 'keyword', index: true },
        
        // Transaction
        referenceId: { type: 'keyword', index: true },
        referenceType: { type: 'keyword', index: true },
        description: searchableTextField,
        
        // Amounts
        debit: { type: 'scaled_float', scaling_factor: 100 },
        credit: { type: 'scaled_float', scaling_factor: 100 },
        amount: { type: 'scaled_float', scaling_factor: 100 },
        
        // Balance
        runningBalance: { type: 'scaled_float', scaling_factor: 100 },
        
        // Party info (for party ledgers)
        partyId: { type: 'keyword', index: true },
        partyName: searchableTextField,
        
        // Date
        transactionDate: createdAtField,
        
        createdAt: createdAtField,
        updatedAt: updatedAtField,
      },
    },
  },
};

/**
 * Expenses Index Mapping
 * Search fields: description, category, vendor
 */
export const expensesIndexMapping: IndicesCreateRequest = {
  index: 'dukanx-expenses',
  body: {
    settings: commonSettings,
    mappings: {
      dynamic: 'strict',
      properties: {
        tenantId: tenantIdField,
        businessId: businessIdField,
        
        expenseId: { type: 'keyword', index: true },
        category: { type: 'keyword', index: true },
        description: searchableTextField,
        
        // Vendor
        vendorName: searchableTextField,
        vendorId: { type: 'keyword', index: true },
        
        // Amount
        amount: { type: 'scaled_float', scaling_factor: 100 },
        
        // Payment
        paymentMode: { type: 'keyword', index: true },
        referenceNumber: { type: 'keyword', index: true },
        
        // Receipt
        hasReceipt: { type: 'boolean' },
        receiptUrl: { type: 'keyword', index: false },
        
        // Date
        expenseDate: createdAtField,
        
        createdAt: createdAtField,
        updatedAt: updatedAtField,
      },
    },
  },
};

/**
 * Bank Transactions Index Mapping
 * Search fields: description, reference, account
 */
export const bankTransactionsIndexMapping: IndicesCreateRequest = {
  index: 'dukanx-bank-transactions',
  body: {
    settings: commonSettings,
    mappings: {
      dynamic: 'strict',
      properties: {
        tenantId: tenantIdField,
        businessId: businessIdField,
        
        transactionId: { type: 'keyword', index: true },
        accountId: { type: 'keyword', index: true },
        accountName: searchableTextField,
        
        // Transaction details
        type: { type: 'keyword', index: true }, // CREDIT, DEBIT
        category: { type: 'keyword', index: true },
        description: searchableTextField,
        
        // Amount
        amount: { type: 'scaled_float', scaling_factor: 100 },
        
        // Reference
        referenceId: { type: 'keyword', index: true },
        referenceType: { type: 'keyword', index: true },
        
        // Running balance
        balance: { type: 'scaled_float', scaling_factor: 100 },
        
        // Date
        transactionDate: createdAtField,
        
        createdAt: createdAtField,
        updatedAt: updatedAtField,
      },
    },
  },
};

/**
 * Delivery Challans Index Mapping
 * Search fields: challan number, customer, e-way bill
 */
export const deliveryChallansIndexMapping: IndicesCreateRequest = {
  index: 'dukanx-delivery-challans',
  body: {
    settings: commonSettings,
    mappings: {
      dynamic: 'strict',
      properties: {
        tenantId: tenantIdField,
        businessId: businessIdField,
        
        challanId: { type: 'keyword', index: true },
        challanNumber: {
          type: 'text',
          analyzer: 'dukanx_standard',
          fields: {
            keyword: { type: 'keyword' },
            edge: { type: 'text', analyzer: 'dukanx_edge_ngram' },
          },
        },
        
        // Customer
        customerId: { type: 'keyword', index: true },
        customerName: searchableTextField,
        
        // Amounts
        subtotal: { type: 'scaled_float', scaling_factor: 100 },
        taxAmount: { type: 'scaled_float', scaling_factor: 100 },
        grandTotal: { type: 'scaled_float', scaling_factor: 100 },
        
        // Transport
        transportMode: { type: 'keyword', index: true },
        vehicleNumber: {
          type: 'text',
          analyzer: 'dukanx_standard',
          fields: { keyword: { type: 'keyword' } },
        },
        eWayBillNumber: {
          type: 'keyword',
          fields: {
            text: { type: 'text', analyzer: 'dukanx_standard' },
          },
        },
        
        // Status
        status: { type: 'keyword', index: true },
        
        // Links
        convertedBillId: { type: 'keyword', index: true },
        
        // Dates
        challanDate: createdAtField,
        dueDate: { type: 'date', format: 'strict_date_optional_time||epoch_millis' },
        
        // Items
        itemNames: { type: 'text', analyzer: 'dukanx_standard' },
        
        createdAt: createdAtField,
        updatedAt: updatedAtField,
      },
    },
  },
};

/**
 * Book Returns Index Mapping
 * Search fields: ISBN, title, vendor
 */
export const bookReturnsIndexMapping: IndicesCreateRequest = {
  index: 'dukanx-book-returns',
  body: {
    settings: commonSettings,
    mappings: {
      dynamic: 'strict',
      properties: {
        tenantId: tenantIdField,
        businessId: businessIdField,
        
        returnId: { type: 'keyword', index: true },
        
        // Vendor
        vendorId: { type: 'keyword', index: true },
        vendorName: searchableTextField,
        
        // Items
        isbns: {
          type: 'keyword',
          fields: {
            text: { type: 'text', analyzer: 'dukanx_standard' },
          },
        },
        titles: { type: 'text', analyzer: 'dukanx_standard' },
        itemCount: { type: 'integer' },
        
        // Amount
        totalAmount: { type: 'scaled_float', scaling_factor: 100 },
        
        // Status
        status: { type: 'keyword', index: true },
        
        // Dates
        returnDate: createdAtField,
        
        createdAt: createdAtField,
        updatedAt: updatedAtField,
      },
    },
  },
};

/**
 * Pre-orders Index Mapping
 * Search fields: customer, product, status
 */
export const preOrdersIndexMapping: IndicesCreateRequest = {
  index: 'dukanx-pre-orders',
  body: {
    settings: commonSettings,
    mappings: {
      dynamic: 'strict',
      properties: {
        tenantId: tenantIdField,
        businessId: businessIdField,
        
        preOrderId: { type: 'keyword', index: true },
        
        // Customer
        customerId: { type: 'keyword', index: true },
        customerName: searchableTextField,
        customerPhone: { type: 'keyword', index: true },
        
        // Product
        productId: { type: 'keyword', index: true },
        productName: searchableTextField,
        
        // Quantity & Amount
        quantity: { type: 'float' },
        advanceAmount: { type: 'scaled_float', scaling_factor: 100 },
        totalAmount: { type: 'scaled_float', scaling_factor: 100 },
        
        // Status
        status: { type: 'keyword', index: true },
        priority: { type: 'keyword', index: true },
        
        // Expected date
        expectedDate: { type: 'date', format: 'strict_date_optional_time||epoch_millis' },
        
        // Notes
        notes: { type: 'text', analyzer: 'dukanx_standard' },
        
        createdAt: createdAtField,
        updatedAt: updatedAtField,
      },
    },
  },
};

/**
 * Service Jobs Index Mapping
 * Search fields: customer, vehicle, problem description
 */
export const serviceJobsIndexMapping: IndicesCreateRequest = {
  index: 'dukanx-service-jobs',
  body: {
    settings: commonSettings,
    mappings: {
      dynamic: 'strict',
      properties: {
        tenantId: tenantIdField,
        businessId: businessIdField,
        businessType: businessTypeField,
        
        jobId: { type: 'keyword', index: true },
        jobNumber: {
          type: 'text',
          analyzer: 'dukanx_standard',
          fields: {
            keyword: { type: 'keyword' },
            edge: { type: 'text', analyzer: 'dukanx_edge_ngram' },
          },
        },
        
        // Customer
        customerId: { type: 'keyword', index: true },
        customerName: searchableTextField,
        customerPhone: { type: 'keyword', index: true },
        
        // Vehicle/Device
        vehicleNumber: {
          type: 'text',
          analyzer: 'dukanx_standard',
          fields: { keyword: { type: 'keyword' } },
        },
        vehicleModel: searchableTextField,
        imei: { type: 'keyword', index: true },
        serialNumber: { type: 'keyword', index: true },
        
        // Problem
        problemDescription: searchableTextField,
        diagnosedIssue: searchableTextField,
        
        // Status
        status: { type: 'keyword', index: true },
        priority: { type: 'keyword', index: true },
        
        // Amounts
        estimatedCost: { type: 'scaled_float', scaling_factor: 100 },
        partsCost: { type: 'scaled_float', scaling_factor: 100 },
        laborCharge: { type: 'scaled_float', scaling_factor: 100 },
        totalAmount: { type: 'scaled_float', scaling_factor: 100 },
        
        // Technician
        assignedTo: { type: 'keyword', index: true },
        technicianName: searchableTextField,
        
        // Dates
        receivedDate: createdAtField,
        promisedDate: { type: 'date', format: 'strict_date_optional_time||epoch_millis' },
        completedDate: { type: 'date', format: 'strict_date_optional_time||epoch_millis' },
        
        createdAt: createdAtField,
        updatedAt: updatedAtField,
      },
    },
  },
};

/**
 * E-Invoices Index Mapping
 * Search fields: IRN, invoice number, customer
 */
export const eInvoicesIndexMapping: IndicesCreateRequest = {
  index: 'dukanx-einvoices',
  body: {
    settings: commonSettings,
    mappings: {
      dynamic: 'strict',
      properties: {
        tenantId: tenantIdField,
        businessId: businessIdField,
        
        eInvoiceId: { type: 'keyword', index: true },
        irn: {
          type: 'keyword',
          fields: {
            text: { type: 'text', analyzer: 'dukanx_standard' },
          },
        },
        ackNo: { type: 'keyword', index: true },
        
        // Link to bill
        billId: { type: 'keyword', index: true },
        invoiceNumber: {
          type: 'text',
          analyzer: 'dukanx_standard',
          fields: {
            keyword: { type: 'keyword' },
            edge: { type: 'text', analyzer: 'dukanx_edge_ngram' },
          },
        },
        
        // Customer
        customerGstin: { type: 'keyword', index: true },
        customerName: searchableTextField,
        
        // Amounts
        taxableAmount: { type: 'scaled_float', scaling_factor: 100 },
        cgst: { type: 'scaled_float', scaling_factor: 100 },
        sgst: { type: 'scaled_float', scaling_factor: 100 },
        igst: { type: 'scaled_float', scaling_factor: 100 },
        totalAmount: { type: 'scaled_float', scaling_factor: 100 },
        
        // Status
        status: { type: 'keyword', index: true },
        
        // GST Portal response
        gstPortalStatus: { type: 'keyword', index: true },
        
        // Dates
        invoiceDate: createdAtField,
        ackDate: { type: 'date', format: 'strict_date_optional_time||epoch_millis' },
        
        createdAt: createdAtField,
        updatedAt: updatedAtField,
      },
    },
  },
};

/**
 * Fuel Transactions Index Mapping (Petrol Pump)
 * Search fields: vehicle number, fuel type, dispenser
 */
export const fuelTransactionsIndexMapping: IndicesCreateRequest = {
  index: 'dukanx-fuel-transactions',
  body: {
    settings: commonSettings,
    mappings: {
      dynamic: 'strict',
      properties: {
        tenantId: tenantIdField,
        businessId: businessIdField,
        
        transactionId: { type: 'keyword', index: true },
        billId: { type: 'keyword', index: true },
        
        // Shift/Dispenser
        shiftId: { type: 'keyword', index: true },
        dispenserId: { type: 'keyword', index: true },
        dispenserName: { type: 'keyword', index: true },
        nozzleId: { type: 'keyword', index: true },
        nozzleName: { type: 'keyword', index: true },
        
        // Fuel
        fuelType: { type: 'keyword', index: true },
        fuelTypeId: { type: 'keyword', index: true },
        
        // Quantity
        litres: { type: 'float' },
        pricePerLitre: { type: 'scaled_float', scaling_factor: 100 },
        
        // Amounts
        amount: { type: 'scaled_float', scaling_factor: 100 },
        discount: { type: 'scaled_float', scaling_factor: 100 },
        totalAmount: { type: 'scaled_float', scaling_factor: 100 },
        
        // Vehicle
        vehicleNumber: {
          type: 'text',
          analyzer: 'dukanx_standard',
          fields: { keyword: { type: 'keyword' } },
        },
        driverName: searchableTextField,
        
        // Payment
        paymentMode: { type: 'keyword', index: true },
        
        // Readings
        pumpReadingStart: { type: 'float' },
        pumpReadingEnd: { type: 'float' },
        
        // Attendant
        attendantId: { type: 'keyword', index: true },
        attendantName: searchableTextField,
        
        // Date
        transactionDate: createdAtField,
        
        createdAt: createdAtField,
        updatedAt: updatedAtField,
      },
    },
  },
};

// ============================================================================
// INDEX REGISTRY
// ============================================================================

export const searchIndexes = {
  bills: billsIndexMapping,
  customers: customersIndexMapping,
  products: productsIndexMapping,
  productBatches: productBatchesIndexMapping,
  suppliers: suppliersIndexMapping,
  purchaseBills: purchaseBillsIndexMapping,
  patients: patientsIndexMapping,
  visits: visitsIndexMapping,
  prescriptions: prescriptionsIndexMapping,
  kots: kotsIndexMapping,
  menuItems: menuItemsIndexMapping,
  ledgerEntries: ledgerEntriesIndexMapping,
  expenses: expensesIndexMapping,
  bankTransactions: bankTransactionsIndexMapping,
  deliveryChallans: deliveryChallansIndexMapping,
  bookReturns: bookReturnsIndexMapping,
  preOrders: preOrdersIndexMapping,
  serviceJobs: serviceJobsIndexMapping,
  eInvoices: eInvoicesIndexMapping,
  fuelTransactions: fuelTransactionsIndexMapping,
};

export type SearchIndexName = keyof typeof searchIndexes;

// ============================================================================
// INDEX NAME HELPER
// ============================================================================

/**
 * Get the OpenSearch index name for an entity type
 * Includes environment prefix for isolation
 */
export function getIndexName(entityType: SearchIndexName, environment: string = 'dev'): string {
  const baseIndex = searchIndexes[entityType].index;
  return `${environment}-${baseIndex}`;
}

/**
 * Get all index names for a bulk operation
 */
export function getAllIndexNames(environment: string = 'dev'): string[] {
  return Object.keys(searchIndexes).map(key => 
    getIndexName(key as SearchIndexName, environment)
  );
}
