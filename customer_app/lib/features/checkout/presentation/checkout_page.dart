import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../addresses/data/address_repository.dart';
import '../../addresses/data/models/address.dart';
import '../../cart/controllers/cart_controller.dart';
import '../controllers/checkout_controller.dart';
import '../data/models/app_settings.dart';

// ── Address list provider (reused from C09 but local to this page) ────────────

final _checkoutAddressListProvider =
    FutureProvider.autoDispose<List<Address>>((ref) {
  return ref.read(addressRepositoryProvider).fetchAddresses();
});

/// C11 — Checkout screen.
///
/// Displays address picker, items summary (read-only), totals card (client
/// preview labelled as estimate), COD note, and Place Order button.
class CheckoutPage extends ConsumerWidget {
  const CheckoutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkoutState = ref.watch(checkoutControllerProvider);
    final cartState = ref.watch(cartControllerProvider);
    final asyncAddresses = ref.watch(_checkoutAddressListProvider);

    // Listen for success navigation.
    ref.listen<CheckoutState>(checkoutControllerProvider, (prev, next) {
      if (next.successOrderId != null &&
          (prev?.successOrderId != next.successOrderId)) {
        context.pushReplacement(
          '/order-success/${next.successOrderId}',
          extra: {
            'orderNumber': next.successOrderNumber,
            'total': next.successTotal,
          },
        );
      }
    });

    // Listen for stock failure dialog.
    ref.listen<CheckoutState>(checkoutControllerProvider, (prev, next) {
      if (next.stockFailure != null &&
          (prev?.stockFailure != next.stockFailure)) {
        _showStockFailureDialog(context, ref, next.stockFailure!);
      }
    });

