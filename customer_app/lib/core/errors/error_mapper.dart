import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_failure.dart';

/// Maps raw exceptions from Supabase/PostgREST into typed [AppFailure]s.
///
/// Rule priority (five rules, in order):
///   1. [SocketException] / connectivity → [NetworkFailure].
///   2. [AuthException] with PGRST301 or JWT-related → [ApiFailure] AUTH_REQUIRED.
///   3. [PostgrestException] code PGRST301 → AUTH_REQUIRED.
///   4. [PostgrestException] code P0001 → decode JSON envelope → typed [ApiFailure].
///   5. [PostgrestException] other codes → map via [_postgrestCodeMap] or INTERNAL_ERROR.
class ErrorMapper {
  ErrorMapper._();

  static const Map<String, String> _postgrestCodeMap = {
    'PGRST116': 'NOT_FOUND', // .single() returned 0 rows
    'PGRST301': 'AUTH_REQUIRED', // JWT expired / missing
    '42501': 'FORBIDDEN', // RLS permission denied
    '23514': 'VALIDATION_ERROR', // CHECK constraint violation
    '23505': 'VALIDATION_ERROR', // UNIQUE constraint violation
  };

  /// Convert any caught [error] into an [AppFailure].
  ///
  /// Never rethrows. Never prints tokens or full stack traces —
  /// only logs `code + sanitized message` in debug mode.
  static AppFailure from(Object error) {
    // Rule 1 — network connectivity
    if (error is SocketException) {
      return const NetworkFailure();
    }

    // Rule 2 — Supabase AuthException
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('jwt') ||
          msg.contains('token') ||
          msg.contains('session')) {
        return const ApiFailure(
            'AUTH_REQUIRED', 'Your session has expired. Please log in again.');
      }
      return ApiFailure('AUTH_REQUIRED', error.message);
    }

    // Rules 3–5 — PostgrestException
    if (error is PostgrestException) {
      final code = error.code ?? '';

      // Rule 3 — PGRST301
      if (code == 'PGRST301') {
        return const ApiFailure(
            'AUTH_REQUIRED', 'Your session has expired. Please log in again.');
      }

      // Rule 4 — P0001: business error envelope
      if (code == 'P0001') {
        try {
          final json = jsonDecode(error.message) as Map<String, dynamic>;
          final businessCode = json['code'] as String? ?? 'INTERNAL_ERROR';
          final businessMsg = json['message'] as String? ??
              'Something went wrong. Please try again.';
          final details = json['details'] as Map<String, dynamic>?;
          return ApiFailure(businessCode, businessMsg, details);
        } catch (_) {
          // Message was not a JSON envelope — fall through to INTERNAL_ERROR.
        }
      }

      // Rule 5 — other known PostgREST / PostgreSQL codes
      final mappedCode = _postgrestCodeMap[code];
      if (mappedCode != null) {
        final msg = error.message.isNotEmpty
            ? error.message
            : _defaultMessageFor(mappedCode);
        return ApiFailure(mappedCode, msg);
      }

      // Unmapped code — sanitize: never expose raw message to UI.
      return const ApiFailure(
        'INTERNAL_ERROR',
        'Something went wrong. Please try again.',
      );
    }

    // Catch-all
    return const ApiFailure(
      'INTERNAL_ERROR',
      'Something went wrong. Please try again.',
    );
  }

  static String _defaultMessageFor(String code) {
    switch (code) {
      case 'AUTH_REQUIRED':
        return 'Please log in to continue.';
      case 'FORBIDDEN':
        return 'You are not allowed to do this.';
      case 'NOT_FOUND':
        return 'The requested item could not be found.';
      case 'VALIDATION_ERROR':
        return 'The submitted data is invalid.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
