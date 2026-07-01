import 'package:dukanx/core/compat/firestore_compat.dart';
import '../core/data/data_guard.dart';

class BillItem {
  String productId; // Renamed from vegId
  String productName; // Renamed from itemName/vegName
  double qty; // generic quantity
  double price; // generic price
  double total;
  bool isBold;

  // GST fields
  String unit;
  String hsn;
  double gstRate; // %
  double discount; // Amount
  double cgst; // Amount
  double sgst; // Amount
  double igst; // Amount
  bool isInterState; // true = IGST, false = CGST+SGST

  // Business-specific (nullable)
  String? batchId; // Link to ProductBatches table
  String? batchNo;
  DateTime? expiryDate;
  String? doctorName;
  String? serialNo;
  int? warrantyMonths;
  String? size;
  String? color;
  String? tableNo;
  bool? isParcel;
  bool? isHalf;
  double? laborCharge;
  double? partsCharge;
  String? notes;
  String? weight;
  String? dimensions;

  // Jewellery/Auto Parts specific fields
  String? vehicleModel;
  String? brand;
  String? purity;
  double? metalWeight;
  double? makingCharges;
  String? hallmark;

  // Hardware specific: material grade (e.g. "Fe500D"), preserved through
  // estimate→invoice conversion (bugfix 2.18).
  String? grade;

  // Petrol Pump specific fields
  String? nozzleId;
  String? dispenserId;
  String? vehicleNumber;

  // Vegetable Broker specific fields
  double? grossWeight;
  double? tareWeight;
  double? netWeight;
  double? commission;
  double? marketFee;
  String? lotId;

  // Medical Compliance
  String? drugSchedule; // H, H1, X, etc.
  String? presignedImageUrl; // S3 image url

  BillItem({
    required this.productId,
    required this.productName,
    required this.qty,
    required this.price,
    this.isBold = false,
    this.unit = 'pcs',
    this.hsn = '',
    this.gstRate = 0.0,
    this.discount = 0.0,
    this.cgst = 0.0,
    this.sgst = 0.0,
    this.igst = 0.0,
    this.isInterState = false,
    // Business-specific
    this.batchId,
    this.batchNo,
    this.expiryDate,
    this.doctorName,
    this.serialNo,
    this.warrantyMonths,
    this.size,
    this.color,
    this.tableNo,
    this.isParcel,
    this.isHalf,
    this.laborCharge,
    this.partsCharge,
    this.notes,
    this.weight,
    this.dimensions,
    this.vehicleModel,
    this.brand,
    this.purity,
    this.metalWeight,
    this.makingCharges,
    this.hallmark,
    this.grade,
    // Petrol Pump
    this.nozzleId,
    this.dispenserId,
    this.vehicleNumber,
    // Vegetable Broker
    this.grossWeight,
    this.tareWeight,
    this.netWeight,
    this.commission,
    this.marketFee,
    this.lotId,
    this.drugSchedule,
    this.presignedImageUrl,
    double? totalOverride,
  }) : total =
           totalOverride ??
           _calculateTotal(
             qty,
             price,
             discount,
             cgst,
             sgst,
             igst,
             laborCharge,
             partsCharge,
             commission,
             marketFee,
           );

  static double _calculateTotal(
    double qty,
    double price,
    double discount,
    double cgst,
    double sgst,
    double igst,
    double? laborCharge,
    double? partsCharge, [
    // Mandi additions
    double? commission,
    double? marketFee,
  ]) {
    double base = (qty * price) - discount + cgst + sgst + igst;
    if (laborCharge != null) base += laborCharge;
    if (partsCharge != null) base += partsCharge;
    if (commission != null) base += commission;
    if (marketFee != null) base += marketFee;
    return base;
  }

  // Backward compatibility getters
  String get vegId => productId;
  String get vegName => productName;
  String get itemName => productName;
  double get qtyKg => qty;
  double get pricePerKg => price;

