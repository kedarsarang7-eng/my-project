# Restaurant Vertical - Critical Fixes Summary

## Status: File Corrupted During Automated Fix Attempt

The file `my-backend/src/handlers/resto.ts` was corrupted during the automated fix process (487K+ lines of duplicate functions). 

**You need to restore the original file first**, then apply these fixes manually.

---

## CRITICAL-1: Add BOM Stock Validation in settleBill

### Step 1: Add Helper Function (after validateManagerOverride, around line 240)

```typescript
/**
 * CRITICAL-1 FIX: Pre-flight BOM stock validation for restaurant bills
 */
async function validateBomStockForBill(
    tenantId: string,
    pk: string,
    kotItems: Array<Record<string, any>>,
): Promise<{ sufficient: boolean; message?: string }> {
    try {
        const menuItemQty = new Map<string, number>();
        for (const item of kotItems) {
            const menuId = item.menuItemId;
            if (!menuId) continue;
            const current = menuItemQty.get(menuId) || 0;
            menuItemQty.set(menuId, current + (Number(item.quantity) || 0));
        }
        if (menuItemQty.size === 0) return { sufficient: true };
        
        const menuKeys = Array.from(menuItemQty.keys()).map(id => ({ PK: pk, SK: `FOODMENUITEM#${id}` }));
        const menuItems = await batchGetItems<Record<string, any>>(menuKeys);
        const menuToProduct = new Map<string, string>();
        for (const m of menuItems) {
            const menuId = m.id || String(m.SK || '').replace('FOODMENUITEM#', '');
            if (m.productId) menuToProduct.set(menuId, m.productId);
        }
        
        const productIds = Array.from(new Set(menuToProduct.values()));
        if (productIds.length === 0) return { sufficient: true };
        
        const recipeKeys = productIds.map(id => ({ PK: pk, SK: `RECIPE#${id}` }));
        const recipes = await batchGetItems<Record<string, any>>(recipeKeys);
        const recipeMap = new Map<string, Record<string, any>>();
        for (const r of recipes) {
            const prodId = String(r.SK || '').replace('RECIPE#', '');
            recipeMap.set(prodId, r);
        }
        
        const ingredientNeeds = new Map<string, { name: string; qtyNeeded: number; currentStock: number }>();
        for (const [menuId, qty] of menuItemQty.entries()) {
            const productId = menuToProduct.get(menuId);
            if (!productId) continue;
            const recipe = recipeMap.get(productId);
            if (!recipe || !Array.isArray(recipe.ingredients)) continue;
            for (const ing of recipe.ingredients) {
                const ingId = ing.inventoryId || ing.productId;
                if (!ingId) continue;
                const ingQty = (ing.quantityPerUnit || 1) * qty;
                const existing = ingredientNeeds.get(ingId);
                if (existing) { existing.qtyNeeded += ingQty; }
                else { ingredientNeeds.set(ingId, { name: ing.name || ingId, qtyNeeded: ingQty, currentStock: 0 }); }
            }
        }
        
        if (ingredientNeeds.size === 0) return { sufficient: true };
        
        const ingKeys = Array.from(ingredientNeeds.keys()).map(id => ({ PK: pk, SK: Keys.productSK(id) }));
        const ingProducts = await batchGetItems<Record<string, any>>(ingKeys);
        const stockMap = new Map<string, number>();
        for (const p of ingProducts) {
            const pId = p.id || String(p.SK || '').replace('PRODUCT#', '');
            stockMap.set(pId, p.currentStock || 0);
            const need = ingredientNeeds.get(pId);
            if (need && p.name) need.name = p.name;
        }
        
        for (const [ingId, need] of ingredientNeeds.entries()) {
            const available = stockMap.get(ingId) || 0;
            if (available < need.qtyNeeded) {
                return { sufficient: false, message: `Insufficient stock for '${need.name}': available=${available}, needed=${need.qtyNeeded}` };
            }
        }
        return { sufficient: true };
    } catch (err: any) {
        logger.warn('BOM stock validation failed, allowing settlement', { error: err.message, tenantId });
        return { sufficient: true };
    }
}
```

### Step 2: Add Stock Validation Call in settleBill (after line ~2901)

Find this code in settleBill:
```typescript
if (kotItems.items.length === 0) {
    return response.badRequest('No active items on this bill. Nothing to settle.');
}

