class VegetablePurchase {
  String vegId;
  String vegName;
  double quantityKg;
  double pricePerKg;
  double total;
  DateTime purchaseDate;
  bool isRecurring;

  VegetablePurchase({
    required this.vegId,
    required this.vegName,
    required this.quantityKg,
    this.pricePerKg = 0.0,
    this.total = 0.0,
    required this.purchaseDate,
    this.isRecurring = false,
  });

  Map<String, dynamic> toMap() => {
    'vegId': vegId,
    'vegName': vegName,
    'quantityKg': quantityKg,
    'pricePerKg': pricePerKg,
    'total': total,
    'purchaseDate': purchaseDate.toIso8601String(),
    'isRecurring': isRecurring,
  };

  factory VegetablePurchase.fromMap(Map<String, dynamic> map) =>
      VegetablePurchase(
        vegId: map['vegId'] ?? '',
        vegName: map['vegName'] ?? '',
        quantityKg: (map['quantityKg'] ?? 0).toDouble(),
        pricePerKg: (map['pricePerKg'] ?? 0).toDouble(),
        total: (map['total'] ?? 0).toDouble(),
        purchaseDate: DateTime.parse(
          map['purchaseDate'] ?? DateTime.now().toIso8601String(),
        ),
        isRecurring: map['isRecurring'] ?? false,
      );
}

class Customer {
  String id;
  String name;
  String phone;
  String address;
  String? email; // NEW
  String password; // For customer login

  // === NEW: Proper FK relationships ===
  /// FK to Business - the primary shop this customer belongs to
  String? businessId;

  /// FK to Ledger - linked Sundry Debtor ledger for this customer
  String? ledgerId;

  /// Customer GSTIN for B2B invoicing
  String? gstin;

  // === DEPRECATED: Use LedgerService.getPartyBalance() instead ===
  @Deprecated(
    'Use LedgerService.getPartyBalance() to derive balance from ledger entries',
  )
  double totalDues;
  @Deprecated('Use LedgerService to derive balance by payment mode')
  double cashDues;
  @Deprecated('Use LedgerService to derive balance by payment mode')
  double onlineDues;

  List<VegetablePurchase> vegetableHistory;
  List<Map<String, dynamic>> billHistory;
  bool isBlacklisted;
  DateTime? blacklistDate;
  double discountPercent;
  double marketTicketAmount;

  // === DEPRECATED: Use businessId instead ===
  @Deprecated('Use businessId FK instead')
  String? linkedOwnerId;
  @Deprecated('Removed array-based ownership. Use businessId FK instead.')
  List<String> linkedShopIds;

