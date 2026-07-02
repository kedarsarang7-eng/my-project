// Business Type Configuration Engine
// Central configuration for all 8 business types
//
// Created: 2024-12-26
// Author: DukanX Team

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

import '../../models/business_type.dart';
export '../../models/business_type.dart';

/// Extension for business type display properties
extension BusinessTypeConfigExtension on BusinessType {
  String get emoji {
    switch (this) {
      case BusinessType.grocery:
        return '🛒';
      case BusinessType.restaurant:
        return '🍽️';
      case BusinessType.pharmacy:
        return '💊';
      case BusinessType.clothing:
        return '👕';
      case BusinessType.hardware:
        return '🧰';
      case BusinessType.electronics:
        return '📱';
      case BusinessType.mobileShop:
        return '📱';
      case BusinessType.computerShop:
        return '💻';
      case BusinessType.service:
        return '🧾';
      case BusinessType.petrolPump:
        return '⛽';
      case BusinessType.vegetablesBroker:
        return '🥦';
      case BusinessType.wholesale:
        return '📦';
      case BusinessType.other:
        return '🏢';
      case BusinessType.clinic:
        return '⚕️';
      case BusinessType.bookStore:
        return '📚';
      case BusinessType.jewellery:
        return '💍';
      case BusinessType.autoParts:
        return '🔧';
      case BusinessType.decorationCatering:
        return '🎪';
      case BusinessType.schoolErp:
        return '🏫';
    }
  }

  Color get primaryColor {
    switch (this) {
      case BusinessType.grocery:
        return const Color(0xFF059669); // Emerald
      case BusinessType.restaurant:
        return const Color(0xFFEA580C); // Orange
      case BusinessType.pharmacy:
        return const Color(0xFF2563EB); // Blue
      case BusinessType.clothing:
        return const Color(0xFFDB2777); // Pink
      case BusinessType.hardware:
        return const Color(0xFF475569); // Slate
      case BusinessType.electronics:
        return const Color(0xFF0891B2); // Cyan
      case BusinessType.mobileShop:
        return const Color(0xFF06B6D4); // Light Cyan
      case BusinessType.computerShop:
        return const Color(0xFF3B82F6); // Blue
      case BusinessType.service:
        return const Color(0xFF7C3AED); // Purple
      case BusinessType.petrolPump:
        return const Color(0xFFDC2626); // Red (fuel)
      case BusinessType.vegetablesBroker:
        return const Color(0xFF16A34A); // Green (vegetables)
      case BusinessType.wholesale:
        return const Color(0xFF0D9488); // Teal (distinct from grocery)
      case BusinessType.other:
        return const Color(0xFF57534E); // Stone/Gray (neutral)
      case BusinessType.clinic:
        return const Color(0xFF0EA5E9); // Sky Blue
      case BusinessType.bookStore:
        return const Color(0xFF8B5CF6); // Violet
      case BusinessType.jewellery:
        return const Color(0xFFD97706); // Amber/Gold
      case BusinessType.autoParts:
        return const Color(0xFF64748B); // Slate
      case BusinessType.decorationCatering:
        return const Color(0xFFE11D48); // Rose
      case BusinessType.schoolErp:
        return const Color(0xFF2563EB); // Blue
    }
  }

  PdfColor get pdfPrimaryColor {
    switch (this) {
      case BusinessType.grocery:
        return PdfColor.fromHex('#059669');
      case BusinessType.restaurant:
        return PdfColor.fromHex('#EA580C');
      case BusinessType.pharmacy:
        return PdfColor.fromHex('#2563EB');
      case BusinessType.clothing:
        return PdfColor.fromHex('#DB2777');
      case BusinessType.hardware:
        return PdfColor.fromHex('#475569');
      case BusinessType.electronics:
        return PdfColor.fromHex('#0891B2');
      case BusinessType.mobileShop:
        return PdfColor.fromHex('#06B6D4');
      case BusinessType.computerShop:
        return PdfColor.fromHex('#3B82F6');
      case BusinessType.service:
        return PdfColor.fromHex('#7C3AED');
      case BusinessType.petrolPump:
        return PdfColor.fromHex('#DC2626');
      case BusinessType.vegetablesBroker:
        return PdfColor.fromHex('#16A34A');
      case BusinessType.wholesale:
        return PdfColor.fromHex('#0D9488'); // Teal
      case BusinessType.other:
        return PdfColor.fromHex('#57534E'); // Stone
      case BusinessType.clinic:
        return PdfColor.fromHex('#0EA5E9');
      case BusinessType.bookStore:
        return PdfColor.fromHex('#8B5CF6');
      case BusinessType.jewellery:
        return PdfColor.fromHex('#D97706');
      case BusinessType.autoParts:
        return PdfColor.fromHex('#64748B');
      case BusinessType.decorationCatering:
        return PdfColor.fromHex('#E11D48');
      case BusinessType.schoolErp:
        return PdfColor.fromHex('#2563EB');
    }
  }
}

