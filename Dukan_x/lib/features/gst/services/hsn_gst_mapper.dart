// ============================================================================
// HSN → GST RATE AUTO-MAPPER
// ============================================================================
// Maps HSN (Harmonized System of Nomenclature) codes to their standard
// GST rate. When a user enters an HSN code on a product, the GST rate
// should auto-fill.
//
// Data source: GST Council rate schedule (simplified for common hardware items)
// Full mapping: 8000+ HSN codes — in production, load from API/JSON asset.
//
// Author: DukanX Engineering
// ============================================================================

/// HSN code entry with GST rate
class HsnGstEntry {
  final String hsnCode; // 2, 4, 6, or 8 digit
  final double gstRate; // 0, 5, 12, 18, 28
  final String description;
  final String? cessRate; // Additional cess if applicable

  const HsnGstEntry({
    required this.hsnCode,
    required this.gstRate,
    required this.description,
    this.cessRate,
  });
}

/// HSN → GST Rate Mapper
///
/// Usage:
/// ```dart
/// final rate = HsnGstMapper.getGstRate('7318'); // → 18.0 (screws, bolts)
/// final rate = HsnGstMapper.getGstRate('73181100'); // → 18.0 (coach screws)
/// ```
class HsnGstMapper {
  HsnGstMapper._();

  /// Look up GST rate for an HSN code.
  ///
  /// Tries exact match first, then progressively shorter prefixes
  /// (8-digit → 6-digit → 4-digit → 2-digit).
  ///
  /// Returns null if no match found.
  static double? getGstRate(String hsnCode) {
    if (hsnCode.isEmpty) return null;

    final clean = hsnCode.replaceAll(RegExp(r'\D'), '').trim();
    if (clean.isEmpty) return null;

    // Try exact match, then progressively shorter codes
    for (int len = clean.length; len >= 2; len -= 2) {
      final prefix = clean.substring(0, len);
      final entry = _hsnMap[prefix];
      if (entry != null) return entry.gstRate;
    }

    return null;
  }

  /// Get full HSN entry with description
  static HsnGstEntry? getEntry(String hsnCode) {
    if (hsnCode.isEmpty) return null;

    final clean = hsnCode.replaceAll(RegExp(r'\D'), '').trim();
    if (clean.isEmpty) return null;

    for (int len = clean.length; len >= 2; len -= 2) {
      final prefix = clean.substring(0, len);
      final entry = _hsnMap[prefix];
      if (entry != null) return entry;
    }

    return null;
  }

  /// Search HSN entries by description keyword
  static List<HsnGstEntry> search(String keyword) {
    if (keyword.isEmpty) return [];
    final lower = keyword.toLowerCase();
    return _hsnMap.values
        .where((e) => e.description.toLowerCase().contains(lower) ||
                      e.hsnCode.contains(keyword))
        .toList();
  }

  // ─────────────────────────────────────────────────────────
  // HARDWARE SHOP — COMMON HSN CODES
  // ─────────────────────────────────────────────────────────
  // This is a curated subset for hardware shops. In production,
  // load the full 8000+ entries from a JSON asset or API.
  // ─────────────────────────────────────────────────────────

