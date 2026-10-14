import 'package:intl/intl.dart';

/// Formatting utilities for currency and dates.
///
/// All monetary values use `en_IN` locale so amounts display with the
/// Indian numbering system (lakhs / crores) and the ₹ symbol.
class Formatters {
  Formatters._();

  static final NumberFormat _inrFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final DateFormat _dateShortFormat = DateFormat('d MMM yyyy');

  /// Formats [amount] as Indian Rupees.
  ///
  /// Example: `Formatters.inr(1234567.5)` → `₹12,34,567.50`
  static String inr(double amount) => _inrFormat.format(amount);

  /// Formats a [DateTime] as a short human-readable date.
  ///
  /// Example: `Formatters.dateShort(DateTime(2024, 1, 5))` → `5 Jan 2024`
  static String dateShort(DateTime date) => _dateShortFormat.format(date);
}
