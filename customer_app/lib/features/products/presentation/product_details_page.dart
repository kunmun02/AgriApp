import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/cached_image.dart';
import '../../../core/widgets/quantity_stepper.dart';
import '../../cart/controllers/cart_badge_controller.dart';
import '../../cart/data/cart_repository.dart';
import '../controllers/product_details_controller.dart';
import '../data/models/product_detail.dart';
import '../widgets/specification_table.dart';

/// C07 — Product details screen at `/products/:productId`.
///
/// Layout:
///   • Hero image carousel (full-width, overlapping card beneath)
///   • Floating card: name, brand, price, stock badge, discount chip
///   • Scrollable body: specifications, description
///   • Sticky bottom bar: quantity stepper + Add to Cart button
class ProductDetailsPage extends ConsumerStatefulWidget {
  const ProductDetailsPage({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends ConsumerState<ProductDetailsPage> {
  int _quantity = 1;
  int _currentImageIndex = 0;
  bool _addingToCart = false;

  Future<void> _addToCart(ProductDetail product) async {
    if (_addingToCart) return;
    setState(() => _addingToCart = true);

    try {
      final cartRepo = ref.read(cartRepositoryProvider);
      final cartId = await cartRepo.ensureCart();
      await cartRepo.addItem(
        cartId: cartId,
        productId: product.id,
        quantity: _quantity,
      );

      if (!mounted) return;
      ref.read(cartBadgeControllerProvider.notifier).increment();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Added to cart'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        ),
      );
    } on AppFailure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.userMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _addingToCart = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(
      productDetailsControllerProvider(widget.productId),
    );

    return Scaffold(
      // Transparent AppBar so the image bleeds behind it
      extendBodyBehindAppBar: true,
      appBar: _TransparentAppBar(
        title: async.maybeWhen(
          data: (p) => p.name,
          orElse: () => 'Product',
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorBody(
          message: err is AppFailure ? err.userMessage : 'Product not found.',
        ),
        data: (product) => _ProductBody(
          product: product,
          quantity: _quantity,
          currentImageIndex: _currentImageIndex,
          addingToCart: _addingToCart,
          onQuantityChanged: (v) => setState(() => _quantity = v),
          onImageChanged: (i) => setState(() => _currentImageIndex = i),
          onAddToCart: () => _addToCart(product),
        ),
      ),
    );
  }
}

// ── Transparent AppBar ────────────────────────────────────────────────────────

class _TransparentAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _TransparentAppBar({required this.title});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Material(
          color: Colors.white.withAlpha(217),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Navigator.of(context).maybePop(),
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: Icon(
                Icons.arrow_back,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
          ),
        ),
      ),
      title: Text(
        title,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.transparent, // hide title; shown in card below
          fontSize: 0,
        ),
      ),
    );
  }
}

// ── Product body ──────────────────────────────────────────────────────────────

class _ProductBody extends StatelessWidget {
  const _ProductBody({
    required this.product,
    required this.quantity,
    required this.currentImageIndex,
    required this.addingToCart,
    required this.onQuantityChanged,
    required this.onImageChanged,
    required this.onAddToCart,
  });

  final ProductDetail product;
  final int quantity;
  final int currentImageIndex;
  final bool addingToCart;
  final ValueChanged<int> onQuantityChanged;
  final ValueChanged<int> onImageChanged;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasMrp = product.mrp != null && product.mrp! > product.price;
    final discountPercent = hasMrp
        ? (((product.mrp! - product.price) / product.mrp!) * 100)
            .round()
        : 0;

