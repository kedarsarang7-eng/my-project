// ============================================================================
// DECORATION & CATERING — REPOSITORY  (Real API)
// ============================================================================
// All methods hit the Lambda-backed /dc/* endpoints via ApiClient.
// Amounts from the API are stored in paise (integer); models use double (₹).
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';
import '../models/dc_models.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final dcRepositoryProvider = Provider<DcRepository>((ref) => DcRepository());

final dcBookingsProvider = FutureProvider.autoDispose<List<EventBooking>>((
  ref,
) async {
  return ref.read(dcRepositoryProvider).getBookings();
});

final dcStatsProvider = FutureProvider.autoDispose<DcDashboardStats>((
  ref,
) async {
  return ref.read(dcRepositoryProvider).getDashboardStats();
});

final dcStaffProvider = FutureProvider.autoDispose<List<DcStaff>>((ref) async {
  return ref.read(dcRepositoryProvider).getStaff();
});

final dcVendorsProvider = FutureProvider.autoDispose<List<DcVendor>>((
  ref,
) async {
  return ref.read(dcRepositoryProvider).getVendors();
});

final dcInventoryProvider = FutureProvider.autoDispose<List<DcInventoryItem>>((
  ref,
) async {
  return ref.read(dcRepositoryProvider).getInventory();
});

final dcMenuItemsProvider = FutureProvider.autoDispose<List<CateringMenuItem>>((
  ref,
) async {
  return ref.read(dcRepositoryProvider).getMenuItems();
});

final dcPackagesProvider = FutureProvider.autoDispose<List<CateringPackage>>((
  ref,
) async {
  return ref.read(dcRepositoryProvider).getPackages();
});

final dcThemesProvider = FutureProvider.autoDispose<List<DecorationTheme>>((
  ref,
) async {
  return ref.read(dcRepositoryProvider).getThemes();
});

final dcExpensesProvider = FutureProvider.autoDispose<List<DcExpense>>((
  ref,
) async {
  return ref.read(dcRepositoryProvider).getExpenses();
});

final dcQuotesProvider = FutureProvider.autoDispose<List<DcQuote>>((ref) async {
  return ref.read(dcRepositoryProvider).getQuotes();
});