  // Forward compatibility getters (already aligned)
  String get id => productId;
  double get quantity => qty;
  double get unitPrice => price;
  double get totalAmount => total;
  double get taxAmount => cgst + sgst + igst;
  double get taxRate => gstRate;

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'productName': productName,
    'qty': qty,
    'price': price,
    'total': total,
    'isBold': isBold,
    'unit': unit,
    'hsn': hsn,
    'gstRate': gstRate,
    'discount': discount,
    'cgst': cgst,
    'sgst': sgst,
    'igst': igst,
    'isInterState': isInterState,
    // Business-specific
    if (batchId != null) 'batchId': batchId,
    if (batchNo != null) 'batchNo': batchNo,
    if (expiryDate != null) 'expiryDate': expiryDate!.toIso8601String(),
    if (doctorName != null) 'doctorName': doctorName,
    if (serialNo != null) 'serialNo': serialNo,
    if (warrantyMonths != null) 'warrantyMonths': warrantyMonths,
    if (size != null) 'size': size,
    if (color != null) 'color': color,
    if (tableNo != null) 'tableNo': tableNo,
    if (isParcel != null) 'isParcel': isParcel,
    if (isHalf != null) 'isHalf': isHalf,
    if (laborCharge != null) 'laborCharge': laborCharge,
    if (partsCharge != null) 'partsCharge': partsCharge,
    if (notes != null) 'notes': notes,
    if (weight != null) 'weight': weight,
    if (dimensions != null) 'dimensions': dimensions,
    if (vehicleModel != null) 'vehicleModel': vehicleModel,
    if (brand != null) 'brand': brand,
    if (purity != null) 'purity': purity,
    if (metalWeight != null) 'metalWeight': metalWeight,
    if (makingCharges != null) 'makingCharges': makingCharges,
    if (hallmark != null) 'hallmark': hallmark,
    if (grade != null) 'grade': grade,
    // Petrol Pump
    if (nozzleId != null) 'nozzleId': nozzleId,
    if (dispenserId != null) 'dispenserId': dispenserId,
    if (vehicleNumber != null) 'vehicleNumber': vehicleNumber,
    // Vegetable Broker
    if (grossWeight != null) 'grossWeight': grossWeight,
    if (tareWeight != null) 'tareWeight': tareWeight,
    if (netWeight != null) 'netWeight': netWeight,
    if (commission != null) 'commission': commission,
    if (marketFee != null) 'marketFee': marketFee,
    if (lotId != null) 'lotId': lotId,
    if (drugSchedule != null) 'drugSchedule': drugSchedule,
    if (presignedImageUrl != null) 'presignedImageUrl': presignedImageUrl,
    // Legacy fields for backward compatibility
    'vegId': productId,
    'vegName': productName,
    'itemName': productName,
    'qtyKg': qty,
    'pricePerKg': price,
  };

  factory BillItem.fromMap(Map<String, dynamic> m) {
    // Handle legacy data with strict fallback
    final name = DataGuard.safeString(
      m['productName'],
      fallback: DataGuard.safeString(
        m['itemName'],
        fallback: DataGuard.safeString(m['vegName']),
      ),
    );

    final id = DataGuard.safeString(
      m['productId'],
      fallback: DataGuard.safeString(m['vegId']),
    );

    final q = DataGuard.safeDouble(m['qty'] ?? m['qtyKg']);
    final p = DataGuard.safeDouble(m['price'] ?? m['pricePerKg']);

    // Parse expiry date
    DateTime? expiry = DataGuard.safeDate(m['expiryDate']);

    return BillItem(
      productId: id,
      productName: name,
      qty: q,
      price: p,
      isBold: DataGuard.safeBool(m['isBold']),
      unit: DataGuard.safeString(m['unit'], fallback: 'pcs'),
      hsn: DataGuard.safeString(m['hsn']),
      gstRate: DataGuard.safeDouble(m['gstRate']),
      discount: DataGuard.safeDouble(m['discount']),
      cgst: DataGuard.safeDouble(m['cgst']),
      sgst: DataGuard.safeDouble(m['sgst']),
      igst: DataGuard.safeDouble(m['igst']),
      isInterState: DataGuard.safeBool(m['isInterState']),
      // Business-specific
      batchId: m['batchId']?.toString(),
      batchNo: m['batchNo']?.toString(),
      expiryDate: expiry,
      doctorName: m['doctorName']?.toString(),
      serialNo: m['serialNo']?.toString(),
      warrantyMonths: DataGuard.safeInt(m['warrantyMonths']),
      size: m['size']?.toString(),
      color: m['color']?.toString(),
      tableNo: m['tableNo']?.toString(),
      isParcel: m['isParcel'] != null
          ? DataGuard.safeBool(m['isParcel'])
          : null,
      isHalf: m['isHalf'] != null ? DataGuard.safeBool(m['isHalf']) : null,
      laborCharge: m['laborCharge'] != null
          ? DataGuard.safeDouble(m['laborCharge'])
          : null,
      partsCharge: m['partsCharge'] != null
          ? DataGuard.safeDouble(m['partsCharge'])
          : null,
      notes: m['notes']?.toString(),
      weight: m['weight']?.toString(),
      dimensions: m['dimensions']?.toString(),
      vehicleModel: m['vehicleModel']?.toString(),
      brand: m['brand']?.toString(),
      purity: m['purity']?.toString(),
      metalWeight: m['metalWeight'] != null
          ? DataGuard.safeDouble(m['metalWeight'])
          : null,
      makingCharges: m['makingCharges'] != null
          ? DataGuard.safeDouble(m['makingCharges'])
          : null,
      hallmark: m['hallmark']?.toString(),
      grade: m['grade']?.toString(),
      // Petrol Pump
      nozzleId: m['nozzleId']?.toString(),
      dispenserId: m['dispenserId']?.toString(),
      vehicleNumber: m['vehicleNumber']?.toString(),
      // Vegetable Broker
      grossWeight: m['grossWeight'] != null
          ? DataGuard.safeDouble(m['grossWeight'])
          : null,
      tareWeight: m['tareWeight'] != null
          ? DataGuard.safeDouble(m['tareWeight'])
          : null,
      netWeight: m['netWeight'] != null
          ? DataGuard.safeDouble(m['netWeight'])
          : null,
      commission: m['commission'] != null
          ? DataGuard.safeDouble(m['commission'])
          : null,
      marketFee: m['marketFee'] != null
          ? DataGuard.safeDouble(m['marketFee'])
          : null,
      lotId: m['lotId']?.toString(),
      drugSchedule: m['drugSchedule']?.toString(),
      presignedImageUrl: m['presignedImageUrl']?.toString(),
    );
  }

  BillItem copyWith({
    String? productId,
    String? productName,
    double? qty,
    double? price,
    bool? isBold,
    String? unit,
    String? hsn,
    double? gstRate,
    double? discount,
    double? cgst,
    double? sgst,
    double? igst,
    bool? isInterState,
    // Business-specific (use Object? to allow null clearing)
    Object? batchId = const _Unset(),
    Object? batchNo = const _Unset(),
    Object? expiryDate = const _Unset(),
    Object? doctorName = const _Unset(),
    Object? serialNo = const _Unset(),
    Object? warrantyMonths = const _Unset(),
    Object? size = const _Unset(),
    Object? color = const _Unset(),
    Object? tableNo = const _Unset(),
    Object? isParcel = const _Unset(),
    Object? isHalf = const _Unset(),
    Object? laborCharge = const _Unset(),
    Object? partsCharge = const _Unset(),
    Object? notes = const _Unset(),
    Object? weight = const _Unset(),
    Object? dimensions = const _Unset(),
    Object? vehicleModel = const _Unset(),
    Object? brand = const _Unset(),
    Object? purity = const _Unset(),
    Object? metalWeight = const _Unset(),
    Object? makingCharges = const _Unset(),
    Object? hallmark = const _Unset(),
    Object? grade = const _Unset(),
    // Petrol Pump
    Object? nozzleId = const _Unset(),
    Object? dispenserId = const _Unset(),
    Object? vehicleNumber = const _Unset(),
    // Vegetable Broker
    Object? grossWeight = const _Unset(),
    Object? tareWeight = const _Unset(),
    Object? netWeight = const _Unset(),
    Object? commission = const _Unset(),
    Object? marketFee = const _Unset(),
    Object? lotId = const _Unset(),
    Object? drugSchedule = const _Unset(),
    Object? presignedImageUrl = const _Unset(),
    // Legacy support for copyWith (optional, maps to new fields)
    String? vegId,
    String? itemName,
    Object? total = const _Unset(),
  }) {
    return BillItem(
      productId: productId ?? vegId ?? this.productId,
      productName: productName ?? itemName ?? this.productName,
      qty: qty ?? this.qty,
      price: price ?? this.price,
      isBold: isBold ?? this.isBold,
      unit: unit ?? this.unit,
      hsn: hsn ?? this.hsn,
      gstRate: gstRate ?? this.gstRate,
      discount: discount ?? this.discount,
      cgst: cgst ?? this.cgst,
      sgst: sgst ?? this.sgst,
      igst: igst ?? this.igst,
      isInterState: isInterState ?? this.isInterState,
      // Business-specific
      batchId: batchId is _Unset ? this.batchId : batchId as String?,
      batchNo: batchNo is _Unset ? this.batchNo : batchNo as String?,
      expiryDate: expiryDate is _Unset
          ? this.expiryDate
          : expiryDate as DateTime?,
      doctorName: doctorName is _Unset
          ? this.doctorName
          : doctorName as String?,
      serialNo: serialNo is _Unset ? this.serialNo : serialNo as String?,
      warrantyMonths: warrantyMonths is _Unset
          ? this.warrantyMonths
          : warrantyMonths as int?,
      size: size is _Unset ? this.size : size as String?,
      color: color is _Unset ? this.color : color as String?,
      tableNo: tableNo is _Unset ? this.tableNo : tableNo as String?,
      isParcel: isParcel is _Unset ? this.isParcel : isParcel as bool?,
      isHalf: isHalf is _Unset ? this.isHalf : isHalf as bool?,
      laborCharge: laborCharge is _Unset
          ? this.laborCharge
          : laborCharge as double?,
      partsCharge: partsCharge is _Unset
          ? this.partsCharge
          : partsCharge as double?,
      notes: notes is _Unset ? this.notes : notes as String?,
      weight: weight is _Unset ? this.weight : weight as String?,
      dimensions: dimensions is _Unset
          ? this.dimensions
          : dimensions as String?,
      vehicleModel: vehicleModel is _Unset
          ? this.vehicleModel
          : vehicleModel as String?,
      brand: brand is _Unset ? this.brand : brand as String?,
      purity: purity is _Unset ? this.purity : purity as String?,
      metalWeight: metalWeight is _Unset
          ? this.metalWeight
          : metalWeight as double?,
      makingCharges: makingCharges is _Unset
          ? this.makingCharges
          : makingCharges as double?,
      hallmark: hallmark is _Unset ? this.hallmark : hallmark as String?,
      grade: grade is _Unset ? this.grade : grade as String?,
      // Petrol Pump
      nozzleId: nozzleId is _Unset ? this.nozzleId : nozzleId as String?,
      dispenserId: dispenserId is _Unset
          ? this.dispenserId
          : dispenserId as String?,
      vehicleNumber: vehicleNumber is _Unset
          ? this.vehicleNumber
          : vehicleNumber as String?,
      // Vegetable Broker
      grossWeight: grossWeight is _Unset
          ? this.grossWeight
          : grossWeight as double?,
      tareWeight: tareWeight is _Unset
          ? this.tareWeight
          : tareWeight as double?,
      netWeight: netWeight is _Unset ? this.netWeight : netWeight as double?,
      commission: commission is _Unset
          ? this.commission
          : commission as double?,
      marketFee: marketFee is _Unset ? this.marketFee : marketFee as double?,
      lotId: lotId is _Unset ? this.lotId : lotId as String?,
      drugSchedule: drugSchedule is _Unset
          ? this.drugSchedule
          : drugSchedule as String?,
      presignedImageUrl: presignedImageUrl is _Unset
          ? this.presignedImageUrl
          : presignedImageUrl as String?,
      totalOverride: total is _Unset ? null : total as double?,
    );
  }
}

