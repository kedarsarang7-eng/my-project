class HardwareApiContract {
  static const createPurchaseOrder = '/hardware/purchase-orders';
  static const listPurchaseOrders = '/hardware/purchase-orders';
  static const updatePurchaseOrderStatus = '/hardware/purchase-orders/{id}/status';

  static const createGrn = '/hardware/grn';
  static const listGrn = '/hardware/grn';

  static const createPurchaseBill = '/hardware/purchase-bills';
  static const listPurchaseBills = '/hardware/purchase-bills';
  static const returnPurchaseBill = '/hardware/purchase-bills/{id}/return';

  static const createParty = '/hardware/parties';
  static const listParties = '/hardware/parties';
  static const partyLedger = '/hardware/parties/{id}/ledger';
  static const partiesAging = '/hardware/parties-aging';
  static const quickInvoice = '/hardware/pos/quick-invoice';
  static const invoiceProfiles = '/hardware/invoice-profiles';
  static const rateComparison = '/hardware/rate-comparison';
  static const pendingPurchaseOrders = '/hardware/purchase-orders/pending';
  static const salesOrders = '/hardware/sales-orders';
  static const salesOrderStatus = '/hardware/sales-orders/{id}/status';
  static const velocityReport = '/hardware/reports/item-velocity';
  static const deadStockReport = '/hardware/reports/dead-stock';
}

class HardwarePermissionMatrix {
  static const Map<String, Set<String>> moduleActions = {
    'pos': {'view', 'create', 'edit', 'delete', 'print'},
    'inventory': {'view', 'create', 'edit', 'delete'},
    'purchase': {'view', 'create', 'approve'},
    'suppliers': {'view', 'create'},
    'party_credit': {'view', 'create'},
    'gst': {'view', 'export'},
    'reports': {'view', 'export'},
    'settings': {'view', 'edit'},
  };
}
