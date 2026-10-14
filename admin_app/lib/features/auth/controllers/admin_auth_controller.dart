import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../data/admin_auth_repository.dart';
import '../data/models/profile.dart';

final adminAuthControllerProvider =
    StateNotifierProvider<AdminAuthController, AsyncValue<Profile?>>((ref) {
  return AdminAuthController(ref.read(adminAuthRepositoryProvider))..init();
});

class AdminAuthController extends StateNotifier<AsyncValue<Profile?>> {
  AdminAuthController(this._repo) : super(const AsyncLoading());

  final AdminAuthRepository _repo;

  // ── Bootstrap ─────────────────────────────────────────────────────────

  Future<void> init() async {
    try {
      final session =
          await _repo.currentUserSession().timeout(const Duration(seconds: 3));

      if (session != null) {
        // Re-verify admin role on every cold start.
        final profile = await _repo.requireAdminProfile(session.user.id);
        state = AsyncData(profile);
      } else {
        state = const AsyncData(null);
      }
    } catch (_) {
      state = const AsyncData(null);
    }
  }

  // ── Sign-in ───────────────────────────────────────────────────────────

  /// Returns null on success, error message string on failure.
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

  // ── Sign-out ──────────────────────────────────────────────────────────

  Future<void> signOut() async {
    try {
      await _repo.signOut();
    } finally {
      state = const AsyncData(null);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  String _messageFrom(Object error) {
    if (error is AppFailure) return error.userMessage;
    return 'Something went wrong. Please try again.';
  }
}
