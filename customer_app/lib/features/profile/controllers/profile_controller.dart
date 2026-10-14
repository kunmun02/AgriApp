import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../auth/controllers/auth_controller.dart';

/// Thin controller that delegates profile updates to [AuthController].
///
/// Kept separate so the profile UI doesn't depend on the full auth controller
/// interface and tests can stub just this surface.
final profileControllerProvider =
    Provider<ProfileController>((ref) => ProfileController(ref));

class ProfileController {
  ProfileController(this._ref);

  final Ref _ref;

  /// Updates [fullName] and/or [phone] for the currently signed-in user.
  ///
  /// Returns null on success, or a human-readable error string on failure.
  Future<String?> save({
    required String userId,
    String? fullName,
    String? phone,
  }) async {
    try {
      return await _ref
          .read(authControllerProvider.notifier)
          .updateProfile(userId: userId, fullName: fullName, phone: phone);
    } catch (e) {
      return e is AppFailure ? e.userMessage : 'Something went wrong.';
    }
  }
}
