import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/config/business_capabilities.dart';
import 'package:dukanx/core/isolation/business_capability.dart';
import 'package:dukanx/core/isolation/feature_resolver.dart' as iso;
import 'package:dukanx/models/business_type.dart';

void main() {
  group('Business Feature Matrix Verification', () {
    test('Grocery Store Configuration', () {
      final caps = BusinessCapabilities.get(BusinessType.grocery);

      // ✅ Must Have
      expect(
        caps.accessProductAdd,
        isA<bool>(),
      ); // Just checking it exists, true by check
      expect(
        caps.accessProductAdd,
        isTrue,
        reason: 'Grocery should have Add Item',
      );
      expect(caps.accessInventoryList, isTrue);
      expect(caps.accessInvoiceList, isTrue);
      expect(caps.accessLowStockAlert, isTrue);
      expect(caps.accessPurchaseOrder, isTrue);

      // ✅ Expiry support (Req 7.3): grocery IS granted useBatchExpiry, so
      // supportsExpiry must mirror the capability (the prior hardcoded `false`
      // was a self-contradiction removed in Phase 4 / task 5.5).
      final groceryHasBatchExpiry = iso.FeatureResolver.canAccess(
        BusinessType.grocery.name,
        BusinessCapability.useBatchExpiry,
      );
      expect(groceryHasBatchExpiry, isTrue);
      expect(
        caps.supportsExpiry,
        isTrue,
        reason: 'Grocery is granted useBatchExpiry, so expiry must be enabled',
      );
      expect(
        caps.supportsExpiry,
        equals(groceryHasBatchExpiry),
        reason:
            'supportsExpiry must equal the granted useBatchExpiry capability',
      );

      // ❌ Blocked / Not Present
      expect(
        caps.accessServiceStatus,
        isFalse,
        reason: 'Grocery not a service',
      );
      expect(caps.supportsPrescriptions, isFalse);
    });

    test('Pharmacy Configuration', () {
      final caps = BusinessCapabilities.get(BusinessType.pharmacy);

      // ✅ Must Have
      expect(caps.accessProductAdd, isTrue);
      expect(caps.accessInventoryList, isTrue);
      expect(caps.accessInvoiceCreate, isTrue);
      expect(caps.supportsPrescriptions, isTrue, reason: 'Pharmacy needs Rx');
      expect(caps.supportsBatch, isTrue);
      expect(caps.supportsExpiry, isTrue);
      expect(caps.accessDeadStock, isTrue);

      // ❌ Blocked
      expect(caps.accessKOT, isFalse);
    });

    test('Restaurant Configuration', () {
      final caps = BusinessCapabilities.get(BusinessType.restaurant);

      // ✅ Must Have
      expect(caps.accessProductAdd, isTrue);
      expect(caps.accessInvoiceCreate, isTrue);
      expect(caps.accessKOT, isTrue, reason: 'Restaurant needs KOT');
      expect(caps.accessTableManagement, isTrue);

      // ❌ Blocked
      expect(caps.accessInventoryExport, isFalse);
      expect(caps.supportsPrescriptions, isFalse);
    });

    test('Service Business Configuration', () {
      final caps = BusinessCapabilities.get(BusinessType.service);

      // ✅ Must Have
      expect(
        caps.supportsGymMode,
        isTrue,
        reason: 'Service uses Job Sheets (GymMode alias)',
      );
      expect(caps.accessInvoiceCreate, isTrue);

      // ❌ Blocked
      expect(
        caps.accessProductAdd,
        isFalse,
        reason: 'Service does not add Items (per checklist)',
      );
      expect(caps.accessInventoryList, isFalse);
      expect(caps.accessSupplierBill, isFalse);
    });

    test('Wholesale Configuration', () {
      final caps = BusinessCapabilities.get(BusinessType.wholesale);

      // ✅ Must Have
      expect(caps.accessInventoryExport, isTrue);
      expect(caps.accessProformaInvoice, isTrue);
      expect(caps.accessDispatchNote, isTrue);
      expect(caps.accessStockReversal, isTrue);
      expect(caps.accessCreditLimit, isTrue);

      // ❌ Blocked
      expect(caps.accessKOT, isFalse);
    });

    test('General Isolation Check', () {
      // Verify no cross-contamination
      final grocery = BusinessCapabilities.get(BusinessType.grocery);
      final pharmacy = BusinessCapabilities.get(BusinessType.pharmacy);

      expect(grocery.supportsPrescriptions, isFalse);
      expect(pharmacy.supportsPrescriptions, isTrue);
    });
  });
}
