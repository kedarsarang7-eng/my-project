// ============================================================================
// EVENT RENTAL — Per-event rental lifecycle state machine
// ============================================================================
// Implements the rental lifecycle for inventory items assigned to events.
//
// State machine:
//   [*] → available
//   available → rentedOut (via rentOut; quantity ∈ [1, availableOnHand])
//   rentedOut → returned (via returnItem; damagedQty == 0)
//   rentedOut → returnedWithDamage (via returnItem; damagedQty ∈ [1, rentedQty])
//   returned → [*]
//   returnedWithDamage → [*]
//
// Invariants:
//   - Out-of-bounds entries are REJECTED; previous state is retained.
//   - Money fields are integer paise (Requirement 1.3/1.4).
//   - IDs use the RID pattern via DcRidGenerator (Requirement 1.5).
//
// Requirements: 9.3, 9.4, 9.5, 9.6
// ============================================================================

/// Rental lifecycle states for a per-event inventory item.
enum RentalState {
  /// Item is available for rent-out.
  available,

  /// Item has been rented out to an event.
  rentedOut,

  /// Item was returned with no damage.
  returned,

  /// Item was returned with damage or loss recorded.
  returnedWithDamage,
}

/// Result of a rental state transition attempt.
///
/// Either contains the updated [EventRental] on success, or an error message
/// explaining why the transition was rejected (with the original state retained).
class RentalTransitionResult {
  final EventRental? rental;
  final String? error;

  const RentalTransitionResult.success(EventRental this.rental) : error = null;
  const RentalTransitionResult.rejected(String this.error) : rental = null;

  bool get isSuccess => rental != null;
  bool get isRejected => error != null;
}

/// A per-event rental record tracking the lifecycle of an inventory item
/// rented for a specific event.
///
/// All money fields are integer paise. IDs are generated using the RID pattern.
class EventRental {
  /// Unique identifier (RID pattern: {tenantId}-{timestamp_ms}-{uuid_v4_short}).
  final String id;

  /// The event this rental is associated with.
  final String eventId;

  /// The inventory item being rented.
  final String inventoryItemId;

  /// Quantity rented out; must be in [1, availableOnHand] at rent-out time.
  final int rentedQty;

  /// Quantity returned damaged or lost; must be in [0, rentedQty] at return time.
  final int damagedOrLostQty;

  /// Current lifecycle state of this rental.
  final RentalState state;

  /// Rental price per unit in integer paise.
  final int rentalPricePerUnitPaise;

  /// Total rental price in integer paise (rentalPricePerUnitPaise * rentedQty).
  final int totalRentalPricePaise;

  /// Timestamp when the rental was created.
  final DateTime createdAt;

  /// Timestamp of the last state transition.
  final DateTime updatedAt;

