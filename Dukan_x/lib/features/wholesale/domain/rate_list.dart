/// A pricing slab within a [RateList].
///
/// Each slab defines a quantity range and the per-unit price (in paise) that
/// applies when the ordered quantity falls within [minQty]..[maxQty].
/// If [maxQty] is null the slab has no upper bound (applies to minQty and above).
class PricingSlab {
  /// Minimum quantity (inclusive) for this slab to apply.
  final int minQty;

  /// Maximum quantity (inclusive). Null means no upper bound.
  final int? maxQty;

  /// Unit price in integer paise for quantities in this slab.
  final int unitPaise;

  const PricingSlab({
    required this.minQty,
    this.maxQty,
    required this.unitPaise,
  });

  /// Whether [qty] falls within this slab's range.
  bool matches(int qty) {
    if (qty < minQty) return false;
    if (maxQty != null && qty > maxQty!) return false;
    return true;
  }

  /// Creates a [PricingSlab] from a JSON map (deserialized from storage).
  factory PricingSlab.fromJson(Map<String, dynamic> json) {
    return PricingSlab(
      minQty: json['minQty'] as int,
      maxQty: json['maxQty'] as int?,
      unitPaise: json['unitPaise'] as int,
    );
  }

  /// Serializes this slab to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {'minQty': minQty, 'maxQty': maxQty, 'unitPaise': unitPaise};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PricingSlab &&
          runtimeType == other.runtimeType &&
          minQty == other.minQty &&
          maxQty == other.maxQty &&
          unitPaise == other.unitPaise;

  @override
  int get hashCode => Object.hash(minQty, maxQty, unitPaise);

  @override
  String toString() =>
      'PricingSlab(minQty: $minQty, maxQty: $maxQty, unitPaise: $unitPaise)';
}

/// A rate list defining tiered/slab pricing for a product, optionally
/// specific to a party (customer).
///
/// Design model (Phase 8):
/// ```
/// RateList / PricingTier (new — Schema_Gate, Phase 8)
///   id         : RID
///   tenantId   : string
///   partyId    : string?    // null => quantity-slab list (generic)
///   productId  : string
///   slabs      : [{ minQty: int, maxQty: int?, unitPaise: int }]
/// ```
///
/// When [partyId] is null, this is a generic quantity-slab rate list that
/// applies to any party for the given product. When [partyId] is set, this
/// is a party-specific rate list that takes priority over generic lists.
///
/// All money values are integer Paise. IDs follow the RID pattern.
class RateList {
  /// RID-format identifier: `{tenantId}-{timestamp_ms}-{uuid_v4_short}`.
  final String id;

  /// The owning tenant — scopes all queries and writes.
  final String tenantId;

  /// The party (customer) this rate list applies to.
  /// Null means this is a generic (product-level) rate list.
  final String? partyId;

  /// The product this rate list prices.
  final String productId;

  /// Ordered list of quantity slabs with their per-unit prices in paise.
  final List<PricingSlab> slabs;

  /// Timestamp when this rate list was created/last updated.
  final DateTime createdAt;

  const RateList({
    required this.id,
    required this.tenantId,
    this.partyId,
    required this.productId,
    required this.slabs,
    required this.createdAt,
  });

  /// Creates a copy with the given fields replaced.
  RateList copyWith({
    String? id,
    String? tenantId,
    String? partyId,
    bool clearPartyId = false,
    String? productId,
    List<PricingSlab>? slabs,
    DateTime? createdAt,
  }) {
    return RateList(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      partyId: clearPartyId ? null : (partyId ?? this.partyId),
      productId: productId ?? this.productId,
      slabs: slabs ?? this.slabs,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RateList &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          tenantId == other.tenantId &&
          partyId == other.partyId &&
          productId == other.productId;

  @override
  int get hashCode => Object.hash(id, tenantId, partyId, productId);

  @override
  String toString() =>
      'RateList(id: $id, tenant: $tenantId, party: $partyId, '
      'product: $productId, slabs: ${slabs.length})';
}
