/// Application-wide constants.
class AppConstants {
  AppConstants._();

  /// Default page size for paginated lists.
  static const int pageSize = 20;

  /// Maximum quantity of a single product in the cart.
  static const int cartQtyMax = 99;

  /// Currency symbol.
  static const String currencySymbol = '₹';

  /// Currency locale for `NumberFormat`.
  static const String currencyLocale = 'en_IN';
}
