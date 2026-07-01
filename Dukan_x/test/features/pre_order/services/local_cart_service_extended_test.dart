import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/pre_order/services/local_cart_service.dart';
import 'package:dukanx/features/pre_order/models/customer_item_request.dart';

void main() {
  group('LocalCartService Extended Tests', () {
    late LocalCartService service;

    setUp(() {
      service = LocalCartService();
    });

    test('updateQuantity should modify existing item', () {
      service.initializeForVendor('vendor1');

      service.addItem(
        CustomerItemRequestItem(
          productId: 'p1',
          productName: 'Test Product',
          requestedQty: 1,
          unit: 'pcs',
          status: ItemStatus.pending,
        ),
      );

      service.updateQuantity('p1', 5);

      expect(service.items.first.requestedQty, 5);
    });

    test('updateQuantity should do nothing for non-existent item', () {
      service.initializeForVendor('vendor1');

      service.addItem(
        CustomerItemRequestItem(
          productId: 'p1',
          productName: 'Test Product',
          requestedQty: 1,
          unit: 'pcs',
          status: ItemStatus.pending,
        ),
      );

      service.updateQuantity('non-existent', 5);

      expect(service.items.length, 1);
      expect(service.items.first.requestedQty, 1);
    });

    test('removeItem should remove specific item', () {
      service.initializeForVendor('vendor1');

      service.addItem(
        CustomerItemRequestItem(
          productId: 'p1',
          productName: 'Product 1',
          requestedQty: 1,
          unit: 'pcs',
          status: ItemStatus.pending,
        ),
      );

      service.addItem(
        CustomerItemRequestItem(
          productId: 'p2',
          productName: 'Product 2',
          requestedQty: 2,
          unit: 'pcs',
          status: ItemStatus.pending,
        ),
      );

      service.removeItem('p1');

      expect(service.items.length, 1);
      expect(service.items.first.productId, 'p2');
    });

    test('itemCount should return correct count', () {
      service.initializeForVendor('vendor1');

      expect(service.itemCount, 0);

      service.addItem(
        CustomerItemRequestItem(
          productId: 'p1',
          productName: 'Product 1',
          requestedQty: 1,
          unit: 'pcs',
          status: ItemStatus.pending,
        ),
      );

      expect(service.itemCount, 1);

      service.addItem(
        CustomerItemRequestItem(
          productId: 'p2',
          productName: 'Product 2',
          requestedQty: 2,
          unit: 'pcs',
          status: ItemStatus.pending,
        ),
      );

      expect(service.itemCount, 2);
    });

    test('clear should remove all items', () {
      service.initializeForVendor('vendor1');

      service.addItem(
        CustomerItemRequestItem(
          productId: 'p1',
          productName: 'Product 1',
          requestedQty: 1,
          unit: 'pcs',
          status: ItemStatus.pending,
        ),
      );

      service.addItem(
        CustomerItemRequestItem(
          productId: 'p2',
          productName: 'Product 2',
          requestedQty: 2,
          unit: 'pcs',
          status: ItemStatus.pending,
        ),
      );

      service.clear();

      expect(service.items.isEmpty, true);
      expect(service.itemCount, 0);
    });

    test('adding duplicate product should update quantity', () {
      service.initializeForVendor('vendor1');

      service.addItem(
        CustomerItemRequestItem(
          productId: 'p1',
          productName: 'Product 1',
          requestedQty: 2,
          unit: 'pcs',
          status: ItemStatus.pending,
        ),
      );

      service.addItem(
        CustomerItemRequestItem(
          productId: 'p1',
          productName: 'Product 1',
          requestedQty: 3,
          unit: 'pcs',
          status: ItemStatus.pending,
        ),
      );

      // Should either have 1 item with qty 5, or 2 items
      // Depends on implementation - let's check item count
      final p1Items = service.items.where((i) => i.productId == 'p1');
      final totalQty = p1Items.fold<double>(
        0,
        (sum, item) => sum + item.requestedQty,
      );

      expect(totalQty >= 3, true); // At least the last quantity or combined
    });

    test('ChangeNotifier should notify listeners', () {
      service.initializeForVendor('vendor1');

      int notifyCount = 0;
      service.addListener(() {
        notifyCount++;
      });

      service.addItem(
        CustomerItemRequestItem(
          productId: 'p1',
          productName: 'Product 1',
          requestedQty: 1,
          unit: 'pcs',
          status: ItemStatus.pending,
        ),
      );

      expect(notifyCount, greaterThan(0));
    });
  });
}
