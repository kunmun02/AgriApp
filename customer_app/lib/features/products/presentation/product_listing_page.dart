import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/paginated.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry.dart';
import '../data/models/product_card.dart';
import '../data/product_repository.dart';
import '../widgets/product_card_widget.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

/// Params carried into the provider family.
class _ListingParams {
  const _ListingParams({
    this.categoryId,
    this.query,
    required this.sort,
    this.minPrice,
    this.maxPrice,
    required this.page,
  });
  final String? categoryId;
  final String? query;
  final ProductSort sort;
  final double? minPrice;
  final double? maxPrice;
  final int page;

  @override
  bool operator ==(Object other) =>
      other is _ListingParams &&
      other.categoryId == categoryId &&
      other.query == query &&
      other.sort == sort &&
      other.minPrice == minPrice &&
      other.maxPrice == maxPrice &&
      other.page == page;

  @override
  int get hashCode =>
      Object.hash(categoryId, query, sort, minPrice, maxPrice, page);
}

final _productListingProvider = FutureProvider.autoDispose
    .family<Paginated<ProductCard>, _ListingParams>((ref, params) {
  return ref.read(productRepositoryProvider).listProducts(
        query: params.query,
        categoryId: params.categoryId,
        minPrice: params.minPrice,
        maxPrice: params.maxPrice,
        sort: params.sort,
        page: params.page,
      );
});

// ── Page ──────────────────────────────────────────────────────────────────────

class ProductListingPage extends ConsumerStatefulWidget {
  const ProductListingPage({
    super.key,
    this.categoryId,
    this.categoryName,
    this.initialQuery,
  });

  final String? categoryId;
  final String? categoryName;
  final String? initialQuery;

  @override
  ConsumerState<ProductListingPage> createState() => _ProductListingPageState();
}

class _ProductListingPageState extends ConsumerState<ProductListingPage> {
  ProductSort _sort = ProductSort.newest;
  bool _filtersExpanded = false;
  bool _inStockOnly = false;

  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();
  final _scrollController = ScrollController();

  double? get _minPrice => double.tryParse(_minCtrl.text);
  double? get _maxPrice => double.tryParse(_maxCtrl.text);

  // Accumulated items across pages.
  final List<ProductCard> _items = [];
  int _page = 1;
  int _total = 0;
  bool _hasMore = false;
  bool _isLoadingMore = false;
  String? _loadMoreError;

  // Track active filter values for re-query on change.
  ProductSort _activeSort = ProductSort.newest;
  double? _activeMin;
  double? _activeMax;

