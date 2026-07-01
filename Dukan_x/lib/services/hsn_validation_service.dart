/// HSN Validation Result
class HsnValidationResult {
  final bool isValid;
  final String? hsnCode;
  final String? description;
  final double? gstRate;
  final String? errorMessage;

  const HsnValidationResult({
    required this.isValid,
    this.hsnCode,
    this.description,
    this.gstRate,
    this.errorMessage,
  });

  @override
  String toString() => isValid
      ? 'HsnValidationResult(valid: $hsnCode - $description @ $gstRate%)'
      : 'HsnValidationResult(invalid: $errorMessage)';
}

/// HSN Code Entry for the master database
class HsnEntry {
  final String code;
  final String description;
  final double gstRate;
  final String category;

  const HsnEntry({
    required this.code,
    required this.description,
    required this.gstRate,
    this.category = 'General',
  });
}

/// HSN Validation Service - Validates HSN codes against master database.
///
/// ## Features
/// - Validates HSN format (2/4/6/8 digits)
/// - Provides HSN lookup with description
/// - Returns applicable GST rate
/// - Contains common retail/wholesale HSN codes
///
/// ## HSN Code Structure
/// - Chapter (2 digits): Broad category
/// - Heading (4 digits): Specific group
/// - Sub-heading (6 digits): Detailed classification
/// - Tariff Item (8 digits): Most specific
class HsnValidationService {
  // Singleton instance
  static final HsnValidationService _instance =
      HsnValidationService._internal();
  factory HsnValidationService() => _instance;
  HsnValidationService._internal();

  // ============================================================
  // HSN MASTER DATABASE (Common Retail/Wholesale Codes)
  // ============================================================

