/// Converts a human-readable attribute name into a snake_case attribute key.
///
/// Rules (applied in order):
///   1. Trim surrounding whitespace.
///   2. Lowercase the whole string.
///   3. Replace any run of whitespace or hyphens with a single `_`.
///   4. Strip any character that is not `[a-z0-9_]`.
///   5. Replace runs of `_` with a single `_`.
///   6. Strip leading/trailing `_`.
///   7. Ensure the result starts with `[a-z]` — if it doesn't (e.g. starts
///      with a digit), prepend `attr_`.
///   8. Truncate to 40 characters (DB constraint: `^[a-z][a-z0-9_]{1,39}$`
///      means max 40 total).
///
/// Examples:
///   "Soil Type"  → `soil_type`
///   "N-P-K %"    → `n_p_k`
///   "123abc"     → `attr_123abc`
///   "  Organic?" → `organic`
abstract final class AttributeKeyGenerator {
  static final _pattern = RegExp(r'^[a-z][a-z0-9_]{1,39}$');

  /// Generate a candidate key from [name].
  ///
  /// Returns an empty string only when [name] is blank or contains nothing
  /// useful after stripping.
  static String fromName(String name) {
    var s = name.trim().toLowerCase();

    // Spaces and hyphens → underscore.
    s = s.replaceAll(RegExp(r'[\s\-]+'), '_');

    // Strip non-alphanumeric/underscore chars.
    s = s.replaceAll(RegExp(r'[^a-z0-9_]'), '');

    // Collapse runs of underscores.
    s = s.replaceAll(RegExp(r'_+'), '_');

    // Trim leading/trailing underscores.
    s = s.replaceAll(RegExp(r'^_+|_+$'), '');

    if (s.isEmpty) return '';

    // Ensure first char is [a-z].
    if (!RegExp(r'^[a-z]').hasMatch(s)) {
      s = 'attr_$s';
    }

    // Truncate to 40 chars.
    if (s.length > 40) s = s.substring(0, 40);

    // Remove any trailing underscore introduced by truncation.
    s = s.replaceAll(RegExp(r'_+$'), '');

    return s;
  }

  /// Returns `true` when [key] matches the DB pattern `^[a-z][a-z0-9_]{1,39}$`.
  static bool isValid(String key) => _pattern.hasMatch(key);
}
