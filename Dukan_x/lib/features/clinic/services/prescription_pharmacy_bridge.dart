// ============================================================================
// PRESCRIPTION-PHARMACY BRIDGE SERVICE (BUG-062 FIX)
// ============================================================================
// Bridges clinic prescriptions with pharmacy inventory
// Checks prescription items against actual pharmacy stock

import '../../../core/api/api_client.dart';
import '../../../core/di/service_locator.dart';
import '../../inventory/services/stock_reservation_service.dart';

/// Bridge between Clinic prescriptions and Pharmacy inventory
class PrescriptionPharmacyBridge {
  final ApiClient _apiClient;
  final StockReservationService? _stockService;
  
  PrescriptionPharmacyBridge({
    ApiClient? apiClient,
    StockReservationService? stockService,
  }) : _apiClient = apiClient ?? sl<ApiClient>(),
       _stockService = stockService;

  /// Validates a prescription against pharmacy inventory
  /// 
  /// Returns availability status for each prescribed item
  Future<PrescriptionValidationResult> validatePrescriptionAvailability({
    required String tenantId,
    required List<PrescriptionItem> items,
  }) async {
    final unavailableItems = <UnavailableItem>[];
    final lowStockItems = <LowStockItem>[];
    final availableItems = <AvailableItem>[];
    
    for (final item in items) {
      // Check if product exists in pharmacy inventory
      final stockCheck = await _checkProductStock(
        tenantId: tenantId,
        productId: item.productId,
        productName: item.productName,
        requiredQuantity: item.quantity,
      );
      
      if (!stockCheck.exists) {
        unavailableItems.add(UnavailableItem(
          productId: item.productId,
          productName: item.productName,
          prescribedQuantity: item.quantity,
          reason: 'Product not in pharmacy inventory',
        ));
      } else if (stockCheck.availableQuantity < item.quantity) {
        lowStockItems.add(LowStockItem(
          productId: item.productId,
          productName: item.productName,
          prescribedQuantity: item.quantity,
          availableQuantity: stockCheck.availableQuantity,
        ));
      } else {
        availableItems.add(AvailableItem(
          productId: item.productId,
          productName: item.productName,
          quantity: item.quantity,
          availableStock: stockCheck.availableQuantity,
        ));
      }
    }
    
    return PrescriptionValidationResult(
      isFullyAvailable: unavailableItems.isEmpty && lowStockItems.isEmpty,
      unavailableItems: unavailableItems,
      lowStockItems: lowStockItems,
      availableItems: availableItems,
    );
  }
  
  /// Reserves stock for prescription items
  /// Call this when patient confirms they want to purchase
  Future<PrescriptionReservationResult> reservePrescriptionStock({
    required String tenantId,
    required String prescriptionId,
    required List<PrescriptionItem> items,
  }) async {
    if (_stockService == null) {
      return PrescriptionReservationResult.failure(
        'Stock reservation service not available',
      );
    }
    
    try {
      // First validate availability
      final validation = await validatePrescriptionAvailability(
        tenantId: tenantId,
        items: items,
      );
      
      if (!validation.isFullyAvailable) {
        return PrescriptionReservationResult.failure(
          'Some items are not available: ${validation.unavailableItems.map((i) => i.productName).join(', ')}',
        );
      }
      
      // Reserve stock per item for 30-minute prescription pickup window.
      // StockReservationService.reserveStock takes one item at a time.
      final billDraftId = 'PRESCRIPTION_$prescriptionId';
      String firstReservationId = '';
      for (final item in items) {
        final result = await _stockService.reserveStock(
          userId: tenantId,
          billDraftId: billDraftId,
          productId: item.productId,
          quantity: item.quantity.toDouble(),
          timeout: const Duration(minutes: 30),
        );
        if (!result.success) {
          return PrescriptionReservationResult.failure(
            result.errorMessage ?? 'Failed to reserve ${item.productName}',
          );
        }
        if (firstReservationId.isEmpty) {
          firstReservationId = result.reservationId ?? '';
        }
      }
      final reservation = ReservationResult.success(firstReservationId);
      
      if (reservation.success) {
        return PrescriptionReservationResult.success(
          reservationId: reservation.reservationId ?? '',
          expiresAt: DateTime.now().add(const Duration(minutes: 30)),
        );
      } else {
        return PrescriptionReservationResult.failure(
          reservation.errorMessage ?? 'Failed to reserve stock',
        );
      }
    } catch (e) {
      return PrescriptionReservationResult.failure(
        'Error reserving stock: $e',
      );
    }
  }
  
