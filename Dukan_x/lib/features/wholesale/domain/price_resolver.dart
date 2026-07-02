import 'rate_list.dart';

/// Context required to resolve a price for a bill line.
///
/// Contains the party-specific and generic rate lists that may apply to a
/// given product+party combination. The [PriceResolver] checks party-specific
/// lists first, then generic lists, and falls back to the provided generic
/// price if no slab matches.
class RateContext {
  /// Rate lists specific to the party (customer) for this product.
  /// Checked first for a matching slab.
  final List<RateList> partyRateLists;

  /// Generic (product-level) rate lists — partyId is null.
  /// Checked second, only if no party-specific slab matches.
  final List<RateList> genericRateLists;

  const RateContext({
    this.partyRateLists = const [],
    this.genericRateLists = const [],
  });
}

/// Resolves line prices from rate lists and computes deterministic net amounts.
///
/// Design interface (Phase 8):
/// ```dart
/// class PriceResolver {
///   int resolveUnitPaise({required RateContext ctx, required int qty, required int genericPaise});
///   int netLinePaise({required int resolvedUnitPaise, required int qty, required int discountPaise});
/// }
/// ```
///
/// Resolution order:
/// 1. Check party-specific rate lists for a slab matching [qty]
/// 2. If no match, check generic rate lists for a slab matching [qty]
/// 3. If nothing matches, return [genericPaise] (fallback — never fabricate a tier)
///
/// Price/discount interaction order (Requirement 11.5):
/// 1. Resolve tier/rate-list unit price
/// 2. Multiply by quantity
/// 3. Subtract line discount
/// Formula: `netLinePaise = (resolvedUnitPaise * qty) - discountPaise`
///
/// All values are integer Paise — deterministic regardless of evaluation path.
class PriceResolver {
  const PriceResolver();

  /// Returns the configured rate for the qty-matching slab/party, or
  /// [genericPaise] if no rate list or slab applies.
  ///
  /// Resolution order:
  /// 1. Party-specific rate lists (partyId != null): first matching slab wins
  /// 2. Generic rate lists (partyId == null): first matching slab wins
  /// 3. Fallback: [genericPaise] — never fabricate a tier
  ///
  /// A slab "matches" when `slab.minQty <= qty` and either `slab.maxQty` is
  /// null or `qty <= slab.maxQty`.
  int resolveUnitPaise({
    required RateContext ctx,
    required int qty,
    required int genericPaise,
  }) {
    // 1. Check party-specific rate lists first.
    for (final rateList in ctx.partyRateLists) {
      for (final slab in rateList.slabs) {
        if (slab.matches(qty)) {
          return slab.unitPaise;
        }
      }
    }

    // 2. Check generic (product-level) rate lists.
    for (final rateList in ctx.genericRateLists) {
      for (final slab in rateList.slabs) {
        if (slab.matches(qty)) {
          return slab.unitPaise;
        }
      }
    }

    // 3. Fallback: generic product price. Never fabricate a tier.
    return genericPaise;
  }

  /// Computes the net line amount in integer Paise.
  ///
  /// Deterministic order (Requirement 11.5):
  /// 1. Resolve tier/rate-list price (already done — [resolvedUnitPaise])
  /// 2. Multiply by [qty]
  /// 3. Subtract [discountPaise]
  ///
  /// Formula: `(resolvedUnitPaise * qty) - discountPaise`
  ///
  /// All integer Paise — no floating-point intermediary.
  int netLinePaise({
    required int resolvedUnitPaise,
    required int qty,
    required int discountPaise,
  }) {
    return (resolvedUnitPaise * qty) - discountPaise;
  }
}
