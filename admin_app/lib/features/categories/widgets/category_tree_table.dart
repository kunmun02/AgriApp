import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../data/admin_category_repository.dart';
import '../data/models/category.dart';

/// Flat-rendered tree table for A03.
/// Each [CategoryTreeNode] is one row with indentation based on [level].
class CategoryTreeTable extends ConsumerWidget {
  const CategoryTreeTable({
    super.key,
    required this.nodes,
    required this.onRefresh,
  });

  final List<CategoryTreeNode> nodes;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (nodes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: Text('No categories yet'),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: nodes.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final node = nodes[i];
        return _CategoryRow(node: node, onRefresh: onRefresh);
      },
    );
  }
}

class _CategoryRow extends ConsumerStatefulWidget {
  const _CategoryRow({required this.node, required this.onRefresh});

  final CategoryTreeNode node;
  final VoidCallback onRefresh;

  @override
  ConsumerState<_CategoryRow> createState() => _CategoryRowState();
}

class _CategoryRowState extends ConsumerState<_CategoryRow> {
  bool _toggling = false;

  @override
  Widget build(BuildContext context) {
    final cat = widget.node.category;
    final indent = widget.node.level * 24.0;
    final isInactive = !cat.isActive;

    return Container(
      color: isInactive ? AppColors.background : null,
      padding: EdgeInsets.only(
        left: AppSpacing.md + indent,
        right: AppSpacing.md,
        top: AppSpacing.sm,
        bottom: AppSpacing.sm,
      ),
      child: Row(
        children: [
          // ── Indent caret ──────────────────────────────────────────
          if (widget.node.level > 0) ...[
            const Icon(Icons.subdirectory_arrow_right,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.xs),
          ],

          // ── Name ──────────────────────────────────────────────────
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    cat.name,
                    style: TextStyle(
                      fontWeight: widget.node.level == 0
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isInactive
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (isInactive) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.outline,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Inactive',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ),
                ],
              ],
            ),
          ),

          // ── Display order ─────────────────────────────────────────
          SizedBox(
            width: 40,
            child: Text(
              cat.displayOrder.toString(),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),

          // ── Active switch ─────────────────────────────────────────
          SizedBox(
            width: 56,
            child: _toggling
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Switch(
                    value: cat.isActive,
                    onChanged: (val) => _toggleActive(context, cat, val),
                  ),
          ),

          // ── Actions ───────────────────────────────────────────────
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Edit',
            onPressed: () => context.go('/admin/categories/${cat.id}/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.tune_outlined, size: 18),
            tooltip: 'Attributes',
            onPressed: () =>
                context.go('/admin/categories/${cat.id}/attributes'),
          ),
          if (cat.isActive)
            IconButton(
              icon: const Icon(Icons.block_outlined,
                  size: 18, color: AppColors.error),
              tooltip: 'Deactivate',
              onPressed: () => _deactivate(context, cat),
            ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(
      BuildContext context, Category cat, bool val) async {
    if (!val) {
      await _deactivate(context, cat);
      return;
    }
    setState(() => _toggling = true);
    try {
      await ref
          .read(adminCategoryRepositoryProvider)
          .update(cat.copyWith(isActive: true));
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _deactivate(BuildContext context, Category cat) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: "Deactivate '${cat.name}'?",
      message:
          'Products remain but are hidden from customers. This cannot be undone from this screen.',
      confirmLabel: 'Deactivate',
    );
    if (!confirmed || !mounted) return;
    setState(() => _toggling = true);
    try {
      await ref.read(adminCategoryRepositoryProvider).deactivate(cat.id);
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }
}