    return Column(
      children: [
        // ── Scrollable content ───────────────────────────────────────────
        Expanded(
          child: CustomScrollView(
            slivers: [
              // 1. Hero image
              SliverToBoxAdapter(
                child: _ImageCarousel(
                  images: product.images,
                  currentIndex: currentImageIndex,
                  onPageChanged: onImageChanged,
                ),
              ),

              // 2. Info card — overlaps image slightly
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -24),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xl,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Brand
                        if (product.brand != null)
                          Container(
                            margin:
                                const EdgeInsets.only(bottom: AppSpacing.xs),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer
                                  .withAlpha(102),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.button),
                            ),
                            child: Text(
                              product.brand!.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),

                        // Product name
                        Text(
                          product.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        // Price row + discount chip
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              Formatters.inr(product.price),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            if (hasMrp) ...[
                              Text(
                                Formatters.inr(product.mrp!),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  decoration: TextDecoration.lineThrough,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFECB3),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.button),
                                ),
                                child: Text(
                                  '$discountPercent% OFF',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: const Color(0xFFE65100),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),

                        // Tax note
                        if (product.taxPercent > 0) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Incl. ${_formatPercent(product.taxPercent)}% tax',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),

                        // Stock badge
                        _StockBadge(inStock: product.inStock),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Divider ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -24),
                  child: const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.outline,
                    indent: AppSpacing.lg,
                    endIndent: AppSpacing.lg,
                  ),
                ),
              ),

              // 3. Specifications
              if (product.attributes.isNotEmpty)
                SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: const Offset(0, -20),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionHeader(
                            icon: Icons.tune_rounded,
                            label: 'Specifications',
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.card),
                              border: Border.all(color: AppColors.outline),
                            ),
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.card),
                              child: SpecificationTable(
                                  attributes: product.attributes),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 4. Description
              if (product.description != null &&
                  product.description!.isNotEmpty)
                SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: const Offset(0, -20),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.xl,
                        AppSpacing.lg,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionHeader(
                            icon: Icons.description_outlined,
                            label: 'Description',
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.card),
                              border: Border.all(color: AppColors.outline),
                            ),
                            child: Text(
                              product.description!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textPrimary,
                                height: 1.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
            ],
          ),
        ),

        // ── Sticky bottom action bar ─────────────────────────────────────
        _BottomActionBar(
          quantity: quantity,
          inStock: product.inStock,
          addingToCart: addingToCart,
          onQuantityChanged: onQuantityChanged,
          onAddToCart: onAddToCart,
        ),
      ],
    );
  }

  String _formatPercent(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
        ),
      ],
    );
  }
}

// ── Bottom action bar ─────────────────────────────────────────────────────────

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.quantity,
    required this.inStock,
    required this.addingToCart,
    required this.onQuantityChanged,
    required this.onAddToCart,
  });

  final int quantity;
  final bool inStock;
  final bool addingToCart;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        MediaQuery.of(context).padding.bottom + AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Quantity stepper (pill style)
          QuantityStepper(
            value: quantity,
            onChanged: inStock ? onQuantityChanged : (_) {},
            compact: true,
          ),
          const SizedBox(width: AppSpacing.md),

          // Add to Cart button
          Expanded(
            child: AppButton(
              label: inStock ? 'Add to Cart' : 'Out of Stock',
              loading: addingToCart,
              enabled: inStock,
              icon: inStock ? Icons.shopping_cart_outlined : null,
              onPressed: inStock ? onAddToCart : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Image carousel ────────────────────────────────────────────────────────────

class _ImageCarousel extends StatefulWidget {
  const _ImageCarousel({
    required this.images,
    required this.currentIndex,
    required this.onPageChanged,
  });

  final List<ProductImage> images;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;

    if (images.isEmpty) {
      return const _EmptyImagePlaceholder();
    }

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        children: [
          // Pages
          PageView.builder(
            controller: _controller,
            itemCount: images.length,
            onPageChanged: widget.onPageChanged,
            itemBuilder: (context, index) => CachedImage(
              storagePath: images[index].storagePath,
              aspectRatio: 4 / 3,
              borderRadius: 0,
            ),
          ),

          // Bottom gradient for readability
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(64),
                  ],
                  stops: const [0.6, 1.0],
                ),
              ),
            ),
          ),

          // Dot indicator
          if (images.length > 1)
            Positioned(
              bottom: AppSpacing.xl,
              left: 0,
              right: 0,
              child: Center(
                child: _DotIndicator(
                  count: images.length,
                  current: widget.currentIndex,
                ),
              ),
            ),

          // Image count badge
          if (images.length > 1)
            Positioned(
              bottom: AppSpacing.lg,
              right: AppSpacing.lg,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(115),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.currentIndex + 1}/${images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Empty image placeholder ───────────────────────────────────────────────────

class _EmptyImagePlaceholder extends StatelessWidget {
  const _EmptyImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        color: AppColors.background,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              size: 64,
              color: AppColors.outline,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'No image available',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dot indicator ─────────────────────────────────────────────────────────────

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color:
                active ? Colors.white : Colors.white.withAlpha(128),
          ),
        );
      }),
    );
  }
}

// ── Stock badge ───────────────────────────────────────────────────────────────

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.inStock});

  final bool inStock;

  @override
  Widget build(BuildContext context) {
    final bg = inStock
        ? AppColors.success.withAlpha(26)
        : AppColors.error.withAlpha(26);
    final fg = inStock ? AppColors.success : AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            inStock
                ? Icons.check_circle_rounded
                : Icons.cancel_rounded,
            size: 14,
            color: fg,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            inStock ? 'In Stock' : 'Out of Stock',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Error body ────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go back'),
            ),
          ],
        ),
      ),
    );
  }
}
