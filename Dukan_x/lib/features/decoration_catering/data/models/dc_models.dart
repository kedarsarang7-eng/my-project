// ============================================================================
// DECORATION & CATERING — DOMAIN MODELS
// ============================================================================

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum EventStatus { inquiry, confirmed, ongoing, completed, cancelled }

enum EventType {
  wedding,
  birthday,
  corporate,
  engagement,
  babyShower,
  anniversary,
  conference,
  other,
}

enum StaffRole { decorator, cook, helper, driver, manager, waiter, supervisor }

enum StaffAttendance { present, absent, halfDay }

enum InventoryCategory {
  furniture,
  lighting,
  flowers,
  fabric,
  utensils,
  sound,
  gasItems,
  miscellaneous,
}

enum MenuCategory { veg, nonVeg, jain, dessert, beverages, custom }

enum PaymentMethod { cash, upi, card, cheque, bankTransfer }

enum PaymentStatus { pending, partial, paid, overdue }

// ---------------------------------------------------------------------------
// EventBooking
// ---------------------------------------------------------------------------

class EventBooking {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final EventType eventType;
  final String eventTitle;
  final DateTime eventDate;
  final DateTime? eventEndDate;
  final String venue;
  final String venueAddress;
  final int guestCount;
  EventStatus status;
  final double quotedAmount;
  double advancePaid;
  final String? notes;
  final DateTime createdAt;
  final String? decorationThemeId;
  final String? cateringPackageId;
  final List<String> assignedStaffIds;
  final List<String> inventoryItemIds;
  final bool includesDecoration;
  final bool includesCatering;
  final List<DcEventNote> notesList;
  final String? setupTime;
  final String? serviceStartTime;
  final String? serviceEndTime;
  final String? cleanupTime;

  EventBooking({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail = '',
    required this.eventType,
    required this.eventTitle,
    required this.eventDate,
    this.eventEndDate,
    required this.venue,
    this.venueAddress = '',
    required this.guestCount,
    this.status = EventStatus.inquiry,
    required this.quotedAmount,
    this.advancePaid = 0,
    this.notes,
    required this.createdAt,
    this.decorationThemeId,
    this.cateringPackageId,
    this.assignedStaffIds = const [],
    this.inventoryItemIds = const [],
    this.includesDecoration = true,
    this.includesCatering = true,
    this.notesList = const [],
    this.setupTime,
    this.serviceStartTime,
    this.serviceEndTime,
    this.cleanupTime,
  });

  double get balanceDue => quotedAmount - advancePaid;

  PaymentStatus get paymentStatus {
    if (advancePaid <= 0) return PaymentStatus.pending;
    if (advancePaid >= quotedAmount) return PaymentStatus.paid;
    if (eventDate.isBefore(DateTime.now()) && balanceDue > 0) {
      return PaymentStatus.overdue;
    }
    return PaymentStatus.partial;
  }

  Color get statusColor {
    switch (status) {
      case EventStatus.inquiry:
        return Colors.orange;
      case EventStatus.confirmed:
        return Colors.blue;
      case EventStatus.ongoing:
        return Colors.purple;
      case EventStatus.completed:
        return Colors.green;
      case EventStatus.cancelled:
        return Colors.red;
    }
  }

