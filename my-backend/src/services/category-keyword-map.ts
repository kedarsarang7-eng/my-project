import { config } from '../config/environment';
// ============================================================================
// Category Keyword Map — Deterministic Auto-Categorization
// ============================================================================
// Priority: keyword map first → LLM fallback (Claude claude-sonnet-4-20250514) → 'General'
// LLM results are cached in DynamoDB (key: SHA-256(normalizedName+vertical), TTL 30 days).
// No external package dependencies — uses only Node crypto built-in.
// ============================================================================

import { createHash } from 'crypto';
import { getItem, putItem, Keys } from '../config/dynamodb.config';
import { logger } from '../utils/logger';
import { CategoryCacheRecord } from '../types/import.types';

// ── Keyword Maps per Business Vertical ──────────────────────────────────────
// Each entry: [category, ...keywords] — keywords are matched against normalizedName.
// Assumption: categories match the string values used in InventoryItem.category.

type CategoryEntry = { category: string; keywords: string[] };

const KEYWORD_MAPS: Record<string, CategoryEntry[]> = {
    grocery: [
        { category: 'Dairy & Eggs', keywords: ['milk', 'curd', 'yogurt', 'paneer', 'cheese', 'butter', 'ghee', 'cream', 'egg', 'dahi'] },
        { category: 'Grains & Cereals', keywords: ['rice', 'wheat', 'flour', 'maida', 'atta', 'suji', 'rava', 'oats', 'poha', 'corn', 'barley', 'ragi', 'bajra', 'jowar'] },
        { category: 'Pulses & Lentils', keywords: ['dal', 'lentil', 'chana', 'moong', 'urad', 'rajma', 'masoor', 'toor', 'arhar', 'peas'] },
        { category: 'Oils & Fats', keywords: ['oil', 'vanaspati', 'sunflower', 'mustard', 'groundnut', 'coconut oil', 'palm', 'soybean oil'] },
        { category: 'Spices & Condiments', keywords: ['salt', 'pepper', 'turmeric', 'haldi', 'cumin', 'jeera', 'coriander', 'chilli', 'mirch', 'garam masala', 'cardamom', 'clove', 'cinnamon', 'ginger', 'garlic', 'vinegar', 'sauce', 'ketchup', 'pickle', 'achar'] },
        { category: 'Sugar & Sweeteners', keywords: ['sugar', 'jaggery', 'honey', 'gur', 'shakkar', 'syrup'] },
        { category: 'Tea & Coffee', keywords: ['tea', 'chai', 'coffee', 'green tea', 'herbal tea'] },
        { category: 'Beverages', keywords: ['juice', 'drink', 'water', 'soda', 'cola', 'squash', 'sharbat', 'lassi', 'nimbu'] },
        { category: 'Snacks & Biscuits', keywords: ['biscuit', 'cookie', 'chips', 'namkeen', 'wafer', 'cracker', 'popcorn', 'chocolate', 'candy', 'toffee', 'choco'] },
        { category: 'Personal Care', keywords: ['soap', 'shampoo', 'detergent', 'toothpaste', 'toothbrush', 'face wash', 'lotion', 'cream', 'powder', 'deo', 'deodorant', 'perfume', 'sanitizer'] },
        { category: 'Household', keywords: ['agarbatti', 'incense', 'candle', 'match', 'lighter', 'floor cleaner', 'vessel', 'utensil', 'bag', 'foil', 'wrap'] },
        { category: 'Frozen Foods', keywords: ['frozen', 'ice cream', 'kulfi', 'popsicle'] },
    ],
    pharmacy: [
        { category: 'Analgesics', keywords: ['paracetamol', 'ibuprofen', 'aspirin', 'diclofenac', 'nimesulide', 'aceclofenac', 'naproxen', 'pain', 'analgesic'] },
        { category: 'Antibiotics', keywords: ['amoxicillin', 'ciprofloxacin', 'azithromycin', 'metronidazole', 'doxycycline', 'cephalexin', 'antibiotic', 'penicillin'] },
        { category: 'Antacids & GI', keywords: ['antacid', 'omeprazole', 'pantoprazole', 'ranitidine', 'domperidone', 'ondansetron', 'laxative', 'lactulose', 'ENO', 'digene', 'gastrointestinal'] },
        { category: 'Vitamins & Supplements', keywords: ['vitamin', 'calcium', 'iron', 'zinc', 'b12', 'b6', 'd3', 'folic', 'multivitamin', 'supplement', 'omega', 'protein', 'biotin'] },
        { category: 'Antidiabetics', keywords: ['metformin', 'glipizide', 'insulin', 'glimepiride', 'diabetes', 'diabetic', 'sitagliptin', 'voglibose'] },
        { category: 'Antihypertensives', keywords: ['amlodipine', 'losartan', 'telmisartan', 'atenolol', 'ramipril', 'blood pressure', 'hypertension', 'enalapril'] },
        { category: 'Antiallergics', keywords: ['cetirizine', 'loratadine', 'fexofenadine', 'chlorpheniramine', 'antiallergic', 'allegra', 'levocetrizine'] },
        { category: 'Cough & Cold', keywords: ['cough', 'cold', 'syrup', 'expectorant', 'broncho', 'dextromethorphan', 'benadryl', 'ambroxol', 'guaifenesin'] },
        { category: 'Surgical & Dressings', keywords: ['bandage', 'dressing', 'gauze', 'cotton', 'plaster', 'surgical', 'syringe', 'gloves', 'mask', 'catheter'] },
        { category: 'Dermatologicals', keywords: ['cream', 'ointment', 'lotion', 'gel', 'derma', 'skin', 'antifungal', 'clotrimazole', 'betadine', 'hydrocortisone'] },
        { category: 'Ophthalmic & ENT', keywords: ['eye drop', 'ear drop', 'nasal', 'tobramycin', 'moxifloxacin', 'otrivin', 'gentamicin'] },
        { category: 'Ayurvedic & Herbal', keywords: ['ayurvedic', 'herbal', 'churna', 'asava', 'kashayam', 'triphala', 'ashwagandha', 'brahmi', 'tulsi'] },
    ],
    hardware: [
        { category: 'Plumbing', keywords: ['pipe', 'pvc', 'cpvc', 'upvc', 'fitting', 'valve', 'tap', 'faucet', 'elbow', 'reducer', 'tee', 'socket', 'union', 'ball valve', 'gate valve', 'ppr', 'gi pipe', 'ms pipe'] },
        { category: 'Electrical', keywords: ['wire', 'cable', 'switch', 'socket', 'mcb', 'elcb', 'rccb', 'conduit', 'junction box', 'bulb', 'led', 'tube light', 'fan', 'plug', 'breaker', 'fuse', 'meter', 'distribution board'] },
        { category: 'Cement & Concrete', keywords: ['cement', 'concrete', 'mortar', 'grout', 'waterproof', 'admixture', 'bonding'] },
        { category: 'Steel & Metal', keywords: ['steel', 'rod', 'bar', 'tmt', 'angle', 'channel', 'flat', 'ms', 'gi', 'ss', 'metal', 'iron', 'aluminium', 'sheet'] },
        { category: 'Paints & Coatings', keywords: ['paint', 'primer', 'putty', 'distemper', 'enamel', 'emulsion', 'varnish', 'thinner', 'turpentine', 'berger', 'asian', 'nerolac', 'dulux'] },
        { category: 'Fasteners', keywords: ['screw', 'bolt', 'nut', 'washer', 'nail', 'anchor', 'rivet', 'stud', 'hex', 'self tapping', 'wood screw'] },
        { category: 'Tools', keywords: ['drill', 'hammer', 'wrench', 'spanner', 'plier', 'cutter', 'grinder', 'saw', 'tape', 'level', 'chisel', 'screwdriver', 'toolbox'] },
        { category: 'Sanitary Ware', keywords: ['toilet', 'commode', 'basin', 'sink', 'bath', 'shower', 'cistern', 'urinal', 'sanitary'] },
        { category: 'Tiles & Flooring', keywords: ['tile', 'floor', 'vitrified', 'ceramic', 'marble', 'granite', 'mosaic', 'adhesive', 'spacer'] },
        { category: 'Wood & Board', keywords: ['plywood', 'mdf', 'particle board', 'wood', 'timber', 'teak', 'pine', 'door', 'frame'] },
    ],
    clothing: [
        { category: "Men's Wear", keywords: ["men's", 'trouser', 'pant', 'shirt', 'kurta', 'sherwani', 'suit', 'jacket', 'blazer', 'jeans', 'chino'] },
        { category: "Women's Wear", keywords: ["women's", 'saree', 'salwar', 'kurti', 'lehenga', 'blouse', 'dupatta', 'anarkali', 'churidar', 'gown', 'dress', 'top', 'skirt'] },
        { category: "Kids' Wear", keywords: ['kids', 'children', 'boy', 'girl', 'infant', 'baby', 'school uniform', 'frock', 'romper'] },
        { category: 'Innerwear & Socks', keywords: ['innerwear', 'underwear', 'brief', 'bra', 'panty', 'vest', 'socks', 'stockings', 'boxers'] },
        { category: 'Winter Wear', keywords: ['sweater', 'sweatshirt', 'hoodie', 'jacket', 'coat', 'cardigan', 'muffler', 'gloves', 'woolen', 'thermal'] },
        { category: 'Ethnic & Traditional', keywords: ['ethnic', 'traditional', 'dhoti', 'pagdi', 'dupatta', 'ghagra', 'patiala'] },
        { category: 'Sportswear', keywords: ['sports', 'track', 'gym', 'yoga', 'jersey', 'shorts', 'cycling', 'activewear'] },
        { category: 'Accessories', keywords: ['belt', 'wallet', 'cap', 'hat', 'tie', 'bow', 'scarf', 'handbag', 'purse', 'bag'] },
    ],
    mobile_shop: [
        { category: 'Smartphones', keywords: ['phone', 'mobile', 'smartphone', 'iphone', 'android', 'galaxy', 'redmi', 'realme', 'oneplus', 'vivo', 'oppo', 'poco', 'iqoo'] },
        { category: 'Feature Phones', keywords: ['keypad', 'feature phone', 'basic phone', 'nokia', 'jio phone'] },
        { category: 'Chargers & Cables', keywords: ['charger', 'cable', 'type-c', 'micro usb', 'lightning', 'fast charge', 'power adapter'] },
        { category: 'Cases & Covers', keywords: ['case', 'cover', 'back cover', 'tempered glass', 'screen guard', 'flip cover', 'wallet case'] },
        { category: 'Earphones & Audio', keywords: ['earphone', 'earbuds', 'headphone', 'speaker', 'tws', 'neckband', 'bluetooth audio'] },
        { category: 'Power Banks', keywords: ['power bank', 'portable charger'] },
        { category: 'Memory & Storage', keywords: ['memory card', 'micro sd', 'sd card', 'pendrive', 'flash drive', 'otg'] },
        { category: 'Spare Parts', keywords: ['screen', 'display', 'battery', 'back panel', 'camera lens', 'speaker mesh', 'motherboard', 'flex', 'ribbon'] },
    ],
    computer_shop: [
        { category: 'Laptops', keywords: ['laptop', 'notebook', 'macbook', 'chromebook', 'ultrabook', 'gaming laptop'] },
        { category: 'Desktops & Components', keywords: ['desktop', 'pc', 'tower', 'all-in-one', 'cpu', 'processor', 'motherboard', 'cabinet', 'chassis'] },
        { category: 'RAM & Storage', keywords: ['ram', 'memory', 'ddr4', 'ddr5', 'ssd', 'hdd', 'nvme', 'm.2', 'hard disk', 'solid state'] },
        { category: 'Graphics & Displays', keywords: ['gpu', 'graphics card', 'monitor', 'display', 'screen', 'vga', 'hdmi', 'display port'] },
        { category: 'Peripherals', keywords: ['keyboard', 'mouse', 'mousepad', 'webcam', 'headset', 'joystick', 'gamepad'] },
        { category: 'Networking', keywords: ['router', 'switch', 'modem', 'ethernet', 'wifi', 'access point', 'network card', 'patch cable'] },
        { category: 'Printers & Scanners', keywords: ['printer', 'scanner', 'cartridge', 'toner', 'ink', 'plotter'] },
        { category: 'UPS & Power', keywords: ['ups', 'stabilizer', 'smps', 'power supply', 'surge protector'] },
    ],
    auto_parts: [
        { category: 'Engine Parts', keywords: ['piston', 'crankshaft', 'camshaft', 'valve', 'gasket', 'cylinder', 'head', 'oil filter', 'air filter', 'fuel filter', 'spark plug', 'injector'] },
        { category: 'Transmission', keywords: ['clutch', 'gearbox', 'gear', 'shaft', 'bearing', 'synchro', 'differential', 'axle', 'cv joint', 'drive shaft'] },
        { category: 'Brakes', keywords: ['brake', 'disc', 'drum', 'caliper', 'pad', 'shoe', 'master cylinder', 'brake fluid', 'abs'] },
        { category: 'Suspension & Steering', keywords: ['shock absorber', 'strut', 'spring', 'stabilizer bar', 'tie rod', 'steering rack', 'wheel bearing', 'ball joint', 'control arm'] },
        { category: 'Electrical & Lighting', keywords: ['battery', 'alternator', 'starter', 'relay', 'fuse', 'bulb', 'headlight', 'taillight', 'indicator', 'wiper', 'motor'] },
        { category: 'Body & Exterior', keywords: ['bumper', 'fender', 'door', 'bonnet', 'boot', 'mirror', 'glass', 'windshield', 'wiper blade', 'handle', 'grille'] },
        { category: 'Tyres & Wheels', keywords: ['tyre', 'tire', 'wheel', 'rim', 'tube', 'alloy', 'steel wheel', 'hub cap', 'tpms'] },
        { category: 'Lubricants & Fluids', keywords: ['engine oil', 'gear oil', 'coolant', 'antifreeze', 'brake fluid', 'power steering fluid', 'grease', 'lubricant'] },
        { category: 'Filters', keywords: ['filter', 'air filter', 'oil filter', 'fuel filter', 'cabin filter', 'pollen filter'] },
    ],
    electronics: [
        { category: 'Consumer Electronics', keywords: ['tv', 'television', 'ac', 'air conditioner', 'refrigerator', 'fridge', 'washing machine', 'microwave', 'oven', 'dishwasher'] },
        { category: 'Small Appliances', keywords: ['mixer', 'grinder', 'juicer', 'iron', 'toaster', 'kettle', 'fan', 'cooler', 'air purifier', 'vacuum cleaner', 'food processor'] },
        { category: 'Lighting', keywords: ['led', 'bulb', 'tube', 'light', 'lamp', 'strip light', 'downlight', 'flood light', 'street light'] },
        { category: 'Audio & Video', keywords: ['speaker', 'soundbar', 'home theater', 'amplifier', 'projector', 'camera', 'cctv', 'dvr', 'nvr'] },
        { category: 'Batteries & Inverters', keywords: ['battery', 'inverter', 'ups', 'solar', 'panel', 'charge controller', 'lithium'] },
        { category: 'Cables & Accessories', keywords: ['hdmi', 'cable', 'adapter', 'converter', 'remote', 'mount', 'stand', 'connector', 'extension'] },
    ],
    restaurant: [
        { category: 'Beverages', keywords: ['tea', 'coffee', 'juice', 'shake', 'lassi', 'soda', 'water', 'mojito', 'mocktail', 'drink'] },
        { category: 'Starters', keywords: ['starter', 'appetizer', 'soup', 'salad', 'fries', 'tikka', 'kebab', 'chaat'] },
        { category: 'Main Course', keywords: ['curry', 'dal', 'sabzi', 'rice', 'biryani', 'pulao', 'gravy', 'main course', 'thali'] },
        { category: 'Breads', keywords: ['roti', 'naan', 'paratha', 'chapati', 'puri', 'bread', 'kulcha', 'bhatura'] },
        { category: 'Desserts', keywords: ['dessert', 'sweet', 'ice cream', 'halwa', 'kheer', 'gulab jamun', 'rasgulla', 'cake', 'pastry', 'mithai'] },
        { category: 'Fast Food', keywords: ['burger', 'pizza', 'sandwich', 'wrap', 'roll', 'pasta', 'noodles', 'momos'] },
        { category: 'Combos & Meals', keywords: ['combo', 'meal', 'set', 'platter', 'special', 'family pack'] },
    ],
    book_store: [
        { category: 'Academic', keywords: ['textbook', 'ncert', 'cbse', 'icse', 'class', 'grade', 'academic', 'school book', 'college book', 'university', 'exam', 'guide', 'question bank', 'solved paper', 'reference book'] },
        { category: 'Fiction', keywords: ['novel', 'fiction', 'thriller', 'mystery', 'romance', 'fantasy', 'sci-fi', 'horror', 'adventure', 'crime', 'short stories'] },
        { category: 'Non-Fiction', keywords: ['biography', 'autobiography', 'memoir', 'history', 'science', 'self-help', 'business', 'philosophy', 'psychology', 'travel', 'cooking'] },
        { category: 'Children\'s Books', keywords: ['children', 'kids', 'picture book', 'story book', 'fairy tale', 'nursery', 'comic', 'activity book'] },
        { category: 'Stationery', keywords: ['pen', 'pencil', 'notebook', 'diary', 'eraser', 'sharpener', 'ruler', 'stapler', 'file', 'folder', 'highlighter', 'marker', 'geometry box'] },
        { category: 'Competitive Exams', keywords: ['upsc', 'ssc', 'cat', 'gmat', 'ielts', 'jee', 'neet', 'gate', 'rrb', 'banking', 'competitive'] },
    ],
    vegetable_broker: [
        { category: 'Leafy Vegetables', keywords: ['spinach', 'palak', 'methi', 'coriander', 'dhaniya', 'mint', 'pudina', 'lettuce', 'kale', 'cabbage', 'patta gobi'] },
        { category: 'Root Vegetables', keywords: ['potato', 'aloo', 'carrot', 'gajar', 'beetroot', 'radish', 'mooli', 'turnip', 'shalgam', 'sweet potato', 'shakarkand', 'ginger', 'adrak', 'garlic', 'lahsun', 'onion', 'pyaz'] },
        { category: 'Gourds & Squash', keywords: ['pumpkin', 'kaddu', 'bottle gourd', 'lauki', 'bitter gourd', 'karela', 'ridge gourd', 'turai', 'snake gourd', 'tinda', 'parwal'] },
        { category: 'Beans & Pods', keywords: ['peas', 'matar', 'beans', 'french bean', 'sem', 'cluster beans', 'gawar', 'lady finger', 'bhindi', 'drumstick', 'moringa'] },
        { category: 'Fruits', keywords: ['tomato', 'tamatar', 'mango', 'apple', 'banana', 'orange', 'papaya', 'grape', 'pomegranate', 'watermelon', 'muskmelon', 'lemon', 'lime', 'guava', 'pineapple'] },
        { category: 'Herbs & Spices (Fresh)', keywords: ['chilli', 'mirch', 'curry leaf', 'curry patta', 'tulsi', 'basil', 'lemongrass'] },
    ],
};