  /// Gets alternative products when prescribed item is unavailable
  Future<List<AlternativeProduct>> getAlternativeProducts({
    required String tenantId,
    required String productId,
    required String productName,
  }) async {
    try {
      // Search for products with similar names or generic equivalents
      final response = await _apiClient.get(
        '/pharmacy/alternatives',
        queryParams: {
          'productId': productId,
          'productName': productName,
        },
      );
      
      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        final alternatives = data['alternatives'] as List<dynamic>? ?? [];
        
        return alternatives.map((a) => AlternativeProduct(
          productId: a['id'] ?? '',
          productName: a['name'] ?? '',
          genericName: a['genericName'],
          availableStock: a['stock'] ?? 0,
          price: (a['price'] ?? 0).toDouble(),
        )).toList();
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }
  
  /// Checks product stock via API
  Future<StockCheckResult> _checkProductStock({
    required String tenantId,
    required String productId,
    required String productName,
    required int requiredQuantity,
  }) async {
    try {
      // Try to get stock via API
      final response = await _apiClient.get(
        '/pharmacy/stock-check',
        queryParams: {
          'tenantId': tenantId,
          'productId': productId,
        },
      );
      
      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        return StockCheckResult(
          exists: true,
          availableQuantity: (data['currentStock'] ?? 0).toInt(),
        );
      }
      
      // Product not found in pharmacy inventory
      return StockCheckResult(
        exists: false,
        availableQuantity: 0,
      );
    } catch (e) {
      // Error checking stock - assume unavailable
      return StockCheckResult(
        exists: false,
        availableQuantity: 0,
      );
    }
  }
}

/// Prescription item from clinic
class PrescriptionItem {
  final String productId;
  final String productName;
  final int quantity;
  final String? dosage;
  final String? frequency;
  final String? duration;
  
  PrescriptionItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    this.dosage,
    this.frequency,
    this.duration,
  });
}

/// Validation result for prescription availability
class PrescriptionValidationResult {
  final bool isFullyAvailable;
  final List<UnavailableItem> unavailableItems;
  final List<LowStockItem> lowStockItems;
  final List<AvailableItem> availableItems;
  
  PrescriptionValidationResult({
    required this.isFullyAvailable,
    required this.unavailableItems,
    required this.lowStockItems,
    required this.availableItems,
  });
  
  /// Get user-friendly message
  String get message {
    if (isFullyAvailable) {
      return 'All prescribed medicines are available';
    }
    
    final parts = <String>[];
    if (unavailableItems.isNotEmpty) {
      parts.add('${unavailableItems.length} item(s) unavailable');
    }
    if (lowStockItems.isNotEmpty) {
      parts.add('${lowStockItems.length} item(s) low stock');
    }
    
    return parts.join(', ');
  }
}

/// Unavailable prescription item
class UnavailableItem {
  final String productId;
  final String productName;
  final int prescribedQuantity;
  final String reason;
  
  UnavailableItem({
    required this.productId,
    required this.productName,
    required this.prescribedQuantity,
    required this.reason,
  });
}

/// Low stock prescription item
class LowStockItem {
  final String productId;
  final String productName;
  final int prescribedQuantity;
  final int availableQuantity;
  
  LowStockItem({
    required this.productId,
    required this.productName,
    required this.prescribedQuantity,
    required this.availableQuantity,
  });
  
  double get stockPercentage => 
    prescribedQuantity > 0 
      ? (availableQuantity / prescribedQuantity) * 100 
      : 0;
}

/// Available prescription item
class AvailableItem {
  final String productId;
  final String productName;
  final int quantity;
  final int availableStock;
  
  AvailableItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.availableStock,
  });
}

/// Prescription stock reservation result
class PrescriptionReservationResult {
  final bool success;
  final String? reservationId;
  final DateTime? expiresAt;
  final String? errorMessage;
  
  PrescriptionReservationResult._({
    required this.success,
    this.reservationId,
    this.expiresAt,
    this.errorMessage,
  });
  
  factory PrescriptionReservationResult.success({
    required String reservationId,
    required DateTime expiresAt,
  }) {
    return PrescriptionReservationResult._(
      success: true,
      reservationId: reservationId,
      expiresAt: expiresAt,
    );
  }
  
  factory PrescriptionReservationResult.failure(String error) {
    return PrescriptionReservationResult._(
      success: false,
      errorMessage: error,
    );
  }
}

/// Alternative product suggestion
class AlternativeProduct {
  final String productId;
  final String productName;
  final String? genericName;
  final int availableStock;
  final double price;
  
  AlternativeProduct({
    required this.productId,
    required this.productName,
    this.genericName,
    required this.availableStock,
    required this.price,
  });
}

/// Stock check result
class StockCheckResult {
  final bool exists;
  final int availableQuantity;
  
  StockCheckResult({
    required this.exists,
    required this.availableQuantity,
  });
}
