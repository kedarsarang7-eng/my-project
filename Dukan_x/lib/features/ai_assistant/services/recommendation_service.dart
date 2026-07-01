import 'package:flutter/material.dart';
import '../../../core/repository/products_repository.dart';
import '../../../core/repository/bills_repository.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/di/service_locator.dart';

/// AI-Powered Recommendation Service
///
/// Provides intelligent product recommendations based on:
/// - Purchase history analysis
/// - Product affinity patterns
/// - Category-based matching
/// - Frequently bought together logic
/// - Time-based trending
class RecommendationService {
  final ProductsRepository _productsRepo;
  final BillsRepository _billsRepo;

  RecommendationService(this._productsRepo, this._billsRepo);

  /// Get recommendations based on the context of the current bill
  Future<List<Product>> getRecommendations(List<BillItem> currentItems) async {
    try {
      final userId = sl<SessionManager>().ownerId;
      if (userId == null) return [];

      // 1. Get all products
      final allProducts = await _productsRepo.watchAll(userId: userId).first;
      if (allProducts.isEmpty) return [];

      // 2. If cart is empty, return popular/trending items
      if (currentItems.isEmpty) {
        return await _getPopularProducts(userId, allProducts);
      }

      // 3. Get frequently bought together recommendations
      final frequentlyBoughtTogether = await _getFrequentlyBoughtTogether(
        userId,
        currentItems,
        allProducts,
      );

      if (frequentlyBoughtTogether.isNotEmpty) {
        return frequentlyBoughtTogether;
      }

      // 4. Fallback to category-based recommendations
      return await _getCategoryBasedRecommendations(currentItems, allProducts);
    } catch (e) {
      debugPrint("Recommendation Error: $e");
      return [];
    }
  }

  /// Get popular products based on recent sales frequency
  Future<List<Product>> _getPopularProducts(
    String userId,
    List<Product> allProducts,
  ) async {
    try {
      // Get sales history for the last 30 days
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final salesHistory = await _calculateProductFrequency(
        userId,
        thirtyDaysAgo,
      );

      // Sort products by sales frequency
      final scoredProducts = allProducts.map((product) {
        final frequency = salesHistory[product.id] ?? 0.0;
        return _ScoredProduct(product, frequency);
      }).toList();

      scoredProducts.sort((a, b) => b.score.compareTo(a.score));

      return scoredProducts.take(5).map((sp) => sp.product).toList();
    } catch (e) {
      debugPrint("Error getting popular products: $e");
      return allProducts.take(5).toList();
    }
  }

  /// Calculate product sales frequency from bills
  Future<Map<String, double>> _calculateProductFrequency(
    String userId,
    DateTime since,
  ) async {
    final result = await _billsRepo.getAll(userId: userId);

    final bills = result.data ?? [];
    final frequency = <String, double>{};

    for (final bill in bills) {
      if (bill.status == 'CANCELLED' || bill.status == 'DRAFT') continue;

      // Only count bills after the since date
      if (bill.date.isBefore(since)) continue;

      for (final item in bill.items) {
        frequency[item.productId] = (frequency[item.productId] ?? 0) + item.qty;
      }
    }

    return frequency;
  }

  /// Get frequently bought together products using association analysis
  Future<List<Product>> _getFrequentlyBoughtTogether(
    String userId,
    List<BillItem> currentItems,
    List<Product> allProducts,
  ) async {
    try {
      // Get bills from last 90 days for pattern detection
      final result = await _billsRepo.getAll(userId: userId);
      final recentBills = result.data ?? [];

      // Filter bills from last 90 days
      final ninetyDaysAgo = DateTime.now().subtract(const Duration(days: 90));
      final filteredBills = recentBills
          .where((bill) => bill.date.isAfter(ninetyDaysAgo))
          .toList();

      // Build product affinity matrix
      final affinityScores = <String, Map<String, double>>{};
      final currentProductIds = currentItems.map((i) => i.productId).toSet();

      for (final bill in filteredBills) {
        if (bill.status == 'CANCELLED' || bill.status == 'DRAFT') continue;

        final billProductIds = bill.items.map((i) => i.productId).toSet();

        // For each product in current cart, find co-occurrence patterns
        for (final currentProductId in currentProductIds) {
          if (!billProductIds.contains(currentProductId)) continue;

          affinityScores[currentProductId] ??= {};

          // Count co-occurrences with other products
          for (final coProduct in billProductIds) {
            if (coProduct == currentProductId) continue;
            if (currentProductIds.contains(coProduct)) {
              continue; // Already in cart
            }

            affinityScores[currentProductId]![coProduct] =
                (affinityScores[currentProductId]![coProduct] ?? 0) + 1;
          }
        }
      }

      // Aggregate affinity scores across all current items
      final aggregatedScores = <String, double>{};
      for (final scores in affinityScores.values) {
        for (final entry in scores.entries) {
          aggregatedScores[entry.key] =
              (aggregatedScores[entry.key] ?? 0) + entry.value;
        }
      }

      // Calculate confidence (minimum 3 co-occurrences)
      final minSupport = 3;
      final recommendations = <_ScoredProduct>[];

      for (final entry in aggregatedScores.entries) {
        if (entry.value >= minSupport) {
          final product = allProducts.firstWhere(
            (p) => p.id == entry.key,
            orElse: () => ProductExtension.empty(),
          );

          if (product.id.isNotEmpty) {
            recommendations.add(_ScoredProduct(product, entry.value));
          }
        }
      }

      // Sort by affinity score and return top 3
      recommendations.sort((a, b) => b.score.compareTo(a.score));
      return recommendations.take(3).map((sp) => sp.product).toList();
    } catch (e) {
      debugPrint("Error calculating frequently bought together: $e");
      return [];
    }
  }

