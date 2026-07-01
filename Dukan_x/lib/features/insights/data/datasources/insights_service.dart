import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../config/api_config.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/repository/bills_repository.dart';
import '../../../../core/repository/products_repository.dart';

class InsightsService {
  // Dependencies
  final BillsRepository _billsRepository = sl<BillsRepository>();
  final ProductsRepository _productsRepository = sl<ProductsRepository>();
  final SessionManager _sessionManager = sl<SessionManager>();

  Future<String> _getOwnerId() async {
    return _sessionManager.ownerId ?? '';
  }

  // --- LOCAL ANALYTICS (Offline-First) ---

  Future<Either<Failure, Map<String, dynamic>>> fetchTodaySummary() async {
    try {
      final ownerId = await _getOwnerId();
      if (ownerId.isEmpty) return Left(ServerFailure("User not logged in"));

      final result = await _billsRepository.getTodaySummary(ownerId);

      if (result.isSuccess && result.data != null) {
        return Right(result.data!);
      } else {
        return Left(
          CacheFailure(result.errorMessage ?? "Failed to fetch summary"),
        );
      }
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  Future<Either<Failure, Map<String, dynamic>>> fetchStockStatus() async {
    try {
      final ownerId = await _getOwnerId();
      if (ownerId.isEmpty) return Left(ServerFailure("User not logged in"));

      final result = await _productsRepository.getStockStatusSummary(ownerId);

      if (result.isSuccess && result.data != null) {
        return Right(result.data!);
      } else {
        return Left(
          CacheFailure(result.errorMessage ?? "Failed to fetch stock status"),
        );
      }
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  Future<Either<Failure, Map<String, dynamic>>> fetchSalesPerformance() async {
    try {
      final ownerId = await _getOwnerId();
      if (ownerId.isEmpty) return Left(ServerFailure("User not logged in"));

      final result = await _productsRepository.getSalesPerformance(ownerId);

      if (result.isSuccess && result.data != null) {
        return Right(result.data!);
      } else {
        return Left(
          CacheFailure(result.errorMessage ?? "Failed to fetch performance"),
        );
      }
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  Future<Either<Failure, Map<String, dynamic>>> fetchPurchaseVsSale() async {
    try {
      final ownerId = await _getOwnerId();
      if (ownerId.isEmpty) return Left(ServerFailure("User not logged in"));

      final result = await _billsRepository.getPurchaseVsSaleStats(ownerId);

      if (result.isSuccess && result.data != null) {
        return Right(result.data!);
      } else {
        return Left(
          CacheFailure(result.errorMessage ?? "Failed to fetch stats"),
        );
      }
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  // --- CLOUD INSIGHTS (AI/LLM) ---

  Future<String> fetchAiInsight() async {
    try {
      final ownerId = await _getOwnerId();
      if (ownerId.isEmpty) {
        return "User not logged in. Unable to generate insights.";
      }

      // Try Online AI
      try {
        final token = await _sessionManager.firebaseUser
            ?.getIdToken(); // Or FirebaseAuth
        if (token == null) throw Exception("No auth token");

        final response = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/insights/ai-insight'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            "owner_uid": ownerId,
            "date": DateTime.now().toIso8601String(),
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['ai_insight'] ?? "No insight available.";
        }
      } catch (_) {
        // Fallthrough to local
      }

      // Local Fallback: Simple Rule-Based Insight
      final summary = await _billsRepository.getTodaySummary(ownerId);
      if (summary.isSuccess) {
        final sales = summary.data?['total_sales'] ?? 0.0;
        if (sales == 0) {
          return "No sales yet today. Try promoting slow-moving stock!";
        }
        if (sales > 5000) {
          return "Great job today! Sales are looking strong. consider replenishing stock.";
        }
        return "Steady sales today. Keep it up!";
      }

      return "Insights unavailable (Offline)";
    } catch (e) {
      return "Welcome! Once you start recording sales, I'll provide AI-powered insights here.";
    }
  }
}

final insightsServiceProvider = Provider<InsightsService>((ref) {
  return InsightsService();
});
