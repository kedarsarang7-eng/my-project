// Entity Action Service - Backend operations for CRUD actions
// Handles soft delete, restore, and entity updates

import '../../../core/api/api_client.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/session/session_manager.dart';

/// Result of an entity action operation
class EntityActionResult {
  final bool success;
  final String? error;
  final dynamic data;

  EntityActionResult({required this.success, this.error, this.data});

  factory EntityActionResult.success([dynamic data]) =>
      EntityActionResult(success: true, data: data);

  factory EntityActionResult.failure(String error) =>
      EntityActionResult(success: false, error: error);
}

/// Service for performing entity actions (Edit/View/Delete)
class EntityActionService {
  final ApiClient _client;
  final SessionManager _session;

  EntityActionService(this._client) : _session = sl<SessionManager>();

  // ─── Product/Inventory Actions ───────────────────────────────────────────

  /// Soft delete a product
  Future<EntityActionResult> deleteProduct(String productId) async {
    try {
      final response = await _client.delete(
        '/products/$productId',
        queryParams: {'soft': 'true'},
      );
      return EntityActionResult.success(response);
    } catch (e) {
      return EntityActionResult.failure('Failed to delete product: $e');
    }
  }

  /// Permanently delete a product
  Future<EntityActionResult> permanentlyDeleteProduct(String productId) async {
    try {
      final response = await _client.delete('/products/$productId');
      return EntityActionResult.success(response);
    } catch (e) {
      return EntityActionResult.failure('Failed to delete product: $e');
    }
  }

  /// Restore a soft-deleted product
  Future<EntityActionResult> restoreProduct(String productId) async {
    try {
      final response = await _client.post('/products/$productId/restore');
      return EntityActionResult.success(response);
    } catch (e) {
      return EntityActionResult.failure('Failed to restore product: $e');
    }
  }

  // ─── Customer Actions ───────────────────────────────────────────────────

  /// Soft delete a customer
  Future<EntityActionResult> deleteCustomer(String customerId) async {
    try {
      final response = await _client.delete(
        '/customers/$customerId',
        queryParams: {'soft': 'true'},
      );
      return EntityActionResult.success(response);
    } catch (e) {
      return EntityActionResult.failure('Failed to delete customer: $e');
    }
  }

  /// Block/unblock a customer
  Future<EntityActionResult> setCustomerBlockStatus(
    String customerId, {
    required bool isBlocked,
    String? reason,
  }) async {
    try {
      final response = await _client.patch(
        '/customers/$customerId',
        body: {'isBlocked': isBlocked, 'blockReason': ?reason},
      );
      return EntityActionResult.success(response);
    } catch (e) {
      return EntityActionResult.failure('Failed to update customer: $e');
    }
  }

  // ─── Staff Actions ────────────────────────────────────────────────────────

  /// Soft delete/deactivate staff member
  Future<EntityActionResult> deleteStaff(String staffId) async {
    try {
      final response = await _client.delete(
        '/staff/$staffId',
        queryParams: {'soft': 'true'},
      );
      return EntityActionResult.success(response);
    } catch (e) {
      return EntityActionResult.failure('Failed to delete staff: $e');
    }
  }

  /// Activate/deactivate staff account
  Future<EntityActionResult> setStaffStatus(
    String staffId, {
    required bool isActive,
  }) async {
    try {
      final response = await _client.patch(
        '/staff/$staffId',
        body: {'isActive': isActive},
      );
      return EntityActionResult.success(response);
    } catch (e) {
      return EntityActionResult.failure('Failed to update staff status: $e');
    }
  }

  // ─── Supplier/Party Actions ─────────────────────────────────────────────

  /// Delete a supplier
  Future<EntityActionResult> deleteSupplier(String supplierId) async {
    try {
      final response = await _client.delete(
        '/suppliers/$supplierId',
        queryParams: {'soft': 'true'},
      );
      return EntityActionResult.success(response);
    } catch (e) {
      return EntityActionResult.failure('Failed to delete supplier: $e');
    }
  }

  // ─── Auto Parts Job Card Actions ─────────────────────────────────────────

  /// Delete a job card
  Future<EntityActionResult> deleteJobCard(String jobCardId) async {
    try {
      final response = await _client.delete(
        '/auto-parts/job-cards/$jobCardId',
        queryParams: {'soft': 'true'},
      );
      return EntityActionResult.success(response);
    } catch (e) {
      return EntityActionResult.failure('Failed to delete job card: $e');
    }
  }

  /// Update job card status
  Future<EntityActionResult> updateJobCardStatus(
    String jobCardId, {
    required String status,
  }) async {
    try {
      final response = await _client.put(
        '/auto-parts/job-cards/$jobCardId',
        body: {'status': status},
      );
      return EntityActionResult.success(response);
    } catch (e) {
      return EntityActionResult.failure('Failed to update job card: $e');
    }
  }

