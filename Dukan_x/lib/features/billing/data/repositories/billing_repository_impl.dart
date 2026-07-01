import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../services/local_storage_service.dart';
import '../../domain/entities/bill.dart';
import '../../domain/repositories/billing_repository.dart';
import '../models/mappers.dart';

class BillingRepositoryImpl implements BillingRepository {
  final LocalStorageService _localStorageService;

  BillingRepositoryImpl(this._localStorageService);

  @override
  Future<Either<Failure, List<Bill>>> getBills() async {
    try {
      final bills = _localStorageService.getAllBills();
      return Right(bills.map((b) => b.toEntity()).toList());
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> saveBill(Bill bill) async {
    try {
      final billModel = bill.toModel();
      await _localStorageService.saveBill(billModel);
      return Right(bill.id);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Bill>> getBillById(String id) async {
    try {
      final bill = _localStorageService.getBill(id);
      if (bill != null) {
        return Right(bill.toEntity());
      } else {
        return Left(CacheFailure('Bill not found'));
      }
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
