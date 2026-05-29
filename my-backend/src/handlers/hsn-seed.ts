// ============================================================================
// HSN Master Data Seed Lambda — One-Time Population
// ============================================================================
// Populates the HSNMASTER# partition with standard Indian GST HSN codes.
// Triggered manually via: POST /admin/hsn-seed
// or: serverless invoke -f hsnMasterSeed
//
// Covers priority categories:
//   1. Cereals (Chapter 10)          — 0% / 5%
//   2. Dairy (0401-0406)             — 0% / 5% / 12%
//   3. Pharmaceuticals (Chapter 30)  — 5% / 12%
//   4. Petroleum (2710)              — 18% / various
//   5. Books/Printed Matter (49xx)   — 0% (exempt)
//   6. Clothing (61xx)               — 5% / 12%
//   7. Computers/Peripherals (8471-8473) — 18%
//   8. Mobile Phones (8517)          — 12%
//   9. Electronics (85xx)            — 18%
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole } from '../types/tenant.types';
import { Keys, batchWrite, putItem } from '../config/dynamodb.config';
import * as response from '../utils/response';
import { logger } from '../utils/logger';

// ── HSN Master Record Builder ──────────────────────────────────────────────

interface HsnSeedEntry {
    hsnCode: string;
    description: string;
    cgstRateBp: number;
    sgstRateBp: number;
    igstRateBp: number;
    exempted: boolean;
    effectiveFrom: string;
}

function buildHsnItem(entry: HsnSeedEntry): Record<string, unknown> {
    const now = new Date().toISOString();
    return {
        PK: Keys.hsnMasterPK(),
        SK: Keys.hsnMasterSK(entry.hsnCode),
        entityType: 'HSN_MASTER',
        hsnCode: entry.hsnCode,
        description: entry.description,
        cgstRateBp: entry.cgstRateBp,
        sgstRateBp: entry.sgstRateBp,
        igstRateBp: entry.igstRateBp,
        exempted: entry.exempted,
        effectiveFrom: entry.effectiveFrom,
        createdAt: now,
        updatedAt: now,
    };
}

// ── Standard Indian GST HSN Codes ──────────────────────────────────────────

