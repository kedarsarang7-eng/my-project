// ============================================================================
// RESTAURANT SK PREFIXES — Single Source of Truth
// ============================================================================
// Phase 1 fix (restaurant-audit remediation): resto.ts and sync.service.ts
// previously maintained two INDEPENDENT prefix maps for the same entities,
// which drifted apart (e.g. `RESTOTABLE#` vs `RESTTABLE#`). This module is
// the one place either file may define a restaurant SK prefix. Do not
// hardcode a restaurant prefix literal anywhere else — import from here.
//
// Canonical values were chosen as `resto.ts`'s existing prefixes, NOT
// sync.service.ts's, because:
//   1. resto.ts is the confirmed-live path for RestaurantOpsRepository's
//      direct API calls (reservations, waitlist, table transfer/merge/split,
//      combos, happy-hours, delivery, aggregator, receipts — see Phase 0
//      finding #4).
//   2. restaurant-v1-public.ts (the PWA-facing handler actually consumed by
//      dukan_restro_pwa in production) independently uses the SAME prefixes
//      as resto.ts (`RESTOTABLE#`, `FOODMENUITEM#`) — confirmed by grep. Two
//      independently-written files agreeing is strong evidence this is the
//      real, live scheme.
//   3. sync.service.ts's generic push/pull path is CONFIRMED to never call
//      /resto/* and is never called BY /resto/* — it is a fully separate
//      data path for FoodOrderRepository/RestaurantTableRepository/etc. on
//      the Flutter side (see Phase 0 finding #4). Changing resto.ts's
//      prefixes would risk breaking the one confirmed-live restaurant API
//      surface for zero benefit.
//
// If a backfill is ever needed for records written under the OLD
// sync.service.ts prefixes, see scripts/backfill-restaurant-sk-prefixes.js
// (Phase 1, step 5) — do NOT run it without first confirming via a
// --dry-run scan whether any such records actually exist.
// ============================================================================

/**
 * Canonical DynamoDB SK prefixes for every restaurant-module entity.
 *
 * Both `resto.ts` and `sync.service.ts` (and any future restaurant code)
 * MUST import from this object rather than hardcoding a prefix string.
 */
export const RestaurantSkPrefix = {
    TABLE: 'RESTOTABLE#',
    FLOOR: 'RESTOFLOOR#',
    BILL: 'RESTOBILL#',
    KOT: 'KOT#',
    KOT_ITEM: 'KOTITEM#',
    MENU_ITEM: 'FOODMENUITEM#',
    CATEGORY: 'FOODCATEGORY#',
    COMBO: 'RESTOCOMBO#',
    HAPPY_HOUR: 'RESTOHAPPYHOUR#',
} as const;

export type RestaurantEntityKey = keyof typeof RestaurantSkPrefix;

/**
 * Maps the client-facing sync table name (as sent by FoodOrderRepository /
 * RestaurantTableRepository / FoodMenuRepository / RestaurantBillRepository
 * via the generic /sync/push /sync/pull path) to its canonical SK prefix.
 *
 * This is what sync.service.ts's TABLE_TO_SK_PREFIX map should delegate to
 * for restaurant entries, instead of hardcoding its own values.
 */
export const RESTAURANT_SYNC_TABLE_TO_SK_PREFIX: Record<string, string> = {
    restaurant_tables: RestaurantSkPrefix.TABLE,
    restaurant_floors: RestaurantSkPrefix.FLOOR,
    restaurant_bills: RestaurantSkPrefix.BILL,
    restaurant_kots: RestaurantSkPrefix.KOT,
    food_menu_items: RestaurantSkPrefix.MENU_ITEM,
    food_categories: RestaurantSkPrefix.CATEGORY,
};
