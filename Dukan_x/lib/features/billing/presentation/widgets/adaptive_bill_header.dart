import 'package:flutter/material.dart';
import '../../../../core/billing/business_strategy_factory.dart';
import '../../../../models/bill.dart';
import '../../../../models/business_type.dart';

class AdaptiveBillHeader extends StatelessWidget {
  final BusinessType businessType;
  final Bill bill;
  final Function(Bill) onUpdate;
  final bool isDark;

  const AdaptiveBillHeader({
    super.key,
    required this.businessType,
    required this.bill,
    required this.onUpdate,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final strategy = BusinessStrategyFactory.getStrategy(businessType);
    return strategy.buildBillHeaderFields(context, bill, onUpdate, isDark);
  }
}