const HSN_SEED_DATA: HsnSeedEntry[] = [
    // ═══════════════════════════════════════════════════════════════════════
    // CHAPTER 10: CEREALS
    // ═══════════════════════════════════════════════════════════════════════
    { hsnCode: '1001', description: 'Wheat and meslin', cgstRateBp: 0, sgstRateBp: 0, igstRateBp: 0, exempted: true, effectiveFrom: '2017-07-01' },
    { hsnCode: '1002', description: 'Rye', cgstRateBp: 0, sgstRateBp: 0, igstRateBp: 0, exempted: true, effectiveFrom: '2017-07-01' },
    { hsnCode: '1003', description: 'Barley', cgstRateBp: 0, sgstRateBp: 0, igstRateBp: 0, exempted: true, effectiveFrom: '2017-07-01' },
    { hsnCode: '1004', description: 'Oats', cgstRateBp: 0, sgstRateBp: 0, igstRateBp: 0, exempted: true, effectiveFrom: '2017-07-01' },
    { hsnCode: '1005', description: 'Maize (corn)', cgstRateBp: 0, sgstRateBp: 0, igstRateBp: 0, exempted: true, effectiveFrom: '2017-07-01' },
    { hsnCode: '1006', description: 'Rice', cgstRateBp: 0, sgstRateBp: 0, igstRateBp: 0, exempted: true, effectiveFrom: '2017-07-01' },
    { hsnCode: '1007', description: 'Grain sorghum (Jowar)', cgstRateBp: 0, sgstRateBp: 0, igstRateBp: 0, exempted: true, effectiveFrom: '2017-07-01' },
    { hsnCode: '1008', description: 'Buckwheat, millet, other cereals (Ragi, Bajra)', cgstRateBp: 0, sgstRateBp: 0, igstRateBp: 0, exempted: true, effectiveFrom: '2017-07-01' },
    // Branded/packaged cereals — 5% GST
    { hsnCode: '100630', description: 'Rice – semi-milled/wholly-milled (branded/packaged)', cgstRateBp: 250, sgstRateBp: 250, igstRateBp: 500, exempted: false, effectiveFrom: '2022-07-18' },
    { hsnCode: '100190', description: 'Wheat flour (Atta) – branded/packaged', cgstRateBp: 250, sgstRateBp: 250, igstRateBp: 500, exempted: false, effectiveFrom: '2022-07-18' },

    // ═══════════════════════════════════════════════════════════════════════
    // CHAPTER 04: DAIRY PRODUCTS
    // ═══════════════════════════════════════════════════════════════════════
    { hsnCode: '0401', description: 'Milk and cream, not concentrated (fresh milk)', cgstRateBp: 0, sgstRateBp: 0, igstRateBp: 0, exempted: true, effectiveFrom: '2017-07-01' },
    { hsnCode: '0402', description: 'Milk and cream, concentrated or sweetened (condensed milk, milk powder)', cgstRateBp: 250, sgstRateBp: 250, igstRateBp: 500, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '0403', description: 'Buttermilk, curd, yogurt, kephir', cgstRateBp: 0, sgstRateBp: 0, igstRateBp: 0, exempted: true, effectiveFrom: '2017-07-01' },
    { hsnCode: '040310', description: 'Yogurt – flavoured, pre-packaged', cgstRateBp: 250, sgstRateBp: 250, igstRateBp: 500, exempted: false, effectiveFrom: '2022-07-18' },
    { hsnCode: '0404', description: 'Whey, natural milk constituents', cgstRateBp: 250, sgstRateBp: 250, igstRateBp: 500, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '0405', description: 'Butter and other fats from milk (ghee)', cgstRateBp: 600, sgstRateBp: 600, igstRateBp: 1200, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '0406', description: 'Cheese and curd (paneer – branded, processed)', cgstRateBp: 600, sgstRateBp: 600, igstRateBp: 1200, exempted: false, effectiveFrom: '2017-07-01' },

    // ═══════════════════════════════════════════════════════════════════════
    // CHAPTER 30: PHARMACEUTICAL PRODUCTS
    // ═══════════════════════════════════════════════════════════════════════
    { hsnCode: '3001', description: 'Glands, organs for organotherapeutic use; heparin; other human/animal substances', cgstRateBp: 250, sgstRateBp: 250, igstRateBp: 500, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '3002', description: 'Vaccines, toxins, cultures of micro-organisms, blood antisera', cgstRateBp: 250, sgstRateBp: 250, igstRateBp: 500, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '3003', description: 'Medicaments – unmixed, not in measured doses (bulk drugs)', cgstRateBp: 600, sgstRateBp: 600, igstRateBp: 1200, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '3004', description: 'Medicaments – mixed, in measured doses or for retail (formulations)', cgstRateBp: 600, sgstRateBp: 600, igstRateBp: 1200, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '300490', description: 'Other medicaments – OTC drugs, tablets, syrups', cgstRateBp: 600, sgstRateBp: 600, igstRateBp: 1200, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '30049011', description: 'Ayurvedic medicaments – for retail sale', cgstRateBp: 600, sgstRateBp: 600, igstRateBp: 1200, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '30049099', description: 'Other pharmaceutical formulations', cgstRateBp: 600, sgstRateBp: 600, igstRateBp: 1200, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '3005', description: 'Wadding, gauze, bandages with pharmaceutical substances (first aid)', cgstRateBp: 600, sgstRateBp: 600, igstRateBp: 1200, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '3006', description: 'Pharmaceutical goods – sterile surgical catgut, blood-grouping reagents', cgstRateBp: 600, sgstRateBp: 600, igstRateBp: 1200, exempted: false, effectiveFrom: '2017-07-01' },

    // ═══════════════════════════════════════════════════════════════════════
    // CHAPTER 27: PETROLEUM PRODUCTS
    // ═══════════════════════════════════════════════════════════════════════
    { hsnCode: '2710', description: 'Petroleum oils and oils from bituminous minerals (crude)', cgstRateBp: 250, sgstRateBp: 250, igstRateBp: 500, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '271012', description: 'Light petroleum oils – motor spirit (petrol)', cgstRateBp: 0, sgstRateBp: 0, igstRateBp: 0, exempted: true, effectiveFrom: '2017-07-01' },
    { hsnCode: '271019', description: 'Diesel / HSD (High Speed Diesel)', cgstRateBp: 0, sgstRateBp: 0, igstRateBp: 0, exempted: true, effectiveFrom: '2017-07-01' },
    { hsnCode: '271011', description: 'Aviation turbine fuel (ATF)', cgstRateBp: 0, sgstRateBp: 0, igstRateBp: 0, exempted: true, effectiveFrom: '2017-07-01' },
    { hsnCode: '271113', description: 'Liquefied Petroleum Gas (LPG) – domestic', cgstRateBp: 250, sgstRateBp: 250, igstRateBp: 500, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '271121', description: 'Natural gas – compressed (CNG)', cgstRateBp: 250, sgstRateBp: 250, igstRateBp: 500, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '271019', description: 'Kerosene – PDS (public distribution)', cgstRateBp: 0, sgstRateBp: 0, igstRateBp: 0, exempted: true, effectiveFrom: '2017-07-01' },
    { hsnCode: '271020', description: 'Lubricating oils and greases', cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800, exempted: false, effectiveFrom: '2017-07-01' },

    // ═══════════════════════════════════════════════════════════════════════
    // CHAPTER 49: BOOKS & PRINTED MATTER
    // ═══════════════════════════════════════════════════════════════════════
    { hsnCode: '4901', description: 'Printed books, brochures, leaflets', cgstRateBp: 0, sgstRateBp: 0, igstRateBp: 0, exempted: true, effectiveFrom: '2017-07-01' },
    { hsnCode: '4902', description: 'Newspapers, journals, periodicals', cgstRateBp: 0, sgstRateBp: 0, igstRateBp: 0, exempted: true, effectiveFrom: '2017-07-01' },
    { hsnCode: '4903', description: "Children's picture, drawing or colouring books", cgstRateBp: 0, sgstRateBp: 0, igstRateBp: 0, exempted: true, effectiveFrom: '2017-07-01' },
    { hsnCode: '4904', description: 'Music, printed or in manuscript', cgstRateBp: 0, sgstRateBp: 0, igstRateBp: 0, exempted: true, effectiveFrom: '2017-07-01' },
    { hsnCode: '4905', description: 'Maps, hydrographic or similar charts', cgstRateBp: 0, sgstRateBp: 0, igstRateBp: 0, exempted: true, effectiveFrom: '2017-07-01' },
    { hsnCode: '4907', description: 'Unused postage, stamp-duty, cheque forms', cgstRateBp: 600, sgstRateBp: 600, igstRateBp: 1200, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '4908', description: 'Transfers (decalcomanias)', cgstRateBp: 600, sgstRateBp: 600, igstRateBp: 1200, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '4910', description: 'Calendars of any kind, printed', cgstRateBp: 600, sgstRateBp: 600, igstRateBp: 1200, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '4911', description: 'Other printed matter – trade advertising material, commercial catalogues', cgstRateBp: 600, sgstRateBp: 600, igstRateBp: 1200, exempted: false, effectiveFrom: '2017-07-01' },

    // ═══════════════════════════════════════════════════════════════════════
    // CHAPTER 61: CLOTHING — KNITTED OR CROCHETED
    // Per GST Council: ≤₹1000 MRP = 5%, >₹1000 MRP = 12%
    // We seed both slabs; validation uses the rate submitted by the frontend.
    // ═══════════════════════════════════════════════════════════════════════
    { hsnCode: '6101', description: 'Men\'s/boys\' overcoats, car-coats, capes (knitted) – MRP ≤₹1000', cgstRateBp: 250, sgstRateBp: 250, igstRateBp: 500, exempted: false, effectiveFrom: '2022-01-01' },
    { hsnCode: '610100', description: 'Men\'s/boys\' overcoats, car-coats (knitted) – MRP >₹1000', cgstRateBp: 600, sgstRateBp: 600, igstRateBp: 1200, exempted: false, effectiveFrom: '2022-01-01' },
    { hsnCode: '6102', description: 'Women\'s/girls\' overcoats, car-coats (knitted) – MRP ≤₹1000', cgstRateBp: 250, sgstRateBp: 250, igstRateBp: 500, exempted: false, effectiveFrom: '2022-01-01' },
    { hsnCode: '610200', description: 'Women\'s/girls\' overcoats (knitted) – MRP >₹1000', cgstRateBp: 600, sgstRateBp: 600, igstRateBp: 1200, exempted: false, effectiveFrom: '2022-01-01' },
    { hsnCode: '6103', description: 'Men\'s/boys\' suits, ensembles, trousers (knitted) – MRP ≤₹1000', cgstRateBp: 250, sgstRateBp: 250, igstRateBp: 500, exempted: false, effectiveFrom: '2022-01-01' },
    { hsnCode: '610300', description: 'Men\'s/boys\' suits, trousers (knitted) – MRP >₹1000', cgstRateBp: 600, sgstRateBp: 600, igstRateBp: 1200, exempted: false, effectiveFrom: '2022-01-01' },
    { hsnCode: '6104', description: 'Women\'s/girls\' suits, ensembles, dresses (knitted) – MRP ≤₹1000', cgstRateBp: 250, sgstRateBp: 250, igstRateBp: 500, exempted: false, effectiveFrom: '2022-01-01' },
    { hsnCode: '610400', description: 'Women\'s/girls\' suits, dresses (knitted) – MRP >₹1000', cgstRateBp: 600, sgstRateBp: 600, igstRateBp: 1200, exempted: false, effectiveFrom: '2022-01-01' },
    { hsnCode: '6105', description: 'Men\'s/boys\' shirts (knitted) – MRP ≤₹1000', cgstRateBp: 250, sgstRateBp: 250, igstRateBp: 500, exempted: false, effectiveFrom: '2022-01-01' },
    { hsnCode: '610500', description: 'Men\'s/boys\' shirts (knitted) – MRP >₹1000', cgstRateBp: 600, sgstRateBp: 600, igstRateBp: 1200, exempted: false, effectiveFrom: '2022-01-01' },
    { hsnCode: '6109', description: 'T-shirts, singlets, vests (knitted) – MRP ≤₹1000', cgstRateBp: 250, sgstRateBp: 250, igstRateBp: 500, exempted: false, effectiveFrom: '2022-01-01' },
    { hsnCode: '610900', description: 'T-shirts, singlets (knitted) – MRP >₹1000', cgstRateBp: 600, sgstRateBp: 600, igstRateBp: 1200, exempted: false, effectiveFrom: '2022-01-01' },
    { hsnCode: '6110', description: 'Jerseys, pullovers, cardigans, waistcoats (knitted) – MRP ≤₹1000', cgstRateBp: 250, sgstRateBp: 250, igstRateBp: 500, exempted: false, effectiveFrom: '2022-01-01' },
    { hsnCode: '6115', description: 'Panty hose, tights, stockings, socks (knitted) – MRP ≤₹1000', cgstRateBp: 250, sgstRateBp: 250, igstRateBp: 500, exempted: false, effectiveFrom: '2022-01-01' },
    { hsnCode: '6116', description: 'Gloves, mittens (knitted) – MRP ≤₹1000', cgstRateBp: 250, sgstRateBp: 250, igstRateBp: 500, exempted: false, effectiveFrom: '2022-01-01' },
    { hsnCode: '6117', description: 'Other made up clothing accessories – shawls, scarves (knitted) – MRP ≤₹1000', cgstRateBp: 250, sgstRateBp: 250, igstRateBp: 500, exempted: false, effectiveFrom: '2022-01-01' },

    // ═══════════════════════════════════════════════════════════════════════
    // CHAPTER 84: COMPUTERS & PERIPHERALS
    // ═══════════════════════════════════════════════════════════════════════
    { hsnCode: '8471', description: 'Automatic data processing machines (computers, laptops)', cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '847130', description: 'Portable data processing machines (laptops, notebooks)', cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '847141', description: 'Desktop computers', cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '847150', description: 'Computer processing units (servers)', cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '8472', description: 'Other office machines (ATM, voting machines)', cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '8473', description: 'Parts and accessories of computers (keyboards, mice, monitors)', cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800, exempted: false, effectiveFrom: '2017-07-01' },

    // ═══════════════════════════════════════════════════════════════════════
    // CHAPTER 85: MOBILE PHONES & ELECTRONICS
    // ═══════════════════════════════════════════════════════════════════════
    { hsnCode: '8517', description: 'Telephone sets incl. smartphones, mobile phones', cgstRateBp: 600, sgstRateBp: 600, igstRateBp: 1200, exempted: false, effectiveFrom: '2020-04-01' },
    { hsnCode: '851712', description: 'Mobile phones (cellular)', cgstRateBp: 600, sgstRateBp: 600, igstRateBp: 1200, exempted: false, effectiveFrom: '2020-04-01' },
    { hsnCode: '851762', description: 'Routers, modems, networking equipment', cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800, exempted: false, effectiveFrom: '2017-07-01' },

    // General electronics — 18% GST
    { hsnCode: '8501', description: 'Electric motors and generators', cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '8504', description: 'Electrical transformers, static converters, UPS', cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '8506', description: 'Primary cells and batteries', cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '8507', description: 'Electric accumulators (rechargeable batteries, lithium-ion)', cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '8508', description: 'Vacuum cleaners', cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '8509', description: 'Electro-mechanical domestic appliances (mixers, juicers)', cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '8516', description: 'Electric water heaters, hair dryers, irons, ovens', cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '8518', description: 'Microphones, loudspeakers, headphones, amplifiers', cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '8519', description: 'Sound recording/reproducing apparatus', cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '8521', description: 'Video recording/reproducing apparatus', cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '8523', description: 'Discs, tapes, solid-state storage (pen drives, memory cards)', cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '8525', description: 'Transmission apparatus – TV cameras, CCTV, webcams', cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '8528', description: 'Monitors, projectors, television receivers', cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '8534', description: 'Printed circuits (PCBs)', cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '8536', description: 'Electrical switches, sockets, plugs, fuses', cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '8541', description: 'Semiconductor devices (diodes, transistors, LEDs)', cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '8542', description: 'Electronic integrated circuits (ICs, chips)', cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '8544', description: 'Insulated wire, cables, optical fibre cables', cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800, exempted: false, effectiveFrom: '2017-07-01' },
    { hsnCode: '8548', description: 'Waste and scrap of primary cells, batteries, electronic components', cgstRateBp: 900, sgstRateBp: 900, igstRateBp: 1800, exempted: false, effectiveFrom: '2017-07-01' },
];

