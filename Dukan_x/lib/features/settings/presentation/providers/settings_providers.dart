import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/bill_template_repository_impl.dart';
import '../../domain/repositories/bill_template_repository.dart';

final billTemplateRepositoryProvider = Provider<BillTemplateRepository>((ref) {
  return BillTemplateRepositoryImpl();
});

final currentTemplateProvider = FutureProvider((ref) async {
  final repo = ref.watch(billTemplateRepositoryProvider);
  return repo.getTemplate();
});