/// Item fields that can be shown/hidden based on business type
enum ItemField {
  // Common fields (always shown)
  itemName,
  quantity,
  unit,
  price,
  discount,
  gst,
  total,

  // Business-specific fields
  batchNo, // Pharmacy, Hardware
  expiryDate, // Pharmacy
  doctorName, // Pharmacy
  serialNo, // Electronics (IMEI)
  warrantyMonths, // Electronics
  hsnCode, // Electronics, Hardware
  size, // Clothing
  color, // Clothing
  brand, // Clothing, Electronics, Hardware
  drugSchedule, // Pharmacy
  tableNo, // Restaurant
  isParcel, // Restaurant
  isHalf, // Restaurant (half portion)
  laborCharge, // Service
  partsCharge, // Service
  notes, // Service
  weight, // Hardware
  dimensions, // Hardware
  // Petrol Pump specific
  nozzleId, // Petrol Pump
  fuelType, // Petrol Pump
  litres, // Petrol Pump
  vehicleNumber, // Petrol Pump
  // Mandi / Vegetable Broker specific
  grossWeight,
  tareWeight,
  netWeight,
  commission,
  lotId,
  marketFee,
  // Jewellery specific
  makingCharges,
  purity,
  metalWeight,
  // Book Store specific
  isbn,
  // Auto Parts specific
  vehicleModel,
}

/// Unit options available for each business type
enum UnitType {
  pcs, // Pieces (all)
  kg, // Kilograms (general, hardware)
  gm, // Grams (general, pharmacy)
  ltr, // Liters (general)
  ml, // Milliliters (pharmacy)
  mtr, // Meters (hardware, clothing)
  ft, // Feet (hardware)
  box, // Box (wholesale)
  strip, // Strip (pharmacy)
  nos, // Numbers (general)
  set, // Set (electronics, clothing)
  hr, // Hour (service)
}

extension UnitTypeExtension on UnitType {
  String get label {
    switch (this) {
      case UnitType.pcs:
        return 'Pcs';
      case UnitType.kg:
        return 'Kg';
      case UnitType.gm:
        return 'Gm';
      case UnitType.ltr:
        return 'Ltr';
      case UnitType.ml:
        return 'ML';
      case UnitType.mtr:
        return 'Mtr';
      case UnitType.ft:
        return 'Ft';
      case UnitType.box:
        return 'Box';
      case UnitType.strip:
        return 'Strip';
      case UnitType.nos:
        return 'Nos';
      case UnitType.set:
        return 'Set';
      case UnitType.hr:
        return 'Hr';
    }
  }
}

/// Configuration for a business type
class BusinessTypeConfig {
  final BusinessType type;
  final List<ItemField> requiredFields;
  final List<ItemField> optionalFields;
  final double defaultGstRate;
  final bool gstEditable;
  final List<UnitType> unitOptions;
  final String itemLabel; // "Item" / "Dish" / "Medicine" etc.
  final String addItemLabel; // "Add Item" / "Add Dish" / "Add Medicine"
  final String priceLabel; // "Rate" / "MRP" / "Labor"
  final List<String>
  modules; // "inventory", "prescriptions", "sales", "returns", "kot", "tables"

  const BusinessTypeConfig({
    required this.type,
    required this.requiredFields,
    required this.optionalFields,
    required this.defaultGstRate,
    required this.gstEditable,
    required this.unitOptions,
    required this.itemLabel,
    required this.addItemLabel,
    required this.priceLabel,
    required this.modules,
  });

  /// Get all fields (required + optional)
  List<ItemField> get allFields => [...requiredFields, ...optionalFields];

  /// Check if a field should be visible
  bool hasField(ItemField field) => allFields.contains(field);

  /// Check if a field is required
  bool isRequired(ItemField field) => requiredFields.contains(field);

  /// Check if a module is enabled
  bool hasModule(String module) => modules.contains(module);
}

