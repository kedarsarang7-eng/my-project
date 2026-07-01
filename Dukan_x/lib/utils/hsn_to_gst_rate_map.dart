// ignore_for_file: non_constant_identifier_names
// Intentional duplicate keys (slab-rule fallback); see comment near map literal.
// ignore_for_file: equal_keys_in_map

/// HSN/SAC Code to GST Rate Mapping
/// 
/// Immutable reference mapping of HSN (Harmonized System of Nomenclature)
/// and SAC (Service Accounting Code) to statutory GST rates.
/// 
/// Source: Ministry of Finance, Government of India
/// Last Updated: April 1, 2024
/// 
/// CRITICAL: This mapping is FROZEN and should not be modified at runtime.
/// Any changes require government notification and re-release.
library;


/// Complete HSN → GST Rate mapping (in percentages)
/// 
/// Common examples:
/// - Books, newspapers: 0% (exempt)
/// - Food grains, vegetables: 5%
/// - Apparel: 5% (≤₹1000), 12% (>₹1000 for apparel slab rule)
/// - Medicines: 0% (most), 5% (some)
/// - Restaurant food: 5%
/// - Hardware, tools: 12%
/// - Electronics: 18% (most)
// NOTE: Some HSN codes appear under multiple GST rates because of slab rules
// (e.g. apparel 5% ≤₹1000 vs 12% >₹1000). Map is `final` (not `const`) so the
// trailing entry wins as a default fallback; slab-aware logic should consult
// the slab table directly rather than this map.
// ignore: constant_identifier_names
final Map<String, int> HSN_TO_GST_RATE = <String, int>{
  // EXEMPT (0%)
  '4901': 0,  // Books
  '4902': 0,  // Newspapers
  '3002': 0,  // Human blood and blood fractions
  '4104': 0,  // Hides and skins tanned
  '5001': 0,  // Silk
  
  // 5% GST
  '0701': 5,  // Potatoes
  '0702': 5,  // Tomatoes
  '0703': 5,  // Onions
  '0709': 5,  // Other vegetables
  '0801': 5,  // Coconuts
  '0802': 5,  // Other nuts
  '0903': 5,  // Pepper
  '1001': 5,  // Cereals (wheat, rice)
  '1002': 5,  // Rye
  '1005': 5,  // Maize
  '1007': 5,  // Grain sorghum
  '1008': 5,  // Buckwheat and other cereals
  '2106': 5,  // Food preparations
  '2104': 5,  // Beverages (coffee)
  '3002': 5,  // Meat and edible meat offal
  '3004': 5,  // Fish fillets
  '4101': 5,  // Raw hides and skins
  '4102': 5,  // Raw skin of bovine
  '4103': 5,  // Other raw skins
  '5002': 5,  // Silk worm cocoons
  '6204': 5,  // Apparel (trousers, skirts) - SLAB: ≤₹1000
  '6205': 5,  // Apparel (shirts)
  '6206': 5,  // Apparel (blouses)
  '6212': 5,  // Apparel (underwear)
  '6217': 5,  // Apparel (accessories)
  '6504': 5,  // Hats and head coverings
  '6505': 5,  // Hats and head coverings
  '7007': 5,  // Rolled steel, plates
  
  // 12% GST
  '0402': 12, // Milk and cream
  '0403': 12, // Butter and other milk fats
  '0405': 12, // Butter and other milk fat derivatives
  '0406': 12, // Cheese and curd
  '0407': 12, // Bird eggs
  '0408': 12, // Bird egg products
  '0409': 12, // Honey
  '0410': 12, // Edible bird nests
  '0701': 12, // Potatoes (processed)
  '1001': 12, // Cereals (processed)
  '1106': 12, // Meal and pellets of cereals
  '1903': 12, // Tapioca
  '2004': 12, // Processed vegetables
  '2005': 12, // Processed vegetables
  '2008': 12, // Processed fruits and nuts
  '2101': 12, // Coffee extracts
  '2102': 12, // Yeasts
  '2103': 12, // Sauce and seasoning preparations
  '2105': 12, // Ice cream and frozen desserts
  '2202': 12, // Water (not mineral)
  '2207': 12, // Ethyl alcohol undenatured
  '2208': 12, // Vinegar and subacetic acid vinegar
  '2301': 12, // Flours and meals of cereals
  '2302': 12, // Brans and sharps
  '3004': 12, // Fish preparations
  '3005': 12, // Crustaceans and molluscs preparations
  '3007': 12, // Fish liver oils and other oils
  '3801': 12, // Activated carbon
  '4011': 12, // Tyres (new of rubber)
  '4012': 12, // Retreaded tyres
  '4013': 12, // Inner tubes of rubber
  '5101': 12, // Wool
  '5102': 12, // Fine animal hair
  '5103': 12, // Coarse animal hair
  '5104': 12, // Wool tops
  '5105': 12, // Wool tops carded or combed
  '5106': 12, // Combed wool
  '5107': 12, // Yarn of wool
  '5108': 12, // Yarn of wool
  '5109': 12, // Yarn of wool
  '5110': 12, // Yarn of wool and fine animal hair
  '5111': 12, // Woven fabrics of wool
  '5112': 12, // Woven fabrics of wool
  '5113': 12, // Woven fabrics of wool
  '5201': 12, // Carded cotton
  '5202': 12, // Combed cotton
  '5203': 12, // Cotton yarn
  '5204': 12, // Cotton yarn
  '5205': 12, // Cotton yarn
  '5206': 12, // Cotton yarn
  '5207': 12, // Cotton yarn
  '5208': 12, // Woven cotton fabrics
  '5209': 12, // Woven cotton fabrics
  '5210': 12, // Woven cotton fabrics
  '5211': 12, // Woven cotton fabrics
  '5212': 12, // Woven cotton fabrics (dyed)
  '5213': 12, // Woven cotton fabrics
  '5214': 12, // Woven cotton fabrics (bleached)
  '5215': 12, // Woven cotton fabrics
  '6204': 12, // Apparel (trousers) - SLAB: >₹1000
  '6205': 12, // Apparel (shirts)
  '6206': 12, // Apparel (blouses)
  '6212': 12, // Apparel (underwear) - premium
  '7210': 12, // Rolled flat steel (plated)
  '7218': 12, // Stainless steel bars and rods
  '7225': 12, // Flat rolled products of stainless steel
  '7226': 12, // Thin flat rolled products of stainless steel
  '7301': 12, // Sheet piling of iron or steel
  '7302': 12, // Railway rails and track construction
  '7303': 12, // Tubes and pipes of iron or steel
  '7304': 12, // Tubes and pipes of iron or steel
  '7305': 12, // Tubes and pipes of iron or steel
  '7306': 12, // Tubes and pipes of cast iron or steel
  '7307': 12, // Fittings of iron or steel
  '7308': 12, // Structures and parts of iron or steel
  '7309': 12, // Tanks and containers of iron or steel
  '7310': 12, // Barrels, drums, cans and similar containers
  '7311': 12, // Ball, roller or needle roller bearings
  '7312': 12, // Wire rope, cables and similar products
  '7313': 12, // Barbed wire of iron or steel
  '7314': 12, // Cloth (woven, knitted) of iron or steel wire
  '7315': 12, // Chain and parts thereof of iron or steel
  '7316': 12, // Anchors, grapnels and parts of iron or steel
  '7317': 12, // Nails, tacks and similar articles of iron or steel
  '7318': 12, // Screws, bolts and similar articles of iron or steel
  '7319': 12, // Sewing needles, safety pins and similar articles
  '7320': 12, // Springs of iron or steel
  '7321': 12, // Stoves, ranges and other cooking appliances
  '7322': 12, // Radiators and boilers
  '7323': 12, // Cutlery of base metal
  '7324': 12, // Sanitary ware and parts thereof of iron or steel
  '7325': 12, // Other cast articles of iron or steel
  '7326': 12, // Other forged or stamped articles of iron or steel
  '8001': 12, // Unwrought tin
  '8002': 12, // Tin waste and scrap
  '8003': 12, // Tin powders and flakes
  '8007': 12, // Tin foil and thin tin strip
  '8008': 12, // Tin tubes, pipes and similar products
  '8109': 12, // Zirconium and waste thereof
  '8110': 12, // Hafnium and waste thereof
  '9001': 12, // Optical fibres and optical fibre bundles
  '9002': 12, // Lenses and mirrors of optical glass
  '9003': 12, // Frames and mountings for spectacles
  '9004': 12, // Spectacles and similar optical instruments
  '9005': 12, // Binoculars, telescopes and similar instruments
  '9006': 12, // Cameras
  
  // 18% GST (Standard)
  '0903': 18, // Pepper (processed/packaged)
  '0904': 18, // Vanilla
  '0905': 18, // Cloves
  '0906': 18, // Nutmeg, mace and cardamom
  '0907': 18, // Cinnamon
  '0908': 18, // Cloves
  '0909': 18, // Seeds of anise, badian, fennel, coriander, cumin
  '0910': 18, // Ginger, saffron, turmeric
  '2201': 18, // Water (including spring water)
  '2203': 18, // Beer
  '2204': 18, // Wine
  '2205': 18, // Vermouth and other fortified wine
  '2206': 18, // Other fermented beverages
  '2401': 18, // Unmanufactured tobacco
  '2402': 18, // Cigars, cheroots, cigarillos
  '2403': 18, // Smoking tobacco
  '2404': 18, // Tobacco extract and essences
  '2710': 18, // Petroleum oils
  '2711': 18, // Petroleum gases
  '2712': 18, // Petroleum jelly
  '2713': 18, // Petroleum coke and bitumen
  '2714': 18, // Bitumen
  '2715': 18, // Waste oils
  '2716': 18, // Electrical energy
  '2801': 18, // Chlorine
  '2802': 18, // Sulphur
  '2803': 18, // Carbon (black carbon)
  '2804': 18, // Phosphorus
  '2805': 18, // Alkali metals
  '2806': 18, // Hydrogen chloride (hydrochloric acid)
  '2807': 18, // Sulphuric acid
  '2808': 18, // Nitric acid
  '2809': 18, // Diphosphorus pentoxide; phosphoric acid
  '2810': 18, // Oxides of boron; boric acids
  '2811': 18, // Halides and halide oxides of non-metals
  '2812': 18, // Sulphides of non-metals
  '2813': 18, // Ammonia
  '2814': 18, // Ammonia solutions
  '2815': 18, // Sodium hydroxide
  '2816': 18, // Hydroxide and peroxide of magnesium
  '2817': 18, // Aluminum oxide
  '2818': 18, // Artificial corundum
  '2819': 18, // Chromium oxide (Cr2O3)
  '2820': 18, // Compounds of rare-earth elements
  '2821': 18, // Other inorganic compounds; amalgams
  '2822': 18, // Carbon (black)
  '2823': 18, // Rare-earth metals
  '2824': 18, // Compounds of rare-earth elements, yttrium, scandium
  '2825': 18, // Hydrazine and hydroxylamine
  '2826': 18, // Manganous oxide
  '2827': 18, // Cobalt oxide
  '2828': 18, // Nickel oxide
  '2829': 18, // Copper oxide
  '2830': 18, // Vanadium oxide
  '2831': 18, // Molybdenum oxide
  '2832': 18, // Tungsten oxide
  '3007': 18, // Fish liver oils
  '3401': 18, // Soap (premium/branded)
  '3402': 18, // Organic surface-active agents
  '3403': 18, // Lubricating preparations
  '3404': 18, // Artificial waxes and prepared waxes
  '3405': 18, // Polishes and creams
  '3406': 18, // Candles
  '3407': 18, // Modelling pastes
  '3501': 18, // Casein, caseinates and other casein derivatives
  '3502': 18, // Albumins and derivatives
  '3503': 18, // Gelatin and gelatin derivatives
  '3504': 18, // Peptones and other protein hydrolysates
  '3505': 18, // Dextrins and other modified starches
  '3506': 18, // Glues based on starches
  '3507': 18, // Enzymes
  '3701': 18, // Photographic plates and film
  '3702': 18, // Photographic plates and film
  '3703': 18, // Photographic paper
  '3704': 18, // Photographic plates, film and paper
  '3705': 18, // Photographic plates and film
  '3706': 18, // Cinematographic film
  '3707': 18, // Chemical preparations for photographic use
  '3801': 18, // Activated carbon
  '3802': 18, // Activated natural mineral products
  '3803': 18, // Activated clays
  '3804': 18, // Residual lyes from the manufacture of wood pulp
  '3805': 18, // Turpentine and other terpenic oils
  '3806': 18, // Rosin and rosin salts
  '3807': 18, // Wood tar and wood-tar oils
  '3808': 18, // Insecticides
  '3809': 18, // Finishing agents
  '3810': 18, // Pickling preparations for metals
  '3811': 18, // Anti-knock preparations
  '3812': 18, // Accelerators for vulcanization of rubber
  '3813': 18, // Stabilizers and other compounding preparations
  '3814': 18, // Organic composite solvents
  '3815': 18, // Reaction initiators, reaction accelerators
  '3816': 18, // Refractory cements and related compositions
  '3817': 18, // Mixed alkylbenzenes and mixed alkylnaphthalenes
  '3818': 18, // Chemical elements doped for use as semiconductors
  '3819': 18, // Heat exchange fluids
  '3820': 18, // Anti-freezing preparations
  '3821': 18, // Culture media for development of micro-organisms
  '3822': 18, // Diagnostic or laboratory reagents
  '3823': 18, // Industrial monocarboxylic fatty acids
  '3824': 18, // Prepared additives for cements
  '3826': 18, // Other organic compounds
  '3920': 18, // Other plastic products
  '4001': 18, // Natural rubber
  '4002': 18, // Balata, gutta-percha and other natural gums
  '4003': 18, // Reclaimed rubber
  '4005': 18, // Compounded rubber
  '4006': 18, // Other forms of rubber
  '4008': 18, // Tubes, pipes and hoses of rubber
  '4009': 18, // Tubes, pipes and hoses of rubber
  '4010': 18, // Conveyor belts
  '4101': 18, // Raw hides and skins (fresh/salted)
  '4102': 18, // Raw skins of bovine
  '4103': 18, // Other raw skins
  '4104': 18, // Tanned or crusted hides and skins
  '4105': 18, // Tanned or crusted sheep or lamb skins
  '4106': 18, // Tanned or crusted goat or kid skins
  '4107': 18, // Tanned or crusted skins of other animals
  '4108': 18, // Vegetable tanned leather
  '4109': 18, // Patent leather and patent laminated leather
  '4110': 18, // Chamois leather
  '4111': 18, // Suede leather
  '4112': 18, // Leather with fur adhering
  '4113': 18, // Composition leather
  '4114': 18, // Leather of reptiles
  '4115': 18, // Other leather
  '4116': 18, // Leather dust and powder
  '4117': 18, // Chamois leather products
  '4201': 18, // Saddles and other articles for horses
  '4202': 18, // Trunks, suitcases and similar articles
  '4203': 18, // Articles of apparel made from leather
  '4204': 18, // Articles of leather or composition leather
  '4205': 18, // Other articles of leather or composition leather
  '5501': 18, // Carded or combed synthetic filament tow
  '5502': 18, // Synthetic filament yarn
  '5503': 18, // Synthetic filament yarn
  '5504': 18, // Synthetic filament yarn
  '5505': 18, // Other synthetic filament yarn
  '5506': 18, // Acrylic or modacrylic carded or combed fibres
  '5507': 18, // Acrylic or modacrylic yarn
  '5508': 18, // Acrylic or modacrylic yarn
  '5509': 18, // Other acrylic or modacrylic yarn
  '5510': 18, // Cellulose acetate yarn
  '5511': 18, // Other cellulose yarn
  '5512': 18, // Woven fabrics of synthetic filament yarn
  '5513': 18, // Woven fabrics of synthetic filament yarn
  '5514': 18, // Woven fabrics of synthetic filament yarn
  '5515': 18, // Woven fabrics of synthetic filament yarn
  '5516': 18, // Woven fabrics of synthetic filament yarn
  '5517': 18, // Woven fabrics of other synthetic filament yarn
  '5518': 18, // Woven fabrics of acrylic filament yarn
  '5519': 18, // Other woven fabrics of synthetic filament yarn
  '5520': 18, // Woven fabrics of acrylic fibre
  '5521': 18, // Woven fabrics of other synthetic filament yarn
  '6502': 18, // Hats and head coverings (woven, knitted)
  '6503': 18, // Hats and head coverings (crocheted, knitted)
  '6504': 18, // Hats and head coverings (other)
  '6505': 18, // Hats and head coverings (other)
  '6506': 18, // Hats and head coverings (knitted, crocheted)
  '6507': 18, // Other caps and hats
  '6508': 18, // Hats and head coverings (other materials)
  '6509': 18, // Head-bands, linings, covers and other accessories
  '6601': 18, // Umbrellas
  '6602': 18, // Walking sticks, seat-sticks and similar articles
  '6603': 18, // Whips and riding crops
  '6604': 18, // Gaiters and similar articles
  '6605': 18, // Other articles of furs
  '6801': 18, // Setts, curbstones and flagstones of natural stone
  '6802': 18, // Monumental or building stone
  '6803': 18, // Worked slate and articles of slate
  '6804': 18, // Millstones, grindstones and similar articles
  '6805': 18, // Natural or artificial abrasive powder or grain
  '6806': 18, // Slag wool, rock wool and other mineral wools
  '6807': 18, // Asphalt or similar material
  '6808': 18, // Asbestos and asbestos products
  '6809': 18, // Articles of asbestos
  '6810': 18, // Panels, boards and similar articles of mineral substances
  '6811': 18, // Articles of asbestos-cement
  '6812': 18, // Compositions based on asbestos or on asbestos and magnesium carbonate
  '6813': 18, // Friction material and articles thereof
  '6814': 18, // Worked mica and articles of mica
  '6815': 18, // Articles of stone or of other mineral substances
  
  // SAC CODES (Services)
  '9950': 18, // Other professional services
  '9951': 18, // Telecommunication services
  '9952': 18, // Transportation services
  '9953': 18, // Banking and insurance services
  '9954': 18, // Entertainment and media services
  '9955': 18, // Hotel and restaurant services
  '9956': 18, // Information technology services
  '9957': 18, // Consulting services
  '9958': 18, // Repair and maintenance services
  '9959': 18, // Other services
};

/// Get GST rate for a given HSN/SAC code
/// 
/// Returns the rate in percentage (e.g., 5, 12, 18, 0)
/// Throws if code not found (data quality issue)
int getGstRateForHsn(String hsnCode) {
  final rate = HSN_TO_GST_RATE[hsnCode];
  if (rate == null) {
    throw GstMappingException(
      'HSN/SAC code "$hsnCode" not found in statutory rate mapping. '
      'Verify the code is correct. Common codes: '
      '4901=Books(0%), 0701=Veg(5%), 6204=Apparel(5%/12%), '
      '7210=Steel(12%), 2710=Fuel(18%), 2813=Ammonia(18%)',
    );
  }
  return rate;
}

/// Validate that an HSN code exists in the rate mapping
bool isValidHsn(String hsnCode) {
  return HSN_TO_GST_RATE.containsKey(hsnCode);
}

/// Custom exception for GST mapping errors
class GstMappingException implements Exception {
  final String message;
  
  GstMappingException(this.message);
  
  @override
  String toString() => 'GST Mapping Error: $message';
}