// Fallback for unrecognized verticals — merge all categories
const GENERAL_CATEGORIES = [
    ...KEYWORD_MAPS.grocery,
    ...KEYWORD_MAPS.hardware,
    ...KEYWORD_MAPS.pharmacy,
];

// ── Category Inference ───────────────────────────────────────────────────────

/**
 * Resolve category from keyword map. Returns null if no match found.
 * Matching is done on the normalized product name (lowercase, no diacritics).
 */
export function resolveFromKeywordMap(
    normalizedName: string,
    vertical: string,
): string | null {
    const entries = KEYWORD_MAPS[vertical] ?? GENERAL_CATEGORIES;

    for (const entry of entries) {
        for (const keyword of entry.keywords) {
            if (normalizedName.includes(keyword)) {
                return entry.category;
            }
        }
    }
    return null;
}

/**
 * Return the list of valid category names for a given vertical.
 * Used in the LLM prompt to constrain output.
 */
export function getValidCategories(vertical: string): string[] {
    const entries = KEYWORD_MAPS[vertical] ?? GENERAL_CATEGORIES;
    return entries.map(e => e.category);
}

// ── DynamoDB Cache ───────────────────────────────────────────────────────────

const CACHE_TTL_DAYS = 30;

function makeCacheKey(normalizedName: string, vertical: string): string {
    return createHash('sha256').update(`${normalizedName}::${vertical}`).digest('hex').slice(0, 32);
}

