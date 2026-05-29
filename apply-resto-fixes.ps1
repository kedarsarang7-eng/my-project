# PowerShell script to apply Restaurant vertical fixes
$ErrorActionPreference = "Stop"

$filePath = "g:\desktop app genuine\my-backend\src\handlers\resto.ts"
$content = Get-Content $filePath -Raw

# Fix 1: Add validateBomStockForBill helper function after validateManagerOverride
$helperFunction = @'

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

'@

# Insert helper function after validateManagerOverride
$insertPoint1 = "return { approvedBy: override.managerUserId, reason: override.reason || null };`n}`n`n/**`n * GET /resto/tables"
if ($content -match [regex]::Escape("return { approvedBy: override.managerUserId, reason: override.reason || null };`n}`n`n/**`n * GET /resto/tables")) {
    $content = $content -replace [regex]::Escape("return { approvedBy: override.managerUserId, reason: override.reason || null };`n}`n`n/**`n * GET /resto/tables"), ($helperFunction + "/**`n * GET /resto/tables")
    Write-Host "✓ Added validateBomStockForBill helper function"
} else {
    Write-Host "✗ Could not find insertion point for helper function"
}

# Fix 2: Add stock validation call in settleBill
$stockValidationCode = @'

        // -- 2b. PRE-FLIGHT STOCK VALIDATION (CRITICAL-1 FIX)
        const stockValidation = await validateBomStockForBill(auth.tenantId, pk, kotItems.items);
        if (!stockValidation.sufficient) {
            return response.error(409, 'INSUFFICIENT_RAW_MATERIAL_STOCK', `Cannot settle bill: ${stockValidation.message}`);
        }
'@

$insertPoint2 = "if (kotItems.items.length === 0) {`n            return response.badRequest('No active items on this bill. Nothing to settle.');`n        }`n`n        const preDiscountTotalCents"
if ($content -match [regex]::Escape($insertPoint2)) {
    $content = $content -replace [regex]::Escape($insertPoint2), ("if (kotItems.items.length === 0) {`n            return response.badRequest('No active items on this bill. Nothing to settle.');`n        }" + $stockValidationCode + "`n        const preDiscountTotalCents")
    Write-Host "✓ Added stock validation in settleBill"
} else {
    Write-Host "✗ Could not find insertion point for stock validation"
}

# Fix 3: Add WebSocket broadcast for table status
$wsBroadcastCode = @'

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
'@

$insertPoint3 = ").catch(err => logger.warn('WS broadcast failed', { error: (err as Error).message }));`n`n        return response.success({`n            message: 'Bill settled and invoice created'"
if ($content -match [regex]::Escape($insertPoint3)) {
    $content = $content -replace [regex]::Escape($insertPoint3), (").catch(err => logger.warn('WS broadcast failed', { error: (err as Error).message }));" + $wsBroadcastCode + "`n        return response.success({`n            message: 'Bill settled and invoice created'")
    Write-Host "✓ Added WebSocket broadcast for table status"
} else {
    Write-Host "✗ Could not find insertion point for WebSocket broadcast"
}

# Write the updated content
$content | Set-Content $filePath -NoNewline
Write-Host "`nFixes applied! File updated: $filePath"