/// Central registry of all business type configurations
class BusinessTypeRegistry {
  static const Map<BusinessType, BusinessTypeConfig> _configs = {
    // =========================================================
    // 🛒 GENERAL STORE - Simple retail billing
    // =========================================================
    BusinessType.grocery: BusinessTypeConfig(
      type: BusinessType.grocery,
      requiredFields: [
        ItemField.itemName,
        ItemField.quantity,
        ItemField.unit,
        ItemField.price,
      ],
      optionalFields: [ItemField.discount, ItemField.gst, ItemField.brand],
      defaultGstRate: 0.0, // Optional GST
      gstEditable: true,
      unitOptions: [
        UnitType.pcs,
        UnitType.kg,
        UnitType.gm,
        UnitType.ltr,
        UnitType.nos,
      ],
      itemLabel: 'Item',
      addItemLabel: 'Add Item',
      priceLabel: 'Rate',
      modules: ['inventory', 'sales', 'returns', 'expenses', 'reports'],
    ),

    // =========================================================
    // 🍽️ RESTAURANT - Food service billing
    // =========================================================
    BusinessType.restaurant: BusinessTypeConfig(
      type: BusinessType.restaurant,
      requiredFields: [ItemField.itemName, ItemField.quantity, ItemField.price],
      optionalFields: [ItemField.isHalf, ItemField.tableNo, ItemField.isParcel],
      defaultGstRate: 5.0, // Fixed 5% for restaurants (no ITC)
      gstEditable: false,
      unitOptions: [UnitType.pcs, UnitType.nos],
      itemLabel: 'Dish',
      addItemLabel: 'Add Dish',
      priceLabel: 'Price',
      modules: ['menu', 'sales', 'kot', 'tables', 'reports'],
    ),

    // =========================================================
    // 💊 PHARMACY - Medicine billing with batch/expiry
    // =========================================================
    BusinessType.pharmacy: BusinessTypeConfig(
      type: BusinessType.pharmacy,
      requiredFields: [
        ItemField.itemName,
        ItemField.quantity,
        ItemField.price,
        ItemField.batchNo,
        ItemField.expiryDate,
        ItemField.drugSchedule,
      ],
      optionalFields: [ItemField.doctorName, ItemField.hsnCode],
      defaultGstRate: 12.0, // Common for medicines (varies by item)
      gstEditable: false, // GST is per-item based on schedule
      unitOptions: [
        UnitType.pcs,
        UnitType.strip,
        UnitType.ml,
        UnitType.gm,
        UnitType.box,
      ],
      itemLabel: 'Medicine',
      addItemLabel: 'Add Medicine',
      priceLabel: 'MRP',
      modules: [
        'inventory',
        'prescriptions',
        'sales',
        'returns',
        'suppliers',
        'reports',
      ],
    ),

    // =========================================================
    // 👕 CLOTHING - Fashion with size/color
    // =========================================================
    BusinessType.clothing: BusinessTypeConfig(
      type: BusinessType.clothing,
      requiredFields: [
        ItemField.itemName,
        ItemField.quantity,
        ItemField.price,
        ItemField.size,
      ],
      optionalFields: [
        ItemField.color,
        ItemField.brand,
        ItemField.discount,
        ItemField.gst,
      ],
      defaultGstRate: 5.0, // 5% for items < ₹1000, 12% for > ₹1000
      gstEditable: true,
      unitOptions: [UnitType.pcs, UnitType.set, UnitType.mtr],
      itemLabel: 'Item',
      addItemLabel: 'Add Item',
      priceLabel: 'Price',
      modules: ['inventory', 'sales', 'returns', 'reports'],
    ),

    // =========================================================
    // 🧰 HARDWARE - Construction materials
    // =========================================================
    BusinessType.hardware: BusinessTypeConfig(
      type: BusinessType.hardware,
      requiredFields: [
        ItemField.itemName,
        ItemField.quantity,
        ItemField.unit,
        ItemField.price,
        ItemField.gst,
      ],
      optionalFields: [
        ItemField.brand,
        ItemField.weight,
        ItemField.dimensions,
        ItemField.hsnCode,
        ItemField.batchNo,
      ],
      defaultGstRate: 18.0, // Most hardware items
      gstEditable: true,
      unitOptions: [
        UnitType.pcs,
        UnitType.kg,
        UnitType.ft,
        UnitType.mtr,
        UnitType.box,
        UnitType.nos,
      ],
      itemLabel: 'Item',
      addItemLabel: 'Add Item',
      priceLabel: 'Rate',
      modules: ['inventory', 'sales', 'returns', 'quotations', 'reports'],
    ),

    // =========================================================
    // 📱 ELECTRONICS - With IMEI/Serial & Warranty
    // =========================================================
    BusinessType.electronics: BusinessTypeConfig(
      type: BusinessType.electronics,
      requiredFields: [
        ItemField.itemName,
        ItemField.quantity,
        ItemField.price,
        ItemField.brand,
        ItemField.hsnCode,
      ],
      optionalFields: [
        ItemField.serialNo,
        ItemField.warrantyMonths,
        ItemField.discount,
      ],
      defaultGstRate: 18.0, // Fixed 18% for electronics
      gstEditable: false,
      unitOptions: [UnitType.pcs, UnitType.set, UnitType.nos],
      itemLabel: 'Product',
      addItemLabel: 'Add Product',
      priceLabel: 'MRP',
      modules: ['inventory', 'sales', 'returns', 'warranty', 'reports'],
    ),

    // =========================================================
    // 📱 MOBILE SHOP - Specialized for mobile phones
    // Full IMEI tracking, service jobs, warranty management
    // =========================================================
    BusinessType.mobileShop: BusinessTypeConfig(
      type: BusinessType.mobileShop,
      requiredFields: [
        ItemField.itemName,
        ItemField.quantity,
        ItemField.price,
        ItemField.brand,
        ItemField.serialNo, // IMEI is required for mobile shop
        ItemField.hsnCode,
      ],
      optionalFields: [
        ItemField.warrantyMonths,
        ItemField.color,
        ItemField.discount,
      ],
      defaultGstRate: 18.0, // Fixed 18% for mobiles
      gstEditable: false,
      unitOptions: [UnitType.pcs, UnitType.set, UnitType.nos],
      itemLabel: 'Mobile',
      addItemLabel: 'Add Mobile',
      priceLabel: 'MRP',
      modules: ['inventory', 'sales', 'repairs', 'second_hand', 'reports'],
    ),

    // =========================================================
    // 💻 COMPUTER SHOP - Specialized for computers/laptops
    // Serial tracking, service jobs, warranty management
    // =========================================================
    BusinessType.computerShop: BusinessTypeConfig(
      type: BusinessType.computerShop,
      requiredFields: [
        ItemField.itemName,
        ItemField.quantity,
        ItemField.price,
        ItemField.brand,
        ItemField.hsnCode,
      ],
      optionalFields: [
        ItemField.serialNo,
        ItemField.warrantyMonths,
        ItemField.discount,
        ItemField.notes, // For specs like RAM/Storage
      ],
      defaultGstRate: 18.0, // Fixed 18% for computers
      gstEditable: false,
      unitOptions: [UnitType.pcs, UnitType.set, UnitType.nos],
      itemLabel: 'Product',
      addItemLabel: 'Add Product',
      priceLabel: 'MRP',
      modules: ['inventory', 'sales', 'repairs', 'custom_builds', 'reports'],
    ),

    // =========================================================
    // 🧾 SERVICE - Labor + Parts billing
    // =========================================================
    BusinessType.service: BusinessTypeConfig(
      type: BusinessType.service,
      requiredFields: [ItemField.itemName, ItemField.laborCharge],
      optionalFields: [ItemField.partsCharge, ItemField.notes, ItemField.gst],
      defaultGstRate: 18.0, // Services at 18%
      gstEditable: true,
      unitOptions: [UnitType.pcs, UnitType.hr, UnitType.nos],
      itemLabel: 'Service',
      addItemLabel: 'Add Service',
      priceLabel: 'Labor',
      modules: ['jobs', 'invoices', 'customers', 'reports'],
    ),

    // =========================================================
    // ⛽ PETROL PUMP - Fuel station billing
    // =========================================================
    BusinessType.petrolPump: BusinessTypeConfig(
      type: BusinessType.petrolPump,
      requiredFields: [ItemField.itemName, ItemField.quantity, ItemField.price],
      optionalFields: [
        ItemField.nozzleId,
        ItemField.fuelType,
        ItemField.litres,
        ItemField.vehicleNumber,
        ItemField.gst,
      ],
      defaultGstRate:
          0.0, // Petrol/diesel are outside the GST regime (state VAT/excise handled in merchant accounting) — fuel GST is 0
      gstEditable: false,
      unitOptions: [UnitType.ltr, UnitType.kg],
      itemLabel: 'Fuel',
      addItemLabel: 'Add Fuel',
      priceLabel: 'Rate/Ltr',
      modules: ['inventory', 'sales', 'shifts', 'reading', 'reports'],
    ),

    // =========================================================
    // 🥦 VEGETABLES BROKER - Mandi Billing
    // =========================================================
    BusinessType.vegetablesBroker: BusinessTypeConfig(
      type: BusinessType.vegetablesBroker,
      requiredFields: [
        ItemField.itemName,
        ItemField.quantity, // Acts as Net Weight usually or crates count
        ItemField.netWeight,
        ItemField.price,
      ],
      optionalFields: [
        ItemField.grossWeight,
        ItemField.tareWeight,
        ItemField.commission,
        ItemField.lotId,
        ItemField.marketFee,
        ItemField.vehicleNumber,
        ItemField.discount,
      ],
      defaultGstRate: 0.0, // Agricultural produce usually exempt
      gstEditable: false,
      unitOptions: [UnitType.kg, UnitType.pcs, UnitType.box],
      itemLabel: 'Vegetable',
      addItemLabel: 'Add Lot',
      priceLabel: 'Rate/Kg',
      modules: ['auction', 'sales', 'farmers', 'buyers', 'reports'],
    ),

    // =========================================================
    // 📦 WHOLESALE
    // =========================================================
    BusinessType.wholesale: BusinessTypeConfig(
      type: BusinessType.wholesale,
      requiredFields: [ItemField.itemName, ItemField.quantity, ItemField.price],
      optionalFields: [
        ItemField.unit,
        ItemField.discount,
        ItemField.gst,
        ItemField.hsnCode,
        ItemField.batchNo,
        ItemField.expiryDate,
      ],
      defaultGstRate: 18.0,
      gstEditable: true,
      unitOptions: [UnitType.pcs, UnitType.box, UnitType.kg],
      itemLabel: 'Product',
      addItemLabel: 'Add Product',
      priceLabel: 'Rate',
      modules: ['inventory', 'sales', 'bulk_orders', 'customers', 'reports'],
    ),

    // =========================================================
    // 🏢 OTHER
    // =========================================================
    BusinessType.other: BusinessTypeConfig(
      type: BusinessType.other,
      requiredFields: [ItemField.itemName, ItemField.quantity, ItemField.price],
      optionalFields: [ItemField.unit, ItemField.discount, ItemField.gst],
      defaultGstRate: 0.0,
      gstEditable: true,
      unitOptions: [UnitType.pcs, UnitType.kg, UnitType.ltr],
      itemLabel: 'Item',
      addItemLabel: 'Add Item',
      priceLabel: 'Price',
      modules: ['inventory', 'sales', 'reports'],
    ),

    // =========================================================
    // ⚕️ CLINIC
    // =========================================================
    BusinessType.clinic: BusinessTypeConfig(
      type: BusinessType.clinic,
      requiredFields: [ItemField.itemName, ItemField.quantity, ItemField.price],
      optionalFields: [
        ItemField.doctorName,
        ItemField.batchNo,
        ItemField.expiryDate,
        ItemField.drugSchedule,
      ],
      defaultGstRate: 0.0, // Services/Medicines
      gstEditable: true,
      unitOptions: [UnitType.pcs, UnitType.strip, UnitType.nos],
      itemLabel: 'Medicine/Service',
      addItemLabel: 'Add Med/Service',
      priceLabel: 'Charge',
      modules: [
        'appointments',
        'patients',
        'prescriptions',
        'inventory',
        'reports',
      ],
    ),

    // =========================================================
    // 📚 BOOK STORE
    // =========================================================
    BusinessType.bookStore: BusinessTypeConfig(
      type: BusinessType.bookStore,
      requiredFields: [ItemField.itemName, ItemField.quantity, ItemField.price],
      optionalFields: [
        ItemField.isbn,
        ItemField.brand,
        ItemField.discount,
        ItemField.gst,
      ],
      defaultGstRate:
          0.0, // Fallback — printed books (HSN 4901) are exempt; per-item rate resolved from HSN via BookGstResolver
      gstEditable: true,
      unitOptions: [UnitType.pcs, UnitType.set],
      itemLabel: 'Book',
      addItemLabel: 'Add Book',
      priceLabel: 'MRP',
      modules: ['inventory', 'sales', 'school_orders', 'reports'],
    ),

    // =========================================================
    // 💍 JEWELLERY SHOP
    // =========================================================
    BusinessType.jewellery: BusinessTypeConfig(
      type: BusinessType.jewellery,
      requiredFields: [
        ItemField.itemName,
        ItemField.quantity,
        ItemField.price,
        ItemField.metalWeight,
      ],
      optionalFields: [
        ItemField.makingCharges,
        ItemField.purity,
        ItemField.gst,
        ItemField.discount,
      ],
      defaultGstRate: 3.0,
      gstEditable: false,
      unitOptions: [UnitType.gm, UnitType.pcs],
      itemLabel: 'Jewellery',
      addItemLabel: 'Add Item',
      priceLabel: 'Rate/Gm',
      modules: ['inventory', 'sales', 'custom_orders', 'reports'],
    ),

    // =========================================================
    // 🔧 AUTO PARTS
    // =========================================================
    BusinessType.autoParts: BusinessTypeConfig(
      type: BusinessType.autoParts,
      requiredFields: [ItemField.itemName, ItemField.quantity, ItemField.price],
      optionalFields: [
        ItemField.vehicleModel,
        ItemField.brand,
        ItemField.hsnCode,
        ItemField.discount,
        ItemField.gst,
      ],
      defaultGstRate: 28.0,
      gstEditable: true,
      unitOptions: [UnitType.pcs, UnitType.nos, UnitType.set],
      itemLabel: 'Part',
      addItemLabel: 'Add Part',
      priceLabel: 'MRP',
      modules: ['inventory', 'sales', 'returns', 'reports'],
    ),

    // =========================================================
    // 🎪 DECORATION & CATERING
    // =========================================================
    BusinessType.decorationCatering: BusinessTypeConfig(
      type: BusinessType.decorationCatering,
      requiredFields: [ItemField.itemName, ItemField.quantity, ItemField.price],
      optionalFields: [ItemField.notes, ItemField.gst, ItemField.discount],
      defaultGstRate: 18.0,
      gstEditable: true,
      unitOptions: [UnitType.pcs, UnitType.set, UnitType.nos],
      itemLabel: 'Service/Item',
      addItemLabel: 'Add Service/Item',
      priceLabel: 'Charge',
      modules: ['events', 'sales', 'caterers', 'inventory', 'reports'],
    ),

    // =========================================================
    // 🏫 SCHOOL ERP
    // =========================================================
    BusinessType.schoolErp: BusinessTypeConfig(
      type: BusinessType.schoolErp,
      requiredFields: [ItemField.itemName, ItemField.quantity, ItemField.price],
      optionalFields: [ItemField.notes, ItemField.gst],
      defaultGstRate: 0.0,
      gstEditable: true,
      unitOptions: [UnitType.pcs, UnitType.set],
      itemLabel: 'Fee/Item',
      addItemLabel: 'Add Fee/Item',
      priceLabel: 'Amount',
      modules: ['students', 'fees', 'attendance', 'exams', 'reports'],
    ),
  };