async function getCached(cacheKey: string): Promise<string | null> {
    try {
        const record = await getItem<CategoryCacheRecord>(
            Keys.categoryCachePK(),
            Keys.categoryCacheSK(cacheKey),
        );
        if (record && record.category) return record.category;
    } catch (err) {
        logger.warn('[CategoryMap] Cache read failed', { cacheKey, error: (err as Error).message });
    }
    return null;
}

async function putCached(
    cacheKey: string,
    normalizedName: string,
    vertical: string,
    category: string,
    resolvedBy: 'keyword_map' | 'llm',
): Promise<void> {
    const now = Date.now();
    const ttl = Math.floor(now / 1000) + CACHE_TTL_DAYS * 86400;

    const record: CategoryCacheRecord & { PK: string; SK: string } = {
        PK: Keys.categoryCachePK(),
        SK: Keys.categoryCacheSK(cacheKey),
        cacheKey,
        normalizedName,
        vertical,
        category,
        resolvedBy,
        createdAt: now,
        ttl,
    };

    try {
        await putItem(record as unknown as Record<string, unknown>);
    } catch (err) {
        // Non-critical — cache miss is acceptable
        logger.warn('[CategoryMap] Cache write failed', { cacheKey, error: (err as Error).message });
    }
}

// ── LLM Fallback (Claude claude-sonnet-4-20250514) ───────────────────────────────────────────────

