/// Shared domain types for the Certification_System.
///
/// This file mirrors the 19 Business_Types from lib/models/business_type.dart,
/// defines the service-only subset, and enumerates the functional modules
/// certified per type.
///
/// Requirements: 1.4, 16.1, 16.3
library;

/// The 19 supported business verticals (mirror of lib/models/business_type.dart).
enum BusinessType {
  grocery,
  pharmacy,
  restaurant,
  clothing,
  electronics,
  mobileShop,
  computerShop,
  hardware,
  service,
  wholesale,
  petrolPump,
  vegetablesBroker,
  clinic,
  other,
  bookStore,
  jewellery,
  autoParts,
  decorationCatering,
  schoolErp,
}

/// Service_Only_Types carry no product/inventory scope.
/// These types omit product and inventory test cases during certification (Req 16.5).
const Set<BusinessType> kServiceOnlyTypes = {
  BusinessType.service,
  BusinessType.clinic,
  BusinessType.schoolErp,
  BusinessType.decorationCatering,
};

/// Functional modules certified per type (Req 1.4).
enum Module {
  customerManagement,
  supplierManagement,
  inventoryTracking,
  invoiceGeneration,
  payments,
  reports,
  analytics,
  dataSync,
  offlineMode,
  subscriptionControls,
  licenseActivation,
  billing,
}
