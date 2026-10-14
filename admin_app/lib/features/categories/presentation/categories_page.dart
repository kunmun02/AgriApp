import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/shell/presentation/admin_shell.dart';
import '../data/admin_category_repository.dart';
import '../data/models/category.dart';
import '../widgets/category_tree_table.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _categoriesProvider =
    FutureProvider.autoDispose<List<Category>>((ref) async {
  return ref.read(adminCategoryRepositoryProvider).fetchAll();
});

// ── Page ──────────────────────────────────────────────────────────────────────

/// A03 — Categories list (`/admin/categories`)
class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdminShell(
      title: 'Categories',
      child: _CategoriesBody(),
    );
  }
}

class _CategoriesBody extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_categoriesProvider);

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(e.toString()),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: () => ref.invalidate(_categoriesProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (categories) => _CategoriesContent(
        categories: categories,
        onRefresh: () => ref.invalidate(_categoriesProvider),
      ),
    );
  }
}

class _CategoriesContent extends StatelessWidget {
  const _CategoriesContent({
    required this.categories,
    required this.onRefresh,
  });

  final List<Category> categories;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final nodes = CategoryTree.build(categories);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Text('Categories',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              SizedBox(
                width: 160,
                child: ElevatedButton.icon(
                  key: const Key('new_category_button'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New category'),
                  onPressed: () => context.go('/admin/categories/new'),
                ),
              ),
            ],
          ),
        ),
        // ── Column headers ────────────────────────────────────────
        const ColoredBox(
            color: AppColors.background,
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Name',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text('Order',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary),
                        textAlign: TextAlign.center),
                  ),
                  SizedBox(width: 56, child: SizedBox()),
                  // Placeholder for action icons width
                  SizedBox(width: 120),
                ],
              ),
            )),
        const Divider(height: 1),
        // ── Tree ──────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            child: CategoryTreeTable(
              nodes: nodes,
              onRefresh: onRefresh,
            ),
          ),
        ),
      ],
    );
  }
}
