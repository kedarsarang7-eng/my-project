import 'dart:convert';
import '../../domain/entities/bill_template.dart';
import '../../domain/repositories/bill_template_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BillTemplateRepositoryImpl implements BillTemplateRepository {
  static const String _storageKey = 'bill_template_config';

  @override
  Future<BillTemplate> getTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr != null) {
      try {
        final map = jsonDecode(jsonStr);
        return BillTemplate(
          id: map['id'] ?? 'default',
          name: map['name'] ?? 'Standard',
          showLogo: map['showLogo'] ?? true,
          showShopName: map['showShopName'] ?? true,
          showAddress: map['showAddress'] ?? true,
          showPhone: map['showPhone'] ?? true,
          showTax: map['showTax'] ?? true,
          headerAlignment: map['headerAlignment'] ?? 'center',
          footerText: map['footerText'] ?? 'Thank you for shopping!',
        );
      } catch (e) {
        return const BillTemplate();
      }
    }
    return const BillTemplate();
  }

  @override
  Future<void> saveTemplate(BillTemplate template) async {
    final prefs = await SharedPreferences.getInstance();
    final map = {
      'id': template.id,
      'name': template.name,
      'showLogo': template.showLogo,
      'showShopName': template.showShopName,
      'showAddress': template.showAddress,
      'showPhone': template.showPhone,
      'showTax': template.showTax,
      'headerAlignment': template.headerAlignment,
      'footerText': template.footerText,
    };
    await prefs.setString(_storageKey, jsonEncode(map));
  }
}
