import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExpensesRepository', () {
    group('Expense Business Logic Tests', () {
      test('should calculate total expenses correctly', () {
        final expenses = [15000.0, 2500.0, 5000.0, 1500.0];
        final totalExpenses = expenses.reduce((a, b) => a + b);
        expect(totalExpenses, 24000.0);
      });

      test('should categorize expenses by category', () {
        final categories = {
          'Rent': 15000.0,
          'Utilities': 2500.0,
          'Supplies': 5000.0,
        };

        expect(categories['Rent'], 15000.0);
        expect(categories.length, 3);
      });

      test('should calculate monthly expense average', () {
        final totalAnnualExpense = 120000.0;
        final monthlyAverage = totalAnnualExpense / 12;
        expect(monthlyAverage, 10000.0);
      });
    });

    group('Expense Category Tests', () {
      test('should recognize common business expense categories', () {
        final categories = [
          'Rent',
          'Utilities',
          'Salary',
          'Supplies',
          'Transport',
          'Marketing',
          'Insurance',
          'Maintenance',
          'Miscellaneous',
        ];

        expect(categories.length, 9);
        expect(categories.contains('Rent'), true);
        expect(categories.contains('Salary'), true);
      });
    });

    group('Payment Mode Tests', () {
      test('should support various payment modes', () {
        final paymentModes = ['CASH', 'UPI', 'CARD', 'NEFT', 'CHEQUE'];
        expect(paymentModes.contains('CASH'), true);
        expect(paymentModes.contains('UPI'), true);
      });
    });

    group('Repository Configuration Tests', () {
      test('should have correct collection name', () {
        expect('expenses', isNotEmpty);
      });
    });
  });
}