/// Sentinel class for copyWith nullable fields
class _Unset {
  const _Unset();
}

class Bill {
  String id;
  String invoiceNumber;
  String customerId;
  String customerName;
  String customerPhone;
  String customerAddress;
  String customerGst;
  String? customerEmail;
  DateTime date;
  List<BillItem> items;
  double subtotal; // Before tax
  double totalTax; // New
  double
  grandTotal; // New (replaces subtotal in some contexts, or subtotal is final)
  double paidAmount;
  double cashPaid;
  double onlinePaid;
  String status; // Paid, Unpaid, Partial
  String paymentType; // Cash, Online
  double discountApplied; // Bill level discount
  double marketTicket;
  String ownerId;

  // Vendor Snapshot (New)
  String shopName;
  String shopAddress;
  String shopGst;
  String shopContact;
  String source;
  String? deliveryChallanId; // New: Link to Delivery Challan

  // Petrol Pump: Link to active shift for reconciliation
  // FRAUD PREVENTION: Every fuel sale must belong to exactly one shift
  // FRAUD PREVENTION: Every fuel sale must belong to exactly one shift
  String? shiftId;

  // Medical: Link to Doctor Prescription
  String? prescriptionId;
  String? visitId; // New: Link to Visit

  // Restaurant
  String? tableNumber;
  String? waiterId;
  String? kotId;