  static const Map<String, HsnEntry> _hsnMaster = {
    // Chapter 01-05: Live animals and animal products
    '0401': HsnEntry(
      code: '0401',
      description: 'Milk and cream',
      gstRate: 0,
      category: 'Dairy',
    ),
    '0402': HsnEntry(
      code: '0402',
      description: 'Milk concentrated/sweetened',
      gstRate: 5,
      category: 'Dairy',
    ),
    '0403': HsnEntry(
      code: '0403',
      description: 'Yogurt, buttermilk',
      gstRate: 5,
      category: 'Dairy',
    ),
    '0406': HsnEntry(
      code: '0406',
      description: 'Cheese and curd',
      gstRate: 12,
      category: 'Dairy',
    ),

    // Chapter 06-14: Vegetable products
    '0701': HsnEntry(
      code: '0701',
      description: 'Potatoes',
      gstRate: 0,
      category: 'Vegetables',
    ),
    '0702': HsnEntry(
      code: '0702',
      description: 'Tomatoes',
      gstRate: 0,
      category: 'Vegetables',
    ),
    '0703': HsnEntry(
      code: '0703',
      description: 'Onions, garlic, leeks',
      gstRate: 0,
      category: 'Vegetables',
    ),
    '0704': HsnEntry(
      code: '0704',
      description: 'Cabbages, cauliflower',
      gstRate: 0,
      category: 'Vegetables',
    ),
    '0706': HsnEntry(
      code: '0706',
      description: 'Carrots, turnips',
      gstRate: 0,
      category: 'Vegetables',
    ),
    '0707': HsnEntry(
      code: '0707',
      description: 'Cucumbers and gherkins',
      gstRate: 0,
      category: 'Vegetables',
    ),
    '0708': HsnEntry(
      code: '0708',
      description: 'Leguminous vegetables',
      gstRate: 0,
      category: 'Vegetables',
    ),
    '0709': HsnEntry(
      code: '0709',
      description: 'Other vegetables',
      gstRate: 0,
      category: 'Vegetables',
    ),
    '0713': HsnEntry(
      code: '0713',
      description: 'Dried leguminous vegetables',
      gstRate: 0,
      category: 'Pulses',
    ),
    '0803': HsnEntry(
      code: '0803',
      description: 'Bananas',
      gstRate: 0,
      category: 'Fruits',
    ),
    '0804': HsnEntry(
      code: '0804',
      description: 'Dates, figs, pineapples',
      gstRate: 0,
      category: 'Fruits',
    ),
    '0805': HsnEntry(
      code: '0805',
      description: 'Citrus fruits',
      gstRate: 0,
      category: 'Fruits',
    ),
    '0806': HsnEntry(
      code: '0806',
      description: 'Grapes',
      gstRate: 0,
      category: 'Fruits',
    ),
    '0807': HsnEntry(
      code: '0807',
      description: 'Melons, papaya',
      gstRate: 0,
      category: 'Fruits',
    ),
    '0808': HsnEntry(
      code: '0808',
      description: 'Apples, pears',
      gstRate: 0,
      category: 'Fruits',
    ),
    '1001': HsnEntry(
      code: '1001',
      description: 'Wheat and meslin',
      gstRate: 0,
      category: 'Cereals',
    ),
    '1006': HsnEntry(
      code: '1006',
      description: 'Rice',
      gstRate: 5,
      category: 'Cereals',
    ),
    '1101': HsnEntry(
      code: '1101',
      description: 'Wheat or meslin flour',
      gstRate: 0,
      category: 'Flour',
    ),
    '1102': HsnEntry(
      code: '1102',
      description: 'Cereal flours',
      gstRate: 0,
      category: 'Flour',
    ),

    // Chapter 15-24: Prepared foodstuffs
    '1501': HsnEntry(
      code: '1501',
      description: 'Pig fat, lard',
      gstRate: 12,
      category: 'Fats',
    ),
    '1507': HsnEntry(
      code: '1507',
      description: 'Soya-bean oil',
      gstRate: 5,
      category: 'Oils',
    ),
    '1508': HsnEntry(
      code: '1508',
      description: 'Groundnut oil',
      gstRate: 5,
      category: 'Oils',
    ),
    '1509': HsnEntry(
      code: '1509',
      description: 'Olive oil',
      gstRate: 5,
      category: 'Oils',
    ),
    '1510': HsnEntry(
      code: '1510',
      description: 'Other olive oils',
      gstRate: 5,
      category: 'Oils',
    ),
    '1511': HsnEntry(
      code: '1511',
      description: 'Palm oil',
      gstRate: 5,
      category: 'Oils',
    ),
    '1512': HsnEntry(
      code: '1512',
      description: 'Sunflower/safflower oil',
      gstRate: 5,
      category: 'Oils',
    ),
    '1513': HsnEntry(
      code: '1513',
      description: 'Coconut oil',
      gstRate: 5,
      category: 'Oils',
    ),
    '1701': HsnEntry(
      code: '1701',
      description: 'Cane/beet sugar',
      gstRate: 5,
      category: 'Sugar',
    ),
    '1702': HsnEntry(
      code: '1702',
      description: 'Other sugars',
      gstRate: 18,
      category: 'Sugar',
    ),
    '1704': HsnEntry(
      code: '1704',
      description: 'Sugar confectionery',
      gstRate: 18,
      category: 'Confectionery',
    ),
    '1806': HsnEntry(
      code: '1806',
      description: 'Chocolate',
      gstRate: 18,
      category: 'Confectionery',
    ),
    '1901': HsnEntry(
      code: '1901',
      description: 'Malt extract, food preparations',
      gstRate: 18,
      category: 'Prepared Foods',
    ),
    '1902': HsnEntry(
      code: '1902',
      description: 'Pasta',
      gstRate: 12,
      category: 'Prepared Foods',
    ),
    '1905': HsnEntry(
      code: '1905',
      description: 'Bread, pastry, cakes',
      gstRate: 5,
      category: 'Bakery',
    ),
    '2101': HsnEntry(
      code: '2101',
      description: 'Coffee/tea extracts',
      gstRate: 18,
      category: 'Beverages',
    ),
    '2106': HsnEntry(
      code: '2106',
      description: 'Food preparations NES',
      gstRate: 18,
      category: 'Prepared Foods',
    ),
    '2201': HsnEntry(
      code: '2201',
      description: 'Mineral/aerated water',
      gstRate: 18,
      category: 'Beverages',
    ),
    '2202': HsnEntry(
      code: '2202',
      description: 'Sweetened/flavored water',
      gstRate: 28,
      category: 'Beverages',
    ),
    '2402': HsnEntry(
      code: '2402',
      description: 'Cigars, cigarettes',
      gstRate: 28,
      category: 'Tobacco',
    ),

    // Chapter 30: Pharmaceutical products
    '3001': HsnEntry(
      code: '3001',
      description: 'Glands, organs dried',
      gstRate: 12,
      category: 'Pharma',
    ),
    '3002': HsnEntry(
      code: '3002',
      description: 'Human/animal blood',
      gstRate: 12,
      category: 'Pharma',
    ),
    '3003': HsnEntry(
      code: '3003',
      description: 'Medicaments (not packaged)',
      gstRate: 12,
      category: 'Pharma',
    ),
    '3004': HsnEntry(
      code: '3004',
      description: 'Medicaments (therapeutic)',
      gstRate: 12,
      category: 'Pharma',
    ),
    '3005': HsnEntry(
      code: '3005',
      description: 'Wadding, bandages',
      gstRate: 12,
      category: 'Medical',
    ),
    '3006': HsnEntry(
      code: '3006',
      description: 'Pharmaceutical goods',
      gstRate: 12,
      category: 'Pharma',
    ),

    // Chapter 33: Essential oils, cosmetics
    '3301': HsnEntry(
      code: '3301',
      description: 'Essential oils',
      gstRate: 18,
      category: 'Cosmetics',
    ),
    '3302': HsnEntry(
      code: '3302',
      description: 'Odoriferous mixtures',
      gstRate: 18,
      category: 'Cosmetics',
    ),
    '3303': HsnEntry(
      code: '3303',
      description: 'Perfumes',
      gstRate: 18,
      category: 'Cosmetics',
    ),
    '3304': HsnEntry(
      code: '3304',
      description: 'Beauty/makeup preparations',
      gstRate: 18,
      category: 'Cosmetics',
    ),
    '3305': HsnEntry(
      code: '3305',
      description: 'Hair preparations',
      gstRate: 18,
      category: 'Cosmetics',
    ),
    '3306': HsnEntry(
      code: '3306',
      description: 'Oral hygiene preparations',
      gstRate: 18,
      category: 'Cosmetics',
    ),
    '3307': HsnEntry(
      code: '3307',
      description: 'Shaving preparations',
      gstRate: 18,
      category: 'Cosmetics',
    ),

    // Chapter 34: Soap, cleaning
    '3401': HsnEntry(
      code: '3401',
      description: 'Soap, cleaning preparations',
      gstRate: 18,
      category: 'FMCG',
    ),
    '3402': HsnEntry(
      code: '3402',
      description: 'Detergents',
      gstRate: 18,
      category: 'FMCG',
    ),

    // Chapter 48-49: Paper
    '4801': HsnEntry(
      code: '4801',
      description: 'Newsprint',
      gstRate: 5,
      category: 'Paper',
    ),
    '4802': HsnEntry(
      code: '4802',
      description: 'Writing/printing paper',
      gstRate: 12,
      category: 'Paper',
    ),
    '4818': HsnEntry(
      code: '4818',
      description: 'Tissue paper, towels',
      gstRate: 12,
      category: 'Paper',
    ),
    '4820': HsnEntry(
      code: '4820',
      description: 'Registers, notebooks',
      gstRate: 12,
      category: 'Stationery',
    ),

    // Chapter 61-63: Textiles
    '6101': HsnEntry(
      code: '6101',
      description: 'Men\'s coats (knitted)',
      gstRate: 12,
      category: 'Apparel',
    ),
    '6102': HsnEntry(
      code: '6102',
      description: 'Women\'s coats (knitted)',
      gstRate: 12,
      category: 'Apparel',
    ),
    '6103': HsnEntry(
      code: '6103',
      description: 'Men\'s suits (knitted)',
      gstRate: 12,
      category: 'Apparel',
    ),
    '6104': HsnEntry(
      code: '6104',
      description: 'Women\'s suits (knitted)',
      gstRate: 12,
      category: 'Apparel',
    ),
    '6105': HsnEntry(
      code: '6105',
      description: 'Men\'s shirts (knitted)',
      gstRate: 12,
      category: 'Apparel',
    ),
    '6106': HsnEntry(
      code: '6106',
      description: 'Women\'s blouses (knitted)',
      gstRate: 12,
      category: 'Apparel',
    ),
    '6109': HsnEntry(
      code: '6109',
      description: 'T-shirts, vests (knitted)',
      gstRate: 12,
      category: 'Apparel',
    ),
    '6110': HsnEntry(
      code: '6110',
      description: 'Jerseys, pullovers',
      gstRate: 12,
      category: 'Apparel',
    ),
    '6201': HsnEntry(
      code: '6201',
      description: 'Men\'s coats (woven)',
      gstRate: 12,
      category: 'Apparel',
    ),
    '6203': HsnEntry(
      code: '6203',
      description: 'Men\'s suits (woven)',
      gstRate: 12,
      category: 'Apparel',
    ),
    '6204': HsnEntry(
      code: '6204',
      description: 'Women\'s suits (woven)',
      gstRate: 12,
      category: 'Apparel',
    ),
    '6205': HsnEntry(
      code: '6205',
      description: 'Men\'s shirts (woven)',
      gstRate: 12,
      category: 'Apparel',
    ),

    // Chapter 64: Footwear
    '6401': HsnEntry(
      code: '6401',
      description: 'Waterproof footwear',
      gstRate: 12,
      category: 'Footwear',
    ),
    '6402': HsnEntry(
      code: '6402',
      description: 'Rubber/plastic footwear',
      gstRate: 12,
      category: 'Footwear',
    ),
    '6403': HsnEntry(
      code: '6403',
      description: 'Leather footwear',
      gstRate: 12,
      category: 'Footwear',
    ),
    '6404': HsnEntry(
      code: '6404',
      description: 'Textile footwear',
      gstRate: 12,
      category: 'Footwear',
    ),

    // Chapter 84-85: Machinery, electronics
    '8415': HsnEntry(
      code: '8415',
      description: 'Air conditioners',
      gstRate: 28,
      category: 'Electronics',
    ),
    '8418': HsnEntry(
      code: '8418',
      description: 'Refrigerators',
      gstRate: 18,
      category: 'Electronics',
    ),
    '8422': HsnEntry(
      code: '8422',
      description: 'Dishwashers',
      gstRate: 18,
      category: 'Electronics',
    ),
    '8450': HsnEntry(
      code: '8450',
      description: 'Washing machines',
      gstRate: 18,
      category: 'Electronics',
    ),
    '8451': HsnEntry(
      code: '8451',
      description: 'Drying machines',
      gstRate: 18,
      category: 'Electronics',
    ),
    '8471': HsnEntry(
      code: '8471',
      description: 'Computers',
      gstRate: 18,
      category: 'Electronics',
    ),
    '8504': HsnEntry(
      code: '8504',
      description: 'Transformers, converters',
      gstRate: 18,
      category: 'Electronics',
    ),
    '8517': HsnEntry(
      code: '8517',
      description: 'Telephones, mobiles',
      gstRate: 18,
      category: 'Electronics',
    ),
    '8518': HsnEntry(
      code: '8518',
      description: 'Microphones, speakers',
      gstRate: 18,
      category: 'Electronics',
    ),
    '8519': HsnEntry(
      code: '8519',
      description: 'Sound recording equipment',
      gstRate: 18,
      category: 'Electronics',
    ),
    '8521': HsnEntry(
      code: '8521',
      description: 'Video recording equipment',
      gstRate: 18,
      category: 'Electronics',
    ),
    '8525': HsnEntry(
      code: '8525',
      description: 'Transmission apparatus',
      gstRate: 18,
      category: 'Electronics',
    ),
    '8528': HsnEntry(
      code: '8528',
      description: 'Monitors, TVs',
      gstRate: 18,
      category: 'Electronics',
    ),
    '8534': HsnEntry(
      code: '8534',
      description: 'Printed circuits',
      gstRate: 18,
      category: 'Electronics',
    ),
    '8536': HsnEntry(
      code: '8536',
      description: 'Switches, plugs',
      gstRate: 18,
      category: 'Electronics',
    ),
    '8539': HsnEntry(
      code: '8539',
      description: 'Electric lamps',
      gstRate: 18,
      category: 'Electronics',
    ),
    '8544': HsnEntry(
      code: '8544',
      description: 'Insulated wire/cable',
      gstRate: 18,
      category: 'Electronics',
    ),

    // Chapter 94: Furniture
    '9401': HsnEntry(
      code: '9401',
      description: 'Seats',
      gstRate: 18,
      category: 'Furniture',
    ),
    '9403': HsnEntry(
      code: '9403',
      description: 'Other furniture',
      gstRate: 18,
      category: 'Furniture',
    ),
    '9404': HsnEntry(
      code: '9404',
      description: 'Mattresses',
      gstRate: 18,
      category: 'Furniture',
    ),
    '9405': HsnEntry(
      code: '9405',
      description: 'Lamps and lighting',
      gstRate: 18,
      category: 'Furniture',
    ),

    // Services (SAC Codes)
    '9954': HsnEntry(
      code: '9954',
      description: 'Construction services',
      gstRate: 18,
      category: 'Services',
    ),
    '9961': HsnEntry(
      code: '9961',
      description: 'Financial services',
      gstRate: 18,
      category: 'Services',
    ),
    '9962': HsnEntry(
      code: '9962',
      description: 'Financial auxiliary services',
      gstRate: 18,
      category: 'Services',
    ),
    '9963': HsnEntry(
      code: '9963',
      description: 'Leasing services',
      gstRate: 18,
      category: 'Services',
    ),
    '9964': HsnEntry(
      code: '9964',
      description: 'Transport of passengers',
      gstRate: 5,
      category: 'Services',
    ),
    '9965': HsnEntry(
      code: '9965',
      description: 'Transport of goods',
      gstRate: 5,
      category: 'Services',
    ),
    '9966': HsnEntry(
      code: '9966',
      description: 'Supporting transport services',
      gstRate: 18,
      category: 'Services',
    ),
    '9971': HsnEntry(
      code: '9971',
      description: 'Professional services',
      gstRate: 18,
      category: 'Services',
    ),
    '9972': HsnEntry(
      code: '9972',
      description: 'Real estate services',
      gstRate: 18,
      category: 'Services',
    ),
    '9973': HsnEntry(
      code: '9973',
      description: 'Equipment leasing',
      gstRate: 18,
      category: 'Services',
    ),
    '9981': HsnEntry(
      code: '9981',
      description: 'IT services',
      gstRate: 18,
      category: 'Services',
    ),
    '9982': HsnEntry(
      code: '9982',
      description: 'Legal services',
      gstRate: 18,
      category: 'Services',
    ),
    '9983': HsnEntry(
      code: '9983',
      description: 'Professional technical services',
      gstRate: 18,
      category: 'Services',
    ),
    '9985': HsnEntry(
      code: '9985',
      description: 'Support services',
      gstRate: 18,
      category: 'Services',
    ),
    '9986': HsnEntry(
      code: '9986',
      description: 'Admin/govt services',
      gstRate: 18,
      category: 'Services',
    ),
    '9987': HsnEntry(
      code: '9987',
      description: 'Educational services',
      gstRate: 0,
      category: 'Services',
    ),
    '9988': HsnEntry(
      code: '9988',
      description: 'Manufacturing services',
      gstRate: 18,
      category: 'Services',
    ),
    '9991': HsnEntry(
      code: '9991',
      description: 'Public admin services',
      gstRate: 0,
      category: 'Services',
    ),
    '9992': HsnEntry(
      code: '9992',
      description: 'Healthcare services',
      gstRate: 0,
      category: 'Services',
    ),
    '9995': HsnEntry(
      code: '9995',
      description: 'Recreation services',
      gstRate: 18,
      category: 'Services',
    ),
    '9996': HsnEntry(
      code: '9996',
      description: 'Personal services',
      gstRate: 18,
      category: 'Services',
    ),
    '9997': HsnEntry(
      code: '9997',
      description: 'Other services',
      gstRate: 18,
      category: 'Services',
    ),
    '9998': HsnEntry(
      code: '9998',
      description: 'Domestic services',
      gstRate: 0,
      category: 'Services',
    ),
    '9999': HsnEntry(
      code: '9999',
      description: 'Services by international orgs',
      gstRate: 0,
      category: 'Services',
    ),
  };