  const EventRental({
    required this.id,
    required this.eventId,
    required this.inventoryItemId,
    this.rentedQty = 0,
    this.damagedOrLostQty = 0,
    this.state = RentalState.available,
    this.rentalPricePerUnitPaise = 0,
    this.totalRentalPricePaise = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a new [EventRental] in the [RentalState.available] state.
  ///
  /// Use [DcRidGenerator.generate()] to produce the [id].
  factory EventRental.create({
    required String id,
    required String eventId,
    required String inventoryItemId,
    required int rentalPricePerUnitPaise,
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.now();
    return EventRental(
      id: id,
      eventId: eventId,
      inventoryItemId: inventoryItemId,
      rentedQty: 0,
      damagedOrLostQty: 0,
      state: RentalState.available,
      rentalPricePerUnitPaise: rentalPricePerUnitPaise,
      totalRentalPricePaise: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Attempts to rent out [quantity] units of this item.
  ///
  /// Validates:
  ///   - Current state must be [RentalState.available]
  ///   - [quantity] must be in [1, availableOnHand]
  ///
  /// On success: transitions to [RentalState.rentedOut], records [rentedQty],
  /// and computes [totalRentalPricePaise].
  ///
  /// On failure: returns [RentalTransitionResult.rejected] with the previous
  /// state retained (Requirement 9.5).
  RentalTransitionResult rentOut({
    required int quantity,
    required int availableOnHand,
  }) {
    // Must be in available state to rent out
    if (state != RentalState.available) {
      return RentalTransitionResult.rejected(
        'Cannot rent out: item is in state "${state.name}", expected "available".',
      );
    }

    // Validate quantity bounds: [1, availableOnHand]
    if (quantity < 1) {
      return RentalTransitionResult.rejected(
        'Cannot rent out: quantity ($quantity) must be at least 1.',
      );
    }
    if (quantity > availableOnHand) {
      return RentalTransitionResult.rejected(
        'Cannot rent out: quantity ($quantity) exceeds available on hand ($availableOnHand).',
      );
    }

    // Valid transition: available → rentedOut
    final totalPrice = rentalPricePerUnitPaise * quantity;
    return RentalTransitionResult.success(
      EventRental(
        id: id,
        eventId: eventId,
        inventoryItemId: inventoryItemId,
        rentedQty: quantity,
        damagedOrLostQty: 0,
        state: RentalState.rentedOut,
        rentalPricePerUnitPaise: rentalPricePerUnitPaise,
        totalRentalPricePaise: totalPrice,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Attempts to return this rented item, recording [damagedQty] as damaged/lost.
  ///
  /// Validates:
  ///   - Current state must be [RentalState.rentedOut]
  ///   - [damagedQty] must be in [0, rentedQty]
  ///
  /// On success:
  ///   - If [damagedQty] == 0 → transitions to [RentalState.returned]
  ///   - If [damagedQty] > 0 → transitions to [RentalState.returnedWithDamage]
  ///
  /// On failure: returns [RentalTransitionResult.rejected] with the previous
  /// state retained (Requirement 9.6).
  RentalTransitionResult returnItem({required int damagedQty}) {
    // Must be in rentedOut state to return
    if (state != RentalState.rentedOut) {
      return RentalTransitionResult.rejected(
        'Cannot return: item is in state "${state.name}", expected "rentedOut".',
      );
    }

    // Validate damagedQty bounds: [0, rentedQty]
    if (damagedQty < 0) {
      return RentalTransitionResult.rejected(
        'Cannot return: damaged/lost quantity ($damagedQty) cannot be negative.',
      );
    }
    if (damagedQty > rentedQty) {
      return RentalTransitionResult.rejected(
        'Cannot return: damaged/lost quantity ($damagedQty) exceeds rented quantity ($rentedQty).',
      );
    }

    // Valid transition: rentedOut → returned / returnedWithDamage
    final newState = damagedQty == 0
        ? RentalState.returned
        : RentalState.returnedWithDamage;

    return RentalTransitionResult.success(
      EventRental(
        id: id,
        eventId: eventId,
        inventoryItemId: inventoryItemId,
        rentedQty: rentedQty,
        damagedOrLostQty: damagedQty,
        state: newState,
        rentalPricePerUnitPaise: rentalPricePerUnitPaise,
        totalRentalPricePaise: totalRentalPricePaise,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Creates a copy with optional field overrides.
  EventRental copyWith({
    String? id,
    String? eventId,
    String? inventoryItemId,
    int? rentedQty,
    int? damagedOrLostQty,
    RentalState? state,
    int? rentalPricePerUnitPaise,
    int? totalRentalPricePaise,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventRental(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      inventoryItemId: inventoryItemId ?? this.inventoryItemId,
      rentedQty: rentedQty ?? this.rentedQty,
      damagedOrLostQty: damagedOrLostQty ?? this.damagedOrLostQty,
      state: state ?? this.state,
      rentalPricePerUnitPaise:
          rentalPricePerUnitPaise ?? this.rentalPricePerUnitPaise,
      totalRentalPricePaise:
          totalRentalPricePaise ?? this.totalRentalPricePaise,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventRental &&
        other.id == id &&
        other.eventId == eventId &&
        other.inventoryItemId == inventoryItemId &&
        other.rentedQty == rentedQty &&
        other.damagedOrLostQty == damagedOrLostQty &&
        other.state == state &&
        other.rentalPricePerUnitPaise == rentalPricePerUnitPaise &&
        other.totalRentalPricePaise == totalRentalPricePaise;
  }

  @override
  int get hashCode => Object.hash(
    id,
    eventId,
    inventoryItemId,
    rentedQty,
    damagedOrLostQty,
    state,
    rentalPricePerUnitPaise,
    totalRentalPricePaise,
  );

  @override
  String toString() =>
      'EventRental(id: $id, event: $eventId, item: $inventoryItemId, '
      'qty: $rentedQty, damaged: $damagedOrLostQty, state: ${state.name}, '
      'pricePerUnit: $rentalPricePerUnitPaise paise, '
      'total: $totalRentalPricePaise paise)';
}
