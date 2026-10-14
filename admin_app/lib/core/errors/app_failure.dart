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
final class ApiFailure extends AppFailure {
  const ApiFailure(super.code, super.message, [super.details]);
}

/// A failure caused by no connectivity or a timeout.
final class NetworkFailure extends AppFailure {
  const NetworkFailure([
    String message = 'No internet connection. Please check your network.',
  ]) : super('NETWORK_ERROR', message);
}

/// A client-side form-validation failure (never from the server).
final class ValidationFailure extends AppFailure {
  const ValidationFailure(String message, [Map<String, dynamic>? details])
      : super('VALIDATION_ERROR', message, details);
}
