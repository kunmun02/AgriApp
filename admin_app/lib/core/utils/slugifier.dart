/// Converts a display name into a URL-safe lowercase-kebab slug.
///
/// Rules:
///   1. Lowercase.
///   2. Replace spaces and underscores with `-`.
///   3. Strip any character that is not `[a-z0-9-]`.
///   4. Collapse consecutive `-` into one.
///   5. Trim leading/trailing `-`.
///   6. Truncate to 80 chars.
abstract final class Slugifier {
  static String slugify(String name) {
    var s = name.toLowerCase();
    s = s.replaceAll(RegExp(r'[\s_]+'), '-');
    s = s.replaceAll(RegExp(r'[^a-z0-9\-]'), '');
    s = s.replaceAll(RegExp(r'-{2,}'), '-');
    s = s.replaceAll(RegExp(r'^-+|-+$'), '');
    if (s.length > 80) s = s.substring(0, 80);
    return s;
  }

  /// Returns `{slug}-{suffix}` for collision retries (suffix = 2, 3, …).
  static String withSuffix(String base, int suffix) => '$base-$suffix';

  /// Sanitises a storage file name: lowercase, spaces→`-`,
  /// keep `[a-z0-9._-]`, strip else, max 60 chars.
  static String sanitizeFileName(String name) {
    var s = name.toLowerCase();
    s = s.replaceAll(RegExp(r'\s+'), '-');
    s = s.replaceAll(RegExp(r'[^a-z0-9._\-]'), '');
    s = s.replaceAll(RegExp(r'-{2,}'), '-');
    if (s.length > 60) s = s.substring(0, 60);
    return s;
  }
}