  // Petrol Pump specific fields (for fleet/credit customers)
  String? vehicleNumber;
  double? creditLimit;
  bool monthlyBillingEnabled;
  double outstandingCreditAmount;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    this.email,
    this.password = '',
    // New FK fields
    this.businessId,
    this.ledgerId,
    this.gstin,
    // Deprecated - keep for backward compatibility
    this.totalDues = 0.0,
    this.cashDues = 0.0,
    this.onlineDues = 0.0,
    this.vegetableHistory = const [],
    this.billHistory = const [],
    this.isBlacklisted = false,
    this.blacklistDate,
    this.discountPercent = 0.0,
    this.marketTicketAmount = 0.0,
    this.linkedOwnerId,
    this.linkedShopIds = const [],
    // Petrol Pump fields
    this.vehicleNumber,
    this.creditLimit,
    this.monthlyBillingEnabled = false,
    this.outstandingCreditAmount = 0.0,
  });

  factory Customer.fromMap(String id, Map<String, dynamic> map) => Customer(
    id: id,
    name: map['name'] ?? '',
    phone: map['phone'] ?? '',
    address: map['address'] ?? '',
    email: map['email'],
    password: map['password'] ?? '',
    // New FK fields
    businessId: map['businessId'],
    ledgerId: map['ledgerId'],
    gstin: map['gstin'],
    totalDues: (map['totalDues'] ?? 0).toDouble(),
    cashDues: (map['cashDues'] ?? 0).toDouble(),
    onlineDues: (map['onlineDues'] ?? 0).toDouble(),
    vegetableHistory:
        (map['vegetableHistory'] as List<dynamic>?)
            ?.map(
              (e) => VegetablePurchase.fromMap(Map<String, dynamic>.from(e)),
            )
            .toList() ??
        [],
    billHistory:
        (map['billHistory'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [],
    isBlacklisted: map['isBlacklisted'] ?? false,
    blacklistDate: map['blacklistDate'] != null
        ? DateTime.parse(map['blacklistDate'])
        : null,
    discountPercent: (map['discountPercent'] ?? 0).toDouble(),
    marketTicketAmount: (map['marketTicketAmount'] ?? 0).toDouble(),
    linkedOwnerId: map['linkedOwnerId'],
    linkedShopIds:
        (map['linkedShopIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        (map['linkedOwnerId'] != null ? [map['linkedOwnerId']] : []),
    // Petrol Pump fields
    vehicleNumber: map['vehicleNumber'] as String?,
    creditLimit: (map['creditLimit'] as num?)?.toDouble(),
    monthlyBillingEnabled: map['monthlyBillingEnabled'] as bool? ?? false,
    outstandingCreditAmount:
        (map['outstandingCreditAmount'] as num?)?.toDouble() ?? 0.0,
  );

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    String? email,
    String? password,
    double? totalDues,
    double? cashDues,
    double? onlineDues,
    List<VegetablePurchase>? vegetableHistory,
    List<Map<String, dynamic>>? billHistory,
    bool? isBlacklisted,
    DateTime? blacklistDate,
    double? discountPercent,
    double? marketTicketAmount,
    String? linkedOwnerId,
    List<String>? linkedShopIds,
    // Petrol Pump fields
    String? vehicleNumber,
    double? creditLimit,
    bool? monthlyBillingEnabled,
    double? outstandingCreditAmount,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      email: email ?? this.email,
      password: password ?? this.password,
      // ignore: deprecated_member_use_from_same_package
      totalDues: totalDues ?? this.totalDues,
      // ignore: deprecated_member_use_from_same_package
      cashDues: cashDues ?? this.cashDues,
      // ignore: deprecated_member_use_from_same_package
      onlineDues: onlineDues ?? this.onlineDues,
      vegetableHistory: vegetableHistory ?? this.vegetableHistory,
      billHistory: billHistory ?? this.billHistory,
      isBlacklisted: isBlacklisted ?? this.isBlacklisted,
      blacklistDate: blacklistDate ?? this.blacklistDate,
      discountPercent: discountPercent ?? this.discountPercent,
      marketTicketAmount: marketTicketAmount ?? this.marketTicketAmount,
      // ignore: deprecated_member_use_from_same_package
      linkedOwnerId: linkedOwnerId ?? this.linkedOwnerId,
      // ignore: deprecated_member_use_from_same_package
      linkedShopIds: linkedShopIds ?? this.linkedShopIds,
      // Petrol Pump fields
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      creditLimit: creditLimit ?? this.creditLimit,
      monthlyBillingEnabled:
          monthlyBillingEnabled ?? this.monthlyBillingEnabled,
      outstandingCreditAmount:
          outstandingCreditAmount ?? this.outstandingCreditAmount,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'phone': phone,
    'address': address,
    if (email != null) 'email': email,
    'password': password,
    // New FK fields
    'businessId': businessId,
    'ledgerId': ledgerId,
    'gstin': gstin,
    // ignore: deprecated_member_use_from_same_package
    'totalDues': totalDues,
    // ignore: deprecated_member_use_from_same_package
    'cashDues': cashDues,
    // ignore: deprecated_member_use_from_same_package
    'onlineDues': onlineDues,
    'vegetableHistory': vegetableHistory.map((e) => e.toMap()).toList(),
    'billHistory': billHistory,
    'isBlacklisted': isBlacklisted,
    'blacklistDate': blacklistDate?.toIso8601String(),
    'discountPercent': discountPercent,
    'marketTicketAmount': marketTicketAmount,
    // ignore: deprecated_member_use_from_same_package
    'linkedOwnerId': linkedOwnerId,
    // ignore: deprecated_member_use_from_same_package
    'linkedShopIds': linkedShopIds,
    // Petrol Pump fields
    if (vehicleNumber != null) 'vehicleNumber': vehicleNumber,
    if (creditLimit != null) 'creditLimit': creditLimit,
    'monthlyBillingEnabled': monthlyBillingEnabled,
    'outstandingCreditAmount': outstandingCreditAmount,
  };
}
