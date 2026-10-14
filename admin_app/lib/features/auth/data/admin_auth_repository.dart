import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/network/supabase_client.dart';
import 'models/profile.dart';

final adminAuthRepositoryProvider = Provider<AdminAuthRepository>((ref) {
  return AdminAuthRepository(ref.read(supabaseClientProvider));
});

/// Handles Supabase Auth for the admin panel.
///
/// On every sign-in, [requireAdminProfile] is called to verify
/// role == admin. Non-admin accounts are signed out immediately.
class AdminAuthRepository {
  AdminAuthRepository(this._client);

  final SupabaseClient _client;

  // ── Session ───────────────────────────────────────────────────────────

  Future<Session?> currentUserSession() async => _client.auth.currentSession;

  Stream<AuthState> onAuthStateChange() => _client.auth.onAuthStateChange;

  // ── Sign-in ───────────────────────────────────────────────────────────

  /// Signs in with email/password then verifies the account is an admin.
  ///
  /// Throws [ApiFailure('FORBIDDEN', 'This account is not an admin')]
  /// if the profile role is not admin (and signs the user out first).
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
      return await requireAdminProfile(userId);
    } on AppFailure {
      rethrow;
    } on AuthException catch (e) {
      throw ErrorMapper.from(e);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  // ── Admin check ───────────────────────────────────────────────────────

  /// Fetches the profile and verifies role == admin.
  /// Signs out and throws [ApiFailure('FORBIDDEN', …)] if not admin.
  Future<Profile> requireAdminProfile(String userId) async {
    try {
      final data =
          await _client.from('profiles').select().eq('id', userId).single();
      final profile = Profile.fromJson(data);
      if (profile.role != ProfileRole.admin) {
        await _client.auth.signOut();
        throw const ApiFailure(
          'FORBIDDEN',
          'This account is not an admin',
        );
      }
      return profile;
    } on AppFailure {
      rethrow;
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  // ── Profile ───────────────────────────────────────────────────────────

  Future<Profile> fetchProfile(String userId) async {
    try {
      final data =
          await _client.from('profiles').select().eq('id', userId).single();
      return Profile.fromJson(data);
    } on PostgrestException catch (e) {
      throw ErrorMapper.from(e);
    }
  }

  // ── Sign-out ──────────────────────────────────────────────────────────

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw ErrorMapper.from(e);
    }
  }
}
