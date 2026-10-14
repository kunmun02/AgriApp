import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../features/shell/presentation/admin_shell.dart';
import '../../categories/data/admin_category_repository.dart';
import '../../categories/data/models/category.dart';
import '../data/admin_attribute_repository.dart';
import '../data/models/category_attribute.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _attributesProvider = FutureProvider.autoDispose
    .family<List<CategoryAttribute>, String>((ref, categoryId) {
  return ref
      .read(adminAttributeRepositoryProvider)
      .fetchForCategory(categoryId);
});

final _categoriesForAttributesProvider =
    FutureProvider.autoDispose<List<Category>>((ref) {
  return ref.read(adminCategoryRepositoryProvider).fetchAll();
});

// ── Page ──────────────────────────────────────────────────────────────────────

/// A05 — Attributes list (`/admin/categories/:categoryId/attributes`)
class AttributesPage extends ConsumerWidget {
  const AttributesPage({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdminShell(
      title: 'Attributes',
      child: _AttributesBody(categoryId: categoryId),
    );
  }
}

class _AttributesBody extends ConsumerWidget {
  const _AttributesBody({required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attrsState = ref.watch(_attributesProvider(categoryId));
    final catsState = ref.watch(_categoriesForAttributesProvider);

    if (attrsState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (attrsState.hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(attrsState.error.toString()),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: () => ref.invalidate(_attributesProvider(categoryId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final attrs = attrsState.value!;

    // Resolve category name from the categories list (best-effort; falls back).
    final categoryName = catsState.whenData((cats) {
          try {
            return cats.firstWhere((c) => c.id == categoryId).name;
          } catch (_) {
            return 'Category';
          }
        }).valueOrNull ??
        'Category';

    return _AttributesContent(
      categoryId: categoryId,
      categoryName: categoryName,
      attributes: attrs,
      onRefresh: () => ref.invalidate(_attributesProvider(categoryId)),
    );
  }
}

// ── Content ───────────────────────────────────────────────────────────────────

class _AttributesContent extends ConsumerWidget {
  const _AttributesContent({
    required this.categoryId,
    required this.categoryName,
    required this.attributes,
    required this.onRefresh,
  });

  final String categoryId;
  final String categoryName;
  final List<CategoryAttribute> attributes;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attributes — $categoryName',
                    key: const Key('attributes_title'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  InkWell(
                    key: const Key('breadcrumb_categories'),
                    onTap: () => context.go('/admin/categories'),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_back,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Categories',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 160,
                child: ElevatedButton.icon(
                  key: const Key('new_attribute_button'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New attribute'),
                  onPressed: () => context
                      .go('/admin/categories/$categoryId/attributes/new'),
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
            child: _ColumnHeaders(),
          ),
        ),
        const Divider(height: 1),

        // ── Rows or empty state ───────────────────────────────────
        if (attributes.isEmpty)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: Text(
                'No attributes yet',
                key: Key('empty_attributes'),
              ),
            ),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: attributes
                    .map((a) => _AttributeRow(
                          attribute: a,
                          categoryId: categoryId,
                          onRefresh: onRefresh,
                          ref: ref,
                        ))
                    .toList(),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Column headers ────────────────────────────────────────────────────────────

class _ColumnHeaders extends StatelessWidget {
  const _ColumnHeaders();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(flex: 3, child: _H('Name')),
        Expanded(flex: 2, child: _H('Key')),
        SizedBox(width: 90, child: Center(child: _H('Type'))),
        SizedBox(width: 72, child: Center(child: _H('Required'))),
        SizedBox(width: 52, child: Center(child: _H('Order'))),
        SizedBox(width: 80, child: Center(child: _H('Active'))),
        SizedBox(width: 80),
      ],
    );
  }
}

class _H extends StatelessWidget {
  const _H(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}

// ── Attribute row ─────────────────────────────────────────────────────────────

class _AttributeRow extends StatefulWidget {
  const _AttributeRow({
    required this.attribute,
    required this.categoryId,
    required this.onRefresh,
    required this.ref,
  });

  final CategoryAttribute attribute;
  final String categoryId;
  final VoidCallback onRefresh;
  final WidgetRef ref;

  @override
  State<_AttributeRow> createState() => _AttributeRowState();
}

class _AttributeRowState extends State<_AttributeRow> {
  bool _loading = false;

  Future<void> _deactivate() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Deactivate attribute?',
      message:
          'Existing product values are kept; the field stops appearing on product forms.',
      confirmLabel: 'Deactivate',
    );
    if (!confirmed || !mounted) return;

    setState(() => _loading = true);
    try {
      await widget.ref
          .read(adminAttributeRepositoryProvider)
          .deactivate(widget.attribute.id);
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.attribute;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            children: [
              // Name + Inactive chip
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Flexible(child: Text(a.name)),
                    if (!a.isActive) ...[
                      const SizedBox(width: AppSpacing.sm),
                      _typeChip(
                        'Inactive',
                        color: AppColors.statusInactiveBg,
                        textColor: AppColors.textSecondary,
                      ),
                    ],
                  ],
                ),
              ),
              // Key
              Expanded(
                flex: 2,
                child: Text(
                  a.attributeKey,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Type chip
              SizedBox(
                width: 90,
                child: Center(
                  child: _typeChip(
                    a.dataType.label,
                    color: AppColors.primaryContainer,
                    textColor: AppColors.onPrimaryContainer,
                  ),
                ),
              ),
              // Required
              SizedBox(
                width: 72,
                child: Center(
                  child: a.isRequired
                      ? const Icon(Icons.check,
                          size: 18, color: AppColors.success)
                      : const SizedBox.shrink(),
                ),
              ),
              // Order
              SizedBox(
                width: 52,
                child: Text(
                  '${a.displayOrder}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              // Active icon
              SizedBox(
                width: 80,
                child: Center(
                  child: a.isActive
                      ? const Icon(Icons.toggle_on,
                          color: AppColors.primary, size: 28)
                      : const Icon(Icons.toggle_off,
                          color: AppColors.textSecondary, size: 28),
                ),
              ),
              // Actions
              SizedBox(
                width: 80,
                child: _loading
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            key: Key('edit_attr_${a.id}'),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: 'Edit',
                            onPressed: () => context.go(
                              '/admin/categories/${widget.categoryId}/attributes/${a.id}/edit',
                            ),
                          ),
                          if (a.isActive)
                            IconButton(
                              key: Key('deactivate_attr_${a.id}'),
                              icon: const Icon(Icons.block_outlined, size: 18),
                              tooltip: 'Deactivate',
                              onPressed: _deactivate,
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  static Widget _typeChip(String label,
      {required Color color, required Color textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w500, color: textColor),
        textAlign: TextAlign.center,
      ),
    );
  }
}