  // Petrol Pump
  String? vehicleNumber;
  String? driverName;
  String? attendantId;
  String? fuelType;
  double? pumpReadingStart;
  double? pumpReadingEnd;

  // Mandi
  String? brokerId;
  double marketCess;
  double commissionAmount;

  // GST: Inter-state flag (IGST vs CGST+SGST)
  bool isInterState;

  // Business Type (for adaptive UI/PDF)
  String businessType; // Stores type at bill creation
  double serviceCharge; // Restaurant service charge
  double tipAmount; // Restaurant tip (not taxable, not included in GST)
  DateTime? updatedAt; // Last update time

  // Fraud Prevention: Bill Locking
  int printCount; // How many times printed/shared

  // Data Isolation
  String? businessId; // New: Partition data by business

  bool get isLocked =>
      printCount > 0 ||
      (paidAmount > 0 && status != 'Draft') ||
      status == 'Paid';
  bool get isEditable => !isLocked;

  Bill({
    required this.id,
    this.invoiceNumber = '',
    required this.customerId,
    this.customerName = '',
    this.customerPhone = '',
    this.customerAddress = '',
    this.customerGst = '',
    this.customerEmail,
    required this.date,
    required this.items,
    this.subtotal = 0.0,
    this.totalTax = 0.0,
    this.grandTotal = 0.0,
    this.paidAmount = 0.0,
    this.cashPaid = 0.0,
    this.onlinePaid = 0.0,
    this.status = 'Unpaid',
    this.paymentType = 'Cash',
    this.discountApplied = 0.0,
    this.marketTicket = 0.0,
    this.ownerId = '',
    this.shopName = '',
    this.shopAddress = '',
    this.shopGst = '',
    this.shopContact = '',
    this.source = 'MANUAL',
    this.deliveryChallanId,
    this.shiftId,
    this.prescriptionId,
    this.visitId, // New: Link to Visit for consultation billing
    this.isInterState = false,
    this.businessType = 'grocery',
    this.serviceCharge = 0.0,
    this.tipAmount = 0.0,
    this.updatedAt,
    this.printCount = 0,
    this.businessId,
    // Restaurant
    this.tableNumber,
    this.waiterId,
    this.kotId,
    // Petrol Pump
    this.vehicleNumber,
    this.driverName,
    this.attendantId,
    this.fuelType,
    this.pumpReadingStart,
    this.pumpReadingEnd,
    // Mandi
    this.brokerId,
    this.marketCess = 0.0,
    this.commissionAmount = 0.0,
  });

