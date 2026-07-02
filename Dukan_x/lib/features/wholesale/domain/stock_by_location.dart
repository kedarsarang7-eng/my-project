// Stock-by-location ledger — attributes stock quantities to specific
// warehouse locations (godowns) for a tenant.
//
// Design model (Phase 7):
// ```
// StockByLocation (new)
//   tenantId   : string
//   productId  : string
//   locationId : RID    // must belong to tenantId
//   quantity   : int
// ```
//
// INVARIANT: sum(quantity by product across locations) == product total stock.

/// Represents the stock quantity of a product at a specific warehouse location.
class StockByLocation {
  /// The owning tenant — scopes all queries and writes.
  final String tenantId;

  /// The product whose stock is being tracked at this location.
  final String productId;

  /// The warehouse/godown RID where this stock is held.
  /// Must belong to [tenantId] — foreign-tenant locations are rejected.
  final String locationId;

  /// The quantity of the product at this location (integer units).
  final int quantity;

  const StockByLocation({
    required this.tenantId,
    required this.productId,
    required this.locationId,
    required this.quantity,
  });

  StockByLocation copyWith({
    String? tenantId,
    String? productId,
    String? locationId,
    int? quantity,
  }) {
    return StockByLocation(
      tenantId: tenantId ?? this.tenantId,
      productId: productId ?? this.productId,
      locationId: locationId ?? this.locationId,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StockByLocation &&
          runtimeType == other.runtimeType &&
          tenantId == other.tenantId &&
          productId == other.productId &&
          locationId == other.locationId &&
          quantity == other.quantity;

  @override
  int get hashCode => Object.hash(tenantId, productId, locationId, quantity);

  @override
  String toString() =>
      'StockByLocation(tenant: $tenantId, product: $productId, '
      'location: $locationId, qty: $quantity)';
}

/// A stock movement event — adds or removes stock at a specific location.
class StockMovement {
  /// The warehouse/godown RID where stock is being moved.
  /// Must belong to the active tenant — foreign-tenant locations are rejected.
  final String locationId;

  /// The product being moved.
  final String productId;

  /// The quantity change: positive for inbound, negative for outbound.
  final int quantityDelta;

  const StockMovement({
    required this.locationId,
    required this.productId,
    required this.quantityDelta,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StockMovement &&
          runtimeType == other.runtimeType &&
          locationId == other.locationId &&
          productId == other.productId &&
          quantityDelta == other.quantityDelta;

  @override
  int get hashCode => Object.hash(locationId, productId, quantityDelta);

  @override
  String toString() =>
      'StockMovement(location: $locationId, product: $productId, '
      'delta: $quantityDelta)';
}

/// Represents the stock state for a single product at a single location.
///
/// Used as the "prior" state input to [StockByLocationLogic.applyMovement].
class StockState {
  /// The current stock quantity at the given location for the product.
  final int quantity;

  /// The tenant that owns this stock record.
  final String tenantId;

  /// The product id.
  final String productId;

  /// The location (warehouse) id.
  final String locationId;

  const StockState({
    required this.quantity,
    required this.tenantId,
    required this.productId,
    required this.locationId,
  });

  @override
  String toString() =>
      'StockState(tenant: $tenantId, product: $productId, '
      'location: $locationId, qty: $quantity)';
}

/// Error thrown when a stock movement references a warehouse that does not
/// belong to the active tenant.
class ForeignTenantMovementError extends Error {
  final String locationId;
  final String activeTenantId;

  ForeignTenantMovementError({
    required this.locationId,
    required this.activeTenantId,
  });

  @override
  String toString() =>
      'ForeignTenantMovementError: location "$locationId" does not belong to '
      'active tenant "$activeTenantId". No data was persisted.';
}

/// Pure domain logic for stock-by-location operations.
///
/// Ensures tenant ownership is validated before any state mutation.
class StockByLocationLogic {
  /// Applies a [StockMovement] to the given [prior] stock state.
  ///
  /// Validates that [movement.locationId] belongs to the [activeTenantId].
  /// If it does not, throws [ForeignTenantMovementError] — no state is changed.
  ///
  /// Returns the new [StockByLocation] with the updated quantity.
  ///
  /// INVARIANT: sum(quantity by product across locations) == product total stock.
  static StockByLocation applyMovement({
    required StockState prior,
    required StockMovement movement,
    required String activeTenantId,
    required bool Function(String locationId, String tenantId)
    locationBelongsToTenant,
  }) {
    // Foreign-tenant rejection: if warehouse does not belong to active tenant,
    // throw error and persist nothing (Requirement 10.4).
    if (!locationBelongsToTenant(movement.locationId, activeTenantId)) {
      throw ForeignTenantMovementError(
        locationId: movement.locationId,
        activeTenantId: activeTenantId,
      );
    }

    final newQuantity = prior.quantity + movement.quantityDelta;

    return StockByLocation(
      tenantId: activeTenantId,
      productId: movement.productId,
      locationId: movement.locationId,
      quantity: newQuantity,
    );
  }
}
