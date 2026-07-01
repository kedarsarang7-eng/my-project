import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/pre_order/services/local_cart_service.dart';
import 'package:dukanx/features/pre_order/models/customer_item_request.dart';

void main() {
  group('LocalCartService Tests', () {
    late LocalCartService service;

    setUp(() {
      service = LocalCartService();
    });

    test('Should initialize with empty items', () {
      expect(service.items, isEmpty);
      expect(service.currentVendorId, isNull);
    });

    test('Should add items when initialized', () {
      service.initializeForVendor('vendor1');
      service.addItem(
        CustomerItemRequestItem(
          productId: 'p1',
          productName: 'Test Product',
          requestedQty: 1,
          unit: 'pcs',
          // other required params if any
        ),
      );

      expect(service.items.length, 1);
      expect(service.items.first.productId, 'p1');
    });

    test('Should fail to add item if not initialized', () {
      expect(
        () => service.addItem(
          CustomerItemRequestItem(
            productId: 'p1',
            productName: 'Test',
            requestedQty: 1,
            unit: 'pcs',
          ),
        ),
        throwsException,
      );
    });

    test('Vendor Change should CLEAR cart', () {
      // 1. Setup Vendor 1
      service.initializeForVendor('vendor1');
      service.addItem(
        CustomerItemRequestItem(
          productId: 'p1',
          productName: 'P1',
          requestedQty: 1,
          unit: 'pcs',
        ),
      );
      expect(service.items.length, 1);

      // 2. Switch to Vendor 2
      service.initializeForVendor('vendor2');

      // 3. Verify Cleared
      expect(service.items, isEmpty);
      expect(service.currentVendorId, 'vendor2');
    });

    test('Same Vendor Init should NOT clear cart', () {
      service.initializeForVendor('vendor1');
      service.addItem(
        CustomerItemRequestItem(
          productId: 'p1',
          productName: 'P1',
          requestedQty: 1,
          unit: 'pcs',
        ),
      );

      service.initializeForVendor('vendor1');
      expect(service.items.length, 1);
    });
  });
}
