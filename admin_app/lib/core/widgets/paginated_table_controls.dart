import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Standard pagination controls used by admin list pages.
///
/// Renders "Prev | Page X of Y | Next".
/// Hidden entirely when [total] ≤ [pageSize] (only one page).
class PaginatedTableControls extends StatelessWidget {
  const PaginatedTableControls({
    super.key,
    required this.page,
    required this.total,
    required this.pageSize,
    required this.onPrev,
    required this.onNext,
  });

  final int page;
  final int total;
  final int pageSize;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  int get _totalPages => (total / pageSize).ceil().clamp(1, 9999);
  bool get _hasPrev => page > 1;
  bool get _hasNext => page < _totalPages;

  @override
  Widget build(BuildContext context) {
    // Hidden when everything fits on one page.
    if (total <= pageSize) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            key: const Key('pager_prev'),
            onPressed: _hasPrev ? onPrev : null,
            child: const Text('Prev'),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Page $page of $_totalPages',
            key: const Key('pager_label'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(
            key: const Key('pager_next'),
            onPressed: _hasNext ? onNext : null,
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
}
