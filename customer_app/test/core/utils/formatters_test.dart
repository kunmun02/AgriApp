import 'package:flutter_test/flutter_test.dart';
import 'package:customer_app/core/utils/formatters.dart';

void main() {
  group('Formatters.inr', () {
    test('formats 1234567.5 as ₹12,34,567.50 (acceptance criterion)', () {
      expect(Formatters.inr(1234567.5), equals('₹12,34,567.50'));
    });

    test('formats zero as ₹0.00', () {
      expect(Formatters.inr(0), equals('₹0.00'));
    });

    test('formats 1000 as ₹1,000.00', () {
      expect(Formatters.inr(1000), equals('₹1,000.00'));
    });

    test('formats 100000 as ₹1,00,000.00 (Indian lakh grouping)', () {
      expect(Formatters.inr(100000), equals('₹1,00,000.00'));
    });

    test('formats 0.5 as ₹0.50', () {
      expect(Formatters.inr(0.5), equals('₹0.50'));
    });

    test('rounds to 2 decimal places', () {
      expect(Formatters.inr(1.999), equals('₹2.00'));
    });
  });

  group('Formatters.dateShort', () {
    test('formats a known date correctly', () {
      expect(
        Formatters.dateShort(DateTime(2024, 1, 5)),
        equals('5 Jan 2024'),
      );
    });

    test('formats a double-digit day correctly', () {
      expect(
        Formatters.dateShort(DateTime(2024, 12, 25)),
        equals('25 Dec 2024'),
      );
    });
  });
}
