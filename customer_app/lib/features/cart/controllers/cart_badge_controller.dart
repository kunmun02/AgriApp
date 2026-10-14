import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cart_repository.dart';

final cartBadgeControllerProvider =
    StateNotifierProvider<CartBadgeController, int>(
  (ref) => CartBadgeController(ref.read(cartRepositoryProvider)),
);

/// Holds the cart item count for the bottom-navigation badge.
///
/// Initialises by fetching the real count from [CartRepository.itemCount].
/// Callers invoke [increment] after a successful add-to-cart to avoid an
/// extra network round-trip; [refresh] re-fetches from the server (e.g. on
/// cart screen open).
class CartBadgeController extends StateNotifier<int> {
  CartBadgeController(this._repo) : super(0) {
    refresh();
  }

  final CartRepository _repo;

  /// Increment the badge by 1 locally (optimistic).
  void increment() => state = state + 1;

  /// Re-fetch the authoritative count from the server.
  Future<void> refresh() async {
    try {
      final count = await _repo.itemCount();
      state = count;
    } catch (_) {
      // Silently ignore — badge is best-effort.
    }
  }
}