  double get pendingAmount =>
      (grandTotal - paidAmount).clamp(0, double.infinity);
  bool get isPaid => pendingAmount <= 0.01;

  double get totalDiscount =>
      discountApplied + items.fold(0.0, (prev, item) => prev + item.discount);

  // Backward compatibility getter
  DateTime get billDate => date;
  String get paymentMode => paymentType;

  // FIX (M-05): Sync status now checks the sync engine via callback.
  // Set Bill.syncChecker to your sync engine's status check function.
  static bool Function(String billId)? syncChecker;
  bool get isSynced => syncChecker?.call(id) ?? true;

  // FIX (M-03): Use mutable list instead of const to allow adding items.
  factory Bill.empty() =>
      Bill(id: '', customerId: '', date: DateTime.now(), items: <BillItem>[]);

  Map<String, dynamic> toMap() => {
    'invoiceNumber': invoiceNumber,
    'customerId': customerId,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'customerAddress': customerAddress,
    'customerGst': customerGst,
    if (customerEmail != null) 'customerEmail': customerEmail,
    'date': date.toIso8601String(),
    'items': items.map((e) => e.toMap()).toList(),
    'subtotal': subtotal,
    'totalTax': totalTax,
    'grandTotal': grandTotal,
    'paidAmount': paidAmount,
    'cashPaid': cashPaid,
    'onlinePaid': onlinePaid,
    'status': status,
    'paymentType': paymentType,
    'discountApplied': discountApplied,
    'marketTicket': marketTicket,
    'ownerId': ownerId,
    'shopName': shopName,
    'shopAddress': shopAddress,
    'shopGst': shopGst,
    'shopContact': shopContact,
    'source': source,
    'deliveryChallanId': deliveryChallanId,
    'shiftId': shiftId,
    'prescriptionId': prescriptionId,
    'visitId': visitId,
    'businessType': businessType,
    'serviceCharge': serviceCharge,
    if (tipAmount > 0) 'tipAmount': tipAmount,
    'isInterState': isInterState,
    'printCount': printCount,
    if (businessId != null) 'businessId': businessId,
    // Restaurant
    if (tableNumber != null) 'tableNumber': tableNumber,
    if (waiterId != null) 'waiterId': waiterId,
    if (kotId != null) 'kotId': kotId,
    // Petrol Pump
    if (vehicleNumber != null) 'vehicleNumber': vehicleNumber,
    if (driverName != null) 'driverName': driverName,
    if (attendantId != null) 'attendantId': attendantId,
    if (fuelType != null) 'fuelType': fuelType,
    if (pumpReadingStart != null) 'pumpReadingStart': pumpReadingStart,
    if (pumpReadingEnd != null) 'pumpReadingEnd': pumpReadingEnd,
    // Mandi
    if (brokerId != null) 'brokerId': brokerId,
    if (marketCess > 0) 'marketCess': marketCess,
    if (commissionAmount > 0) 'commissionAmount': commissionAmount,
  };

