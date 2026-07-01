// Worked-example test for D11 book_store business rules
// (clauses 2.16 + 2.19 of `bugfix.md`).

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/book_store/utils/book_store_business_rules.dart';

void main() {
  group('BookStoreBusinessRules.isValidIsbn', () {
    test('valid ISBN-10 with X checksum', () {
      expect(BookStoreBusinessRules.isValidIsbn('0306406152'), isTrue);
      expect(BookStoreBusinessRules.isValidIsbn('097522980X'), isTrue);
    });
    test('valid ISBN-13', () {
      expect(BookStoreBusinessRules.isValidIsbn('9780306406157'), isTrue);
      expect(BookStoreBusinessRules.isValidIsbn('978-0-306-40615-7'), isTrue);
    });
    test('rejects bad checksum', () {
      expect(BookStoreBusinessRules.isValidIsbn('0306406151'), isFalse);
      expect(BookStoreBusinessRules.isValidIsbn('9780306406150'), isFalse);
    });
    test('rejects wrong-length input', () {
      expect(BookStoreBusinessRules.isValidIsbn('123'), isFalse);
      expect(BookStoreBusinessRules.isValidIsbn(''), isFalse);
    });
  });

  group('BookStoreBusinessRules.suggestedResalePrice', () {
    test('brand new -> 5% off', () {
      expect(
        BookStoreBusinessRules.suggestedResalePrice(
          1000,
          BookCondition.brandNew,
        ),
        equals(950.0),
      );
    });
    test('damaged -> 75% off', () {
      expect(
        BookStoreBusinessRules.suggestedResalePrice(
          1000,
          BookCondition.damaged,
        ),
        equals(250.0),
      );
    });
    test('negative input clamps to 0', () {
      expect(
        BookStoreBusinessRules.suggestedResalePrice(-50, BookCondition.good),
        equals(0.0),
      );
    });
  });
}
