// ============================================================================
// ONLINE-ONLY FEATURE REGISTRY — declarative catalogue of features that
// cannot function in Offline_Lifetime_Mode
// ============================================================================
// Feature: offline-license-activation (Task 13.1)
//
// An Online_Only_Feature is a feature that depends on a REAL-TIME EXTERNAL
// SERVICE and therefore cannot function in Offline_Lifetime_Mode (see the
// requirements Glossary). This file is the single, declarative source of truth
// for that set (Requirement 11.8) and documents each entry as unavailable
// offline with a clear, machine-readable reason (Requirement 11.9).
//
// SCOPE OF THIS TASK (13.1): build the registry and document each entry. The
// registry is purely declarative here — it lists the features and explains why
// each is offline-unavailable. Actually BLOCKING execution of these features in
// Offline_Lifetime_Mode (Requirement 11.10) is a SEPARATE task (13.2) that
// consumes this registry; it is intentionally NOT implemented in this file.
//
// Design constraints honoured here (see design.md, "Offline Feature Parity"):
//   * REUSE, DON'T REBUILD. Every feature that works purely on local data
//     (billing, GST, inventory, purchases, reports, printing, PDF) is NOT in
//     this registry — those keep full offline parity. Only the features that
//     genuinely reach a live external service are listed.
//   * SERVICE LAYER ONLY. Pure Dart with no Flutter / IO dependency; injected
//     through the existing `service_locator` (`sl`) and never referenced by the
//     widget tree.
//
// Author: DukanX Engineering
// ============================================================================

/// A feature that depends on a real-time external service and therefore cannot
/// function in Offline_Lifetime_Mode (Requirement 11.8).
///
/// Each entry carries its stable [id], a human-readable [displayName], the
/// [externalService] it depends on, and the [unavailableOfflineReason] that
/// documents WHY it cannot run offline (Requirement 11.9). The enum is the
/// declarative registry; nothing here blocks execution (that is Task 13.2).
enum OnlineOnlyFeature {
  /// AI/OCR bill scanning (`/purchase/scan-bill/extract`) — uploads an image to
  /// a cloud OCR service (AWS Textract) and waits for a parsed result.
  scanBillOcr(
    id: 'scan_bill_ocr',
    displayName: 'Scan Bill (OCR extraction)',
    externalService: 'Cloud OCR service (AWS Textract)',
    unavailableOfflineReason:
        'Bill image scanning sends the image to a cloud OCR service for '
        'real-time text extraction. No local OCR engine is available offline, '
        'so scanning cannot be performed in Offline_Lifetime_Mode. Enter the '
        'purchase manually instead.',
  ),

  /// E-Invoice IRN generation — registers the invoice with the government
  /// Invoice Registration Portal (IRP) and returns an IRN + signed QR.
  eInvoiceIrn(
    id: 'einvoice_irn',
    displayName: 'E-Invoice (IRN generation)',
    externalService: 'GST Invoice Registration Portal (IRP)',
    unavailableOfflineReason:
        'Generating an IRN requires registering the invoice with the '
        'government Invoice Registration Portal in real time. The invoice can '
        'still be created and printed offline; IRN generation must be done '
        'while online.',
  ),

  /// E-Way Bill generation — obtains an e-way bill number from the NIC e-way
  /// bill portal for goods in transit.
  eWayBill(
    id: 'eway_bill',
    displayName: 'E-Way Bill generation',
    externalService: 'NIC E-Way Bill portal',
    unavailableOfflineReason:
        'An e-way bill number is issued by the NIC e-way bill portal over the '
        'internet. The transport details can be recorded on the invoice '
        'offline, but the e-way bill number must be generated while online.',
  ),

  /// GSTIN verification — validates a counterparty GSTIN against the live GST
  /// portal (beyond the offline checksum/format validation).
  gstinVerification(
    id: 'gstin_verification',
    displayName: 'GSTIN online verification',
    externalService: 'GST portal taxpayer API',
    unavailableOfflineReason:
        'Confirming a GSTIN against the live taxpayer registry requires the '
        'GST portal. Offline mode still validates GSTIN format and checksum '
        'locally; live registry lookup is unavailable offline.',
  ),

