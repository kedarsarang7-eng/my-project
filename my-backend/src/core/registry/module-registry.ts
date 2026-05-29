// ============================================================================
// MODULE REGISTRY — Central Plugin Registry
// ============================================================================
// Single source of truth for all registered business modules.
// Loaded once at Lambda cold-start. Zero runtime cost.
//
// TO ADD A NEW BUSINESS MODULE:
//   1. Create src/modules/<your-module>/manifest.ts
//   2. Import and register it here (one line)
//   3. Create src/modules/<your-module>/serverless.module.yml
//   4. Import the yml in serverless.yml
//   NO OTHER CORE FILE CHANGES REQUIRED.
// ============================================================================

import { ModuleManifest } from '../types/module.types';

// ── Module manifests ─────────────────────────────────────────────────────────
import { groceryManifest } from '../../modules/grocery/manifest';
import { pharmacyManifest } from '../../modules/pharmacy/manifest';
import { restaurantManifest } from '../../modules/restaurant/manifest';
import { clinicManifest } from '../../modules/clinic/manifest';
import { schoolErpManifest } from '../../modules/school-erp/manifest';
import { petrolPumpManifest } from '../../modules/petrol-pump/manifest';
import { jewelleryManifest } from '../../modules/jewellery/manifest';
import { hardwareManifest } from '../../modules/hardware/manifest';
import { clothingManifest } from '../../modules/clothing/manifest';
import { mobileShopManifest } from '../../modules/mobile-shop/manifest';
import { computerShopManifest } from '../../modules/computer-shop/manifest';
import { wholesaleManifest } from '../../modules/wholesale/manifest';
import { autoPartsManifest } from '../../modules/auto-parts/manifest';
import { bookStoreManifest } from '../../modules/book-store/manifest';
import { vegetablesBrokerManifest } from '../../modules/vegetables-broker/manifest';
import { decorationCateringManifest } from '../../modules/decoration-catering/manifest';

// ── Registry Assembly ────────────────────────────────────────────────────────

const MODULE_LIST: ModuleManifest[] = [
    groceryManifest,
    pharmacyManifest,
    restaurantManifest,
    clinicManifest,
    schoolErpManifest,
    petrolPumpManifest,
    jewelleryManifest,
    hardwareManifest,
    clothingManifest,
    mobileShopManifest,
    computerShopManifest,
    wholesaleManifest,
    autoPartsManifest,
    bookStoreManifest,
    vegetablesBrokerManifest,
    decorationCateringManifest,
];

// ── Validate uniqueness at cold-start ────────────────────────────────────────
function buildRegistry(modules: ModuleManifest[]): Map<string, ModuleManifest> {
    const registry = new Map<string, ModuleManifest>();
    for (const m of modules) {
        if (registry.has(m.id)) {
            throw new Error(`[ModuleRegistry] Duplicate module ID detected: "${m.id}". Each module must have a unique id.`);
        }
        // Validate SK prefix uniqueness across modules
        const allPrefixes = new Set<string>();
        for (const prefix of m.db.skPrefixes) {
            if (allPrefixes.has(prefix)) {
                throw new Error(`[ModuleRegistry] SK prefix collision: "${prefix}" in module "${m.id}"`);
            }
            allPrefixes.add(prefix);
        }
        registry.set(m.id, m);
    }
    return registry;
}

export const MODULE_REGISTRY: Map<string, ModuleManifest> = buildRegistry(MODULE_LIST);

// ── Query helpers ─────────────────────────────────────────────────────────────

/** Get a module by ID. Returns undefined if not found (never throws). */
export function getModule(moduleId: string): ModuleManifest | undefined {
    return MODULE_REGISTRY.get(moduleId);
}

/** Get all active (non-disabled) modules */
export function getActiveModules(): ModuleManifest[] {
    return [...MODULE_REGISTRY.values()].filter(m => m.status !== 'disabled');
}

/** Get modules for a specific business type */
export function getModulesForBusinessType(businessType: string): ModuleManifest[] {
    return [...MODULE_REGISTRY.values()].filter(m =>
        m.businessTypes.includes(businessType as any) && m.status !== 'disabled'
    );
}

/** Get all WS channel prefixes (for channel isolation validation) */
export function getAllWsChannelPrefixes(): string[] {
    return [...MODULE_REGISTRY.values()].map(m => m.wsChannelPrefix);
}

/** Get all SK prefixes owned by a module */
export function getModuleSkPrefixes(moduleId: string): string[] {
    return MODULE_REGISTRY.get(moduleId)?.db.skPrefixes ?? [];
}

/** Check if a given SK belongs to a specific module */
export function getModuleForSk(sk: string): ModuleManifest | undefined {
    for (const m of MODULE_REGISTRY.values()) {
        if (m.db.skPrefixes.some(prefix => sk.startsWith(prefix))) {
            return m;
        }
    }
    return undefined;
}

/** List all registered module IDs */
export function listModuleIds(): string[] {
    return [...MODULE_REGISTRY.keys()];
}