  /// Get category-based recommendations
  Future<List<Product>> _getCategoryBasedRecommendations(
    List<BillItem> currentItems,
    List<Product> allProducts,
  ) async {
    try {
      // Get categories from current items
      final currentProductIds = currentItems.map((i) => i.productId).toSet();
      final categoriesInCart = <String>{};

      for (final item in currentItems) {
        final product = allProducts.firstWhere(
          (p) => p.id == item.productId,
          orElse: () => ProductExtension.empty(),
        );
        if (product.category != null && product.category!.isNotEmpty) {
          categoriesInCart.add(product.category!);
        }
      }

      if (categoriesInCart.isEmpty) {
        // No categories found, return random products
        return allProducts
            .where((p) => !currentProductIds.contains(p.id))
            .take(3)
            .toList();
      }

      // Find products from same categories not in cart
      var sameCategoryProducts = allProducts.where((p) {
        return !currentProductIds.contains(p.id) &&
            p.category != null &&
            categoriesInCart.contains(p.category);
      }).toList();

      // Fallback: If no same-category products found, use random products
      if (sameCategoryProducts.isEmpty) {
        sameCategoryProducts = allProducts
            .where((p) => !currentProductIds.contains(p.id))
            .toList();
      }

      // Shuffle for variety
      sameCategoryProducts.shuffle();
      return sameCategoryProducts.take(3).toList();
    } catch (e) {
      debugPrint("Error getting category-based recommendations: $e");
      return allProducts
          .where((p) => !currentItems.any((item) => item.productId == p.id))
          .take(3)
          .toList();
    }
  }

  /// Get trending products (high velocity in recent period)
  Future<List<Product>> getTrendingProducts(String userId) async {
    try {
      final allProducts = await _productsRepo.watchAll(userId: userId).first;
      if (allProducts.isEmpty) return [];

      // Compare last 7 days vs previous 7 days
      final now = DateTime.now();
      final last7Days = now.subtract(const Duration(days: 7));
      final previous7Days = now.subtract(const Duration(days: 14));

      final recentFreq = await _calculateProductFrequency(userId, last7Days);
      final previousFreq = await _calculateProductFrequency(
        userId,
        previous7Days,
      );

      // Calculate velocity (growth rate)
      final velocityScores = <String, double>{};
      for (final productId in recentFreq.keys) {
        final recent = recentFreq[productId] ?? 0;
        final previous = previousFreq[productId] ?? 0;

        if (recent > 0) {
          // Velocity = (recent - previous) / max(previous, 1)
          final velocity = (recent - previous) / (previous > 0 ? previous : 1);
          velocityScores[productId] = velocity;
        }
      }

      // Sort by velocity
      final scored = velocityScores.entries
          .map((e) {
            final product = allProducts.firstWhere(
              (p) => p.id == e.key,
              orElse: () => ProductExtension.empty(),
            );
            return _ScoredProduct(product, e.value);
          })
          .where((sp) => sp.product.id.isNotEmpty)
          .toList();

      scored.sort((a, b) => b.score.compareTo(a.score));
      return scored.take(5).map((sp) => sp.product).toList();
    } catch (e) {
      debugPrint("Error getting trending products: $e");
      return [];
    }
  }

  /// Get personalized recommendations with weighted scoring
  Future<List<Product>> getPersonalizedRecommendations(
    String userId,
    List<BillItem> currentItems,
  ) async {
    try {
      final allProducts = await _productsRepo.watchAll(userId: userId).first;
      if (allProducts.isEmpty) return [];

      // Get multiple signals
      final currentProductIds = currentItems.map((i) => i.productId).toSet();
      final popularProducts = await _getPopularProducts(userId, allProducts);
      final trendingProducts = await getTrendingProducts(userId);
      final frequentlyBought = await _getFrequentlyBoughtTogether(
        userId,
        currentItems.isEmpty ? [] : currentItems,
        allProducts,
      );
      final categoryBased = await _getCategoryBasedRecommendations(
        currentItems.isEmpty ? [] : currentItems,
        allProducts,
      );

      // Build weighted scores
      final scores = <String, double>{};

      // Affinity weight: 0.4
      for (final product in frequentlyBought) {
        scores[product.id] = (scores[product.id] ?? 0) + 0.4;
      }

      // Popularity weight: 0.2
      for (final product in popularProducts) {
        scores[product.id] = (scores[product.id] ?? 0) + 0.2;
      }

      // Recency/Trending weight: 0.3
      for (final product in trendingProducts) {
        scores[product.id] = (scores[product.id] ?? 0) + 0.3;
      }

      // Category match weight: 0.1
      for (final product in categoryBased) {
        scores[product.id] = (scores[product.id] ?? 0) + 0.1;
      }

      // Remove products already in cart
      for (final productId in currentProductIds) {
        scores.remove(productId);
      }

      // Sort by score
      final sortedScores = scores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Map to products
      final recommendations = <Product>[];
      for (final entry in sortedScores.take(10)) {
        final product = allProducts.firstWhere(
          (p) => p.id == entry.key,
          orElse: () => ProductExtension.empty(),
        );
        if (product.id.isNotEmpty) {
          recommendations.add(product);
        }
      }

      return recommendations;
    } catch (e) {
      debugPrint("Error getting personalized recommendations: $e");
      return [];
    }
  }
}

/// Helper class to hold product with score
class _ScoredProduct {
  final Product product;
  final double score;

  _ScoredProduct(this.product, this.score);
}

/// Extension to add empty() factory to Product
extension ProductExtension on Product {
  static Product empty() {
    return Product(
      id: '',
      userId: '',
      name: '',
      sellingPrice: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
