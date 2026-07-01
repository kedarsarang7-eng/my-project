import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../core/di/service_locator.dart';
import '../models/models.dart';

/// GST Repository for managing GST settings, invoice details, and HSN codes
class GstRepository {
  final AppDatabase _db;

  GstRepository({AppDatabase? db}) : _db = db ?? sl<AppDatabase>();

  // ============================================================================
  // GST SETTINGS
  // ============================================================================

  /// Get GST settings for a user
  Future<GstSettingsModel?> getGstSettings(String userId) async {
    final result = await (_db.select(
      _db.gstSettings,
    )..where((t) => t.id.equals(userId))).getSingleOrNull();

    if (result == null) return null;

    return GstSettingsModel(
      id: result.id,
      gstin: result.gstin,
      stateCode: result.stateCode,
      legalName: result.legalName,
      tradeName: result.tradeName,
      filingFrequency: result.filingFrequency ?? 'MONTHLY',
      isCompositionScheme: result.isCompositionScheme,
      compositionRate: result.compositionRate,
      isEInvoiceEnabled: result.isEInvoiceEnabled,
      registrationDate: result.registrationDate,
      createdAt: result.createdAt,
      updatedAt: result.updatedAt,
      isSynced: result.isSynced,
    );
  }

  /// Save or update GST settings
  Future<void> saveGstSettings(GstSettingsModel settings) async {
    await _db
        .into(_db.gstSettings)
        .insertOnConflictUpdate(
          GstSettingsCompanion(
            id: Value(settings.id),
            gstin: Value(settings.gstin),
            stateCode: Value(settings.stateCode),
            legalName: Value(settings.legalName),
            tradeName: Value(settings.tradeName),
            filingFrequency: Value(settings.filingFrequency),
            isCompositionScheme: Value(settings.isCompositionScheme),
            compositionRate: Value(settings.compositionRate),
            isEInvoiceEnabled: Value(settings.isEInvoiceEnabled),
            registrationDate: Value(settings.registrationDate),
            createdAt: Value(settings.createdAt),
            updatedAt: Value(DateTime.now()),
            isSynced: const Value(false),
          ),
        );
  }

  /// Check if GST is enabled for user
  Future<bool> isGstEnabled(String userId) async {
    final settings = await getGstSettings(userId);
    return settings?.isGstEnabled ?? false;
  }

  // ============================================================================
  // GST INVOICE DETAILS
  // ============================================================================

  /// Get GST details for a bill
  Future<GstInvoiceDetailModel?> getGstDetailsByBillId(String billId) async {
    final result = await (_db.select(
      _db.gstInvoiceDetails,
    )..where((t) => t.billId.equals(billId))).getSingleOrNull();

    if (result == null) return null;

    return GstInvoiceDetailModel.fromMap({
      'id': result.id,
      'billId': result.billId,
      'invoiceType': result.invoiceType,
      'supplyType': result.supplyType,
      'placeOfSupply': result.placeOfSupply,
      'taxableValue': result.taxableValue,
      'cgstRate': result.cgstRate,
      'cgstAmount': result.cgstAmount,
      'sgstRate': result.sgstRate,
      'sgstAmount': result.sgstAmount,
      'igstRate': result.igstRate,
      'igstAmount': result.igstAmount,
      'cessAmount': result.cessAmount,
      'hsnSummaryJson': result.hsnSummaryJson,
      'isReverseCharge': result.isReverseCharge,
      'eInvoiceIrn': result.eInvoiceIrn,
      'createdAt': result.createdAt.toIso8601String(),
      'isSynced': result.isSynced,
    });
  }

  /// Save GST invoice details
  Future<void> saveGstInvoiceDetail(GstInvoiceDetailModel detail) async {
    final map = detail.toMap();
    await _db
        .into(_db.gstInvoiceDetails)
        .insertOnConflictUpdate(
          GstInvoiceDetailsCompanion(
            id: Value(detail.id),
            billId: Value(detail.billId),
            invoiceType: Value(map['invoiceType']),
            supplyType: Value(map['supplyType']),
            placeOfSupply: Value(detail.placeOfSupply),
            taxableValue: Value(detail.taxableValue),
            cgstRate: Value(detail.cgstRate),
            cgstAmount: Value(detail.cgstAmount),
            sgstRate: Value(detail.sgstRate),
            sgstAmount: Value(detail.sgstAmount),
            igstRate: Value(detail.igstRate),
            igstAmount: Value(detail.igstAmount),
            cessAmount: Value(detail.cessAmount),
            hsnSummaryJson: Value(map['hsnSummaryJson']),
            isReverseCharge: Value(detail.isReverseCharge),
            eInvoiceIrn: Value(detail.eInvoiceIrn),
            createdAt: Value(detail.createdAt),
            isSynced: const Value(false),
          ),
        );
  }