  // ============================================================
  // VALIDATION METHODS
  // ============================================================

  /// Validate HSN code format.
  ///
  /// Valid formats:
  /// - 2 digits: Chapter code (e.g., "01")
  /// - 4 digits: Heading code (e.g., "0101")
  /// - 6 digits: Sub-heading code (e.g., "010121")
  /// - 8 digits: Tariff item (e.g., "01012100")
  bool isValidFormat(String hsn) {
    if (hsn.isEmpty) return false;

    // Remove any whitespace
    final cleaned = hsn.replaceAll(RegExp(r'\s'), '');

    // Check if it's all digits
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) return false;

    // Valid lengths: 2, 4, 6, or 8
    return [2, 4, 6, 8].contains(cleaned.length);
  }

  /// Validate and lookup HSN code.
  ///
  /// Returns HsnValidationResult with:
  /// - isValid: true if code is valid
  /// - description: Product/service description
  /// - gstRate: Applicable GST rate
  HsnValidationResult validate(String hsn) {
    if (hsn.isEmpty) {
      return const HsnValidationResult(
        isValid: true, // Empty HSN is valid for non-GST items
        hsnCode: null,
        description: 'No HSN specified',
        gstRate: null,
      );
    }

    final cleaned = hsn.replaceAll(RegExp(r'\s'), '');

    // Format check
    if (!isValidFormat(cleaned)) {
      return HsnValidationResult(
        isValid: false,
        hsnCode: cleaned,
        errorMessage: 'Invalid HSN format. Must be 2, 4, 6, or 8 digits.',
      );
    }

    // Lookup in master database
    // Try exact match first, then progressively shorter prefixes
    HsnEntry? entry;
    for (int len = cleaned.length; len >= 2; len -= 2) {
      final prefix = cleaned.substring(0, len);
      if (_hsnMaster.containsKey(prefix)) {
        entry = _hsnMaster[prefix];
        break;
      }
    }

    if (entry != null) {
      return HsnValidationResult(
        isValid: true,
        hsnCode: cleaned,
        description: entry.description,
        gstRate: entry.gstRate,
      );
    }

    // Code is valid format but not in our database
    // We still accept it (user might have specialized HSN)
    return HsnValidationResult(
      isValid: true,
      hsnCode: cleaned,
      description: 'HSN code not in master database',
      gstRate: null, // Unknown rate
    );
  }

  /// Get GST rate for an HSN code.
  ///
  /// Returns null if HSN is not found in master database.
  double? getGstRate(String hsn) {
    final result = validate(hsn);
    return result.gstRate;
  }

  /// Get description for an HSN code.
  String? getDescription(String hsn) {
    final result = validate(hsn);
    return result.description;
  }

  /// Search HSN codes by description.
  ///
  /// Returns list of matching entries.
  List<HsnEntry> searchByDescription(String query) {
    if (query.isEmpty) return [];

    final lowerQuery = query.toLowerCase();
    return _hsnMaster.values
        .where((e) => e.description.toLowerCase().contains(lowerQuery))
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));
  }

  /// Get all HSN codes for a category.
  List<HsnEntry> getByCategory(String category) {
    return _hsnMaster.values
        .where((e) => e.category.toLowerCase() == category.toLowerCase())
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));
  }

  /// Get all available categories.
  List<String> getCategories() {
    final categories = _hsnMaster.values
        .map((e) => e.category)
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }

  /// Get all HSN entries (for dropdown/autocomplete).
  List<HsnEntry> getAllEntries() {
    return _hsnMaster.values.toList()..sort((a, b) => a.code.compareTo(b.code));
  }

  /// Suggest HSN code based on product name.
  ///
  /// Uses simple keyword matching to suggest relevant HSN codes.
  List<HsnEntry> suggestFromProductName(String productName) {
    if (productName.isEmpty) return [];

    final keywords = productName.toLowerCase().split(RegExp(r'[\s,]+'));
    final suggestions = <HsnEntry>[];

    for (final entry in _hsnMaster.values) {
      final desc = entry.description.toLowerCase();
      for (final keyword in keywords) {
        if (keyword.length >= 3 && desc.contains(keyword)) {
          if (!suggestions.contains(entry)) {
            suggestions.add(entry);
          }
          break;
        }
      }
    }

    // Sort by relevance (number of matching keywords)
    suggestions.sort((a, b) {
      int countA = 0, countB = 0;
      for (final keyword in keywords) {
        if (a.description.toLowerCase().contains(keyword)) countA++;
        if (b.description.toLowerCase().contains(keyword)) countB++;
      }
      return countB.compareTo(countA); // Higher count first
    });

    return suggestions.take(10).toList();
  }

  // ============================================================
  // VALIDATION FOR BILL ITEMS
  // ============================================================

  /// Validate HSN codes for a list of bill items.
  ///
  /// Returns a map of productId -> HsnValidationResult
  Map<String, HsnValidationResult> validateBillItems(
    List<Map<String, dynamic>> items,
  ) {
    final results = <String, HsnValidationResult>{};

    for (final item in items) {
      final productId = item['productId'] as String? ?? '';
      final hsn = item['hsn'] as String? ?? '';

      if (productId.isNotEmpty) {
        results[productId] = validate(hsn);
      }
    }

    return results;
  }

  /// Check if all items have valid HSN codes.
  bool areAllItemsValid(List<Map<String, dynamic>> items) {
    final results = validateBillItems(items);
    return results.values.every((r) => r.isValid);
  }

  /// Get any validation errors from items.
  List<String> getValidationErrors(List<Map<String, dynamic>> items) {
    final errors = <String>[];
    final results = validateBillItems(items);

    for (final entry in results.entries) {
      if (!entry.value.isValid) {
        final productName =
            items.firstWhere(
              (i) => i['productId'] == entry.key,
              orElse: () => <String, dynamic>{},
            )['productName'] ??
            'Unknown';
        errors.add('$productName: ${entry.value.errorMessage}');
      }
    }

    return errors;
  }
}
