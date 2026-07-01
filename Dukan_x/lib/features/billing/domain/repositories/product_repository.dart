import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/product.dart';

abstract class ProductRepository {
  Future<Either<Failure, List<Product>>> searchProducts(String query);
  Future<Either<Failure, List<Product>>> getAllProducts();
  Future<Either<Failure, void>> saveProduct(Product product);
}
