import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/cart_item.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/cached_image.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/quantity_stepper.dart';
import '../controllers/cart_controller.dart';

/// C08 — Cart screen.
///
/// Shows all cart items (available + unavailable), a price summary card,
/// and a "Proceed to Checkout" button (disabled when no available items).
/// Unavailable items are greyed-out with an "Unavailable" chip and excluded
/// from the subtotal.
class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart'),
      ),
      body: _buildBody(context, ref, cartState),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, CartState state) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.error!.message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(
                onPressed: () =>
                    ref.read(cartControllerProvider.notifier).fetch(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      return EmptyState(
        icon: Icons.shopping_cart_outlined,
        title: 'Your cart is empty',
        message: 'Add items from the catalogue to get started.',
        actionLabel: 'Browse products',
        onAction: () => context.go('/categories'),
      );
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(cartControllerProvider.notifier).fetch(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.lg,
              ),
              itemCount: state.items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final item = state.items[index];
                return _CartItemTile(item: item);
              },
            ),
          ),
        ),
        _SummaryCard(subtotal: state.subtotal),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Proceed to Checkout',
              enabled: state.availableItems.isNotEmpty,
              onPressed: state.availableItems.isNotEmpty
                  ? () => context.push('/checkout')
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Cart item tile ─────────────────────────────────────────────────────────────

class _CartItemTile extends ConsumerWidget {
  const _CartItemTile({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(cartControllerProvider.notifier);
    final isUnavailable = !item.isAvailable;

    return Opacity(
      opacity: isUnavailable ? 0.5 : 1.0,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Thumbnail ────────────────────────────────────────────────
              SizedBox(
                width: 72,
                height: 72,
                child: CachedImage(
                  storagePath: item.product?.primaryImagePath,
                  aspectRatio: 1,
                  borderRadius: AppRadius.card,
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // ── Details ──────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + unavailable chip row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.product?.name ?? 'Unknown product',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isUnavailable
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isUnavailable) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Chip(
                            label: const Text('Unavailable'),
                            labelStyle: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.error,
                            ),
                            backgroundColor: AppColors.error.withAlpha(20),
                            side: BorderSide(
                                color: AppColors.error.withAlpha(60)),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: AppSpacing.xs),

                    // Unit price
                    if (item.product != null)
                      Text(
                        Formatters.inr(item.product!.price),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),

                    const SizedBox(height: AppSpacing.sm),

                    // Stepper + line total + remove button
                    Row(
                      children: [
                        if (!isUnavailable)
                          QuantityStepper(
                            value: item.quantity,
                            min: 1,
                            max: 99,
                            onChanged: (newQty) async {
                              final failure = await controller.updateQuantity(
                                itemId: item.id,
                                quantity: newQty,
                              );
                              if (failure != null && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(failure.message),
                                  ),
                                );
                              }
                            },
                          )
                        else
                          // Show quantity as static text for unavailable items.
                          Text(
                            'Qty: ${item.quantity}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),

                        const Spacer(),

                        // Line total (only for available items)
                        if (!isUnavailable && item.product != null)
                          Text(
                            Formatters.inr(item.lineTotal),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),

                        const SizedBox(width: AppSpacing.sm),

                        // Remove button
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.error,
                          ),
                          tooltip: 'Remove item',
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              _confirmRemove(context, ref, item.id),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    String itemId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove item?'),
        content: const Text('This item will be removed from your cart.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final failure =
          await ref.read(cartControllerProvider.notifier).removeItem(itemId);
      if (failure != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      }
    }
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.subtotal});

  final double subtotal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Price summary',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary)),
              Text(
                Formatters.inr(subtotal),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Delivery calculated at checkout',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