/// Family provider: filters expenses by [from, to] date strings 'YYYY-MM-DD'
final dcExpensesFilteredProvider = FutureProvider.autoDispose
    .family<List<DcExpense>, ({String from, String to})>((ref, range) async {
      return ref
          .read(dcRepositoryProvider)
          .getExpenses(from: range.from, to: range.to);
    });

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class DcRepository {
  ApiClient get _api => sl<ApiClient>();

  // ── helpers ──────────────────────────────────────────────────────────────

  static double _paisa(dynamic v) => (v as num? ?? 0) / 100.0;
  static int _toPaisa(double v) => (v * 100).round();

  static EventStatus _parseStatus(String? s) {
    switch (s) {
      case 'confirmed':
        return EventStatus.confirmed;
      case 'ongoing':
        return EventStatus.ongoing;
      case 'completed':
        return EventStatus.completed;
      case 'cancelled':
        return EventStatus.cancelled;
      default:
        return EventStatus.inquiry;
    }
  }

  static String _statusStr(EventStatus s) {
    switch (s) {
      case EventStatus.confirmed:
        return 'confirmed';
      case EventStatus.ongoing:
        return 'ongoing';
      case EventStatus.completed:
        return 'completed';
      case EventStatus.cancelled:
        return 'cancelled';
      case EventStatus.inquiry:
        return 'enquiry';
    }
  }

  static EventType _parseEventType(String? s) {
    switch (s) {
      case 'birthday':
        return EventType.birthday;
      case 'corporate':
        return EventType.corporate;
      case 'engagement':
        return EventType.engagement;
      case 'babyShower':
        return EventType.babyShower;
      case 'anniversary':
        return EventType.anniversary;
      case 'conference':
        return EventType.conference;
      case 'wedding':
        return EventType.wedding;
      default:
        return EventType.other;
    }
  }

  static StaffRole _parseStaffRole(String? s) {
    switch (s) {
      case 'cook':
        return StaffRole.cook;
      case 'helper':
        return StaffRole.helper;
      case 'driver':
        return StaffRole.driver;
      case 'manager':
        return StaffRole.manager;
      case 'waiter':
        return StaffRole.waiter;
      case 'supervisor':
        return StaffRole.supervisor;
      default:
        return StaffRole.decorator;
    }
  }

  static InventoryCategory _parseInventoryCategory(String? s) {
    switch (s) {
      case 'lighting':
        return InventoryCategory.lighting;
      case 'flowers':
        return InventoryCategory.flowers;
      case 'fabric':
        return InventoryCategory.fabric;
      case 'utensils':
        return InventoryCategory.utensils;
      case 'sound':
        return InventoryCategory.sound;
      case 'gasItems':
        return InventoryCategory.gasItems;
      case 'miscellaneous':
        return InventoryCategory.miscellaneous;
      default:
        return InventoryCategory.furniture;
    }
  }

  static MenuCategory _parseMenuCategory(String? s) {
    switch (s) {
      case 'nonVeg':
        return MenuCategory.nonVeg;
      case 'jain':
        return MenuCategory.jain;
      case 'dessert':
        return MenuCategory.dessert;
      case 'beverages':
        return MenuCategory.beverages;
      case 'custom':
        return MenuCategory.custom;
      default:
        return MenuCategory.veg;
    }
  }

  // ── fromJson helpers ─────────────────────────────────────────────────────

  /// Parses a single booking record with null-safe defaults.
  /// Throws if 'id' is missing (caller handles skip logic).
  static EventBooking _bookingFromJson(Map<String, dynamic> j) {
    // id is mandatory — a missing id means the record is unusable.
    final id = j['id'] as String?;
    if (id == null || id.isEmpty) {
      throw FormatException('Booking record missing required "id" field');
    }

    // Parse eventDate with tryParse fallback
    final eventDate =
        DateTime.tryParse(j['eventDate'] as String? ?? '') ?? DateTime.now();

    // Parse and validate eventEndDate (Requirement 12.6, 12.11)
    DateTime? eventEndDate;
    final rawEndDate = j['eventEndDate'] as String?;
    if (rawEndDate != null && rawEndDate.isNotEmpty) {
      final parsed = DateTime.tryParse(rawEndDate);
      if (parsed != null) {
        if (parsed.isBefore(eventDate)) {
          // eventEndDate < eventDate → reject with error indication
          debugPrint(
            '[DcRepository] eventEndDate "$rawEndDate" is before eventDate '
            '"${eventDate.toIso8601String()}" for booking "$id"; '
            'rejecting eventEndDate (set to null)',
          );
          eventEndDate = null;
        } else {
          eventEndDate = parsed;
        }
      }
    }

    // Parse createdAt with tryParse fallback
    final createdAt =
        DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now();

    return EventBooking(
      id: id,
      customerId: j['customerId'] as String? ?? '',
      customerName: j['customerName'] as String? ?? '',
      customerPhone: j['customerPhone'] as String? ?? '',
      customerEmail: j['customerEmail'] as String? ?? '',
      eventType: _parseEventType(j['eventType'] as String?),
      eventTitle: j['eventTitle'] as String? ?? j['eventType'] as String? ?? '',
      eventDate: eventDate,
      eventEndDate: eventEndDate,
      venue: j['venueName'] as String? ?? '',
      venueAddress: j['venueAddress'] as String? ?? '',
      guestCount: (j['guestCount'] as num?)?.toInt() ?? 0,
      status: _parseStatus(j['status'] as String?),
      quotedAmount: _paisa(j['totalAmountPaisa']),
      advancePaid: _paisa(j['advanceAmountPaisa']),
      notes: j['notes'] as String?,
      createdAt: createdAt,
      decorationThemeId: j['decorationThemeId'] as String?,
      cateringPackageId: j['cateringPackageId'] as String?,
      assignedStaffIds: List<String>.from(j['assignedStaffIds'] ?? []),
      includesDecoration: j['includesDecoration'] as bool? ?? false,
      includesCatering: j['includesCatering'] as bool? ?? false,
      notesList: (j['notesList'] as List? ?? [])
          .map((e) => _noteFromJson(e as Map<String, dynamic>))
          .toList(),
      setupTime: j['setupTime'] as String?,
      serviceStartTime: j['serviceStartTime'] as String?,
      serviceEndTime: j['serviceEndTime'] as String?,
      cleanupTime: j['cleanupTime'] as String?,
    );
  }

  static DecorationTheme _themeFromJson(Map<String, dynamic> j) =>
      DecorationTheme(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String? ?? '',
        category: j['category'] as String,
        basePrice: _paisa(j['baseRatePaisa']),
        includedItems: List<String>.from(j['tags'] ?? []),
        imageUrls: List<String>.from(j['imageUrls'] ?? []),
      );

  static CateringMenuItem _menuItemFromJson(Map<String, dynamic> j) =>
      CateringMenuItem(
        id: j['id'] as String,
        name: j['name'] as String,
        category: _parseMenuCategory(j['category'] as String?),
        pricePerPlate: _paisa(j['ratePaisaPerPlate']),
        description: j['description'] as String?,
        isAvailable: true,
      );

  static CateringPackage _packageFromJson(Map<String, dynamic> j) =>
      CateringPackage(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String? ?? '',
        pricePerPlate: _paisa(j['pricePerPlatePaisa']),
        minGuests: (j['minGuests'] as num?)?.toInt() ?? 1,
        menuItemIds: List<String>.from(j['menuItemIds'] ?? []),
      );

  static DcStaff _staffFromJson(Map<String, dynamic> j) => DcStaff(
    id: j['id'] as String,
    name: j['name'] as String,
    phone: j['phone'] as String,
    role: _parseStaffRole(j['role'] as String?),
    dailyWage: _paisa(j['dailyRatePaisa']),
    isAvailable: j['isActive'] as bool? ?? true,
    address: j['address'] as String?,
  );

  static DcVendor _vendorFromJson(Map<String, dynamic> j) => DcVendor(
    id: j['id'] as String,
    name: j['name'] as String,
    phone: j['phone'] as String,
    email: j['email'] as String?,
    category: j['vendorType'] as String? ?? '',
    address: j['address'] as String?,
    totalPaid: _paisa(j['totalPaidPaisa']),
    totalDue: _paisa(j['totalDuePaisa']),
    totalExpense: _paisa(j['totalExpensePaisa']),
    notes: j['notes'] as String?,
    createdAt: DateTime.parse(j['createdAt'] as String),
  );

  static DcInventoryItem _inventoryFromJson(Map<String, dynamic> j) {
    // Try both possible API field names for rental price (paise integer).
    // Phase 0 confirmed the backend does NOT currently have this field,
    // so we default to 0 and surface a non-blocking debug indication.
    final dynamic rawRentalPrice = j['rentalPricePaisa'] ?? j['rentalPrice'];
    final bool rentalPriceAvailable = rawRentalPrice != null;
    final double rentalPrice = rentalPriceAvailable
        ? _paisa(rawRentalPrice)
        : 0;

    if (!rentalPriceAvailable) {
      debugPrint(
        '[DcRepository] rentalPrice unavailable for item "${j['id']}"; '
        'defaulting to 0',
      );
    }

    return DcInventoryItem(
      id: j['id'] as String,
      name: j['name'] as String,
      category: _parseInventoryCategory(j['category'] as String?),
      totalQty: (j['currentStock'] as num?)?.toInt() ?? 0,
      availableQty: (j['currentStock'] as num?)?.toInt() ?? 0,
      purchasePrice: _paisa(j['costPaisaPerUnit']),
      rentalPrice: rentalPrice,
      unit: j['unit'] as String? ?? 'pcs',
      lowStockThreshold: (j['reorderPoint'] as num?)?.toInt() ?? 5,
    );
  }

  static QuoteStatus _parseQuoteStatus(String? s) {
    switch (s) {
      case 'sent':
        return QuoteStatus.sent;
      case 'accepted':
        return QuoteStatus.accepted;
      case 'rejected':
        return QuoteStatus.rejected;
      default:
        return QuoteStatus.draft;
    }
  }

  static DcQuote _quoteFromJson(Map<String, dynamic> j) => DcQuote(
    id: j['id'] as String,
    quoteNumber: j['quoteNumber'] as String? ?? '',
    customerName: j['customerName'] as String,
    customerPhone: j['customerPhone'] as String? ?? '',
    eventType: j['eventType'] as String? ?? '',
    eventDate: j['eventDate'] as String?,
    venue: j['venue'] as String?,
    guestCount: (j['guestCount'] as num?)?.toInt() ?? 0,
    lineItems: List<Map<String, dynamic>>.from(
      (j['lineItems'] as List? ?? []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    ),
    subtotal: _paisa(j['subtotalPaisa']),
    gstPct: (j['gstPercent'] as num?)?.toDouble() ?? 18,
    gstAmount: _paisa(j['gstAmountPaisa']),
    discount: _paisa(j['discountPaisa']),
    total: _paisa(j['totalPaisa']),
    notes: j['notes'] as String?,
    validUntil: j['validUntil'] as String?,
    status: _parseQuoteStatus(j['status'] as String?),
    createdAt: DateTime.parse(j['createdAt'] as String),
  );

  static DcEventNote _noteFromJson(Map<String, dynamic> j) => DcEventNote(
    id: j['id'] as String,
    text: j['text'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    createdBy: j['createdBy'] as String? ?? '',
  );

  static DcShoppingListItem _shoppingItemFromJson(Map<String, dynamic> j) =>
      DcShoppingListItem(
        item: j['item'] as String,
        qty: (j['qty'] as num).toDouble(),
        unit: j['unit'] as String,
        estimatedCost: _paisa(j['estimatedCostPaisa']),
      );

  /// Parses a payment method string to the [PaymentMethod] enum.
  /// Returns [PaymentMethod.cash] as a defined default for missing/unrecognized
  /// values and surfaces a non-blocking [debugPrint] indication.
  static PaymentMethod _parsePaymentMethod(String? raw, {String? contextId}) {
    if (raw == null || raw.isEmpty) {
      debugPrint(
        '[DcRepository] paymentMethod missing for record "$contextId"; '
        'defaulting to cash',
      );
      return PaymentMethod.cash;
    }
    switch (raw.toLowerCase()) {
      case 'cash':
        return PaymentMethod.cash;
      case 'upi':
        return PaymentMethod.upi;
      case 'card':
        return PaymentMethod.card;
      case 'cheque':
        return PaymentMethod.cheque;
      case 'banktransfer':
      case 'bank_transfer':
      case 'bank':
        return PaymentMethod.bankTransfer;
      default:
        debugPrint(
          '[DcRepository] unrecognized paymentMethod "$raw" for record '
          '"$contextId"; defaulting to cash',
        );
        return PaymentMethod.cash;
    }
  }

  /// Maps a [PaymentMethod] enum value to its canonical string representation
  /// used in JSON/API payloads.
  static String _paymentMethodToString(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'cash';
      case PaymentMethod.upi:
        return 'upi';
      case PaymentMethod.card:
        return 'card';
      case PaymentMethod.cheque:
        return 'cheque';
      case PaymentMethod.bankTransfer:
        return 'bankTransfer';
    }
  }

  static DcVendorPayment _vendorPaymentFromJson(Map<String, dynamic> j) {
    final rawMode =
        j['paymentMode'] as String? ?? j['paymentMethod'] as String?;
    final recordId = j['id'] as String?;
    // Validate against known PaymentMethod enum values; use canonical string.
    final parsed = _parsePaymentMethod(rawMode, contextId: recordId);
    final validatedMode = _paymentMethodToString(parsed);

    return DcVendorPayment(
      id: j['id'] as String,
      vendorId: j['vendorId'] as String,
      vendorName: j['vendorName'] as String? ?? '',
      amount: _paisa(j['amountPaisa']),
      paymentMode: validatedMode,
      reference: j['reference'] as String?,
      eventId: j['eventId'] as String?,
      notes: j['notes'] as String?,
      date: DateTime.parse(j['date'] as String? ?? j['createdAt'] as String),
    );
  }

  static DcExpense _expenseFromJson(Map<String, dynamic> j) {
    final rawMethod =
        j['paymentMethod'] as String? ?? j['paymentMode'] as String?;
    final recordId = j['id'] as String?;
    final paymentMethod = _parsePaymentMethod(rawMethod, contextId: recordId);

    return DcExpense(
      id: j['id'] as String,
      eventId: j['eventId'] as String? ?? '',
      title: j['description'] as String? ?? j['category'] as String,
      category: j['category'] as String,
      amount: _paisa(j['amountPaisa']),
      paymentMethod: paymentMethod,
      date: DateTime.parse(j['date'] as String),
      notes: j['notes'] as String?,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<T> _dataList<T>(
    ApiResponse<Map<String, dynamic>> res,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = res.data?['data'];
    if (raw is! List) return [];

    final results = <T>[];
    for (final e in raw) {
      try {
        results.add(fromJson(e as Map<String, dynamic>));
      } catch (ex) {
        // Skip malformed record; surface error indication via debugPrint.
        // Valid records are preserved — one bad record does not crash the list.
        debugPrint(
          '[DcRepository] Skipping malformed record: $ex '
          '(data: ${e.toString().substring(0, (e.toString().length).clamp(0, 120))})',
        );
      }
    }
    return results;
  }

  T _dataObject<T>(
    ApiResponse<Map<String, dynamic>> res,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = res.data?['data'];
    if (raw is Map<String, dynamic>) return fromJson(raw);
    throw Exception('Unexpected response shape');
  }

  // ── Bookings ──────────────────────────────────────────────────────────────

  Future<List<EventBooking>> getBookings({
    EventStatus? statusFilter,
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final params = <String, String>{};
    if (statusFilter != null) params['status'] = _statusStr(statusFilter);
    if (search != null && search.isNotEmpty) params['search'] = search;
    final res = await _api.get('/dc/events', queryParams: params);
    return _dataList(res, _bookingFromJson);
  }

  Future<EventBooking?> getBookingById(String id) async {
    final res = await _api.get('/dc/events/$id');
    if (res.statusCode == 404) return null;
    return _dataObject(res, _bookingFromJson);
  }

  Future<EventBooking> createBooking(EventBooking booking) async {
    final body = <String, dynamic>{
      'customerName': booking.customerName,
      'customerPhone': booking.customerPhone,
      'customerEmail': booking.customerEmail,
      'eventType': booking.eventType.name,
      'eventTitle': booking.eventTitle,
      'eventDate': booking.eventDate.toIso8601String().substring(0, 10),
      'venueName': booking.venue,
      'venueAddress': booking.venueAddress,
      'guestCount': booking.guestCount,
      'decorationThemeId': booking.decorationThemeId,
      'cateringPackageId': booking.cateringPackageId,
      'includesDecoration': booking.includesDecoration,
      'includesCatering': booking.includesCatering,
      'advanceAmountPaisa': _toPaisa(booking.advancePaid),
      'notes': booking.notes,
    };
    if (booking.eventEndDate != null) {
      body['eventEndDate'] = booking.eventEndDate!.toIso8601String().substring(
        0,
        10,
      );
    }
    final res = await _api.post('/dc/events', body: body);
    return _dataObject(res, _bookingFromJson);
  }

  Future<EventBooking> updateBooking(EventBooking updated) async {
    final body = <String, dynamic>{
      'customerName': updated.customerName,
      'customerPhone': updated.customerPhone,
      'customerEmail': updated.customerEmail,
      'eventType': updated.eventType.name,
      'eventTitle': updated.eventTitle,
      'eventDate': updated.eventDate.toIso8601String().substring(0, 10),
      'venueName': updated.venue,
      'venueAddress': updated.venueAddress,
      'guestCount': updated.guestCount,
      'status': _statusStr(updated.status),
      'decorationThemeId': updated.decorationThemeId,
      'cateringPackageId': updated.cateringPackageId,
      'includesDecoration': updated.includesDecoration,
      'includesCatering': updated.includesCatering,
      'advanceAmountPaisa': _toPaisa(updated.advancePaid),
      'totalAmountPaisa': _toPaisa(updated.quotedAmount),
      'notes': updated.notes,
      'assignedStaffIds': updated.assignedStaffIds,
    };
    if (updated.eventEndDate != null) {
      body['eventEndDate'] = updated.eventEndDate!.toIso8601String().substring(
        0,
        10,
      );
    }
    final res = await _api.put('/dc/events/${updated.id}', body: body);
    return _dataObject(res, _bookingFromJson);
  }

  Future<void> deleteBooking(String id) async {
    await _api.delete('/dc/events/$id');
  }

  Future<void> updateBookingStatus(String id, EventStatus status) async {
    await _api.put('/dc/events/$id', body: {'status': _statusStr(status)});
  }

  Future<EventBooking> assignStaffToEvent(
    String eventId,
    List<String> staffIds,
  ) async {
    final res = await _api.put(
      '/dc/events/$eventId',
      body: {'assignedStaffIds': staffIds},
    );
    return _dataObject(res, _bookingFromJson);
  }

  Future<void> recordPayment(DcPayment payment) async {
    await _api.post(
      '/dc/events/${payment.eventId}/payments',
      body: {
        'amountPaisa': _toPaisa(payment.amount),
        'paymentMode': payment.method.name,
        'reference': payment.referenceNumber,
        'invoiceId': payment.invoiceId,
      },
    );
  }

  // ── Staff ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getStaffRaw() async {
    final res = await _api.get('/dc/staff');
    final raw = res.data?['data'];
    if (raw is! List) return [];
    return raw.cast<Map<String, dynamic>>();
  }

  Future<List<DcStaff>> getStaff({
    String? search,
    StaffRole? roleFilter,
  }) async {
    final params = <String, String>{};
    if (roleFilter != null) params['role'] = roleFilter.name;
    if (search != null && search.isNotEmpty) params['search'] = search;
    final res = await _api.get('/dc/staff', queryParams: params);
    return _dataList(res, _staffFromJson);
  }

  Future<DcStaff> createStaff(DcStaff staff) async {
    final res = await _api.post(
      '/dc/staff',
      body: {
        'name': staff.name,
        'phone': staff.phone,
        'role': staff.role.name,
        'dailyRatePaisa': _toPaisa(staff.dailyWage),
        'address': staff.address,
      },
    );
    return _dataObject(res, _staffFromJson);
  }

  Future<void> deleteStaff(String id) async {
    await _api.delete('/dc/staff/$id');
  }

  Future<void> markAttendance({
    required String date,
    required Map<String, StaffAttendance> attendance,
  }) async {
    final records = attendance.entries
        .map((e) => {'staffId': e.key, 'status': e.value.name})
        .toList();
    await _api.post(
      '/dc/staff/attendance',
      body: {'date': date, 'records': records},
    );
  }

  // ── Vendors ───────────────────────────────────────────────────────────────

  Future<List<DcVendor>> getVendors({String? search}) async {
    final params = <String, String>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final res = await _api.get('/dc/vendors', queryParams: params);
    return _dataList(res, _vendorFromJson);
  }

  Future<DcVendor> createVendor(DcVendor vendor) async {
    final res = await _api.post(
      '/dc/vendors',
      body: {
        'name': vendor.name,
        'phone': vendor.phone,
        'email': vendor.email,
        'vendorType': vendor.category,
        'address': vendor.address,
        'notes': vendor.notes,
      },
    );
    return _dataObject(res, _vendorFromJson);
  }

  Future<void> deleteVendor(String id) async {
    await _api.delete('/dc/vendors/$id');
  }

  // ── Inventory ─────────────────────────────────────────────────────────────

  Future<List<DcInventoryItem>> getInventory({
    InventoryCategory? category,
    bool lowStockOnly = false,
  }) async {
    final params = <String, String>{};
    if (category != null) params['category'] = category.name;
    if (lowStockOnly) params['lowStock'] = 'true';
    final res = await _api.get('/dc/inventory', queryParams: params);
    return _dataList(res, _inventoryFromJson);
  }

  Future<DcInventoryItem> createInventoryItem(DcInventoryItem item) async {
    final res = await _api.post(
      '/dc/inventory',
      body: {
        'name': item.name,
        'category': item.category.name,
        'unit': item.unit,
        'currentStock': item.availableQty,
        'reorderPoint': item.lowStockThreshold,
        'costPaisaPerUnit': _toPaisa(item.purchasePrice),
      },
    );
    return _dataObject(res, _inventoryFromJson);
  }

  // ────────────────────────────────────────────────────────────────────────
  // BACKEND GAP (Requirement 9.9): The backend does NOT provide an atomic
  // delta endpoint for inventory adjustment. Phase 0 Verification confirmed
  // only `PUT /dc/inventory/{id}` (absolute `currentStock`) exists.
  //
  // This method attempts `POST /dc/inventory/{id}/adjust { deltaQty }` which
  // is the correct atomic-delta contract. Until the backend implements this
  // endpoint the call will fail with 404 and this method surfaces that error
  // explicitly. There is NO silent fallback to the read-all-then-PUT pattern
  // (which was racy and violated Requirement 9.7).
  //
  // To resolve: deploy an atomic delta handler at POST /dc/inventory/{id}/adjust
  // that applies `deltaQty` atomically (DynamoDB ADD expression or equivalent).
  // ────────────────────────────────────────────────────────────────────────
  Future<void> adjustInventory(String id, int delta) async {
    final res = await _api.post(
      '/dc/inventory/$id/adjust',
      body: {'deltaQty': delta},
    );

    if (!res.isSuccess) {
      if (res.statusCode == 404) {
        // Backend gap: atomic delta endpoint not deployed.
        // Stored quantity is unchanged — no silent fallback.
        throw Exception(
          'Inventory atomic-delta endpoint not available '
          '(POST /dc/inventory/$id/adjust returned 404). '
          'BACKEND GAP: deploy an atomic delta handler. '
          'Stored quantity unchanged.',
        );
      }
      // Transient or other failure — quantity unchanged, surface the error.
      throw Exception(
        'Failed to adjust inventory for item $id: '
        '${res.error ?? 'HTTP ${res.statusCode}'}. '
        'Stored quantity unchanged.',
      );
    }
  }

  // ── Menu Items ────────────────────────────────────────────────────────────

  Future<List<CateringMenuItem>> getMenuItems({MenuCategory? category}) async {
    final params = <String, String>{};
    if (category != null) params['category'] = category.name;
    final res = await _api.get('/dc/menu', queryParams: params);
    return _dataList(res, _menuItemFromJson);
  }

  Future<CateringMenuItem> createMenuItem(CateringMenuItem item) async {
    final res = await _api.post(
      '/dc/menu',
      body: {
        'name': item.name,
        'category': item.category.name,
        'description': item.description,
        'ratePaisaPerPlate': _toPaisa(item.pricePerPlate),
      },
    );
    return _dataObject(res, _menuItemFromJson);
  }

  // ── Packages ──────────────────────────────────────────────────────────────

  Future<List<CateringPackage>> getPackages() async {
    final res = await _api.get('/dc/packages');
    return _dataList(res, _packageFromJson);
  }

  Future<CateringPackage> createPackage(CateringPackage pkg) async {
    final res = await _api.post(
      '/dc/packages',
      body: {
        'name': pkg.name,
        'description': pkg.description,
        'pricePerPlatePaisa': _toPaisa(pkg.pricePerPlate),
        'menuItemIds': pkg.menuItemIds,
        'minGuests': pkg.minGuests,
      },
    );
    return _dataObject(res, _packageFromJson);
  }

  // ── Themes ────────────────────────────────────────────────────────────────

  Future<List<DecorationTheme>> getThemes() async {
    final res = await _api.get('/dc/themes');
    return _dataList(res, _themeFromJson);
  }

  Future<DecorationTheme> createTheme(DecorationTheme theme) async {
    final res = await _api.post(
      '/dc/themes',
      body: {
        'name': theme.name,
        'category': theme.category,
        'description': theme.description,
        'baseRatePaisa': _toPaisa(theme.basePrice),
        'tags': theme.includedItems,
      },
    );
    return _dataObject(res, _themeFromJson);
  }

  // ── Expenses ──────────────────────────────────────────────────────────────

  Future<List<DcExpense>> getExpenses({
    String? eventId,
    String? from,
    String? to,
  }) async {
    final params = <String, String>{};
    if (eventId != null) params['eventId'] = eventId;
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    final res = await _api.get('/dc/expenses', queryParams: params);
    return _dataList(res, _expenseFromJson);
  }

  Future<List<Map<String, dynamic>>> getExpensesRaw({
    String? from,
    String? to,
  }) async {
    final params = <String, String>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    final res = await _api.get('/dc/expenses', queryParams: params);
    final raw = res.data?['data'];
    if (raw is! List) return [];
    return raw.cast<Map<String, dynamic>>();
  }

  Future<DcExpense> createExpense(DcExpense expense) async {
    final res = await _api.post(
      '/dc/expenses',
      body: {
        'eventId': expense.eventId,
        'category': expense.category,
        'description': expense.title,
        'amountPaisa': _toPaisa(expense.amount),
        'date': expense.date.toIso8601String().substring(0, 10),
        'paymentMode': expense.paymentMethod.name,
        'notes': expense.notes,
      },
    );
    return _dataObject(res, _expenseFromJson);
  }

  // ── Invoices ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createInvoice({
    required String eventId,
    required String customerName,
    required String customerPhone,
    required List<Map<String, dynamic>> lineItems,
    required double subtotal,
    required double discountPct,
    required double gstPct,
    required double total,
    required double advancePaid,
  }) async {
    final res = await _api.post(
      '/dc/invoices',
      body: {
        'eventId': eventId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'lineItems': lineItems,
        'subtotalPaisa': _toPaisa(subtotal),
        'discountPercent': discountPct,
        'gstPercent': gstPct,
        'totalAmountPaisa': _toPaisa(total),
        'advancePaidPaisa': _toPaisa(advancePaid),
      },
    );
    return res.data?['data'] as Map<String, dynamic>? ?? {};
  }

  Future<List<Map<String, dynamic>>> getInvoices({
    String? eventId,
    String? status,
    String? search,
    String? invoiceNumber,
    int page = 1,
    int limit = 50,
  }) async {
    final params = <String, String>{'page': '$page', 'limit': '$limit'};
    if (eventId != null) params['eventId'] = eventId;
    if (status != null) params['status'] = status;
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (invoiceNumber != null && invoiceNumber.isNotEmpty)
      params['invoiceNumber'] = invoiceNumber;
    final res = await _api.get('/dc/invoices', queryParams: params);
    final raw = res.data?['data'];
    if (raw is! List) return [];
    return raw.cast<Map<String, dynamic>>();
  }

  // ── Payments (via invoice endpoint) ───────────────────────────────────────

  Future<List<DcPayment>> getPayments({String? eventId}) async {
    final params = <String, String>{'limit': '100'};
    if (eventId != null) params['eventId'] = eventId;
    final res = await _api.get('/dc/invoices', queryParams: params);
    final raw = res.data?['data'];
    if (raw is! List) return [];
    return raw.map((e) {
      final j = e as Map<String, dynamic>;
      return DcPayment(
        id: j['id'] as String,
        eventId: j['eventId'] as String? ?? '',
        customerName: j['customerName'] as String? ?? '',
        amount: _paisa(j['advancePaidPaisa']),
        method: PaymentMethod.cash,
        date: DateTime.parse(j['createdAt'] as String),
      );
    }).toList();
  }

  // ── Quotes ────────────────────────────────────────────────────────────────

  Future<List<DcQuote>> getQuotes({String? status}) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    final res = await _api.get('/dc/quotes', queryParams: params);
    return _dataList(res, _quoteFromJson);
  }

  Future<DcQuote> createQuote(DcQuote quote) async {
    final res = await _api.post(
      '/dc/quotes',
      body: {
        'customerName': quote.customerName,
        'customerPhone': quote.customerPhone,
        'eventType': quote.eventType,
        'eventDate': quote.eventDate,
        'venue': quote.venue,
        'guestCount': quote.guestCount,
        'lineItems': quote.lineItems,
        'discountPaisa': _toPaisa(quote.discount),
        'gstPercent': quote.gstPct,
        'notes': quote.notes,
        'validUntil': quote.validUntil,
      },
    );
    return _dataObject(res, _quoteFromJson);
  }

  Future<DcQuote> updateQuoteStatus(String id, QuoteStatus status) async {
    final res = await _api.put('/dc/quotes/$id', body: {'status': status.name});
    return _dataObject(res, _quoteFromJson);
  }

  Future<void> deleteQuote(String id) async {
    await _api.delete('/dc/quotes/$id');
  }

  // ── Event Notes ───────────────────────────────────────────────────────────

  Future<List<DcEventNote>> appendEventNote(String eventId, String text) async {
    final res = await _api.post(
      '/dc/events/$eventId/notes',
      body: {'text': text},
    );
    final raw = res.data?['data']?['notesList'];
    if (raw is! List) return [];
    return raw.map((e) => _noteFromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Shopping List ─────────────────────────────────────────────────────────

  Future<({List<DcShoppingListItem> items, int guestCount, double totalCost})>
  getShoppingList(String eventId) async {
    final res = await _api.get('/dc/events/$eventId/shopping-list');
    final body = res.data?['data'] as Map<String, dynamic>? ?? {};
    final rawItems = body['items'] as List? ?? [];
    return (
      items: rawItems
          .map((e) => _shoppingItemFromJson(e as Map<String, dynamic>))
          .toList(),
      guestCount: (body['guestCount'] as num?)?.toInt() ?? 0,
      totalCost: _paisa(body['totalEstimatedCostPaisa']),
    );
  }

  // ── Profitability ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getEventProfitability(String eventId) async {
    final res = await _api.get('/dc/events/$eventId/profitability');
    final body = res.data?['data'] as Map<String, dynamic>? ?? {};
    return {
      'totalRevenue': _paisa(body['totalRevenuePaisa']),
      'totalCollected': _paisa(body['totalCollectedPaisa']),
      'totalExpenses': _paisa(body['totalExpensesPaisa']),
      'netProfit': _paisa(body['netProfitPaisa']),
      'marginPct': (body['marginPct'] as num?)?.toInt() ?? 0,
      'expenseByCategory':
          (body['expenseByCategory'] as Map<String, dynamic>? ?? {}).map(
            (k, v) => MapEntry(k, _paisa(v)),
          ),
      'invoiceCount': (body['invoiceCount'] as num?)?.toInt() ?? 0,
      'expenseCount': (body['expenseCount'] as num?)?.toInt() ?? 0,
      'customerName': body['customerName'] as String? ?? '',
      'eventDate': body['eventDate'] as String? ?? '',
      'eventEndDate': body['eventEndDate'] as String? ?? '',
      'guestCount': (body['guestCount'] as num?)?.toInt() ?? 0,
    };
  }

  // ── Vendor Payments ───────────────────────────────────────────────────────

  Future<List<DcVendorPayment>> getVendorPayments(String vendorId) async {
    final res = await _api.get('/dc/vendors/$vendorId/payments');
    return _dataList(res, _vendorPaymentFromJson);
  }

  Future<DcVendorPayment> recordVendorPayment({
    required String vendorId,
    required double amount,
    required String paymentMode,
    String? reference,
    String? eventId,
    String? notes,
  }) async {
    final res = await _api.post(
      '/dc/vendors/$vendorId/payments',
      body: {
        'amountPaisa': _toPaisa(amount),
        'paymentMode': paymentMode,
        'reference': reference,
        'eventId': eventId,
        'notes': notes,
      },
    );
    return _dataObject(res, _vendorPaymentFromJson);
  }

  // ── Dashboard Stats ───────────────────────────────────────────────────────

  Future<DcDashboardStats> getDashboardStats() async {
    final res = await _api.get('/dc/dashboard');
    final body = res.data?['data'] as Map<String, dynamic>? ?? {};
    final kpis = body['kpis'] as Map<String, dynamic>? ?? {};
    final upcoming = body['upcomingEvents'] as List? ?? [];
    final statusMap = body['statusCounts'] as Map<String, dynamic>? ?? {};
    final rawRevenueByMonth =
        body['revenueByMonth'] as Map<String, dynamic>? ?? {};
    final rawRevenueByDay = body['revenueByDay'] as Map<String, dynamic>? ?? {};
    final rawBookingsByType =
        body['eventTypeCounts'] as Map<String, dynamic>? ?? {};

    final revenueByMonth = rawRevenueByMonth.map(
      (k, v) => MapEntry(k, _paisa(v)),
    );
    final revenueByDay = rawRevenueByDay.map((k, v) => MapEntry(k, _paisa(v)));

    final bookingsByType = <EventType, int>{};
    rawBookingsByType.forEach((k, v) {
      final et = _parseEventType(k);
      bookingsByType[et] =
          (bookingsByType[et] ?? 0) + ((v as num?)?.toInt() ?? 0);
    });

    return DcDashboardStats(
      totalBookings: (kpis['totalEvents'] as num?)?.toInt() ?? 0,
      upcomingEvents: upcoming.length,
      todayEvents: (kpis['todayEvents'] as num?)?.toInt() ?? 0,
      completedEvents: (statusMap['completed'] as num?)?.toInt() ?? 0,
      totalRevenue: _paisa(kpis['revenueThisMonthPaisa']),
      pendingPayments: _paisa(kpis['pendingBalancePaisa']),
      monthlyRevenue: _paisa(kpis['revenueThisMonthPaisa']),
      monthlyExpenses: _paisa(kpis['thisMonthExpensesPaisa']),
      activeStaff: (kpis['activeStaff'] as num?)?.toInt() ?? 0,
      lowStockAlerts: (kpis['lowStockAlerts'] as num?)?.toInt() ?? 0,
      revenueByMonth: revenueByMonth,
      revenueByDay: revenueByDay,
      bookingsByType: bookingsByType,
    );
  }
}
