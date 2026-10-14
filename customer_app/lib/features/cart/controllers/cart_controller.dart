import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/cart_item.dart';
import '../../cart/controllers/cart_badge_controller.dart';
import '../data/cart_repository.dart';

// ── State ─────────────────────────────────────────────────────────────────────

/// Immutable state for [CartController].
class CartState {
  const CartState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  final List<CartItem> items;
  final bool isLoading;
  final AppFailure? error;

  /// Items that are available (active + published product).
  List<CartItem> get availableItems =>
      items.where((i) => i.isAvailable).toList();

  /// Subtotal derived exclusively from available items.
  double get subtotal => availableItems.fold(0, (sum, i) => sum + i.lineTotal);

  /// Total count of all items (available + unavailable) — used for badge.
  int get totalItemCount => items.length;

  CartState copyWith({
    List<CartItem>? items,
    bool? isLoading,
    AppFailure? error,
    bool clearError = false,
  }) {
    return CartState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final cartControllerProvider = StateNotifierProvider<CartController, CartState>(
  (ref) => CartController(
    ref.read(cartRepositoryProvider),
    ref.read(cartBadgeControllerProvider.notifier),
  ),
);

// ── Controller ────────────────────────────────────────────────────────────────

/// Manages the full cart screen state.
///
/// Responsibilities:
/// - Fetch items on construction via [fetch].
/// - [updateQuantity]: optimistic update with revert on failure.
/// - [removeItem]: removes row after confirmation (dialog is in the UI).
/// - [addItem]: delegates to repository (called from outside, e.g. product details).
/// - Calls [CartBadgeController.refresh] after every successful mutation.
class CartController extends StateNotifier<CartState> {
  CartController(this._repo, this._badge) : super(const CartState()) {
    fetch();
  }

  final CartRepository _repo;
  final CartBadgeController _badge;

  // ── Fetch ──────────────────────────────────────────────────────────────────

  Future<void> fetch() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final cartId = await _repo.ensureCart();
      final items = await _repo.fetchItems(cartId);
      state = state.copyWith(items: items, isLoading: false);
    } on AppFailure catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: ApiFailure('INTERNAL_ERROR', e.toString()),
      );
    }
  }

  // ── Add ────────────────────────────────────────────────────────────────────

  /// Adds a product to the cart; used by callers such as ProductDetailsPage.
  ///
  /// Returns the [AppFailure] on error so callers can show a snackbar.
  Future<AppFailure?> addItem({
    required String productId,
    required int quantity,
  }) async {
    try {
      final cartId = await _repo.ensureCart();
      await _repo.addItem(
          cartId: cartId, productId: productId, quantity: quantity);
      // Re-fetch so the cart screen reflects the new item.
      await fetch();
      await _badge.refresh();
      return null;
    } on AppFailure catch (e) {
      return e;
    } catch (e) {
      return ApiFailure('INTERNAL_ERROR', e.toString());
    }
  }

  // ── Update quantity ────────────────────────────────────────────────────────

  /// Updates the quantity of [itemId] to [quantity] (1–99).
  ///
  /// Applies optimistically; reverts to [previous] on failure and returns the
  /// [AppFailure] so the UI can show a snackbar.
  Future<AppFailure?> updateQuantity({
    required String itemId,
    required int quantity,
  }) async {
    // Clamp defensively — stepper should already prevent values outside 1–99.
    final clamped = quantity.clamp(1, 99);

    // Optimistic update.
    final previous = state.items;
    state = state.copyWith(
      items: previous
          .map((i) => i.id == itemId ? i.copyWith(quantity: clamped) : i)
          .toList(),
    );

    try {
      await _repo.updateQuantity(itemId: itemId, quantity: clamped);
      await _badge.refresh();
      return null;
    } on AppFailure catch (e) {
      // Revert.
      state = state.copyWith(items: previous);
      return e;
    } catch (e) {
      state = state.copyWith(items: previous);
      return ApiFailure('INTERNAL_ERROR', e.toString());
    }
  }

  // ── Remove ─────────────────────────────────────────────────────────────────

  /// Removes [itemId] from the cart.
  ///
  /// The calling UI is responsible for showing a confirmation dialog BEFORE
  /// invoking this method. Returns the [AppFailure] on error.
  Future<AppFailure?> removeItem(String itemId) async {
    // Optimistic removal.
    final previous = state.items;
    state = state.copyWith(
      items: previous.where((i) => i.id != itemId).toList(),
    );

    try {
      await _repo.removeItem(itemId);
      await _badge.refresh();
      return null;
    } on AppFailure catch (e) {
      state = state.copyWith(items: previous);
      return e;
    } catch (e) {
      state = state.copyWith(items: previous);
      return ApiFailure('INTERNAL_ERROR', e.toString());
    }
  }
}
