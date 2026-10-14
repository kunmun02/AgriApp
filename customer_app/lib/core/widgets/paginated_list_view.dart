import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Infinite-scroll list with offset paging (pageSize 20).
///
/// Calls [loadMore] when the user scrolls within 400 px of the bottom.
/// Shows a footer spinner while loading the next page.
/// Shows "Page x of y" text when all pages are loaded.
class PaginatedListView<T> extends StatefulWidget {
  const PaginatedListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.hasMore,
    required this.onLoadMore,
    this.isLoadingMore = false,
    this.loadMoreError,
    this.onRetryLoadMore,
    this.padding,
    this.currentPage = 1,
    this.total = 0,
    this.pageSize = 20,
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final bool isLoadingMore;
  final String? loadMoreError;
  final VoidCallback? onRetryLoadMore;
  final EdgeInsetsGeometry? padding;
  final int currentPage;
  final int total;
  final int pageSize;

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.hasMore || widget.isLoadingMore) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      padding: widget.padding,
      itemCount: widget.items.length + 1, // +1 for footer
      itemBuilder: (context, index) {
        if (index < widget.items.length) {
          return widget.itemBuilder(context, widget.items[index], index);
        }
        // Footer
        return _buildFooter(context);
      },
    );
  }

  Widget _buildFooter(BuildContext context) {
    if (widget.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (widget.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          children: [
            Text(
              widget.loadMoreError!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            if (widget.onRetryLoadMore != null)
              TextButton(
                onPressed: widget.onRetryLoadMore,
                child: const Text('Retry'),
              ),
          ],
        ),
      );
    }
    if (!widget.hasMore && widget.total > 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: Text(
            '${widget.items.length} of ${widget.total} shown',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
