import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/failures.dart';
import '../../../../providers/app_state_providers.dart';

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepository(
    apiClient: sl<ApiClient>(),
    tenantIdResolver: () => ref.read(authStateProvider).userId,
  );
});

class SchoolOrder {
  final String id;
  final String schoolName;
  final String grade;
  final int totalSets;
  final int fulfilledSets;
  final String status;

  SchoolOrder({
    required this.id,
    required this.schoolName,
    required this.grade,
    required this.totalSets,
    required this.fulfilledSets,
    required this.status,
  });

  factory SchoolOrder.fromJson(Map<String, dynamic> json) {
    return SchoolOrder(
      id: json['id'],
      schoolName: json['schoolName'],
      grade: json['grade'],
      totalSets: json['totalSets'],
      fulfilledSets: json['fulfilledSets'],
      status: json['status'],
    );
  }
}

class Consignment {
  final String id;
  final String publisherId;
  final String publisherName;
  final int totalBooksReceived;
  final int totalBooksSold;
  final double settlementAmount;
  final String status;

  Consignment({
    required this.id,
    required this.publisherId,
    required this.publisherName,
    required this.totalBooksReceived,
    required this.totalBooksSold,
    required this.settlementAmount,
    required this.status,
  });

  factory Consignment.fromJson(Map<String, dynamic> json) {
    return Consignment(
      id: json['id'],
      publisherId: json['publisherId'],
      publisherName: json['publisherName'],
      totalBooksReceived: json['totalBooksReceived'],
      totalBooksSold: json['totalBooksSold'],
      settlementAmount: (json['settlementAmount'] ?? 0).toDouble(),
      status: json['status'],
    );
  }
}

class BookRepository {
  final ApiClient apiClient;

  BookRepository({required this.apiClient});

  Future<Either<Failure, List<SchoolOrder>>> getSchoolOrders() async {
    try {
      final response = await apiClient.get('/books/school-orders');
      final items = (response.data!['orders'] as List)
          .map((item) => SchoolOrder.fromJson(item))
          .toList();
      return Right(items);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, bool>> fulfillSchoolOrder(
    String orderId,
    int setsToFulfill,
  ) async {
    try {
      await apiClient.post(
        '/books/school-orders/$orderId/fulfill',
        body: {'sets': setsToFulfill},
      );
      return const Right(true);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, List<Consignment>>> getConsignments() async {
    try {
      final response = await apiClient.get('/books/consignments');
      final items = (response.data!['consignments'] as List)
          .map((item) => Consignment.fromJson(item))
          .toList();
      return Right(items);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, bool>> processSettlement(
    String consignmentId,
    double amount,
  ) async {
    try {
      await apiClient.post(
        '/books/consignments/$consignmentId/settle',
        body: {'amount': amount},
      );
      return const Right(true);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