  factory Bill.fromMap(String id, Map<String, dynamic> m) {
    final itemsRaw = DataGuard.safeList(m['items']);
    final items = itemsRaw.map((item) {
      final itemMap = item is Map
          ? Map<String, dynamic>.from(item)
          : <String, dynamic>{};
      return BillItem.fromMap(itemMap);
    }).toList();

    // Handle backward compatibility for subtotal/grandTotal
    double sub = DataGuard.safeDouble(m['subtotal']);
    double grand = DataGuard.safeDouble(m['grandTotal']);
    if (grand == 0 && sub > 0) {
      grand = sub; // Legacy bills had subtotal as final amount
    }

    return Bill(
      id: id,
      invoiceNumber: DataGuard.safeString(m['invoiceNumber']),
      customerId: DataGuard.safeString(m['customerId']),
      customerName: DataGuard.safeString(m['customerName']),
      customerPhone: DataGuard.safeString(m['customerPhone']),
      customerAddress: DataGuard.safeString(m['customerAddress']),
      customerGst: DataGuard.safeString(m['customerGst']),
      customerEmail: DataGuard.safeString(m['customerEmail']).isEmpty
          ? null
          : DataGuard.safeString(m['customerEmail']),
      date: _coerceDate(m['date']),
      items: items,
      subtotal: sub,
      totalTax: DataGuard.safeDouble(m['totalTax']),
      grandTotal: grand,
      paidAmount: DataGuard.safeDouble(m['paidAmount']),
      cashPaid: DataGuard.safeDouble(m['cashPaid']),
      onlinePaid: DataGuard.safeDouble(m['onlinePaid']),
      status: DataGuard.safeString(m['status'], fallback: 'Unpaid'),
      paymentType: DataGuard.safeString(m['paymentType'], fallback: 'Cash'),
      discountApplied: DataGuard.safeDouble(m['discountApplied']),
      marketTicket: DataGuard.safeDouble(m['marketTicket']),
      ownerId: DataGuard.safeString(m['ownerId']),
      shopName: DataGuard.safeString(m['shopName']),
      shopAddress: DataGuard.safeString(m['shopAddress']),
      shopGst: DataGuard.safeString(m['shopGst']),
      shopContact: DataGuard.safeString(m['shopContact']),
      source: DataGuard.safeString(m['source'], fallback: 'MANUAL'),
      deliveryChallanId: m['deliveryChallanId']?.toString(),
      shiftId: m['shiftId']?.toString(),
      prescriptionId: m['prescriptionId']?.toString(),
      visitId: m['visitId']?.toString(),
      businessType: DataGuard.safeString(
        m['businessType'],
        fallback: 'grocery',
      ),
      serviceCharge: DataGuard.safeDouble(m['serviceCharge']),
      tipAmount: DataGuard.safeDouble(m['tipAmount']),
      isInterState: DataGuard.safeBool(m['isInterState']),
      printCount: DataGuard.safeInt(m['printCount']),
      businessId: m['businessId']?.toString(),
      // Restaurant
      tableNumber: m['tableNumber']?.toString(),
      waiterId: m['waiterId']?.toString(),
      kotId: m['kotId']?.toString(),
      // Petrol Pump
      vehicleNumber: m['vehicleNumber']?.toString(),
      driverName: m['driverName']?.toString(),
      attendantId: m['attendantId']?.toString(),
      fuelType: m['fuelType']?.toString(),
      pumpReadingStart: DataGuard.safeDouble(m['pumpReadingStart']),
      pumpReadingEnd: DataGuard.safeDouble(m['pumpReadingEnd']),
      // Mandi
      brokerId: m['brokerId']?.toString(),
      marketCess: DataGuard.safeDouble(m['marketCess']),
      commissionAmount: DataGuard.safeDouble(m['commissionAmount']),
    ).sanitized();
  }

