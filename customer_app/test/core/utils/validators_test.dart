import 'package:flutter_test/flutter_test.dart';
import 'package:customer_app/core/utils/validators.dart';

void main() {
  // ── email ──────────────────────────────────────────────────────────────
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

    test('spaces in address return error', () {
      expect(Validators.email('user @example.com'), isNotNull);
    });
  });

  // ── password ───────────────────────────────────────────────────────────
  group('Validators.password', () {
    test('8 chars returns null', () {
      expect(Validators.password('12345678'), isNull);
    });

    test('more than 8 chars returns null', () {
      expect(Validators.password('supersecret'), isNull);
    });

    test('7 chars returns error', () {
      expect(Validators.password('1234567'), isNotNull);
    });

    test('empty returns error', () {
      expect(Validators.password(''), isNotNull);
    });

    test('null returns error', () {
      expect(Validators.password(null), isNotNull);
    });
  });

  // ── fullName ───────────────────────────────────────────────────────────
  group('Validators.fullName', () {
    test('valid name returns null', () {
      expect(Validators.fullName('Ravi Kumar'), isNull);
    });

    test('exactly 2 chars returns null', () {
      expect(Validators.fullName('Jo'), isNull);
    });

    test('1 char returns error', () {
      expect(Validators.fullName('J'), isNotNull);
    });

    test('81 chars returns error', () {
      expect(Validators.fullName('A' * 81), isNotNull);
    });

    test('80 chars returns null', () {
      expect(Validators.fullName('A' * 80), isNull);
    });

    test('empty returns error', () {
      expect(Validators.fullName(''), isNotNull);
    });

    test('whitespace-only returns error', () {
      expect(Validators.fullName('   '), isNotNull);
    });
  });

  // ── phone ──────────────────────────────────────────────────────────────
  group('Validators.phone', () {
    test('valid 10-digit number starting 9 returns null', () {
      expect(Validators.phone('9876543210'), isNull);
    });

    test('valid 10-digit number starting 6 returns null', () {
      expect(Validators.phone('6000000000'), isNull);
    });

    test('starts with 5 returns error', () {
      expect(Validators.phone('5876543210'), isNotNull);
    });

    test('starts with 1 returns error', () {
      expect(Validators.phone('1234567890'), isNotNull);
    });

    test('9 digits returns error', () {
      expect(Validators.phone('987654321'), isNotNull);
    });

    test('11 digits returns error', () {
      expect(Validators.phone('98765432101'), isNotNull);
    });

    test('null returns error', () {
      expect(Validators.phone(null), isNotNull);
    });
  });

  // ── postalCode ─────────────────────────────────────────────────────────
  group('Validators.postalCode', () {
    test('valid PIN 110001 returns null', () {
      expect(Validators.postalCode('110001'), isNull);
    });

    test('starts with 0 returns error', () {
      expect(Validators.postalCode('012345'), isNotNull);
    });

    test('5 digits returns error', () {
      expect(Validators.postalCode('11000'), isNotNull);
    });

    test('7 digits returns error', () {
      expect(Validators.postalCode('1100011'), isNotNull);
    });

    test('letters return error', () {
      expect(Validators.postalCode('11000A'), isNotNull);
    });

    test('null returns error', () {
      expect(Validators.postalCode(null), isNotNull);
    });
  });

  // ── cartQuantity ────────────────────────────────────────────────────────
  group('Validators.cartQuantity', () {
    test('1 returns null', () {
      expect(Validators.cartQuantity(1), isNull);
    });

    test('99 returns null', () {
      expect(Validators.cartQuantity(99), isNull);
    });

    test('50 returns null', () {
      expect(Validators.cartQuantity(50), isNull);
    });

    test('0 returns error', () {
      expect(Validators.cartQuantity(0), isNotNull);
    });

    test('100 returns error', () {
      expect(Validators.cartQuantity(100), isNotNull);
    });

    test('null returns error', () {
      expect(Validators.cartQuantity(null), isNotNull);
    });
  });

  // ── price ──────────────────────────────────────────────────────────────
  group('Validators.price', () {
    test('0 returns null', () {
      expect(Validators.price(0), isNull);
    });

    test('positive value returns null', () {
      expect(Validators.price(999.99), isNull);
    });

    test('negative returns error', () {
      expect(Validators.price(-1), isNotNull);
    });

    test('null returns error', () {
      expect(Validators.price(null), isNotNull);
    });
  });

  // ── taxPercent ─────────────────────────────────────────────────────────
  group('Validators.taxPercent', () {
    test('0 returns null', () {
      expect(Validators.taxPercent(0), isNull);
    });

    test('100 returns null', () {
      expect(Validators.taxPercent(100), isNull);
    });

    test('5.5 returns null', () {
      expect(Validators.taxPercent(5.5), isNull);
    });

    test('negative returns error', () {
      expect(Validators.taxPercent(-1), isNotNull);
    });

    test('101 returns error', () {
      expect(Validators.taxPercent(101), isNotNull);
    });

    test('null returns error', () {
      expect(Validators.taxPercent(null), isNotNull);
    });
  });

  // ── sku ────────────────────────────────────────────────────────────────
  group('Validators.sku', () {
    test('valid 3-char SKU returns null', () {
      expect(Validators.sku('ABC'), isNull);
    });

    test('valid 40-char SKU returns null', () {
      expect(Validators.sku('A' * 40), isNull);
    });

    test('valid SKU with hyphens returns null', () {
      expect(Validators.sku('SEED-001'), isNull);
    });

    test('valid SKU with digits returns null', () {
      expect(Validators.sku('SKU123'), isNull);
    });

    test('2 chars returns error', () {
      expect(Validators.sku('AB'), isNotNull);
    });

    test('41 chars returns error', () {
      expect(Validators.sku('A' * 41), isNotNull);
    });

    test('lowercase letters return error', () {
      expect(Validators.sku('abc'), isNotNull);
    });

    test('special chars return error', () {
      expect(Validators.sku('SKU@001'), isNotNull);
    });

    test('null returns error', () {
      expect(Validators.sku(null), isNotNull);
    });

    test('empty returns error', () {
      expect(Validators.sku(''), isNotNull);
    });
  });
}