    // Listen for snackbar errors.
    ref.listen<CheckoutState>(checkoutControllerProvider, (prev, next) {
      if (next.error != null && (prev?.error != next.error)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!.message),
            action: next.error is NetworkFailure
                ? SnackBarAction(
                    label: 'Retry',
                    onPressed: () => ref
                        .read(checkoutControllerProvider.notifier)
                        .placeOrder(),
                  )
                : null,
          ),
        );
      }
    });

    final availableItems = cartState.availableItems;

    // Guard: redirect if cart is empty.
    if (!cartState.isLoading && availableItems.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/cart');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // ── Address section ──────────────────────────────────────────────
          const _SectionHeader(title: 'Delivery Address'),
          const SizedBox(height: AppSpacing.sm),
          asyncAddresses.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(
              e is AppFailure ? e.message : 'Failed to load addresses.',
            ),
            data: (addresses) => _AddressPicker(
              addresses: addresses,
              selectedAddress: checkoutState.selectedAddress,
              onSelect: (addr) {
                ref
                    .read(checkoutControllerProvider.notifier)
                    .selectAddress(addr);
              },
              onAddNew: () async {
                final selected =
                    await context.push<Address>('/addresses?selectMode=true');
                if (selected != null) {
                  ref
                      .read(checkoutControllerProvider.notifier)
                      .selectAddress(selected);
                  ref.invalidate(_checkoutAddressListProvider);
                }
              },
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Items summary ────────────────────────────────────────────────
          const _SectionHeader(title: 'Order Summary'),
          const SizedBox(height: AppSpacing.sm),
          ...availableItems.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.product?.name ?? 'Product'} × ${item.quantity}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    Formatters.inr(item.lineTotal),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: AppSpacing.xl),

          // ── Totals card ──────────────────────────────────────────────────
          _TotalsCard(
            cartSubtotal: cartState.subtotal,
            cartTaxPreview: _computeTaxPreview(cartState),
            settings: checkoutState.settings,
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Payment method ───────────────────────────────────────────────
          const _SectionHeader(title: 'Payment'),
          const SizedBox(height: AppSpacing.sm),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.radio_button_checked, color: AppColors.primary),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cash on Delivery',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        Text('Pay when your order arrives.',
                            style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Place Order button ────────────────────────────────────────────
          AppButton(
            key: const Key('placeOrderButton'),
            label: 'Place Order',
            onPressed: checkoutState.selectedAddress == null ||
                    checkoutState.settings == null
                ? null
                : () =>
                    ref.read(checkoutControllerProvider.notifier).placeOrder(),
            loading: checkoutState.isLoading,
            enabled: checkoutState.selectedAddress != null &&
                checkoutState.settings != null,
          ),

          if (checkoutState.selectedAddress == null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Please select a delivery address.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.error),
            ),
          ],

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  double _computeTaxPreview(CartState cartState) {
    return cartState.availableItems.fold(0.0, (sum, item) {
      final lineTotal = item.lineTotal;
      final taxPercent = item.product?.taxPercent ?? 0.0;
      // Mirror server formula: ROUND(line_total * tax_percent / 100, 2)
      final lineTax =
          (lineTotal * taxPercent / 100 * 100).roundToDouble() / 100;
      return sum + lineTax;
    });
  }

  void _showStockFailureDialog(
    BuildContext context,
    WidgetRef ref,
    StockFailure failure,
  ) {
    final isStock = failure.code == 'OUT_OF_STOCK';
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(isStock ? 'Out of Stock' : 'Items Unavailable'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isStock
                ? 'The following items are out of stock:'
                : 'The following items are no longer available:'),
            const SizedBox(height: AppSpacing.sm),
            ...failure.itemNames.map(
              (name) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.remove_circle_outline,
                        size: 16, color: AppColors.error),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(name)),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(checkoutControllerProvider.notifier).clearStockFailure();
              context.go('/cart');
            },
            child: const Text('Back to Cart'),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _AddressPicker extends StatelessWidget {
  const _AddressPicker({
    required this.addresses,
    required this.selectedAddress,
    required this.onSelect,
    required this.onAddNew,
  });

  final List<Address> addresses;
  final Address? selectedAddress;
  final void Function(Address) onSelect;
  final VoidCallback onAddNew;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...addresses.map(
          (addr) => InkWell(
            key: ValueKey(addr.id),
            onTap: () => onSelect(addr),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      selectedAddress?.id == addr.id
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: selectedAddress?.id == addr.id
                          ? AppColors.primary
                          : null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${addr.recipientName} (${addr.label})',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          [
                            addr.line1,
                            addr.city,
                            addr.state,
                            addr.postalCode,
                          ].join(', '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (addr.isDefault)
                    Chip(
                      label: const Text('Default'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor:
                          AppColors.success.withValues(alpha: 0.15),
                      labelStyle: const TextStyle(
                          color: AppColors.success, fontSize: 11),
                    ),
                ],
              ),
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onAddNew,
          icon: const Icon(Icons.add),
          label: const Text('Add new address'),
        ),
      ],
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({
    required this.cartSubtotal,
    required this.cartTaxPreview,
    required this.settings,
  });

  final double cartSubtotal;
  final double cartTaxPreview;
  final AppSettings? settings;

  @override
  Widget build(BuildContext context) {
    final delivery = settings == null
        ? null
        : cartSubtotal >= settings!.freeDeliveryThreshold
            ? 0.0
            : settings!.deliveryCharge;

    final total =
        delivery == null ? null : cartSubtotal + cartTaxPreview + delivery;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            _TotalsRow(label: 'Subtotal', amount: cartSubtotal),
            const SizedBox(height: AppSpacing.xs),
            _TotalsRow(
              label: 'Delivery',
              amount: delivery ?? 0,
              freeLabel: delivery == 0 ? 'FREE' : null,
              muted: delivery == null,
            ),
            const SizedBox(height: AppSpacing.xs),
            _TotalsRow(label: 'Tax (est.)', amount: cartTaxPreview),
            const Divider(height: AppSpacing.lg),
            _TotalsRow(
              label: 'Total (est.)',
              amount: total ?? (cartSubtotal + cartTaxPreview),
              bold: true,
            ),
            if (settings != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '* Final totals are confirmed at order placement.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({
    required this.label,
    required this.amount,
    this.freeLabel,
    this.bold = false,
    this.muted = false,
  });

  final String label;
  final double amount;
  final String? freeLabel;
  final bool bold;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: bold ? FontWeight.w700 : null,
          color: muted ? AppColors.textSecondary : null,
          fontSize: bold ? 16 : null,
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        if (freeLabel != null)
          Text(
            freeLabel!,
            style: style?.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w700,
            ),
          )
        else
          Text(Formatters.inr(amount), style: style),
      ],
    );
  }
}