  // Guard to prevent seeding the same page-1 data multiple times.
  Object? _lastSeededParamsKey;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  String get _appBarTitle {
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      return 'Search: ${widget.initialQuery}';
    }
    return widget.categoryName ?? 'Products';
  }

  void _applyFilters() {
    _resetList();
    _activeMin = _minPrice;
    _activeMax = _maxPrice;
    _activeSort = _sort;
  }

  void _resetList() {
    setState(() {
      _items.clear();
      _page = 1;
      _total = 0;
      _hasMore = false;
      _loadMoreError = null;
    });
  }

  void _clearFilters() {
    _minCtrl.clear();
    _maxCtrl.clear();
    setState(() {
      _sort = ProductSort.newest;
      _inStockOnly = false;
    });
    _activeMin = null;
    _activeMax = null;
    _activeSort = ProductSort.newest;
    _resetList();
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });
    try {
      final params = _ListingParams(
        categoryId: widget.categoryId,
        query: widget.initialQuery,
        sort: _activeSort,
        minPrice: _activeMin,
        maxPrice: _activeMax,
        page: _page + 1,
      );
      final result = await ref.read(_productListingProvider(params).future);
      setState(() {
        _items.addAll(result.items);
        _page = result.page;
        _total = result.total;
        _hasMore = result.hasMore;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _loadMoreError =
            e is AppFailure ? e.userMessage : 'Failed to load more';
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refresh() async {
    _resetList();
  }

  List<ProductCard> get _displayItems =>
      _inStockOnly ? _items.where((p) => p.inStock).toList() : _items;

  @override
  Widget build(BuildContext context) {
    // Watch page 1 for initial load + resets.
    final params1 = _ListingParams(
      categoryId: widget.categoryId,
      query: widget.initialQuery,
      sort: _activeSort,
      minPrice: _activeMin,
      maxPrice: _activeMax,
      page: 1,
    );
    final page1Async = ref.watch(_productListingProvider(params1));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_appBarTitle),
        actions: [
          // In-stock-only toggle.
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Row(
              children: [
                Text('In stock', style: Theme.of(context).textTheme.bodySmall),
                Switch(
                  value: _inStockOnly,
                  onChanged: (v) => setState(() => _inStockOnly = v),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Sort + Filters row ──────────────────────────────────────────
          _buildToolbar(context),

          // ── Grid ────────────────────────────────────────────────────────
          Expanded(
            child: page1Async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) {
                final msg =
                    e is AppFailure ? e.userMessage : 'Failed to load products';
                return ErrorRetry(
                  message: msg,
                  onRetry: () {
                    _resetList();
                    ref.invalidate(_productListingProvider(params1));
                  },
                );
              },
              data: (page1) {
                // Seed items on first load or reset (once per unique params).
                final paramsKey = Object.hash(
                    widget.categoryId, widget.initialQuery,
                    _activeSort, _activeMin, _activeMax);
                if (_lastSeededParamsKey != paramsKey &&
                    page1.items.isNotEmpty) {
                  _lastSeededParamsKey = paramsKey;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _items
                          ..clear()
                          ..addAll(page1.items);
                        _page = 1;
                        _total = page1.total;
                        _hasMore = page1.hasMore;
                      });
                    }
                  });
                }
                final display = _displayItems;
                if (display.isEmpty && !page1.hasMore) {
                  return _buildEmpty(context);
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: _buildGrid(display),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Sort dropdown.
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ProductSort>(
                    value: _sort,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                          value: ProductSort.newest, child: Text('Newest')),
                      DropdownMenuItem(
                          value: ProductSort.priceAsc, child: Text('Price ↑')),
                      DropdownMenuItem(
                          value: ProductSort.priceDesc, child: Text('Price ↓')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _sort = v);
                      _activeSort = v;
                      _resetList();
                    },
                  ),
                ),
              ),
              // Filters toggle.
              TextButton.icon(
                onPressed: () =>
                    setState(() => _filtersExpanded = !_filtersExpanded),
                icon: Icon(_filtersExpanded
                    ? Icons.filter_list_off
                    : Icons.filter_list),
                label: const Text('Filters'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          ),
          // Expandable price filters.
          if (_filtersExpanded) ...[
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Min ₹',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: _maxCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max ₹',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                ElevatedButton(
                  onPressed: _applyFilters,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  ),
                  child: const Text('Apply'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return EmptyState(
      icon: Icons.search_off_rounded,
      title: 'No products found',
      message: 'Try adjusting your filters or search terms.',
      actionLabel: 'Clear filters',
      onAction: _clearFilters,
    );
  }

  Widget _buildGrid(List<ProductCard> items) {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.65,
      ),
      itemCount: items.length + 1, // +1 for footer
      itemBuilder: (context, index) {
        if (index < items.length) {
          return ProductCardWidget(
            product: items[index],
            onTap: () => context.push('/products/${items[index].id}'),
          );
        }
        // Footer: spinner / error / end-of-list indicator.
        if (_hasMore || _isLoadingMore) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (_isLoadingMore) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (_loadMoreError != null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: TextButton.icon(
                onPressed: _loadMore,
                icon: const Icon(Icons.refresh),
                label: Text(_loadMoreError!),
              ),
            ),
          );
        }
        // All loaded.
        if (_total > 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: Text(
                '${items.length} of $_total shown',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