  // ─── Jewellery Custom Order Actions ─────────────────────────────────────

  /// Delete a custom order
  Future<EntityActionResult> deleteCustomOrder(String orderId) async {
    try {
      final response = await _client.delete(
        '/jewellery/custom-orders/$orderId',
        queryParams: {'soft': 'true'},
      );
      return EntityActionResult.success(response);
    } catch (e) {
      return EntityActionResult.failure('Failed to delete order: $e');
    }
  }

  /// Update order status
  Future<EntityActionResult> updateCustomOrderStatus(
    String orderId, {
    required String status,
  }) async {
    try {
      final response = await _client.put(
        '/jewellery/custom-orders/$orderId',
        body: {'status': status},
      );
      return EntityActionResult.success(response);
    } catch (e) {
      return EntityActionResult.failure('Failed to update order: $e');
    }
  }

  // ─── Invoice Actions ─────────────────────────────────────────────────────

  /// Void/cancel an invoice
  Future<EntityActionResult> voidInvoice(
    String invoiceId, {
    String? reason,
  }) async {
    try {
      final response = await _client.post(
        '/invoices/$invoiceId/void',
        body: {'reason': ?reason},
      );
      return EntityActionResult.success(response);
    } catch (e) {
      return EntityActionResult.failure('Failed to void invoice: $e');
    }
  }

  // ─── Generic Entity Actions ──────────────────────────────────────────────

  /// Generic soft delete for any entity type
  Future<EntityActionResult> softDelete({
    required String entityType,
    required String entityId,
  }) async {
    try {
      final response = await _client.delete(
        '/$entityType/$entityId',
        queryParams: {'soft': 'true'},
      );
      return EntityActionResult.success(response);
    } catch (e) {
      return EntityActionResult.failure('Failed to delete: $e');
    }
  }

  /// Generic restore for any entity type
  Future<EntityActionResult> restore({
    required String entityType,
    required String entityId,
  }) async {
    try {
      final response = await _client.post('/$entityType/$entityId/restore');
      return EntityActionResult.success(response);
    } catch (e) {
      return EntityActionResult.failure('Failed to restore: $e');
    }
  }

  /// Generic update for any entity
  Future<EntityActionResult> update({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _client.patch(
        '/$entityType/$entityId',
        body: data,
      );
      return EntityActionResult.success(response);
    } catch (e) {
      return EntityActionResult.failure('Failed to update: $e');
    }
  }

  /// Get entity details
  Future<EntityActionResult> getDetails({
    required String entityType,
    required String entityId,
  }) async {
    try {
      final response = await _client.get('/$entityType/$entityId');
      return EntityActionResult.success(response);
    } catch (e) {
      return EntityActionResult.failure('Failed to fetch details: $e');
    }
  }

  /// Batch delete multiple entities
  Future<EntityActionResult> batchDelete({
    required String entityType,
    required List<String> entityIds,
    bool soft = true,
  }) async {
    try {
      final response = await _client.post(
        '/$entityType/batch-delete',
        body: {'ids': entityIds, 'soft': soft},
      );
      return EntityActionResult.success(response);
    } catch (e) {
      return EntityActionResult.failure('Failed to batch delete: $e');
    }
  }

  // ─── Recycle Bin / Trash Actions ────────────────────────────────────────

  /// Get deleted items (recycle bin)
  Future<EntityActionResult> getDeletedItems({
    String? entityType,
    int limit = 50,
    String? nextToken,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'deleted': 'true',
        'type': ?entityType,
        'nextToken': ?nextToken,
      };

      final response = await _client.get(
        '/deleted-items',
        queryParams: queryParams,
      );
      return EntityActionResult.success(response);
    } catch (e) {
      return EntityActionResult.failure('Failed to fetch deleted items: $e');
    }
  }

  /// Permanently delete from trash
  Future<EntityActionResult> permanentDelete(
    String entityType,
    String entityId,
  ) async {
    try {
      final response = await _client.delete(
        '/$entityType/$entityId',
        queryParams: {'permanent': 'true'},
      );
      return EntityActionResult.success(response);
    } catch (e) {
      return EntityActionResult.failure('Failed to permanently delete: $e');
    }
  }

  /// Empty trash for an entity type
  Future<EntityActionResult> emptyTrash(String entityType) async {
    try {
      final response = await _client.post('/$entityType/empty-trash');
      return EntityActionResult.success(response);
    } catch (e) {
      return EntityActionResult.failure('Failed to empty trash: $e');
    }
  }
}