  Bill copyWith({
    String? id,
    String? invoiceNumber,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    String? customerGst,
    Object? customerEmail = const _Unset(),
    DateTime? date,
    List<BillItem>? items,
    double? subtotal,
    double? totalTax,
    double? grandTotal,
    double? paidAmount,
    double? cashPaid,
    double? onlinePaid,
    String? status,
    String? paymentType,
    double? discountApplied,
    double? marketTicket,
    String? ownerId,
    String? shopName,
    String? shopAddress,
    String? shopGst,
    String? shopContact,
    String? source,
    String? deliveryChallanId,
    String? shiftId,
    String? prescriptionId,
    String? visitId,
    String? businessType,
    double? serviceCharge,
    double? tipAmount,
    bool? isInterState,
    int? printCount,
    Object? businessId = const _Unset(),
    // Restaurant
    Object? tableNumber = const _Unset(),
    Object? waiterId = const _Unset(),
    Object? kotId = const _Unset(),
    // Petrol Pump
    Object? vehicleNumber = const _Unset(),
    Object? driverName = const _Unset(),
    Object? attendantId = const _Unset(),
    Object? fuelType = const _Unset(),
    Object? pumpReadingStart = const _Unset(),
    Object? pumpReadingEnd = const _Unset(),
    // Mandi
    Object? brokerId = const _Unset(),
    Object? marketCess = const _Unset(),
    Object? commissionAmount = const _Unset(),
  }) {
    return Bill(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      customerGst: customerGst ?? this.customerGst,
      customerEmail: customerEmail is _Unset
          ? this.customerEmail
          : customerEmail as String?,
      date: date ?? this.date,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      totalTax: totalTax ?? this.totalTax,
      grandTotal: grandTotal ?? this.grandTotal,
      paidAmount: paidAmount ?? this.paidAmount,
      cashPaid: cashPaid ?? this.cashPaid,
      onlinePaid: onlinePaid ?? this.onlinePaid,
      status: status ?? this.status,
      paymentType: paymentType ?? this.paymentType,
      discountApplied: discountApplied ?? this.discountApplied,
      marketTicket: marketTicket ?? this.marketTicket,
      ownerId: ownerId ?? this.ownerId,
      shopName: shopName ?? this.shopName,
      shopAddress: shopAddress ?? this.shopAddress,
      shopGst: shopGst ?? this.shopGst,
      shopContact: shopContact ?? this.shopContact,
      source: source ?? this.source,
      deliveryChallanId: deliveryChallanId ?? this.deliveryChallanId,
      shiftId: shiftId ?? this.shiftId,
      prescriptionId: prescriptionId ?? this.prescriptionId,
      visitId: visitId ?? this.visitId,
      businessType: businessType ?? this.businessType,
      serviceCharge: serviceCharge ?? this.serviceCharge,
      tipAmount: tipAmount ?? this.tipAmount,
      isInterState: isInterState ?? this.isInterState,
      printCount: printCount ?? this.printCount,
      businessId: businessId is _Unset
          ? this.businessId
          : businessId as String?,
      // Restaurant
      tableNumber: tableNumber is _Unset
          ? this.tableNumber
          : tableNumber as String?,
      waiterId: waiterId is _Unset ? this.waiterId : waiterId as String?,
      kotId: kotId is _Unset ? this.kotId : kotId as String?,
      // Petrol Pump
      vehicleNumber: vehicleNumber is _Unset
          ? this.vehicleNumber
          : vehicleNumber as String?,
      driverName: driverName is _Unset
          ? this.driverName
          : driverName as String?,
      attendantId: attendantId is _Unset
          ? this.attendantId
          : attendantId as String?,
      fuelType: fuelType is _Unset ? this.fuelType : fuelType as String?,
      pumpReadingStart: pumpReadingStart is _Unset
          ? this.pumpReadingStart
          : pumpReadingStart as double?,
      pumpReadingEnd: pumpReadingEnd is _Unset
          ? this.pumpReadingEnd
          : pumpReadingEnd as double?,
      // Mandi
      brokerId: brokerId is _Unset ? this.brokerId : brokerId as String?,
      marketCess: marketCess is _Unset
          ? this.marketCess
          : (marketCess as double? ?? 0.0),
      commissionAmount: commissionAmount is _Unset
          ? this.commissionAmount
          : (commissionAmount as double? ?? 0.0),
    );
  }

