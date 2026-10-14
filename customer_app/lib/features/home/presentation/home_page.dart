import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/category.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cached_image.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry.dart';
import '../../categories/data/category_repository.dart';
import '../../products/data/models/product_card.dart';
import '../../products/data/product_repository.dart';
import '../../products/widgets/product_card_widget.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _popularProductsProvider =
    FutureProvider.autoDispose<List<ProductCard>>((ref) {
  return ref.read(productRepositoryProvider).popularProducts();
});

final _homeCategoriesProvider =
    FutureProvider.autoDispose<List<Category>>((ref) {
  return ref.read(categoryRepositoryProvider).fetchActiveCategories();
});

// ── Banner data ───────────────────────────────────────────────────────────────

class _BannerData {
  const _BannerData({
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.gradientStart,
    required this.gradientEnd,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String ctaLabel;
  final Color gradientStart;
  final Color gradientEnd;
  final IconData icon;
}

const _banners = [
  _BannerData(
    title: 'Fresh Farm Supplies',
    subtitle: 'Quality agri products delivered to your door',
    ctaLabel: 'Shop Now',
    gradientStart: Color(0xFF1B5E20),
    gradientEnd: Color(0xFF43A047),
    icon: Icons.agriculture,
  ),
  _BannerData(
    title: 'Premium Seeds',
    subtitle: 'Certified seeds for a better harvest this season',
    ctaLabel: 'Explore Seeds',
    gradientStart: Color(0xFF004D40),
    gradientEnd: Color(0xFF26A69A),
    icon: Icons.eco,
  ),
  _BannerData(
    title: 'Free Delivery',
    subtitle: 'On orders above ₹500 — pan India',
    ctaLabel: 'Order Now',
    gradientStart: Color(0xFFE65100),
    gradientEnd: Color(0xFFF9A825),
    icon: Icons.local_shipping_outlined,
  ),
];

// ── Quick-offer data ──────────────────────────────────────────────────────────

class _OfferChipData {
  const _OfferChipData({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

const _offers = [
  _OfferChipData(
    label: 'Free Delivery',
    icon: Icons.local_shipping_outlined,
    color: Color(0xFF2E7D32),
  ),
  _OfferChipData(
    label: "Today's Deal",
    icon: Icons.local_offer_outlined,
    color: Color(0xFFE65100),
  ),
  _OfferChipData(
    label: 'New Arrivals',
    icon: Icons.fiber_new_outlined,
    color: Color(0xFF1565C0),
  ),
];

// ── Greeting helper ───────────────────────────────────────────────────────────

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good Morning 🌱';
  if (hour < 17) return 'Good Afternoon ☀️';
  return 'Good Evening 🌙';
}

// ── Page ──────────────────────────────────────────────────────────────────────

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final PageController _bannerController = PageController();
  int _currentBanner = 0;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _startBannerTimer();
  }

  void _startBannerTimer() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_currentBanner + 1) % _banners.length;
      _bannerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(_popularProductsProvider);
    ref.invalidate(_homeCategoriesProvider);
    await Future.wait([
      ref
          .read(_popularProductsProvider.future)
          .catchError((_) => <ProductCard>[]),
      ref.read(_homeCategoriesProvider.future).catchError((_) => <Category>[]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final popularAsync = ref.watch(_popularProductsProvider);
    final categoriesAsync = ref.watch(_homeCategoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── SliverAppBar with greeting ─────────────────────────────
            SliverAppBar(
              pinned: true,
              floating: false,
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              elevation: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _greeting(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Color(0xCCFFFFFF),
                    ),
                  ),
                  const Text(
                    'AgriStore',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onPrimary,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  tooltip: 'Notifications',
                  onPressed: () => context.push('/notifications'),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
            ),

            // ── Search bar ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                child: GestureDetector(
                  onTap: () => context.go('/categories'),
                  child: AbsorbPointer(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search products…',
                        prefixIcon: const Icon(Icons.search,
                            color: AppColors.textSecondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                          borderSide:
                              const BorderSide(color: AppColors.outline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                          borderSide:
                              const BorderSide(color: AppColors.outline),
                        ),
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Banner carousel ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                child: _BannerCarousel(
                  controller: _bannerController,
                  currentIndex: _currentBanner,
                  onPageChanged: (i) => setState(() => _currentBanner = i),
                  onCtaTap: () => context.go('/categories'),
                ),
              ),
            ),

            // ── Quick offers strip ─────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
                child: Row(
                  children: _offers
                      .map((o) => Expanded(child: _OfferChip(data: o)))
                      .toList(),
                ),
              ),
            ),

            // ── Categories section header ──────────────────────────────
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Categories',
                onViewAll: () => context.go('/categories'),
              ),
            ),

            // ── Categories horizontal strip ────────────────────────────
            SliverToBoxAdapter(
              child: categoriesAsync.when(
                loading: () => const _CategoryCirclesSkeleton(),
                error: (e, _) => const SizedBox.shrink(),
                data: (cats) {
                  final roots = cats.where((c) => c.parentId == null).toList()
                    ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
                  if (roots.isEmpty) {
                    return const EmptyState(
                      icon: Icons.grid_view_outlined,
                      title: 'No categories yet',
                    );
                  }
                  return SizedBox(
                    height: 104,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg),
                      itemCount: roots.length,
                      itemBuilder: (_, i) =>
                          _CategoryCircle(category: roots[i]),
                    ),
                  );
                },
              ),
            ),

            // ── Popular Products section header ────────────────────────
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Popular Products',
                onViewAll: () => context.push('/products'),
              ),
            ),

            // ── Popular products grid ──────────────────────────────────
            popularAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: _ProductGridSkeleton(),
              ),
              error: (e, _) {
                final msg =
                    e is AppFailure ? e.userMessage : 'Failed to load products';
                return SliverToBoxAdapter(
                  child: ErrorRetry(
                      message: msg,
                      onRetry: () =>
                          ref.invalidate(_popularProductsProvider)),
                );
              },
              data: (products) {
                if (products.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.shopping_bag_outlined,
                      title: 'No products yet',
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: AppSpacing.sm,
                      mainAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 0.85,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => ProductCardWidget(
                        product: products[i],
                        onTap: () =>
                            context.push('/products/${products[i].id}'),
                      ),
                      childCount: products.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Banner carousel ───────────────────────────────────────────────────────────

class _BannerCarousel extends StatelessWidget {
  const _BannerCarousel({
    required this.controller,
    required this.currentIndex,
    required this.onPageChanged,
    required this.onCtaTap,
  });

  final PageController controller;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onCtaTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Slide area
        SizedBox(
          height: 160,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: PageView.builder(
              controller: controller,
              onPageChanged: onPageChanged,
              itemCount: _banners.length,
              itemBuilder: (_, i) => _BannerSlide(
                data: _banners[i],
                onCtaTap: onCtaTap,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _banners.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              width: i == currentIndex ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == currentIndex
                    ? AppColors.primary
                    : AppColors.outline,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BannerSlide extends StatelessWidget {
  const _BannerSlide({required this.data, required this.onCtaTap});

  final _BannerData data;
  final VoidCallback onCtaTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [data.gradientStart, data.gradientEnd],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          // Text + CTA
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  data.subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Color(0xCCFFFFFF),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.md),
                GestureDetector(
                  onTap: onCtaTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(AppRadius.button),
                    ),
                    child: Text(
                      data.ctaLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: data.gradientStart,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Icon illustration
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: Icon(
              data.icon,
              size: 72,
              color: Colors.white.withAlpha(51),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Offer chip ────────────────────────────────────────────────────────────────

class _OfferChip extends StatelessWidget {
  const _OfferChip({required this.data});

  final _OfferChipData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: data.color.withAlpha(20),
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: data.color.withAlpha(60)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: 20, color: data.color),
          const SizedBox(height: 4),
          Text(
            data.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: data.color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onViewAll});

  final String title;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.sm),
      child: Row(
        children: [
          // Left accent bar
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          if (onViewAll != null)
            GestureDetector(
              onTap: onViewAll,
              child: const Text(
                'View all →',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Category circle ───────────────────────────────────────────────────────────

class _CategoryCircle extends StatelessWidget {
  const _CategoryCircle({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/categories/${category.id}'),
      child: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.md),
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryContainer,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(30),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: category.imagePath != null
                      ? CachedImage(
                          storagePath: category.imagePath,
                          bucket: 'category-images',
                          borderRadius: 30,
                        )
                      : const Icon(Icons.category_outlined,
                          color: AppColors.primary, size: 28),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                category.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Skeletons ─────────────────────────────────────────────────────────────────

class _CategoryCirclesSkeleton extends StatelessWidget {
  const _CategoryCirclesSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: 5,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(right: AppSpacing.md),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.outline,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Container(width: 48, height: 10, color: AppColors.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductGridSkeleton extends StatelessWidget {
  const _ProductGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.65,
      ),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: AppColors.outline,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
    );
  }
}
