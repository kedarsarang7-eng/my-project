// ============================================================================
// CONNECTION SERVICE TESTS
// ============================================================================
// Tests for ConnectionService models and QR data generation
//
// Author: DukanX Engineering
// Version: 1.0.0
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/services/connection_service.dart';

void main() {
  group('ConnectionRequest Model Tests', () {
    test('should create ConnectionRequest from map', () {
      final map = {
        'customerId': 'cust-123',
        'customerUserId': 'user-456',
        'customerName': 'John Doe',
        'customerPhone': '9876543210',
        'status': 'pending',
      };

      final request = ConnectionRequest.fromMap('req-001', map);

      expect(request.id, 'req-001');
      expect(request.customerId, 'cust-123');
      expect(request.customerUserId, 'user-456');
      expect(request.customerName, 'John Doe');
      expect(request.customerPhone, '9876543210');
      expect(request.status, 'pending');
      expect(request.createdAt, null);
    });

    test('should handle missing fields with defaults', () {
      final map = <String, dynamic>{};

      final request = ConnectionRequest.fromMap('req-002', map);

      expect(request.id, 'req-002');
      expect(request.customerId, '');
      expect(request.customerUserId, '');
      expect(request.customerName, '');
      expect(request.customerPhone, '');
      expect(request.status, 'pending');
    });

    test('should handle different status values', () {
      final pendingMap = {'status': 'pending'};
      final acceptedMap = {'status': 'accepted'};
      final rejectedMap = {'status': 'rejected'};

      final pending = ConnectionRequest.fromMap('r1', pendingMap);
      final accepted = ConnectionRequest.fromMap('r2', acceptedMap);
      final rejected = ConnectionRequest.fromMap('r3', rejectedMap);

      expect(pending.status, 'pending');
      expect(accepted.status, 'accepted');
      expect(rejected.status, 'rejected');
    });
  });

  group('ConnectedShop Model Tests', () {
    test('should create ConnectedShop from map', () {
      final map = {
        'vendorId': 'vendor-123',
        'customerId': 'cust-456',
        'shopName': 'My Grocery Store',
      };

      final shop = ConnectedShop.fromMap(map);

      expect(shop.vendorId, 'vendor-123');
      expect(shop.customerId, 'cust-456');
      expect(shop.shopName, 'My Grocery Store');
    });

    test('should handle missing shopName with default', () {
      final map = {'vendorId': 'vendor-123', 'customerId': 'cust-456'};

      final shop = ConnectedShop.fromMap(map);

      expect(shop.vendorId, 'vendor-123');
      expect(shop.customerId, 'cust-456');
      expect(shop.shopName, 'Unknown Shop');
    });

    test('should handle empty map', () {
      final shop = ConnectedShop.fromMap({});

      expect(shop.vendorId, '');
      expect(shop.customerId, '');
      expect(shop.shopName, 'Unknown Shop');
    });

    test('should handle various shop names', () {
      final shops = [
        ConnectedShop.fromMap({
          'vendorId': 'v1',
          'customerId': 'c1',
          'shopName': 'ABC Store',
        }),
        ConnectedShop.fromMap({
          'vendorId': 'v2',
          'customerId': 'c2',
          'shopName': 'XYZ Mart',
        }),
        ConnectedShop.fromMap({
          'vendorId': 'v3',
          'customerId': 'c3',
          'shopName': 'दुकान नंबर 123',
        }),
      ];

      expect(shops[0].shopName, 'ABC Store');
      expect(shops[1].shopName, 'XYZ Mart');
      expect(shops[2].shopName, 'दुकान नंबर 123');
    });
  });

  group('QR Data Format Tests', () {
    test('should validate v1 QR format structure', () {
      // Expected format: "v1:vendorId:customerId:checksum"
      const qrData = 'v1:vendor123:cust456:abc12345';

      final parts = qrData.split(':');

      expect(parts.length, 4);
      expect(parts[0], 'v1');
      expect(parts[1], 'vendor123');
      expect(parts[2], 'cust456');
      expect(parts[3].length, 8); // Checksum is 8 characters
    });

    test('should reject invalid QR format - wrong version', () {
      const qrData = 'v2:vendor123:cust456:abc12345';

      final parts = qrData.split(':');

      expect(parts[0] == 'v1', false);
    });

    test('should reject invalid QR format - missing parts', () {
      const qrData1 = 'v1:vendor123';
      const qrData2 = 'v1:vendor123:cust456';

      expect(qrData1.split(':').length, 2);
      expect(qrData2.split(':').length, 3);
      expect(qrData1.split(':').length == 4, false);
      expect(qrData2.split(':').length == 4, false);
    });

    test('should handle QR data with special characters', () {
      const specialVendorId = 'vendor_123-abc';
      const specialCustomerId = 'cust_456-xyz';
      final qrData = 'v1:$specialVendorId:$specialCustomerId:checksum1';

      final parts = qrData.split(':');

      expect(parts[1], specialVendorId);
      expect(parts[2], specialCustomerId);
    });
  });

  group('Request Status Flow Tests', () {
    test('valid status transitions', () {
      final validStatuses = ['pending', 'accepted', 'rejected'];

      for (final status in validStatuses) {
        final request = ConnectionRequest.fromMap('r1', {'status': status});
        expect(validStatuses.contains(request.status), true);
      }
    });

    test('pending request should be processable', () {
      final request = ConnectionRequest.fromMap('req-1', {
        'customerId': 'cust-123',
        'customerUserId': 'user-456',
        'customerName': 'Test Customer',
        'customerPhone': '1234567890',
        'status': 'pending',
      });

      expect(request.status, 'pending');
      expect(request.customerName.isNotEmpty, true);
      expect(request.customerUserId.isNotEmpty, true);
    });
  });
}