  String get statusLabel {
    switch (status) {
      case EventStatus.inquiry:
        return 'Inquiry';
      case EventStatus.confirmed:
        return 'Confirmed';
      case EventStatus.ongoing:
        return 'Ongoing';
      case EventStatus.completed:
        return 'Completed';
      case EventStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get eventTypeLabel {
    switch (eventType) {
      case EventType.wedding:
        return 'Wedding';
      case EventType.birthday:
        return 'Birthday';
      case EventType.corporate:
        return 'Corporate';
      case EventType.engagement:
        return 'Engagement';
      case EventType.babyShower:
        return 'Baby Shower';
      case EventType.anniversary:
        return 'Anniversary';
      case EventType.conference:
        return 'Conference';
      case EventType.other:
        return 'Other';
    }
  }

  EventBooking copyWith({
    EventStatus? status,
    double? advancePaid,
    String? decorationThemeId,
    String? cateringPackageId,
    List<String>? assignedStaffIds,
    List<String>? inventoryItemIds,
    List<DcEventNote>? notesList,
    String? setupTime,
    String? serviceStartTime,
    String? serviceEndTime,
    String? cleanupTime,
  }) {
    return EventBooking(
      id: id,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      eventType: eventType,
      eventTitle: eventTitle,
      eventDate: eventDate,
      eventEndDate: eventEndDate,
      venue: venue,
      venueAddress: venueAddress,
      guestCount: guestCount,
      status: status ?? this.status,
      quotedAmount: quotedAmount,
      advancePaid: advancePaid ?? this.advancePaid,
      notes: notes,
      createdAt: createdAt,
      decorationThemeId: decorationThemeId ?? this.decorationThemeId,
      cateringPackageId: cateringPackageId ?? this.cateringPackageId,
      assignedStaffIds: assignedStaffIds ?? this.assignedStaffIds,
      inventoryItemIds: inventoryItemIds ?? this.inventoryItemIds,
      includesDecoration: includesDecoration,
      includesCatering: includesCatering,
      notesList: notesList ?? this.notesList,
      setupTime: setupTime ?? this.setupTime,
      serviceStartTime: serviceStartTime ?? this.serviceStartTime,
      serviceEndTime: serviceEndTime ?? this.serviceEndTime,
      cleanupTime: cleanupTime ?? this.cleanupTime,
    );
  }
}

// ---------------------------------------------------------------------------
// DecorationTheme
// ---------------------------------------------------------------------------

class DecorationTheme {
  final String id;
  final String name;
  final String description;
  final String category; // Floral, Royal, Modern, etc.
  final double basePrice;
  final List<String> includedItems;
  final List<String> imageUrls;
  final bool isActive;
  final Color? themeColor;

  const DecorationTheme({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.basePrice,
    this.includedItems = const [],
    this.imageUrls = const [],
    this.isActive = true,
    this.themeColor,
  });
}

// ---------------------------------------------------------------------------
// CateringPackage & MenuItem
// ---------------------------------------------------------------------------

class CateringMenuItem {
  final String id;
  final String name;
  final MenuCategory category;
  final double pricePerPlate;
  final String? description;
  final bool isAvailable;

  const CateringMenuItem({
    required this.id,
    required this.name,
    required this.category,
    required this.pricePerPlate,
    this.description,
    this.isAvailable = true,
  });

  String get categoryLabel {
    switch (category) {
      case MenuCategory.veg:
        return 'Veg';
      case MenuCategory.nonVeg:
        return 'Non-Veg';
      case MenuCategory.jain:
        return 'Jain';
      case MenuCategory.dessert:
        return 'Dessert';
      case MenuCategory.beverages:
        return 'Beverages';
      case MenuCategory.custom:
        return 'Custom';
    }
  }

  Color get categoryColor {
    switch (category) {
      case MenuCategory.veg:
        return Colors.green;
      case MenuCategory.nonVeg:
        return Colors.red;
      case MenuCategory.jain:
        return Colors.orange;
      case MenuCategory.dessert:
        return Colors.pink;
      case MenuCategory.beverages:
        return Colors.blue;
      case MenuCategory.custom:
        return Colors.purple;
    }
  }
}

class CateringPackage {
  final String id;
  final String name;
  final String description;
  final double pricePerPlate;
  final int minGuests;
  final List<String> menuItemIds;
  final bool includesService;
  final bool isActive;

  const CateringPackage({
    required this.id,
    required this.name,
    required this.description,
    required this.pricePerPlate,
    required this.minGuests,
    this.menuItemIds = const [],
    this.includesService = true,
    this.isActive = true,
  });
}

// ---------------------------------------------------------------------------
// DcStaff
// ---------------------------------------------------------------------------

class DcStaff {
  final String id;
  final String name;
  final String phone;
  final StaffRole role;
  final double dailyWage;
  final bool isAvailable;
  final List<String> assignedEventIds;
  final DateTime? joinDate;
  final String? address;

  const DcStaff({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.dailyWage,
    this.isAvailable = true,
    this.assignedEventIds = const [],
    this.joinDate,
    this.address,
  });

  String get roleLabel {
    switch (role) {
      case StaffRole.decorator:
        return 'Decorator';
      case StaffRole.cook:
        return 'Cook';
      case StaffRole.helper:
        return 'Helper';
      case StaffRole.driver:
        return 'Driver';
      case StaffRole.manager:
        return 'Manager';
      case StaffRole.waiter:
        return 'Waiter';
      case StaffRole.supervisor:
        return 'Supervisor';
    }
  }

  Color get roleColor {
    switch (role) {
      case StaffRole.decorator:
        return const Color(0xFFE91E63);
      case StaffRole.cook:
        return const Color(0xFFFF5722);
      case StaffRole.helper:
        return const Color(0xFF607D8B);
      case StaffRole.driver:
        return const Color(0xFF795548);
      case StaffRole.manager:
        return const Color(0xFF2196F3);
      case StaffRole.waiter:
        return const Color(0xFF4CAF50);
      case StaffRole.supervisor:
        return const Color(0xFF9C27B0);
    }
  }
}

// ---------------------------------------------------------------------------
// DcVendor
// ---------------------------------------------------------------------------

class DcVendor {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String category; // Flowers, Tent, Lighting, Utensils, etc.
  final String? address;
  final double totalPaid;
  final double totalDue;
  final double totalExpense;
  final double rating;
  final String? notes;
  final DateTime createdAt;

  const DcVendor({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.category,
    this.address,
    this.totalPaid = 0,
    this.totalDue = 0,
    this.totalExpense = 0,
    this.rating = 0,
    this.notes,
    required this.createdAt,
  });

  double get totalBusiness => totalPaid + totalDue;
}

// ---------------------------------------------------------------------------
// DcInventoryItem
// ---------------------------------------------------------------------------

class DcInventoryItem {
  final String id;
  final String name;
  final InventoryCategory category;
  final int totalQty;
  int availableQty;
  final double purchasePrice;
  final double rentalPrice;
  final String unit;
  final int lowStockThreshold;
  final String? barcode;

  DcInventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.totalQty,
    required this.availableQty,
    required this.purchasePrice,
    required this.rentalPrice,
    this.unit = 'pcs',
    this.lowStockThreshold = 5,
    this.barcode,
  });

