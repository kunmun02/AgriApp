import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';

/// C12 — Order Success screen.
///
/// Navigated to via `pushReplacement('/order-success/:orderId', extra: {...})`.
/// Displays a success visual, the order number (copyable), the confirmed total,
/// and navigation actions for "View Order" and "Continue Shopping".
class OrderSuccessPage extends StatelessWidget {
  const OrderSuccessPage({
    super.key,
    required this.orderId,
    this.orderNumber,
    this.total,
  });

  final String orderId;

  /// Server-confirmed order number (e.g. AGR-261006-A1B2C3). May be null on
  /// a duplicate-replay where the server only returns the order_id.
  final String? orderNumber;

  /// Server-confirmed total. May be null on a duplicate-replay.
  final double? total;

  @override
  Widget build(BuildContext context) {
    final displayNumber = orderNumber ?? orderId.substring(0, 8).toUpperCase();
    final theme = Theme.of(context);

    return Scaffold(
      // No back button — use pushReplacement so the stack is clean.
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Order Placed'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(),

              // ── Success icon ────────────────────────────────────────────
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 64,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              Text(
                'Order Placed!',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),

              Text(
                'Thank you for your order. We will confirm it shortly.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Order number (copyable) ─────────────────────────────────
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: displayNumber));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Order number copied to clipboard.')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                    horizontal: AppSpacing.lg,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        children: [
                          Text(
                            'Order Number',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayNumber,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: AppSpacing.md),
                      const Icon(Icons.copy_outlined,
                          size: 18, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),

              if (total != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Total: ${Formatters.inr(total!)}',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],

              const SizedBox(height: AppSpacing.sm),
              Text(
                'Expected: pending admin confirmation',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),

              const Spacer(),

              // ── Actions ─────────────────────────────────────────────────
              AppButton(
                label: 'View Order',
                onPressed: () => context.go('/orders/$orderId'),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Continue Shopping',
                type: AppButtonType.secondary,
                onPressed: () => context.go('/home'),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