  /// Live metal/gold rate fetch — pulls the current market rate from an
  /// external rate feed (used by the jewellery vertical).
  liveMetalRates(
    id: 'live_metal_rates',
    displayName: 'Live gold/metal rate fetch',
    externalService: 'External market rate feed',
    unavailableOfflineReason:
        'Fetching the current gold/silver market rate requires a live rate '
        'feed. Offline mode uses the most recently saved rate; automatic live '
        'rate refresh is unavailable offline. Enter the rate manually.',
  ),

  /// Phone OTP / SMS login — sends a one-time passcode over an SMS gateway.
  phoneOtpLogin(
    id: 'phone_otp_login',
    displayName: 'Phone OTP / SMS sign-in',
    externalService: 'SMS / phone-auth gateway',
    unavailableOfflineReason:
        'Delivering a one-time passcode requires an SMS gateway. '
        'Offline_Lifetime_Mode authenticates users locally with username and '
        'password instead, so SMS OTP sign-in is unavailable offline.',
  ),

  /// Push notifications — delivers messages through a cloud push service.
  pushNotifications(
    id: 'push_notifications',
    displayName: 'Push notifications',
    externalService: 'Cloud push notification service',
    unavailableOfflineReason:
        'Push notifications are delivered through a cloud messaging service '
        'and cannot be sent or received while offline. In-app alerts that are '
        'computed from local data continue to work.',
  ),

  /// Cloud backup / synchronization — transfers data to the AWS backend.
  cloudSync(
    id: 'cloud_sync',
    displayName: 'Cloud backup & synchronization',
    externalService: 'AWS cloud backend',
    unavailableOfflineReason:
        'Cloud backup and synchronization move data to the AWS backend, which '
        'is unreachable offline. Offline_Lifetime_Mode protects data with '
        'local verified backups instead; cloud sync is unavailable offline.',
  );

  /// Stable, serialization-friendly identifier for the feature.
  final String id;

  /// Human-readable name of the feature, suitable for documentation/logging.
  final String displayName;

  /// The real-time external service this feature depends on (Requirement 11.8).
  final String externalService;

  /// Documented reason the feature is unavailable in Offline_Lifetime_Mode
  /// (Requirement 11.9).
  final String unavailableOfflineReason;

  const OnlineOnlyFeature({
    required this.id,
    required this.displayName,
    required this.externalService,
    required this.unavailableOfflineReason,
  });
}

/// The declarative Online_Only_Feature registry (Requirement 11.8).
///
/// A single source of truth that lists every feature which depends on a
/// real-time external service and documents each as unavailable offline
/// (Requirement 11.9). It is a pure lookup table — it performs NO blocking of
/// its own; the offline gate (Task 13.2) consumes these entries to enforce
/// Requirement 11.10.
class OnlineOnlyFeatureRegistry {
  OnlineOnlyFeatureRegistry._();

  /// Every registered Online_Only_Feature, in declaration order.
  ///
  /// This is the complete catalogue (Requirement 11.8). Iterating it yields,
  /// for each entry, its documented offline-unavailable reason
  /// (Requirement 11.9).
  static List<OnlineOnlyFeature> get all =>
      List.unmodifiable(OnlineOnlyFeature.values);

  /// Fast id → feature lookup, built once from [OnlineOnlyFeature.values].
  static final Map<String, OnlineOnlyFeature> _byId = {
    for (final feature in OnlineOnlyFeature.values) feature.id: feature,
  };

  /// Returns the [OnlineOnlyFeature] with the given [id], or `null` when [id]
  /// is not a registered online-only feature.
  static OnlineOnlyFeature? byId(String id) => _byId[id];

  /// Whether [featureId] names a registered Online_Only_Feature — i.e. a
  /// feature this registry documents as unavailable in Offline_Lifetime_Mode
  /// (Requirements 11.8, 11.9).
  ///
  /// Features that are NOT in the registry (billing, GST, inventory, reports,
  /// printing, …) keep full offline parity, so this returns `false` for them.
  static bool isOnlineOnly(String featureId) => _byId.containsKey(featureId);

  /// The documented offline-unavailable reason for [featureId]
  /// (Requirement 11.9), or `null` when [featureId] is not an
  /// Online_Only_Feature (in which case it is available offline).
  static String? unavailableOfflineReason(String featureId) =>
      _byId[featureId]?.unavailableOfflineReason;
}