  static const Map<String, HsnGstEntry> _hsnMap = {
    // ── IRON & STEEL (Chapter 72) ──
    '7202': HsnGstEntry(hsnCode: '7202', gstRate: 18, description: 'Ferro-alloys'),
    '7207': HsnGstEntry(hsnCode: '7207', gstRate: 18, description: 'Semi-finished products of iron/steel'),
    '7208': HsnGstEntry(hsnCode: '7208', gstRate: 18, description: 'Flat-rolled steel (hot-rolled)'),
    '7209': HsnGstEntry(hsnCode: '7209', gstRate: 18, description: 'Flat-rolled steel (cold-rolled)'),
    '7210': HsnGstEntry(hsnCode: '7210', gstRate: 18, description: 'Galvanized/coated flat steel'),
    '7213': HsnGstEntry(hsnCode: '7213', gstRate: 18, description: 'Bars & rods (hot-rolled)'),
    '7214': HsnGstEntry(hsnCode: '7214', gstRate: 18, description: 'Iron/steel bars (forged)'),
    '7216': HsnGstEntry(hsnCode: '7216', gstRate: 18, description: 'Angles, shapes, sections of iron/steel'),
    '7217': HsnGstEntry(hsnCode: '7217', gstRate: 18, description: 'Iron/steel wire'),
    '7228': HsnGstEntry(hsnCode: '7228', gstRate: 18, description: 'Bars & rods of alloy steel'),

    // ── ARTICLES OF IRON & STEEL (Chapter 73) ──
    '7301': HsnGstEntry(hsnCode: '7301', gstRate: 18, description: 'Sheet piling, angles, shapes'),
    '7303': HsnGstEntry(hsnCode: '7303', gstRate: 18, description: 'Cast iron tubes & pipes'),
    '7304': HsnGstEntry(hsnCode: '7304', gstRate: 18, description: 'Seamless steel tubes/pipes'),
    '7306': HsnGstEntry(hsnCode: '7306', gstRate: 18, description: 'Welded steel tubes/pipes'),
    '7307': HsnGstEntry(hsnCode: '7307', gstRate: 18, description: 'Tube/pipe fittings (flanges, elbows)'),
    '7308': HsnGstEntry(hsnCode: '7308', gstRate: 18, description: 'Structures of iron/steel (gates, frames)'),
    '7309': HsnGstEntry(hsnCode: '7309', gstRate: 18, description: 'Iron/steel tanks, vats'),
    '7310': HsnGstEntry(hsnCode: '7310', gstRate: 18, description: 'Iron/steel containers, drums'),
    '7312': HsnGstEntry(hsnCode: '7312', gstRate: 18, description: 'Wire rope, cables'),
    '7313': HsnGstEntry(hsnCode: '7313', gstRate: 18, description: 'Barbed wire, twisted wire'),
    '7314': HsnGstEntry(hsnCode: '7314', gstRate: 18, description: 'Wire cloth, grill, netting'),
    '7315': HsnGstEntry(hsnCode: '7315', gstRate: 18, description: 'Chain and parts'),
    '7317': HsnGstEntry(hsnCode: '7317', gstRate: 18, description: 'Nails, tacks, staples'),
    '7318': HsnGstEntry(hsnCode: '7318', gstRate: 18, description: 'Screws, bolts, nuts, washers'),
    '7320': HsnGstEntry(hsnCode: '7320', gstRate: 18, description: 'Springs'),
    '7321': HsnGstEntry(hsnCode: '7321', gstRate: 18, description: 'Stoves, grates, radiators'),
    '7323': HsnGstEntry(hsnCode: '7323', gstRate: 12, description: 'Iron/steel household articles'),
    '7324': HsnGstEntry(hsnCode: '7324', gstRate: 18, description: 'Sanitary ware of iron/steel'),
    '7325': HsnGstEntry(hsnCode: '7325', gstRate: 18, description: 'Cast articles of iron/steel'),
    '7326': HsnGstEntry(hsnCode: '7326', gstRate: 18, description: 'Other articles of iron/steel'),

    // ── COPPER (Chapter 74) ──
    '7408': HsnGstEntry(hsnCode: '7408', gstRate: 18, description: 'Copper wire'),
    '7411': HsnGstEntry(hsnCode: '7411', gstRate: 18, description: 'Copper tubes/pipes'),
    '7412': HsnGstEntry(hsnCode: '7412', gstRate: 18, description: 'Copper pipe fittings'),
    '7413': HsnGstEntry(hsnCode: '7413', gstRate: 18, description: 'Stranded copper wire, cables'),

    // ── ALUMINIUM (Chapter 76) ──
    '7604': HsnGstEntry(hsnCode: '7604', gstRate: 18, description: 'Aluminium bars, rods, profiles'),
    '7606': HsnGstEntry(hsnCode: '7606', gstRate: 18, description: 'Aluminium plates, sheets'),
    '7607': HsnGstEntry(hsnCode: '7607', gstRate: 18, description: 'Aluminium foil'),
    '7608': HsnGstEntry(hsnCode: '7608', gstRate: 18, description: 'Aluminium tubes/pipes'),
    '7610': HsnGstEntry(hsnCode: '7610', gstRate: 18, description: 'Aluminium structures (doors, windows)'),
    '7615': HsnGstEntry(hsnCode: '7615', gstRate: 12, description: 'Aluminium household articles'),
    '7616': HsnGstEntry(hsnCode: '7616', gstRate: 18, description: 'Other aluminium articles'),

    // ── TOOLS (Chapter 82) ──
    '8201': HsnGstEntry(hsnCode: '8201', gstRate: 18, description: 'Hand tools: spades, shovels, picks'),
    '8202': HsnGstEntry(hsnCode: '8202', gstRate: 18, description: 'Hand saws'),
    '8203': HsnGstEntry(hsnCode: '8203', gstRate: 18, description: 'Files, pliers, pincers, tweezers'),
    '8204': HsnGstEntry(hsnCode: '8204', gstRate: 18, description: 'Spanners, wrenches'),
    '8205': HsnGstEntry(hsnCode: '8205', gstRate: 18, description: 'Hand tools: hammers, screwdrivers'),
    '8206': HsnGstEntry(hsnCode: '8206', gstRate: 18, description: 'Tool sets'),
    '8207': HsnGstEntry(hsnCode: '8207', gstRate: 18, description: 'Drill bits, cutting tools'),
    '8208': HsnGstEntry(hsnCode: '8208', gstRate: 18, description: 'Knives, blades for machines'),
    '8211': HsnGstEntry(hsnCode: '8211', gstRate: 18, description: 'Knives with cutting blades'),

    // ── LOCKS & PADLOCKS (Chapter 83) ──
    '8301': HsnGstEntry(hsnCode: '8301', gstRate: 18, description: 'Padlocks, locks, keys'),
    '8302': HsnGstEntry(hsnCode: '8302', gstRate: 18, description: 'Hinges, fittings, mountings'),
    '8305': HsnGstEntry(hsnCode: '8305', gstRate: 18, description: 'Staple removers, paper clips'),
    '8311': HsnGstEntry(hsnCode: '8311', gstRate: 18, description: 'Welding wire, rods, electrodes'),

    // ── ELECTRICAL (Chapter 85) ──
    '8536': HsnGstEntry(hsnCode: '8536', gstRate: 18, description: 'Switches, sockets, plugs (≤1000V)'),
    '8537': HsnGstEntry(hsnCode: '8537', gstRate: 18, description: 'Boards, panels, switchboards'),
    '8539': HsnGstEntry(hsnCode: '8539', gstRate: 18, description: 'Electric filament lamps'),
    '8544': HsnGstEntry(hsnCode: '8544', gstRate: 18, description: 'Insulated wire, cables'),

    // ── CEMENT & BUILDING MATERIALS ──
    '2523': HsnGstEntry(hsnCode: '2523', gstRate: 28, description: 'Portland cement, aluminous cement'),
    '2515': HsnGstEntry(hsnCode: '2515', gstRate: 5, description: 'Marble, granite (blocks)'),
    '2516': HsnGstEntry(hsnCode: '2516', gstRate: 5, description: 'Granite, sandstone'),
    '6802': HsnGstEntry(hsnCode: '6802', gstRate: 28, description: 'Worked stone (slabs, tiles)'),
    '6901': HsnGstEntry(hsnCode: '6901', gstRate: 18, description: 'Bricks, blocks, tiles (siliceous)'),
    '6904': HsnGstEntry(hsnCode: '6904', gstRate: 5, description: 'Ceramic building bricks'),
    '6905': HsnGstEntry(hsnCode: '6905', gstRate: 18, description: 'Roofing tiles'),
    '6907': HsnGstEntry(hsnCode: '6907', gstRate: 18, description: 'Ceramic flags, tiles (floor/wall)'),
    '6910': HsnGstEntry(hsnCode: '6910', gstRate: 18, description: 'Ceramic sinks, wash basins, toilets'),

    // ── PAINT & COATINGS ──
    '3208': HsnGstEntry(hsnCode: '3208', gstRate: 28, description: 'Paints and varnishes (non-aqueous)'),
    '3209': HsnGstEntry(hsnCode: '3209', gstRate: 18, description: 'Paints and varnishes (aqueous)'),
    '3210': HsnGstEntry(hsnCode: '3210', gstRate: 18, description: 'Other paints and varnishes'),
    '3214': HsnGstEntry(hsnCode: '3214', gstRate: 28, description: 'Putty, glazing, mastics'),

    // ── PVC & PLASTICS ──
    '3917': HsnGstEntry(hsnCode: '3917', gstRate: 18, description: 'PVC tubes, pipes, hoses'),
    '3922': HsnGstEntry(hsnCode: '3922', gstRate: 18, description: 'Plastic baths, sinks, toilet seats'),
    '3925': HsnGstEntry(hsnCode: '3925', gstRate: 18, description: 'Plastic building materials (doors, windows)'),
    '3926': HsnGstEntry(hsnCode: '3926', gstRate: 18, description: 'Other articles of plastics'),

    // ── WOOD (Chapter 44) ──
    '4407': HsnGstEntry(hsnCode: '4407', gstRate: 18, description: 'Sawn wood'),
    '4408': HsnGstEntry(hsnCode: '4408', gstRate: 18, description: 'Veneer sheets, plywood sheets'),
    '4410': HsnGstEntry(hsnCode: '4410', gstRate: 18, description: 'Particle board'),
    '4411': HsnGstEntry(hsnCode: '4411', gstRate: 18, description: 'Fibreboard (MDF, HDF)'),
    '4412': HsnGstEntry(hsnCode: '4412', gstRate: 18, description: 'Plywood, veneered panels'),

    // ── GLASS ──
    '7003': HsnGstEntry(hsnCode: '7003', gstRate: 18, description: 'Cast/rolled glass, sheets'),
    '7004': HsnGstEntry(hsnCode: '7004', gstRate: 18, description: 'Drawn/blown glass, sheets'),
    '7005': HsnGstEntry(hsnCode: '7005', gstRate: 18, description: 'Float glass, polished glass'),
    '7007': HsnGstEntry(hsnCode: '7007', gstRate: 18, description: 'Safety glass (tempered, laminated)'),
    '7008': HsnGstEntry(hsnCode: '7008', gstRate: 18, description: 'Glass insulating units'),

    // ── ADHESIVES & SEALANTS ──
    '3506': HsnGstEntry(hsnCode: '3506', gstRate: 18, description: 'Adhesives (Fevicol, etc.)'),

    // ── SANDPAPER & ABRASIVES ──
    '6805': HsnGstEntry(hsnCode: '6805', gstRate: 18, description: 'Sandpaper, abrasive cloths'),

    // ── RUBBER (Chapter 40) ──
    '4009': HsnGstEntry(hsnCode: '4009', gstRate: 18, description: 'Rubber tubes/pipes/hoses'),
    '4016': HsnGstEntry(hsnCode: '4016', gstRate: 18, description: 'Other articles of rubber'),
  };
}
