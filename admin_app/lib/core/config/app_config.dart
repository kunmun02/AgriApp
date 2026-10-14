/// Reads Supabase connection parameters injected at compile time via
/// `--dart-define-from-file=.env`.
///
/// Usage:
///   flutter run -d chrome --dart-define-from-file=.env
///
/// The .env file must be a JSON object:
///   { "SUPABASE_URL": "https://xxx.supabase.co",
///     "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_..." }
///
/// Legacy key name SUPABASE_ANON_KEY is also accepted for backwards
/// compatibility with older projects (eyJ... format).
class AppConfig {
  AppConfig._();

  /// Supabase project URL.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase publishable key (new sb_publishable_... format).
  /// Falls back to SUPABASE_ANON_KEY for legacy eyJ... format keys.
  static const String supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Legacy anon key (eyJ... format). Used when SUPABASE_PUBLISHABLE_KEY
  /// is not set.
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Returns whichever key is configured — new publishable key takes
  /// precedence over the legacy anon key.
  static String get supabaseKey =>
      supabasePublishableKey.isNotEmpty ? supabasePublishableKey : supabaseAnonKey;
}
