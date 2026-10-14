import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/cached_image.dart';
import '../data/models/product_card.dart';

/// 2-column product card: square image, 1-line name, price + MRP strikethrough
/// + inline discount badge. No "Add" button — tap the card to view detail.
class ProductCardWidget extends StatelessWidget {
  const ProductCardWidget({
    super.key,
    required this.product,
    this.onTap,
  });

  final ProductCard product;
  final VoidCallback? onTap;

  /// Returns the discount percentage string (e.g. "40% off") or null.
  String? _discountLabel() {
    final mrp = product.mrp;
    if (mrp == null || mrp <= product.price) return null;
    final pct = ((mrp - product.price) / mrp * 100).round();
    if (pct <= 0) return null;
    return '$pct% off';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasMrp = product.mrp != null && product.mrp! > product.price;
    final discountLabel = _discountLabel();
    final isOos = !product.inStock;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.outline),
        ),
        color: AppColors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image — fills available height above the fixed info section ─
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedImage(
                    storagePath: product.primaryImagePath,
                    borderRadius: AppRadius.card,
                  ),
                if (isOos)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(100),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppRadius.card),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius:
                              BorderRadius.circular(AppRadius.button),
                        ),
                        child: Text(
                          'Out of stock',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Info ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product name — 1 line, secondary grey, 12 px.
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isOos
                          ? AppColors.textSecondary.withAlpha(128)
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  // Price row: price  ~~mrp~~  N% off badge
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      // Selling price.
                      Text(
                        Formatters.inr(product.price),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isOos
                              ? AppColors.textSecondary.withAlpha(128)
                              : AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      // MRP strikethrough.
                      if (hasMrp)
                        Text(
                          Formatters.inr(product.mrp!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isOos
                                ? AppColors.textSecondary.withAlpha(80)
                                : AppColors.textSecondary,
                            decoration: TextDecoration.lineThrough,
                            fontSize: 10,
                          ),
                        ),

                      // Discount badge.
                      if (discountLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isOos
                                ? AppColors.outline
                                : AppColors.primaryContainer
                                    .withAlpha(180),
                            borderRadius:
                                BorderRadius.circular(AppRadius.card),
                            border: Border.all(
                              color: isOos
                                  ? AppColors.outline
                                  : AppColors.primaryContainer,
                            ),
                          ),
                          child: Text(
                            discountLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isOos
                                  ? AppColors.textSecondary.withAlpha(128)
                                  : AppColors.onPrimaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