  bool get isLowStock => availableQty <= lowStockThreshold;

  String get categoryLabel {
    switch (category) {
      case InventoryCategory.furniture:
        return 'Furniture';
      case InventoryCategory.lighting:
        return 'Lighting';
      case InventoryCategory.flowers:
        return 'Flowers';
      case InventoryCategory.fabric:
        return 'Fabric';
      case InventoryCategory.utensils:
        return 'Utensils';
      case InventoryCategory.sound:
        return 'Sound';
      case InventoryCategory.gasItems:
        return 'Gas / Cylinders';
      case InventoryCategory.miscellaneous:
        return 'Miscellaneous';
    }
  }
}

// ---------------------------------------------------------------------------
// DcExpense
// ---------------------------------------------------------------------------

class DcExpense {
  final String id;
  final String eventId;
  final String title;
  final String category;
  final double amount;
  final PaymentMethod paymentMethod;
  final DateTime date;
  final String? vendorId;
  final String? notes;

  const DcExpense({
    required this.id,
    required this.eventId,
    required this.title,
    required this.category,
    required this.amount,
    required this.paymentMethod,
    required this.date,
    this.vendorId,
    this.notes,
  });
}

// ---------------------------------------------------------------------------
// DcPayment
// ---------------------------------------------------------------------------

class DcPayment {
  final String id;
  final String eventId;
  final String customerName;
  final double amount;
  final PaymentMethod method;
  final DateTime date;
  final String? referenceNumber;
  final String? notes;
  final String? invoiceId;

  const DcPayment({
    required this.id,
    required this.eventId,
    required this.customerName,
    required this.amount,
    required this.method,
    required this.date,
    this.referenceNumber,
    this.notes,
    this.invoiceId,
  });
}

