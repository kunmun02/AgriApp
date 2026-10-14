import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/category.dart';
import '../../../core/theme/app_theme.dart';

/// Recursive expandable category tree.
/// Tapping any node navigates to /categories/:id.
class CategoryTreeView extends StatelessWidget {
  const CategoryTreeView({
    super.key,
    required this.roots,
  });

  final List<CategoryTreeNode> roots;

  @override
  Widget build(BuildContext context) {
    if (roots.isEmpty) return const SizedBox.shrink();
    return Column(
      children: roots.map((node) => _TreeTile(node: node, depth: 0)).toList(),
    );
  }
}

class _TreeTile extends StatelessWidget {
  const _TreeTile({required this.node, required this.depth});

  final CategoryTreeNode node;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final indent = depth * AppSpacing.xl;
    final cat = node.category;

    if (node.isLeaf) {
      return ListTile(
        contentPadding: EdgeInsets.only(
          left: AppSpacing.lg + indent,
          right: AppSpacing.lg,
        ),
        leading: const Icon(Icons.label_outline, color: AppColors.primary),
        title: Text(cat.name),
        onTap: () => context.push('/categories/${cat.id}'),
      );
    }

    return ExpansionTile(
      tilePadding: EdgeInsets.only(
        left: AppSpacing.lg + indent,
        right: AppSpacing.lg,
      ),
      leading: const Icon(Icons.folder_outlined, color: AppColors.primary),
      title: Text(cat.name),
      onExpansionChanged: (expanding) {
        // Tapping the tile itself (not the expand arrow) navigates.
        // We handle that via trailing tap below; collapse/expand is normal.
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Navigate icon.
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 14),
            tooltip: 'Browse ${cat.name}',
            onPressed: () => context.push('/categories/${cat.id}'),
          ),
          // Default expand icon provided by ExpansionTile.
        ],
      ),
      children: node.children
          .map((child) => _TreeTile(node: child, depth: depth + 1))
          .toList(),
    );
  }
}
