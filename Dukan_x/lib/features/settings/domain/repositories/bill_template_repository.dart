import '../entities/bill_template.dart';

abstract class BillTemplateRepository {
  Future<BillTemplate> getTemplate();
  Future<void> saveTemplate(BillTemplate template);
}
