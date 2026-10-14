/// Reads Supabase connection parameters injected at compile time via
/// `--dart-define-from-file=.env`.
///
/// Usage:
///   flutter run --dart-define-from-file=.env
///
/// The .env file must be a JSON object:
///   { "SUPABASE_URL": "https://xxx.supabase.co",
///     "SUPABASE_ANON_KEY": "eyJ..." }
///
/// Fallback values are embedded so that a plain `flutter run` still works
/// during local development. They are identical to the values in .env.
class AppConfig {
  AppConfig._();

  // ── Supabase project URL ───────────────────────────────────────────────
  // Falls back to the hardcoded project URL when the --dart-define-from-file
  // flag is omitted (e.g. plain `flutter run` without specifying .env).
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://nlnatvcjzcjeydwcimri.supabase.co',
  );

  // ── Supabase anonymous (public) key ───────────────────────────────────
  // Safe to embed in client bundles; Row-Level Security protects the data.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5sbmF0dmNqemNqZXlkd2NpbXJpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA5NTc5NTYsImV4cCI6MjEwNjUzMzk1Nn0.nn6LcrSlwF1OuWeiiyypEvSQBdOIqdFM2-cByqUzc8w',
  );
}
