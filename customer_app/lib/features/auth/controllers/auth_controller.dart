import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../data/auth_repository.dart';
import '../data/models/profile.dart';

/// Exposes [AsyncValue<Profile?>]:
///   - [AsyncLoading]  → session restore in progress (show splash)
///   - [AsyncData<Profile>] → signed in
///   - [AsyncData<null>]   → signed out
final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<Profile?>>((ref) {
  return AuthController(ref.read(authRepositoryProvider))..init();
});

class AuthController extends StateNotifier<AsyncValue<Profile?>> {
  AuthController(this._repo) : super(const AsyncLoading());

  final AuthRepository _repo;

  // ── Bootstrap ──────────────────────────────────────────────────────────

  /// Called once on startup: restores the existing session (if any).
  /// Times out after 3 s to avoid blocking the splash forever.
  Future<void> init() async {
    try {
      final session =
          await _repo.currentUserSession().timeout(const Duration(seconds: 3));

      if (session != null) {
        final profile = await _repo.fetchProfile(session.user.id);
        state = AsyncData(profile);
      } else {
        state = const AsyncData(null);
      }
    } catch (_) {
      // Any error (timeout, network, etc.) → treat as signed-out.
      state = const AsyncData(null);
    }
  }

  // ── Sign-up ────────────────────────────────────────────────────────────

  /// Creates an account and transitions to signed-in state.
  /// Returns [null] on success. Returns an error message string on failure.
  Future<String?> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = const AsyncLoading();
    try {
      final profile = await _repo.signUp(
        email: email,
        password: password,
        fullName: fullName,
      );
      state = AsyncData(profile);
      return null;
    } catch (e) {
      state = const AsyncData(null);
      return _messageFrom(e);
    }
  }

  // ── Sign-in ────────────────────────────────────────────────────────────

  /// Signs in and transitions to signed-in state.
  /// Returns [null] on success, error message string on failure.
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      final profile = await _repo.signIn(email: email, password: password);
      state = AsyncData(profile);
      return null;
    } catch (e) {
      state = const AsyncData(null);
      return _messageFrom(e);
    }
  }

  // ── Sign-out ───────────────────────────────────────────────────────────

  Future<void> signOut() async {
    try {
      await _repo.signOut();
    } finally {
      state = const AsyncData(null);
    }
  }

  // ── Profile update ─────────────────────────────────────────────────────

  Future<String?> updateProfile({
    required String userId,
    String? fullName,
    String? phone,
  }) async {
    try {
      final updated = await _repo.updateProfile(
        userId: userId,
        fullName: fullName,
        phone: phone,
      );
      state = AsyncData(updated);
      return null;
    } catch (e) {
      return _messageFrom(e);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  String _messageFrom(Object error) {
    if (error is AppFailure) return error.userMessage;
    return 'Something went wrong. Please try again.';
  }
}
