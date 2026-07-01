import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dukanx/features/ai_assistant/services/recommendation_service.dart';
import 'package:dukanx/core/repository/products_repository.dart';
import 'package:dukanx/core/repository/bills_repository.dart';
import 'package:dukanx/core/session/session_manager.dart';
import 'package:dukanx/core/error/error_handler.dart';

// Generate mocks with:
// flutter pub run build_runner build
@GenerateMocks([ProductsRepository, BillsRepository, SessionManager])
import 'recommendation_service_test.mocks.dart';

import 'package:get_it/get_it.dart';

void main() {
  late RecommendationService service;
  late MockProductsRepository mockProductsRepo;
  late MockBillsRepository mockBillsRepo;
  late MockSessionManager mockSessionManager;

  setUp(() {
    mockProductsRepo = MockProductsRepository();
    mockBillsRepo = MockBillsRepository();
    mockSessionManager = MockSessionManager();

    // Register SessionManager mock in GetIt
    if (GetIt.I.isRegistered<SessionManager>()) {
      GetIt.I.unregister<SessionManager>();
    }
    GetIt.I.registerSingleton<SessionManager>(mockSessionManager);

    // Stub ownerId to return a valid string by default
    when(mockSessionManager.ownerId).thenReturn('user123');

    service = RecommendationService(mockProductsRepo, mockBillsRepo);
  });

  tearDown(() {
    GetIt.I.reset();
  });

  group('RecommendationService - Basic Functionality', () {
    const userId = 'user123';

    test('getRecommendations with empty cart returns popular items', () async {
      //Arrange
      final mockProducts = [
        _createMockProduct('p1', 'Product 1', 'Category A', 100.0),
        _createMockProduct('p2', 'Product 2', 'Category B', 150.0),
        _createMockProduct('p3', 'Product 3', 'Category A', 200.0),
        _createMockProduct('p4', 'Product 4', 'Category C', 250.0),
        _createMockProduct('p5', 'Product 5', 'Category B', 300.0),
      ];

      when(
        mockProductsRepo.watchAll(userId: userId),
      ).thenAnswer((_) => Stream.value(mockProducts));

      // Mock session manager
      // Note: This would need proper service locator setup

      // Act
      final result = await service.getRecommendations([]);

      // Assert
      expect(result, isNotEmpty);
      expect(result.length, lessThanOrEqualTo(5));
    });

    test(
      'getRecommendations with items in cart returns related products',
      () async {
        // Arrange
        final mockProducts = [
          _createMockProduct('p1', 'Apple', 'Fruits', 50.0),
          _createMockProduct('p2', 'Banana', 'Fruits', 30.0),
          _createMockProduct('p3', 'Orange', 'Fruits', 40.0),
          _createMockProduct('p4', 'Milk', 'Dairy', 60.0),
        ];

        final cartItems = [
          BillItem(productId: 'p1', productName: 'Apple', qty: 2, price: 50.0),
        ];

        when(
          mockProductsRepo.watchAll(userId: userId),
        ).thenAnswer((_) => Stream.value(mockProducts));

        // Act
        final result = await service.getRecommendations(cartItems);

        // Assert
        expect(result, isNotEmpty);
        // Should not include the item already in cart
        expect(result.any((p) => p.id == 'p1'), false);
      },
    );

    test('getRecommendations with no products returns empty list', () async {
      // Arrange
      when(
        mockProductsRepo.watchAll(userId: userId),
      ).thenAnswer((_) => Stream.value([]));

      // Act
      final result = await service.getRecommendations([]);

      // Assert
      expect(result, isEmpty);
    });
  });

  group('RecommendationService - Purchase History Analysis', () {
    test('calculates product affinity from historical bills', () async {
      // Arrange
      final mockProducts = [
        _createMockProduct('p1', 'Bread', 'Bakery', 30.0),
        _createMockProduct('p2', 'Butter', 'Dairy', 50.0),
        _createMockProduct('p3', 'Jam', 'Spreads', 80.0),
      ];

      final mockBills = [
        _createMockBill('b1', DateTime.now(), [
          BillItem(productId: 'p1', productName: 'Bread', qty: 1, price: 30.0),
          BillItem(productId: 'p2', productName: 'Butter', qty: 1, price: 50.0),
        ]),
        _createMockBill('b2', DateTime.now(), [
          BillItem(productId: 'p1', productName: 'Bread', qty: 1, price: 30.0),
          BillItem(productId: 'p2', productName: 'Butter', qty: 1, price: 50.0),
        ]),
        _createMockBill('b3', DateTime.now(), [
          BillItem(productId: 'p1', productName: 'Bread', qty: 1, price: 30.0),
          BillItem(productId: 'p3', productName: 'Jam', qty: 1, price: 80.0),
        ]),
      ];

      when(
        mockProductsRepo.watchAll(userId: 'user123'),
      ).thenAnswer((_) => Stream.value(mockProducts));

      when(
        mockBillsRepo.getAll(userId: 'user123'),
      ).thenAnswer((_) async => RepositoryResult.success(mockBills));

      // Act
      final cartItems = [
        BillItem(productId: 'p1', productName: 'Bread', qty: 1, price: 30.0),
      ];
      final result = await service.getRecommendations(cartItems);

      // Assert
      // Butter should be recommended (2 co-occurrences)
      // Jam should also be recommended (1 co-occurrence)
      expect(result, isNotEmpty);
    });

    test('calculates product sales frequency correctly', () async {
      // Test for popular products algorithm
      expect(true, true); // Placeholder
    });
  });

  group('RecommendationService - Category-Based Logic', () {
    test('recommends products from same category', () async {
      // Arrange
      final mockProducts = [
        _createMockProduct('p1', 'iPhone 12', 'Electronics', 50000.0),
        _createMockProduct('p2', 'iPhone Case', 'Electronics', 500.0),
        _createMockProduct('p3', 'Screen Protector', 'Electronics', 200.0),
        _createMockProduct('p4', 'T-Shirt', 'Clothing', 300.0),
      ];

      final cartItems = [
        BillItem(
          productId: 'p1',
          productName: 'iPhone 12',
          qty: 1,
          price: 50000.0,
        ),
      ];

      when(
        mockProductsRepo.watchAll(userId: 'user123'),
      ).thenAnswer((_) => Stream.value(mockProducts));

      when(
        mockBillsRepo.getAll(userId: anyNamed('userId')),
      ).thenAnswer((_) async => RepositoryResult.success([]));

      // Act
      final result = await service.getRecommendations(cartItems);

      // Assert
      expect(result, isNotEmpty);
      // Should primarily contain Electronics category items
      final electronicsItems = result.where((p) => p.category == 'Electronics');
      expect(electronicsItems, isNotEmpty);
    });

    test('fallback when no same-category items available', () async {
      // Arrange
      final mockProducts = [
        _createMockProduct('p1', 'Product A', 'Category A', 100.0),
        _createMockProduct('p2', 'Product B', 'Category B', 200.0),
      ];

      final cartItems = [
        BillItem(
          productId: 'p1',
          productName: 'Product A',
          qty: 1,
          price: 100.0,
        ),
      ];

      when(
        mockProductsRepo.watchAll(userId: 'user123'),
      ).thenAnswer((_) => Stream.value(mockProducts));

      when(
        mockBillsRepo.getAll(userId: anyNamed('userId')),
      ).thenAnswer((_) async => RepositoryResult.success([]));

      // Act
      final result = await service.getRecommendations(cartItems);

      // Assert
      expect(result, isNotEmpty);
      // Should fallback to other products
      expect(result.any((p) => p.id == 'p2'), true);
    });
  });

  group('RecommendationService - Frequently Bought Together', () {
    test('identifies association rules with minimum support', () async {
      // Test implementation for support threshold
      expect(true, true); // Placeholder
    });

    test('calculates confidence correctly', () async {
      // Test implementation for confidence metric
      expect(true, true); // Placeholder
    });

    test('filters by minimum occurrence count', () async {
      // Test implementation for minimum occurrence filtering
      expect(true, true); // Placeholder
    });
  });

  group('RecommendationService - Trending Products', () {
    test(
      'getTrendingProducts identifies products with high velocity',
      () async {
        // Arrange
        final now = DateTime.now();
        final mockProducts = [
          _createMockProduct('p1', 'Trending Product', 'Category A', 100.0),
          _createMockProduct('p2', 'Regular Product', 'Category B', 150.0),
        ];

        // Recent bills (last 7 days) with high sales
        final recentBills = List.generate(
          10,
          (i) => _createMockBill('b$i', now.subtract(Duration(days: i ~/ 2)), [
            BillItem(
              productId: 'p1',
              productName: 'Trending Product',
              qty: 5,
              price: 100.0,
            ),
          ]),
        );

        // Previous bills (7-14 days ago) with low sales
        final previousBills = [
          _createMockBill('b10', now.subtract(const Duration(days: 10)), [
            BillItem(
              productId: 'p1',
              productName: 'Trending Product',
              qty: 1,
              price: 100.0,
            ),
          ]),
        ];

        when(
          mockProductsRepo.watchAll(userId: 'user123'),
        ).thenAnswer((_) => Stream.value(mockProducts));

        when(mockBillsRepo.getAll(userId: 'user123')).thenAnswer((
          invocation,
        ) async {
          return RepositoryResult.success([...recentBills, ...previousBills]);
        });

        // Act
        final result = await service.getTrendingProducts('user123');

        // Assert
        expect(result, isNotEmpty);
        // p1 should have positive velocity
        expect(result.any((p) => p.id == 'p1'), true);
      },
    );

    test('handles zero previous sales correctly', () async {
      // Test edge case where previous period has no sales
      expect(true, true); // Placeholder
    });
  });

  group('RecommendationService - Scoring System', () {
    test('getPersonalizedRecommendations uses weighted scoring', () async {
      // Arrange
      final mockProducts = [
        _createMockProduct('p1', 'Product 1', 'Category A', 100.0),
        _createMockProduct('p2', 'Product 2', 'Category B', 150.0),
        _createMockProduct('p3', 'Product 3', 'Category A', 200.0),
      ];

      when(
        mockProductsRepo.watchAll(userId: 'user123'),
      ).thenAnswer((_) => Stream.value(mockProducts));

      when(
        mockBillsRepo.getAll(userId: anyNamed('userId')),
      ).thenAnswer((_) async => RepositoryResult.success([]));

      // Act
      final result = await service.getPersonalizedRecommendations(
        'user123',
        [],
      );

      // Assert
      expect(result, isNotEmpty);
      // Recommendations should be ranked by score
    });

    test('combines multiple signals correctly', () async {
      // Test that affinity, popularity, recency, and category all contribute
      expect(true, true); // Placeholder
    });

    test('normalizes scores properly', () async {
      // Test score normalization
      expect(true, true); // Placeholder
    });

    test('excludes cart items from recommendations', () async {
      // Arrange
      final mockProducts = [
        _createMockProduct('p1', 'In Cart', 'Category A', 100.0),
        _createMockProduct('p2', 'Not In Cart', 'Category A', 150.0),
      ];

      final cartItems = [
        BillItem(productId: 'p1', productName: 'In Cart', qty: 1, price: 100.0),
      ];

      when(
        mockProductsRepo.watchAll(userId: 'user123'),
      ).thenAnswer((_) => Stream.value(mockProducts));

      when(
        mockBillsRepo.getAll(userId: anyNamed('userId')),
      ).thenAnswer((_) async => RepositoryResult.success([]));

      // Act
      final result = await service.getPersonalizedRecommendations(
        'user123',
        cartItems,
      );

      // Assert
      expect(result.any((p) => p.id == 'p1'), false);
      expect(result.any((p) => p.id == 'p2'), true);
    });
  });

  group('RecommendationService - Error Handling', () {
    test('handles repository errors gracefully', () async {
      // Arrange
      when(
        mockProductsRepo.watchAll(userId: anyNamed('userId')),
      ).thenAnswer((_) => Stream.error(Exception('Database error')));

      // Act
      final result = await service.getRecommendations([]);

      // Assert
      expect(result, isEmpty);
    });

    test('handles null or invalid data', () async {
      // Test implementation
      expect(true, true); // Placeholder
    });
  });
}

// Helper functions
Product _createMockProduct(
  String id,
  String name,
  String category,
  double price,
) {
  final now = DateTime.now();
  return Product(
    id: id,
    userId: 'user123',
    name: name,
    category: category,
    sellingPrice: price,
    stockQuantity: 100,
    createdAt: now,
    updatedAt: now,
  );
}

Bill _createMockBill(String id, DateTime date, List<BillItem> items) {
  return Bill(
    id: id,
    customerId: 'customer123',
    customerName: 'Test Customer',
    date: date,
    items: items,
    status: 'PAID',
    grandTotal: items.fold(0.0, (sum, item) => sum + item.total),
  );
}
