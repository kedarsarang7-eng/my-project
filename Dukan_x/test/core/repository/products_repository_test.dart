// ============================================================================
// PRODUCTS REPOSITORY TESTS
// ============================================================================
// Tests for ProductsRepository - offline-first pattern
//
// Author: DukanX Engineering
// Version: 2.0.0
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/repository/products_repository.dart';

void main() {
  group('Product Model Tests', () {
    test('should create Product with required fields', () {
      final now = DateTime.now();
      final product = Product(
        id: 'prod-123',
        userId: 'owner-456',
        name: 'Test Product',
        sellingPrice: 100.0,
        createdAt: now,
        updatedAt: now,
      );

      expect(product.id, 'prod-123');
      expect(product.userId, 'owner-456');
      expect(product.name, 'Test Product');
      expect(product.sellingPrice, 100.0);
      expect(product.costPrice, 0);
      expect(product.stockQuantity, 0);
      expect(product.unit, 'pcs');
      expect(product.isActive, true);
      expect(product.isSynced, false);
    });

    test('should create Product with all optional fields', () {
      final now = DateTime.now();
      final product = Product(
        id: 'prod-123',
        userId: 'owner-456',
        name: 'Test Product',
        sku: 'SKU-001',
        barcode: '1234567890',
        category: 'Electronics',
        unit: 'pcs',
        sellingPrice: 100.0,
        costPrice: 70.0,
        taxRate: 18.0,
        stockQuantity: 50.0,
        lowStockThreshold: 10.0,
        createdAt: now,
        updatedAt: now,
      );

      expect(product.sku, 'SKU-001');
      expect(product.barcode, '1234567890');
      expect(product.category, 'Electronics');
      expect(product.costPrice, 70.0);
      expect(product.taxRate, 18.0);
      expect(product.stockQuantity, 50.0);
      expect(product.lowStockThreshold, 10.0);
    });

    test('isLowStock should be true when stock <= threshold', () {
      final now = DateTime.now();

      final lowStock = Product(
        id: 'prod-1',
        userId: 'owner-456',
        name: 'Low Stock Product',
        sellingPrice: 100.0,
        stockQuantity: 5.0,
        lowStockThreshold: 10.0,
        createdAt: now,
        updatedAt: now,
      );

      final okStock = Product(
        id: 'prod-2',
        userId: 'owner-456',
        name: 'OK Stock Product',
        sellingPrice: 100.0,
        stockQuantity: 50.0,
        lowStockThreshold: 10.0,
        createdAt: now,
        updatedAt: now,
      );

      final exactThreshold = Product(
        id: 'prod-3',
        userId: 'owner-456',
        name: 'Exact Threshold Product',
        sellingPrice: 100.0,
        stockQuantity: 10.0,
        lowStockThreshold: 10.0,
        createdAt: now,
        updatedAt: now,
      );

      expect(lowStock.isLowStock, true);
      expect(okStock.isLowStock, false);
      expect(exactThreshold.isLowStock, true); // Equal to threshold
    });

    test('copyWith should create a copy with updated fields', () {
      final now = DateTime.now();
      final original = Product(
        id: 'prod-123',
        userId: 'owner-456',
        name: 'Original Name',
        sellingPrice: 100.0,
        stockQuantity: 50.0,
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(
        name: 'Updated Name',
        sellingPrice: 120.0,
        stockQuantity: 45.0,
      );

      // Changed fields
      expect(updated.name, 'Updated Name');
      expect(updated.sellingPrice, 120.0);
      expect(updated.stockQuantity, 45.0);

      // Unchanged fields
      expect(updated.id, 'prod-123');
      expect(updated.userId, 'owner-456');
    });

    test('toFirestoreMap should serialize correctly', () {
      final now = DateTime.now();
      final product = Product(
        id: 'prod-123',
        userId: 'owner-456',
        name: 'Test Product',
        sku: 'SKU-001',
        sellingPrice: 100.0,
        costPrice: 70.0,
        stockQuantity: 50.0,
        createdAt: now,
        updatedAt: now,
      );

      final map = product.toFirestoreMap();

      expect(map['id'], 'prod-123');
      expect(map['name'], 'Test Product');
      expect(map['sku'], 'SKU-001');
      expect(map['sellingPrice'], 100.0);
      expect(map['costPrice'], 70.0);
      expect(map['stockQuantity'], 50.0);

      // Should NOT include local-only fields
      expect(map.containsKey('isSynced'), false);
    });
  });

  group('Stock Calculation Tests', () {
    test('profit margin calculation', () {
      final product = Product(
        id: 'prod-123',
        userId: 'owner-456',
        name: 'Test Product',
        sellingPrice: 100.0,
        costPrice: 70.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final profitPerUnit = product.sellingPrice - product.costPrice;
      final marginPercent = (profitPerUnit / product.costPrice) * 100;

      expect(profitPerUnit, 30.0);
      expect(marginPercent.toStringAsFixed(1), '42.9');
    });

    test('stock value calculation', () {
      final product = Product(
        id: 'prod-123',
        userId: 'owner-456',
        name: 'Test Product',
        sellingPrice: 100.0,
        costPrice: 70.0,
        stockQuantity: 50.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final stockValueAtCost = product.stockQuantity * product.costPrice;
      final stockValueAtSelling = product.stockQuantity * product.sellingPrice;
      final potentialProfit = stockValueAtSelling - stockValueAtCost;

      expect(stockValueAtCost, 3500.0);
      expect(stockValueAtSelling, 5000.0);
      expect(potentialProfit, 1500.0);
    });
  });
}
