import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/billing/services/commission_input.dart';

void main() {
  group('CommissionInput validation (Requirement 5.6)', () {
    // ===== FlatCommission =====

    group('FlatCommission', () {
      test('valid flat commission (0 paise) passes validation', () {
        const commission = FlatCommission(0);
        expect(commission.validate(), isNull);
        expect(commission.amountPaise, 0);
        expect(commission.typeString, 'flat');
        expect(commission.isFlat, isTrue);
        expect(commission.isPercentage, isFalse);
      });

      test('valid flat commission (positive paise) passes validation', () {
        const commission = FlatCommission(5000);
        expect(commission.validate(), isNull);
        expect(commission.amountPaise, 5000);
      });

      test('negative flat commission is rejected', () {
        const commission = FlatCommission(-1);
        final error = commission.validate();
        expect(error, isNotNull);
        expect(error, contains('negative'));
      });

      test('large flat commission passes validation', () {
        const commission = FlatCommission(99999999); // ₹9,99,999.99
        expect(commission.validate(), isNull);
        expect(commission.amountPaise, 99999999);
      });
    });

    // ===== PercentageCommission =====

    group('PercentageCommission', () {
      test('valid percentage (5.25%, 525 paise) passes validation', () {
        const commission = PercentageCommission(rate: 5.25, resultPaise: 525);
        expect(commission.validate(), isNull);
        expect(commission.amountPaise, 525);
        expect(commission.typeString, 'percentage');
        expect(commission.isFlat, isFalse);
        expect(commission.isPercentage, isTrue);
      });

      test('rate of 0.00% passes validation', () {
        const commission = PercentageCommission(rate: 0.0, resultPaise: 0);
        expect(commission.validate(), isNull);
      });

      test('rate of 100.00% passes validation', () {
        const commission = PercentageCommission(
          rate: 100.0,
          resultPaise: 10000,
        );
        expect(commission.validate(), isNull);
      });

      test('rate preserves ≥2 decimal places', () {
        const commission = PercentageCommission(rate: 3.75, resultPaise: 375);
        expect(commission.validate(), isNull);
        // The rate field stores the percentage with at least 2 decimal places
        expect(commission.rate, 3.75);
      });

      test('negative rate is rejected', () {
        const commission = PercentageCommission(rate: -0.01, resultPaise: 0);
        final error = commission.validate();
        expect(error, isNotNull);
        expect(error, contains('negative'));
      });

      test('rate > 100.00% is rejected', () {
        const commission = PercentageCommission(
          rate: 100.01,
          resultPaise: 10001,
        );
        final error = commission.validate();
        expect(error, isNotNull);
        expect(error, contains('100.00%'));
      });

      test('negative resultPaise is rejected', () {
        const commission = PercentageCommission(rate: 5.0, resultPaise: -1);
        final error = commission.validate();
        expect(error, isNotNull);
        expect(error, contains('negative'));
      });
    });
  });
}
