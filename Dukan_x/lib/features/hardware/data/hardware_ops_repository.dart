import 'package:dukanx/core/api/api_client.dart';
import 'package:dukanx/core/di/service_locator.dart';
import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/isolation/feature_resolver.dart';
import 'package:dukanx/core/session/session_manager.dart';
import 'hardware_phase12_contracts.dart';

/// Surface-area exception used to bubble actionable failures out of the
/// hardware operations repository.
///
/// Previously this repository swallowed every API failure and returned an
/// empty list, which silently broke critical workflows (PO listings, deposit
/// settlements, project closure, etc.) and made the UI indistinguishable
/// between "no data" and "the server returned 4xx/5xx".
///
/// Callers should wrap the repository methods in try/catch and surface this
/// exception's [message] to the user, so operators can take corrective action
/// (retry, contact support, fix permissions, …).
class HardwareOpsException implements Exception {
  final String operation;
  final String message;
  final int? statusCode;

  HardwareOpsException(this.operation, this.message, {this.statusCode});

  @override
  String toString() =>
      'HardwareOpsException[$operation${statusCode != null ? ' · $statusCode' : ''}]: $message';
}

class HardwareOpsRepository {
  ApiClient get _api => sl<ApiClient>();

  /// Indian GSTIN format: 15 characters —
  /// `NN AAAAA NNNN A X Z X` (state code, PAN, entity, check chars).
  /// Used for client-side validation before submitting (bugfix.md 2.22).
  static final RegExp _gstinPattern = RegExp(
    r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]Z[0-9A-Z]$',
  );

  /// HSN/SAC codes are 4, 6, or 8 digits (bugfix.md 2.22).
  static final RegExp _hsnPattern = RegExp(r'^(\d{4}|\d{6}|\d{8})$');

  /// Returns true when [gstin] matches the 15-character GSTIN format.
  static bool isValidGstin(String gstin) =>
      _gstinPattern.hasMatch(gstin.trim().toUpperCase());

  /// Returns true when [hsn] is a 4, 6, or 8 digit HSN/SAC code.
  static bool isValidHsn(String hsn) => _hsnPattern.hasMatch(hsn.trim());

  /// Per-call capability enforcement (Task 3.5 — bugfix.md 2.10).
  ///
  /// Resolves the active business type from the live session and delegates to
  /// the SAME isolation authority (`FeatureResolver.enforceAccess`) used by the
  /// router boundary and `BillsRepository`, so a business type that is not
  /// granted the required hardware capability cannot exercise these endpoints
  /// (preventing cross-vertical data leakage). Throws [SecurityException] on
  /// denial. Hardware is granted every capability enforced below, so the
  /// hardware vertical itself is unaffected.
  void _enforce(BusinessCapability capability) {
    final businessType = sl<SessionManager>().activeBusinessType.name;
    FeatureResolver.enforceAccess(businessType, capability);
  }

  Never _failList(String op, ApiResponse res) {
    throw HardwareOpsException(
      op,
      res.error ?? 'Failed to load $op (no error message returned)',
      statusCode: res.statusCode,
    );
  }

  Never _failWrite(String op, ApiResponse res) {
    throw HardwareOpsException(
      op,
      res.error ?? 'Failed to perform $op',
      statusCode: res.statusCode,
    );
  }

  List<Map<String, dynamic>> _extractItems(
    ApiResponse res,
    String op, {
    String key = 'items',
  }) {
    if (!res.isSuccess) _failList(op, res);
    final items = res.data?['data']?[key] ?? res.data?[key];
    if (items == null) return const [];
    if (items is! List) {
      throw HardwareOpsException(
        op,
        'Unexpected response shape for $op (expected List)',
        statusCode: res.statusCode,
      );
    }
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> listCustomers() async {
    _enforce(BusinessCapability.useInventoryList);
    final res = await _api.get('/customers');
    return _extractItems(res, 'listCustomers');
  }

  Future<List<Map<String, dynamic>>> listProducts() async {
    _enforce(BusinessCapability.useInventoryList);
    final res = await _api.get('/inventory');
    return _extractItems(res, 'listProducts');
  }

  Future<List<Map<String, dynamic>>> listProjects() async {
    _enforce(BusinessCapability.useInventoryList);
    final res = await _api.get('/hardware/projects');
    return _extractItems(res, 'listProjects');
  }

  Future<bool> createProject({
    required String projectName,
    String? contractorName,
    String? siteAddress,
    String? notes,
  }) async {
    _enforce(BusinessCapability.useStockManagement);
    final res = await _api.post(
      '/hardware/projects',
      body: {
        'projectName': projectName,
        if (contractorName != null && contractorName.trim().isNotEmpty)
          'contractorName': contractorName.trim(),
        if (siteAddress != null && siteAddress.trim().isNotEmpty)
          'siteAddress': siteAddress.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    if (!res.isSuccess) _failWrite('createProject', res);
    return true;
  }

  Future<bool> closeProject(String projectId) async {
    _enforce(BusinessCapability.useStockManagement);
    final res = await _api.post('/hardware/projects/$projectId/close');
    if (!res.isSuccess) _failWrite('closeProject', res);
    return true;
  }

  Future<List<Map<String, dynamic>>> listIndents({String? projectId}) async {
    _enforce(BusinessCapability.useInventoryList);
    final res = await _api.get(
      '/hardware/indents',
      queryParameters: {
        if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
      },
    );
    return _extractItems(res, 'listIndents');
  }

  Future<bool> createIndent({
    required String projectId,
    required String requestedBy,
    required List<Map<String, dynamic>> items,
    String priority = 'normal',
    String? notes,
  }) async {
    _enforce(BusinessCapability.useStockManagement);
    // Client-side HSN validation (bugfix.md 2.22): there is no dedicated
    // createItem endpoint — items are created here. Validate any item that
    // carries an HSN/SAC code before submitting (4/6/8 digits). Items without
    // an HSN field are unaffected, so existing callers are preserved.
    for (final item in items) {
      final hsn = (item['hsn'] ?? item['hsnCode'])?.toString().trim() ?? '';
      if (hsn.isNotEmpty && !isValidHsn(hsn)) {
        throw HardwareOpsException(
          'createIndent',
          'Invalid HSN code "$hsn": must be 4, 6, or 8 digits.',
        );
      }
    }
    final res = await _api.post(
      '/hardware/indents',
      body: {
        'projectId': projectId,
        'requestedBy': requestedBy,
        'priority': priority,
        'items': items,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    if (!res.isSuccess) _failWrite('createIndent', res);
    return true;
  }

  Future<bool> closeIndent(String indentId) async {
    _enforce(BusinessCapability.useStockManagement);
    final res = await _api.post('/hardware/indents/$indentId/close');
    if (!res.isSuccess) _failWrite('closeIndent', res);
    return true;
  }

  Future<List<Map<String, dynamic>>> listDeposits({String? status}) async {
    _enforce(BusinessCapability.useInventoryList);
    final res = await _api.get(
      '/hardware/deposits',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return _extractItems(res, 'listDeposits');
  }

  Future<bool> createDeposit({
    required String customerId,
    required String customerName,
    required String itemType,
    required double quantity,
    required int depositAmountCents,
    String? referenceNo,
    String? notes,
  }) async {
    _enforce(BusinessCapability.useStockManagement);
    final res = await _api.post(
      '/hardware/deposits',
      body: {
        'customerId': customerId,
        'customerName': customerName,
        'itemType': itemType,
        'quantity': quantity,
        'depositAmountCents': depositAmountCents,
        if (referenceNo != null && referenceNo.trim().isNotEmpty)
          'referenceNo': referenceNo.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    if (!res.isSuccess) _failWrite('createDeposit', res);
    return true;
  }

  Future<bool> settleDeposit({
    required String depositId,
    required double returnedQuantity,
    required int refundAmountCents,
    String? notes,
  }) async {
    _enforce(BusinessCapability.useStockManagement);
    final res = await _api.post(
      '/hardware/deposits/$depositId/settle',
      body: {
        'returnedQuantity': returnedQuantity,
        'refundAmountCents': refundAmountCents,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    if (!res.isSuccess) _failWrite('settleDeposit', res);
    return true;
  }

  Future<List<Map<String, dynamic>>> listPurchaseOrders() async {
    _enforce(BusinessCapability.useInventoryList);
    final res = await _api.get(HardwareApiContract.listPurchaseOrders);
    return _extractItems(res, 'listPurchaseOrders');
  }

  Future<bool> createPurchaseOrder({
    required String supplierId,
    required List<Map<String, dynamic>> items,
    String? expectedDeliveryDate,
    String? notes,
  }) async {
    _enforce(BusinessCapability.usePurchaseOrder);
    final res = await _api.post(
      HardwareApiContract.createPurchaseOrder,
      body: {
        'supplierId': supplierId,
        'items': items,
        if (expectedDeliveryDate != null && expectedDeliveryDate.isNotEmpty)
          'expectedDeliveryDate': expectedDeliveryDate,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    if (!res.isSuccess) _failWrite('createPurchaseOrder', res);
    return true;
  }

  Future<List<Map<String, dynamic>>> listParties() async {
    _enforce(BusinessCapability.useInventoryList);
    final res = await _api.get(HardwareApiContract.listParties);
    return _extractItems(res, 'listParties');
  }

  Future<bool> createParty({
    required String name,
    required String type,
    String? phone,
    String? gstin,
    String? address,
    int creditLimit = 0,
    int creditDays = 30,
    String priceCategory = 'retail',
  }) async {
    _enforce(BusinessCapability.useStockManagement);
    // Client-side GSTIN validation (bugfix.md 2.22): reject a malformed GSTIN
    // before hitting the network so bad data never reaches the server.
    final cleanGstin = gstin?.trim();
    if (cleanGstin != null &&
        cleanGstin.isNotEmpty &&
        !isValidGstin(cleanGstin)) {
      throw HardwareOpsException(
        'createParty',
        'Invalid GSTIN format: must be a 15-character GSTIN '
            '(e.g. 27ABCDE1234F1Z5).',
      );
    }
    final res = await _api.post(
      HardwareApiContract.createParty,
      body: {
        'name': name,
        'type': type,
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (cleanGstin != null && cleanGstin.isNotEmpty) 'gstin': cleanGstin,
        if (address != null && address.trim().isNotEmpty)
          'address': address.trim(),
        'creditLimit': creditLimit,
        'creditDays': creditDays,
        'priceCategory': priceCategory,
      },
    );
    if (!res.isSuccess) _failWrite('createParty', res);
    return true;
  }

  Future<List<Map<String, dynamic>>> getRateComparison({
    String? itemName,
  }) async {
    _enforce(BusinessCapability.useInventoryList);
    final res = await _api.get(
      '/hardware/rate-comparison',
      queryParameters: {
        if (itemName != null && itemName.trim().isNotEmpty)
          'itemName': itemName.trim(),
      },
    );
    return _extractItems(res, 'getRateComparison', key: 'best');
  }

  Future<List<Map<String, dynamic>>> getPendingPurchaseOrders() async {
    _enforce(BusinessCapability.useInventoryList);
    final res = await _api.get('/hardware/purchase-orders/pending');
    return _extractItems(res, 'getPendingPurchaseOrders');
  }

  Future<List<Map<String, dynamic>>> listSalesOrders() async {
    _enforce(BusinessCapability.useInventoryList);
    final res = await _api.get('/hardware/sales-orders');
    return _extractItems(res, 'listSalesOrders');
  }

  Future<bool> updateSalesOrderStatus({
    required String id,
    required String status,
    String? notes,
  }) async {
    _enforce(BusinessCapability.useStockManagement);
    final res = await _api.post(
      '/hardware/sales-orders/$id/status',
      body: {
        'status': status,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    if (!res.isSuccess) _failWrite('updateSalesOrderStatus', res);
    return true;
  }

  Future<Map<String, dynamic>> getInvoiceProfiles() async {
    _enforce(BusinessCapability.useInvoiceList);
    final res = await _api.get('/hardware/invoice-profiles');
    if (!res.isSuccess) _failList('getInvoiceProfiles', res);
    final data = res.data?['data'] ?? res.data ?? const {};
    return Map<String, dynamic>.from(data as Map);
  }

  Future<bool> saveInvoiceProfiles({
    required List<Map<String, dynamic>> profiles,
    String? defaultProfileId,
  }) async {
    _enforce(BusinessCapability.useInvoiceCreate);
    final res = await _api.put(
      '/hardware/invoice-profiles',
      body: {'profiles': profiles, 'defaultProfileId': defaultProfileId},
    );
    if (!res.isSuccess) _failWrite('saveInvoiceProfiles', res);
    return true;
  }

  Future<List<Map<String, dynamic>>> getFastSlowMoving() async {
    _enforce(BusinessCapability.useInventoryList);
    final res = await _api.get('/hardware/reports/item-velocity');
    if (!res.isSuccess) _failList('getFastSlowMoving', res);
    final data = res.data?['data'] ?? res.data ?? const {};
    final fast = (data['fastMoving'] as List?) ?? const [];
    final slow = (data['slowMoving'] as List?) ?? const [];
    return [
      ...fast.whereType<Map>().map(
        (e) => {'bucket': 'fast', ...Map<String, dynamic>.from(e)},
      ),
      ...slow.whereType<Map>().map(
        (e) => {'bucket': 'slow', ...Map<String, dynamic>.from(e)},
      ),
    ];
  }

  Future<List<Map<String, dynamic>>> getDeadStock() async {
    _enforce(BusinessCapability.useInventoryList);
    final res = await _api.get('/hardware/reports/dead-stock');
    return _extractItems(res, 'getDeadStock');
  }

  /// Total outstanding contractor credit (in paise/cents) for the hardware
  /// dashboard KPI card (bugfix.md 2.25). Reads the same
  /// `/customers/credit/reminder-candidates` endpoint the Credit Control
  /// screen uses and returns the aggregate `totals.totalOutstanding`.
  Future<int> getContractorCreditOutstandingCents() async {
    _enforce(BusinessCapability.useCreditManagement);
    final res = await _api.get('/customers/credit/reminder-candidates');
    if (!res.isSuccess) _failList('getContractorCreditOutstandingCents', res);
    final data = res.data?['data'] ?? res.data ?? const {};
    final totals = (data is Map ? data['totals'] : null) as Map? ?? const {};
    return (totals['totalOutstanding'] as num?)?.round() ?? 0;
  }
}
