import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/utils/idempotency.dart';
import '../../cart/controllers/cart_badge_controller.dart';
import '../../cart/controllers/cart_controller.dart';
import '../../addresses/data/models/address.dart';
import '../data/checkout_repository.dart';
import '../data/models/app_settings.dart';

// ── State ─────────────────────────────────────────────────────────────────────

/// Outcome of a failed place-order call that requires a dialog with item names.
class StockFailure {
  const StockFailure({required this.code, required this.itemNames});

  /// `OUT_OF_STOCK` or `PRODUCT_UNAVAILABLE`
  final String code;

  /// Product names extracted from `details.skipped` or the error message.
  final List<String> itemNames;
}

/// Immutable state for [CheckoutController].
class CheckoutState {
  const CheckoutState({
    this.settings,
    this.selectedAddress,
    this.isLoading = false,
    this.error,
    this.stockFailure,
    this.successOrderId,
    this.successOrderNumber,
    this.successTotal,
    required this.idempotencyKey,
  });

  final AppSettings? settings;
  final Address? selectedAddress;
  final bool isLoading;

  /// A non-stock, non-network failure (shown as snackbar).
  final AppFailure? error;

  /// Stock / availability failure (shown as dialog).
  final StockFailure? stockFailure;

  /// Non-null after a successful (or replayed) order.
  final String? successOrderId;

  /// Order number string (e.g. AGR-261006-A1B2C3) — set alongside [successOrderId].
  final String? successOrderNumber;

  /// Server-confirmed total — set alongside [successOrderId].
  final double? successTotal;

  /// UUID v4 generated once per checkout attempt.
  final String idempotencyKey;

  CheckoutState copyWith({
    AppSettings? settings,
    Address? selectedAddress,
    bool? isLoading,
    AppFailure? error,
    bool clearError = false,
    StockFailure? stockFailure,
    bool clearStockFailure = false,
    String? successOrderId,
    String? successOrderNumber,
    double? successTotal,
    String? idempotencyKey,
  }) {
    return CheckoutState(
      settings: settings ?? this.settings,
      selectedAddress: selectedAddress ?? this.selectedAddress,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      stockFailure:
          clearStockFailure ? null : (stockFailure ?? this.stockFailure),
      successOrderId: successOrderId ?? this.successOrderId,
      successOrderNumber: successOrderNumber ?? this.successOrderNumber,
      successTotal: successTotal ?? this.successTotal,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final checkoutControllerProvider =
    StateNotifierProvider.autoDispose<CheckoutController, CheckoutState>(
  (ref) => CheckoutController(
    ref.read(checkoutRepositoryProvider),
    ref.read(cartBadgeControllerProvider.notifier),
    ref.read(cartControllerProvider.notifier),
  ),
);

// ── Controller ────────────────────────────────────────────────────────────────

class CheckoutController extends StateNotifier<CheckoutState> {
  CheckoutController(this._repo, this._badge, this._cart)
      : super(CheckoutState(idempotencyKey: generateIdempotencyKey())) {
    loadSettings();
  }

  final CheckoutRepository _repo;
  final CartBadgeController _badge;
  final CartController _cart;

  // ── Load settings ──────────────────────────────────────────────────────────

  Future<void> loadSettings() async {
    try {
      final settings = await _repo.fetchSettings();
      state = state.copyWith(settings: settings, clearError: true);
    } on AppFailure catch (e) {
      state = state.copyWith(error: e);
    }
  }

  // ── Address selection ──────────────────────────────────────────────────────

  void selectAddress(Address address) {
    state = state.copyWith(selectedAddress: address);
  }

  // ── Place order ────────────────────────────────────────────────────────────

  Future<void> placeOrder() async {
    if (state.isLoading) return;
    if (state.selectedAddress == null) return;

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearStockFailure: true,
    );

    try {
      final result = await _repo.createOrder(
        addressId: state.selectedAddress!.id,
        idempotencyKey: state.idempotencyKey,
      );

      final isDuplicate = result['duplicate'] as bool? ?? false;
      final orderId = result['order_id'] as String;
      // order_number and total only present on fresh orders, not on duplicate replay.
      final orderNumber = result['order_number'] as String?;
      final total = result['total'] != null
          ? (num.tryParse(result['total'].toString()) ?? 0).toDouble()
          : null;

      // On success (new or replay): clear cart badge, reset cart, emit orderId.
      await _badge.refresh();
      _cart.fetch();

      state = state.copyWith(
        isLoading: false,
        successOrderId: orderId,
        successOrderNumber: orderNumber,
        successTotal: total,
        // Regenerate key — this attempt is consumed.
        idempotencyKey: generateIdempotencyKey(),
      );

      // isDuplicate is informational; navigation is identical for both.
      assert(isDuplicate == isDuplicate); // suppress unused warning
    } on ApiFailure catch (e) {
      if (e.code == 'OUT_OF_STOCK' || e.code == 'PRODUCT_UNAVAILABLE') {
        // Extract product names from details or message for the dialog.
        final names = _extractItemNames(e);
        state = state.copyWith(
          isLoading: false,
          stockFailure: StockFailure(code: e.code, itemNames: names),
          // Regenerate key — this cart state is now invalid.
          idempotencyKey: generateIdempotencyKey(),
        );
      } else if (e.code == 'DUPLICATE_REQUEST') {
        // Treat as success — replay.
        final orderId = e.details?['order_id'] as String? ?? '';
        await _badge.refresh();
        state = state.copyWith(
          isLoading: false,
          successOrderId: orderId,
          idempotencyKey: generateIdempotencyKey(),
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: e,
          // Keep the idempotency key for non-network failures too.
        );
      }
    } on NetworkFailure catch (e) {
      // Keep the key so the user can retry the same submission.
      state = state.copyWith(isLoading: false, error: e);
    } on AppFailure catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  /// Clears a displayed stock failure so the dialog can be dismissed.
  void clearStockFailure() {
    state = state.copyWith(clearStockFailure: true);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<String> _extractItemNames(ApiFailure e) {
    final details = e.details;
    if (details != null) {
      // PRODUCT_UNAVAILABLE puts names in details.skipped (jsonb array)
      final skipped = details['skipped'];
      if (skipped is List) {
        return skipped.map((n) => n.toString()).toList();
      }
      // OUT_OF_STOCK puts one name in details.product_id (not a name, so
      // fall back to message parsing).
    }
    // Last resort: use message text.
    return [e.message];
  }
}