  Bill sanitized() {
    double roundTo(num value, int precision) =>
        double.parse(value.toStringAsFixed(precision));
    double ensureNonNegative(double value) =>
        value.isFinite ? (value < 0 ? 0 : value) : 0;

    final safeItems = items
        .where(
          (item) =>
              item.productName.trim().isNotEmpty &&
              item.qty > 0 &&
              item.price >= 0,
        )
        .map(
          (item) => item.copyWith(
            productName: item.productName.trim(),
            qty: roundTo(item.qty, 3),
            price: roundTo(item.price, 2),
          ),
        )
        .toList();

    // Recalculate totals based on items
    // Note: This logic assumes items have correct totals including tax/discount
    // Ideally we should recalculate item totals here too, but for now we trust the item.total

    // However, for consistency, let's just use the passed values but ensure they are safe
    // Or we can recalculate grandTotal from items if we want to be strict.
    // Given the complexity of tax/discount, let's trust the passed values but clamp them.

    final safeGrandTotal = roundTo(ensureNonNegative(grandTotal), 2);
    final safePaid = roundTo(
      ensureNonNegative(paidAmount).clamp(0, safeGrandTotal),
      2,
    );
    final safeCash = roundTo(ensureNonNegative(cashPaid).clamp(0, safePaid), 2);
    final remainingForOnline = (safePaid - safeCash).clamp(0, safePaid);
    final safeOnline = roundTo(
      ensureNonNegative(onlinePaid).clamp(0, remainingForOnline),
      2,
    );

    return copyWith(
      invoiceNumber: invoiceNumber.trim(),
      customerName: customerName.trim(),
      items: safeItems,
      grandTotal: safeGrandTotal,
      paidAmount: safePaid,
      cashPaid: safeCash,
      onlinePaid: safeOnline,
      status: _deriveStatus(safePaid, safeGrandTotal),
      paymentType: _derivePaymentType(safeCash, safeOnline, paymentType),
      ownerId: ownerId.trim(),
    );
  }

  static String _deriveStatus(double paid, double total) {
    if (total <= 0) return 'Unpaid';
    if ((total - paid).abs() <= 0.01) return 'Paid';
    if (paid <= 0) return 'Unpaid';
    return 'Partial';
  }

  static String _derivePaymentType(
    double cash,
    double online,
    String fallback,
  ) {
    if (cash > 0 && online > 0) return 'Mixed';
    if (cash > 0) return 'Cash';
    if (online > 0) return 'Online';
    return fallback.isNotEmpty ? fallback : 'Cash';
  }

  static DateTime _coerceDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is int) {
      final isSeconds = raw.toString().length <= 10;
      return DateTime.fromMillisecondsSinceEpoch(
        isSeconds ? raw * 1000 : raw,
        isUtc: false,
      );
    }
    if (raw is double) {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt(), isUtc: false);
    }
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw) ?? DateTime.now();
    }
    return DateTime.now();
  }
}
