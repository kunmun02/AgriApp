/// Sealed hierarchy for typed application failures.
///
/// Controllers expose `AsyncValue<T>`; screens render per the
/// 04_UI states contract. Failure subtypes map to the code table in
/// 02_BACKEND/02_ERROR_CODES.md.
sealed class AppFailure {
  const AppFailure(this.code, this.message, [this.details]);

  /// Machine-readable code (e.g. `OUT_OF_STOCK`, `FORBIDDEN`).
  final String code;

  /// Human-readable message shown in UI (localised copy or server message).
  final String message;

  /// Optional structured context from the server envelope.
  final Map<String, dynamic>? details;

  /// The copy actually shown to the user.
  String get userMessage => message;

  @override
  String toString() => 'AppFailure($code: $message)';
}

/// A failure originating from the Supabase/PostgREST API.
///
/// Covers P0001 business errors, RLS denials (42501 → FORBIDDEN),
/// PGRST116 (NOT_FOUND), PGRST301 (AUTH_REQUIRED) and any other
/// non-connectivity server error.
final class ApiFailure extends AppFailure {
  const ApiFailure(super.code, super.message, [super.details]);
}

/// A failure caused by no connectivity or a timeout.
///
/// Client should show a retry affordance and NEVER fake success.
final class NetworkFailure extends AppFailure {
  const NetworkFailure([
    String message = 'No internet connection. Please check your network.',
  ]) : super('NETWORK_ERROR', message);
}

/// A client-side form-validation failure (never from the server).
///
/// Used only to surface field-level errors in forms before a request
/// is made; the server also validates independently.
final class ValidationFailure extends AppFailure {
  const ValidationFailure(String message, [Map<String, dynamic>? details])
      : super('VALIDATION_ERROR', message, details);
}