  /// Get configuration for a business type
  static BusinessTypeConfig getConfig(BusinessType type) {
    return _configs[type] ?? _configs[BusinessType.grocery]!;
  }

  /// Get all available business types
  static List<BusinessType> get allTypes => BusinessType.values;

  /// Get config by string name (for persistence)
  static BusinessTypeConfig getConfigByName(String name) {
    final type = BusinessType.values.firstWhere(
      (t) => t.name == name || t.toString() == name,
      orElse: () => BusinessType.grocery,
    );
    return getConfig(type);
  }
}

/// Helper to convert old BusinessType enum to new one
BusinessType migrateBusinessType(String oldType) {
  switch (oldType.toLowerCase()) {
    case 'grocery':
    case 'generalstore':
    case 'businesstype.grocery':
      return BusinessType.grocery;
    case 'pharmacy':
    case 'businesstype.pharmacy':
      return BusinessType.pharmacy;
    case 'restaurant':
    case 'businesstype.restaurant':
      return BusinessType.restaurant;
    case 'hardware':
    case 'businesstype.hardware':
      return BusinessType.hardware;
    case 'service':
    case 'businesstype.service':
      return BusinessType.service;
    case 'wholesale':
    case 'businesstype.wholesale':
      return BusinessType.wholesale;
    case 'petrolpump':
    case 'petrol_pump':
    case 'businesstype.petrolpump':
      return BusinessType.petrolPump;
    case 'vegetablesbroker':
    case 'mandi':
    case 'businesstype.vegetablesbroker':
      return BusinessType.vegetablesBroker;
    default:
      return BusinessType.grocery;
  }
}
