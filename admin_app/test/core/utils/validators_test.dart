import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/core/utils/validators.dart';

void main() {
  group('Validators.email', () {
    test('valid address returns null', () {
      expect(Validators.email('user@example.com'), isNull);
    });

    test('null returns required error', () {
      expect(Validators.email(null), isNotNull);
    });

    test('empty string returns required error', () {
      expect(Validators.email(''), isNotNull);
    });

    test('missing @ returns error', () {
      expect(Validators.email('userexample.com'), isNotNull);
    });

    test('missing TLD returns error', () {
      expect(Validators.email('user@example'), isNotNull);
    });
  });

  group('Validators.password', () {
    test('8 chars returns null', () {
      expect(Validators.password('12345678'), isNull);
    });

    test('7 chars returns error', () {
      expect(Validators.password('1234567'), isNotNull);
    });

    test('null returns error', () {
      expect(Validators.password(null), isNotNull);
    });
  });

  group('Validators.fullName', () {
    test('valid name returns null', () {
      expect(Validators.fullName('Priya Singh'), isNull);
    });

    test('1 char returns error', () {
      expect(Validators.fullName('J'), isNotNull);
    });

    test('81 chars returns error', () {
      expect(Validators.fullName('A' * 81), isNotNull);
    });

    test('whitespace-only returns error', () {
      expect(Validators.fullName('   '), isNotNull);
    });
  });

  group('Validators.phone', () {
    test('valid 10-digit number starting 9 returns null', () {
      expect(Validators.phone('9876543210'), isNull);
    });

    test('starts with 5 returns error', () {
      expect(Validators.phone('5876543210'), isNotNull);
    });

    test('9 digits returns error', () {
      expect(Validators.phone('987654321'), isNotNull);
    });
  });

  group('Validators.postalCode', () {
    test('valid PIN 400001 returns null', () {
      expect(Validators.postalCode('400001'), isNull);
    });

    test('starts with 0 returns error', () {
      expect(Validators.postalCode('012345'), isNotNull);
    });

    test('5 digits returns error', () {
      expect(Validators.postalCode('11000'), isNotNull);
    });
  });

  group('Validators.cartQuantity', () {
    test('1 returns null', () {
      expect(Validators.cartQuantity(1), isNull);
    });

    test('99 returns null', () {
      expect(Validators.cartQuantity(99), isNull);
    });

    test('0 returns error', () {
      expect(Validators.cartQuantity(0), isNotNull);
    });

    test('100 returns error', () {
      expect(Validators.cartQuantity(100), isNotNull);
    });
  });

  group('Validators.price', () {
    test('0 returns null', () {
      expect(Validators.price(0), isNull);
    });

    test('positive value returns null', () {
      expect(Validators.price(499.99), isNull);
    });

    test('negative returns error', () {
      expect(Validators.price(-0.01), isNotNull);
    });
  });

  group('Validators.taxPercent', () {
    test('0 returns null', () {
      expect(Validators.taxPercent(0), isNull);
    });

    test('100 returns null', () {
      expect(Validators.taxPercent(100), isNull);
    });

    test('101 returns error', () {
      expect(Validators.taxPercent(101), isNotNull);
    });
  });

  group('Validators.sku', () {
    test('valid SKU returns null', () {
      expect(Validators.sku('SEED-001'), isNull);
    });

    test('2 chars returns error', () {
      expect(Validators.sku('AB'), isNotNull);
    });

    test('lowercase returns error', () {
      expect(Validators.sku('abc'), isNotNull);
    });

    test('41 chars returns error', () {
      expect(Validators.sku('A' * 41), isNotNull);
    });
  });
}
