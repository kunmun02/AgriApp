/// Client-side validation functions.
///
/// Every rule mirrors a server-side constraint described in
/// 00_MASTER §3.13 Validation summary.
class Validators {
  Validators._();

  static final RegExp _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _phoneRe = RegExp(r'^[6-9][0-9]{9}$');
  static final RegExp _postalRe = RegExp(r'^[1-9][0-9]{5}$');
  static final RegExp _skuRe = RegExp(r'^[A-Z0-9\-]{3,40}$');

  /// RFC-ish email validation.
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required.';
    if (!_emailRe.hasMatch(value.trim())) return 'Enter a valid email address.';
    return null;
  }

  /// Password must be at least 8 characters.
  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required.';
    if (value.length < 8) return 'Password must be at least 8 characters.';
    return null;
  }

  /// Full name: 2–80 characters, trimmed non-empty.
  static String? fullName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Full name is required.';
    final trimmed = value.trim();
    if (trimmed.length < 2) return 'Name must be at least 2 characters.';
    if (trimmed.length > 80) return 'Name must be 80 characters or fewer.';
    return null;
  }

  /// Indian mobile phone number: 10 digits starting 6–9.
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required.';
    }
    if (!_phoneRe.hasMatch(value.trim())) {
      return 'Enter a valid 10-digit Indian mobile number.';
    }
    return null;
  }

  /// Indian postal (PIN) code: 6 digits, first digit 1–9.
  static String? postalCode(String? value) {
    if (value == null || value.trim().isEmpty) return 'PIN code is required.';
    if (!_postalRe.hasMatch(value.trim())) {
      return 'Enter a valid 6-digit PIN code.';
    }
    return null;
  }

  /// Cart quantity: integer 1–99.
  static String? cartQuantity(int? value) {
    if (value == null) return 'Quantity is required.';
    if (value < 1) return 'Quantity must be at least 1.';
    if (value > 99) return 'Quantity cannot exceed 99.';
    return null;
  }

  /// Product price or MRP: must be non-negative.
  static String? price(double? value) {
    if (value == null) return 'Price is required.';
    if (value < 0) return 'Price must be 0 or greater.';
    return null;
  }

  /// Product tax percent: 0–100.
  static String? taxPercent(double? value) {
    if (value == null) return 'Tax percent is required.';
    if (value < 0) return 'Tax percent must be 0 or greater.';
    if (value > 100) return 'Tax percent cannot exceed 100.';
    return null;
  }

  /// Product SKU: 3–40 chars, uppercase letters / digits / hyphens only.
  static String? sku(String? value) {
    if (value == null || value.trim().isEmpty) return 'SKU is required.';
    if (!_skuRe.hasMatch(value.trim())) {
      return 'SKU must be 3–40 characters: uppercase letters, digits, hyphens only.';
    }
    return null;
  }
}