// ── Handler ────────────────────────────────────────────────────────────────

/**
 * POST /admin/hsn-seed
 * One-time seed of HSN master table with standard Indian GST codes.
 * Restricted to OWNER/ADMIN roles.
 */
export const handler = authorizedHandler(
    [UserRole.OWNER, UserRole.ADMIN],
    async (_event, _context, _auth) => {
        logger.info('HSN Master seed started', { totalEntries: HSN_SEED_DATA.length });

        const items = HSN_SEED_DATA.map(entry => ({
            type: 'put' as const,
            item: buildHsnItem(entry),
        }));

        try {
            await batchWrite(items);

            logger.info('HSN Master seed completed successfully', {
                totalSeeded: HSN_SEED_DATA.length,
            });

            return response.success({
                message: 'HSN master table seeded successfully',
                totalEntries: HSN_SEED_DATA.length,
                categories: {
                    cereals: HSN_SEED_DATA.filter(e => e.hsnCode.startsWith('10')).length,
                    dairy: HSN_SEED_DATA.filter(e => e.hsnCode.startsWith('04')).length,
                    pharmaceuticals: HSN_SEED_DATA.filter(e => e.hsnCode.startsWith('30')).length,
                    petroleum: HSN_SEED_DATA.filter(e => e.hsnCode.startsWith('27')).length,
                    books: HSN_SEED_DATA.filter(e => e.hsnCode.startsWith('49')).length,
                    clothing: HSN_SEED_DATA.filter(e => e.hsnCode.startsWith('61')).length,
                    computers: HSN_SEED_DATA.filter(e => e.hsnCode.startsWith('847')).length,
                    electronics: HSN_SEED_DATA.filter(e => e.hsnCode.startsWith('85')).length,
                },
            }, 201);
        } catch (err) {
            logger.error('HSN Master seed failed', { error: (err as Error).message });
            return response.error(500, 'HSN_SEED_FAILED', `Failed to seed HSN master table: ${(err as Error).message}`);
        }
    },
);
