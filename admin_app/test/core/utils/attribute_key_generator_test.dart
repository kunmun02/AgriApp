import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/core/utils/attribute_key_generator.dart';

void main() {
  group('AttributeKeyGenerator.fromName', () {
    // ── Basic transformations ────────────────────────────────────────────

    test('"Soil Type" → soil_type', () {
      expect(AttributeKeyGenerator.fromName('Soil Type'), 'soil_type');
    });

    test('"nitrogen %" strips invalid char and returns nitrogen', () {
      expect(AttributeKeyGenerator.fromName('nitrogen %'), 'nitrogen');
    });

    test('"N-P-K" → n_p_k', () {
      expect(AttributeKeyGenerator.fromName('N-P-K'), 'n_p_k');
    });

    test('"Organic Matter" → organic_matter', () {
      expect(
          AttributeKeyGenerator.fromName('Organic Matter'), 'organic_matter');
    });

    test('" Organic? " trims and strips → organic', () {
      expect(AttributeKeyGenerator.fromName('  Organic?  '), 'organic');
    });

    test('already snake_case unchanged', () {
      expect(AttributeKeyGenerator.fromName('soil_type'), 'soil_type');
    });

    test('multiple spaces collapse to single underscore', () {
      expect(AttributeKeyGenerator.fromName('a  b'), 'a_b');
    });

    test('leading/trailing underscores stripped', () {
      expect(AttributeKeyGenerator.fromName('_hello_'), 'hello');
    });

    test('"123abc" starts with digit → prepends attr_', () {
      final result = AttributeKeyGenerator.fromName('123abc');
      expect(result, startsWith('attr_'));
    });

    test('empty string returns empty', () {
      expect(AttributeKeyGenerator.fromName(''), '');
    });

    test('all-invalid chars returns empty', () {
      expect(AttributeKeyGenerator.fromName('???!!!'), '');
    });

    test('long name truncated to 40 chars', () {
      final longName = 'abcdefgh ' * 6; // produces a long snake_case
      final result = AttributeKeyGenerator.fromName(longName);
      expect(result.length, lessThanOrEqualTo(40));
    });

    test('result passes isValid when non-empty', () {
      final cases = [
        'Soil Type',
        'Nitrogen %',
        'pH Value',
        'Water Content (ml)',
        'Brand',
      ];
      for (final name in cases) {
        final key = AttributeKeyGenerator.fromName(name);
        if (key.isNotEmpty) {
          expect(
            AttributeKeyGenerator.isValid(key),
            isTrue,
            reason: 'key "$key" from name "$name" should be valid',
          );
        }
      }
    });
  });

  group('AttributeKeyGenerator.isValid', () {
    test('valid key passes', () {
      expect(AttributeKeyGenerator.isValid('nitrogen_percent'), isTrue);
    });

    test('single letter key (too short: min length 2 total)', () {
      // Pattern requires {1,39} after first char so "ab" (2 total) is the minimum.
      expect(AttributeKeyGenerator.isValid('a'), isFalse);
    });

    test('valid two-char key passes', () {
      expect(AttributeKeyGenerator.isValid('ab'), isTrue);
    });

    test('starts with digit fails', () {
      expect(AttributeKeyGenerator.isValid('1abc'), isFalse);
    });

    test('contains uppercase fails', () {
      expect(AttributeKeyGenerator.isValid('Nitrogen'), isFalse);
    });

    test('contains hyphen fails', () {
      expect(AttributeKeyGenerator.isValid('n-p-k'), isFalse);
    });

    test('exactly 40 chars passes', () {
      // First char a-z, 39 more chars
      final key = 'a${'b' * 39}'; // 40 chars
      expect(AttributeKeyGenerator.isValid(key), isTrue);
    });

    test('41 chars fails', () {
      final key = 'a${'b' * 40}'; // 41 chars
      expect(AttributeKeyGenerator.isValid(key), isFalse);
    });

    test('empty string fails', () {
      expect(AttributeKeyGenerator.isValid(''), isFalse);
    });
  });
}
