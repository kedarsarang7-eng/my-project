// Worked-example test for D11 computer_shop business rules
// (clauses 2.16 + 2.19 of `bugfix.md`).

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/computer_shop/utils/computer_shop_business_rules.dart';

void main() {
  group('ComputerShopBusinessRules.isValidJobTransition', () {
    test('intake -> diagnosis is allowed', () {
      expect(
        ComputerShopBusinessRules.isValidJobTransition(
          ComputerJobStatus.intake,
          ComputerJobStatus.diagnosis,
        ),
        isTrue,
      );
    });
    test('intake -> qa is rejected', () {
      expect(
        ComputerShopBusinessRules.isValidJobTransition(
          ComputerJobStatus.intake,
          ComputerJobStatus.qa,
        ),
        isFalse,
      );
    });
    test('cancellation allowed from any pre-delivery state', () {
      for (final s in ComputerJobStatus.values) {
        final allowed = ComputerShopBusinessRules.isValidJobTransition(
          s,
          ComputerJobStatus.cancelled,
        );
        final expected =
            s != ComputerJobStatus.cancelled &&
            s != ComputerJobStatus.delivered;
        expect(allowed, expected, reason: 'cancel from $s');
      }
    });
  });

  group('ComputerShopBusinessRules.isAmcDue', () {
    test('expiry within window -> due', () {
      expect(
        ComputerShopBusinessRules.isAmcDue(
          DateTime(2024, 7, 1),
          DateTime(2024, 6, 15),
        ),
        isTrue,
      );
    });
    test('expiry already past -> due', () {
      expect(
        ComputerShopBusinessRules.isAmcDue(
          DateTime(2024, 5, 1),
          DateTime(2024, 6, 15),
        ),
        isTrue,
      );
    });
    test('expiry beyond window -> not due', () {
      expect(
        ComputerShopBusinessRules.isAmcDue(
          DateTime(2024, 9, 1),
          DateTime(2024, 6, 15),
        ),
        isFalse,
      );
    });
  });
}