async function resolveFromLLM(
    normalizedName: string,
    vertical: string,
    validCategories: string[],
): Promise<string> {
    const apiKey = config.ai.anthropicKey;
    if (!apiKey) {
        logger.warn('[CategoryMap] ANTHROPIC_API_KEY not set — defaulting to General');
        return 'General';
    }

    const prompt = `You are a product categorization assistant for a ${vertical} store.
Given the product name below, respond with exactly one JSON object and nothing else.
Valid categories: ${JSON.stringify(validCategories)}
Product name: "${normalizedName}"
Respond with: {"category": "<one of the valid categories above>"}
If no category fits well, use "General".`;

    try {
        const res = await fetch('https://api.anthropic.com/v1/messages', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'x-api-key': apiKey,
                'anthropic-version': '2023-06-01',
            },
            body: JSON.stringify({
                model: 'claude-sonnet-4-20250514',
                max_tokens: 64,
                messages: [{ role: 'user', content: prompt }],
            }),
        });

        if (!res.ok) {
            logger.warn('[CategoryMap] LLM API error', { status: res.status });
            return 'General';
        }

        const json = await res.json() as { content: Array<{ type: string; text: string }> };
        const text = json.content?.[0]?.text?.trim() ?? '';
        const parsed = JSON.parse(text) as { category?: string };

        const resolved = parsed.category;
        if (resolved && validCategories.includes(resolved)) return resolved;

        logger.warn('[CategoryMap] LLM returned invalid category', { resolved, normalizedName });
        return 'General';
    } catch (err) {
        logger.warn('[CategoryMap] LLM call failed', { error: (err as Error).message });
        return 'General';
    }
}

