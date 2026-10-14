import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/network/supabase_client.dart';
import 'models/profile.dart';

/// Repository provider — injected with the Supabase client.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(supabaseClientProvider));
});

/// Handles all Supabase Auth and profile operations.
///
/// All methods map raw Supabase/PostgREST exceptions to [AppFailure]
/// via [ErrorMapper]. Screens never call Supabase directly.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  // ── Session ────────────────────────────────────────────────────────────

  /// Returns the current [Session] if one exists (e.g. after a hot restart).
  Future<Session?> currentUserSession() async {
    return _client.auth.currentSession;
  }

  /// Emits an [AuthState] event whenever sign-in / sign-out / token refresh occurs.
  Stream<AuthState> onAuthStateChange() {
    return _client.auth.onAuthStateChange;
  }

  // ── Sign-up ────────────────────────────────────────────────────────────

  /// Creates a new account and returns the resulting [Profile].
  ///
  /// The `full_name` user-metadata key triggers the DB
  /// `handle_new_user` trigger to insert a `profiles` row.
  /// Email-confirmation is disabled for this project, so the user
  /// is automatically signed in after sign-up.
  Future<Profile> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );

      final userId = response.user?.id;
      if (userId == null) {
        throw const AuthException('Sign-up failed: no user returned.');
      }

      // The trigger may need a moment; fetch with a tiny retry.
      return await _fetchProfileWithRetry(userId);
    } on AuthException catch (e) {
      throw ErrorMapper.from(e);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  // ── Sign-in ────────────────────────────────────────────────────────────

  /// Signs in and returns the current [Profile].
  Future<Profile> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final userId = response.user?.id;
      if (userId == null) {
        throw const AuthException('Sign-in failed: no user returned.');
      }

      return await fetchProfile(userId);
    } on AuthException catch (e) {
      throw ErrorMapper.from(e);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  // ── Sign-out ───────────────────────────────────────────────────────────

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  // ── Profile ────────────────────────────────────────────────────────────

  /// Fetches a single profile row by user id.
  /// Throws [ApiFailure('NOT_FOUND')] if the row doesn't exist.
  Future<Profile> fetchProfile(String userId) async {
    try {
      final data =
          await _client.from('profiles').select().eq('id', userId).single();
      return Profile.fromJson(data);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  /// Updates mutable profile fields for [userId].
  Future<Profile> updateProfile({
    required String userId,
    String? fullName,
    String? phone,
  }) async {
    try {
      final patch = <String, dynamic>{};
      if (fullName != null) patch['full_name'] = fullName;
      if (phone != null) patch['phone'] = phone;

      final data = await _client
          .from('profiles')
          .update(patch)
          .eq('id', userId)
          .select()
          .single();
      return Profile.fromJson(data);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  /// Retries fetchProfile up to 3 times with 300 ms gaps.
  /// The DB trigger runs asynchronously; the row may not be visible
  /// immediately after sign-up completes.
  Future<Profile> _fetchProfileWithRetry(String userId) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await fetchProfile(userId);
      } catch (_) {
        if (attempt == 2) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
    throw StateError('unreachable');
  }
}