// ---------------------------------------------------------------------------
// DcQuote
// ---------------------------------------------------------------------------

enum QuoteStatus { draft, sent, accepted, rejected }

extension QuoteStatusX on QuoteStatus {
  String get statusLabel {
    switch (this) {
      case QuoteStatus.draft:    return 'Draft';
      case QuoteStatus.sent:     return 'Sent';
      case QuoteStatus.accepted: return 'Accepted';
      case QuoteStatus.rejected: return 'Rejected';
    }
  }

  Color get statusColor {
    switch (this) {
      case QuoteStatus.draft:    return Colors.grey;
      case QuoteStatus.sent:     return Colors.blue;
      case QuoteStatus.accepted: return Colors.green;
      case QuoteStatus.rejected: return Colors.red;
    }
  }
}

class DcQuote {
  final String id;
  final String quoteNumber;
  final String customerName;
  final String customerPhone;
  final String eventType;
  final String? eventDate;
  final String? venue;
  final int guestCount;
  final List<Map<String, dynamic>> lineItems;
  final double subtotal;
  final double gstPct;
  final double gstAmount;
  final double discount;
  final double total;
  final String? notes;
  final String? validUntil;
  final QuoteStatus status;
  final DateTime createdAt;

  const DcQuote({
    required this.id,
    required this.quoteNumber,
    required this.customerName,
    required this.customerPhone,
    required this.eventType,
    this.eventDate,
    this.venue,
    this.guestCount = 0,
    this.lineItems = const [],
    required this.subtotal,
    this.gstPct = 18,
    required this.gstAmount,
    this.discount = 0,
    required this.total,
    this.notes,
    this.validUntil,
    this.status = QuoteStatus.draft,
    required this.createdAt,
  });

}

// ---------------------------------------------------------------------------
// DcEventNote
// ---------------------------------------------------------------------------

class DcEventNote {
  final String id;
  final String text;
  final DateTime createdAt;
  final String createdBy;

  const DcEventNote({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.createdBy,
  });
}

// ---------------------------------------------------------------------------
// DcShoppingListItem
// ---------------------------------------------------------------------------

class DcShoppingListItem {
  final String item;
  final double qty;
  final String unit;
  final double estimatedCost;

  const DcShoppingListItem({
    required this.item,
    required this.qty,
    required this.unit,
    required this.estimatedCost,
  });
}

// ---------------------------------------------------------------------------
// DcVendorPayment
// ---------------------------------------------------------------------------

class DcVendorPayment {
  final String id;
  final String vendorId;
  final String vendorName;
  final double amount;
  final String paymentMode;
  final String? reference;
  final String? eventId;
  final String? notes;
  final DateTime date;

  const DcVendorPayment({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.amount,
    required this.paymentMode,
    this.reference,
    this.eventId,
    this.notes,
    required this.date,
  });
}

// ---------------------------------------------------------------------------
// DcDashboardStats
// ---------------------------------------------------------------------------

class DcDashboardStats {
  final int totalBookings;
  final int upcomingEvents;
  final int todayEvents;
  final int completedEvents;
  final double totalRevenue;
  final double pendingPayments;
  final double monthlyRevenue;
  final double monthlyExpenses;
  final int activeStaff;
  final int lowStockAlerts;
  final Map<String, double> revenueByMonth;
  final Map<String, double> revenueByDay;
  final Map<EventType, int> bookingsByType;

  const DcDashboardStats({
    this.totalBookings = 0,
    this.upcomingEvents = 0,
    this.todayEvents = 0,
    this.completedEvents = 0,
    this.totalRevenue = 0,
    this.pendingPayments = 0,
    this.monthlyRevenue = 0,
    this.monthlyExpenses = 0,
    this.activeStaff = 0,
    this.lowStockAlerts = 0,
    this.revenueByMonth = const {},
    this.revenueByDay = const {},
    this.bookingsByType = const {},
  });

  double get monthlyProfit => monthlyRevenue - monthlyExpenses;
}