const preDiscountTotalCents = kotItems.items.reduce(...
```

Add after the empty check:
```typescript
// -- 2b. PRE-FLIGHT STOCK VALIDATION (CRITICAL-1 FIX)
const stockValidation = await validateBomStockForBill(auth.tenantId, pk, kotItems.items);
if (!stockValidation.sufficient) {
    return response.error(409, 'INSUFFICIENT_RAW_MATERIAL_STOCK', `Cannot settle bill: ${stockValidation.message}`);
}
```

---

## CRITICAL-2: Add WebSocket Broadcast for Table Status

### In settleBill, after the broadcast settlement block (around line 3117)

Find:
```typescript
// -- 9. Broadcast settlement -------------------------------------
wsService.broadcastToClientType(
    auth.tenantId, ClientType.RESTAURANT_STAFF_APP,
    WSEventName.BILL_CREATED,
    {
        action: 'settled', billId, tableId: bill.tableId,
        invoiceId: invoiceResult.id, totalCents: invoiceResult.totalCents,
    },
).catch(err => logger.warn('WS broadcast failed', { error: (err as Error).message }));

return response.success({
```

Add before `return response.success({`:
```typescript
// CRITICAL-2 FIX: Broadcast table status change notification
if (bill.tableId) {
    wsService.broadcastToClientType(
        auth.tenantId, ClientType.RESTAURANT_STAFF_APP,
        WSEventName.BILL_UPDATED,
        {
            action: 'table_status_changed',
            tableId: bill.tableId,
            billId,
            status: 'settled',
            message: 'Bill settled - table ready for release',
        },
    ).catch(err => logger.warn('WS broadcast failed', { error: (err as Error).message }));
}
```

---

## HIGH-1: Frontend - Fix Dashboard to Listen for Invoice Events

### File: `Dukan_x/lib/features/restaurant/presentation/screens/restaurant_daily_summary_screen.dart`

Add invoice event subscription in initState (around line 66):
```dart
// Add this alongside existing kotCreated subscription
_onInvoiceSettled = (data) {
  if (mounted) {
    LoggerService.d('RestaurantSummary', 
      '[Restaurant] Websocket Event: INVOICE_SETTLED. Refreshing daily summary.',
    );
    _loadData();
  }
};
WebSocketService.instance.subscribe(WSEventName.BILL_CREATED, _onInvoiceSettled);
```

And in dispose():
```dart
WebSocketService.instance.unsubscribe(WSEventName.BILL_CREATED, _onInvoiceSettled);
```

---

## MEDIUM: Add Inventory Filters for Visible/Dead Stock

### File: `Dukan_x/lib/features/restaurant/data/repositories/restaurant_inventory_repository.dart`

Add these methods after line 198:

```dart
/// Get visible stock items (qty > 0)
Future<RepositoryResult<List<RestaurantInventoryItem>>> getVisibleStock(
  String vendorId,
) async {
  return await _errorHandler.runSafe<List<RestaurantInventoryItem>>(() async {
    final entities =
        await (_db.select(_db.restaurantInventoryItems)
              ..where(
                (t) =>
                    t.vendorId.equals(vendorId) &
                    t.currentStock.isBiggerThanValue(0) &
                    t.deletedAt.isNull(),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.name)]))
            .get();
    return entities.map((e) => RestaurantInventoryItem.fromEntity(e)).toList();
  }, 'getVisibleStock');
}

/// Get dead stock items (qty = 0)
Future<RepositoryResult<List<RestaurantInventoryItem>>> getDeadStock(
  String vendorId,
) async {
  return await _errorHandler.runSafe<List<RestaurantInventoryItem>>(() async {
    final entities =
        await (_db.select(_db.restaurantInventoryItems)
              ..where(
                (t) =>
                    t.vendorId.equals(vendorId) &
                    t.currentStock.equals(0) &
                    t.deletedAt.isNull(),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.name)]))
            .get();
    return entities.map((e) => RestaurantInventoryItem.fromEntity(e)).toList();
  }, 'getDeadStock');
}
```

---

## Test Commands to Verify Fixes

```bash
# Backend tests
cd my-backend
npm test -- --testPathPattern="restaurant-kot-gst"
npm test -- --testPathPattern="data-integrity"

# Type check
npx tsc --noEmit src/handlers/resto.ts
```

---

## Summary of All Fixes

| Priority | Issue | File | Status |
|----------|-------|------|--------|
| CRITICAL | Zero stock guard missing | resto.ts | ⏳ PENDING |
| CRITICAL | WebSocket for table status | resto.ts | ⏳ PENDING |
| HIGH | Dashboard invoice events | restaurant_daily_summary_screen.dart | ⏳ PENDING |
| MEDIUM | Inventory filters | restaurant_inventory_repository.dart | ⏳ PENDING |

**Note:** The audit identified additional issues that were actually already implemented:
- ✅ WebSocket broadcasting (KOT_CREATED, BILL_UPDATED) - Already exists
- ✅ KOT item-level cancellation - Already implemented via `cancelKotItem` handler
- ✅ Stock check at KOT creation - Already implemented (`isOutOfStock` check)