// ── Public API ───────────────────────────────────────────────────────────────

/**
 * Resolve category for a normalized product name + business vertical.
 * Resolution order:
 *   1. Keyword map (deterministic, free)
 *   2. DynamoDB cache (previous LLM result)
 *   3. LLM (Claude claude-sonnet-4-20250514) → cached in DynamoDB
 *   4. Fallback: 'General'
 */
export async function resolveCategory(
    normalizedName: string,
    vertical: string,
): Promise<{ category: string; resolvedBy: 'keyword_map' | 'llm' | 'fallback' }> {
    // 1. Keyword map
    const fromKeyword = resolveFromKeywordMap(normalizedName, vertical);
    if (fromKeyword) {
        return { category: fromKeyword, resolvedBy: 'keyword_map' };
    }

    const cacheKey = makeCacheKey(normalizedName, vertical);

    // 2. DynamoDB cache
    const cached = await getCached(cacheKey);
    if (cached) {
        return { category: cached, resolvedBy: 'llm' };
    }

    // 3. LLM fallback
    const validCategories = getValidCategories(vertical);
    const llmCategory = await resolveFromLLM(normalizedName, vertical, validCategories);

    // Cache the LLM result (async — don't block the response)
    putCached(cacheKey, normalizedName, vertical, llmCategory, 'llm').catch(() => { });

    if (llmCategory === 'General') {
        return { category: 'General', resolvedBy: 'fallback' };
    }

    return { category: llmCategory, resolvedBy: 'llm' };
}
