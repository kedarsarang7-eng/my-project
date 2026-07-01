import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/bill.dart';

abstract class BillingRepository {
  Future<Either<Failure, String>> saveBill(Bill bill);
  Future<Either<Failure, List<Bill>>> getBills();
  Future<Either<Failure, Bill>> getBillById(String id);
}