  /// Get all GST invoices for a date range (for GSTR-1 export)
  Future<List<GstInvoiceDetailModel>> getGstInvoicesForPeriod({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Join with bills to filter by userId and date
    final query =
        _db.select(_db.gstInvoiceDetails).join([
            innerJoin(
              _db.bills,
              _db.bills.id.equalsExp(_db.gstInvoiceDetails.billId),
            ),
          ])
          ..where(_db.bills.userId.equals(userId))
          ..where(_db.bills.billDate.isBetweenValues(startDate, endDate))
          ..where(_db.bills.deletedAt.isNull());

    final results = await query.get();

    return results.map((row) {
      final gst = row.readTable(_db.gstInvoiceDetails);
      return GstInvoiceDetailModel.fromMap({
        'id': gst.id,
        'billId': gst.billId,
        'invoiceType': gst.invoiceType,
        'supplyType': gst.supplyType,
        'placeOfSupply': gst.placeOfSupply,
        'taxableValue': gst.taxableValue,
        'cgstRate': gst.cgstRate,
        'cgstAmount': gst.cgstAmount,
        'sgstRate': gst.sgstRate,
        'sgstAmount': gst.sgstAmount,
        'igstRate': gst.igstRate,
        'igstAmount': gst.igstAmount,
        'cessAmount': gst.cessAmount,
        'hsnSummaryJson': gst.hsnSummaryJson,
        'isReverseCharge': gst.isReverseCharge,
        'eInvoiceIrn': gst.eInvoiceIrn,
        'createdAt': gst.createdAt.toIso8601String(),
        'isSynced': gst.isSynced,
      });
    }).toList();
  }

  // ============================================================================
  // HSN MASTER
  // ============================================================================

  /// Get all HSN codes
  Future<List<HsnCodeModel>> getAllHsnCodes() async {
    final results = await (_db.select(
      _db.hsnMaster,
    )..where((t) => t.isActive.equals(true))).get();

    return results
        .map(
          (r) => HsnCodeModel(
            hsnCode: r.hsnCode ?? r.code,
            description: r.description ?? '',
            cgstRate: r.cgstRate,
            sgstRate: r.sgstRate,
            igstRate: r.igstRate,
            unit: r.unit,
            isActive: r.isActive,
          ),
        )
        .toList();
  }

  /// Get HSN code by code
  Future<HsnCodeModel?> getHsnCode(String hsnCode) async {
    final result = await (_db.select(
      _db.hsnMaster,
    )..where((t) => t.hsnCode.equals(hsnCode))).getSingleOrNull();

    if (result == null) return null;

    return HsnCodeModel(
      hsnCode: result.hsnCode ?? result.code,
      description: result.description ?? '',
      cgstRate: result.cgstRate,
      sgstRate: result.sgstRate,
      igstRate: result.igstRate,
      unit: result.unit,
      isActive: result.isActive,
    );
  }

  /// Save HSN code
  Future<void> saveHsnCode(HsnCodeModel hsn) async {
    await _db
        .into(_db.hsnMaster)
        .insertOnConflictUpdate(
          HsnMasterCompanion(
            hsnCode: Value(hsn.hsnCode),
            description: Value(hsn.description),
            cgstRate: Value(hsn.cgstRate),
            sgstRate: Value(hsn.sgstRate),
            igstRate: Value(hsn.igstRate),
            unit: Value(hsn.unit),
            isActive: Value(hsn.isActive),
          ),
        );
  }

  /// Seed common HSN codes if not exists
  Future<void> seedCommonHsnCodes() async {
    final existingCount = await _db.select(_db.hsnMaster).get();
    if (existingCount.isEmpty) {
      for (final hsn in GstTaxSlabs.commonHsnCodes) {
        await saveHsnCode(hsn);
      }
    }
  }

  /// Search HSN codes by description or code
  Future<List<HsnCodeModel>> searchHsnCodes(String query) async {
    final results =
        await (_db.select(_db.hsnMaster)
              ..where(
                (t) =>
                    t.hsnCode.contains(query) | t.description.contains(query),
              )
              ..where((t) => t.isActive.equals(true)))
            .get();

    return results
        .map(
          (r) => HsnCodeModel(
            hsnCode: r.hsnCode ?? r.code,
            description: r.description ?? '',
            cgstRate: r.cgstRate,
            sgstRate: r.sgstRate,
            igstRate: r.igstRate,
            unit: r.unit,
            isActive: r.isActive,
          ),
        )
        .toList();
  }
}
